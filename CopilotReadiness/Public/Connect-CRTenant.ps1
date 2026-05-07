function Connect-CRTenant {
    <#
    .SYNOPSIS
        Authenticates to Microsoft 365 services required for the Copilot Readiness Assessment.
    .DESCRIPTION
        Connects to Microsoft Graph, Exchange Online, and Security & Compliance
        using interactive browser authentication — no custom app registration needed.
        The well-known "Microsoft Graph Command Line Tools" enterprise app is used for Graph.
        Follows the same multi-service pattern as the Maester project.
    .PARAMETER TenantUrl
        SharePoint Admin Center URL (e.g. https://contoso-admin.sharepoint.com).
        Used to derive the tenant short name for display purposes only.
    .PARAMETER Service
        Which services to connect to. Defaults to all three.
        Valid values: Graph, ExchangeOnline, SecurityCompliance, All
    .PARAMETER UseDeviceCode
        Use device code flow instead of interactive browser (WAM). Recommended when running
        from a WinForms GUI or any context where WAM popups are hidden. A code + URL will
        be printed to the terminal — open the URL and enter the code to complete sign-in.
        Note: Security & Compliance (Connect-IPPSSession) does not support device code and
        will be skipped when this switch is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantUrl,

        [ValidateSet('All', 'Graph', 'ExchangeOnline', 'SecurityCompliance')]
        [string[]]$Service = @('Graph', 'ExchangeOnline', 'SecurityCompliance'),

        [switch]$UseDeviceCode
    )

    $normalizedTenantUrl = $TenantUrl.Trim().TrimEnd('/')
    $tenantMatch = [regex]::Match($normalizedTenantUrl, '^https://([a-z0-9-]+)-admin\.sharepoint\.com$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if (-not $tenantMatch.Success) {
        throw 'TenantUrl must match https://<tenant>-admin.sharepoint.com'
    }

    $tenantShortName = $tenantMatch.Groups[1].Value.ToLowerInvariant()
    $tenantDomain    = "$tenantShortName.onmicrosoft.com"
    $connectAll      = $Service -contains 'All'
    $connectedSvcs   = [System.Collections.Generic.List[string]]::new()

    # ── Microsoft Graph ──────────────────────────────────────────────────────────
    if ($connectAll -or $Service -contains 'Graph') {
        # InformationProtectionPolicy.Read.All is intentionally excluded — it requires explicit
        # admin consent that may not be granted on the Graph Command Line Tools enterprise app.
        # Sensitivity label metadata is sourced from Security & Compliance (Get-Label) instead.
        $requiredScopes = @(
            'Policy.Read.All',
            'Directory.Read.All',
            'User.Read.All',
            'AuditLog.Read.All',
            'Sites.Read.All',
            'Files.Read.All'
        )

        $existingCtx = Get-MgContext -ErrorAction SilentlyContinue
        if ($null -ne $existingCtx -and -not [string]::IsNullOrWhiteSpace($existingCtx.Account)) {
            Write-CRLog -Message 'Microsoft Graph: reusing existing session.'
        }
        else {
            if ($UseDeviceCode) {
                Write-CRLog -Message 'Microsoft Graph: connecting via device code — check the terminal for the code and URL ...'
            }
            else {
                Write-CRLog -Message 'Microsoft Graph: connecting (interactive browser sign-in) ...'
            }
            try {
                # No -TenantId: let MSAL authenticate against the user's home tenant.
                # The "Microsoft Graph Command Line Tools" multi-tenant enterprise app is used.
                # -ErrorAction Stop promotes non-terminating auth errors to exceptions.
                Connect-MgGraph -Scopes $requiredScopes -NoWelcome -UseDeviceCode:$UseDeviceCode -ErrorAction Stop | Out-Null
            }
            catch [System.Management.Automation.CommandNotFoundException] {
                throw 'Microsoft.Graph.Authentication module is not installed. Run .\Install-Prerequisites.ps1 first.'
            }
            catch {
                throw "Microsoft Graph sign-in failed: $($_.Exception.Message)"
            }
        }

        $mgContext = Get-MgContext -ErrorAction Stop
        if ($null -eq $mgContext -or [string]::IsNullOrWhiteSpace($mgContext.TenantId)) {
            throw 'Microsoft Graph authentication did not complete successfully. No active context was returned.'
        }
        if ([string]::IsNullOrWhiteSpace($mgContext.Account)) {
            Write-CRLog -Level Warning -Message 'Graph context has no Account field — using TenantId for identification.'
        }

        # Soft-warn on missing scopes — admin-consented scopes may not surface in Get-MgContext.
        # Log all granted scopes for diagnostics.
        $grantedScopes = @($mgContext.Scopes)
        Write-CRLog -Message "Granted scopes: $($grantedScopes -join ', ')"
        $missingScopes = $requiredScopes | Where-Object { $grantedScopes -notcontains $_ }
        if ($missingScopes) {
            Write-CRLog -Level Warning -Message "Scopes not in token context: $($missingScopes -join ', ')"
        }

        # WAM can silently reuse a cached token that is missing critical scopes (e.g. Sites.Read.All).
        # If SharePoint scopes are absent, force a full disconnect + reconnect to bust the cache.
        $criticalScopes = @('Sites.Read.All', 'Files.Read.All')
        $missingCritical = $criticalScopes | Where-Object { $grantedScopes -notcontains $_ }
        if ($missingCritical) {
            Write-CRLog -Level Warning -Message "Critical scopes missing from token ($($missingCritical -join ', ')). WAM may have returned a cached token. Forcing fresh authentication ..."
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            try {
                Connect-MgGraph -Scopes $requiredScopes -NoWelcome -UseDeviceCode:$UseDeviceCode -ErrorAction Stop | Out-Null
            }
            catch {
                throw "Microsoft Graph re-authentication failed: $($_.Exception.Message)"
            }
            $mgContext = Get-MgContext -ErrorAction Stop
            $grantedScopes = @($mgContext.Scopes)
            $stillMissing = $criticalScopes | Where-Object { $grantedScopes -notcontains $_ }
            if ($stillMissing) {
                Write-CRLog -Level Warning -Message (
                    "Scopes still missing after re-auth: $($stillMissing -join ', '). " +
                    "SharePoint assessments will fail with 403 Forbidden. " +
                    "To fix: in Azure AD, go to Enterprise Applications > Microsoft Graph Command Line Tools > Permissions and grant admin consent for Sites.Read.All and Files.Read.All.")
            }
        }

        $organizationName = $tenantDomain
        try {
            $orgResp = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/organization?$select=id,displayName' -OutputType PSObject
            if ($null -ne $orgResp.value -and $orgResp.value.Count -gt 0) {
                $organizationName = $orgResp.value[0].displayName
            }
        }
        catch {
            Write-CRLog -Level Warning -Message "Could not resolve org display name. $($_.Exception.Message)"
        }

        $script:CRState = [ordered]@{
            Connected         = $true
            TenantUrl         = $normalizedTenantUrl
            TenantShortName   = $tenantShortName
            TenantDomain      = $tenantDomain
            TenantId          = $mgContext.TenantId
            OrganizationName  = $organizationName
            ConnectedUser     = $mgContext.Account
            ConnectedAt       = Get-Date
            Scopes            = $requiredScopes
            ConnectedServices = @()
        }

        $connectedSvcs.Add('Graph')
        $displayAccount = if ([string]::IsNullOrWhiteSpace($mgContext.Account)) { $mgContext.TenantId } else { $mgContext.Account }
        Write-CRLog -Level Success -Message "Microsoft Graph: connected as $displayAccount to $organizationName."
    }

    # ── Exchange Online ──────────────────────────────────────────────────────────
    if ($connectAll -or $Service -contains 'ExchangeOnline') {
        try {
            $exoConn = Get-ConnectionInformation -ErrorAction SilentlyContinue
            $activeExo = $exoConn | Where-Object { $_.State -eq 'Connected' -and -not $_.IsEopSession }
            if ($activeExo) {
                Write-CRLog -Message 'Exchange Online: reusing existing session.'
            }
            else {
                if ($UseDeviceCode) {
                    Write-CRLog -Message 'Exchange Online: connecting via device code — check the terminal for the code and URL ...'
                }
                else {
                    Write-CRLog -Message 'Exchange Online: connecting (interactive browser sign-in) ...'
                }
                Connect-ExchangeOnline -ShowBanner:$false -Device:$UseDeviceCode -ErrorAction Stop
            }
            $connectedSvcs.Add('ExchangeOnline')
            Write-CRLog -Level Success -Message 'Exchange Online: connected.'
        }
        catch [System.Management.Automation.CommandNotFoundException] {
            Write-CRLog -Level Warning -Message 'ExchangeOnlineManagement module not installed — Exchange Online checks will be skipped. Run .\Install-Prerequisites.ps1.'
        }
        catch {
            Write-CRLog -Level Warning -Message "Exchange Online connection failed — Exchange checks will be skipped. $($_.Exception.Message)"
        }
    }

    # ── Security & Compliance (sensitivity label metadata, DLP) ─────────────────
    # Note: Connect-IPPSSession does not support device code flow (Maester parity).
    if (($connectAll -or $Service -contains 'SecurityCompliance') -and -not $UseDeviceCode) {
        try {
            # Connect-IPPSSession shares the EXO module; requires ExchangeOnlineManagement
            Write-CRLog -Message 'Security & Compliance: connecting (interactive browser sign-in) ...'
            Connect-IPPSSession -ShowBanner:$false -ErrorAction Stop
            $connectedSvcs.Add('SecurityCompliance')
            Write-CRLog -Level Success -Message 'Security & Compliance: connected.'
        }
        catch [System.Management.Automation.CommandNotFoundException] {
            Write-CRLog -Level Warning -Message 'ExchangeOnlineManagement module not installed — Security & Compliance checks will be skipped. Run .\Install-Prerequisites.ps1.'
        }
        catch {
            Write-CRLog -Level Warning -Message "Security & Compliance connection failed — label policy data will come from Graph only. $($_.Exception.Message)"
        }
    }
    elseif ($UseDeviceCode -and ($connectAll -or $Service -contains 'SecurityCompliance')) {
        Write-CRLog -Level Warning -Message 'Security & Compliance: skipped — Connect-IPPSSession does not support device code flow. Label names will be resolved via Microsoft Graph.'
    }

    $script:CRState.ConnectedServices = $connectedSvcs.ToArray()

    if (-not $script:CRState.Connected) {
        throw 'Microsoft Graph connection is required but did not succeed.'
    }

    return [pscustomobject]$script:CRState
}

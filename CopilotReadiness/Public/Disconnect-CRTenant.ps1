function Disconnect-CRTenant {
    [CmdletBinding()]
    param()

    # ── Microsoft Graph ──────────────────────────────────────────────────────────
    try {
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if ($null -ne $context) {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Write-CRLog -Message 'Microsoft Graph: disconnected.'
        }
    }
    catch {
        Write-CRLog -Level Warning -Message "Microsoft Graph disconnect error: $($_.Exception.Message)"
    }

    # ── Exchange Online ──────────────────────────────────────────────────────────
    try {
        $exoConn = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if ($exoConn) {
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            Write-CRLog -Message 'Exchange Online: disconnected.'
        }
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        # Module not installed — nothing to disconnect
    }
    catch {
        Write-CRLog -Level Warning -Message "Exchange Online disconnect error: $($_.Exception.Message)"
    }

    $script:CRState = [ordered]@{
        Connected         = $false
        TenantUrl         = $null
        TenantShortName   = $null
        TenantDomain      = $null
        TenantId          = $null
        OrganizationName  = $null
        ConnectedUser     = $null
        ConnectedAt       = $null
        Scopes            = @()
        ConnectedServices = @()
    }
}

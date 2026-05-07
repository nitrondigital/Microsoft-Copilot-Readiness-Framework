function Get-CRExternalUserAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [switch]$IncludeInactiveUsers
    )

    if (-not $script:CRState.Connected) {
        throw 'No Graph connection found. Run Connect-CRTenant first.'
    }

    if (-not (Test-Path -Path $OutputPath)) {
        $null = New-Item -ItemType Directory -Path $OutputPath -Force
    }

    Write-CRLog -Message 'Retrieving guest users from Microsoft Graph...'
    $externalUsers = @(Get-CRGraphPaged -Uri "https://graph.microsoft.com/beta/users?`$filter=userType%20eq%20%27Guest%27&`$select=id,displayName,mail,userPrincipalName,createdDateTime,signInActivity,userType&`$top=200")

    Write-CRLog -Message "Found $($externalUsers.Count) guest users."

    $riskRank = @{ Low = 1; Medium = 2; High = 3; Critical = 4 }
    $permissionRank = @{ 'Limited Access' = 1; 'Read' = 2; 'Edit' = 3; 'Design' = 4; 'Full Control' = 5 }

    $summaryById = @{}
    $emailToId = @{}

    foreach ($user in $externalUsers) {
        $email = if ([string]::IsNullOrWhiteSpace($user.mail)) { $user.'userPrincipalName' } else { $user.mail }
        $domain = ''
        if ($email -like '*@*') {
            $domain = $email.Split('@')[-1].ToLowerInvariant()
        }

        $lastSignIn = $null
        if ($null -ne $user.signInActivity) {
            if ($user.signInActivity.lastSignInDateTime) {
                $lastSignIn = [datetime]$user.signInActivity.lastSignInDateTime
            }
            elseif ($user.signInActivity.lastSuccessfulSignInDateTime) {
                $lastSignIn = [datetime]$user.signInActivity.lastSuccessfulSignInDateTime
            }
        }

        $daysSinceLastActivity = if ($null -ne $lastSignIn) {
            (New-TimeSpan -Start $lastSignIn -End (Get-Date)).Days
        }
        else {
            999
        }

        $summaryById[$user.id] = [ordered]@{
            Id                    = $user.id
            Email                 = $email
            DisplayName           = $user.displayName
            LoginName             = $user.'userPrincipalName'
            HighestPermission     = 'Limited Access'
            HighestRiskLevel      = 'Low'
            TotalSites            = 0
            DaysSinceLastActivity = $daysSinceLastActivity
            SitesAccessed         = [System.Collections.Generic.HashSet[string]]::new()
            Domain                = $domain
        }

        if (-not [string]::IsNullOrWhiteSpace($email)) {
            $emailToId[$email.ToLowerInvariant()] = $user.id
        }

        if (-not [string]::IsNullOrWhiteSpace($user.'userPrincipalName')) {
            $emailToId[$user.'userPrincipalName'.ToLowerInvariant()] = $user.id
        }
    }

    $externalUserAccess = @()

    Write-CRLog -Message 'Retrieving SharePoint sites via Microsoft Search API...'
    # GET /sites?search=* requires application permissions for wildcard; requires a real keyword for delegated.
    # GET /sites (list all) also requires application permissions — delegated not supported.
    # POST /search/query with entityTypes=["site"] supports delegated Sites.Read.All.
    # Ref: https://learn.microsoft.com/graph/api/search-query
    $sites = @(Get-CRSitesList)
    Write-CRLog -Message "Found $($sites.Count) sites to evaluate for guest access."

    foreach ($site in $sites) {
        try {
            $sitePermissions = Get-CRGraphPaged -Uri "https://graph.microsoft.com/v1.0/sites/$($site.id)/permissions?`$top=200"
        }
        catch {
            Write-CRLog -Level Warning -Message "Skipping site permission scan for $($site.webUrl). $($_.Exception.Message)"
            continue
        }

        foreach ($permission in $sitePermissions) {
            $roles = if ($permission.roles) { $permission.roles -join '; ' } else { 'Read' }
            $granteeSet = @()

            if ($null -ne $permission.grantedToV2) {
                $granteeSet += $permission.grantedToV2
            }

            if ($null -ne $permission.grantedToIdentitiesV2) {
                $granteeSet += @($permission.grantedToIdentitiesV2)
            }

            foreach ($grantee in $granteeSet) {
                $granteeId = $null
                $granteeMail = $null

                if ($null -ne $grantee.user) {
                    $granteeId = $grantee.user.id
                    $granteeMail = $grantee.user.email
                }
                elseif ($null -ne $grantee.siteUser) {
                    $granteeId = $grantee.siteUser.id
                    $granteeMail = $grantee.siteUser.email
                }
                else {
                    continue
                }

                $summaryKey = $null
                if (-not [string]::IsNullOrWhiteSpace($granteeId) -and $summaryById.ContainsKey($granteeId)) {
                    $summaryKey = $granteeId
                }
                elseif (-not [string]::IsNullOrWhiteSpace($granteeMail)) {
                    $normalizedMail = $granteeMail.ToLowerInvariant()
                    if ($emailToId.ContainsKey($normalizedMail)) {
                        $summaryKey = $emailToId[$normalizedMail]
                    }
                }

                if ([string]::IsNullOrWhiteSpace($summaryKey)) {
                    continue
                }

                $riskLevel = 'Low'
                $riskFactors = @('Direct site permission assignment')

                if ($roles -match '(?i)owner|fullcontrol') {
                    $riskLevel = 'Critical'
                    $riskFactors += 'Full control style role'
                    $highestPermission = 'Full Control'
                }
                elseif ($roles -match '(?i)write|edit|manage') {
                    $riskLevel = 'High'
                    $riskFactors += 'Edit or write role'
                    $highestPermission = 'Edit'
                }
                else {
                    $highestPermission = 'Read'
                }

                $summaryEntry = $summaryById[$summaryKey]

                if ($summaryEntry.DaysSinceLastActivity -gt 90) {
                    $riskFactors += "No sign-in in $($summaryEntry.DaysSinceLastActivity) days"
                    if ($riskRank[$riskLevel] -lt $riskRank['Medium']) {
                        $riskLevel = 'Medium'
                    }
                }

                $consumerDomains = @('gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com', 'live.com')
                if ($consumerDomains -contains $summaryEntry.Domain) {
                    $riskFactors += 'Consumer email domain'
                    if ($riskRank[$riskLevel] -lt $riskRank['Medium']) {
                        $riskLevel = 'Medium'
                    }
                }

                $accessRecord = [PSCustomObject]@{
                    ExternalUserEmail     = $summaryEntry.Email
                    DisplayName           = $summaryEntry.DisplayName
                    LoginName             = $summaryEntry.LoginName
                    SiteUrl               = $site.webUrl
                    SiteTitle             = $site.displayName
                    Permissions           = $roles
                    RiskLevel             = $riskLevel
                    RiskFactors           = ($riskFactors -join '; ')
                    EmailDomain           = $summaryEntry.Domain
                    DaysSinceLastActivity = $summaryEntry.DaysSinceLastActivity
                    InvitedBy             = ''
                    InvitedDate           = ''
                }

                $externalUserAccess += $accessRecord

                $null = $summaryEntry.SitesAccessed.Add($site.webUrl)
                $summaryEntry.TotalSites = $summaryEntry.SitesAccessed.Count

                if ($permissionRank[$highestPermission] -gt $permissionRank[$summaryEntry.HighestPermission]) {
                    $summaryEntry.HighestPermission = $highestPermission
                }

                if ($riskRank[$riskLevel] -gt $riskRank[$summaryEntry.HighestRiskLevel]) {
                    $summaryEntry.HighestRiskLevel = $riskLevel
                }
            }
        }
    }

    $userSummaryReport = @(foreach ($entry in $summaryById.Values) {
        if (-not $IncludeInactiveUsers -and $entry.DaysSinceLastActivity -gt 90 -and $entry.TotalSites -eq 0) {
            continue
        }

        [PSCustomObject]@{
            Email                 = $entry.Email
            DisplayName           = $entry.DisplayName
            TotalSitesAccessed    = $entry.TotalSites
            HighestPermission     = $entry.HighestPermission
            HighestRiskLevel      = $entry.HighestRiskLevel
            DaysSinceLastActivity = $entry.DaysSinceLastActivity
            SitesAccessed         = (@($entry.SitesAccessed) -join '; ')
        }
    })

    $highRiskAccess = @($externalUserAccess | Where-Object { $_.RiskLevel -in @('Critical', 'High') })

    $totalExternalUsers = $userSummaryReport.Count
    $criticalRiskUsers = @($userSummaryReport | Where-Object { $_.HighestRiskLevel -eq 'Critical' }).Count
    $highRiskUsers = @($userSummaryReport | Where-Object { $_.HighestRiskLevel -eq 'High' }).Count
    $inactiveUsers = @($userSummaryReport | Where-Object { $_.DaysSinceLastActivity -gt 90 }).Count
    $fullControlUsers = @($userSummaryReport | Where-Object { $_.HighestPermission -eq 'Full Control' }).Count

    $readinessRating = if ($criticalRiskUsers -eq 0 -and $fullControlUsers -eq 0 -and ($totalExternalUsers -eq 0 -or $inactiveUsers -lt ($totalExternalUsers * 0.1))) {
        'Ready'
    }
    elseif ($criticalRiskUsers -le 2 -and $fullControlUsers -le 2) {
        'Nearly Ready'
    }
    elseif ($criticalRiskUsers -le 5) {
        'Requires Work'
    }
    else {
        'Not Ready'
    }

    $readinessScore = [Math]::Max(0, 100 - ($criticalRiskUsers * 20) - ($highRiskUsers * 10) - ($fullControlUsers * 15))

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outputFileAccess = Join-Path -Path $OutputPath -ChildPath "ExternalUserAccess_$timestamp.csv"
    $outputFileSummary = Join-Path -Path $OutputPath -ChildPath "ExternalUserSummary_$timestamp.csv"
    $outputFileHighRisk = Join-Path -Path $OutputPath -ChildPath "HighRiskExternalAccess_$timestamp.csv"
    $outputFileExecSummary = Join-Path -Path $OutputPath -ChildPath "ExternalUserAccess_ExecutiveSummary_$timestamp.txt"

    $externalUserAccess | Export-Csv -Path $outputFileAccess -NoTypeInformation -Encoding UTF8
    $userSummaryReport | Export-Csv -Path $outputFileSummary -NoTypeInformation -Encoding UTF8
    if ($highRiskAccess.Count -gt 0) {
        $highRiskAccess | Export-Csv -Path $outputFileHighRisk -NoTypeInformation -Encoding UTF8
    }

    $summary = [PSCustomObject]@{
        AssessmentDate    = Get-Date
        TotalExternalUsers = $totalExternalUsers
        CriticalRiskUsers = $criticalRiskUsers
        HighRiskUsers     = $highRiskUsers
        InactiveUsers     = $inactiveUsers
        FullControlUsers  = $fullControlUsers
        TotalAccessPoints = $externalUserAccess.Count
        ReadinessRating   = $readinessRating
    }

    @(
        "AssessmentDate=$($summary.AssessmentDate)",
        "TotalExternalUsers=$($summary.TotalExternalUsers)",
        "CriticalRiskUsers=$($summary.CriticalRiskUsers)",
        "HighRiskUsers=$($summary.HighRiskUsers)",
        "InactiveUsers=$($summary.InactiveUsers)",
        "FullControlUsers=$($summary.FullControlUsers)",
        "TotalAccessPoints=$($summary.TotalAccessPoints)",
        "ReadinessRating=$($summary.ReadinessRating)"
    ) | Set-Content -Path $outputFileExecSummary -Encoding UTF8

    Write-CRLog -Level Success -Message "External user access assessment complete. Users=$totalExternalUsers, HighRisk=$highRiskUsers, Critical=$criticalRiskUsers"

    return [PSCustomObject]@{
        Name            = 'ExternalUserAccess'
        Summary         = $summary
        Findings        = $externalUserAccess
        HighRiskAccess  = $highRiskAccess
        UserSummary     = $userSummaryReport
        RawCsvPaths     = @{
            DetailedAccess   = $outputFileAccess
            UserSummary      = $outputFileSummary
            HighRisk         = if ($highRiskAccess.Count -gt 0) { $outputFileHighRisk } else { $null }
            ExecutiveSummary = $outputFileExecSummary
        }
        ReadinessScore  = $readinessScore
        ReadinessRating = $readinessRating
    }
}

function Get-CRCAPolicyAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [switch]$CheckCopilotApps
    )

    if (-not $script:CRState.Connected) {
        throw 'No Graph connection found. Run Connect-CRTenant first.'
    }

    if (-not (Test-Path -Path $OutputPath)) {
        $null = New-Item -ItemType Directory -Path $OutputPath -Force
    }

    $copilotAppIds = @(
        '0ec893e0-5785-4de6-99da-4ed124e5296c',
        'b1831b8b-e4f8-41f4-99d9-b0d8e0e5a4b5',
        '00000003-0000-0000-c000-000000000000'
    )

    Write-CRLog -Message 'Retrieving Conditional Access policies from Microsoft Graph...'
    $policies = Get-CRGraphPaged -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies?$top=200'

    $policyAnalysis = @()
    $copilotCompatibilityIssues = @()

    foreach ($policy in $policies) {
        $assessment = [PSCustomObject]@{
            PolicyName                  = $policy.displayName
            PolicyId                    = $policy.id
            State                       = $policy.state
            CreatedDateTime             = $policy.createdDateTime
            ModifiedDateTime            = $policy.modifiedDateTime
            AppliesTo                   = ''
            IncludeUsers                = ''
            ExcludeUsers                = ''
            IncludeGroups               = ''
            ExcludeGroups               = ''
            IncludeApplications         = ''
            ExcludeApplications         = ''
            UserRiskLevels              = ''
            SignInRiskLevels            = ''
            Platforms                   = ''
            Locations                   = ''
            ClientAppTypes              = ''
            GrantControlOperator        = ''
            GrantControls               = ''
            RequiresMFA                 = $false
            RequiresCompliantDevice     = $false
            RequiresHybridJoin          = $false
            RequiresPasswordChange      = $false
            SessionControls             = ''
            BlocksCopilotApps           = $false
            CopilotCompatibilityScore   = 0
            CompatibilityIssues         = ''
            Recommendations             = ''
        }

        $users = $policy.conditions.users
        $apps = $policy.conditions.applications
        $grantControls = $policy.grantControls

        if ($null -ne $users) {
            if ($users.includeUsers -contains 'All') {
                $assessment.AppliesTo = 'All Users'
            }
            elseif ($users.includeUsers) {
                $assessment.AppliesTo = 'Specific Users'
                $assessment.IncludeUsers = ($users.includeUsers -join '; ')
            }

            if ($users.excludeUsers) {
                $assessment.ExcludeUsers = ($users.excludeUsers -join '; ')
            }

            if ($users.includeGroups) {
                $assessment.IncludeGroups = ($users.includeGroups -join '; ')
            }

            if ($users.excludeGroups) {
                $assessment.ExcludeGroups = ($users.excludeGroups -join '; ')
            }
        }

        if ($null -ne $apps) {
            if ($apps.includeApplications -contains 'All') {
                $assessment.IncludeApplications = 'All Apps'
            }
            elseif ($apps.includeApplications) {
                $assessment.IncludeApplications = ($apps.includeApplications -join '; ')
            }

            if ($apps.excludeApplications) {
                $assessment.ExcludeApplications = ($apps.excludeApplications -join '; ')
            }
        }

        if ($policy.conditions.userRiskLevels) {
            $assessment.UserRiskLevels = ($policy.conditions.userRiskLevels -join ', ')
        }

        if ($policy.conditions.signInRiskLevels) {
            $assessment.SignInRiskLevels = ($policy.conditions.signInRiskLevels -join ', ')
        }

        $caPlatforms = $policy.conditions.platforms
        if ($null -ne $caPlatforms -and $caPlatforms.PSObject.Properties['includePlatforms'] -and $caPlatforms.includePlatforms) {
            $assessment.Platforms = ($caPlatforms.includePlatforms -join ', ')
        }

        $caLocations = $policy.conditions.locations
        if ($null -ne $caLocations -and $caLocations.PSObject.Properties['includeLocations']) {
            if ($caLocations.includeLocations -contains 'All') {
                $assessment.Locations = 'All Locations'
            }
            elseif ($caLocations.includeLocations) {
                $assessment.Locations = ($caLocations.includeLocations -join ', ')
            }
        }

        if ($policy.conditions.clientAppTypes) {
            $assessment.ClientAppTypes = ($policy.conditions.clientAppTypes -join ', ')
        }

        if ($null -ne $grantControls) {
            if ($grantControls.PSObject.Properties['operator']) {
                $assessment.GrantControlOperator = $grantControls.operator
            }
            if ($grantControls.PSObject.Properties['builtInControls'] -and $grantControls.builtInControls) {
                $assessment.GrantControls = ($grantControls.builtInControls -join ', ')
                $assessment.RequiresMFA = $grantControls.builtInControls -contains 'mfa'
                $assessment.RequiresCompliantDevice = $grantControls.builtInControls -contains 'compliantDevice'
                $assessment.RequiresHybridJoin = $grantControls.builtInControls -contains 'domainJoinedDevice'
                $assessment.RequiresPasswordChange = $grantControls.builtInControls -contains 'passwordChange'
            }
        }

        $sessionControlList = @()
        $scSif = $null
        $sc = $policy.sessionControls
        if ($null -ne $sc) {
            $scAer = if ($sc.PSObject.Properties['applicationEnforcedRestrictions']) { $sc.applicationEnforcedRestrictions } else { $null }
            if ($null -ne $scAer -and $scAer.PSObject.Properties['isEnabled'] -and $scAer.isEnabled -eq $true) {
                $sessionControlList += 'App Enforced Restrictions'
            }
            $scCas = if ($sc.PSObject.Properties['cloudAppSecurity']) { $sc.cloudAppSecurity } else { $null }
            if ($null -ne $scCas -and $scCas.PSObject.Properties['isEnabled'] -and $scCas.isEnabled -eq $true) {
                $sessionControlList += 'Cloud App Security Session Control'
            }
            $scSif = if ($sc.PSObject.Properties['signInFrequency']) { $sc.signInFrequency } else { $null }
            if ($null -ne $scSif -and $scSif.PSObject.Properties['isEnabled'] -and $scSif.isEnabled -eq $true) {
                $sessionControlList += "Sign-in Frequency: $($scSif.value) $($scSif.type)"
            }
            $scPb = if ($sc.PSObject.Properties['persistentBrowser']) { $sc.persistentBrowser } else { $null }
            if ($null -ne $scPb -and $scPb.PSObject.Properties['isEnabled'] -and $scPb.isEnabled -eq $true) {
                $sessionControlList += "Persistent Browser: $($scPb.mode)"
            }
        }
        $assessment.SessionControls = ($sessionControlList -join '; ')

        $gcBuiltIn = if ($null -ne $grantControls -and $grantControls.PSObject.Properties['builtInControls']) { $grantControls.builtInControls } else { @() }
        if ($CheckCopilotApps -and $gcBuiltIn -contains 'block') {
            if ($apps.includeApplications -contains 'All') {
                $hasCopilotExclusion = $false
                foreach ($appId in $copilotAppIds) {
                    if ($apps.excludeApplications -contains $appId) {
                        $hasCopilotExclusion = $true
                        break
                    }
                }

                if (-not $hasCopilotExclusion) {
                    $assessment.BlocksCopilotApps = $true
                }
            }
        }

        $compatibilityScore = 100
        $issues = @()
        $recommendations = @()

        if ($assessment.BlocksCopilotApps) {
            $compatibilityScore -= 100
            $issues += 'Policy blocks all apps without Copilot exclusion.'
            $recommendations += 'Exclude Copilot app IDs from this blocking policy.'
        }

        if (-not $assessment.RequiresMFA -and $assessment.State -eq 'enabled' -and $assessment.AppliesTo -eq 'All Users') {
            $compatibilityScore -= 20
            $issues += 'No MFA requirement for users in scope.'
            $recommendations += 'Require MFA for Copilot access.'
        }

        if (-not $assessment.RequiresCompliantDevice -and $assessment.State -eq 'enabled' -and $assessment.AppliesTo -eq 'All Users') {
            $compatibilityScore -= 10
            $issues += 'No compliant device requirement for users in scope.'
            $recommendations += 'Consider compliant device enforcement for Copilot access.'
        }

        if ($null -ne $scSif -and $scSif.PSObject.Properties['isEnabled'] -and $scSif.isEnabled -eq $true -and
            $scSif.PSObject.Properties['value'] -and $scSif.value -lt 4) {
            $compatibilityScore -= 15
            $issues += 'Frequent sign-in requirement may degrade Copilot experience.'
            $recommendations += 'Review sign-in frequency for Copilot workflows.'
        }

        $assessment.CopilotCompatibilityScore = [Math]::Max(0, $compatibilityScore)
        $assessment.CompatibilityIssues = ($issues -join '; ')
        $assessment.Recommendations = ($recommendations -join '; ')

        $policyAnalysis += $assessment

        if ($assessment.CopilotCompatibilityScore -lt 80) {
            $copilotCompatibilityIssues += $assessment
        }
    }

    $recommendedPolicies = @(
        [PSCustomObject]@{
            PolicyName    = 'Copilot - Require MFA'
            Description   = 'Require multi-factor authentication for Copilot access.'
            AppliesTo     = 'All Users'
            Applications  = 'Microsoft 365 Copilot'
            Conditions    = 'All cloud apps'
            GrantControls = 'Require MFA'
            Priority      = 'High'
        },
        [PSCustomObject]@{
            PolicyName    = 'Copilot - Require Compliant Device'
            Description   = 'Require managed, compliant devices for Copilot access.'
            AppliesTo     = 'All Users'
            Applications  = 'Microsoft 365 Copilot'
            Conditions    = 'All devices'
            GrantControls = 'Require compliant device'
            Priority      = 'High'
        },
        [PSCustomObject]@{
            PolicyName    = 'Copilot - Block High-Risk Sign-ins'
            Description   = 'Block Copilot access from high-risk sign-ins.'
            AppliesTo     = 'All Users'
            Applications  = 'Microsoft 365 Copilot'
            Conditions    = 'Sign-in risk: High'
            GrantControls = 'Block access'
            Priority      = 'Critical'
        },
        [PSCustomObject]@{
            PolicyName    = 'Copilot - External Users Restriction'
            Description   = 'Additional controls for external users accessing Copilot.'
            AppliesTo     = 'Guest users'
            Applications  = 'Microsoft 365 Copilot'
            Conditions    = 'All cloud apps'
            GrantControls = 'Require MFA AND compliant device'
            Priority      = 'High'
        }
    )

    $totalPolicies = $policyAnalysis.Count
    $enabledPolicies = @($policyAnalysis | Where-Object { $_.State -eq 'enabled' }).Count
    $policiesWithMFA = @($policyAnalysis | Where-Object { $_.State -eq 'enabled' -and $_.RequiresMFA }).Count
    $policiesWithDeviceCompliance = @($policyAnalysis | Where-Object { $_.State -eq 'enabled' -and $_.RequiresCompliantDevice }).Count
    $blockingPolicies = @($policyAnalysis | Where-Object { $_.State -eq 'enabled' -and $_.GrantControls -match 'block' }).Count
    $compatibilityIssuesCount = $copilotCompatibilityIssues.Count
    $averageScore = if ($totalPolicies -gt 0) {
        [Math]::Round((($policyAnalysis | Measure-Object -Property CopilotCompatibilityScore -Average).Average), 2)
    }
    else {
        0
    }

    $readinessRating = if ($compatibilityIssuesCount -eq 0 -and $policiesWithMFA -ge 1) {
        'Ready'
    }
    elseif ($compatibilityIssuesCount -le 2) {
        'Nearly Ready'
    }
    elseif ($compatibilityIssuesCount -le 5) {
        'Requires Work'
    }
    else {
        'Not Ready'
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outputFileAnalysis = Join-Path -Path $OutputPath -ChildPath "CA_PolicyAnalysis_$timestamp.csv"
    $outputFileSummary = Join-Path -Path $OutputPath -ChildPath "CA_ExecutiveSummary_$timestamp.txt"
    $outputFileRecommended = Join-Path -Path $OutputPath -ChildPath "CA_RecommendedCopilotPolicies_$timestamp.csv"
    $outputFileIssues = Join-Path -Path $OutputPath -ChildPath "CA_CompatibilityIssues_$timestamp.csv"

    $policyAnalysis | Export-Csv -Path $outputFileAnalysis -NoTypeInformation -Encoding UTF8
    $recommendedPolicies | Export-Csv -Path $outputFileRecommended -NoTypeInformation -Encoding UTF8
    if ($copilotCompatibilityIssues.Count -gt 0) {
        $copilotCompatibilityIssues | Export-Csv -Path $outputFileIssues -NoTypeInformation -Encoding UTF8
    }

    $summary = [PSCustomObject]@{
        AssessmentDate                   = Get-Date
        TotalPolicies                    = $totalPolicies
        EnabledPolicies                  = $enabledPolicies
        PoliciesWithMFA                  = $policiesWithMFA
        PoliciesWithDeviceCompliance     = $policiesWithDeviceCompliance
        BlockingPolicies                 = $blockingPolicies
        CompatibilityIssues              = $compatibilityIssuesCount
        AverageCopilotCompatibilityScore = $averageScore
        ReadinessRating                  = $readinessRating
    }

    @(
        "AssessmentDate=$($summary.AssessmentDate)",
        "TotalPolicies=$($summary.TotalPolicies)",
        "EnabledPolicies=$($summary.EnabledPolicies)",
        "PoliciesWithMFA=$($summary.PoliciesWithMFA)",
        "PoliciesWithDeviceCompliance=$($summary.PoliciesWithDeviceCompliance)",
        "BlockingPolicies=$($summary.BlockingPolicies)",
        "CompatibilityIssues=$($summary.CompatibilityIssues)",
        "AverageCopilotCompatibilityScore=$($summary.AverageCopilotCompatibilityScore)",
        "ReadinessRating=$($summary.ReadinessRating)"
    ) | Set-Content -Path $outputFileSummary -Encoding UTF8

    Write-CRLog -Level Success -Message "CA assessment complete. Policies=$totalPolicies, Issues=$compatibilityIssuesCount, Score=$averageScore"

    return [PSCustomObject]@{
        Name            = 'CAPolicies'
        Summary         = $summary
        Findings        = $policyAnalysis
        RawCsvPaths     = @{
            Analysis           = $outputFileAnalysis
            Summary            = $outputFileSummary
            Recommended        = $outputFileRecommended
            CompatibilityIssues = if ($copilotCompatibilityIssues.Count -gt 0) { $outputFileIssues } else { $null }
        }
        ReadinessScore  = $averageScore
        ReadinessRating = $readinessRating
    }
}

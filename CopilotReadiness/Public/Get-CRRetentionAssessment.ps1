function Get-CRRetentionAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    if (-not $script:CRState.Connected) {
        throw 'No Graph connection found. Run Connect-CRTenant first.'
    }

    if (-not (Test-Path -Path $OutputPath)) {
        $null = New-Item -ItemType Directory -Path $OutputPath -Force
    }

    $retentionLabels   = @()
    $retentionPolicies = @()
    $retentionRulesMap = @{}

    if ($script:CRState.ConnectedServices -contains 'SecurityCompliance') {
        # S&C already connected (e.g. terminal usage via Connect-CRTenant -Service All).
        Write-CRLog -Message 'Retrieving retention labels from Security & Compliance ...'
        try { $retentionLabels = @(Get-ComplianceTag -ErrorAction Stop) }
        catch { throw "Failed to retrieve retention labels. $($_.Exception.Message)" }

        Write-CRLog -Message 'Retrieving retention policies from Security & Compliance ...'
        try { $retentionPolicies = @(Get-RetentionCompliancePolicy -DistributionDetail -ErrorAction Stop) }
        catch { throw "Failed to retrieve retention policies. $($_.Exception.Message)" }

        foreach ($pol in $retentionPolicies) {
            $pn = [string](Get-CRSafeProperty $pol 'Name')
            if (-not [string]::IsNullOrWhiteSpace($pn)) {
                try { $retentionRulesMap[$pn] = @(Get-RetentionComplianceRule -Policy $pn -ErrorAction Stop) }
                catch { $retentionRulesMap[$pn] = @() }
            }
        }
    }
    else {
        # Connect S&C in a new STA runspace to avoid deadlocking the WinForms STA thread.
        # Connect-IPPSSession uses a MSAL localhost OAuth callback. When called on the GUI
        # STA thread the callback can never be processed (the thread is blocked waiting for
        # itself). A fresh STA runspace provides an independent thread where the callback
        # completes normally. All S&C proxy commands are collected there and results are
        # returned as plain PSCustomObjects that survive runspace serialisation.
        Write-CRLog -Message 'Security & Compliance: connecting (browser sign-in) — complete the authentication in the browser window that opens ...'

        $scScript = {
            param([string]$UserPrincipalName)
            Import-Module ExchangeOnlineManagement -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($UserPrincipalName)) {
                Connect-IPPSSession -ShowBanner:$false -UserPrincipalName $UserPrincipalName -ErrorAction Stop
            }
            else {
                Connect-IPPSSession -ShowBanner:$false -ErrorAction Stop
            }
            $labels   = @(Get-ComplianceTag -ErrorAction Stop)
            $policies = @(Get-RetentionCompliancePolicy -DistributionDetail -ErrorAction Stop)
            $rulesMap = @{}
            foreach ($pol in $policies) {
                $pn = $pol.Name
                if (-not [string]::IsNullOrWhiteSpace($pn)) {
                    try { $rulesMap[$pn] = @(Get-RetentionComplianceRule -Policy $pn -ErrorAction Stop) }
                    catch { $rulesMap[$pn] = @() }
                }
            }
            return [PSCustomObject]@{
                Labels   = $labels
                Policies = $policies
                Rules    = $rulesMap
            }
        }

        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = [System.Threading.ApartmentState]::STA
        $rs.Open()
        $psInst = [System.Management.Automation.PowerShell]::Create()
        $psInst.Runspace = $rs

        $upn = [string](Get-CRSafeProperty $script:CRState 'ConnectedUser')
        $null = $psInst.AddScript($scScript).AddParameter('UserPrincipalName', $upn)

        try {
            $asyncHandle = $psInst.BeginInvoke()
            $scResults   = $psInst.EndInvoke($asyncHandle)

            if ($psInst.HadErrors) {
                $errMsg = ($psInst.Streams.Error | ForEach-Object { $_.ToString() }) -join '; '
                throw "Security & Compliance runspace errors: $errMsg"
            }

            if ($scResults.Count -gt 0) {
                $scData            = $scResults[0]
                $retentionLabels   = @(Get-CRSafeProperty $scData 'Labels')
                $retentionPolicies = @(Get-CRSafeProperty $scData 'Policies')
                $rawRules = Get-CRSafeProperty $scData 'Rules'
                if ($null -ne $rawRules) {
                    foreach ($key in @($rawRules.Keys)) {
                        $retentionRulesMap[$key] = @($rawRules[$key])
                    }
                }
            }

            $script:CRState.ConnectedServices = @($script:CRState.ConnectedServices) + 'SecurityCompliance'
            Write-CRLog -Level Success -Message 'Security & Compliance: connected and data retrieved.'
        }
        catch {
            throw "Failed to connect to Security and Compliance or retrieve data. $($_.Exception.Message)"
        }
        finally {
            $psInst.Dispose()
            $rs.Close()
            $rs.Dispose()
        }
    }

    $locationConfigured = {
        param([object]$Value)

        if ($null -eq $Value) {
            return $false
        }

        if ($Value -is [string]) {
            $trimmed = $Value.Trim()
            return -not [string]::IsNullOrWhiteSpace($trimmed) -and $trimmed -ne 'None'
        }

        if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
            $items = @($Value)
            if ($items.Count -eq 0) {
                return $false
            }

            if ($items.Count -eq 1 -and [string]$items[0] -eq 'None') {
                return $false
            }

            return $true
        }

        return $true
    }

    $labelInventory = @(
        foreach ($label in $retentionLabels) {
            [PSCustomObject]@{
                LabelName                     = [string](Get-CRSafeProperty $label 'Name')
                RetentionAction               = [string](Get-CRSafeProperty $label 'RetentionAction')
                RetentionDuration             = [string](Get-CRSafeProperty $label 'RetentionDuration')
                RetentionDurationDisplayHint  = [string](Get-CRSafeProperty $label 'RetentionDurationDisplayHint')
                IsRecordLabel                 = [bool](Get-CRSafeProperty $label 'IsRecordLabel')
                Priority                      = [string](Get-CRSafeProperty $label 'Priority')
            }
        }
    )

    $policyFindings = @()
    $activeSharePoint = $false
    $activeOneDrive = $false
    $activeExchange = $false
    $activeTeams = $false
    $policiesWithDeleteAction = 0
    $keepOnlyPolicies = 0
    $deleteOnlyPolicies = 0
    $keepAndDeletePolicies = 0

    foreach ($policy in $retentionPolicies) {
        $policyName = [string](Get-CRSafeProperty $policy 'Name')
        $enabledRaw = Get-CRSafeProperty $policy 'Enabled'
        $isEnabled = $true
        if ($enabledRaw -is [bool]) {
            $isEnabled = [bool]$enabledRaw
        }
        elseif ($enabledRaw -is [string] -and -not [string]::IsNullOrWhiteSpace($enabledRaw)) {
            $isEnabled = [System.Convert]::ToBoolean($enabledRaw)
        }

        $spConfigured = & $locationConfigured (Get-CRSafeProperty $policy 'SharePointLocation')
        $odConfigured = & $locationConfigured (Get-CRSafeProperty $policy 'OneDriveLocation')
        $exConfigured = & $locationConfigured (Get-CRSafeProperty $policy 'ExchangeLocation')
        $teamsConfigured =
            (& $locationConfigured (Get-CRSafeProperty $policy 'TeamsChatLocation')) -or
            (& $locationConfigured (Get-CRSafeProperty $policy 'TeamsChannelLocation')) -or
            (& $locationConfigured (Get-CRSafeProperty $policy 'TeamsLocation'))

        if ($isEnabled) {
            if ($spConfigured) { $activeSharePoint = $true }
            if ($odConfigured) { $activeOneDrive = $true }
            if ($exConfigured) { $activeExchange = $true }
            if ($teamsConfigured) { $activeTeams = $true }
        }

        $rules = @()
        if (-not [string]::IsNullOrWhiteSpace($policyName) -and $retentionRulesMap.ContainsKey($policyName)) {
            $rules = @($retentionRulesMap[$policyName])
        }

        $actions = @($rules | ForEach-Object { [string](Get-CRSafeProperty $_ 'RetentionComplianceAction') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        $durations = @($rules | ForEach-Object { [string](Get-CRSafeProperty $_ 'RetentionDuration') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

        $hasDeleteAction = $actions | Where-Object { $_ -match '(?i)delete' }
        if ($isEnabled -and $hasDeleteAction) {
            $policiesWithDeleteAction++
        }

        $policyLifecycle = 'NotSpecified'
        if ($actions -contains 'KeepAndDelete') {
            $policyLifecycle = 'RetainThenDelete'
            if ($isEnabled) { $keepAndDeletePolicies++ }
        }
        elseif ($actions -contains 'Delete') {
            $policyLifecycle = 'DeleteOnly'
            if ($isEnabled) { $deleteOnlyPolicies++ }
        }
        elseif ($actions -contains 'Keep') {
            $policyLifecycle = 'RetainOnly'
            if ($isEnabled) { $keepOnlyPolicies++ }
        }

        $workloads = @()
        if ($spConfigured) { $workloads += 'SharePoint' }
        if ($odConfigured) { $workloads += 'OneDrive' }
        if ($exConfigured) { $workloads += 'Exchange' }
        if ($teamsConfigured) { $workloads += 'Teams' }

        $policyFindings += [PSCustomObject]@{
            PolicyName       = if ([string]::IsNullOrWhiteSpace($policyName)) { '<Unnamed Policy>' } else { $policyName }
            EnabledStatus    = if ($isEnabled) { 'Enabled' } else { 'Disabled' }
            WorkloadsCovered = if ($workloads.Count -gt 0) { $workloads -join '; ' } else { 'None' }
            RetentionAction  = if ($actions.Count -gt 0) { $actions -join '; ' } else { 'NotSpecified' }
            RetentionDuration = if ($durations.Count -gt 0) { $durations -join '; ' } else { 'NotSpecified' }
            LifecycleMode    = $policyLifecycle
        }
    }

    $activePolicies = @($policyFindings | Where-Object { $_.EnabledStatus -eq 'Enabled' })

    $readinessScore = 0
    if ($activeSharePoint) { $readinessScore += 25 }
    if ($activeOneDrive) { $readinessScore += 20 }
    if ($activeExchange) { $readinessScore += 20 }
    if ($activeTeams) { $readinessScore += 15 }
    if ($policiesWithDeleteAction -gt 0) { $readinessScore += 20 }

    $workloadsCovered = @()
    if ($activeSharePoint) { $workloadsCovered += 'SharePoint' }
    if ($activeOneDrive) { $workloadsCovered += 'OneDrive' }
    if ($activeExchange) { $workloadsCovered += 'Exchange' }
    if ($activeTeams) { $workloadsCovered += 'Teams' }

    $dataLifecyclePosture = if ($keepAndDeletePolicies -gt 0 -or $deleteOnlyPolicies -gt 0) {
        'Retention and deletion actions configured'
    }
    elseif ($keepOnlyPolicies -gt 0) {
        'Retention-only actions configured'
    }
    else {
        'No explicit retention actions detected'
    }

    $readinessRating = Get-CRReadinessRating -Score $readinessScore

    $summary = [PSCustomObject]@{
        AssessmentDate            = Get-Date
        TotalRetentionLabels      = $labelInventory.Count
        TotalPolicies             = $policyFindings.Count
        TotalActivePolicies       = $activePolicies.Count
        WorkloadsCovered          = if ($workloadsCovered.Count -gt 0) { $workloadsCovered -join ', ' } else { 'None' }
        PoliciesWithDeleteAction  = $policiesWithDeleteAction
        KeepOnlyPolicies          = $keepOnlyPolicies
        DeleteOnlyPolicies        = $deleteOnlyPolicies
        KeepAndDeletePolicies     = $keepAndDeletePolicies
        DataLifecyclePosture      = $dataLifecyclePosture
        ReadinessRating           = $readinessRating
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outputFilePolicies = Join-Path -Path $OutputPath -ChildPath "RetentionPolicyFindings_$timestamp.csv"
    $outputFileLabels = Join-Path -Path $OutputPath -ChildPath "RetentionLabels_$timestamp.csv"
    $outputFileSummary = Join-Path -Path $OutputPath -ChildPath "RetentionAssessmentSummary_$timestamp.csv"

    $policyFindings | Export-Csv -Path $outputFilePolicies -NoTypeInformation -Encoding UTF8
    $labelInventory | Export-Csv -Path $outputFileLabels -NoTypeInformation -Encoding UTF8
    @($summary) | Export-Csv -Path $outputFileSummary -NoTypeInformation -Encoding UTF8

    Write-CRLog -Level Success -Message "Retention assessment complete. ActivePolicies=$($summary.TotalActivePolicies), Labels=$($summary.TotalRetentionLabels), Score=$readinessScore"

    return [PSCustomObject]@{
        Name            = 'RetentionLabels'
        Summary         = $summary
        Findings        = $policyFindings
        LabelInventory  = $labelInventory
        RawCsvPaths     = @{
            PolicyFindings = $outputFilePolicies
            Labels         = $outputFileLabels
            Summary        = $outputFileSummary
        }
        ReadinessScore  = $readinessScore
        ReadinessRating = $readinessRating
    }
}
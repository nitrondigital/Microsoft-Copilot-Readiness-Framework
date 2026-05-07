function New-CRReadinessReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Results,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$TenantUrl
    )

    if (-not (Test-Path -Path $OutputPath)) {
        $null = New-Item -ItemType Directory -Path $OutputPath -Force
    }

    $templatePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Templates\report.html'
    $templatePath = (Resolve-Path -Path $templatePath).Path

    if (-not (Test-Path -Path $templatePath)) {
        throw "HTML template not found: $templatePath"
    }

    $encode = {
        param([object]$Value)
        [System.Net.WebUtility]::HtmlEncode([string]$Value)
    }

    $badgeClass = {
        param([string]$Rating)
        switch ($Rating) {
            'Ready' { 'ready' }
            'Nearly Ready' { 'nearly-ready' }
            'Requires Work' { 'requires-work' }
            default { 'not-ready' }
        }
    }

    $toRows = {
        param(
            [object[]]$Items,
            [string[]]$Columns
        )

        if ($null -eq $Items -or $Items.Count -eq 0) {
            return "<tr><td colspan='$($Columns.Count)'>No findings.</td></tr>"
        }

        $rowBuilder = New-Object System.Text.StringBuilder
        foreach ($item in $Items) {
            [void]$rowBuilder.Append('<tr>')
            foreach ($column in $Columns) {
                $value = ''
                if ($item.PSObject.Properties.Name -contains $column) {
                    $value = $item.$column
                }
                [void]$rowBuilder.Append("<td>$(& $encode $value)</td>")
            }
            [void]$rowBuilder.Append('</tr>')
        }

        return $rowBuilder.ToString()
    }

    $dimensions = @(
        [PSCustomObject]@{ Key = 'CAPolicies'; Name = 'Conditional Access'; Result = $Results['CAPolicies'] },
        [PSCustomObject]@{ Key = 'ExternalUserAccess'; Name = 'External User Access'; Result = $Results['ExternalUserAccess'] },
        [PSCustomObject]@{ Key = 'LabelCoverage'; Name = 'Sensitivity Labels'; Result = $Results['LabelCoverage'] },
        [PSCustomObject]@{ Key = 'OversharedContent'; Name = 'Overshared Content'; Result = $Results['OversharedContent'] }
    )

    $cardsBuilder = New-Object System.Text.StringBuilder
    $radarLabels = @()
    $radarData = @()
    $scores = @()

    foreach ($dimension in $dimensions) {
        $score = 0
        $rating = 'Not Ready'

        if ($null -ne $dimension.Result) {
            $score = [Math]::Round([double]$dimension.Result.ReadinessScore, 2)
            $rating = [string]$dimension.Result.ReadinessRating
        }

        $radarLabels += $dimension.Name
        $radarData += $score
        $scores += $score

        $class = & $badgeClass $rating
        [void]$cardsBuilder.Append("<div class='card'><h3>$(& $encode $dimension.Name)</h3><p><strong>$score</strong> / 100</p><span class='badge $class'>$(& $encode $rating)</span></div>")
    }

    $overallScore = if ($scores.Count -gt 0) {
        [Math]::Round((($scores | Measure-Object -Average).Average), 2)
    }
    else {
        0
    }
    $overallRating = Get-CRReadinessRating -Score $overallScore
    $overallClass = & $badgeClass $overallRating

    $caRows = @()
    if ($null -ne $Results['CAPolicies'] -and $null -ne $Results['CAPolicies'].Findings) {
        $caRows = $Results['CAPolicies'].Findings |
            Where-Object { $_.CopilotCompatibilityScore -lt 80 } |
            Sort-Object -Property CopilotCompatibilityScore |
            Select-Object -First 15 PolicyName, CopilotCompatibilityScore, CompatibilityIssues
    }

    $externalRows = @()
    if ($null -ne $Results['ExternalUserAccess']) {
        if ($Results['ExternalUserAccess'].PSObject.Properties['HighRiskAccess'] -and $null -ne $Results['ExternalUserAccess'].HighRiskAccess) {
            $externalRows = $Results['ExternalUserAccess'].HighRiskAccess |
                Select-Object -First 15 ExternalUserEmail, SiteUrl, Permissions, RiskLevel
        }
        elseif ($Results['ExternalUserAccess'].PSObject.Properties['Findings'] -and $null -ne $Results['ExternalUserAccess'].Findings) {
            $externalRows = $Results['ExternalUserAccess'].Findings |
                Where-Object { $_.RiskLevel -in @('Critical', 'High') } |
                Select-Object -First 15 ExternalUserEmail, SiteUrl, Permissions, RiskLevel
        }
    }

    $labelRows = @()
    if ($null -ne $Results['LabelCoverage']) {
        $unlabeledSensitive = Get-CRSafeProperty $Results['LabelCoverage'] 'UnlabeledSensitive'
        if ($null -ne $unlabeledSensitive) {
            $labelRows = @($unlabeledSensitive) |
                Select-Object -First 15 FileName, SiteUrl, SensitiveIndicators
        }
    }

    $oversharedRows = @()
    if ($null -ne $Results['OversharedContent'] -and $null -ne $Results['OversharedContent'].Findings) {
        $oversharedRows = $Results['OversharedContent'].Findings |
            Select-Object -First 15 ItemName, SiteUrl, SharedWith, RiskLevel, RiskReason
    }

    $rawLinksBuilder = New-Object System.Text.StringBuilder
    foreach ($dimension in $dimensions) {
        if ($null -eq $dimension.Result -or $null -eq $dimension.Result.RawCsvPaths) {
            continue
        }

        foreach ($entry in $dimension.Result.RawCsvPaths.GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace([string]$entry.Value)) {
                continue
            }

            if (-not (Test-Path -Path $entry.Value)) {
                continue
            }

            $uriPath = 'file:///' + ($entry.Value -replace '\\', '/')
            $linkText = "$($dimension.Name) - $($entry.Key)"
            [void]$rawLinksBuilder.Append("<li><a href='$uriPath'>$(& $encode $linkText)</a></li>")
        }
    }

    if ($rawLinksBuilder.Length -eq 0) {
        [void]$rawLinksBuilder.Append('<li>No output files were generated.</li>')
    }

    $rawLinksHtml = "<ul>$($rawLinksBuilder.ToString())</ul>"

    $labelDistribution = @()
    if ($null -ne $Results['LabelCoverage'] -and $null -ne $Results['LabelCoverage'].LabelDistribution) {
        $labelDistribution = @($Results['LabelCoverage'].LabelDistribution)
    }

    $labelNames = if ($labelDistribution.Count -gt 0) {
        $labelDistribution | ForEach-Object { $_.LabelName }
    }
    else {
        @('No Data')
    }

    $labelValues = if ($labelDistribution.Count -gt 0) {
        $labelDistribution | ForEach-Object { [int]$_.DocumentCount }
    }
    else {
        @(1)
    }

    $reportHtml = Get-Content -Path $templatePath -Raw
    $reportHtml = $reportHtml.Replace('{{REPORT_TITLE}}', 'Microsoft Copilot Readiness Assessment Report')
    $reportHtml = $reportHtml.Replace('{{TENANT_URL}}', $TenantUrl)
    $reportHtml = $reportHtml.Replace('{{GENERATED_AT}}', (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
    $reportHtml = $reportHtml.Replace('{{OVERALL_SCORE}}', [string]$overallScore)
    $reportHtml = $reportHtml.Replace('{{OVERALL_RATING}}', $overallRating)
    $reportHtml = $reportHtml.Replace('{{OVERALL_CLASS}}', $overallClass)
    $reportHtml = $reportHtml.Replace('{{SCORE_CARDS}}', $cardsBuilder.ToString())
    $reportHtml = $reportHtml.Replace('{{CA_FINDINGS_ROWS}}', (& $toRows $caRows @('PolicyName', 'CopilotCompatibilityScore', 'CompatibilityIssues')))
    $reportHtml = $reportHtml.Replace('{{EXTERNAL_FINDINGS_ROWS}}', (& $toRows $externalRows @('ExternalUserEmail', 'SiteUrl', 'Permissions', 'RiskLevel')))
    $reportHtml = $reportHtml.Replace('{{LABEL_FINDINGS_ROWS}}', (& $toRows $labelRows @('FileName', 'SiteUrl', 'SensitiveIndicators')))
    $reportHtml = $reportHtml.Replace('{{OVERSHARED_FINDINGS_ROWS}}', (& $toRows $oversharedRows @('ItemName', 'SiteUrl', 'SharedWith', 'RiskLevel', 'RiskReason')))
    $reportHtml = $reportHtml.Replace('{{RAW_FILE_LINKS_HTML}}', $rawLinksHtml)
    $reportHtml = $reportHtml.Replace('{{RADAR_LABELS_JSON}}', (ConvertTo-Json -InputObject $radarLabels -Compress))
    $reportHtml = $reportHtml.Replace('{{RADAR_DATA_JSON}}', (ConvertTo-Json -InputObject $radarData -Compress))
    $reportHtml = $reportHtml.Replace('{{LABEL_NAMES_JSON}}', (ConvertTo-Json -InputObject $labelNames -Compress))
    $reportHtml = $reportHtml.Replace('{{LABEL_VALUES_JSON}}', (ConvertTo-Json -InputObject $labelValues -Compress))

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportPath = Join-Path -Path $OutputPath -ChildPath "CopilotReadinessReport_$timestamp.html"
    Set-Content -Path $reportPath -Value $reportHtml -Encoding UTF8

    $script:CRLastReportPath = $reportPath
    Write-CRLog -Level Success -Message "HTML report generated: $reportPath"

    return $reportPath
}

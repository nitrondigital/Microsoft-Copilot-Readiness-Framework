function Get-CRLabelCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [switch]$IncludeOneDrive,

        [int]$SampleSize = 0
    )

    if (-not $script:CRState.Connected) {
        throw 'No Graph connection found. Run Connect-CRTenant first.'
    }

    if (-not (Test-Path -Path $OutputPath)) {
        $null = New-Item -ItemType Directory -Path $OutputPath -Force
    }

    $totalDocuments = 0
    $labeledDocuments = 0
    $labelDistribution = @{}
    $unlabeledSensitiveContent = @()
    $labelCoverageDetails = @()

    $labelLookup = @{}
    $scConnected = $script:CRState.ConnectedServices -contains 'SecurityCompliance'

    if ($scConnected) {
        try {
            Write-CRLog -Message 'Retrieving sensitivity labels from Security & Compliance ...'
            # Get-Label ImmutableId (GUID) matches the label ID returned in Graph driveItem sensitivityLabel
            $scLabels = Get-Label -ErrorAction Stop
            foreach ($scLabel in $scLabels) {
                if (-not [string]::IsNullOrWhiteSpace($scLabel.ImmutableId)) {
                    $labelLookup[$scLabel.ImmutableId] = $scLabel.DisplayName
                }
            }
            Write-CRLog -Message "Loaded $($labelLookup.Count) sensitivity labels from Security & Compliance."
        }
        catch {
            Write-CRLog -Level Warning -Message "Could not load labels from Security & Compliance; falling back to Graph. $($_.Exception.Message)"
            $scConnected = $false
        }
    }

    if (-not $scConnected) {
        # The Graph beta sensitivityLabels endpoint requires InformationProtectionPolicy.Read.All
        # (admin-restricted scope). We skip it and proceed with label IDs only; the report will
        # show GUIDs where names cannot be resolved without the S&C connection.
        Write-CRLog -Level Warning -Message 'Sensitivity label names cannot be resolved without a Security & Compliance connection. Label GUIDs will appear in the report.'
    }

    Write-CRLog -Message 'Retrieving SharePoint sites via Microsoft Search API...'
    # GET /sites?search=* requires a real keyword (not wildcard) for delegated access.
    # GET /sites (list all) requires application permissions — delegated not supported.
    # POST /search/query with entityTypes=["site"] supports delegated Sites.Read.All.
    # Ref: https://learn.microsoft.com/graph/api/search-query
    $sites = @(Get-CRSitesList)

    if (-not $IncludeOneDrive) {
        $sites = @($sites | Where-Object { $_.webUrl -notlike '*-my.sharepoint.com/personal/*' })
    }

    Write-CRLog -Message "Scanning $($sites.Count) sites for label coverage."

    foreach ($site in $sites) {
        $drives = @()
        try {
            $drives = Get-CRGraphPaged -Uri "https://graph.microsoft.com/v1.0/sites/$($site.id)/drives?`$top=200"
        }
        catch {
            Write-CRLog -Level Warning -Message "Skipping drives for site $($site.webUrl). $($_.Exception.Message)"
            continue
        }

        foreach ($drive in $drives) {
            Write-CRLog -Message "Scanning drive '$($drive.name)' in site '$($site.displayName)'."

            $fileItems = New-Object System.Collections.Generic.List[object]

            $enumerateChildren = {
                param(
                    [string]$DriveId,
                    [string]$ItemId
                )

                if ($SampleSize -gt 0 -and $fileItems.Count -ge $SampleSize) {
                    return
                }

                $childrenUri = "https://graph.microsoft.com/beta/drives/$DriveId/items/$ItemId/children?`$select=id,name,webUrl,file,folder,createdDateTime,lastModifiedDateTime,lastModifiedBy,sensitivityLabel&`$top=200"

                $children = @()
                try {
                    $children = Get-CRGraphPaged -Uri $childrenUri
                }
                catch {
                    Write-CRLog -Level Warning -Message "Unable to enumerate children for drive $DriveId item $ItemId. $($_.Exception.Message)"
                    return
                }

                foreach ($child in $children) {
                    # Use Get-CRSafeProperty to handle both PSCustomObject and Hashtable responses
                    # (Graph beta endpoint with sensitivityLabel may return items as Hashtables)
                    $childFile = Get-CRSafeProperty $child 'file'
                    $childFolder = Get-CRSafeProperty $child 'folder'
                    $childId = Get-CRSafeProperty $child 'id'
                    if ($null -ne $childFile) {
                        $fileItems.Add($child)
                        if ($SampleSize -gt 0 -and $fileItems.Count -ge $SampleSize) {
                            return
                        }
                    }
                    elseif ($null -ne $childFolder -and -not [string]::IsNullOrWhiteSpace($childId)) {
                        & $enumerateChildren $DriveId $childId
                        if ($SampleSize -gt 0 -and $fileItems.Count -ge $SampleSize) {
                            return
                        }
                    }
                }
            }

            & $enumerateChildren $drive.id 'root'

            foreach ($item in $fileItems) {
                $totalDocuments++

                $labelId = $null
                $sensitivityLabel = Get-CRSafeProperty $item 'sensitivityLabel'
                if ($null -ne $sensitivityLabel) {
                    $labelId = Get-CRSafeProperty $sensitivityLabel 'id'
                }

                $hasLabel = -not [string]::IsNullOrWhiteSpace($labelId)
                $labelName = if ($hasLabel) {
                    if ($labelLookup.ContainsKey($labelId)) { $labelLookup[$labelId] } else { $labelId }
                }
                else {
                    'None'
                }

                $fileType = [System.IO.Path]::GetExtension($item.name)
                if ($fileType.StartsWith('.')) {
                    $fileType = $fileType.Substring(1)
                }

                $autoLabeled = $false
                if ($hasLabel) {
                    $labeledDocuments++
                    if ($labelDistribution.ContainsKey($labelName)) {
                        $labelDistribution[$labelName]++
                    }
                    else {
                        $labelDistribution[$labelName] = 1
                    }

                    $lastModBy = Get-CRSafeProperty $item 'lastModifiedBy'
                    $autoLabeled = if ($null -ne $lastModBy) {
                        $null -ne (Get-CRSafeProperty $lastModBy 'application') -or
                        $null -eq (Get-CRSafeProperty $lastModBy 'user')
                    } else { $false }
                }

                $detail = [PSCustomObject]@{
                    SiteUrl          = $site.webUrl
                    LibraryName      = $drive.name
                    FileName         = $item.name
                    FilePath         = $item.webUrl
                    FileType         = $fileType
                    HasLabel         = $hasLabel
                    LabelName        = $labelName
                    AutoLabeled      = $autoLabeled
                    LabelAppliedDate = $null
                    FileCreated      = $item.createdDateTime
                    FileModified     = $item.lastModifiedDateTime
                }

                $labelCoverageDetails += $detail

                if (-not $hasLabel) {
                    $isSensitive = $item.name -match '(?i)confidential|secret|internal|restricted|private|ssn|financ|payroll|hr|contract'
                    if ($isSensitive) {
                        $unlabeledSensitiveContent += [PSCustomObject]@{
                            SiteUrl              = $site.webUrl
                            LibraryName          = $drive.name
                            FileName             = $item.name
                            FilePath             = $item.webUrl
                            SensitiveIndicators  = 'Sensitive filename indicator'
                            FileCreated          = $item.createdDateTime
                            FileModified         = $item.lastModifiedDateTime
                        }
                    }
                }
            }
        }
    }

    $labelCoveragePercent = if ($totalDocuments -gt 0) {
        [Math]::Round(($labeledDocuments / $totalDocuments) * 100, 2)
    }
    else {
        0
    }

    $autoLabeledCount = @($labelCoverageDetails | Where-Object { $_.AutoLabeled }).Count
    $autoLabelPercent = if ($labeledDocuments -gt 0) {
        [Math]::Round(($autoLabeledCount / $labeledDocuments) * 100, 2)
    }
    else {
        0
    }

    $labelDistributionReport = $labelDistribution.GetEnumerator() |
        ForEach-Object {
            [PSCustomObject]@{
                LabelName     = $_.Key
                DocumentCount = $_.Value
                Percentage    = if ($labeledDocuments -gt 0) {
                    [Math]::Round(($_.Value / $labeledDocuments) * 100, 2)
                }
                else {
                    0
                }
            }
        } |
        Sort-Object -Property DocumentCount -Descending

    $readinessRating = Get-CRReadinessRating -Score $labelCoveragePercent

    $summary = [PSCustomObject]@{
        AssessmentDate            = Get-Date
        TotalDocumentsScanned     = $totalDocuments
        LabeledDocuments          = $labeledDocuments
        UnlabeledDocuments        = ($totalDocuments - $labeledDocuments)
        LabelCoveragePercent      = $labelCoveragePercent
        AutoLabeledDocuments      = $autoLabeledCount
        AutoLabelPercent          = $autoLabelPercent
        UniqueLabelTypes          = $labelDistribution.Count
        UnlabeledSensitiveContent = $unlabeledSensitiveContent.Count
        ReadinessRating           = $readinessRating
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outputFileCoverage = Join-Path -Path $OutputPath -ChildPath "LabelCoverage_$timestamp.csv"
    $outputFileDist = Join-Path -Path $OutputPath -ChildPath "LabelDistribution_$timestamp.csv"
    $outputFileSummary = Join-Path -Path $OutputPath -ChildPath "LabelCoverage_Summary_$timestamp.txt"
    $outputFileUnlabeled = Join-Path -Path $OutputPath -ChildPath "UnlabeledSensitiveContent_$timestamp.csv"

    $labelCoverageDetails | Export-Csv -Path $outputFileCoverage -NoTypeInformation -Encoding UTF8
    $labelDistributionReport | Export-Csv -Path $outputFileDist -NoTypeInformation -Encoding UTF8
    if ($unlabeledSensitiveContent.Count -gt 0) {
        $unlabeledSensitiveContent | Export-Csv -Path $outputFileUnlabeled -NoTypeInformation -Encoding UTF8
    }

    @(
        "AssessmentDate=$($summary.AssessmentDate)",
        "TotalDocumentsScanned=$($summary.TotalDocumentsScanned)",
        "LabeledDocuments=$($summary.LabeledDocuments)",
        "UnlabeledDocuments=$($summary.UnlabeledDocuments)",
        "LabelCoveragePercent=$($summary.LabelCoveragePercent)",
        "AutoLabeledDocuments=$($summary.AutoLabeledDocuments)",
        "AutoLabelPercent=$($summary.AutoLabelPercent)",
        "UniqueLabelTypes=$($summary.UniqueLabelTypes)",
        "UnlabeledSensitiveContent=$($summary.UnlabeledSensitiveContent)",
        "ReadinessRating=$($summary.ReadinessRating)"
    ) | Set-Content -Path $outputFileSummary -Encoding UTF8

    Write-CRLog -Level Success -Message "Label coverage assessment complete. Documents=$totalDocuments, Coverage=$labelCoveragePercent%"

    return [PSCustomObject]@{
        Name                = 'LabelCoverage'
        Summary             = $summary
        Findings            = $labelCoverageDetails
        LabelDistribution   = $labelDistributionReport
        UnlabeledSensitive  = $unlabeledSensitiveContent
        RawCsvPaths         = @{
            Coverage          = $outputFileCoverage
            Distribution      = $outputFileDist
            Summary           = $outputFileSummary
            UnlabeledSensitive = if ($unlabeledSensitiveContent.Count -gt 0) { $outputFileUnlabeled } else { $null }
        }
        ReadinessScore      = $labelCoveragePercent
        ReadinessRating     = $readinessRating
    }
}

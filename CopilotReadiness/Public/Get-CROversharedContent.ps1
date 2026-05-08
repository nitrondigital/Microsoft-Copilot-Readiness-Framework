function Get-CROversharedContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [switch]$IncludeOneDrive,

        [int]$SampleSize = 100
    )

    if (-not $script:CRState.Connected) {
        throw 'No Graph connection found. Run Connect-CRTenant first.'
    }

    if (-not (Test-Path -Path $OutputPath)) {
        $null = New-Item -ItemType Directory -Path $OutputPath -Force
    }

    $groupMemberCountCache = @{}

    $getGroupMemberCount = {
        param([string]$GroupId)

        if ([string]::IsNullOrWhiteSpace($GroupId)) {
            return 0
        }

        if ($groupMemberCountCache.ContainsKey($GroupId)) {
            return $groupMemberCountCache[$GroupId]
        }

        try {
            $count = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members/`$count" -Headers @{ ConsistencyLevel = 'eventual' } -OutputType PSObject
            $groupMemberCountCache[$GroupId] = [int]$count
            return [int]$count
        }
        catch {
            Write-CRLog -Level Warning -Message "Unable to count members for group $GroupId. $($_.Exception.Message)"
            $groupMemberCountCache[$GroupId] = 0
            return 0
        }
    }

    $overSharingResults = @()

    Write-CRLog -Message 'Retrieving SharePoint sites for oversharing analysis via Microsoft Search API...'
    # GET /sites?search=* requires a real keyword (not wildcard) for delegated access.
    # GET /sites (list all) requires application permissions — delegated not supported.
    # POST /search/query with entityTypes=["site"] supports delegated Sites.Read.All.
    # Ref: https://learn.microsoft.com/graph/api/search-query
    $sites = @(Get-CRSitesList)

    if (-not $IncludeOneDrive) {
        $sites = @($sites | Where-Object { $_.webUrl -notlike '*-my.sharepoint.com/personal/*' })
    }

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
            $fileItems = New-Object System.Collections.Generic.List[object]

            $enumerateChildren = {
                param(
                    [string]$DriveId,
                    [string]$ItemId
                )

                if ($SampleSize -gt 0 -and $fileItems.Count -ge $SampleSize) {
                    return
                }

                $childrenUri = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId/children?`$select=id,name,webUrl,file,folder,lastModifiedDateTime&`$top=200"
                $children = @()
                try {
                    $children = Get-CRGraphPaged -Uri $childrenUri
                }
                catch {
                    Write-CRLog -Level Warning -Message "Unable to enumerate child items in drive $DriveId. $($_.Exception.Message)"
                    return
                }

                foreach ($child in $children) {
                    # Use Get-CRSafeProperty to handle both PSCustomObject and Hashtable responses
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
                $permissions = @()
                try {
                    $permissions = Get-CRGraphPaged -Uri "https://graph.microsoft.com/v1.0/drives/$($drive.id)/items/$($item.id)/permissions?`$top=200"
                }
                catch {
                    Write-CRLog -Level Warning -Message "Skipping permission check for item $($item.webUrl). $($_.Exception.Message)"
                    continue
                }

                foreach ($permission in $permissions) {
                    $permLink = Get-CRSafeProperty $permission 'link'
                    $linkScope = Get-CRSafeProperty $permLink 'scope'
                    if ($linkScope -eq 'anonymous') {
                        $overSharingResults += [PSCustomObject]@{
                            SiteUrl       = $site.webUrl
                            SiteTitle     = $site.displayName
                            LibraryName   = $drive.name
                            ItemName      = $item.name
                            ItemPath      = $item.webUrl
                            SharedWith    = 'Anonymous Link'
                            MemberType    = 'Anonymous'
                            RiskLevel     = 'Critical'
                            RiskReason    = 'Anyone with link can access'
                            LastModified  = $item.lastModifiedDateTime
                        }
                    }

                    $principalSet = @()
                    $grantedToV2 = Get-CRSafeProperty $permission 'grantedToV2'
                    if ($null -ne $grantedToV2) {
                        $principalSet += $grantedToV2
                    }
                    $grantedToIdentitiesV2 = Get-CRSafeProperty $permission 'grantedToIdentitiesV2'
                    if ($null -ne $grantedToIdentitiesV2) {
                        $principalSet += @($grantedToIdentitiesV2)
                    }

                    foreach ($principal in $principalSet) {
                        $riskLevel = 'Low'
                        $riskReason = ''
                        $sharedWith = 'Unknown'
                        $memberType = 'Unknown'

                        $pSiteGroup = Get-CRSafeProperty $principal 'siteGroup'
                        $pGroup     = Get-CRSafeProperty $principal 'group'
                        $pUser      = Get-CRSafeProperty $principal 'user'
                        $pSiteUser  = Get-CRSafeProperty $principal 'siteUser'

                        if ($null -ne $pSiteGroup) {
                            $sharedWith = [string](Get-CRSafeProperty $pSiteGroup 'displayName')
                            $memberType = 'SiteGroup'

                            if ($sharedWith -like '*Everyone except external users*') {
                                $riskLevel = 'High'
                                $riskReason = 'Shared with Everyone except external users'
                            }
                            elseif ($sharedWith -like '*Everyone*') {
                                $riskLevel = 'Critical'
                                $riskReason = 'Shared with Everyone group'
                            }
                        }
                        elseif ($null -ne $pGroup) {
                            $sharedWith = [string](Get-CRSafeProperty $pGroup 'displayName')
                            $memberType = 'SecurityGroup'

                            $groupCount = & $getGroupMemberCount ([string](Get-CRSafeProperty $pGroup 'id'))
                            if ($groupCount -gt 500) {
                                $riskLevel = 'Medium'
                                $riskReason = "Shared with large security group ($groupCount members)"
                            }
                        }
                        elseif ($null -ne $pUser) {
                            $userEmail   = [string](Get-CRSafeProperty $pUser 'email')
                            $userDisplay = [string](Get-CRSafeProperty $pUser 'displayName')
                            $sharedWith  = if ([string]::IsNullOrWhiteSpace($userEmail)) { $userDisplay } else { $userEmail }
                            $memberType  = 'User'
                        }
                        elseif ($null -ne $pSiteUser) {
                            $suEmail   = [string](Get-CRSafeProperty $pSiteUser 'email')
                            $suDisplay = [string](Get-CRSafeProperty $pSiteUser 'displayName')
                            $sharedWith = if ([string]::IsNullOrWhiteSpace($suEmail)) { $suDisplay } else { $suEmail }
                            $memberType = 'SiteUser'
                        }

                        if ($riskLevel -ne 'Low') {
                            $overSharingResults += [PSCustomObject]@{
                                SiteUrl       = $site.webUrl
                                SiteTitle     = $site.displayName
                                LibraryName   = $drive.name
                                ItemName      = $item.name
                                ItemPath      = $item.webUrl
                                SharedWith    = $sharedWith
                                MemberType    = $memberType
                                RiskLevel     = $riskLevel
                                RiskReason    = $riskReason
                                LastModified  = $item.lastModifiedDateTime
                            }
                        }
                    }
                }
            }
        }
    }

    $criticalCount = @($overSharingResults | Where-Object { $_.RiskLevel -eq 'Critical' }).Count
    $highCount = @($overSharingResults | Where-Object { $_.RiskLevel -eq 'High' }).Count
    $mediumCount = @($overSharingResults | Where-Object { $_.RiskLevel -eq 'Medium' }).Count

    $readinessScore = [Math]::Max(0, 100 - ($criticalCount * 20) - ($highCount * 10) - ($mediumCount * 5))
    $readinessRating = Get-CRReadinessRating -Score $readinessScore

    $summary = [PSCustomObject]@{
        AssessmentDate            = Get-Date
        TotalOversharingInstances = $overSharingResults.Count
        CriticalRisk              = $criticalCount
        HighRisk                  = $highCount
        MediumRisk                = $mediumCount
        ReadinessRating           = $readinessRating
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outputFile = Join-Path -Path $OutputPath -ChildPath "OversharedContent_$timestamp.csv"
    $summaryFile = Join-Path -Path $OutputPath -ChildPath "OversharedContent_Summary_$timestamp.txt"

    $overSharingResults | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

    @(
        "AssessmentDate=$($summary.AssessmentDate)",
        "TotalOversharingInstances=$($summary.TotalOversharingInstances)",
        "CriticalRisk=$($summary.CriticalRisk)",
        "HighRisk=$($summary.HighRisk)",
        "MediumRisk=$($summary.MediumRisk)",
        "ReadinessRating=$($summary.ReadinessRating)"
    ) | Set-Content -Path $summaryFile -Encoding UTF8

    Write-CRLog -Level Success -Message "Overshared content assessment complete. Total=$($summary.TotalOversharingInstances), Critical=$criticalCount"

    return [PSCustomObject]@{
        Name            = 'OversharedContent'
        Summary         = $summary
        Findings        = $overSharingResults
        RawCsvPaths     = @{
            OversharedContent = $outputFile
            Summary           = $summaryFile
        }
        ReadinessScore  = $readinessScore
        ReadinessRating = $readinessRating
    }
}

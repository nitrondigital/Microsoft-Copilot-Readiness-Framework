function Get-CRSitesList {
    <#
    .SYNOPSIS
        Enumerates SharePoint sites using the Microsoft Search API (POST /search/query).
    .DESCRIPTION
        Uses POST /search/query with entityTypes=["site"] and queryString="*" which supports
        delegated Sites.Read.All without requiring application permissions.

        NOTE: GET /sites?search=* (site-search API) requires an actual keyword, not a wildcard.
              GET /sites (list all) requires application permissions — delegated NOT supported.
              GET /sites/getAllSites requires application permissions — delegated NOT supported.
              POST /search/query with entityTypes=["site"] supports delegated Sites.Read.All.
        Ref: https://learn.microsoft.com/graph/api/search-query
    .PARAMETER PageSize
        Number of results per search page (max 500).
    .PARAMETER MaxSites
        Maximum total sites to return. 0 = unlimited.
    #>
    [CmdletBinding()]
    param(
        [int]$PageSize = 500,
        [int]$MaxSites = 0
    )

    $allSites = [System.Collections.Generic.List[object]]::new()
    $from = 0
    $moreAvailable = $true

    while ($moreAvailable) {
        $requestBody = @{
            requests = @(
                @{
                    entityTypes = @('site')
                    query       = @{ queryString = '*' }
                    from        = $from
                    size        = $PageSize
                    fields      = @('id', 'name', 'displayName', 'webUrl', 'description', 'createdDateTime', 'lastModifiedDateTime')
                }
            )
        } | ConvertTo-Json -Depth 5

        try {
            $response = Invoke-MgGraphRequest -Method POST `
                -Uri 'https://graph.microsoft.com/v1.0/search/query' `
                -Body $requestBody `
                -ContentType 'application/json' `
                -OutputType PSObject
        }
        catch {
            Write-CRLog -Level Warning -Message "Microsoft Search API site enumeration failed (from=$from): $($_.Exception.Message)"
            break
        }

        # Response structure: .value[0].hitsContainers[0]
        $container = $null
        if ($response.PSObject.Properties['value']) {
            $firstResult = @($response.value)[0]
            if ($null -ne $firstResult -and $firstResult.PSObject.Properties['hitsContainers']) {
                $containers = @($firstResult.hitsContainers)
                if ($containers.Count -gt 0) {
                    $container = $containers[0]
                }
            }
        }

        if ($null -eq $container) {
            Write-CRLog -Level Warning -Message 'Microsoft Search API returned unexpected response structure during site enumeration.'
            break
        }

        $hits = if ($container.PSObject.Properties['hits']) { @($container.hits) } else { @() }

        foreach ($hit in $hits) {
            if ($hit.PSObject.Properties['resource']) {
                $siteResource = $hit.resource
                # Ensure the id property is populated — fall back to hitId if needed
                if ($null -ne $siteResource -and (-not $siteResource.PSObject.Properties['id'] -or [string]::IsNullOrWhiteSpace($siteResource.id))) {
                    if ($hit.PSObject.Properties['hitId'] -and -not [string]::IsNullOrWhiteSpace($hit.hitId)) {
                        $siteResource | Add-Member -NotePropertyName 'id' -NotePropertyValue $hit.hitId -Force
                    }
                }
                if ($null -ne $siteResource) {
                    $allSites.Add($siteResource)
                }
            }

            if ($MaxSites -gt 0 -and $allSites.Count -ge $MaxSites) {
                $moreAvailable = $false
                break
            }
        }

        if ($hits.Count -eq 0) {
            break
        }

        $moreAvailable = if ($container.PSObject.Properties['moreResultsAvailable']) {
            [bool]$container.moreResultsAvailable
        }
        else {
            $false
        }

        $from += $PageSize
    }

    # Fallback: root site + direct subsites if Search API returned nothing
    if ($allSites.Count -eq 0) {
        Write-CRLog -Level Warning -Message 'Search API returned no sites. Falling back to root site and direct subsites.'
        try {
            $rootSite = Invoke-MgGraphRequest -Method GET `
                -Uri 'https://graph.microsoft.com/v1.0/sites/root' `
                -OutputType PSObject
            if ($null -ne $rootSite) {
                $allSites.Add($rootSite)
                $subSites = @(Get-CRGraphPaged -Uri "https://graph.microsoft.com/v1.0/sites/$($rootSite.id)/sites")
                foreach ($s in $subSites) { $allSites.Add($s) }
            }
        }
        catch {
            Write-CRLog -Level Warning -Message "Root site fallback also failed: $($_.Exception.Message)"
        }
    }

    Write-CRLog -Message "Site enumeration complete. Found $($allSites.Count) site(s)."
    return $allSites.ToArray()
}

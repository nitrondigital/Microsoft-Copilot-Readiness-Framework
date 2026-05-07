function Get-CRGraphPaged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [ValidateSet('GET', 'POST')]
        [string]$Method = 'GET',

        [hashtable]$Headers,

        [object]$Body
    )

    $results = @()
    $nextUri = $Uri

    while (-not [string]::IsNullOrWhiteSpace($nextUri)) {
        try {
            if ($PSBoundParameters.ContainsKey('Body')) {
                $response = Invoke-MgGraphRequest -Method $Method -Uri $nextUri -Headers $Headers -Body $Body -OutputType PSObject
            }
            else {
                $response = Invoke-MgGraphRequest -Method $Method -Uri $nextUri -Headers $Headers -OutputType PSObject
            }
        }
        catch {
            Write-CRLog -Level Error -Message "Graph request failed: $nextUri. $($_.Exception.Message)"
            throw
        }

        if ($null -ne $response.PSObject.Properties['value']) {
            $results += @($response.value)
            # Safe access required — strict mode throws if property is absent (last page)
            $nextUri = if ($response.PSObject.Properties['@odata.nextLink']) { $response.'@odata.nextLink' } else { $null }
        }
        else {
            $results += $response
            $nextUri = $null
        }
    }

    return $results
}

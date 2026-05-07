function Invoke-CRAssessment {
    [CmdletBinding()]
    param(
        [ValidateSet('CAPolicies', 'ExternalUserAccess', 'LabelCoverage', 'OversharedContent')]
        [string[]]$Assessments = @('CAPolicies', 'ExternalUserAccess', 'LabelCoverage', 'OversharedContent'),

        [Parameter(Mandatory)]
        [string]$TenantUrl,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [switch]$IncludeOneDrive,

        [int]$SampleSize = 100,

        [switch]$CheckCopilotApps
    )

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        throw 'OutputPath is required.'
    }

    if (-not (Test-Path -Path $OutputPath)) {
        $null = New-Item -Path $OutputPath -ItemType Directory -Force
    }

    if (-not $script:CRState.Connected -or $script:CRState.TenantUrl -ne $TenantUrl.Trim().TrimEnd('/')) {
        Connect-CRTenant -TenantUrl $TenantUrl | Out-Null
    }

    $results = @{}

    foreach ($assessment in $Assessments) {
        Write-CRLog -Message "Starting assessment: $assessment"

        try {
            switch ($assessment) {
                'CAPolicies' {
                    $results[$assessment] = Get-CRCAPolicyAssessment -OutputPath $OutputPath -CheckCopilotApps:$CheckCopilotApps
                }
                'ExternalUserAccess' {
                    $results[$assessment] = Get-CRExternalUserAccess -OutputPath $OutputPath
                }
                'LabelCoverage' {
                    $results[$assessment] = Get-CRLabelCoverage -OutputPath $OutputPath -IncludeOneDrive:$IncludeOneDrive -SampleSize $SampleSize
                }
                'OversharedContent' {
                    $results[$assessment] = Get-CROversharedContent -OutputPath $OutputPath -IncludeOneDrive:$IncludeOneDrive -SampleSize $SampleSize
                }
            }

            Write-CRLog -Level Success -Message "Completed assessment: $assessment"
        }
        catch {
            Write-CRLog -Level Error -Message "Assessment failed ($assessment): $($_.Exception.Message)"
            $results[$assessment] = [pscustomobject]@{
                Name            = $assessment
                Error           = $_.Exception.Message
                Summary         = $null
                Findings        = @()
                RawCsvPaths     = @{}
                ReadinessScore  = 0
                ReadinessRating = 'Not Ready'
            }
        }
    }

    $script:CRLastResults = $results
    return $results
}

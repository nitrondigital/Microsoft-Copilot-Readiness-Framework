function Write-CRLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$timestamp] [$Level] $Message"

    if (-not $script:CRLogBuffer) {
        $script:CRLogBuffer = [System.Collections.Generic.List[string]]::new()
    }

    $script:CRLogBuffer.Add($line)

    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        default { 'Gray' }
    }

    Write-Host $line -ForegroundColor $color

    if ($null -ne $script:CRLogSink -and $script:CRLogSink -is [scriptblock]) {
        try {
            & $script:CRLogSink $line
        }
        catch {
            # Ignore sink failures to keep logging resilient.
        }
    }
}

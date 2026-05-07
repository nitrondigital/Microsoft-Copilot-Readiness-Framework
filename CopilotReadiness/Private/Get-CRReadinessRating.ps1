function Get-CRReadinessRating {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$Score
    )

    if ($Score -ge 80) {
        return 'Ready'
    }

    if ($Score -ge 60) {
        return 'Nearly Ready'
    }

    if ($Score -ge 40) {
        return 'Requires Work'
    }

    return 'Not Ready'
}

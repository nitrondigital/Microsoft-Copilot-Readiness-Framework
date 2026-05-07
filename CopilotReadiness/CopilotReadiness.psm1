Set-StrictMode -Version Latest

if (-not (Get-Variable -Name CRState -Scope Script -ErrorAction SilentlyContinue)) {
    $script:CRState = [ordered]@{
        Connected          = $false
        TenantUrl          = $null
        TenantShortName    = $null
        TenantDomain       = $null
        TenantId           = $null
        OrganizationName   = $null
        ConnectedUser      = $null
        ConnectedAt        = $null
        Scopes             = @()
        ConnectedServices  = @()
    }
}

if (-not (Get-Variable -Name CRLogBuffer -Scope Script -ErrorAction SilentlyContinue)) {
    $script:CRLogBuffer = [System.Collections.Generic.List[string]]::new()
}

if (-not (Get-Variable -Name CRLogSink -Scope Script -ErrorAction SilentlyContinue)) {
    $script:CRLogSink = $null
}

if (-not (Get-Variable -Name CRLastResults -Scope Script -ErrorAction SilentlyContinue)) {
    $script:CRLastResults = $null
}

if (-not (Get-Variable -Name CRLastReportPath -Scope Script -ErrorAction SilentlyContinue)) {
    $script:CRLastReportPath = $null
}

$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'

Get-ChildItem -Path $privatePath -Filter '*.ps1' -File |
    Sort-Object -Property Name |
    ForEach-Object { . $_.FullName }

Get-ChildItem -Path $publicPath -Filter '*.ps1' -File |
    Sort-Object -Property Name |
    ForEach-Object { . $_.FullName }

$functionsToExport = Get-ChildItem -Path $publicPath -Filter '*.ps1' -File |
    ForEach-Object { $_.BaseName }

Export-ModuleMember -Function $functionsToExport

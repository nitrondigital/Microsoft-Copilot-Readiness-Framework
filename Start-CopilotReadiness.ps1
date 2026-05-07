#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

$moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath 'CopilotReadiness'
$moduleManifest = Join-Path -Path $moduleRoot -ChildPath 'CopilotReadiness.psd1'

if (-not (Test-Path -Path $moduleManifest)) {
    throw "Module manifest was not found: $moduleManifest"
}

Import-Module -Name $moduleManifest -Force
Show-CRGui

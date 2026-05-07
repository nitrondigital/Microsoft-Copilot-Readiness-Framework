# Install-Prerequisites.ps1
# Checks and installs required PowerShell modules for the Copilot Readiness Framework
# Created by: Nitron Digital LLC

#Requires -Version 5.1

$requiredModules = @(
    @{
        Name        = "Microsoft.Online.SharePoint.PowerShell"
        Description = "SharePoint Online Management Shell (Get-OversharedContent, Get-LabelCoverage, Get-ExternalUserAccess)"
        MinVersion  = "16.0.0"
    },
    @{
        Name        = "PnP.PowerShell"
        Description = "PnP PowerShell (Get-OversharedContent, Get-LabelCoverage, Get-ExternalUserAccess)"
        MinVersion  = "2.0.0"
    },
    @{
        Name        = "Microsoft.Graph.Identity.SignIns"
        Description = "Microsoft Graph - Identity & Sign-Ins (Get-CAPolicies)"
        MinVersion  = "2.0.0"
    },
    @{
        Name        = "Microsoft.Graph.Users"
        Description = "Microsoft Graph - Users (Get-CAPolicies)"
        MinVersion  = "2.0.0"
    }
)

function Test-ModuleInstalled {
    param(
        [string]$Name,
        [string]$MinVersion
    )
    $installed = Get-Module -ListAvailable -Name $Name |
                 Sort-Object Version -Descending |
                 Select-Object -First 1
    if (-not $installed) { return $false }
    if ([version]$installed.Version -ge [version]$MinVersion) { return $true }
    return $false
}

Write-Host "`n=== Copilot Readiness Framework - Prerequisites Check ===" -ForegroundColor Cyan
Write-Host "Checking required PowerShell modules...`n" -ForegroundColor Cyan

# Check if running as admin (required for AllUsers scope install)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
$installScope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }
Write-Host "Install scope: $installScope $(if (-not $isAdmin) { '(run as Administrator to install for AllUsers)' })`n" -ForegroundColor Gray

$missing  = [System.Collections.Generic.List[hashtable]]::new()
$present  = [System.Collections.Generic.List[string]]::new()

foreach ($module in $requiredModules) {
    $installed = Test-ModuleInstalled -Name $module.Name -MinVersion $module.MinVersion
    if ($installed) {
        $ver = (Get-Module -ListAvailable -Name $module.Name | Sort-Object Version -Descending | Select-Object -First 1).Version
        Write-Host "  [OK]  $($module.Name) v$ver" -ForegroundColor Green
        Write-Host "        $($module.Description)" -ForegroundColor Gray
        $present.Add($module.Name)
    } else {
        Write-Host "  [--]  $($module.Name) (not installed / below minimum v$($module.MinVersion))" -ForegroundColor Yellow
        Write-Host "        $($module.Description)" -ForegroundColor Gray
        $missing.Add($module)
    }
}

if ($missing.Count -eq 0) {
    Write-Host "`nAll required modules are installed. You are ready to run the assessment scripts." -ForegroundColor Green
    exit 0
}

Write-Host "`n$($missing.Count) module(s) need to be installed:" -ForegroundColor Yellow
$missing | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }

$response = Read-Host "`nInstall missing modules now? [Y/N]"
if ($response -notmatch '^[Yy]') {
    Write-Host "Installation skipped. Re-run this script when ready." -ForegroundColor Gray
    exit 0
}

# Ensure PSGallery is trusted so installs don't prompt interactively
$gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
if ($gallery.InstallationPolicy -ne "Trusted") {
    Write-Host "`nSetting PSGallery as trusted repository..." -ForegroundColor Cyan
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

$failed = [System.Collections.Generic.List[string]]::new()

foreach ($module in $missing) {
    Write-Host "`nInstalling $($module.Name)..." -ForegroundColor Cyan
    try {
        Install-Module -Name $module.Name `
                       -Scope $installScope `
                       -MinimumVersion $module.MinVersion `
                       -AllowClobber `
                       -Force `
                       -ErrorAction Stop
        $ver = (Get-Module -ListAvailable -Name $module.Name | Sort-Object Version -Descending | Select-Object -First 1).Version
        Write-Host "  Installed $($module.Name) v$ver" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR installing $($module.Name): $_" -ForegroundColor Red
        $failed.Add($module.Name)
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Already installed : $($present.Count)" -ForegroundColor Green
Write-Host "Newly installed   : $($missing.Count - $failed.Count)" -ForegroundColor Green
if ($failed.Count -gt 0) {
    Write-Host "Failed            : $($failed.Count)" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "`nTry running this script as Administrator, or install failed modules manually:" -ForegroundColor Yellow
    $failed | ForEach-Object { Write-Host "  Install-Module $_ -Scope CurrentUser -Force" -ForegroundColor Yellow }
    exit 1
} else {
    Write-Host "`nAll prerequisites installed successfully. You are ready to run the assessment scripts." -ForegroundColor Green
    exit 0
}

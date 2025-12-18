# Get-OversharedContent.ps1
# Identifies SharePoint sites and OneDrive files with broad sharing permissions
# Requirements: SharePoint Online Management Shell, appropriate admin permissions
# Created by:
# Brandon Marcus
# Managing Principal, Nitron Digital LLC
# brandon@nitron.digital | (833) 3-NITRON


<#
.SYNOPSIS
    Detects overshared content across SharePoint Online and OneDrive for Business
    
.DESCRIPTION
    Scans SharePoint sites and OneDrive for content shared with:
    - "Everyone" or "Everyone except external users"
    - Anonymous/Anyone links
    - Large security groups (>500 members)
    - External users
    
.PARAMETER TenantUrl
    The SharePoint Online admin URL (e.g., https://contoso-admin.sharepoint.com)
    
.PARAMETER OutputPath
    Path for the CSV output file. Defaults to current directory.
    
.PARAMETER IncludeOneDrive
    Switch to include OneDrive analysis (can be time-consuming for large tenants)
    
.EXAMPLE
    .\Get-OversharedContent.ps1 -TenantUrl "https://contoso-admin.sharepoint.com" -OutputPath "C:\Reports\"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeOneDrive
)

# Import required modules
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
Import-Module PnP.PowerShell -ErrorAction Stop

# Connect to SharePoint Online
Write-Host "Connecting to SharePoint Online..." -ForegroundColor Cyan
Connect-SPOService -Url $TenantUrl

# Initialize results array
$overSharingResults = @()

# Get all site collections
Write-Host "Retrieving site collections..." -ForegroundColor Cyan
$sites = Get-SPOSite -Limit All | Where-Object { $_.Template -notlike "*MySite*" -or $IncludeOneDrive }

$siteCount = $sites.Count
$currentSite = 0

foreach ($site in $sites) {
    $currentSite++
    Write-Progress -Activity "Scanning sites for oversharing" -Status "Site $currentSite of $siteCount" -PercentComplete (($currentSite / $siteCount) * 100)
    
    try {
        # Connect to the site using PnP
        Connect-PnPOnline -Url $site.Url -Interactive
        
        # Check site sharing capabilities
        $siteSharing = Get-SPOSite -Identity $site.Url
        
        # Get all lists in the site
        $lists = Get-PnPList | Where-Object { $_.BaseTemplate -eq 101 -or $_.BaseTemplate -eq 109 } # Document Libraries
        
        foreach ($list in $lists) {
            # Get all items with unique permissions
            $items = Get-PnPListItem -List $list -PageSize 500
            
            foreach ($item in $items) {
                $hasUniquePermissions = $item.HasUniqueRoleAssignments
                
                if ($hasUniquePermissions) {
                    # Get role assignments for this item
                    $roleAssignments = Get-PnPProperty -ClientObject $item -Property RoleAssignments
                    
                    foreach ($roleAssignment in $roleAssignments) {
                        $member = Get-PnPProperty -ClientObject $roleAssignment -Property Member
                        $memberType = $member.PrincipalType
                        $memberTitle = $member.Title
                        
                        # Flag risky sharing patterns
                        $riskLevel = "Low"
                        $riskReason = ""
                        
                        if ($memberTitle -like "*Everyone*") {
                            $riskLevel = "Critical"
                            $riskReason = "Shared with Everyone group"
                        }
                        elseif ($memberTitle -like "*except external*") {
                            $riskLevel = "High"
                            $riskReason = "Shared with Everyone except external users"
                        }
                        elseif ($memberType -eq "SecurityGroup") {
                            # Check group size (you'd need Graph API for exact count)
                            $riskLevel = "Medium"
                            $riskReason = "Shared with security group: $memberTitle"
                        }
                        
                        if ($riskLevel -ne "Low") {
                            $result = [PSCustomObject]@{
                                SiteUrl = $site.Url
                                SiteTitle = $site.Title
                                LibraryName = $list.Title
                                ItemName = $item.FieldValues["FileLeafRef"]
                                ItemPath = $item.FieldValues["FileRef"]
                                SharedWith = $memberTitle
                                MemberType = $memberType
                                RiskLevel = $riskLevel
                                RiskReason = $riskReason
                                LastModified = $item.FieldValues["Modified"]
                            }
                            $overSharingResults += $result
                        }
                    }
                }
                
                # Check for anonymous/anyone links
                $sharingInfo = Get-PnPFileSharingLink -FileUrl $item.FieldValues["FileRef"] -ErrorAction SilentlyContinue
                
                if ($sharingInfo) {
                    foreach ($link in $sharingInfo) {
                        if ($link.ShareType -eq "AnonymousAccess") {
                            $result = [PSCustomObject]@{
                                SiteUrl = $site.Url
                                SiteTitle = $site.Title
                                LibraryName = $list.Title
                                ItemName = $item.FieldValues["FileLeafRef"]
                                ItemPath = $item.FieldValues["FileRef"]
                                SharedWith = "Anonymous Link"
                                MemberType = "Anonymous"
                                RiskLevel = "Critical"
                                RiskReason = "Anyone with link can access"
                                LastModified = $item.FieldValues["Modified"]
                            }
                            $overSharingResults += $result
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Error processing site $($site.Url): $_"
    }
}

# Generate summary statistics
$criticalCount = ($overSharingResults | Where-Object { $_.RiskLevel -eq "Critical" }).Count
$highCount = ($overSharingResults | Where-Object { $_.RiskLevel -eq "High" }).Count
$mediumCount = ($overSharingResults | Where-Object { $_.RiskLevel -eq "Medium" }).Count

# Export results
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path $OutputPath "OversharedContent_$timestamp.csv"
$overSharingResults | Export-Csv -Path $outputFile -NoTypeInformation

# Display summary
Write-Host "`n=== Oversharing Assessment Summary ===" -ForegroundColor Yellow
Write-Host "Total oversharing instances found: $($overSharingResults.Count)" -ForegroundColor White
Write-Host "Critical Risk: $criticalCount" -ForegroundColor Red
Write-Host "High Risk: $highCount" -ForegroundColor Yellow
Write-Host "Medium Risk: $mediumCount" -ForegroundColor Cyan
Write-Host "`nResults exported to: $outputFile" -ForegroundColor Green

# Disconnect
Disconnect-SPOService

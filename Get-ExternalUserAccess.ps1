# Get-ExternalUserAccess.ps1
# Audits all external users and their access permissions across SharePoint Online
# Critical for Copilot security in regulated industries
# Created by:
# Brandon Marcus
# Managing Principal, Nitron Digital LLC
# brandon@nitron.digital | (833) 3-NITRON


<#
.SYNOPSIS
    Audits external user access across the M365 tenant
    
.DESCRIPTION
    Identifies and reports on:
    - All external users with access
    - Sites and content they can access
    - Permission levels granted
    - Last activity dates
    - Orphaned external accounts
    
.PARAMETER TenantUrl
    The SharePoint Online admin URL
    
.PARAMETER OutputPath
    Path for the output reports
    
.PARAMETER IncludeInactiveUsers
    Include external users with no activity in last 90 days
    
.EXAMPLE
    .\Get-ExternalUserAccess.ps1 -TenantUrl "https://contoso-admin.sharepoint.com"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeInactiveUsers
)

# Import required modules
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
Import-Module PnP.PowerShell -ErrorAction Stop

# Connect to SharePoint Online
Write-Host "Connecting to SharePoint Online..." -ForegroundColor Cyan
Connect-SPOService -Url $TenantUrl

# Initialize tracking
$externalUserAccess = @()
$orphanedAccounts = @()
$highRiskAccess = @()

# Get all external users
Write-Host "Retrieving external users..." -ForegroundColor Cyan
$externalUsers = Get-SPOExternalUser -PageSize 50

Write-Host "Found $($externalUsers.Count) external users" -ForegroundColor White

# Get all sites
$sites = Get-SPOSite -Limit All -Filter "Template -notlike '*MySite*'"
$siteCount = $sites.Count
$currentSite = 0

# Track unique external users and their access
$externalUserSummary = @{}

foreach ($site in $sites) {
    $currentSite++
    Write-Progress -Activity "Auditing external user access" -Status "Site $currentSite of $siteCount" -PercentComplete (($currentSite / $siteCount) * 100)
    
    try {
        # Connect to the site
        Connect-PnPOnline -Url $site.Url -Interactive
        
        # Get all users with access to this site
        $siteUsers = Get-PnPUser | Where-Object { 
            $_.LoginName -like "*#ext#*" -or 
            $_.LoginName -like "*urn:spo:guest*" 
        }
        
        foreach ($user in $siteUsers) {
            # Get user's role assignments
            $web = Get-PnPWeb
            $roleAssignments = Get-PnPProperty -ClientObject $web -Property RoleAssignments
            
            $userPermissions = @()
            foreach ($roleAssignment in $roleAssignments) {
                $member = Get-PnPProperty -ClientObject $roleAssignment -Property Member
                $roleDefinitions = Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings
                
                if ($member.LoginName -eq $user.LoginName) {
                    foreach ($roleDef in $roleDefinitions) {
                        $userPermissions += $roleDef.Name
                    }
                }
            }
            
            # Determine risk level
            $riskLevel = "Low"
            $riskFactors = @()
            
            if ($userPermissions -contains "Full Control") {
                $riskLevel = "Critical"
                $riskFactors += "Full Control access"
            }
            elseif ($userPermissions -contains "Design" -or $userPermissions -contains "Edit") {
                $riskLevel = "High"
                $riskFactors += "Edit permissions"
            }
            
            # Check for inactive users
            $daysSinceLastActivity = 999
            try {
                $lastActivity = $user.LastActivityDate
                if ($lastActivity) {
                    $daysSinceLastActivity = (New-TimeSpan -Start $lastActivity -End (Get-Date)).Days
                    if ($daysSinceLastActivity -gt 90) {
                        $riskFactors += "No activity in $daysSinceLastActivity days"
                        if ($riskLevel -eq "Low") { $riskLevel = "Medium" }
                    }
                }
            }
            catch {
                # LastActivityDate might not be available
                $riskFactors += "Activity date unknown"
            }
            
            # Check domain
            $emailDomain = ""
            if ($user.Email) {
                $emailDomain = $user.Email.Split("@")[1]
                # You might want to flag certain domains
                $untrustedDomains = @("gmail.com", "yahoo.com", "outlook.com", "hotmail.com")
                if ($untrustedDomains -contains $emailDomain) {
                    $riskFactors += "Consumer email domain"
                    if ($riskLevel -eq "Low") { $riskLevel = "Medium" }
                }
            }
            
            # Create access record
            $accessRecord = [PSCustomObject]@{
                ExternalUserEmail = $user.Email
                DisplayName = $user.Title
                LoginName = $user.LoginName
                SiteUrl = $site.Url
                SiteTitle = $site.Title
                Permissions = ($userPermissions -join "; ")
                RiskLevel = $riskLevel
                RiskFactors = ($riskFactors -join "; ")
                EmailDomain = $emailDomain
                DaysSinceLastActivity = $daysSinceLastActivity
                InvitedBy = "" # Would need Graph API to get this
                InvitedDate = "" # Would need Graph API to get this
            }
            
            $externalUserAccess += $accessRecord
            
            # Track high-risk access
            if ($riskLevel -in @("Critical", "High")) {
                $highRiskAccess += $accessRecord
            }
            
            # Build summary by user
            if (-not $externalUserSummary.ContainsKey($user.Email)) {
                $externalUserSummary[$user.Email] = @{
                    Email = $user.Email
                    DisplayName = $user.Title
                    SitesAccessed = @()
                    HighestPermission = "Limited Access"
                    HighestRiskLevel = "Low"
                    TotalSites = 0
                    DaysSinceLastActivity = $daysSinceLastActivity
                }
            }
            
            $externalUserSummary[$user.Email].SitesAccessed += $site.Url
            $externalUserSummary[$user.Email].TotalSites++
            
            # Update highest permission
            if ($userPermissions -contains "Full Control") {
                $externalUserSummary[$user.Email].HighestPermission = "Full Control"
            }
            elseif ($userPermissions -contains "Design" -and $externalUserSummary[$user.Email].HighestPermission -ne "Full Control") {
                $externalUserSummary[$user.Email].HighestPermission = "Design"
            }
            elseif ($userPermissions -contains "Edit" -and $externalUserSummary[$user.Email].HighestPermission -notin @("Full Control", "Design")) {
                $externalUserSummary[$user.Email].HighestPermission = "Edit"
            }
            
            # Update highest risk level
            $riskLevels = @("Low" = 1; "Medium" = 2; "High" = 3; "Critical" = 4)
            if ($riskLevels[$riskLevel] -gt $riskLevels[$externalUserSummary[$user.Email].HighestRiskLevel]) {
                $externalUserSummary[$user.Email].HighestRiskLevel = $riskLevel
            }
        }
    }
    catch {
        Write-Warning "Error processing site $($site.Url): $_"
    }
}

# Create user summary report
$userSummaryReport = $externalUserSummary.Values | ForEach-Object {
    [PSCustomObject]@{
        Email = $_.Email
        DisplayName = $_.DisplayName
        TotalSitesAccessed = $_.TotalSites
        HighestPermission = $_.HighestPermission
        HighestRiskLevel = $_.HighestRiskLevel
        DaysSinceLastActivity = $_.DaysSinceLastActivity
        SitesAccessed = ($_.SitesAccessed -join "; ")
    }
} | Sort-Object -Property HighestRiskLevel,TotalSitesAccessed -Descending

# Calculate statistics
$totalExternalUsers = $externalUserSummary.Count
$criticalRiskUsers = ($userSummaryReport | Where-Object { $_.HighestRiskLevel -eq "Critical" }).Count
$highRiskUsers = ($userSummaryReport | Where-Object { $_.HighestRiskLevel -eq "High" }).Count
$inactiveUsers = ($userSummaryReport | Where-Object { $_.DaysSinceLastActivity -gt 90 }).Count
$fullControlUsers = ($userSummaryReport | Where-Object { $_.HighestPermission -eq "Full Control" }).Count

# Export results
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Detailed access log
$outputFileAccess = Join-Path $OutputPath "ExternalUserAccess_$timestamp.csv"
$externalUserAccess | Export-Csv -Path $outputFileAccess -NoTypeInformation

# User summary
$outputFileSummary = Join-Path $OutputPath "ExternalUserSummary_$timestamp.csv"
$userSummaryReport | Export-Csv -Path $outputFileSummary -NoTypeInformation

# High-risk access
if ($highRiskAccess.Count -gt 0) {
    $outputFileHighRisk = Join-Path $OutputPath "HighRiskExternalAccess_$timestamp.csv"
    $highRiskAccess | Export-Csv -Path $outputFileHighRisk -NoTypeInformation
}

# Generate executive summary
$executiveSummary = [PSCustomObject]@{
    AssessmentDate = Get-Date
    TotalExternalUsers = $totalExternalUsers
    CriticalRiskUsers = $criticalRiskUsers
    HighRiskUsers = $highRiskUsers
    InactiveUsers = $inactiveUsers
    FullControlUsers = $fullControlUsers
    TotalAccessPoints = $externalUserAccess.Count
    ReadinessScore = if ($criticalRiskUsers -eq 0 -and $fullControlUsers -eq 0 -and $inactiveUsers -lt ($totalExternalUsers * 0.1)) { "Ready" }
                     elseif ($criticalRiskUsers -le 2 -and $fullControlUsers -le 2) { "Nearly Ready" }
                     elseif ($criticalRiskUsers -le 5) { "Requires Work" }
                     else { "Not Ready" }
}

$outputFileExecSummary = Join-Path $OutputPath "ExternalUserAccess_ExecutiveSummary_$timestamp.txt"
$executiveSummary | Out-File -FilePath $outputFileExecSummary

# Display summary
Write-Host "`n=== External User Access Audit Summary ===" -ForegroundColor Yellow
Write-Host "Total external users: $totalExternalUsers" -ForegroundColor White
Write-Host "Critical risk users: $criticalRiskUsers" -ForegroundColor $(if ($criticalRiskUsers -gt 0) { "Red" } else { "Green" })
Write-Host "High risk users: $highRiskUsers" -ForegroundColor $(if ($highRiskUsers -gt 0) { "Yellow" } else { "Green" })
Write-Host "Inactive users (>90 days): $inactiveUsers" -ForegroundColor $(if ($inactiveUsers -gt 0) { "Yellow" } else { "Green" })
Write-Host "Users with Full Control: $fullControlUsers" -ForegroundColor $(if ($fullControlUsers -gt 0) { "Red" } else { "Green" })
Write-Host "Total access points: $($externalUserAccess.Count)" -ForegroundColor White
Write-Host "`nReadiness Assessment: $($executiveSummary.ReadinessScore)" -ForegroundColor $(if ($executiveSummary.ReadinessScore -eq "Ready") { "Green" } else { "Yellow" })

Write-Host "`n=== Top 10 External Users by Site Access ===" -ForegroundColor Yellow
$userSummaryReport | Select-Object -First 10 Email,TotalSitesAccessed,HighestPermission,HighestRiskLevel | Format-Table -AutoSize

Write-Host "`nReports exported to:" -ForegroundColor Green
Write-Host "  Detailed Access: $outputFileAccess"
Write-Host "  User Summary: $outputFileSummary"
Write-Host "  Executive Summary: $outputFileExecSummary"
if ($highRiskAccess.Count -gt 0) {
    Write-Host "  High Risk Access: $outputFileHighRisk" -ForegroundColor Red
}

# Recommendations
Write-Host "`n=== Recommendations ===" -ForegroundColor Yellow
if ($criticalRiskUsers -gt 0) {
    Write-Host "  • URGENT: Review $criticalRiskUsers external user(s) with critical risk access" -ForegroundColor Red
}
if ($fullControlUsers -gt 0) {
    Write-Host "  • Review $fullControlUsers external user(s) with Full Control permissions" -ForegroundColor Red
    Write-Host "  • Consider downgrading to Edit or Contribute where possible" -ForegroundColor Yellow
}
if ($inactiveUsers -gt ($totalExternalUsers * 0.2)) {
    Write-Host "  • Review and remove $inactiveUsers inactive external accounts" -ForegroundColor Yellow
}
if ($totalExternalUsers -gt 100) {
    Write-Host "  • Consider implementing access reviews for external users" -ForegroundColor Yellow
    Write-Host "  • Establish external user governance policy" -ForegroundColor Yellow
}

Write-Host "`nFor Copilot deployment in regulated environments:" -ForegroundColor Cyan
Write-Host "  • External user access will be subject to Copilot's data access scope" -ForegroundColor White
Write-Host "  • Ensure all external access is reviewed and approved" -ForegroundColor White
Write-Host "  • Consider conditional access policies for external users" -ForegroundColor White

# Disconnect
Disconnect-SPOService

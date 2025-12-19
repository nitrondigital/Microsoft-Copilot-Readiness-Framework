# Get-CAPolicies.ps1
# Reviews conditional access policies for Microsoft Copilot compatibility
# Ensures Zero Trust controls don't block Copilot functionality
# Created by:
# Brandon Marcus
# Managing Principal, Nitron Digital LLC
# brandon@nitron.digital | (833) 3-NITRON

<#
.SYNOPSIS
    Audits Conditional Access policies for Copilot readiness
    
.DESCRIPTION
    Analyzes CA policies to ensure:
    - Appropriate controls for AI driven tools
    - No blocking configurations for Copilot apps
    - MFA enforcement
    - Device compliance requirements
    - Location-based restrictions compatibility
    
.PARAMETER OutputPath
    Path for the output report
    
.PARAMETER CheckCopilotApps
    Verify policies don't block Copilot cloud app IDs
    
.EXAMPLE
    .\Get-CAPolicies.ps1 -OutputPath "C:\Reports\" -CheckCopilotApps
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\",
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckCopilotApps
)

# Import required modules
Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Policy.Read.All", "Directory.Read.All", "User.Read.All"

# Microsoft Copilot related app IDs
$copilotAppIds = @(
    "0ec893e0-5785-4de6-99da-4ed124e5296c",  # Microsoft 365 Copilot
    "b1831b8b-e4f8-41f4-99d9-b0d8e0e5a4b5",  # Copilot for Microsoft 365 (example)
    "00000003-0000-0000-c000-000000000000"   # Microsoft Graph (required for Copilot)
)

# Initialize tracking
$policyAnalysis = @()
$copilotCompatibilityIssues = @()
$recommendedPolicies = @()

# Get all Conditional Access policies
Write-Host "Retrieving Conditional Access policies..." -ForegroundColor Cyan
$policies = Get-MgIdentityConditionalAccessPolicy

Write-Host "Found $($policies.Count) Conditional Access policies" -ForegroundColor White

foreach ($policy in $policies) {
    Write-Host "Analyzing policy: $($policy.DisplayName)" -ForegroundColor Gray
    
    # Initialize policy assessment
    $assessment = [PSCustomObject]@{
        PolicyName = $policy.DisplayName
        PolicyId = $policy.Id
        State = $policy.State
        CreatedDateTime = $policy.CreatedDateTime
        ModifiedDateTime = $policy.ModifiedDateTime
        
        # Assignments
        AppliesTo = ""
        IncludeUsers = ""
        ExcludeUsers = ""
        IncludeGroups = ""
        ExcludeGroups = ""
        IncludeApplications = ""
        ExcludeApplications = ""
        
        # Conditions
        UserRiskLevels = ""
        SignInRiskLevels = ""
        Platforms = ""
        Locations = ""
        ClientAppTypes = ""
        
        # Grant Controls
        GrantControlOperator = ""
        GrantControls = ""
        RequiresMFA = $false
        RequiresCompliantDevice = $false
        RequiresHybridJoin = $false
        RequiresPasswordChange = $false
        
        # Session Controls
        SessionControls = ""
        
        # Copilot Compatibility
        BlocksCopilotApps = $false
        CopilotCompatibilityScore = 0
        CompatibilityIssues = ""
        Recommendations = ""
    }
    
    # Analyze Assignments
    if ($policy.Conditions.Users.IncludeUsers -contains "All") {
        $assessment.AppliesTo = "All Users"
    } elseif ($policy.Conditions.Users.IncludeUsers) {
        $assessment.AppliesTo = "Specific Users"
        $assessment.IncludeUsers = ($policy.Conditions.Users.IncludeUsers -join "; ")
    }
    
    if ($policy.Conditions.Users.ExcludeUsers) {
        $assessment.ExcludeUsers = ($policy.Conditions.Users.ExcludeUsers -join "; ")
    }
    
    if ($policy.Conditions.Users.IncludeGroups) {
        $assessment.IncludeGroups = ($policy.Conditions.Users.IncludeGroups -join "; ")
    }
    
    if ($policy.Conditions.Users.ExcludeGroups) {
        $assessment.ExcludeGroups = ($policy.Conditions.Users.ExcludeGroups -join "; ")
    }
    
    # Analyze Applications
    if ($policy.Conditions.Applications.IncludeApplications -contains "All") {
        $assessment.IncludeApplications = "All Apps"
    } elseif ($policy.Conditions.Applications.IncludeApplications) {
        $assessment.IncludeApplications = ($policy.Conditions.Applications.IncludeApplications -join "; ")
    }
    
    if ($policy.Conditions.Applications.ExcludeApplications) {
        $assessment.ExcludeApplications = ($policy.Conditions.Applications.ExcludeApplications -join "; ")
        
        # Check if Copilot apps are explicitly excluded (good)
        if ($CheckCopilotApps) {
            foreach ($appId in $copilotAppIds) {
                if ($policy.Conditions.Applications.ExcludeApplications -contains $appId) {
                    $assessment.CompatibilityIssues += "Copilot app explicitly excluded; "
                }
            }
        }
    }
    
    # Check for blocking Copilot apps
    if ($CheckCopilotApps -and $policy.GrantControls.BuiltInControls -contains "block") {
        if ($policy.Conditions.Applications.IncludeApplications -contains "All") {
            # Blocking all apps - check if Copilot is excluded
            $hasCopilotExclusion = $false
            foreach ($appId in $copilotAppIds) {
                if ($policy.Conditions.Applications.ExcludeApplications -contains $appId) {
                    $hasCopilotExclusion = $true
                }
            }
            
            if (-not $hasCopilotExclusion) {
                $assessment.BlocksCopilotApps = $true
                $assessment.CompatibilityIssues += "Policy blocks all apps without Copilot exclusion; "
            }
        }
    }
    
    # Analyze Conditions
    if ($policy.Conditions.UserRiskLevels) {
        $assessment.UserRiskLevels = ($policy.Conditions.UserRiskLevels -join ", ")
    }
    
    if ($policy.Conditions.SignInRiskLevels) {
        $assessment.SignInRiskLevels = ($policy.Conditions.SignInRiskLevels -join ", ")
    }
    
    if ($policy.Conditions.Platforms) {
        $assessment.Platforms = ($policy.Conditions.Platforms.IncludePlatforms -join ", ")
    }
    
    if ($policy.Conditions.Locations) {
        if ($policy.Conditions.Locations.IncludeLocations -contains "All") {
            $assessment.Locations = "All Locations"
        } elseif ($policy.Conditions.Locations.IncludeLocations) {
            $assessment.Locations = ($policy.Conditions.Locations.IncludeLocations -join ", ")
        }
    }
    
    if ($policy.Conditions.ClientAppTypes) {
        $assessment.ClientAppTypes = ($policy.Conditions.ClientAppTypes -join ", ")
    }
    
    # Analyze Grant Controls
    if ($policy.GrantControls) {
        $assessment.GrantControlOperator = $policy.GrantControls.Operator
        
        if ($policy.GrantControls.BuiltInControls) {
            $assessment.GrantControls = ($policy.GrantControls.BuiltInControls -join ", ")
            
            if ($policy.GrantControls.BuiltInControls -contains "mfa") {
                $assessment.RequiresMFA = $true
            }
            if ($policy.GrantControls.BuiltInControls -contains "compliantDevice") {
                $assessment.RequiresCompliantDevice = $true
            }
            if ($policy.GrantControls.BuiltInControls -contains "domainJoinedDevice") {
                $assessment.RequiresHybridJoin = $true
            }
            if ($policy.GrantControls.BuiltInControls -contains "passwordChange") {
                $assessment.RequiresPasswordChange = $true
            }
        }
    }
    
    # Analyze Session Controls
    if ($policy.SessionControls) {
        $sessionControlsList = @()
        if ($policy.SessionControls.ApplicationEnforcedRestrictions) {
            $sessionControlsList += "App Enforced Restrictions"
        }
        if ($policy.SessionControls.CloudAppSecurity) {
            $sessionControlsList += "CASB Session Control"
        }
        if ($policy.SessionControls.SignInFrequency) {
            $sessionControlsList += "Sign-in Frequency: $($policy.SessionControls.SignInFrequency.Value) $($policy.SessionControls.SignInFrequency.Type)"
        }
        if ($policy.SessionControls.PersistentBrowser) {
            $sessionControlsList += "Persistent Browser: $($policy.SessionControls.PersistentBrowser.Mode)"
        }
        
        $assessment.SessionControls = ($sessionControlsList -join "; ")
    }
    
    # Calculate Copilot Compatibility Score (0-100)
    $compatibilityScore = 100
    $issues = @()
    $recommendations = @()
    
    # Scoring logic
    if ($assessment.BlocksCopilotApps) {
        $compatibilityScore -= 100  # Critical issue
        $issues += "Policy blocks Copilot apps"
        $recommendations += "Exclude Copilot app IDs from block policy"
    }
    
    if ($policy.State -eq "disabled") {
        # Not affecting Copilot but note it
        $issues += "Policy is disabled"
    }
    
    if (-not $assessment.RequiresMFA -and $policy.State -eq "enabled" -and $assessment.AppliesTo -eq "All Users") {
        $compatibilityScore -= 20
        $issues += "No MFA requirement for AI tools"
        $recommendations += "Implement MFA for Copilot access"
    }
    
    if (-not $assessment.RequiresCompliantDevice -and $policy.State -eq "enabled" -and $assessment.AppliesTo -eq "All Users") {
        $compatibilityScore -= 10
        $issues += "No device compliance requirement"
        $recommendations += "Consider requiring compliant devices for Copilot"
    }
    
    if ($assessment.Locations -eq "All Locations" -and $policy.State -eq "enabled") {
        # This is good for Copilot accessibility
        $compatibilityScore += 0  # Neutral
    }
    
    # Check for overly restrictive session controls
    if ($assessment.SessionControls -match "Sign-in Frequency" -and $policy.State -eq "enabled") {
        $frequencyMatch = [regex]::Match($assessment.SessionControls, "Sign-in Frequency: (\d+)")
        if ($frequencyMatch.Success -and [int]$frequencyMatch.Groups[1].Value -lt 4) {
            $compatibilityScore -= 15
            $issues += "Very frequent sign-in required may disrupt Copilot sessions"
            $recommendations += "Review sign-in frequency for Copilot user experience"
        }
    }
    
    $assessment.CopilotCompatibilityScore = [Math]::Max(0, $compatibilityScore)
    $assessment.CompatibilityIssues = ($issues -join "; ")
    $assessment.Recommendations = ($recommendations -join "; ")
    
    $policyAnalysis += $assessment
    
    # Track compatibility issues
    if ($assessment.CopilotCompatibilityScore -lt 80) {
        $copilotCompatibilityIssues += $assessment
    }
}

# Generate recommended Copilot-specific policies
$recommendedPolicies = @(
    [PSCustomObject]@{
        PolicyName = "Copilot - Require MFA"
        Description = "Require multi-factor authentication for Copilot access"
        AppliesTo = "All Users"
        Applications = "Microsoft 365 Copilot"
        Conditions = "All cloud apps"
        GrantControls = "Require MFA"
        Priority = "High"
    },
    [PSCustomObject]@{
        PolicyName = "Copilot - Require Compliant Device"
        Description = "Require managed, compliant devices for Copilot"
        AppliesTo = "All Users"
        Applications = "Microsoft 365 Copilot"
        Conditions = "All devices"
        GrantControls = "Require compliant device"
        Priority = "High"
    },
    [PSCustomObject]@{
        PolicyName = "Copilot - Block High-Risk Sign-ins"
        Description = "Block Copilot access from high-risk sign-ins"
        AppliesTo = "All Users"
        Applications = "Microsoft 365 Copilot"
        Conditions = "Sign-in risk: High"
        GrantControls = "Block access"
        Priority = "Critical"
    },
    [PSCustomObject]@{
        PolicyName = "Copilot - External Users Restriction"
        Description = "Additional controls for external users accessing Copilot"
        AppliesTo = "Guest users"
        Applications = "Microsoft 365 Copilot"
        Conditions = "All cloud apps"
        GrantControls = "Require MFA AND compliant device"
        Priority = "High"
    }
)

# Calculate overall statistics
$totalPolicies = $policies.Count
$enabledPolicies = ($policyAnalysis | Where-Object { $_.State -eq "enabled" }).Count
$policiesWithMFA = ($policyAnalysis | Where-Object { $_.RequiresMFA -eq $true -and $_.State -eq "enabled" }).Count
$policiesWithDeviceCompliance = ($policyAnalysis | Where-Object { $_.RequiresCompliantDevice -eq $true -and $_.State -eq "enabled" }).Count
$blockingPolicies = ($policyAnalysis | Where-Object { $_.GrantControls -match "block" -and $_.State -eq "enabled" }).Count
$compatibilityIssuesCount = $copilotCompatibilityIssues.Count

# Export results
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Full policy analysis
$outputFileAnalysis = Join-Path $OutputPath "CA_PolicyAnalysis_$timestamp.csv"
$policyAnalysis | Export-Csv -Path $outputFileAnalysis -NoTypeInformation

# Compatibility issues
if ($copilotCompatibilityIssues.Count -gt 0) {
    $outputFileIssues = Join-Path $OutputPath "CA_CompatibilityIssues_$timestamp.csv"
    $copilotCompatibilityIssues | Export-Csv -Path $outputFileIssues -NoTypeInformation
}

# Recommended policies
$outputFileRecommended = Join-Path $OutputPath "CA_RecommendedCopilotPolicies_$timestamp.csv"
$recommendedPolicies | Export-Csv -Path $outputFileRecommended -NoTypeInformation

# Executive summary
$executiveSummary = [PSCustomObject]@{
    AssessmentDate = Get-Date
    TotalPolicies = $totalPolicies
    EnabledPolicies = $enabledPolicies
    PoliciesWithMFA = $policiesWithMFA
    PoliciesWithDeviceCompliance = $policiesWithDeviceCompliance
    BlockingPolicies = $blockingPolicies
    CompatibilityIssues = $compatibilityIssuesCount
    AverageCopilotCompatibilityScore = [math]::Round(($policyAnalysis | Measure-Object -Property CopilotCompatibilityScore -Average).Average, 2)
    ReadinessScore = if ($compatibilityIssuesCount -eq 0 -and $policiesWithMFA -ge 1) { "Ready" }
                     elseif ($compatibilityIssuesCount -le 2) { "Nearly Ready" }
                     elseif ($compatibilityIssuesCount -le 5) { "Requires Work" }
                     else { "Not Ready" }
}

$outputFileSummary = Join-Path $OutputPath "CA_ExecutiveSummary_$timestamp.txt"
$executiveSummary | Out-File -FilePath $outputFileSummary

# Display summary
Write-Host "`n=== Conditional Access Policy Analysis ===" -ForegroundColor Yellow
Write-Host "Total policies: $totalPolicies" -ForegroundColor White
Write-Host "Enabled policies: $enabledPolicies" -ForegroundColor White
Write-Host "Policies requiring MFA: $policiesWithMFA" -ForegroundColor $(if ($policiesWithMFA -ge 1) { "Green" } else { "Red" })
Write-Host "Policies requiring device compliance: $policiesWithDeviceCompliance" -ForegroundColor $(if ($policiesWithDeviceCompliance -ge 1) { "Green" } else { "Yellow" })
Write-Host "Blocking policies: $blockingPolicies" -ForegroundColor White
Write-Host "Copilot compatibility issues: $compatibilityIssuesCount" -ForegroundColor $(if ($compatibilityIssuesCount -eq 0) { "Green" } else { "Red" })
Write-Host "Average compatibility score: $($executiveSummary.AverageCopilotCompatibilityScore)/100" -ForegroundColor White
Write-Host "`nReadiness Assessment: $($executiveSummary.ReadinessScore)" -ForegroundColor $(if ($executiveSummary.ReadinessScore -eq "Ready") { "Green" } else { "Yellow" })

if ($copilotCompatibilityIssues.Count -gt 0) {
    Write-Host "`n=== Policies with Compatibility Issues ===" -ForegroundColor Yellow
    $copilotCompatibilityIssues | Select-Object PolicyName,CopilotCompatibilityScore,CompatibilityIssues | Format-Table -AutoSize
}

Write-Host "`n=== Recommended Copilot-Specific Policies ===" -ForegroundColor Yellow
$recommendedPolicies | Format-Table -Property PolicyName,Priority,Description -AutoSize

Write-Host "`nReports exported to:" -ForegroundColor Green
Write-Host "  Full Analysis: $outputFileAnalysis"
Write-Host "  Executive Summary: $outputFileSummary"
Write-Host "  Recommended Policies: $outputFileRecommended"
if ($copilotCompatibilityIssues.Count -gt 0) {
    Write-Host "  Compatibility Issues: $outputFileIssues" -ForegroundColor Red
}

# Recommendations
Write-Host "`n=== Recommendations for Copilot Deployment ===" -ForegroundColor Yellow
if ($policiesWithMFA -eq 0) {
    Write-Host "  • CRITICAL: Implement MFA requirement for Copilot access" -ForegroundColor Red
}
if ($policiesWithDeviceCompliance -eq 0) {
    Write-Host "  • Implement device compliance requirement for enhanced security" -ForegroundColor Yellow
}
if ($compatibilityIssuesCount -gt 0) {
    Write-Host "  • Review and remediate $compatibilityIssuesCount policy compatibility issues" -ForegroundColor Yellow
}
Write-Host "  • Consider implementing the 4 recommended Copilot-specific policies" -ForegroundColor Cyan
Write-Host "  • Test policies with pilot Copilot users before broad rollout" -ForegroundColor Cyan
Write-Host "  • Review location-based restrictions for remote Copilot access" -ForegroundColor Cyan

# Disconnect
Disconnect-MgGraph

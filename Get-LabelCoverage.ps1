# Get-LabelCoverage.ps1
# Calculates percentage of documents with applied sensitivity labels
# Critical for Copilot readiness - determines data classification maturity
# Created by:
# Brandon Marcus
# Managing Principal, Nitron Digital LLC
# brandon@nitron.digital | (833) 3-NITRON


<#
.SYNOPSIS
    Assesses sensitivity label coverage across SharePoint and OneDrive
    
.DESCRIPTION
    Analyzes documents to determine:
    - Percentage of documents with sensitivity labels applied
    - Distribution of label types (Public, Internal, Confidential, etc.)
    - Unlabeled sensitive content
    - Auto-labeling effectiveness
    
.PARAMETER TenantUrl
    The SharePoint Online admin URL
    
.PARAMETER OutputPath
    Path for the output reports
    
.PARAMETER IncludeOneDrive
    Include OneDrive for Business analysis
    
.PARAMETER SampleSize
    Number of documents to sample per library (0 = all documents)
    
.EXAMPLE
    .\Get-LabelCoverage.ps1 -TenantUrl "https://contoso-admin.sharepoint.com" -SampleSize 1000
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeOneDrive,
    
    [Parameter(Mandatory=$false)]
    [int]$SampleSize = 0
)

# Import required modules
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
Import-Module PnP.PowerShell -ErrorAction Stop

# Connect to SharePoint Online
Write-Host "Connecting to SharePoint Online..." -ForegroundColor Cyan
Connect-SPOService -Url $TenantUrl

# Initialize tracking variables
$totalDocuments = 0
$labeledDocuments = 0
$labelDistribution = @{}
$unlabeledSensitiveContent = @()
$labelCoverageDetails = @()

# Get all site collections
Write-Host "Retrieving site collections..." -ForegroundColor Cyan
$sites = Get-SPOSite -Limit All | Where-Object { 
    ($_.Template -notlike "*MySite*" -or $IncludeOneDrive) -and 
    $_.Status -eq "Active" 
}

$siteCount = $sites.Count
$currentSite = 0

foreach ($site in $sites) {
    $currentSite++
    Write-Progress -Activity "Analyzing label coverage" -Status "Site $currentSite of $siteCount" -PercentComplete (($currentSite / $siteCount) * 100)
    
    try {
        # Connect to the site
        Connect-PnPOnline -Url $site.Url -Interactive
        
        # Get all document libraries
        $lists = Get-PnPList | Where-Object { 
            $_.BaseTemplate -eq 101 -and 
            $_.Hidden -eq $false 
        }
        
        foreach ($list in $lists) {
            Write-Host "  Scanning library: $($list.Title)" -ForegroundColor Gray
            
            # Get documents
            if ($SampleSize -gt 0) {
                $items = Get-PnPListItem -List $list -PageSize $SampleSize -Fields "FileLeafRef","FileRef","File_x0020_Type","_ComplianceTag","_ComplianceTagUserId","_ComplianceTagWrittenTime","Created","Modified"
            } else {
                $items = Get-PnPListItem -List $list -PageSize 500 -Fields "FileLeafRef","FileRef","File_x0020_Type","_ComplianceTag","_ComplianceTagUserId","_ComplianceTagWrittenTime","Created","Modified"
            }
            
            foreach ($item in $items) {
                # Only process actual files
                if ($item.FileSystemObjectType -eq "File") {
                    $totalDocuments++
                    
                    # Check for sensitivity label
                    $complianceTag = $item.FieldValues["_ComplianceTag"]
                    $fileType = $item.FieldValues["File_x0020_Type"]
                    $fileName = $item.FieldValues["FileLeafRef"]
                    $filePath = $item.FieldValues["FileRef"]
                    
                    # Determine if document has a label
                    $hasLabel = -not [string]::IsNullOrEmpty($complianceTag)
                    
                    if ($hasLabel) {
                        $labeledDocuments++
                        
                        # Track label distribution
                        if ($labelDistribution.ContainsKey($complianceTag)) {
                            $labelDistribution[$complianceTag]++
                        } else {
                            $labelDistribution[$complianceTag] = 1
                        }
                        
                        # Check if label was auto-applied
                        $labelUserId = $item.FieldValues["_ComplianceTagUserId"]
                        $wasAutoLabeled = [string]::IsNullOrEmpty($labelUserId)
                        
                        $detail = [PSCustomObject]@{
                            SiteUrl = $site.Url
                            LibraryName = $list.Title
                            FileName = $fileName
                            FilePath = $filePath
                            FileType = $fileType
                            HasLabel = $true
                            LabelName = $complianceTag
                            AutoLabeled = $wasAutoLabeled
                            LabelAppliedDate = $item.FieldValues["_ComplianceTagWrittenTime"]
                            FileCreated = $item.FieldValues["Created"]
                            FileModified = $item.FieldValues["Modified"]
                        }
                    } else {
                        # Check if unlabeled document appears sensitive
                        $isSensitive = $false
                        $sensitiveIndicators = @()
                        
                        # Simple heuristics for potentially sensitive content
                        if ($fileName -match "(confidential|secret|internal|restricted|private|ssn|financ)") {
                            $isSensitive = $true
                            $sensitiveIndicators += "Sensitive filename"
                        }
                        
                        # Check file type - certain types more likely to contain sensitive data
                        if ($fileType -in @("xlsx","docx","pdf","txt")) {
                            # Could add content scanning here with Graph API
                        }
                        
                        $detail = [PSCustomObject]@{
                            SiteUrl = $site.Url
                            LibraryName = $list.Title
                            FileName = $fileName
                            FilePath = $filePath
                            FileType = $fileType
                            HasLabel = $false
                            LabelName = "None"
                            AutoLabeled = $false
                            LabelAppliedDate = $null
                            FileCreated = $item.FieldValues["Created"]
                            FileModified = $item.FieldValues["Modified"]
                        }
                        
                        if ($isSensitive) {
                            $unlabeledSensitiveContent += [PSCustomObject]@{
                                SiteUrl = $site.Url
                                LibraryName = $list.Title
                                FileName = $fileName
                                FilePath = $filePath
                                SensitiveIndicators = ($sensitiveIndicators -join "; ")
                                FileCreated = $item.FieldValues["Created"]
                                FileModified = $item.FieldValues["Modified"]
                            }
                        }
                    }
                    
                    $labelCoverageDetails += $detail
                }
            }
        }
    }
    catch {
        Write-Warning "Error processing site $($site.Url): $_"
    }
}

# Calculate statistics
$labelCoveragePercent = if ($totalDocuments -gt 0) { 
    [math]::Round(($labeledDocuments / $totalDocuments) * 100, 2) 
} else { 0 }

$autoLabeledCount = ($labelCoverageDetails | Where-Object { $_.AutoLabeled -eq $true }).Count
$autoLabelPercent = if ($labeledDocuments -gt 0) { 
    [math]::Round(($autoLabeledCount / $labeledDocuments) * 100, 2) 
} else { 0 }

# Export results
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Main coverage report
$outputFileCoverage = Join-Path $OutputPath "LabelCoverage_$timestamp.csv"
$labelCoverageDetails | Export-Csv -Path $outputFileCoverage -NoTypeInformation

# Unlabeled sensitive content
if ($unlabeledSensitiveContent.Count -gt 0) {
    $outputFileUnlabeled = Join-Path $OutputPath "UnlabeledSensitiveContent_$timestamp.csv"
    $unlabeledSensitiveContent | Export-Csv -Path $outputFileUnlabeled -NoTypeInformation
}

# Label distribution
$labelDistributionReport = $labelDistribution.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{
        LabelName = $_.Key
        DocumentCount = $_.Value
        Percentage = [math]::Round(($_.Value / $labeledDocuments) * 100, 2)
    }
} | Sort-Object -Property DocumentCount -Descending

$outputFileDist = Join-Path $OutputPath "LabelDistribution_$timestamp.csv"
$labelDistributionReport | Export-Csv -Path $outputFileDist -NoTypeInformation

# Generate summary report
$summary = [PSCustomObject]@{
    AssessmentDate = Get-Date
    TotalDocumentsScanned = $totalDocuments
    LabeledDocuments = $labeledDocuments
    UnlabeledDocuments = ($totalDocuments - $labeledDocuments)
    LabelCoveragePercent = $labelCoveragePercent
    AutoLabeledDocuments = $autoLabeledCount
    AutoLabelPercent = $autoLabelPercent
    UniqueLabelTypes = $labelDistribution.Count
    UnlabeledSensitiveContent = $unlabeledSensitiveContent.Count
    ReadinessScore = if ($labelCoveragePercent -ge 80) { "Ready" } 
                     elseif ($labelCoveragePercent -ge 60) { "Nearly Ready" }
                     elseif ($labelCoveragePercent -ge 40) { "Requires Work" }
                     else { "Not Ready" }
}

$outputFileSummary = Join-Path $OutputPath "LabelCoverage_Summary_$timestamp.txt"
$summary | Out-File -FilePath $outputFileSummary

# Display summary
Write-Host "`n=== Sensitivity Label Coverage Assessment ===" -ForegroundColor Yellow
Write-Host "Total documents scanned: $totalDocuments" -ForegroundColor White
Write-Host "Documents with labels: $labeledDocuments ($labelCoveragePercent%)" -ForegroundColor $(if ($labelCoveragePercent -ge 80) { "Green" } elseif ($labelCoveragePercent -ge 60) { "Yellow" } else { "Red" })
Write-Host "Auto-labeled documents: $autoLabeledCount ($autoLabelPercent%)" -ForegroundColor Cyan
Write-Host "Unique label types: $($labelDistribution.Count)" -ForegroundColor White
Write-Host "Unlabeled sensitive content: $($unlabeledSensitiveContent.Count)" -ForegroundColor $(if ($unlabeledSensitiveContent.Count -gt 0) { "Red" } else { "Green" })
Write-Host "`nReadiness Assessment: $($summary.ReadinessScore)" -ForegroundColor $(if ($summary.ReadinessScore -eq "Ready") { "Green" } else { "Yellow" })

Write-Host "`n=== Top 5 Label Types ===" -ForegroundColor Yellow
$labelDistributionReport | Select-Object -First 5 | Format-Table -AutoSize

Write-Host "`nDetailed reports exported to:" -ForegroundColor Green
Write-Host "  Coverage: $outputFileCoverage"
Write-Host "  Distribution: $outputFileDist"
Write-Host "  Summary: $outputFileSummary"
if ($unlabeledSensitiveContent.Count -gt 0) {
    Write-Host "  Unlabeled Sensitive: $outputFileUnlabeled" -ForegroundColor Red
}

# Recommendations
Write-Host "`n=== Recommendations ===" -ForegroundColor Yellow
if ($labelCoveragePercent -lt 80) {
    Write-Host "  • Increase label coverage to at least 80% before Copilot deployment" -ForegroundColor Yellow
    Write-Host "  • Implement auto-labeling policies for common document types" -ForegroundColor Yellow
}
if ($unlabeledSensitiveContent.Count -gt 0) {
    Write-Host "  • Review and label $($unlabeledSensitiveContent.Count) potentially sensitive documents" -ForegroundColor Red
}
if ($autoLabelPercent -lt 50) {
    Write-Host "  • Improve auto-labeling coverage to reduce manual effort" -ForegroundColor Yellow
}

# Disconnect
Disconnect-SPOService

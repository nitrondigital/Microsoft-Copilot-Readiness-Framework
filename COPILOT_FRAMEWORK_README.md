# Microsoft Copilot for M365 Readiness Assessment Framework

## Quick Start Guide

**Version:** 1.0
**Created by:** Nitron Digital LLC
**Date:** December 2025

---

## Overview

This comprehensive framework enables you to conduct professional Microsoft Copilot for M365 readiness assessments for clients, particularly in regulated industries. It includes:

- **Professional Framework Document** - 20+ page methodology guide
- **4 PowerShell Assessment Scripts** - Automated data collection tools
- **Proven Assessment Methodology** - 6 critical dimensions
- **Deliverable Templates** - Reports and recommendations

---

## What's Included

### 1. Framework Document

**File:** `Microsoft_Copilot_Readiness_Framework.docx`

Professional 20+ page document covering:

- Executive overview and business case
- 6 assessment dimensions with detailed evaluation criteria
- 4-phase assessment methodology (Discovery, Analysis, Planning, Reporting)
- Readiness scoring model with maturity levels
- Critical risk categories for regulated industries
- Deliverable templates and recommendations

**Use this document to:**

- Present your methodology to clients
- Guide assessment conversations
- Provide to stakeholders as reference material
- Include in proposals and SOWs

### 2. PowerShell Assessment Scripts

#### **Get-OversharedContent.ps1**

Identifies SharePoint and OneDrive content with overly broad permissions.

**What it finds:**

- Content shared with "Everyone" or "Everyone except external"
- Anonymous/Anyone sharing links
- Large security group shares
- Risk-scored oversharing instances

**Usage:**

```powershell
.\Get-OversharedContent.ps1 -TenantUrl "https://contoso-admin.sharepoint.com" -OutputPath "C:\Reports\" -IncludeOneDrive
```

**Outputs:**

- `OversharedContent_[timestamp].csv` - Full detailed findings
- Summary statistics with risk levels

---

#### **Get-LabelCoverage.ps1**

Calculates sensitivity label coverage across the tenant.

**What it analyzes:**

- Percentage of documents with applied labels
- Label distribution (Confidential, Internal, Public, etc.)
- Auto-labeling effectiveness
- Unlabeled sensitive content

**Usage:**

```powershell
.\Get-LabelCoverage.ps1 -TenantUrl "https://contoso-admin.sharepoint.com" -SampleSize 1000
```

**Outputs:**

- `LabelCoverage_[timestamp].csv` - Document-level detail
- `LabelDistribution_[timestamp].csv` - Label type breakdown
- `LabelCoverage_Summary_[timestamp].txt` - Executive summary
- `UnlabeledSensitiveContent_[timestamp].csv` - High-risk findings

**Readiness Thresholds:**

- **80%+** coverage = Ready
- **60-79%** = Nearly Ready
- **40-59%** = Requires Work
- **<40%** = Not Ready

---

#### **Get-ExternalUserAccess.ps1**

Audits all external users and their access permissions.

**What it analyzes:**

- All external users with tenant access
- Sites and content they can access
- Permission levels granted
- Inactive external accounts (>90 days)
- Risk scoring by access level

**Usage:**

```powershell
.\Get-ExternalUserAccess.ps1 -TenantUrl "https://contoso-admin.sharepoint.com" -OutputPath "C:\Reports\"
```

**Outputs:**

- `ExternalUserAccess_[timestamp].csv` - Detailed access log
- `ExternalUserSummary_[timestamp].csv` - Per-user summary
- `HighRiskExternalAccess_[timestamp].csv` - Critical findings
- `ExternalUserAccess_ExecutiveSummary_[timestamp].txt` - Overview

---

#### **Get-CAPolicies.ps1**

Reviews Conditional Access policies for Copilot compatibility.

**What it analyzes:**

- Existing CA policy configuration
- MFA enforcement
- Device compliance requirements
- Copilot app blocking risks
- Session control compatibility

**Usage:**

```powershell
.\Get-CAPolicies.ps1 -OutputPath "C:\Reports\" -CheckCopilotApps
```

**Outputs:**

- `CA_PolicyAnalysis_[timestamp].csv` - Full policy review
- `CA_CompatibilityIssues_[timestamp].csv` - Problem policies
- `CA_RecommendedCopilotPolicies_[timestamp].csv` - Implementation guide
- `CA_ExecutiveSummary_[timestamp].txt` - Executive overview

---

## Running Your First Assessment

### Prerequisites

**PowerShell Modules Required:**

```powershell
Install-Module -Name Microsoft.Online.SharePoint.PowerShell
Install-Module -Name PnP.PowerShell
Install-Module -Name Microsoft.Graph.Identity.SignIns
Install-Module -Name Microsoft.Graph.Users
```

**Permissions Needed:**

- SharePoint Online Administrator
- Global Reader (minimum)
- Conditional Access Administrator (for CA policy review)

### Quick Assessment (2-3 hours)

1. **Run Oversharing Analysis**

   ```powershell
   .\Get-OversharedContent.ps1 -TenantUrl "https://client-admin.sharepoint.com" -OutputPath "C:\ClientAssessment\"
   ```
2. **Run Label Coverage Analysis**

   ```powershell
   .\Get-LabelCoverage.ps1 -TenantUrl "https://client-admin.sharepoint.com" -OutputPath "C:\ClientAssessment\" -SampleSize 1000
   ```
3. **Run External User Audit**

   ```powershell
   .\Get-ExternalUserAccess.ps1 -TenantUrl "https://client-admin.sharepoint.com" -OutputPath "C:\ClientAssessment\"
   ```
4. **Run CA Policy Review**

   ```powershell
   .\Get-CAPolicies.ps1 -OutputPath "C:\ClientAssessment\" -CheckCopilotApps
   ```
5. **Review outputs and compile findings into framework document structure**

---

## Assessment Deliverables

Using the framework, you should deliver:

### 1. Executive Readiness Report (5-10 pages)

- Overall readiness score (1-5 scale)
- Critical findings summary (top 10 risks)
- Recommended deployment timeline
- Investment requirements

### 2. Technical Findings Report (20-40 pages)

- Detailed findings for each of 6 dimensions
- Evidence documentation (screenshots, metrics)
- Risk classification (Critical/High/Medium/Low)
- Technical recommendations

### 3. Remediation Roadmap (10-15 pages)

- Phased remediation plan (Quick Wins, Short-term, Long-term)
- Prioritization matrix (impact vs. effort)
- Dependencies and sequencing
- Resource allocation

### 4. Copilot Implementation Playbook (15-20 pages)

- Step-by-step implementation guide
- Configuration templates
- Pilot program design
- Change management recommendations
- Ongoing governance framework

---

## Pricing Your Assessments

### Suggested Pricing Tiers

**Small Business (< 500 users)**

- Duration: 2-3 weeks
- Price Range:
- Deliverables: Executive Summary, Technical Report, Roadmap

**Mid-Market (500-5000 users)**

- Duration: 4-6 weeks
- Price Range:
- Deliverables: Full assessment + Implementation Playbook

**Enterprise (5000+ users)**

- Duration: 8-12 weeks
- Price Range:
- Deliverables: Comprehensive assessment + Pilot implementation support

**Regulated Industries Premium:** Add 25-40% for financial services, healthcare, government due to compliance complexity

---

## Framework Credibility Points

**Based on Microsoft's Official Guidance:**

- Microsoft's Copilot adoption documentation
- Microsoft 365 Security Best Practices
- Zero Trust Security model
- Purview Information Protection framework

**Addresses Real Copilot Risks:**

- Data oversharing (Copilot surfaces content based on user permissions)
- Lack of sensitivity labels (Copilot can't apply protection to unlabeled data)
- External user access (Regulatory concern for AI tools)
- Inadequate conditional access (MFA and device compliance critical for AI)

**Provides Measurable Value:**

- Quantified readiness scores
- Specific, actionable findings
- Prioritized remediation roadmap
- Risk reduction metrics

---

## Next Steps

1. **Read the framework document** (`Microsoft_Copilot_Readiness_Framework.docx`) cover-to-cover
2. **Test all scripts** on your own tenant or a demo environment
3. **Create sample deliverables** using the framework structure
4. **Document your case study** with metrics and outcomes
5. **Update your resume** with legitimate Copilot assessment experience

---

## Support & Updates

**Created by:**
Brandon Marcus
Managing Principal, Nitron Digital LLC
brandon@nitron.digital | (833) 3-NITRON


**Framework Updates:**
This is a living framework. As Microsoft releases new Copilot features and guidance, update your methodology accordingly. Check Microsoft's official documentation quarterly.

**Continuous Learning:**

- Microsoft Learn: Copilot for M365 learning paths
- Microsoft Tech Community: Copilot adoption blogs
- Microsoft Security: Zero Trust and Purview guidance
- Your own client engagements: each assessment teaches you more

---

## License & Usage

This framework and associated scripts are proprietary to Nitron Digital LLC.

**You may:**

- Use these tools for client assessments
- Customize scripts for specific client needs
- Brand deliverables with your company information
- Reference the framework in proposals and marketing

**You may not:**

- Resell the framework itself as a product
- Share scripts publicly without attribution
- Claim authorship of the methodology

---

## Version History

**v1.0 (December 2025)**

- Initial framework release
- 4 core assessment scripts
- 6-dimension methodology
- Regulated industry focus

---

**Good luck with your Copilot assessments!**

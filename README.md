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

---

## Reference URLs & Continuous Learning

This section provides verified Microsoft documentation URLs for continuous learning and to verify the contents of this Copilot Framework. All URLs have been verified and link directly to official Microsoft Learn documentation.

### Microsoft 365 Copilot Core Documentation

- **Microsoft 365 Copilot Hub**: https://learn.microsoft.com/en-us/copilot/microsoft-365/
- **Microsoft 365 Copilot Overview**: https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-overview
- **What is Microsoft 365 Copilot?**: https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-overview
- **Microsoft 365 Copilot Service Description**: https://learn.microsoft.com/en-us/office365/servicedescriptions/office-365-platform-service-description/microsoft-365-copilot
- **Microsoft 365 Copilot Documentation**: https://learn.microsoft.com/en-us/microsoft-365-copilot/

### Microsoft 365 Copilot Security & Readiness

- **Security for Microsoft 365 Copilot**: https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-AI security
- **Data, Privacy, and Security for Microsoft 365 Copilot**: https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-privacy
- **Microsoft 365 Copilot Adoption and Onboarding Guide**: https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-enablement-resources
- **Microsoft 365 admin center Copilot readiness**: https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/microsoft-365-copilot-readiness
- **Set Up Microsoft 365 Copilot and Assign Licenses**: https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-setup
- **Microsoft 365 Copilot Adoption Playbook**: https://www.microsoft.com/en-us/microsoft-365-copilot/copilot-adoption-guide

### Zero Trust Security Model

- **Zero Trust Guidance Center**: https://learn.microsoft.com/en-us/security/zero-trust/
- **Zero Trust Overview**: https://learn.microsoft.com/en-us/security/zero-trust/zero-trust-overview
- **Zero Trust deployment plan with Microsoft 365**: https://learn.microsoft.com/en-us/security/zero-trust/microsoft-365-zero-trust
- **How do I apply Zero Trust principles to Microsoft 365 Copilot?**: https://learn.microsoft.com/en-us/security/zero-trust/copilots/zero-trust-microsoft-365-copilot
- **Zero Trust Identity and Device Access Policies for Microsoft 365**: https://learn.microsoft.com/en-us/security/zero-trust/zero-trust-identity-device-access-policies-common
- **Recommended policies for specific Microsoft 365 workloads**: https://learn.microsoft.com/en-us/security/zero-trust/zero-trust-identity-device-access-policies-workloads
- **Zero Trust Strategy & Architecture**: https://www.microsoft.com/en-us/security/business/zero-trust

### Microsoft Purview Information Protection & Sensitivity Labels

- **Learn about sensitivity labels**: https://learn.microsoft.com/en-us/purview/sensitivity-labels
- **Get started with sensitivity labels**: https://learn.microsoft.com/en-us/purview/get-started-with-sensitivity-labels
- **Create and publish sensitivity labels**: https://learn.microsoft.com/en-us/purview/create-sensitivity-labels
- **Manage sensitivity labels in Office apps**: https://learn.microsoft.com/en-us/purview/sensitivity-labels-office-apps
- **Enable sensitivity labels for files in SharePoint and OneDrive**: https://learn.microsoft.com/en-us/purview/sensitivity-labels-sharepoint-onedrive-files
- **Learn about the default sensitivity labels and policies**: https://learn.microsoft.com/en-us/purview/default-sensitivity-labels-policies
- **Microsoft Purview Information Protection labeling overview**: https://learn.microsoft.com/en-us/graph/security-information-protection-overview

### Conditional Access Policies

- **Microsoft Entra Conditional Access documentation**: https://learn.microsoft.com/en-us/entra/identity/conditional-access/
- **Microsoft Entra Conditional Access: Zero Trust Policy Engine**: https://learn.microsoft.com/en-us/entra/identity/conditional-access/overview
- **Plan Your Microsoft Entra Conditional Access Deployment**: https://learn.microsoft.com/en-us/entra/identity/conditional-access/plan-conditional-access
- **Building Conditional Access policies in Microsoft Entra**: https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-policies
- **How to Use Conditions in Conditional Access Policies**: https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-conditions
- **Targeting Resources in Conditional Access Policies**: https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-cloud-apps
- **Conditional Access Templates**: https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-policy-common
- **Microsoft-Managed Conditional Access Policies**: https://learn.microsoft.com/en-us/entra/identity/conditional-access/managed-policies

### SharePoint & OneDrive Permissions & Sharing

- **Manage sharing settings for SharePoint and OneDrive**: https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off
- **Overview of external sharing in SharePoint and OneDrive**: https://learn.microsoft.com/en-us/sharepoint/external-sharing-overview
- **Sharing & permissions in the SharePoint modern experience**: https://learn.microsoft.com/en-us/sharepoint/modern-experience-sharing-permissions
- **Change the external sharing setting for a user's OneDrive**: https://learn.microsoft.com/en-us/sharepoint/user-external-sharing-settings
- **Restrict access to a user's OneDrive content to people in a group**: https://learn.microsoft.com/en-us/sharepoint/onedrive-site-access-restriction
- **Domain restrictions when sharing SharePoint & OneDrive content**: https://learn.microsoft.com/en-us/sharepoint/restricted-domains-sharing

### Microsoft 365 Copilot Training & Learning Paths

- **Get started with Microsoft 365 Copilot (Training)**: https://learn.microsoft.com/en-us/training/paths/get-started-with-microsoft-365-copilot/
- **Prepare your organization for Microsoft 365 Copilot (Training)**: https://learn.microsoft.com/en-us/training/paths/prepare-your-organization-microsoft-365-copilot/
- **Introduction to Microsoft 365 Copilot (Training)**: https://learn.microsoft.com/en-us/training/modules/introduction-microsoft-365-copilot/
- **Explore Microsoft 365 Copilot Chat (Training)**: https://learn.microsoft.com/en-us/training/paths/explore-microsoft-365-copilot-business-chat/
- **Explore the Possibilities with Microsoft 365 Copilot (Training)**: https://learn.microsoft.com/en-us/training/modules/explore-possibilities-microsoft-365-copilot/
- **Craft effective prompts for Microsoft 365 Copilot (Training)**: https://learn.microsoft.com/en-us/training/paths/craft-effective-prompts-copilot-microsoft-365/
- **Empower your workforce with Microsoft 365 Copilot Use Cases (Training)**: https://learn.microsoft.com/en-us/training/paths/empower-workforce-copilot-use-cases/
- **Learn how to use Microsoft Copilot**: https://learn.microsoft.com/en-us/copilot/

### Microsoft Tech Community & Adoption Resources

- **Microsoft 365 Copilot Blog (Tech Community)**: https://techcommunity.microsoft.com/category/microsoft365copilot/blog/microsoft365copilotblog
- **Microsoft 365 Copilot – Microsoft Adoption**: https://adoption.microsoft.com/en-us/copilot/
- **Microsoft Copilot Blog**: https://www.microsoft.com/en-us/microsoft-copilot/blog/
- **Driving Microsoft 365 Copilot adoption with Copilot Champs Community**: https://www.microsoft.com/insidetrack/blog/driving-copilot-for-microsoft-365-adoption-with-our-copilot-champs-community/
- **Enabling meaningful AI adoption at Microsoft with Microsoft 365 Copilot Expo**: https://www.microsoft.com/insidetrack/blog/enabling-meaningful-AI adoption-at-microsoft-with-a-microsoft-365-copilot-expo/

---

## License & Usage

This framework and associated scripts are licensed under the MIT License with Attribution. Copyright (c) 2025 Nitron Digital LLC.

**License Terms:**

This software is provided subject to the following conditions:

1. **Attribution Requirement**: All use of this Software, whether in source or binary form, must include proper attribution to Nitron Digital LLC. This includes:
   - Including the copyright notice in all copies or substantial portions
   - Maintaining attribution in any modified versions or derivative works
   - Crediting Nitron Digital LLC as the original author in any documentation, publications, or materials that reference or incorporate this Software

2. **Commercial Use Requirement**: Any commercial use of this Software, including but not limited to use in commercial products, services, or for-profit activities, must explicitly reference Nitron Digital LLC. This reference must be:
   - Prominently displayed in any product documentation, user interfaces, or marketing materials that utilize this Software
   - Included in any licensing or attribution documentation for commercial products or services incorporating this Software
   - Maintained in any commercial distribution or deployment of this Software

**You may:**

- Use these tools for client assessments
- Customize scripts for specific client needs
- Brand deliverables with your company information
- Reference the framework in proposals and marketing
- Modify and distribute the software (with proper attribution)

**You may not:**

- Resell the framework itself as a product without attribution
- Share scripts publicly without proper attribution to Nitron Digital LLC
- Claim authorship of the methodology
- Use commercially without explicit reference to Nitron Digital LLC

For the complete license text, see the [LICENSE](LICENSE) file in this repository.

---

## Version History

**v1.0 (December 2025)**

- Initial framework release
- 4 core assessment scripts
- 6-dimension methodology
- Regulated industry focus

---

**Good luck with your Copilot assessments!**

@{
    RootModule        = 'CopilotReadiness.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '59a85f1b-d47f-4eec-9335-3b0e9f1d69a6'
    Author            = 'Nitron Digital LLC'
    CompanyName       = 'Nitron Digital LLC'
    Copyright         = '(c) Nitron Digital LLC. All rights reserved.'
    Description       = 'Microsoft Copilot readiness assessments with Graph authentication, GUI orchestration, and consolidated HTML reporting.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Connect-CRTenant',
        'Disconnect-CRTenant',
        'Invoke-CRAssessment',
        'Get-CRCAPolicyAssessment',
        'Get-CRExternalUserAccess',
        'Get-CRLabelCoverage',
        'Get-CROversharedContent',
        'Get-CRRetentionAssessment',
        'New-CRReadinessReport',
        'Show-CRGui'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    RequiredModules = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Identity.SignIns'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Sites'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Files'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion = '2.0.0' }
    )
}

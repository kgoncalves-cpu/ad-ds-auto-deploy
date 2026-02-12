@{
    # Informações do Módulo
    ModuleVersion = '2.2.0'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'BRMC IT Team'
    CompanyName = 'BRMC'
    Copyright = '(c) 2025 BRMC IT Team. All rights reserved.'
    Description = 'Active Directory Domain Controller deployment automation with modular architecture'
    
    # Requisitos PowerShell
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop')
    
    # Módulos Necessários
    RequiredModules = @(
        @{ModuleName='ActiveDirectory'; ModuleVersion='1.0.0.0'; Mandatory=$false}
        @{ModuleName='GroupPolicy'; ModuleVersion='1.0.0.0'; Mandatory=$false}
        @{ModuleName='DhcpServer'; ModuleVersion='1.0.0.0'; Mandatory=$false}
    )
    
    # Módulos de Script Internos
    NestedModules = @(
        'Modules/ADDeployment.Config.psm1'
        'Modules/ADDeployment.Validate.psm1'
        'Modules/ADDeployment.Setup.psm1'
        'Modules/ADDeployment.Install.psm1'
        'Modules/ADDeployment.PostConfig.psm1'
        'Modules/ADDeployment.Core.psm1'
    )
    
    # Funções Exportadas
    FunctionsToExport = @(
        # Config
        'Import-ADConfig'
        'Show-ADConfig'
        'Test-ADConfigStructure'
        'Get-ADExecutionMode'
        
        # Validate
        'Invoke-ADConfigValidation'
        'Get-ADDeploymentConfirmation'
        'Test-ADIPInSegment'
        
        # Setup
        'Invoke-ADServerSetup'
        
        # Install
        'Invoke-ADInstallation'
        
        # PostConfig
        'Invoke-ADPostConfiguration'
    )
    
    # Cmdlets Exportados
    CmdletsToExport = @()
    
    # Variáveis Exportadas
    VariablesToExport = @()
    
    # Aliases Exportados
    AliasesToExport = @()
    
    # Metadados Privados
    PrivateData = @{
        PSData = @{
            Tags = @(
                'ActiveDirectory'
                'DomainController'
                'Deployment'
                'Automation'
                'Windows'
                'Infrastructure'
            )
            
            LicenseUri = 'https://github.com/BLUTEK-Tecnologias-de-Informacao/ps-ad-ds-auto-in/blob/main/LICENSE'
            ProjectUri = 'https://github.com/BLUTEK-Tecnologias-de-Informacao/ps-ad-ds-auto-in'
            ReleaseNotes = 'See CHANGELOG.md'
            
            Prerelease = ''
            RequireLicenseAcceptance = $false
        }
    }
    
    # Requisitos de Plataforma
    HelpInfoUri = 'https://github.com/BLUTEK-Tecnologias-de-Informacao/ps-ad-ds-auto-in/wiki'
}
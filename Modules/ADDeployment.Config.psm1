<#
.SYNOPSIS
    Módulo de gerenciamento de configuração para AD Deployment
.DESCRIPTION
    Responsável por carregar, validar e exibir configurações do deployment
.NOTES
    Parte do ADDeployment Framework
    Versão: 1.0
#>

# Exportar funções públicas
Export-ModuleMember -Function @(
    'Import-ADConfig',
    'Show-ADConfig',
    'Test-ADConfigStructure',
    'Get-ADExecutionMode'
)
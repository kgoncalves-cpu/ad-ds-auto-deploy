<#
.SYNOPSIS
    Módulo de orquestração de configuração pós-instalação
.DESCRIPTION
    Orquestra funções dos Utilities.ADManagement e Utilities.ADPolicies
.NOTES
    Parte do ADDeployment Framework
    Versão: 1.1 - Refatorado com Utilities separados
#>

# =====================================================
# CARREGAR DEPENDÊNCIAS
# =====================================================

# Carregar utilitários de gerenciamento AD
. "$PSScriptRoot\..\Functions\Utilities.ADManagement.ps1"

# Carregar utilitários de políticas AD
. "$PSScriptRoot\..\Functions\Utilities.ADPolicies.ps1"

# =====================================================
# EXPORTAR FUNÇÕES PÚBLICAS
# =====================================================

Export-ModuleMember -Function @(
    # Gerenciamento
    'Invoke-ADDNSConfiguration',
    'New-ADOrganizationalUnitStructure',
    'New-ADSecurityGroups',
    'Get-ADUserPassword',
    'New-ADUsers',
    
    # Políticas
    'Set-ADPasswordPolicies',
    'Install-ADDHCPService',
    'Test-ADPostConfigValidation',
    
    # Orquestração
    'Invoke-ADPostConfiguration'
)
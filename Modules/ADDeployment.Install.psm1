<#
.SYNOPSIS
    Módulo de instalação e promoção de Active Directory
.DESCRIPTION
    Responsável por instalar AD-Domain-Services e promover servidor a Domain Controller
.NOTES
    Parte do ADDeployment Framework
    Versão: 1.1 - Correção de DomainMode/ForestMode
    Requer: Privilégios administrativos
    Aviso: Este módulo faz modificações profundas no sistema
#>
# Carregar utilitários de gerenciamento AD
. "$PSScriptRoot\..\Functions\Utilities.Install.ps1"
# =====================================================
# FUNÇÃO: Verificar Nome do Servidor
# =====================================================


# TODO : Implementar em Validations.ps1 como ADValidator::ValidateServerName()

function Test-ADServerNameApplied {
    <#
    .SYNOPSIS
        Verifica se o nome do servidor foi aplicado corretamente
    .DESCRIPTION
        Compara nome do computador com nome esperado da configuração
    .PARAMETER ExpectedName
        Nome esperado do servidor
    .PARAMETER Logger
        Objeto logger para registrar operações
    .OUTPUTS
        [bool] $true se nome foi aplicado
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExpectedName,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`nVerificando nome do servidor..." -ForegroundColor Yellow
        Write-Host "Nome esperado: $ExpectedName" -ForegroundColor Gray
        Write-Host "Nome atual: $env:COMPUTERNAME" -ForegroundColor Gray
        
        if ($env:COMPUTERNAME -ne $ExpectedName) {
            throw "Nome do servidor ainda não foi aplicado. Reinicie manualmente."
        }
        
        $Logger.Info("Nome do servidor confirmado: $env:COMPUTERNAME")
        Write-Host "✅ Nome do servidor confirmado" -ForegroundColor Green
        
        return $true
        
    } catch {
        $Logger.Error("Erro ao verificar nome do servidor: $_")
        throw
    }
}


# =====================================================
# EXPORTAR FUNÇÕES PÚBLICAS
# =====================================================

Export-ModuleMember -Function @(
    'Test-ADServerNameApplied',
    'Install-ADDomainServices',
    'Get-ADDSRMPassword',
    'Invoke-ADDSForestPromotion',
    'Invoke-ADInstallation'
)
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

# =====================================================
# FUNÇÃO: Verificar Nome do Servidor
# =====================================================

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
# FUNÇÃO: Instalar AD-Domain-Services
# =====================================================

function Install-ADDomainServices {
    <#
    .SYNOPSIS
        Instala o recurso AD-Domain-Services
    .DESCRIPTION
        Instala AD-Domain-Services com ferramentas de gerenciamento
    .PARAMETER Logger
        Objeto logger para registrar operações
    .PARAMETER State
        Objeto state para marcar instalação
    .OUTPUTS
        [hashtable] com resultado { Success, RestartNeeded, Message }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Logger,
        
        [Parameter(Mandatory = $true)]
        [object]$State
    )
    
    try {
        Write-Host "`nInstalando recursos AD-Domain-Services..." -ForegroundColor Yellow
        Write-Host "Aguarde, este processo pode levar alguns minutos..." -ForegroundColor Gray
        $Logger.Info("Iniciando instalação de AD-Domain-Services")
        
        # Instalar feature
        $installResult = Install-WindowsFeature `
            -Name AD-Domain-Services `
            -IncludeManagementTools `
            -ErrorAction Stop
        
        Write-Host ""
        
        if ($installResult.Success) {
            $Logger.Success("AD-Domain-Services instalado com sucesso")
            Write-Host "✅ AD-Domain-Services instalado com sucesso" -ForegroundColor Green
            
            # Verificar reboot necessário
            $restartNeeded = $installResult.RestartNeeded -eq "Yes"
            
            if ($restartNeeded) {
                $Logger.Warning("Reboot necessário para completar instalação")
                Write-Host "⚠️  Reboot será necessário após próxima etapa" -ForegroundColor Yellow
            }
            
            Write-Host "Próxima etapa: Configuração DSRM" -ForegroundColor Yellow
            $State.MarkADInstalled()
            
            return @{
                Success        = $true
                RestartNeeded  = $restartNeeded
                Message        = "AD-Domain-Services instalado com sucesso"
            }
        } else {
            throw "Falha na instalação: $($installResult.ExitCode)"
        }
        
    } catch {
        $Logger.Error("Erro ao instalar AD-Domain-Services: $_")
        throw
    }
}

# =====================================================
# FUNÇÃO: Obter Senha DSRM
# =====================================================

function Get-ADDSRMPassword {
    <#
    .SYNOPSIS
        Obtém a senha DSRM de forma segura
    .DESCRIPTION
        Obtém senha interativamente ou da configuração
    .PARAMETER ConfigPassword
        Senha DSRM da configuração (se fornecida)
    .PARAMETER EffectiveMode
        Modo de execução: Interactive ou Automated
    .PARAMETER Logger
        Objeto logger para registrar operações
    .OUTPUTS
        [SecureString] com a senha DSRM
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$ConfigPassword,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Interactive", "Automated")]
        [string]$EffectiveMode,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`nConfigurando senha DSRM..." -ForegroundColor Yellow
        
        # Se senha está na configuração
        if (-not [string]::IsNullOrWhiteSpace($ConfigPassword)) {
            $Logger.Success("Senha DSRM carregada da configuração")
            Write-Host "✅ Senha DSRM carregada da configuração" -ForegroundColor Green
            return (ConvertTo-SecureString $ConfigPassword -AsPlainText -Force)
        }
        
        # Se modo interativo, pedir ao usuário
        if ($EffectiveMode -eq "Interactive") {
            $Logger.Info("Solicitando senha DSRM ao usuário")
            
            do {
                $dsrmPassword = Read-Host "Digite a senha DSRM (mínimo 8 caracteres)" -AsSecureString
                $dsrmPasswordConfirm = Read-Host "Confirme a senha DSRM" -AsSecureString
                
                $dsrmPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($dsrmPassword))
                $dsrmConfirmPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($dsrmPasswordConfirm))
                
                if ($dsrmPlain -ne $dsrmConfirmPlain) {
                    Write-Host "❌ As senhas não coincidem" -ForegroundColor Red
                } elseif ($dsrmPlain.Length -lt 8) {
                    Write-Host "❌ A senha deve ter no mínimo 8 caracteres" -ForegroundColor Red
                } else {
                    Write-Host "✅ Senha DSRM confirmada" -ForegroundColor Green
                    $Logger.Success("Senha DSRM obtida e validada")
                    return $dsrmPassword
                }
                
            } while ($true)
        } else {
            # Modo automático sem senha configurada
            $Logger.Error("ERRO: Modo automático requer senha DSRM configurada")
            throw "Modo automático requer senha DSRM. Configure 'Passwords.DSRM' em Config\Default.psd1"
        }
        
    } catch {
        $Logger.Error("Erro ao obter senha DSRM: $_")
        throw
    }
}

# =====================================================
# FUNÇÃO: Promover a Domain Controller (CORRIGIDA v2)
# =====================================================

function Invoke-ADDSForestPromotion {
    <#
    .SYNOPSIS
        Promove o servidor a Domain Controller
    .DESCRIPTION
        Executa Install-ADDSForest com os parâmetros CORRETOS
    .PARAMETER Config
        Hashtable com configuração carregada
    .PARAMETER DSRMPassword
        SecureString com a senha DSRM
    .PARAMETER Logger
        Objeto logger para registrar operações
    .PARAMETER State
        Objeto state para marcar promoção
    .OUTPUTS
        [hashtable] com resultado { Success, Message }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [SecureString]$DSRMPassword,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger,
        
        [Parameter(Mandatory = $true)]
        [object]$State
    )
    
    try {
        Write-Host "`nPromovendo servidor a Domain Controller..." -ForegroundColor Yellow
        Write-Host "Este processo pode levar vários minutos..." -ForegroundColor Gray
        
        $Logger.Info("Iniciando promoção a Domain Controller para: $($Config.Domain.Name)")
        
        # ✅ VALIDAR VALORES ANTES DE USAR
        $forestModeValue = $Config.Advanced.ForestMode
        $domainModeValue = $Config.Advanced.DomainMode
        
        $Logger.Info("Parâmetros VALIDADOS:")
        $Logger.Info("  Domínio: $($Config.Domain.Name)")
        $Logger.Info("  NetBIOS: $($Config.Domain.NetBIOS)")
        $Logger.Info("  ForestMode: $forestModeValue (tipo: $($forestModeValue.GetType().Name))")
        $Logger.Info("  DomainMode: $domainModeValue (tipo: $($domainModeValue.GetType().Name))")
        
        # Carregar módulo ADDSDeployment
        Write-Host "`nCarregando módulo ADDSDeployment..." -ForegroundColor Gray
        Import-Module ADDSDeployment -ErrorAction Stop
        
        # ✅ EXECUTAR INSTALL-ADDSFOREST COM PARÂMETROS CORRETOS
        Write-Host "Executando Install-ADDSForest..." -ForegroundColor Gray
        
        # Usar hashtable para splatting (mais limpo e seguro)
        $addsParams = @{
            DomainName                 = $Config.Domain.Name
            DomainNetbiosName          = $Config.Domain.NetBIOS
            ForestMode                 = $forestModeValue
            DomainMode                 = $domainModeValue
            InstallDns                 = $true
            SafeModeAdministratorPassword = $DSRMPassword
            Force                      = $true
            NoRebootOnCompletion       = $false
        }
        
        Write-Host "Parâmetros do Install-ADDSForest:" -ForegroundColor Gray
        foreach ($key in $addsParams.Keys) {
            if ($key -eq "SafeModeAdministratorPassword") {
                Write-Host "  $key : [SecureString]" -ForegroundColor Gray
            } else {
                Write-Host "  $key : $($addsParams[$key])" -ForegroundColor Gray
            }
        }
        
        # Executar com splatting
        Install-ADDSForest @addsParams
        
        $Logger.Success("Domain Controller criado com sucesso")
        Write-Host "✅ Domain Controller criado com sucesso" -ForegroundColor Green
        
        $State.MarkADPromoted()
        $State.SetPhase(3)
        
        return @{
            Success = $true
            Message = "Domain Controller criado com sucesso"
        }
        
    } catch {
        $Logger.Error("Erro na promoção a Domain Controller: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
        throw
    }
}

# =====================================================
# FUNÇÃO: Executar FASE 3 Completa
# =====================================================

function Invoke-ADInstallation {
    <#
    .SYNOPSIS
        Executa toda a Fase 3 de instalação do AD
    .DESCRIPTION
        Instala AD-Domain-Services e promove servidor a Domain Controller
    .PARAMETER Config
        Hashtable com configuração carregada
    .PARAMETER Logger
        Objeto logger para registrar operações
    .PARAMETER State
        Objeto state para rastrear progresso
    .PARAMETER EffectiveMode
        Modo de execução: Interactive ou Automated
    .EXAMPLE
        Invoke-ADInstallation -Config $config -Logger $logger -State $state -EffectiveMode "Interactive"
    .OUTPUTS
        [hashtable] com resultado { Success, Message }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger,
        
        [Parameter(Mandatory = $true)]
        [object]$State,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Interactive", "Automated")]
        [string]$EffectiveMode
    )
    
    try {
        Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
        Write-Host "FASE 3: INSTALAÇÃO DO ACTIVE DIRECTORY" -ForegroundColor Yellow
        Write-Host ("=" * 64) -ForegroundColor Cyan
        
        $Logger.Info("Iniciando Fase 3: Instalação do Active Directory")
        
        # PASSO 1: Verificar nome do servidor
        Test-ADServerNameApplied -ExpectedName $Config.Server.Name -Logger $Logger
        
        # PASSO 2: Instalar AD-Domain-Services
        $installResult = Install-ADDomainServices -Logger $Logger -State $State
        
        # PASSO 3: Obter senha DSRM
        $dsrmPassword = Get-ADDSRMPassword -ConfigPassword $Config.Passwords.DSRM `
                                          -EffectiveMode $EffectiveMode `
                                          -Logger $Logger
        
        # PASSO 4: Promover a Domain Controller
        $promotionResult = Invoke-ADDSForestPromotion -Config $Config `
                                                     -DSRMPassword $dsrmPassword `
                                                     -Logger $Logger `
                                                     -State $State
        
        return @{
            Success = $true
            Message = "Fase 3 concluída com sucesso"
        }
        
    } catch {
        $Logger.Error("Erro na Fase 3: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
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
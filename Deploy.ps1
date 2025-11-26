#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Script de deployment de Active Directory Domain Controller
.DESCRIPTION
    Implementação modular e configurável de Domain Controller com automação.
    
.PARAMETER ConfigFile
    Caminho para o arquivo de configuração (padrão: Config/Default.psd1)
    
.PARAMETER Mode
    Modo de execução: Interactive ou Automated
    
.PARAMETER AutoContinue
    Ativar continuação automática após reboot (padrão: $false)
    
.EXAMPLE
    # Para execução PADRÃO (com prompts, reboots manuais)
    .\Deploy.ps1 -ConfigFile .\Config\Default.psd1 -AutoContinue

    # Para execução INTERATIVA (com prompts, reboots manuais)
    .\Deploy.ps1 -ConfigFile .\Config\Default.psd1 -Mode Interactive -AutoContinue

    # Para execução AUTOMÁTICA (sem prompts, reboots automáticos)
    .\Deploy.ps1 -ConfigFile .\Config\Default.psd1 -Mode Automated -AutoContinue
    
.NOTES
    Autor: BRMC IT Team
    Versão: 2.2 com Correção de CIDR
    Requer: Windows Server 2022
#>

param(
    [string]$ConfigFile = "$PSScriptRoot\Config\Default.psd1",
    [string]$Mode = "Interactive",
    [switch]$AutoContinue
)

# =====================================================
# INICIALIZAÇÃO
# =====================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Converter booleano para string (compatível com PS 5.0)
$autoContinueStatus = if ($AutoContinue) { 'Ativo' } else { 'Inativo' }

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  DEPLOYMENT DE ACTIVE DIRECTORY - VERSÃO 2.2 CORRIGIDA     ║" -ForegroundColor Cyan
Write-Host "║  Modo: $Mode | AutoContinue: $autoContinueStatus           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# =====================================================
# CARREGAR FUNÇÕES (DOTTED SOURCING)
# =====================================================

Write-Host "`nCarregando funções..." -ForegroundColor Yellow

try {
    . "$PSScriptRoot\Functions\Logging.ps1" -ErrorAction Stop
    Write-Host "Logging.ps1 carregado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao carregar Logging.ps1: $_" -ForegroundColor Red
    exit 1
}

try {
    . "$PSScriptRoot\Functions\StateManagement.ps1" -ErrorAction Stop
    Write-Host "StateManagement.ps1 carregado" -ForegroundColor Green
} catch {
    Write-Host "Aviso: StateManagement.ps1 não encontrado" -ForegroundColor Yellow
}

try {
    . "$PSScriptRoot\Functions\Utilities.ps1" -ErrorAction Stop
    Write-Host "Utilities.ps1 carregado" -ForegroundColor Green
} catch {
    Write-Host "Aviso: Utilities.ps1 não encontrado (não crítico)" -ForegroundColor Yellow
}

# =====================================================
# CRIAR LOGGER E STATE MANAGER
# =====================================================

$logPath = "$PSScriptRoot\Logs\ADDeployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$statePath = "$PSScriptRoot\Logs\ADDeployment.state"

try {
    $logger = [ADLogger]::new($logPath, $true, $true)
    $logger.Info("═══════════════════════════════════════════════════════════")
    $logger.Info("DEPLOYMENT DE ACTIVE DIRECTORY - VERSÃO 2.2 CORRIGIDA")
    $logger.Info("Modo: $Mode | AutoContinue: $autoContinueStatus")
    $logger.Info("═══════════════════════════════════════════════════════════")
    Write-Host "Logger inicializado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao criar logger: $_" -ForegroundColor Red
    exit 1
}

# Carregar estado
$state = [DeploymentState]::new($statePath)
$currentPhase = $state.GetPhase()

if ($currentPhase -gt 0) {
    Write-Host "`nEstado anterior detectado:" -ForegroundColor Yellow
    Write-Host "Fase atual: $currentPhase" -ForegroundColor Gray
    $logger.Info("Estado anterior carregado - Fase: $currentPhase")
}

# =====================================================
# DETERMINAR MODO DE EXECUÇÃO (APÓS LOGGER)
# =====================================================

$isAutomaticExecution = -not ([Environment]::UserInteractive)
$effectiveMode = if ($isAutomaticExecution -and $AutoContinue) { "Automated" } else { $Mode }

if ($effectiveMode -eq "Automated") {
    Write-Host "Modo AUTOMÁTICO detectado (pós-reboot) - sem prompts interativos" -ForegroundColor Yellow
    $logger.Info("Modo de execução: AUTOMÁTICO (detecção de reboot)")
} else {
    Write-Host "Modo INTERATIVO - aguardando confirmações do usuário" -ForegroundColor White
    $logger.Info("Modo de execução: INTERATIVO")
}

# =====================================================
# CARREGAR MÓDULOS
# =====================================================

Write-Host "`nCarregando módulos..." -ForegroundColor Yellow
# ADDeployment.Config
try {
    Import-Module "$PSScriptRoot\Modules\ADDeployment.Config.psm1" -ErrorAction Stop
    Write-Host "ADDeployment.Config carregado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao carregar ADDeployment.Config: $_" -ForegroundColor Red
    exit 1
}
# ADDeployment.Validate
try {
    Import-Module "$PSScriptRoot\Modules\ADDeployment.Validate.psm1" -ErrorAction Stop
    Write-Host "ADDeployment.Validate carregado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao carregar ADDeployment.Validate: $_" -ForegroundColor Red
    exit 1
}
# ADDeployment.Setup
try {
    Import-Module "$PSScriptRoot\Modules\ADDeployment.Setup.psm1" -ErrorAction Stop
    Write-Host "ADDeployment.Setup carregado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao carregar ADDeployment.Setup: $_" -ForegroundColor Red
    exit 1
}
# ADDeployment.Install
try {
    Import-Module "$PSScriptRoot\Modules\ADDeployment.Install.psm1" -ErrorAction Stop
    Write-Host "ADDeployment.Install carregado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao carregar ADDeployment.Install: $_" -ForegroundColor Red
    exit 1
}

# =====================================================
# CARREGAR CONFIGURAÇÃO (NOVO FLUXO)
# =====================================================

Write-Host "`nCarregando configuração..." -ForegroundColor Yellow

try {
    # Carregar config via módulo
    $config = Import-ADConfig -ConfigFile $ConfigFile -Logger $logger
    
    # Validar estrutura
    Test-ADConfigStructure -Config $config -Logger $logger
    
    # Exibir configuração
    Show-ADConfig -Config $config -Logger $logger
    
} catch {
    $logger.Error("Erro ao carregar configuração: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
    exit 1
}

# =====================================================
# DETERMINAR MODO DE EXECUÇÃO (ATUALIZADO)
# =====================================================

$effectiveMode = Get-ADExecutionMode -Mode $Mode -AutoContinue $AutoContinue -Logger $logger

# =====================================================
# VALIDAÇÕES (APENAS NA PRIMEIRA EXECUÇÃO)
# =====================================================
if ($currentPhase -eq 0) {
    try {
        # Validar configuração via módulo
        Invoke-ADConfigValidation -Config $config -Logger $logger
        
        # Obter confirmação do usuário
        $confirmed = Get-ADDeploymentConfirmation -Config $config -EffectiveMode $effectiveMode -Logger $logger
        
        if (-not $confirmed) {
            Write-Host "`nOperação cancelada" -ForegroundColor Yellow
            exit 0
        }
        
    } catch {
        $logger.Error("Erro na validação: $_")
        Write-Host "Erro: $_" -ForegroundColor Red
        exit 1
    }
    
    # Se modo AutoContinue, criar tarefa agendada
    if ($AutoContinue) {
        Write-Host "`nAutomação ativa: Script será retomado automaticamente após reboot" -ForegroundColor Green
        $logger.Info("AutoContinue: Criando tarefa no Task Scheduler")
        
        try {
            $taskName = "ADDeployment-AutoContinue"
            $taskPath = "\ADDeployment\"
            $scriptPath = $PSCommandPath
            $configPath = $ConfigFile
            
            Write-Host "Criando tarefa no Task Scheduler..." -ForegroundColor Yellow
            
            # Remover tarefa anterior se existir
            try {
                Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
                $logger.Info("Tarefa anterior removida")
                Start-Sleep -Seconds 2
            } catch {
                # Tarefa não existe, continuar
            }
            
            # =====================================================
            # USAR POWERSHELL DIRETO (SEM BATCH - MAIS CONFIÁVEL)
            # =====================================================
            
            # Obter caminho absoluto do script
            $scriptPathAbsolute = if ([System.IO.Path]::IsPathRooted($scriptPath)) {
                $scriptPath
            } else {
                Join-Path -Path $PSScriptRoot -ChildPath $scriptPath
            }
            
            # Obter caminho absoluto da configuração
            $configPathAbsolute = if ([System.IO.Path]::IsPathRooted($configPath)) {
                $configPath
            } else {
                Join-Path -Path $PSScriptRoot -ChildPath $configPath
            }
            
            # Caminho do executor (wrapper)
            $taskExecutorPath = Join-Path -Path $PSScriptRoot -ChildPath "Functions\TaskExecutor.ps1"
            
            $logger.Info("Caminhos da tarefa:")
            $logger.Info("  Executor: $taskExecutorPath")
            $logger.Info("  Script: $scriptPathAbsolute")
            $logger.Info("  Config: $configPathAbsolute")
            
            # ✅ Criar ação PowerShell com executor wrapper - COM JANELA VISÍVEL
            $action = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "-ExecutionPolicy Bypass -NoProfile -NoExit -File `"$taskExecutorPath`" -ScriptPath `"$scriptPathAbsolute`" -ConfigPath `"$configPathAbsolute`" -Mode `"$Mode`" -AutoContinue"
            
            # Criar trigger para executar no logon (com delay)
            $trigger = New-ScheduledTaskTrigger -AtLogOn -RandomDelay (New-TimeSpan -Seconds 30)
            
            # ✅ CONFIGURAÇÕES CORRIGIDAS PARA MOSTRAR JANELA
            $settings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -StartWhenAvailable `
                -MultipleInstances IgnoreNew `
                -ExecutionTimeLimit (New-TimeSpan -Hours 2)
            
            # ✅ Registrar tarefa
            Register-ScheduledTask `
                -TaskName $taskName `
                -TaskPath $taskPath `
                -Action $action `
                -Trigger $trigger `
                -Settings $settings `
                -RunLevel Highest `
                -Force `
                -ErrorAction Stop
            
            # ✅ Aguardar registro
            Start-Sleep -Seconds 2
            
            # ✅ Recuperar a tarefa já criada
            $task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
            
            if ($null -ne $task) {
                $logger.Info("Tarefa registrada com sucesso")
                Write-Host "Tarefa de automação criada com sucesso" -ForegroundColor Green
                
                # ✅ INFORMAÇÕES FINAIS
                $logger.Info("Task Scheduler Details:")
                $logger.Info("  Nome: $taskName")
                $logger.Info("  Caminho: $taskPath")
                $logger.Info("  Executor: powershell.exe")
                $logger.Info("  Trigger: AtLogOn com delay de 30 segundos")
                Write-Host "`n✅ Tarefa será executada automaticamente após o próximo logon" -ForegroundColor Green
            } else {
                throw "Falha ao verificar tarefa após registro"
            }
        } catch {
            $logger.Warning("Erro ao criar Task Scheduler: $_")
            Write-Host "Aviso: Task Scheduler pode não ter sido criada corretamente." -ForegroundColor Yellow
            Write-Host "Será necessário executar o script manualmente após o reboot." -ForegroundColor Yellow
        }
    }
    
    $state.SetPhase(1)
    Write-Host "`nImplementação iniciada" -ForegroundColor Green
}

Write-Host "`nContinuando com a implementação..." -ForegroundColor White
Start-Sleep -Seconds 2

# =====================================================
# FASE 2: PREPARAÇÃO DO SERVIDOR
# =====================================================

try {
    $setupResult = Invoke-ADServerSetup -Config $config `
                                       -Logger $logger `
                                       -State $state `
                                       -EffectiveMode $effectiveMode
    
    if (-not $setupResult.Success) {
        throw $setupResult.Message
    }
    
} catch {
    $logger.Error("Erro na Fase 2: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
    exit 1
}
# =====================================================
# FASE 3: INSTALAÇÃO DO ACTIVE DIRECTORY
# =====================================================

try {
    $installResult = Invoke-ADInstallation -Config $config `
                                          -Logger $logger `
                                          -State $state `
                                          -EffectiveMode $effectiveMode
    
    if (-not $installResult.Success) {
        throw $installResult.Message
    }
    
} catch {
    $logger.Error("Erro na Fase 3: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
    exit 1
}
# =====================================================
# FINALIZAÇÃO
# =====================================================

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
Write-Host "PRÓXIMA ETAPA: PÓS-INSTALAÇÃO" -ForegroundColor Yellow
Write-Host ("=" * 64) -ForegroundColor Cyan

$logger.Info("═══════════════════════════════════════════════════════════")
$logger.Info("Fases 1-3 concluídas com sucesso")
$logger.Info("Execute Deploy-Part2.ps1 após o reboot")
$logger.Info("═══════════════════════════════════════════════════════════")

Write-Host "`nO servidor será reiniciado automaticamente" -ForegroundColor Yellow
Write-Host "`nApós a reinicialização:" -ForegroundColor White
Write-Host "1. Aguarde 10 minutos para os serviços do AD iniciarem" -ForegroundColor Gray
Write-Host "2. Faça login como $($config.Domain.NetBIOS)\Administrator" -ForegroundColor Gray
Write-Host "3. Execute: .\Deploy-Part2.ps1 -ConfigFile .\Config\Default.psd1" -ForegroundColor Gray
Write-Host "`nLogs: $logPath" -ForegroundColor Gray

Read-Host "`nPressione ENTER para finalizar"

# =====================================================
# DEBUG: Verificar valores carregados
# =====================================================

Write-Host "`n[DEBUG] Valores carregados de Config:" -ForegroundColor Cyan
Write-Host "  Network.Segments[0].Network: $($config.Network.Segments[0].Network)" -ForegroundColor Gray
Write-Host "  Network.Segments[0].CIDR: $($config.Network.Segments[0].CIDR)" -ForegroundColor Gray
Write-Host "  Network.Segments[0].Mask: $($config.Network.Segments[0].Mask)" -ForegroundColor Gray
Write-Host "  Network.ServerIP: $($config.Network.ServerIP)" -ForegroundColor Gray

$logger.Info("[DEBUG] Valores de configuração finais:")
$logger.Info("  Network.Segments[0].Network: $($config.Network.Segments[0].Network)")
$logger.Info("  Network.Segments[0].CIDR: $($config.Network.Segments[0].CIDR)")
$logger.Info("  Network.Segments[0].Mask: $($config.Network.Segments[0].Mask)")
$logger.Info("  Network.ServerIP: $($config.Network.ServerIP)")

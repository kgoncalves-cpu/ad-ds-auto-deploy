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
    . "$PSScriptRoot\Functions\Validation.ps1" -ErrorAction Stop
    Write-Host "Validation.ps1 carregado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao carregar Validation.ps1: $_" -ForegroundColor Red
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
# CARREGAR CONFIGURAÇÃO
# =====================================================

Write-Host "`nCarregando configuração..." -ForegroundColor Yellow

try {
    if (-not (Test-Path $ConfigFile)) {
        throw "Arquivo de configuração não encontrado: $ConfigFile"
    }
    
    $config = Import-PowerShellDataFile -Path $ConfigFile
    $logger.Success("Configuração carregada: $ConfigFile")
    Write-Host "Configuração carregada com sucesso" -ForegroundColor Green
} catch {
    $logger.Error("Erro ao carregar configuração: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
    exit 1
}

# =====================================================
# EXIBIR CONFIGURAÇÃO
# =====================================================

Write-Host "`nConfigração Carregada:" -ForegroundColor Yellow
Write-Host "Domínio: $($config.Domain.Name)" -ForegroundColor Gray
Write-Host "NetBIOS: $($config.Domain.NetBIOS)" -ForegroundColor Gray
Write-Host "Servidor: $($config.Server.Name)" -ForegroundColor Gray
Write-Host "IP: $($config.Network.ServerIP)" -ForegroundColor Gray
Write-Host "CIDR: $($config.Network.Segments[0].CIDR)" -ForegroundColor Gray
Write-Host "Máscara: $($config.Network.Segments[0].Mask)" -ForegroundColor Gray
Write-Host "DHCP: $(if($config.Services.InstallDHCP){'Sim'}else{'Não'})" -ForegroundColor Gray

# =====================================================
# VALIDAÇÕES (APENAS NA PRIMEIRA EXECUÇÃO)
# =====================================================

if ($currentPhase -eq 0) {
    Write-Host "`nValidando configuração..." -ForegroundColor Yellow
    
    try {
        if (-not [ADValidator]::ValidateDomainName($config.Domain.Name)) {
            throw "Nome de domínio inválido: $($config.Domain.Name)"
        }
        Write-Host "Domínio válido" -ForegroundColor Green
        
        if (-not [ADValidator]::ValidateIPAddress($config.Network.ServerIP)) {
            throw "IP do servidor inválido: $($config.Network.ServerIP)"
        }
        Write-Host "IP válido" -ForegroundColor Green
        
        foreach ($segment in $config.Network.Segments) {
            if (-not [ADValidator]::ValidateIPAddress($segment.Network)) {
                throw "IP de rede inválido: $($segment.Network)"
            }
        }
        Write-Host "Rede válida" -ForegroundColor Green
        
        #NOVA VALIDAÇÃO: Verificar consistência entre CIDR e Máscara
        Write-Host "`nValidando consistência entre CIDR e máscara..." -ForegroundColor Yellow
        
        foreach ($segment in $config.Network.Segments) {
            $calculatedMask = [ADValidator]::ConvertCIDRToMask($segment.CIDR)
            
            if ([string]::IsNullOrEmpty($calculatedMask)) {
                throw "CIDR inválido: $($segment.CIDR). Deve estar entre 0 e 32"
            }
            
            if ($calculatedMask -ne $segment.Mask) {
                $logger.Warning("Inconsistência detectada: CIDR $($segment.CIDR) deveria gerar máscara $calculatedMask, mas config contém $($segment.Mask)")
                Write-Host "Aviso: Máscara de config será substituída pela calculada" -ForegroundColor Yellow
                $segment.Mask = $calculatedMask
            }
        }
        
        Write-Host "Validação de CIDR/Máscara concluída" -ForegroundColor Green
        
    } catch {
        $logger.Error("Erro na validação: $_")
        Write-Host "Erro: $_" -ForegroundColor Red
        exit 1
    }
    
    # ================================================
    # CONFIRMAÇÃO (APENAS PRIMEIRA EXECUÇÃO)
    # ================================================
    
    if ($effectiveMode -eq "Interactive") {
        Write-Host ("`n" + ("=" * 64)) -ForegroundColor Cyan
        $response = Read-Host "Deseja continuar com a implementação? (S/N)"
        
        if ($response -ne 'S' -and $response -ne 's') {
            $logger.Warning("Implementação cancelada pelo usuário")
            Write-Host "`nOperação cancelada" -ForegroundColor Yellow
            exit 0
        }
    } else {
        Write-Host ("`n" + ("=" * 64)) -ForegroundColor Cyan
        Write-Host "Modo AUTOMÁTICO - continuando sem confirmação..." -ForegroundColor Green
        $logger.Info("Modo automático: continuando sem prompt de usuário")
        Start-Sleep -Seconds 3
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

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
Write-Host "FASE 2: PREPARAÇÃO DO SERVIDOR" -ForegroundColor Yellow
Write-Host ("=" * 64) -ForegroundColor Cyan

$logger.Info("Iniciando Fase 2: Preparação do Servidor")

try {
    # 2.1 - Renomear servidor
    if ($env:COMPUTERNAME -ne $config.Server.Name) {
        Write-Host "`nRenomeando servidor..." -ForegroundColor Yellow
        $logger.Info("Renomeando servidor de $($env:COMPUTERNAME) para $($config.Server.Name)")
        
        Rename-Computer -NewName $config.Server.Name -Force -ErrorAction Stop
        $logger.Success("Servidor renomeado com sucesso")
        Write-Host "Servidor renomeado: $($config.Server.Name)" -ForegroundColor Green
        
        $state.MarkRenameApplied()
        
        Write-Host "`n" + ("=" * 64) -ForegroundColor Red
        Write-Host "REBOOT OBRIGATÓRIO #1 - RENAME DO SERVIDOR" -ForegroundColor Red
        Write-Host ("=" * 64) -ForegroundColor Red
        
        Write-Host "`nO Windows exige um reboot para aplicar a mudança de nome" -ForegroundColor White

        $rebootChoice = if ($effectiveMode -eq "Interactive") {
            Read-Host "`nDeseja reiniciar agora? (S/N)"
        } else {
            Write-Host "`nModo AUTOMÁTICO: Reiniciando automaticamente em 10 segundos..." -ForegroundColor Yellow
            $logger.Info("Reboot automático em 10 segundos (modo automático)")
            "S"  # Simula "Sim"
        }
        
        if ($rebootChoice -eq 'S' -or $rebootChoice -eq 's') {
            $logger.Info("Iniciando reboot #1 em 10 segundos")
            Write-Host "`nServidor será reiniciado em 10 segundos..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        } else {
            Write-Host "`nReinicie manualmente o servidor para continuar" -ForegroundColor Yellow
            $logger.Warning("Reboot adiado pelo usuário")
            exit 0
        }
        exit 0
    } else {
        $logger.Info("Servidor já possui o nome correto: $($config.Server.Name)")
        Write-Host "Servidor já possui o nome correto: $($config.Server.Name)" -ForegroundColor Green
        $state.MarkRenameApplied()
    }
    
    # 2.2 - Configurar IP estático (APÓS rename ter sido aplicado)
    Write-Host "`nConfigurando IP estático..." -ForegroundColor Yellow
    $logger.Info("Configurando IP estático: $($config.Network.ServerIP)")
    
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    
    if ($null -eq $adapter) {
        throw "Nenhum adaptador de rede ativo encontrado"
    }
    
    Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    
    # ✅ CORREÇÃO: Garantir que CIDR é válido antes de usar
    $segment = $config.Network.Segments[0]
    $prefixLength = $segment.CIDR
    
    # Validar que o CIDR está entre 0-32
    if ($prefixLength -lt 0 -or $prefixLength -gt 32) {
        throw "CIDR inválido: $prefixLength. Deve estar entre 0 e 32"
    }
    
    $gateway = $segment.Gateway
    $dnsServers = @($config.Network.PrimaryDNS, $config.Network.SecondaryDNS)
    
    $logger.Info("Configurações de rede:")
    $logger.Info("  IP: $($config.Network.ServerIP)")
    $logger.Info("  CIDR/PrefixLength: $prefixLength")
    $logger.Info("  Máscara: $($segment.Mask)")
    $logger.Info("  Gateway: $gateway")
    
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex `
                    -IPAddress $config.Network.ServerIP `
                    -PrefixLength $prefixLength `
                    -DefaultGateway $gateway -ErrorAction Stop
    
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex `
                               -ServerAddresses $dnsServers -ErrorAction Stop
    
    # ✅ VALIDAÇÃO PÓS-APLICAÇÃO: Verificar se foi aplicado corretamente
    Write-Host "`nValidando configuração de IP aplicada..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    $appliedIP = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    
    if ($appliedIP.IPAddress -eq $config.Network.ServerIP) {
        $logger.Success("IP aplicado corretamente: $($appliedIP.IPAddress)/$($appliedIP.PrefixLength)")
        Write-Host "IP aplicado corretamente: $($appliedIP.IPAddress)/$($appliedIP.PrefixLength)" -ForegroundColor Green
        
        # ✅ Verificar se o PrefixLength está correto
        if ($appliedIP.PrefixLength -ne $prefixLength) {
            $logger.Warning("AVISO: PrefixLength foi alterado pelo Windows!")
            $logger.Warning("  Esperado: $prefixLength")
            $logger.Warning("  Aplicado: $($appliedIP.PrefixLength)")
            Write-Host "AVISO: PrefixLength alterado! Esperado: $prefixLength, Aplicado: $($appliedIP.PrefixLength)" -ForegroundColor Red
            
            # Tentar corrigir se foi alterado
            if ($appliedIP.PrefixLength -ne $prefixLength) {
                Write-Host "Tentando corrigir PrefixLength..." -ForegroundColor Yellow
                Remove-NetIPAddress -IPAddress $config.Network.ServerIP -Confirm:$false -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
                New-NetIPAddress -InterfaceIndex $adapter.ifIndex `
                                -IPAddress $config.Network.ServerIP `
                                -PrefixLength $prefixLength `
                                -DefaultGateway $gateway -ErrorAction Stop
                $logger.Info("PrefixLength reconfigurado")
            }
        }
    } else {
        throw "IP não foi aplicado corretamente. Esperado: $($config.Network.ServerIP), Obtido: $($appliedIP.IPAddress)"
    }
    
    $logger.Success("IP estático configurado: $($config.Network.ServerIP)/$prefixLength")
    Write-Host "IP estático configurado com sucesso" -ForegroundColor Green
    
    $state.SetPhase(2)
    
} catch {
    $logger.Error("Erro na Fase 2: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
    exit 1
}

# =====================================================
# FASE 3: INSTALAÇÃO DO ACTIVE DIRECTORY
# =====================================================

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
Write-Host "FASE 3: INSTALAÇÃO DO ACTIVE DIRECTORY" -ForegroundColor Yellow
Write-Host ("=" * 64) -ForegroundColor Cyan

$logger.Info("Iniciando Fase 3: Instalação do Active Directory")

try {
    # Verificar nome do servidor
    Write-Host "`nVerificando nome do servidor..." -ForegroundColor Yellow
    Write-Host "Nome atual: $env:COMPUTERNAME" -ForegroundColor Gray
    
    if ($env:COMPUTERNAME -ne $config.Server.Name) {
        throw "Nome do servidor ainda não foi aplicado. Reinicie manualmente."
    }
    
    $logger.Info("Nome do servidor confirmado: $env:COMPUTERNAME")
    Write-Host "Nome do servidor confirmado" -ForegroundColor Green
    
    # Instalar recursos
    Write-Host "`nInstalando recursos AD-Domain-Services..." -ForegroundColor Yellow
    Write-Host "Aguarde, este processo pode levar alguns minutos..." -ForegroundColor Gray
    $logger.Info("Iniciando instalação de AD-Domain-Services")
    
    # ✅ CORRETO: Sem -NoRestart (não existe), sem -Restart (você quer controlar reboots)
    $installResult = Install-WindowsFeature `
        -Name AD-Domain-Services `
        -IncludeManagementTools `
        -ErrorAction Stop
    
    Write-Host ""
    
    if ($installResult.Success) {
        $logger.Success("AD-Domain-Services instalado com sucesso")
        Write-Host "✅ AD-Domain-Services instalado com sucesso" -ForegroundColor Green
        
        # ✅ Verificar se reboot é necessário
        if ($installResult.RestartNeeded -eq "Yes") {
            $logger.Warning("Reboot necessário para completar instalação")
            Write-Host "⚠️  Reboot será necessário após próxima etapa" -ForegroundColor Yellow
        }
        
        Write-Host "Próxima etapa: Configuração DSRM" -ForegroundColor Yellow
        $state.MarkADInstalled()
    } else {
        $logger.Error("Falha na instalação: $($installResult.ExitCode)")
        Write-Host "❌ Falha na instalação" -ForegroundColor Red
        throw "Install-WindowsFeature falhou com código: $($installResult.ExitCode)"
    }
    
    # Solicitar senha DSRM
    Write-Host "`nConfigurando senha DSRM..." -ForegroundColor Yellow
    
    if ([string]::IsNullOrWhiteSpace($config.Passwords.DSRM)) {
        if ($effectiveMode -eq "Interactive") {
            do {
                $dsrmPassword = Read-Host "Digite a senha DSRM (mínimo 8 caracteres)" -AsSecureString
                $dsrmPasswordConfirm = Read-Host "Confirme a senha DSRM" -AsSecureString
                
                $dsrmPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($dsrmPassword))
                $dsrmConfirmPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($dsrmPasswordConfirm))
                
                if ($dsrmPlain -ne $dsrmConfirmPlain) {
                    Write-Host "As senhas não coincidem" -ForegroundColor Yellow
                } elseif ($dsrmPlain.Length -lt 8) {
                    Write-Host "A senha deve ter no mínimo 8 caracteres" -ForegroundColor Yellow
                }
            } while ($dsrmPlain -ne $dsrmConfirmPlain -or $dsrmPlain.Length -lt 8)
        } else {
            $logger.Error("ERRO: Modo automático requer senha DSRM configurada em Config")
            Write-Host "ERRO: Senha DSRM não configurada para modo automático" -ForegroundColor Red
            Write-Host "Configure 'Passwords.DSRM' em Config\Default.psd1" -ForegroundColor Yellow
            exit 1
        }
    } else {
        $dsrmPassword = ConvertTo-SecureString $config.Passwords.DSRM -AsPlainText -Force
        Write-Host "Senha DSRM carregada da configuração" -ForegroundColor Green
    }
    
    # Promover a Domain Controller
    Write-Host "`nPromovendo servidor a Domain Controller..." -ForegroundColor Yellow
    Write-Host "Este processo pode levar vários minutos..." -ForegroundColor Gray
    
    $logger.Info("Iniciando promoção a Domain Controller para: $($config.Domain.Name)")
    
    Import-Module ADDSDeployment -ErrorAction Stop
    
    Install-ADDSForest `
        -DomainName $config.Domain.Name `
        -DomainNetbiosName $config.Domain.NetBIOS `
        -ForestMode $config.Advanced.ForestMode `
        -DomainMode $config.Advanced.DomainMode `
        -InstallDns:$true `
        -SafeModeAdministratorPassword $dsrmPassword `
        -Force:$true `
        -NoRebootOnCompletion:$false
    
    $logger.Success("Domain Controller criado com sucesso")
    Write-Host "Domain Controller criado com sucesso" -ForegroundColor Green
    $state.MarkADPromoted()
    $state.SetPhase(3)
    
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

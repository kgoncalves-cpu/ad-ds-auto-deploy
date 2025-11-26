#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Parte 2 - Configuração pós-instalação do Active Directory
.DESCRIPTION
    Realiza configuração pós-instalação: OUs, usuários, grupos, GPOs, DNS, DHCP, etc.
    
.PARAMETER ConfigFile
    Caminho para o arquivo de configuração (padrão: Config/Default.psd1)
    
.NOTES
    Autor: BRMC IT Team
    Versão: 2.1 - Refatorado com módulos
    Requer: Windows Server 2022 com AD DS instalado
#>

param(
    [string]$ConfigFile = "$PSScriptRoot\Config\Default.psd1"
)

# =====================================================
# INICIALIZAÇÃO
# =====================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CONFIGURAÇÃO PÓS-INSTALAÇÃO - VERSÃO 2.1 MODULAR         ║" -ForegroundColor Cyan
Write-Host "║  Parte 2 - Após Domain Controller                          ║" -ForegroundColor Cyan
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

# =====================================================
# CRIAR LOGGER
# =====================================================

$logsDir = "$PSScriptRoot\Logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

$logPath = "$logsDir\ADDeployment_Part2_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

try {
    $logger = [ADLogger]::new($logPath, $true, $true)
    $logger.Info("═══════════════════════════════════════════════════════════")
    $logger.Info("CONFIGURAÇÃO PÓS-INSTALAÇÃO - VERSÃO 2.1 MODULAR")
    $logger.Info("Parte 2 - Após Domain Controller")
    $logger.Info("═══════════════════════════════════════════════════════════")
    Write-Host "Logger inicializado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao criar logger: $_" -ForegroundColor Red
    exit 1
}

# =====================================================
# CARREGAR MÓDULOS
# =====================================================

Write-Host "`nCarregando módulos..." -ForegroundColor Yellow

try {
    Import-Module "$PSScriptRoot\Modules\ADDeployment.Validate.psm1" -ErrorAction Stop
    Write-Host "ADDeployment.Validate carregado" -ForegroundColor Green
    $logger.Info("ADDeployment.Validate carregado")
} catch {
    Write-Host "Erro ao carregar ADDeployment.Validate: $_" -ForegroundColor Red
    $logger.Error("Erro ao carregar ADDeployment.Validate: $_")
    exit 1
}

try {
    Import-Module "$PSScriptRoot\Modules\ADDeployment.Config.psm1" -ErrorAction Stop
    Write-Host "ADDeployment.Config carregado" -ForegroundColor Green
    $logger.Info("ADDeployment.Config carregado")
} catch {
    Write-Host "Erro ao carregar ADDeployment.Config: $_" -ForegroundColor Red
    $logger.Error("Erro ao carregar ADDeployment.Config: $_")
    exit 1
}

try {
    Import-Module "$PSScriptRoot\Modules\ADDeployment.PostConfig.psm1" -ErrorAction Stop
    Write-Host "ADDeployment.PostConfig carregado" -ForegroundColor Green
    $logger.Info("ADDeployment.PostConfig carregado")
} catch {
    Write-Host "Erro ao carregar ADDeployment.PostConfig: $_" -ForegroundColor Red
    $logger.Error("Erro ao carregar ADDeployment.PostConfig: $_")
    exit 1
}

# =====================================================
# CARREGAR CONFIGURAÇÃO
# =====================================================

Write-Host "`nCarregando configuração..." -ForegroundColor Yellow

try {
    if (-not (Test-Path $ConfigFile)) {
        throw "Arquivo de configuração não encontrado: $ConfigFile"
    }
    
    $config = Import-ADConfig -ConfigFile $ConfigFile -Logger $logger
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

Write-Host "`nConfigração para Pós-Instalação:" -ForegroundColor Yellow
Write-Host "Domínio: $($config.Domain.Name)" -ForegroundColor Gray
Write-Host "NetBIOS: $($config.Domain.NetBIOS)" -ForegroundColor Gray
Write-Host "Servidor: $($config.Server.Name)" -ForegroundColor Gray
Write-Host "IP: $($config.Network.ServerIP)" -ForegroundColor Gray

# =====================================================
# AGUARDAR SERVIÇOS DO AD
# =====================================================

Write-Host "`nAguardando serviços do Active Directory..." -ForegroundColor Yellow
$logger.Info("Aguardando serviços do AD iniciarem")
Start-Sleep -Seconds 30
Write-Host "Serviços do AD prontos" -ForegroundColor Green

# =====================================================
# IMPORTAR MÓDULOS DO AD
# =====================================================

Write-Host "`nImportando módulos do Active Directory..." -ForegroundColor Yellow

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module GroupPolicy -ErrorAction Stop
    $logger.Success("Módulos ActiveDirectory e GroupPolicy importados")
    Write-Host "Módulos importados com sucesso" -ForegroundColor Green
} catch {
    $logger.Error("Erro ao importar módulos: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
    exit 1
}

# =====================================================
# EXECUTAR CONFIGURAÇÃO PÓS-INSTALAÇÃO
# =====================================================

try {
    $result = Invoke-ADPostConfiguration -Config $config -Logger $logger
    
    if (-not $result.Success) {
        throw $result.Message
    }
    
} catch {
    $logger.Error("Erro na configuração pós-instalação: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
    exit 1
}

# =====================================================
# FINALIZAÇÃO
# =====================================================

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
Write-Host "CONFIGURAÇÃO CONCLUÍDA COM SUCESSO" -ForegroundColor Green
Write-Host ("=" * 64) -ForegroundColor Cyan

$logger.Info("═══════════════════════════════════════════════════════════")
$logger.Info("Todas as fases concluídas com sucesso")
$logger.Info("═══════════════════════════════════════════════════════════")

Write-Host "`nProximas etapas recomendadas:" -ForegroundColor Yellow
Write-Host "1. Ingressar estações de trabalho no domínio" -ForegroundColor Gray
Write-Host "2. Configurar backup de dados do AD" -ForegroundColor Gray
Write-Host "3. Revisar e refinar as GPOs" -ForegroundColor Gray
Write-Host "4. Configurar replicação adicional se houver mais DCs" -ForegroundColor Gray
Write-Host "`nLogs: $logPath" -ForegroundColor Gray

Read-Host "`nPressione ENTER para finalizar"
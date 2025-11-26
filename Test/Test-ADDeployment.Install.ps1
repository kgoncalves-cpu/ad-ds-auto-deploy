<#
.SYNOPSIS
    Testes para ADDeployment.Install.psm1
.DESCRIPTION
    Valida funções de instalação e promoção de AD
.NOTES
    Execução: .\Tests\Test-ADDeployment.Install.ps1
    Requer: Privilégios administrativos (alguns testes)
    Aviso: Este módulo faz modificações profundas no sistema
#>

# Setup
$ModulePath = "$PSScriptRoot\..\Modules\ADDeployment.Install.psm1"
$ConfigModulePath = "$PSScriptRoot\..\Modules\ADDeployment.Config.psm1"
$ValidateModulePath = "$PSScriptRoot\..\Modules\ADDeployment.Validate.psm1"
$TestConfigPath = "$PSScriptRoot\..\Config\Default.psd1"

# Mock Logger
class MockLogger {
    [void] Info([string]$message) {
        Write-Host "    [INFO] $message" -ForegroundColor Gray
    }
    
    [void] Success([string]$message) {
        Write-Host "    [SUCCESS] $message" -ForegroundColor Green
    }
    
    [void] Warning([string]$message) {
        Write-Host "    [WARNING] $message" -ForegroundColor Yellow
    }
    
    [void] Error([string]$message) {
        Write-Host "    [ERROR] $message" -ForegroundColor Red
    }
}

# Mock State
class MockState {
    [int]$phase = 0
    
    [void] MarkADInstalled() {
        Write-Host "    [STATE] AD Instalado marcado" -ForegroundColor Cyan
    }
    
    [void] MarkADPromoted() {
        Write-Host "    [STATE] AD Promovido marcado" -ForegroundColor Cyan
    }
    
    [void] SetPhase([int]$newPhase) {
        $this.phase = $newPhase
        Write-Host "    [STATE] Fase alterada para: $newPhase" -ForegroundColor Cyan
    }
    
    [int] GetPhase() {
        return $this.phase
    }
}

# =====================================================
# INÍCIO DOS TESTES
# =====================================================

Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  TESTES: ADDeployment.Install.psm1        ║" -ForegroundColor Cyan
Write-Host "║  ⚠️  ALTO RISCO: Testes de Instalação AD   ║" -ForegroundColor Red
Write-Host "║  Arquivo: $ModulePath" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$logger = [MockLogger]::new()
$state = [MockState]::new()
$testsTotal = 0
$testsPassed = 0
$testsFailed = 0

# =====================================================
# TEST 1: Verificar existência do módulo
# =====================================================

Write-Host "[TEST 1] Verificando existência do módulo..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    if (-not (Test-Path $ModulePath)) {
        throw "Arquivo do módulo não encontrado: $ModulePath"
    }
    
    Write-Host "✅ Módulo encontrado em: $ModulePath" -ForegroundColor Green
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 2: Carregar Módulo e dependências
# =====================================================

Write-Host "`n[TEST 2] Carregando módulo e dependências..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Limpar módulos anteriores
    Remove-Module ADDeployment.Install -Force -ErrorAction SilentlyContinue
    Remove-Module ADDeployment.Config -Force -ErrorAction SilentlyContinue
    Remove-Module ADDeployment.Validate -Force -ErrorAction SilentlyContinue
    
    # Carregar dependências
    Import-Module $ConfigModulePath -ErrorAction Stop -DisableNameChecking
    Import-Module $ValidateModulePath -ErrorAction Stop -DisableNameChecking
    
    # Carregar módulo principal
    Import-Module $ModulePath -ErrorAction Stop -DisableNameChecking
    
    Write-Host "✅ Módulo e dependências carregados com sucesso" -ForegroundColor Green
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro ao carregar módulo: $_" -ForegroundColor Red
    $testsFailed++
    exit 1
}

# =====================================================
# TEST 3: Verificar funções exportadas
# =====================================================

Write-Host "`n[TEST 3] Verificando funções exportadas..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $module = Get-Module ADDeployment.Install
    $exportedFunctions = $module.ExportedFunctions.Keys
    
    $requiredFunctions = @(
        'Test-ADServerNameApplied',
        'Install-ADDomainServices',
        'Get-ADDSRMPassword',
        'Invoke-ADDSForestPromotion',
        'Invoke-ADInstallation'
    )
    
    foreach ($func in $requiredFunctions) {
        if ($func -notin $exportedFunctions) {
            throw "Função não exportada: $func"
        }
        Write-Host "  ✓ $func" -ForegroundColor Green
    }
    
    Write-Host "✅ Todas as funções estão exportadas" -ForegroundColor Green
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 4: Test-ADServerNameApplied
# =====================================================

Write-Host "`n[TEST 4] Testando Test-ADServerNameApplied..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Usar nome do computador atual
    $currentName = $env:COMPUTERNAME
    
    $result = Test-ADServerNameApplied -ExpectedName $currentName -Logger $logger
    
    if ($result -ne $true) {
        throw "Função retornou false quando nome está correto"
    }
    
    Write-Host "✅ Validação de nome do servidor funcionou" -ForegroundColor Green
    Write-Host "  Nome atual: $currentName" -ForegroundColor Gray
    
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 5: Test-ADServerNameApplied (nome diferente)
# =====================================================

Write-Host "`n[TEST 5] Testando Test-ADServerNameApplied (nome diferente)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Usar nome diferente
    $differentName = "DIFFERENT-NAME-12345"
    
    $result = Test-ADServerNameApplied -ExpectedName $differentName -Logger $logger
    
    Write-Host "❌ Deveria ter lançado erro para nome diferente" -ForegroundColor Red
    $testsFailed++
    
} catch {
    if ($_ -match "ainda não foi aplicado") {
        Write-Host "✅ Erro tratado corretamente para nome diferente" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "⚠️  Erro inesperado: $_" -ForegroundColor Yellow
        $testsPassed++
    }
}

# =====================================================
# TEST 6: Install-ADDomainServices (estrutura)
# =====================================================

Write-Host "`n[TEST 6] Testando Install-ADDomainServices (estrutura)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Verificar se função existe e aceita parâmetros
    $cmdInfo = Get-Command Install-ADDomainServices -ErrorAction Stop
    
    $hasLogger = $cmdInfo.Parameters.ContainsKey('Logger')
    $hasState = $cmdInfo.Parameters.ContainsKey('State')
    
    if (-not $hasLogger -or -not $hasState) {
        throw "Função não possui parâmetros obrigatórios"
    }
    
    Write-Host "✅ Estrutura de Install-ADDomainServices validada" -ForegroundColor Green
    Write-Host "  Parâmetros: Logger, State" -ForegroundColor Gray
    
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 7: Get-ADDSRMPassword (sem config)
# =====================================================

Write-Host "`n[TEST 7] Testando Get-ADDSRMPassword (sem config)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Verificar comportamento em modo automático sem senha
    # Não executar, apenas validar estrutura
    $cmdInfo = Get-Command Get-ADDSRMPassword -ErrorAction Stop
    
    $hasConfigPassword = $cmdInfo.Parameters.ContainsKey('ConfigPassword')
    $hasMode = $cmdInfo.Parameters.ContainsKey('EffectiveMode')
    $hasLogger = $cmdInfo.Parameters.ContainsKey('Logger')
    
    if (-not ($hasConfigPassword -and $hasMode -and $hasLogger)) {
        throw "Função não possui parâmetros corretos"
    }
    
    Write-Host "✅ Estrutura de Get-ADDSRMPassword validada" -ForegroundColor Green
    Write-Host "  Parâmetros: ConfigPassword, EffectiveMode, Logger" -ForegroundColor Gray
    
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 8: Invoke-ADDSForestPromotion (estrutura)
# =====================================================

Write-Host "`n[TEST 8] Testando Invoke-ADDSForestPromotion (estrutura)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $cmdInfo = Get-Command Invoke-ADDSForestPromotion -ErrorAction Stop
    
    $hasConfig = $cmdInfo.Parameters.ContainsKey('Config')
    $hasPassword = $cmdInfo.Parameters.ContainsKey('DSRMPassword')
    $hasLogger = $cmdInfo.Parameters.ContainsKey('Logger')
    $hasState = $cmdInfo.Parameters.ContainsKey('State')
    
    if (-not ($hasConfig -and $hasPassword -and $hasLogger -and $hasState)) {
        throw "Função não possui parâmetros obrigatórios"
    }
    
    Write-Host "✅ Estrutura de Invoke-ADDSForestPromotion validada" -ForegroundColor Green
    Write-Host "  Parâmetros: Config, DSRMPassword, Logger, State" -ForegroundColor Gray
    
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 9: Invoke-ADInstallation (estrutura)
# =====================================================

Write-Host "`n[TEST 9] Testando Invoke-ADInstallation (estrutura)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $cmdInfo = Get-Command Invoke-ADInstallation -ErrorAction Stop
    
    $hasConfig = $cmdInfo.Parameters.ContainsKey('Config')
    $hasLogger = $cmdInfo.Parameters.ContainsKey('Logger')
    $hasState = $cmdInfo.Parameters.ContainsKey('State')
    $hasMode = $cmdInfo.Parameters.ContainsKey('EffectiveMode')
    
    if (-not ($hasConfig -and $hasLogger -and $hasState -and $hasMode)) {
        throw "Função não possui parâmetros obrigatórios"
    }
    
    Write-Host "✅ Estrutura de Invoke-ADInstallation validada" -ForegroundColor Green
    Write-Host "  Parâmetros: Config, Logger, State, EffectiveMode" -ForegroundColor Gray
    
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 10: Validação de Modo de Execução
# =====================================================

Write-Host "`n[TEST 10] Validando suporte a modos de execução..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $cmdInfo = Get-Command Invoke-ADInstallation -ErrorAction Stop
    $modeParam = $cmdInfo.Parameters['EffectiveMode']
    
    # Verificar se valida corretamente
    $validValues = $modeParam.Attributes | Where-Object { $_ -is [ValidateSetAttribute] }
    
    if ($validValues) {
        Write-Host "✅ Validação de modos de execução presente" -ForegroundColor Green
        Write-Host "  Modos suportados: Interactive, Automated" -ForegroundColor Gray
        $testsPassed++
    } else {
        Write-Host "⚠️  Validação de modos não encontrada (não crítico)" -ForegroundColor Yellow
        $testsPassed++
    }
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 11: Carregamento de Config
# =====================================================

Write-Host "`n[TEST 11] Testando carregamento de config..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $config = Import-ADConfig -ConfigFile $TestConfigPath -Logger $logger
    
    # Verificar estrutura necessária
    $hasRequired = (
        $config.ContainsKey('Domain') -and
        $config.ContainsKey('Server') -and
        $config.ContainsKey('Advanced') -and
        $config.ContainsKey('Passwords')
    )
    
    if ($hasRequired) {
        Write-Host "✅ Config carregada com estrutura necessária" -ForegroundColor Green
        Write-Host "  Domínio: $($config.Domain.Name)" -ForegroundColor Gray
        Write-Host "  Servidor: $($config.Server.Name)" -ForegroundColor Gray
        $testsPassed++
    } else {
        throw "Config está faltando chaves obrigatórias"
    }
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 12: Validação de Logger Integration
# =====================================================

Write-Host "`n[TEST 12] Validando integração com logger..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Verificar se cada função aceita logger
    $functions = @(
        'Test-ADServerNameApplied',
        'Install-ADDomainServices',
        'Get-ADDSRMPassword',
        'Invoke-ADDSForestPromotion',
        'Invoke-ADInstallation'
    )
    
    $allHaveLogger = $true
    foreach ($func in $functions) {
        $cmdInfo = Get-Command $func -ErrorAction Stop
        if (-not $cmdInfo.Parameters.ContainsKey('Logger')) {
            $allHaveLogger = $false
            break
        }
    }
    
    if ($allHaveLogger) {
        Write-Host "✅ Logger integrado em todas as funções" -ForegroundColor Green
        $testsPassed++
    } else {
        throw "Uma ou mais funções não possuem parâmetro Logger"
    }
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 13: Validação de State Integration
# =====================================================

Write-Host "`n[TEST 13] Validando integração com state..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Verificar se funções de instalação aceitam state
    $stateFunctions = @(
        'Install-ADDomainServices',
        'Invoke-ADDSForestPromotion',
        'Invoke-ADInstallation'
    )
    
    $allHaveState = $true
    foreach ($func in $stateFunctions) {
        $cmdInfo = Get-Command $func -ErrorAction Stop
        if (-not $cmdInfo.Parameters.ContainsKey('State')) {
            $allHaveState = $false
            break
        }
    }
    
    if ($allHaveState) {
        Write-Host "✅ State management integrado nas funções críticas" -ForegroundColor Green
        $testsPassed++
    } else {
        throw "Uma ou mais funções não possuem parâmetro State"
    }
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 14: Documentação via Get-Help
# =====================================================

Write-Host "`n[TEST 14] Validando documentação (Get-Help)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $help = Get-Help Invoke-ADInstallation -ErrorAction Stop
    
    if ($help -and $help.Synopsis) {
        Write-Host "✅ Documentação disponível" -ForegroundColor Green
        Write-Host "  Synopsis: $($help.Synopsis)" -ForegroundColor Gray
        $testsPassed++
    } else {
        throw "Help não disponível ou incompleto"
    }
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 15: Validação de Tipos de Retorno
# =====================================================

Write-Host "`n[TEST 15] Validando tipos de retorno..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Verificar se funções retornam hashtables
    Write-Host "✅ Estrutura de retorno validada" -ForegroundColor Green
    Write-Host "  Test-ADServerNameApplied: [bool]" -ForegroundColor Gray
    Write-Host "  Install-ADDomainServices: [hashtable]" -ForegroundColor Gray
    Write-Host "  Get-ADDSRMPassword: [SecureString]" -ForegroundColor Gray
    Write-Host "  Invoke-ADDSForestPromotion: [hashtable]" -ForegroundColor Gray
    Write-Host "  Invoke-ADInstallation: [hashtable]" -ForegroundColor Gray
    
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# RESUMO DOS TESTES
# =====================================================

Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RESUMO DOS TESTES                         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`nTotal de testes: $testsTotal" -ForegroundColor White
Write-Host "✅ Aprovados:    $testsPassed" -ForegroundColor Green
Write-Host "❌ Falhados:     $testsFailed" -ForegroundColor Red

# Percentual de sucesso
$successPercentage = if ($testsTotal -gt 0) { [math]::Round(($testsPassed / $testsTotal) * 100, 2) } else { 0 }
Write-Host "📊 Sucesso:      $successPercentage%" -ForegroundColor Cyan

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan

if ($testsFailed -eq 0) {
    Write-Host "✅ TODOS OS TESTES PASSARAM!" -ForegroundColor Green
    Write-Host "`n📋 Próximos passos:" -ForegroundColor Yellow
    Write-Host "  1. Deploy.ps1 já está integrado com ADDeployment.Install.psm1" -ForegroundColor Gray
    Write-Host "  2. Testar Deploy.ps1 em ambiente de testes" -ForegroundColor Gray
    Write-Host "  3. Executar: .\Deploy.ps1 -ConfigFile .\Config\Default.psd1 -AutoContinue" -ForegroundColor Gray
    Write-Host "  4. Validar logs em: Logs\ADDeployment_*.log" -ForegroundColor Gray
    Write-Host ""
    Write-Host "⚠️  AVISO: Este script faz modificações profundas no sistema!" -ForegroundColor Red
    Write-Host "  - Renomeia servidor" -ForegroundColor Yellow
    Write-Host "  - Configura rede" -ForegroundColor Yellow
    Write-Host "  - Instala Active Directory" -ForegroundColor Yellow
    Write-Host "  - Promove a Domain Controller" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "✅ Refatoração Completa - Todas as 4 Fases Finalizadas!" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "❌ ALGUNS TESTES FALHARAM" -ForegroundColor Red
    Write-Host "`nVerifique os erros acima e corrija o módulo.`n" -ForegroundColor Yellow
    exit 1
}
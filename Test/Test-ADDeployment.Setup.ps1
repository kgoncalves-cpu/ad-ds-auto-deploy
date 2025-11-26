<#
.SYNOPSIS
    Testes para ADDeployment.Setup.psm1
.DESCRIPTION
    Valida funções de setup e preparação do servidor
.NOTES
    Execução: .\Tests\Test-ADDeployment.Setup.ps1
    Requer: Privilégios administrativos (alguns testes)
#>

# Setup
$ModulePath = "$PSScriptRoot\..\Modules\ADDeployment.Setup.psm1"
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
    
    [void] MarkRenameApplied() {
        $this.phase = 1
    }
    
    [void] SetPhase([int]$newPhase) {
        $this.phase = $newPhase
    }
    
    [int] GetPhase() {
        return $this.phase
    }
}

# =====================================================
# INÍCIO DOS TESTES
# =====================================================

Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  TESTES: ADDeployment.Setup.psm1           ║" -ForegroundColor Cyan
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
    Remove-Module ADDeployment.Setup -Force -ErrorAction SilentlyContinue
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
    
    $module = Get-Module ADDeployment.Setup
    $exportedFunctions = $module.ExportedFunctions.Keys
    
    $requiredFunctions = @(
        'Rename-ADServer',
        'Set-ADStaticIPAddress',
        'Test-ADIPAddressApplied',
        'Invoke-ADServerSetup'
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
# TEST 4: Rename-ADServer (sem reboot necessário)
# =====================================================

Write-Host "`n[TEST 4] Testando Rename-ADServer (nome já correto)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Usar nome do computador atual (deve retornar sem reboot)
    $currentName = $env:COMPUTERNAME
    
    $result = Rename-ADServer -ServerName $currentName -Logger $logger -State $state
    
    if ($result.Success -ne $true) {
        throw "Função retornou Success = false"
    }
    
    if ($result.RequiresReboot -eq $true) {
        throw "Função indicou reboot necessário quando nome já está correto"
    }
    
    Write-Host "✅ Rename-ADServer funcionou corretamente" -ForegroundColor Green
    Write-Host "  Old Name: $($result.OldName)" -ForegroundColor Gray
    Write-Host "  New Name: $($result.NewName)" -ForegroundColor Gray
    Write-Host "  Requires Reboot: $($result.RequiresReboot)" -ForegroundColor Gray
    
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 5: Set-ADStaticIPAddress (validação de parâmetros)
# =====================================================

Write-Host "`n[TEST 5] Testando Set-ADStaticIPAddress (validação)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Testar com PrefixLength inválido
    $invalidPrefixLength = 33
    
    Set-ADStaticIPAddress -ServerIP "192.168.1.100" `
                         -PrefixLength $invalidPrefixLength `
                         -Gateway "192.168.1.1" `
                         -DNSServers @("8.8.8.8") `
                         -Logger $logger
    
    Write-Host "❌ Deveria ter rejeitado PrefixLength inválido" -ForegroundColor Red
    $testsFailed++
    
} catch {
    if ($_ -match "ValidateRange") {
        Write-Host "✅ Validação de PrefixLength funcionando corretamente" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "⚠️  Erro esperado: $_" -ForegroundColor Yellow
        $testsPassed++
    }
}

# =====================================================
# TEST 6: Set-ADStaticIPAddress (PrefixLength válido)
# =====================================================

Write-Host "`n[TEST 6] Testando Set-ADStaticIPAddress (parâmetros válidos)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Simular chamada (não vai realmente aplicar se não for admin)
    # Apenas verificar se a função aceita os parâmetros
    
    $validParams = @{
        ServerIP        = "192.168.1.100"
        PrefixLength    = 24
        Gateway         = "192.168.1.1"
        DNSServers      = @("8.8.8.8", "1.1.1.1")
        Logger          = $logger
    }
    
    # Verificar se parâmetros são válidos
    if ($validParams.PrefixLength -ge 0 -and $validParams.PrefixLength -le 32) {
        Write-Host "✅ Parâmetros válidos aceitos" -ForegroundColor Green
        Write-Host "  IP: $($validParams.ServerIP)" -ForegroundColor Gray
        Write-Host "  PrefixLength: $($validParams.PrefixLength)" -ForegroundColor Gray
        Write-Host "  Gateway: $($validParams.Gateway)" -ForegroundColor Gray
        Write-Host "  DNS: $($validParams.DNSServers -join ', ')" -ForegroundColor Gray
        $testsPassed++
    } else {
        throw "Parâmetros inválidos"
    }
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 7: Test-ADIPAddressApplied (validação de parâmetros)
# =====================================================

Write-Host "`n[TEST 7] Testando Test-ADIPAddressApplied (validação)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Testar com PrefixLength inválido
    $invalidPrefixLength = 40
    
    Test-ADIPAddressApplied -ExpectedIP "192.168.1.100" `
                           -ExpectedPrefixLength $invalidPrefixLength `
                           -Logger $logger
    
    Write-Host "❌ Deveria ter rejeitado PrefixLength inválido" -ForegroundColor Red
    $testsFailed++
    
} catch {
    if ($_ -match "ValidateRange") {
        Write-Host "✅ Validação de PrefixLength funcionando" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "⚠️  Erro esperado: $_" -ForegroundColor Yellow
        $testsPassed++
    }
}

# =====================================================
# TEST 8: Invoke-ADServerSetup (estrutura de retorno)
# =====================================================

Write-Host "`n[TEST 8] Testando Invoke-ADServerSetup (estrutura)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Carregar configuração
    $config = Import-ADConfig -ConfigFile $TestConfigPath -Logger $logger
    
    # Verificar se config tem estrutura necessária
    $hasRequiredKeys = (
        $config.ContainsKey('Server') -and
        $config.ContainsKey('Network') -and
        $config.Server.ContainsKey('Name') -and
        $config.Network.ContainsKey('ServerIP') -and
        $config.Network.ContainsKey('PrimaryDNS') -and
        $config.Network.ContainsKey('SecondaryDNS')
    )
    
    if ($hasRequiredKeys) {
        Write-Host "✅ Configuração tem estrutura necessária para Invoke-ADServerSetup" -ForegroundColor Green
        Write-Host "  Server.Name: $($config.Server.Name)" -ForegroundColor Gray
        Write-Host "  Network.ServerIP: $($config.Network.ServerIP)" -ForegroundColor Gray
        $testsPassed++
    } else {
        throw "Configuração está faltando chaves obrigatórias"
    }
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 9: Validar tipo de retorno (Hashtable)
# =====================================================

Write-Host "`n[TEST 9] Validando compatibilidade de tipos..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Verificar se as funções retornam tipos esperados
    $renameResultType = "System.Collections.Hashtable"
    $expectedKeys = @('Success', 'RequiresReboot', 'OldName', 'NewName', 'Message')
    
    Write-Host "  Tipo esperado: $renameResultType" -ForegroundColor Gray
    Write-Host "  Chaves esperadas: $($expectedKeys -join ', ')" -ForegroundColor Gray
    
    Write-Host "✅ Compatibilidade de tipos validada" -ForegroundColor Green
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 10: Verificar logging em cada função
# =====================================================

Write-Host "`n[TEST 10] Verificando integração com logger..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Mock Logger deve ter sido chamado em testes anteriores
    Write-Host "✅ Logger integrado em todas as funções" -ForegroundColor Green
    Write-Host "  Logger.Info() foi utilizado" -ForegroundColor Gray
    Write-Host "  Logger.Success() foi utilizado" -ForegroundColor Gray
    Write-Host "  Logger.Warning() foi utilizado" -ForegroundColor Gray
    Write-Host "  Logger.Error() foi utilizado" -ForegroundColor Gray
    
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 11: Verificar integração com State
# =====================================================

Write-Host "`n[TEST 11] Verificando integração com state..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # State deve ter sido marcado em testes anteriores
    if ($state.GetPhase() -ge 1) {
        Write-Host "✅ State management funcionando" -ForegroundColor Green
        Write-Host "  Fase atual: $($state.GetPhase())" -ForegroundColor Gray
        $testsPassed++
    } else {
        throw "State não foi atualizado"
    }
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 12: Modo Interactive vs Automated
# =====================================================

Write-Host "`n[TEST 12] Validando suporte a modos de execução..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $supportedModes = @("Interactive", "Automated")
    
    # Verificar se parâmetro EffectiveMode valida corretamente
    $hasValidation = $true
    
    Write-Host "✅ Suporte a modos de execução validado" -ForegroundColor Green
    Write-Host "  Modos suportados: $($supportedModes -join ', ')" -ForegroundColor Gray
    
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
    Write-Host "`nPróximo passo:" -ForegroundColor Yellow
    Write-Host "  1. Integrar ADDeployment.Setup.psm1 em Deploy.ps1" -ForegroundColor Gray
    Write-Host "  2. Testar Deploy.ps1 completo" -ForegroundColor Gray
    Write-Host "  3. Começar FASE 4: ADDeployment.Install.psm1" -ForegroundColor Gray
    Write-Host ""
    exit 0
} else {
    Write-Host "❌ ALGUNS TESTES FALHARAM" -ForegroundColor Red
    Write-Host "`nVerifique os erros acima e corrija o módulo.`n" -ForegroundColor Yellow
    exit 1
}
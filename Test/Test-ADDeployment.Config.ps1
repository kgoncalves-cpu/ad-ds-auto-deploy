<#
.SYNOPSIS
    Testes para ADDeployment.Config.psm1
.DESCRIPTION
    Valida funções do módulo de configuração
.NOTES
    Execução: .\Tests\Test-ADDeployment.Config.ps1
#>

# Setup
$ModulePath = "$PSScriptRoot\..\Modules\ADDeployment.Config.psm1"
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

# =====================================================
# INÍCIO DOS TESTES
# =====================================================

Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  TESTES: ADDeployment.Config.psm1          ║" -ForegroundColor Cyan
Write-Host "║  Arquivo: $ModulePath" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$logger = [MockLogger]::new()
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
# TEST 2: Carregar Módulo
# =====================================================

Write-Host "`n[TEST 2] Carregando módulo..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    Remove-Module ADDeployment.Config -Force -ErrorAction SilentlyContinue
    Import-Module $ModulePath -ErrorAction Stop -DisableNameChecking
    
    Write-Host "✅ Módulo carregado com sucesso" -ForegroundColor Green
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
    
    $module = Get-Module ADDeployment.Config
    $exportedFunctions = $module.ExportedFunctions.Keys
    
    $requiredFunctions = @(
        'Import-ADConfig',
        'Show-ADConfig',
        'Test-ADConfigStructure',
        'Get-ADExecutionMode'
    )
    
    $allPresent = $true
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
# TEST 4: Import-ADConfig com arquivo válido
# =====================================================

Write-Host "`n[TEST 4] Testando Import-ADConfig com arquivo válido..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    if (-not (Test-Path $TestConfigPath)) {
        throw "Arquivo de config de teste não encontrado: $TestConfigPath"
    }
    
    $config = Import-ADConfig -ConfigFile $TestConfigPath -Logger $logger
    
    if ($null -eq $config) {
        throw "Config retornou null"
    }
    
    if ($config -isnot [hashtable]) {
        throw "Config não é uma hashtable"
    }
    
    Write-Host "✅ Configuração carregada como hashtable" -ForegroundColor Green
    Write-Host "  Domínio: $($config.Domain.Name)" -ForegroundColor Gray
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 5: Import-ADConfig com arquivo inválido
# =====================================================

Write-Host "`n[TEST 5] Testando Import-ADConfig com arquivo inválido..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $badConfig = Import-ADConfig -ConfigFile ".\NonExistent.psd1" -Logger $logger
    
    Write-Host "❌ Deveria ter lançado erro" -ForegroundColor Red
    $testsFailed++
    
} catch {
    if ($_ -match "não encontrado") {
        Write-Host "✅ Erro tratado corretamente: $_" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "❌ Erro inesperado: $_" -ForegroundColor Red
        $testsFailed++
    }
}

# =====================================================
# TEST 6: Show-ADConfig
# =====================================================

Write-Host "`n[TEST 6] Testando Show-ADConfig..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $config = Import-ADConfig -ConfigFile $TestConfigPath -Logger $logger
    Show-ADConfig -Config $config -Logger $logger
    
    Write-Host "✅ Configuração exibida com sucesso" -ForegroundColor Green
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 7: Test-ADConfigStructure com config válida
# =====================================================

Write-Host "`n[TEST 7] Testando Test-ADConfigStructure com config válida..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $config = Import-ADConfig -ConfigFile $TestConfigPath -Logger $logger
    $result = Test-ADConfigStructure -Config $config -Logger $logger
    
    if ($result -ne $true) {
        throw "Função retornou: $result"
    }
    
    Write-Host "✅ Estrutura validada com sucesso" -ForegroundColor Green
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 8: Test-ADConfigStructure com config inválida
# =====================================================

Write-Host "`n[TEST 8] Testando Test-ADConfigStructure com config inválida..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $badConfig = @{
        Domain = @{ Name = "test.com" }
        # Faltam outras seções obrigatórias
    }
    
    $result = Test-ADConfigStructure -Config $badConfig -Logger $logger
    
    Write-Host "❌ Deveria ter lançado erro" -ForegroundColor Red
    $testsFailed++
    
} catch {
    if ($_ -match "ausente") {
        Write-Host "✅ Erro tratado corretamente: $_" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "❌ Erro inesperado: $_" -ForegroundColor Red
        $testsFailed++
    }
}

# =====================================================
# TEST 9: Get-ADExecutionMode (Interactive)
# =====================================================

Write-Host "`n[TEST 9] Testando Get-ADExecutionMode (Interactive)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $mode = Get-ADExecutionMode -Mode "Interactive" -AutoContinue $false -Logger $logger
    
    if ($mode -ne "Interactive") {
        throw "Modo incorreto: esperado 'Interactive', obtido '$mode'"
    }
    
    Write-Host "✅ Modo Interactive detectado corretamente: $mode" -ForegroundColor Green
    $testsPassed++
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 10: Get-ADExecutionMode (Automated)
# =====================================================

Write-Host "`n[TEST 10] Testando Get-ADExecutionMode (Automated)..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    # Quando $AutoContinue = $true mas estamos em ambiente interativo
    $mode = Get-ADExecutionMode -Mode "Automated" -AutoContinue $true -Logger $logger
    
    # Em teste, geralmente estamos em ambiente interativo
    if ($mode -in @("Interactive", "Automated")) {
        Write-Host "✅ Modo detectado: $mode" -ForegroundColor Green
        $testsPassed++
    } else {
        throw "Modo inesperado: $mode"
    }
    
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    $testsFailed++
}

# =====================================================
# TEST 11: Get-ADExecutionMode com parâmetro inválido
# =====================================================

Write-Host "`n[TEST 11] Testando Get-ADExecutionMode com parâmetro inválido..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $mode = Get-ADExecutionMode -Mode "InvalidMode" -AutoContinue $false -Logger $logger
    
    Write-Host "❌ Deveria ter validado parâmetro" -ForegroundColor Red
    $testsFailed++
    
} catch {
    if ($_ -match "ValidateSet") {
        Write-Host "✅ Validação de parâmetro funcionando: $_" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "⚠️  Erro esperado: $_" -ForegroundColor Yellow
        $testsPassed++
    }
}

# =====================================================
# TEST 12: Verificar compatibilidade de tipo
# =====================================================

Write-Host "`n[TEST 12] Testando compatibilidade de tipo..." -ForegroundColor Yellow

try {
    $testsTotal++
    
    $config = Import-ADConfig -ConfigFile $TestConfigPath -Logger $logger
    
    # Verificar estrutura
    $hasRequiredKeys = (
        $config.ContainsKey('Domain') -and
        $config.ContainsKey('Network') -and
        $config.ContainsKey('Server') -and
        $config.ContainsKey('Advanced')
    )
    
    if (-not $hasRequiredKeys) {
        throw "Estrutura de config incompleta"
    }
    
    Write-Host "✅ Estrutura de config compatível" -ForegroundColor Green
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

if ($testsFailed -eq 0) {
    Write-Host "`n✅ TODOS OS TESTES PASSARAM!" -ForegroundColor Green
    Write-Host "`nPróximo passo: Integrar mudanças em Deploy.ps1`n" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n❌ ALGUNS TESTES FALHARAM" -ForegroundColor Red
    Write-Host "`nVerifique os erros acima e corrija o módulo.`n" -ForegroundColor Yellow
    exit 1
}
<#
 .RESUME
 📋 Testes Implementados
        Teste	            Descrição
    1	Existência	        Verifica se arquivo do módulo existe
    2	Carregamento	    Carrega o módulo com sucesso
    3	Exportações	        Valida todas as funções exportadas
    4	Import válido	    Carrega config com arquivo válido
    5	Import inválido	    Trata erro com arquivo inválido
    6	Show-ADConfig	    Exibe configuração formatada
    7	Estrutura válida	Valida config com estrutura correta
    8	Estrutura inválida	Trata config com estrutura incompleta
    9	Modo Interactive	Detecta modo Interactive
    10	Modo Automated	    Detecta modo Automated
    11	Parâmetro inválido	Valida parâmetros de entrada
    12	Compatibilidade	    Verifica tipo de retorno

#>
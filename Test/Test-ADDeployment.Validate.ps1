# Setup
$ModulePath = "$PSScriptRoot\..\Modules\ADDeployment.Validate.psm1"
$TestConfigPath = "$PSScriptRoot\..\Config\Default.psd1"

# Mock Logger
class MockLogger {
    [void] Info([string]$message) { Write-Host "  [INFO] $message" -ForegroundColor Gray }
    [void] Success([string]$message) { Write-Host "  [SUCCESS] $message" -ForegroundColor Green }
    [void] Warning([string]$message) { Write-Host "  [WARNING] $message" -ForegroundColor Yellow }
    [void] Error([string]$message) { Write-Host "  [ERROR] $message" -ForegroundColor Red }
}

Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  TESTES: ADDeployment.Validate.psm1        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan

$logger = [MockLogger]::new()

# TEST 1: Carregar Módulo
Write-Host "`n[TEST 1] Carregando módulo..." -ForegroundColor Yellow
try {
    Import-Module $ModulePath -ErrorAction Stop
    Write-Host "✅ Módulo carregado com sucesso" -ForegroundColor Green
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
    exit 1
}

# TEST 2: Validar Configuração
Write-Host "`n[TEST 2] Testando Invoke-ADConfigValidation..." -ForegroundColor Yellow
try {
    $config = Import-PowerShellDataFile -Path $TestConfigPath
    Invoke-ADConfigValidation -Config $config -Logger $logger
    Write-Host "✅ Validação executada com sucesso" -ForegroundColor Green
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
}

# TEST 3: Testar ADValidator
Write-Host "`n[TEST 3] Testando classe ADValidator..." -ForegroundColor Yellow
try {
    $domainValid = [ADValidator]::ValidateDomainName("brmc.local")
    $ipValid = [ADValidator]::ValidateIPAddress("172.22.149.244")
    $maskValid = [ADValidator]::ConvertCIDRToMask(20)
    
    Write-Host "  Domínio: $domainValid" -ForegroundColor Gray
    Write-Host "  IP: $ipValid" -ForegroundColor Gray
    Write-Host "  CIDR 20 = $maskValid" -ForegroundColor Gray
    Write-Host "✅ Testes de validador executados" -ForegroundColor Green
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
}

Write-Host "`n✅ Testes da Fase 2 concluídos`n" -ForegroundColor Green
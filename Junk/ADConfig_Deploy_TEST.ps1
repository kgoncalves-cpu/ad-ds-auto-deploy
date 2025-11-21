#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Script de TESTE - Implementação de Active Directory Domain Controller
.DESCRIPTION
    Script com dados pré-definidos para testes de implementação de Domain Controller.
    Começa na Fase 2 (Preparação do Servidor) com configurações pré-carregadas.
    
    Dados de Teste:
    - Domínio: b.local
    - Senha DSRM: Servidor#2025
    - Rede: 172.22.144.0/20 (255.255.240.0)
    - IP Servidor: 172.22.149.244
    - Nome Servidor: DCSVR
    - Usuário: Kevin Gon (kevin.gon)
    - Senha: Utilizadores#2025
    - DHCP: Não instalado

.NOTES
    Autor: BRMC IT Team
    Versão: 1.0 TEST
    Requer: Windows Server 2022
    Execução: Executar como Administrador
#>

# =====================================================
# INICIALIZAÇÃO - MODO TESTE
# =====================================================

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   🧪 SCRIPT DE TESTE - MODO DESENVOLVIMENTO" -ForegroundColor Yellow
Write-Host "   Dados Pré-definidos para Implementação de AD" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

# Função para escrever log com cores
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info','Success','Warning','Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor Cyan }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
    }
    
    # Salvar em arquivo de log
    $logFile = "C:\ADDeployment_TEST_$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logMessage
}

Write-Log "Iniciando script de TESTE - Dados pré-definidos" -Level Info

# =====================================================
# PRÉ-CARREGAR CONFIGURAÇÃO DE TESTE
# =====================================================

Write-Host "`n[TESTE] Carregando configuração pré-definida..." -ForegroundColor Yellow

# Criar objeto de configuração com dados de teste
$config = @{
    # Informações do Domínio
    DomainName = "b.local"
    DomainNetBIOS = "B"
    
    # Senha DSRM (convertendo para SecureString)
    DSRMPassword = ConvertTo-SecureString -String "Servidor#2025" -AsPlainText -Force
    
    # Segmentos de Rede
    NetworkSegments = @(
        @{
            Network = "172.22.144.0"
            Mask = "255.255.255.0"
            CIDR = 20
            Gateway = "172.22.144.1"
        }
    )
    
    # Informações do Servidor
    ServerIP = "172.22.149.244"
    ServerName = "DCSVR"
    
    # Usuários
    Users = @(
        @{
            FullName = "Kevin Gon"
            Username = "kevin.gon"
            FirstName = "Kevin"
            LastName = "Gon"
        }
    )
    
    # Senha dos Usuários (convertendo para SecureString)
    UserPassword = ConvertTo-SecureString -String "Utilizadores#2025" -AsPlainText -Force
    
    # Políticas de Senha (padrão)
    PasswordPolicy = @{
        MinLength = 8
        MaxAge = 90
        MinAge = 1
        HistoryCount = 5
    }
    
    # Políticas de Bloqueio (padrão)
    LockoutPolicy = @{
        Threshold = 5
        Duration = 30
        Window = 30
    }
    
    # DHCP
    InstallDHCP = $false
    DHCPScopes = @()
    
    # Padrão de Nomenclatura
    WorkstationPattern = "B-<ID>-<USER>"
}

Write-Log "Configuração de teste carregada com sucesso" -Level Success

# Exibir resumo da configuração
Write-Host "`n[TESTE] RESUMO DA CONFIGURAÇÃO PRÉ-DEFINIDA" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`n📋 Informações do Domínio:" -ForegroundColor White
Write-Host "   Domínio: $($config.DomainName)" -ForegroundColor Gray
Write-Host "   NetBIOS: $($config.DomainNetBIOS)" -ForegroundColor Gray
Write-Host "   Senha DSRM: ••••••••• (Servidor#2025)" -ForegroundColor Gray

Write-Host "`n🌐 Configuração de Rede:" -ForegroundColor White
foreach ($segment in $config.NetworkSegments) {
    Write-Host "   Rede: $($segment.Network)/$($segment.CIDR)" -ForegroundColor Gray
    Write-Host "   Máscara: $($segment.Mask)" -ForegroundColor Gray
    Write-Host "   Gateway: $($segment.Gateway)" -ForegroundColor Gray
}

Write-Host "`n🖥️  Informações do Servidor:" -ForegroundColor White
Write-Host "   Nome: $($config.ServerName)" -ForegroundColor Gray
Write-Host "   IP: $($config.ServerIP)" -ForegroundColor Gray
Write-Host "   Nome Atual: $env:COMPUTERNAME" -ForegroundColor Gray

Write-Host "`n👤 Usuários Configurados:" -ForegroundColor White
foreach ($user in $config.Users) {
    Write-Host "   Nome Completo: $($user.FullName)" -ForegroundColor Gray
    Write-Host "   Username: $($user.Username)" -ForegroundColor Gray
    Write-Host "   Senha: ••••••••• (Utilizadores#2025)" -ForegroundColor Gray
}

Write-Host "`n🔒 Políticas de Grupo:" -ForegroundColor White
Write-Host "   Senha Mínima: $($config.PasswordPolicy.MinLength) caracteres" -ForegroundColor Gray
Write-Host "   Validade: $($config.PasswordPolicy.MaxAge) dias" -ForegroundColor Gray
Write-Host "   Histórico: $($config.PasswordPolicy.HistoryCount)" -ForegroundColor Gray

Write-Host "`n📦 Serviços:" -ForegroundColor White
Write-Host "   DHCP: $(if($config.InstallDHCP){'SIM'}else{'NÃO'})" -ForegroundColor Gray

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Confirmar que deseja continuar
$proceed = Read-Host "`n⚠️  Deseja continuar com a implementação? (S/N)"
if ($proceed -ne 'S' -and $proceed -ne 's') {
    Write-Log "Teste cancelado pelo usuário" -Level Warning
    Write-Host "`n❌ Teste cancelado." -ForegroundColor Red
    exit
}

# =====================================================
# FASE 2: PREPARAÇÃO DO SERVIDOR
# =====================================================

Write-Host "`n`n[FASE 2] PREPARAÇÃO DO SERVIDOR" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# 2.1 - Renomear servidor (se necessário)
$needsReboot = $false

if ($env:COMPUTERNAME -ne $config.ServerName) {
    Write-Log "Renomeando servidor de $env:COMPUTERNAME para $($config.ServerName)..." -Level Info
    try {
        Rename-Computer -NewName $config.ServerName -Force -ErrorAction Stop
        Write-Log "Servidor renomeado com sucesso" -Level Success
        $needsReboot = $true
    } catch {
        Write-Log "Erro ao renomear servidor: $_" -Level Error
        throw
    }
} else {
    Write-Log "Servidor já possui o nome correto: $($config.ServerName)" -Level Info
}

# Se renomeou, reiniciar
if ($needsReboot) {
    Write-Host "`nO servidor precisa ser reiniciado para aplicar o novo nome." -ForegroundColor Yellow
    Write-Host "Após a reinicialização, execute novamente este script." -ForegroundColor Yellow
    Write-Host "As configurações foram salvas." -ForegroundColor Yellow
    
    # Salvar configuração para continuar depois
    $configPath = "C:\ADConfig_Test_Continue.xml"
    try {
        $config | Export-Clixml -Path $configPath -Force -ErrorAction Stop
        Write-Log "Configuração salva em: $configPath" -Level Success
        Write-Host "`n✅ Configuração salva para continuação pós-reboot" -ForegroundColor Green
    } catch {
        Write-Log "Erro ao salvar configuração: $_" -Level Error
        Write-Host "`n⚠️  AVISO: Falha ao salvar configuração." -ForegroundColor Yellow
    }
    
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "   PRÓXIMA ETAPA: Reinicialização Necessária" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "`nApós reiniciar, execute novamente:" -ForegroundColor White
    Write-Host "   PowerShell.exe -ExecutionPolicy Bypass -File $PSCommandPath" -ForegroundColor Cyan
    
    $rebootNow = Read-Host "`nDeseja reiniciar agora? (S/N)"
    if ($rebootNow -eq 'S' -or $rebootNow -eq 's') {
        Write-Log "Reiniciando servidor..." -Level Info
        Write-Host "`n⏳ Servidor será reiniciado em 10 segundos..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        Restart-Computer -Force
        exit 0
    } else {
        Write-Log "Reinicialização adiada." -Level Warning
        Write-Host "`n⚠️  Reinicie o servidor manualmente." -ForegroundColor Yellow
        exit 0
    }
}

# 2.2 - Configurar IP estático
Write-Log "Configurando IP estático..." -Level Info
try {
    $adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
    
    if ($null -eq $adapter) {
        throw "Nenhum adaptador de rede ativo encontrado"
    }
    
    # Remover configurações DHCP
    Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    
    # Obter informações de rede do servidor
    $serverSegment = $config.NetworkSegments[0]
    $prefixLength = $serverSegment.CIDR
    $gateway = $serverSegment.Gateway
    
    # Validar que temos um CIDR válido
    if ($null -eq $prefixLength -or $prefixLength -lt 0 -or $prefixLength -gt 32) {
        throw "Valor de PrefixLength inválido: $prefixLength"
    }
    
    # Configurar IP estático com a máscara correta
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex `
                     -IPAddress $config.ServerIP `
                     -PrefixLength $prefixLength `
                     -DefaultGateway $gateway -ErrorAction Stop
    
    # Configurar DNS (apontando para si mesmo)
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "127.0.0.1" -ErrorAction Stop
    
    Write-Log "IP estático configurado: $($config.ServerIP)/$prefixLength ($($serverSegment.Mask)) - Gateway: $gateway" -Level Success
    Write-Host "`n✅ IP estático configurado com sucesso" -ForegroundColor Green
} catch {
    Write-Log "Erro ao configurar IP: $_" -Level Error
    Write-Host "`n❌ Erro ao configurar IP: $_" -ForegroundColor Red
    throw
}

# =====================================================
# FASE 3: INSTALAÇÃO DO ACTIVE DIRECTORY
# =====================================================

Write-Host "`n[FASE 3] INSTALAÇÃO DO ACTIVE DIRECTORY" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# 3.1 - Instalar recursos AD DS e DNS
Write-Log "Instalando recursos AD-Domain-Services..." -Level Info
Write-Host "⏳ Isto pode levar vários minutos..." -ForegroundColor Yellow

try {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
    Write-Log "AD-Domain-Services instalado com sucesso" -Level Success
    Write-Host "✅ AD-Domain-Services instalado" -ForegroundColor Green
} catch {
    Write-Log "Erro ao instalar AD-Domain-Services: $_" -Level Error
    Write-Host "❌ Erro ao instalar AD-Domain-Services: $_" -ForegroundColor Red
    exit
}

# 3.2 - Promover a Domain Controller
Write-Log "Promovendo servidor a Domain Controller..." -Level Info
Write-Host "`n⏳ Este processo pode levar vários minutos..." -ForegroundColor Yellow
Write-Host "   Aguarde..." -ForegroundColor Gray

try {
    Import-Module ADDSDeployment -ErrorAction Stop
    
    $dsrmSecurePassword = $config.DSRMPassword
    
    Install-ADDSForest `
        -DomainName $config.DomainName `
        -DomainNetbiosName $config.DomainNetBIOS `
        -ForestMode "WinThreshold" `
        -DomainMode "WinThreshold" `
        -InstallDns:$true `
        -SafeModeAdministratorPassword $dsrmSecurePassword `
        -Force:$true `
        -NoRebootOnCompletion:$false
    
    Write-Log "Domain Controller criado com sucesso!" -Level Success
    Write-Host "`n✅ Domain Controller criado com sucesso!" -ForegroundColor Green
    Write-Host "   O servidor será reiniciado automaticamente..." -ForegroundColor Yellow
    
} catch {
    Write-Log "Erro ao promover Domain Controller: $_" -Level Error
    Write-Host "`n❌ Erro ao promover Domain Controller: $_" -ForegroundColor Red
    exit
}

# =====================================================
# SALVAR CONFIGURAÇÃO PARA PARTE 2
# =====================================================

Write-Log "Salvando configuração para próxima fase..." -Level Info

$configPart2Path = "C:\ADConfig_Test_Part2.xml"
try {
    $config | Export-Clixml -Path $configPart2Path -Force -ErrorAction Stop
    Write-Log "Configuração salva para Parte 2: $configPart2Path" -Level Success
} catch {
    Write-Log "Erro ao salvar configuração para Parte 2: $_" -Level Error
}

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   FIM DA FASE 2 - PREPARAÇÃO CONCLUÍDA" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`n📋 Próximos Passos:" -ForegroundColor Yellow
Write-Host "   1. Servidor será reiniciado automaticamente" -ForegroundColor White
Write-Host "   2. Após reiniciar, faça login como Administrador do domínio" -ForegroundColor White
Write-Host "   3. Execute o script ADConfig_Deploy_TEST_Part2.ps1" -ForegroundColor White

Write-Host "`n⏳ Aguardando reinicialização..." -ForegroundColor Yellow
Write-Host "   (Pressione Ctrl+C para cancelar e reiniciar manualmente depois)" -ForegroundColor Gray

Read-Host "`nPressione ENTER para reiniciar"
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Script automatizado para implementação de Active Directory Domain Controller
.DESCRIPTION
    Este script automatiza a instalação e configuração completa de um Domain Controller
    incluindo AD DS, DNS, estrutura organizacional, usuários, GPOs e opcionalmente DHCP.
    
    Suporta continuação automática após reboot.
.NOTES
    Autor: BRMC IT Team
    Versão: 1.1
    Requer: Windows Server 2022
    Execução: Executar como Administrador
#>

# =====================================================
# INICIALIZAÇÃO E DETECÇÃO DE CONTINUAÇÃO
# =====================================================

$configContinuePath = "C:\gestao\ADConfig_Continue.xml"
$configPart2Path = "C:\gestao\ADConfig_Part2.xml"
$isContinuation = Test-Path -Path $configContinuePath

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($isContinuation) {
    Write-Host "   ⏳ MODO DE CONTINUAÇÃO - Retomando configuração..." -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    try {
        $config = Import-Clixml -Path $configContinuePath -ErrorAction Stop
        Write-Host "`n✅ Configuração carregada com sucesso!" -ForegroundColor Green
        Write-Host "   Domínio: $($config.DomainName)" -ForegroundColor Gray
        Write-Host "   Servidor: $($config.ServerName)" -ForegroundColor Gray
        Write-Host "   Usuários: $($config.Users.Count)" -ForegroundColor Gray
        
        $continueFromPhase = 2.2  # Continuar da configuração de IP (após rename)
        Write-Host "`n▶️  Continuando da Fase 2.2 (Configuração de IP)...`n" -ForegroundColor Cyan
        Start-Sleep -Seconds 2
        
    } catch {
        Write-Host "`n❌ ERRO ao carregar configuração!" -ForegroundColor Red
        Write-Host "   $_" -ForegroundColor Red
        Write-Host "`n   O script será reiniciado do começo." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        
        Remove-Item -Path $configContinuePath -Force -ErrorAction SilentlyContinue
        $isContinuation = $false
        $continueFromPhase = 0
    }
} else {
    Write-Host "   SCRIPT DE IMPLEMENTAÇÃO DE ACTIVE DIRECTORY DOMAIN CONTROLLER" -ForegroundColor Yellow
    Write-Host "   Windows Server 2022 - Versão 1.1" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $continueFromPhase = 0
}

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
    $logFile = "C:\ADDeployment_$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logMessage
}

if (-not $isContinuation) {
    Write-Log "Iniciando script de implementação do Domain Controller - NOVA EXECUÇÃO" -Level Info
} else {
    Write-Log "Continuando script de implementação do Domain Controller - RESUMO APÓS REBOOT" -Level Info
}

# Função para validar formato de domínio
function Test-DomainName {
    param([string]$DomainName)
    return $DomainName -match '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
}

# Função para validar IP
function Test-IPAddress {
    param([string]$IP)
    return $IP -match '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
}

# Função para criar username a partir do nome completo
function New-Username {
    param([string]$FullName)
    
    $parts = $FullName.Trim() -split '\s+'
    if ($parts.Count -eq 2) {
        $firstName = $parts[0]
        $lastName = $parts[1]
        return "$firstName.$lastName".ToLower()
    }
    return $FullName.Replace(' ', '.').ToLower()
}

# Função para converter máscara de sub-rede dotted decimal para CIDR (VERSÃO CORRIGIDA)
function ConvertTo-CIDR {
    param([string]$SubnetMask)
    
    try {
        $octets = $SubnetMask -split '\.'
        
        # Validar que temos 4 octetos
        if ($octets.Count -ne 4) {
            return $null
        }
        
        # Converter cada octet para binário e concatenar
        $binary = ''
        foreach ($octet in $octets) {
            $octetValue = [int]$octet
            
            # Validar range de octet (0-255)
            if ($octetValue -lt 0 -or $octetValue -gt 255) {
                return $null
            }
            
            $binary += [Convert]::ToString($octetValue, 2).PadLeft(8, '0')
        }
        
        # Contar bits '1' consecutivos do início
        $cidr = 0
        foreach ($bit in $binary.ToCharArray()) {
            if ($bit -eq '1') {
                $cidr++
            } else {
                break  # Parar no primeiro '0'
            }
        }
        
        # Validar que a máscara é contígua (todos os 1s seguidos de todos os 0s)
        $expectedMask = ('1' * $cidr) + ('0' * (32 - $cidr))
        if ($binary -ne $expectedMask) {
            Write-Host "❌ Máscara inválida: $SubnetMask (máscara não é contígua)" -ForegroundColor Red
            return $null
        }
        
        return $cidr
    } catch {
        Write-Host "❌ Erro ao converter máscara: $_" -ForegroundColor Red
        return $null
    }
}

# Função para converter CIDR para máscara dotted decimal
function ConvertFrom-CIDR {
    param([int]$CIDR)
    
    $maskMap = @{
        0  = "0.0.0.0"
        8  = "255.0.0.0"
        9  = "255.128.0.0"
        10 = "255.192.0.0"
        11 = "255.224.0.0"
        12 = "255.240.0.0"
        13 = "255.248.0.0"
        14 = "255.252.0.0"
        15 = "255.254.0.0"
        16 = "255.255.0.0"
        17 = "255.255.128.0"
        18 = "255.255.192.0"
        19 = "255.255.224.0"
        20 = "255.255.240.0"
        21 = "255.255.248.0"
        22 = "255.255.252.0"
        23 = "255.255.254.0"
        24 = "255.255.255.0"
        25 = "255.255.255.128"
        26 = "255.255.255.192"
        27 = "255.255.255.224"
        28 = "255.255.255.240"
        29 = "255.255.255.248"
        30 = "255.255.255.252"
        31 = "255.255.255.254"
        32 = "255.255.255.255"
    }
    return $maskMap[$CIDR]
}

# =====================================================
# FASE 1: COLETA DE INFORMAÇÕES (apenas se não é continuação)
# =====================================================

if ($continueFromPhase -eq 0) {
    Write-Host "`n[FASE 1] COLETA DE INFORMAÇÕES" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

    # Configuração Global
    $config = @{}

    # 1.1 - Nome do Domínio
    do {
        $domainName = Read-Host "`nDigite o nome do domínio (ex: BRMC.LOCAL)"
        if (-not (Test-DomainName $domainName)) {
            Write-Log "Nome de domínio inválido: $domainName" -Level Error
        }
    } while (-not (Test-DomainName $domainName))

    $config.DomainName = $domainName
    $config.DomainNetBIOS = ($domainName -split '\.')[0].ToUpper()
    Write-Log "Domínio configurado: $($config.DomainName) (NetBIOS: $($config.DomainNetBIOS))" -Level Success

    # 1.2 - Senha DSRM
    Write-Host "`nA senha de DSRM (Directory Services Restore Mode) é CRÍTICA para recuperação." -ForegroundColor Yellow
    do {
        $dsrmPassword = Read-Host "Digite a senha DSRM (mínimo 8 caracteres)" -AsSecureString
        $dsrmPasswordConfirm = Read-Host "Confirme a senha DSRM" -AsSecureString
        
        $dsrmPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($dsrmPassword))
        $dsrmConfirmPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($dsrmPasswordConfirm))
        
        if ($dsrmPlain -ne $dsrmConfirmPlain) {
            Write-Log "As senhas não coincidem!" -Level Error
        } elseif ($dsrmPlain.Length -lt 8) {
            Write-Log "A senha deve ter no mínimo 8 caracteres!" -Level Error
        }
    } while ($dsrmPlain -ne $dsrmConfirmPlain -or $dsrmPlain.Length -lt 8)

    $config.DSRMPassword = $dsrmPassword
    Write-Log "Senha DSRM configurada com sucesso" -Level Success

    # 1.3 - Configuração de Rede
    Write-Host "`n--- CONFIGURAÇÃO DE REDE ---" -ForegroundColor Cyan
    $config.NetworkSegments = @()
    $segmentCount = 1

    do {
        Write-Host "`nSegmento de Rede #$segmentCount" -ForegroundColor Yellow
        
        do {
            $networkIP = Read-Host "Digite o IP da rede (ex: 10.2.60.0)"
        } while (-not (Test-IPAddress $networkIP))
        
        do {
            $subnetMask = Read-Host "Digite a máscara de sub-rede (ex: 255.255.255.0 ou 24)"
            $validMask = $false
            $cidrValue = $null
            
            # Tentar converter se for CIDR (número)
            if ($subnetMask -match '^\d{1,2}$') {
                $cidrValue = [int]$subnetMask
                
                # Validar intervalo CIDR válido
                if ($cidrValue -ge 0 -and $cidrValue -le 32) {
                    $subnetMask = ConvertFrom-CIDR -CIDR $cidrValue
                    $validMask = $null -ne $subnetMask
                }
            } 
            # Ou validar se já é uma máscara em formato dotted decimal
            elseif (Test-IPAddress $subnetMask) {
                $validMask = $true
                $cidrValue = ConvertTo-CIDR -SubnetMask $subnetMask
            }
            
            if (-not $validMask) {
                Write-Log "Máscara de sub-rede inválida. Use formato CIDR (0-32) ou dotted decimal (ex: 255.255.255.0)" -Level Error
            }
        } while (-not $validMask)
        
        do {
            $gateway = Read-Host "Digite o gateway (ex: 10.2.60.1)"
        } while (-not (Test-IPAddress $gateway))
        
        $config.NetworkSegments += @{
            Network = $networkIP
            Mask = $subnetMask
            CIDR = $cidrValue
            Gateway = $gateway
        }
        
        Write-Log "Segmento $segmentCount adicionado: $networkIP/$cidrValue ($subnetMask) - Gateway: $gateway" -Level Success
        
        $addMore = Read-Host "`nDeseja adicionar outro segmento de rede? (S/N)"
        $segmentCount++
    } while ($addMore -eq 'S' -or $addMore -eq 's')

    # 1.4 - IP do Servidor DC
    Write-Host "`n--- CONFIGURAÇÃO DO SERVIDOR ---" -ForegroundColor Cyan
    do {
        $serverIP = Read-Host "Digite o IP estático para este servidor DC (ex: 10.2.60.10)"
    } while (-not (Test-IPAddress $serverIP))

    $config.ServerIP = $serverIP
    Write-Log "IP do servidor: $serverIP" -Level Success

    # 1.5 - Nome do Servidor
    $currentHostname = $env:COMPUTERNAME
    $defaultDCName = "$($config.DomainNetBIOS)-DC01"
    $serverName = Read-Host "`nDigite o nome do servidor DC (atual: $currentHostname) [Enter para '$defaultDCName']"
    if ([string]::IsNullOrWhiteSpace($serverName)) {
        $serverName = $defaultDCName
    }
    $config.ServerName = $serverName
    Write-Log "Nome do servidor: $serverName" -Level Success

    # 1.6 - Usuários
    Write-Host "`n--- USUÁRIOS DO DOMÍNIO ---" -ForegroundColor Cyan
    Write-Host "Digite os nomes completos dos usuários (um por linha)."
    Write-Host "Digite uma linha vazia quando terminar." -ForegroundColor Yellow

    $config.Users = @()
    $userCount = 1

    do {
        $fullName = Read-Host "`nUsuário #$userCount - Nome completo"
        if (-not [string]::IsNullOrWhiteSpace($fullName)) {
            $username = New-Username -FullName $fullName
            $config.Users += @{
                FullName = $fullName
                Username = $username
                FirstName = ($fullName -split '\s+')[0]
                LastName = (($fullName -split '\s+')[1..999] -join ' ')
            }
            Write-Host "  → Username: $username" -ForegroundColor Green
            $userCount++
        }
    } while (-not [string]::IsNullOrWhiteSpace($fullName))

    Write-Log "Total de usuários configurados: $($config.Users.Count)" -Level Success

    # 1.7 - Senha padrão dos usuários
    Write-Host "`n--- SENHA PADRÃO DOS USUÁRIOS ---" -ForegroundColor Cyan
    do {
        $userPassword = Read-Host "Digite a senha padrão inicial para os usuários (mínimo 8 caracteres)" -AsSecureString
        $userPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($userPassword))
    } while ($userPasswordPlain.Length -lt 8)

    $config.UserPassword = $userPassword
    Write-Log "Senha padrão dos usuários configurada" -Level Success

    # 1.8 - Configurações de GPO
    Write-Host "`n--- CONFIGURAÇÕES DE GPO ---" -ForegroundColor Cyan

    Write-Host "`nPolítica de Senhas:" -ForegroundColor Yellow
    $config.PasswordPolicy = @{
        MinLength = [int](Read-Host "  Comprimento mínimo da senha [Enter para 8]" -ErrorAction SilentlyContinue)
        MaxAge = [int](Read-Host "  Validade da senha em dias [Enter para 90]" -ErrorAction SilentlyContinue)
        MinAge = [int](Read-Host "  Idade mínima da senha em dias [Enter para 1]" -ErrorAction SilentlyContinue)
        HistoryCount = [int](Read-Host "  Histórico de senhas [Enter para 5]" -ErrorAction SilentlyContinue)
    }

    if ($config.PasswordPolicy.MinLength -eq 0) { $config.PasswordPolicy.MinLength = 8 }
    if ($config.PasswordPolicy.MaxAge -eq 0) { $config.PasswordPolicy.MaxAge = 90 }
    if ($config.PasswordPolicy.MinAge -eq 0) { $config.PasswordPolicy.MinAge = 1 }
    if ($config.PasswordPolicy.HistoryCount -eq 0) { $config.PasswordPolicy.HistoryCount = 5 }

    Write-Host "`nPolítica de Bloqueio de Conta:" -ForegroundColor Yellow
    $config.LockoutPolicy = @{
        Threshold = [int](Read-Host "  Limite de tentativas inválidas [Enter para 5]" -ErrorAction SilentlyContinue)
        Duration = [int](Read-Host "  Duração do bloqueio em minutos [Enter para 30]" -ErrorAction SilentlyContinue)
        Window = [int](Read-Host "  Janela de contagem em minutos [Enter para 30]" -ErrorAction SilentlyContinue)
    }

    if ($config.LockoutPolicy.Threshold -eq 0) { $config.LockoutPolicy.Threshold = 5 }
    if ($config.LockoutPolicy.Duration -eq 0) { $config.LockoutPolicy.Duration = 30 }
    if ($config.LockoutPolicy.Window -eq 0) { $config.LockoutPolicy.Window = 30 }

    Write-Log "Políticas de GPO configuradas" -Level Success

    # 1.9 - Instalação do DHCP
    $installDHCP = Read-Host "`nDeseja instalar e configurar o serviço DHCP? (S/N)"
    $config.InstallDHCP = ($installDHCP -eq 'S' -or $installDHCP -eq 's')

    if ($config.InstallDHCP) {
        Write-Host "`n--- CONFIGURAÇÃO DHCP ---" -ForegroundColor Cyan
        $config.DHCPScopes = @()
        
        foreach ($segment in $config.NetworkSegments) {
            Write-Host "`nConfiguração DHCP para rede $($segment.Network)" -ForegroundColor Yellow
            
            $startIP = Read-Host "  IP inicial do range DHCP (ex: 10.2.60.100)"
            $endIP = Read-Host "  IP final do range DHCP (ex: 10.2.60.200)"
            $leaseDays = Read-Host "  Duração do lease em dias [Enter para 8]"
            if ([string]::IsNullOrWhiteSpace($leaseDays)) { $leaseDays = 8 }
            
            $config.DHCPScopes += @{
                Network = $segment.Network
                StartIP = $startIP
                EndIP = $endIP
                Mask = $segment.Mask
                Gateway = $segment.Gateway
                DNS = $config.ServerIP
                LeaseDays = [int]$leaseDays
            }
            
            Write-Log "Escopo DHCP configurado para $($segment.Network)" -Level Success
        }
    }

    # 1.10 - Padrão de nomenclatura de estações
    Write-Host "`n--- NOMENCLATURA DE ESTAÇÕES ---" -ForegroundColor Cyan
    $workstationPattern = Read-Host "Digite o padrão de nomenclatura (use <ID> e <USER>) [Enter para '$($config.DomainNetBIOS)-<ID>-<USER>']"
    if ([string]::IsNullOrWhiteSpace($workstationPattern)) {
        $workstationPattern = "$($config.DomainNetBIOS)-<ID>-<USER>"
    }
    $config.WorkstationPattern = $workstationPattern
    Write-Log "Padrão de nomenclatura: $workstationPattern" -Level Success

    # Resumo da configuração
    Write-Host "`n`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "   RESUMO DA CONFIGURAÇÃO" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "`nDomínio: $($config.DomainName) (NetBIOS: $($config.DomainNetBIOS))" -ForegroundColor White
    Write-Host "Servidor: $($config.ServerName) - IP: $($config.ServerIP)" -ForegroundColor White
    Write-Host "Usuários: $($config.Users.Count)" -ForegroundColor White
    Write-Host "Segmentos de rede: $($config.NetworkSegments.Count)" -ForegroundColor White
    Write-Host "DHCP: $(if($config.InstallDHCP){'SIM'}else{'NÃO'})" -ForegroundColor White
    Write-Host "`nPolítica de Senhas:" -ForegroundColor White
    Write-Host "  - Comprimento mínimo: $($config.PasswordPolicy.MinLength)" -ForegroundColor Gray
    Write-Host "  - Validade: $($config.PasswordPolicy.MaxAge) dias" -ForegroundColor Gray
    Write-Host "  - Histórico: $($config.PasswordPolicy.HistoryCount)" -ForegroundColor Gray
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

    $confirm = Read-Host "`nDeseja continuar com a implementação? (S/N)"
    if ($confirm -ne 'S' -and $confirm -ne 's') {
        Write-Log "Implementação cancelada pelo usuário" -Level Warning
        exit
    }
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
    try {
        $config | Export-Clixml -Path $configContinuePath -Force -ErrorAction Stop
        Write-Log "Configuração salva em: $configContinuePath" -Level Success
        Write-Host "`n✅ Configuração salva para continuação pós-reboot" -ForegroundColor Green
    } catch {
        Write-Log "Erro ao salvar configuração: $_" -Level Error
        Write-Host "`n⚠️  AVISO: Falha ao salvar configuração. Você pode perder as definições." -ForegroundColor Yellow
    }
    
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "   PRÓXIMA ETAPA: Reinicialização Necessária" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "`nApós reiniciar, execute novamente:" -ForegroundColor White
    Write-Host "   PowerShell.exe -ExecutionPolicy Bypass -File $PSCommandPath" -ForegroundColor Cyan
    Write-Host "`nO script continuará automaticamente a partir da próxima fase." -ForegroundColor Gray
    
    $rebootNow = Read-Host "`nDeseja reiniciar agora? (S/N)"
    if ($rebootNow -eq 'S' -or $rebootNow -eq 's') {
        Write-Log "Reiniciando servidor..." -Level Info
        Write-Host "`n⏳ Servidor será reiniciado em 10 segundos..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        Restart-Computer -Force
        exit 0
    } else {
        Write-Log "Reinicialização adiada. Reinicie o servidor manualmente quando estiver pronto." -Level Warning
        Write-Host "`n⚠️  Reinicie o servidor manualmente e execute o script novamente." -ForegroundColor Yellow
        Write-Host "    Comando: PowerShell.exe -ExecutionPolicy Bypass -File $PSCommandPath" -ForegroundColor Cyan
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
} catch {
    Write-Log "Erro ao configurar IP: $_" -Level Error
    throw
}

# =====================================================
# FASE 3: INSTALAÇÃO DO ACTIVE DIRECTORY
# =====================================================
Write-Host "`n[FASE 3] INSTALAÇÃO DO ACTIVE DIRECTORY" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# 3.1 - Instalar recursos AD DS e DNS
Write-Log "Instalando recursos AD-Domain-Services..." -Level Info
try {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
    Write-Log "AD-Domain-Services instalado com sucesso" -Level Success
} catch {
    Write-Log "Erro ao instalar AD-Domain-Services: $_" -Level Error
    exit
}

# 3.2 - Promover a Domain Controller
Write-Log "Promovendo servidor a Domain Controller..." -Level Info
Write-Host "`nEste processo pode levar vários minutos..." -ForegroundColor Yellow

try {
    Import-Module ADDSDeployment
    
    Install-ADDSForest `
        -DomainName $config.DomainName `
        -DomainNetbiosName $config.DomainNetBIOS `
        -ForestMode "WinThreshold" `
        -DomainMode "WinThreshold" `
        -InstallDns:$true `
        -SafeModeAdministratorPassword $config.DSRMPassword `
        -Force:$true `
        -NoRebootOnCompletion:$false
    
    Write-Log "Domain Controller criado com sucesso!" -Level Success
    Write-Host "`nO servidor será reiniciado automaticamente..." -ForegroundColor Yellow
    
} catch {
    Write-Log "Erro ao promover Domain Controller: $_" -Level Error
    exit
}

# =====================================================
# FASE 4: CONFIGURAÇÃO PÓS-INSTALAÇÃO (Após reinicialização)
# =====================================================
# Esta parte será executada após o servidor reiniciar

Write-Log "Aguardando reinicialização do servidor..." -Level Info
Write-Host "`nApós a reinicialização, faça login como Administrador do domínio" -ForegroundColor Yellow
Write-Host "e execute a segunda parte do script: ADConfig_Part2.ps1" -ForegroundColor Yellow

# Salvar configuração para Parte 2
$config | Export-Clixml -Path $configPart2Path

# Criar script da Parte 2
$part2Script = @'
#Requires -RunAsAdministrator
# PARTE 2: Configuração pós-instalação do AD

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   PARTE 2: CONFIGURAÇÃO PÓS-INSTALAÇÃO" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Carregar configuração salva
if (-not (Test-Path $configPart2Path)) {
    Write-Host "Arquivo de configuração não encontrado!" -ForegroundColor Red
    exit
}

$config = Import-Clixml -Path $configPart2Path

function Write-Log {
    param([string]$Message, [string]$Level = 'Info')
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor Cyan }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
    }
    $logFile = "C:\ADDeployment_Part2_$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logMessage
}

# Aguardar serviços do AD iniciarem
Write-Log "Aguardando serviços do Active Directory..." -Level Info
Start-Sleep -Seconds 30

# Importar módulo AD
Import-Module ActiveDirectory

# =====================================================
# FASE 4: CONFIGURAÇÃO DO DNS
# =====================================================
Write-Host "`n[FASE 4] CONFIGURAÇÃO DO DNS" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Log "Configurando zonas de DNS reverso..." -Level Info

foreach ($segment in $config.NetworkSegments) {
    $networkID = $segment.Network -replace '\.\d+$',''
    $lastOctet = ($segment.Network -split '\.')[-1]
    
    try {
        # Criar zona reversa
        Add-DnsServerPrimaryZone -NetworkID "$networkID.0/24" -ReplicationScope "Forest" -ErrorAction Stop
        Write-Log "Zona reversa criada para $($segment.Network)" -Level Success
    } catch {
        Write-Log "Erro ao criar zona reversa: $_" -Level Warning
    }
}

# Configurar encaminhadores DNS
Write-Log "Configurando encaminhadores DNS..." -Level Info
try {
    Set-DnsServerForwarder -IPAddress "8.8.8.8","1.1.1.1" -ErrorAction Stop
    Write-Log "Encaminhadores DNS configurados (Google e Cloudflare)" -Level Success
} catch {
    Write-Log "Erro ao configurar encaminhadores: $_" -Level Warning
}

# =====================================================
# FASE 5: ESTRUTURA ORGANIZACIONAL
# =====================================================
Write-Host "`n[FASE 5] CRIAÇÃO DA ESTRUTURA ORGANIZACIONAL" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$domainDN = "DC=" + ($config.DomainName -replace '\.',',DC=')
$ouPrefix = $config.DomainNetBIOS

# Criar OUs principais
Write-Log "Criando estrutura de OUs..." -Level Info

$ous = @(
    @{Name="$ouPrefix-Computadores"; Path=$domainDN},
    @{Name="$ouPrefix-Desktops"; Path="OU=$ouPrefix-Computadores,$domainDN"},
    @{Name="$ouPrefix-Laptops"; Path="OU=$ouPrefix-Computadores,$domainDN"},
    @{Name="$ouPrefix-Usuarios"; Path=$domainDN},
    @{Name="$ouPrefix-Administrativos"; Path="OU=$ouPrefix-Usuarios,$domainDN"},
    @{Name="$ouPrefix-Operacionais"; Path="OU=$ouPrefix-Usuarios,$domainDN"},
    @{Name="$ouPrefix-Grupos"; Path=$domainDN},
    @{Name="$ouPrefix-Servidores"; Path=$domainDN}
)

foreach ($ou in $ous) {
    try {
        New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
        Write-Log "OU criada: $($ou.Name)" -Level Success
    } catch {
        Write-Log "Erro ao criar OU $($ou.Name): $_" -Level Warning
    }
}

# =====================================================
# FASE 6: CRIAÇÃO DE USUÁRIOS
# =====================================================
Write-Host "`n[FASE 6] CRIAÇÃO DE USUÁRIOS" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Log "Criando contas de usuários..." -Level Info

$usersOU = "OU=$ouPrefix-Operacionais,OU=$ouPrefix-Usuarios,$domainDN"

foreach ($user in $config.Users) {
    try {
        New-ADUser `
            -Name $user.FullName `
            -GivenName $user.FirstName `
            -Surname $user.LastName `
            -SamAccountName $user.Username `
            -UserPrincipalName "$($user.Username)@$($config.DomainName)" `
            -Path $usersOU `
            -AccountPassword $config.UserPassword `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -PasswordNeverExpires $false `
            -ErrorAction Stop
        
        Write-Log "Usuário criado: $($user.Username) ($($user.FullName))" -Level Success
    } catch {
        Write-Log "Erro ao criar usuário $($user.Username): $_" -Level Error
    }
}

# =====================================================
# FASE 7: GRUPOS DE SEGURANÇA
# =====================================================
Write-Host "`n[FASE 7] CRIAÇÃO DE GRUPOS" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Log "Criando grupos de segurança..." -Level Info

$groupsOU = "OU=$ouPrefix-Grupos,$domainDN"

$groups = @(
    @{Name="GRP-Usuarios-Padrao"; Description="Grupo padrão de usuários"},
    @{Name="GRP-Administradores-TI"; Description="Administradores de TI"},
    @{Name="GRP-Gerencia"; Description="Gerência"}
)

foreach ($group in $groups) {
    try {
        New-ADGroup `
            -Name $group.Name `
            -GroupScope Global `
            -GroupCategory Security `
            -Path $groupsOU `
            -Description $group.Description `
            -ErrorAction Stop
        
        Write-Log "Grupo criado: $($group.Name)" -Level Success
    } catch {
        Write-Log "Erro ao criar grupo $($group.Name): $_" -Level Warning
    }
}

# Adicionar usuários ao grupo padrão
Write-Log "Adicionando usuários ao grupo padrão..." -Level Info
foreach ($user in $config.Users) {
    try {
        Add-ADGroupMember -Identity "GRP-Usuarios-Padrao" -Members $user.Username -ErrorAction Stop
    } catch {
        Write-Log "Erro ao adicionar $($user.Username) ao grupo: $_" -Level Warning
    }
}

# =====================================================
# FASE 8: POLÍTICAS DE GRUPO (GPO)
# =====================================================
Write-Host "`n[FASE 8] CONFIGURAÇÃO DE POLÍTICAS DE GRUPO" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Log "Configurando políticas de domínio..." -Level Info

# Política de senha
try {
    Set-ADDefaultDomainPasswordPolicy `
        -Identity $config.DomainName `
        -MinPasswordLength $config.PasswordPolicy.MinLength `
        -MaxPasswordAge (New-TimeSpan -Days $config.PasswordPolicy.MaxAge) `
        -MinPasswordAge (New-TimeSpan -Days $config.PasswordPolicy.MinAge) `
        -PasswordHistoryCount $config.PasswordPolicy.HistoryCount `
        -ComplexityEnabled $true `
        -ReversibleEncryptionEnabled $false `
        -LockoutThreshold $config.LockoutPolicy.Threshold `
        -LockoutDuration (New-TimeSpan -Minutes $config.LockoutPolicy.Duration) `
        -LockoutObservationWindow (New-TimeSpan -Minutes $config.LockoutPolicy.Window) `
        -ErrorAction Stop
    
    Write-Log "Política de senhas configurada com sucesso" -Level Success
} catch {
    Write-Log "Erro ao configurar política de senhas: $_" -Level Error
}

# Criar GPOs personalizadas
Write-Log "Criando GPOs personalizadas..." -Level Info

Import-Module GroupPolicy

# GPO: Política de Auditoria
try {
    $gpoAudit = New-GPO -Name "$ouPrefix-Politica-Auditoria" -ErrorAction Stop
    $gpoAudit | New-GPLink -Target $domainDN -ErrorAction Stop
    Write-Log "GPO de Auditoria criada e vinculada" -Level Success
} catch {
    Write-Log "Erro ao criar GPO de Auditoria: $_" -Level Warning
}

# GPO: Configuração de Workstations
try {
    $gpoWorkstations = New-GPO -Name "$ouPrefix-Config-Workstations" -ErrorAction Stop
    $gpoWorkstations | New-GPLink -Target "OU=$ouPrefix-Computadores,$domainDN" -ErrorAction Stop
    Write-Log "GPO de Workstations criada e vinculada" -Level Success
} catch {
    Write-Log "Erro ao criar GPO de Workstations: $_" -Level Warning
}

# GPO: Restrições de Usuário
try {
    $gpoUsers = New-GPO -Name "$ouPrefix-Restricoes-Usuario" -ErrorAction Stop
    $gpoUsers | New-GPLink -Target "OU=$ouPrefix-Usuarios,$domainDN" -ErrorAction Stop
    Write-Log "GPO de Usuários criada e vinculada" -Level Success
} catch {
    Write-Log "Erro ao criar GPO de Usuários: $_" -Level Warning
}

# =====================================================
# FASE 9: INSTALAÇÃO DO DHCP (SE SOLICITADO)
# =====================================================
if ($config.InstallDHCP) {
    Write-Host "`n[FASE 9] INSTALAÇÃO E CONFIGURAÇÃO DO DHCP" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    Write-Log "Instalando serviço DHCP..." -Level Info
    
    try {
        # Instalar DHCP
        Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction Stop
        Write-Log "DHCP instalado com sucesso" -Level Success
        
        # Autorizar servidor DHCP no AD
        Add-DhcpServerInDC -DnsName "$($config.ServerName).$($config.DomainName)" -IPAddress $config.ServerIP -ErrorAction Stop
        Write-Log "Servidor DHCP autorizado no Active Directory" -Level Success
        
        # Configurar escopos DHCP
        foreach ($scope in $config.DHCPScopes) {
            $scopeID = $scope.Network
            $scopeName = "Escopo-$scopeID"
            
            try {
                # Criar escopo
                Add-DhcpServerv4Scope `
                    -Name $scopeName `
                    -StartRange $scope.StartIP `
                    -EndRange $scope.EndIP `
                    -SubnetMask $scope.Mask `
                    -State Active `
                    -LeaseDuration (New-TimeSpan -Days $scope.LeaseDays) `
                    -ErrorAction Stop
                
                # Configurar opções do escopo
                Set-DhcpServerv4OptionValue `
                    -ScopeId $scopeID `
                    -Router $scope.Gateway `
                    -DnsServer $scope.DNS `
                    -DnsDomain $config.DomainName `
                    -ErrorAction Stop
                
                Write-Log "Escopo DHCP criado: $scopeName ($($scope.StartIP) - $($scope.EndIP))" -Level Success
            } catch {
                Write-Log "Erro ao criar escopo DHCP para $scopeID: $_" -Level Error
            }
        }
        
        # Completar configuração do DHCP
        Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2 -ErrorAction SilentlyContinue
        
    } catch {
        Write-Log "Erro ao instalar DHCP: $_" -Level Error
    }
}

# =====================================================
# FASE 10: VALIDAÇÃO E TESTES
# =====================================================
Write-Host "`n[FASE 10] VALIDAÇÃO DA INSTALAÇÃO" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Log "Executando validação do Domain Controller..." -Level Info

# Teste 1: DCDiag
Write-Log "Executando DCDiag..." -Level Info
try {
    $dcdiag = dcdiag /v
    $dcdiag | Out-File "C:\DCDiag_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    Write-Log "DCDiag executado - resultado salvo em C:\DCDiag_*.txt" -Level Success
} catch {
    Write-Log "Erro ao executar DCDiag: $_" -Level Warning
}

# Teste 2: Replicação
Write-Log "Verificando replicação do AD..." -Level Info
try {
    $repadmin = repadmin /replsummary
    $repadmin | Out-File "C:\Repadmin_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    Write-Log "Replicação verificada - resultado salvo em C:\Repadmin_*.txt" -Level Success
} catch {
    Write-Log "Erro ao verificar replicação: $_" -Level Warning
}

# Teste 3: DNS
Write-Log "Testando resolução DNS..." -Level Info
try {
    $dnsTest = Resolve-DnsName -Name $config.DomainName -Server 127.0.0.1 -ErrorAction Stop
    Write-Log "DNS resolvendo corretamente: $($config.DomainName)" -Level Success
} catch {
    Write-Log "Erro na resolução DNS: $_" -Level Error
}

# Teste 4: Serviços
Write-Log "Verificando serviços críticos..." -Level Info
$services = @('NTDS', 'DNS', 'Netlogon', 'W32Time')
foreach ($service in $services) {
    $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') {
        Write-Log "Serviço $service: Running" -Level Success
    } else {
        Write-Log "Serviço $service: PROBLEMA!" -Level Error
    }
}

# Teste 5: Contar objetos criados
$userCount = (Get-ADUser -Filter * -SearchBase "OU=$ouPrefix-Usuarios,$domainDN").Count
$ouCount = (Get-ADOrganizationalUnit -Filter * -SearchBase $domainDN).Count
$groupCount = (Get-ADGroup -Filter * -SearchBase "OU=$ouPrefix-Grupos,$domainDN" -ErrorAction SilentlyContinue).Count
$gpoCount = (Get-GPO -All).Count

Write-Log "Objetos criados - Usuários: $userCount | OUs: $ouCount | Grupos: $groupCount | GPOs: $gpoCount" -Level Info

# =====================================================
# RELATÓRIO FINAL
# =====================================================
Write-Host "`n`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   IMPLEMENTAÇÃO CONCLUÍDA!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`n📊 RESUMO DA IMPLEMENTAÇÃO:" -ForegroundColor Yellow
Write-Host "   Domínio: $($config.DomainName)" -ForegroundColor White
Write-Host "   NetBIOS: $($config.DomainNetBIOS)" -ForegroundColor White
Write-Host "   Servidor DC: $($config.ServerName) ($($config.ServerIP))" -ForegroundColor White
Write-Host "   Usuários criados: $userCount" -ForegroundColor White
Write-Host "   Grupos criados: $groupCount" -ForegroundColor White
Write-Host "   OUs criadas: $ouCount" -ForegroundColor White
Write-Host "   GPOs criadas: $gpoCount" -ForegroundColor White
if ($config.InstallDHCP) {
    Write-Host "   DHCP: Instalado e configurado" -ForegroundColor White
}

Write-Host "`n📋 PRÓXIMOS PASSOS:" -ForegroundColor Yellow
Write-Host "   1. Revisar os logs de validação:" -ForegroundColor White
Write-Host "      - C:\DCDiag_*.txt" -ForegroundColor Gray
Write-Host "      - C:\Repadmin_*.txt" -ForegroundColor Gray
Write-Host "      - C:\ADDeployment_Part2_*.log" -ForegroundColor Gray
Write-Host "`n   2. Configurar backup do Active Directory" -ForegroundColor White
Write-Host "`n   3. Documentar a senha DSRM em local seguro" -ForegroundColor White
Write-Host "`n   4. Ingressar estações de trabalho no domínio" -ForegroundColor White
Write-Host "      Padrão de nomenclatura: $($config.WorkstationPattern)" -ForegroundColor Gray

Write-Host "`n📝 LISTA DE ESTAÇÕES SUGERIDAS:" -ForegroundColor Yellow
$workstationID = 1
foreach ($user in $config.Users) {
    $userShort = ($user.Username -split '\.')[0].Substring(0, [Math]::Min(1, ($user.Username -split '\.')[0].Length)) + `
                 ($user.Username -split '\.')[-1].ToUpper()
    if ($userShort.Length -gt 8) { $userShort = $userShort.Substring(0, 8) }
    
    $wsName = $config.WorkstationPattern `
        -replace '<ID>', $workstationID.ToString('00') `
        -replace '<USER>', $userShort
    
    Write-Host "   $wsName → $($user.FullName) ($($user.Username))" -ForegroundColor Gray
    $workstationID++
}

Write-Host "`n   5. Refinar e testar GPOs conforme necessário" -ForegroundColor White
Write-Host "`n   6. Configurar monitoramento e alertas" -ForegroundColor White

Write-Host "`n⚠️  IMPORTANTE:" -ForegroundColor Red
Write-Host "   - A senha padrão dos usuários está configurada para expirar no primeiro logon" -ForegroundColor Yellow
Write-Host "   - Certifique-se de documentar todas as senhas administrativas" -ForegroundColor Yellow
Write-Host "   - Configure backup antes de colocar em produção" -ForegroundColor Yellow

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Criar arquivo de documentação
$docContent = @"
═══════════════════════════════════════════════════════════════
  DOCUMENTAÇÃO DA IMPLEMENTAÇÃO - $($config.DomainName)
═══════════════════════════════════════════════════════════════

Data de Implementação: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')

INFORMAÇÕES DO DOMÍNIO
─────────────────────────────────────────────────────────────
Nome do Domínio: $($config.DomainName)
NetBIOS: $($config.DomainNetBIOS)
Nível Funcional: Windows Server 2016

SERVIDOR DOMAIN CONTROLLER
─────────────────────────────────────────────────────────────
Nome: $($config.ServerName)
IP: $($config.ServerIP)
Sistema Operacional: Windows Server 2022

SEGMENTOS DE REDE
─────────────────────────────────────────────────────────────
"@

foreach ($segment in $config.NetworkSegments) {
    $docContent += "`nRede: $($segment.Network)/$($segment.Mask)"
    $docContent += "`nGateway: $($segment.Gateway)"
}

$docContent += @"

`n
ESTRUTURA ORGANIZACIONAL
─────────────────────────────────────────────────────────────
$ouPrefix-Computadores
├── $ouPrefix-Desktops
└── $ouPrefix-Laptops

$ouPrefix-Usuarios
├── $ouPrefix-Administrativos
└── $ouPrefix-Operacionais

$ouPrefix-Grupos
$ouPrefix-Servidores

USUÁRIOS CRIADOS
─────────────────────────────────────────────────────────────
"@

foreach ($user in $config.Users) {
    $docContent += "`n$($user.Username) - $($user.FullName)"
}

$docContent += @"

`n
GRUPOS DE SEGURANÇA
─────────────────────────────────────────────────────────────
- GRP-Usuarios-Padrao
- GRP-Administradores-TI
- GRP-Gerencia

POLÍTICAS DE GRUPO
─────────────────────────────────────────────────────────────
Política de Senhas:
- Comprimento mínimo: $($config.PasswordPolicy.MinLength) caracteres
- Validade: $($config.PasswordPolicy.MaxAge) dias
- Idade mínima: $($config.PasswordPolicy.MinAge) dias
- Histórico: $($config.PasswordPolicy.HistoryCount) senhas
- Complexidade: Habilitada

Política de Bloqueio:
- Limite de tentativas: $($config.LockoutPolicy.Threshold)
- Duração do bloqueio: $($config.LockoutPolicy.Duration) minutos
- Janela de observação: $($config.LockoutPolicy.Window) minutos

GPOs Criadas:
- $ouPrefix-Politica-Auditoria
- $ouPrefix-Config-Workstations
- $ouPrefix-Restricoes-Usuario
"@

if ($config.InstallDHCP) {
    $docContent += @"

`n
CONFIGURAÇÃO DHCP
─────────────────────────────────────────────────────────────
"@
    foreach ($scope in $config.DHCPScopes) {
        $docContent += "`n`nEscopo: $($scope.Network)"
        $docContent += "`nRange: $($scope.StartIP) - $($scope.EndIP)"
        $docContent += "`nMáscara: $($scope.Mask)"
        $docContent += "`nGateway: $($scope.Gateway)"
        $docContent += "`nDNS: $($scope.DNS)"
        $docContent += "`nDuração do Lease: $($scope.LeaseDays) dias"
    }
}

$docContent += @"

`n
NOMENCLATURA DE ESTAÇÕES
─────────────────────────────────────────────────────────────
Padrão: $($config.WorkstationPattern)

Estações Sugeridas:
"@

$workstationID = 1
foreach ($user in $config.Users) {
    $userShort = ($user.Username -split '\.')[0].Substring(0, [Math]::Min(1, ($user.Username -split '\.')[0].Length)) + `
                 ($user.Username -split '\.')[-1].ToUpper()
    if ($userShort.Length -gt 8) { $userShort = $userShort.Substring(0, 8) }
    
    $wsName = $config.WorkstationPattern `
        -replace '<ID>', $workstationID.ToString('00') `
        -replace '<USER>', $userShort
    
    $docContent += "`n$wsName → $($user.FullName)"
    $workstationID++
}

$docContent += @"

`n
SENHAS ADMINISTRATIVAS
─────────────────────────────────────────────────────────────
⚠️  DOCUMENTO CONFIDENCIAL - MANTER EM LOCAL SEGURO

DSRM Password: [DOCUMENTAR MANUALMENTE]
Administrator Domain: [DOCUMENTAR MANUALMENTE]

TAREFAS DE MANUTENÇÃO
─────────────────────────────────────────────────────────────
□ Configurar backup do System State (diário)
□ Configurar backup das zonas DNS
□ Configurar monitoramento de eventos
□ Documentar procedimento de recuperação
□ Agendar revisão mensal com dcdiag
□ Configurar alertas de replicação
□ Revisar políticas de grupo trimestralmente

LOGS E VALIDAÇÃO
─────────────────────────────────────────────────────────────
- DCDiag: C:\DCDiag_*.txt
- Repadmin: C:\Repadmin_*.txt
- Log de Implementação: C:\ADDeployment_Part2_*.log

═══════════════════════════════════════════════════════════════
FIM DA DOCUMENTAÇÃO
═══════════════════════════════════════════════════════════════
"@

# Salvar documentação
$docPath = "C:\AD_Implementation_Documentation_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$docContent | Out-File -FilePath $docPath -Encoding UTF8

Write-Host "`n📄 Documentação salva em: $docPath" -ForegroundColor Green

Write-Log "Implementação do Active Directory concluída com sucesso!" -Level Success

Write-Host "`nPressione qualquer tecla para finalizar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
'@

# Salvar script da Parte 2
$part2Path = "C:\gestao\ADConfig_Part2.ps1"
$part2Script | Out-File -FilePath $part2Path -Encoding UTF8 -Force

# Verificar se o arquivo foi realmente criado
if (Test-Path $part2Path) {
    $fileSize = (Get-Item $part2Path).Length
    Write-Log "Script da Parte 2 criado com sucesso: $part2Path ($fileSize bytes)" -Level Success
    Write-Host "`n✅ Script da Parte 2 criado: $part2Path" -ForegroundColor Green
    Write-Host "   Tamanho: $fileSize bytes" -ForegroundColor Gray
} else {
    Write-Log "ERRO: Script da Parte 2 não foi criado!" -Level Error
    Write-Host "`n❌ ERRO: Falha ao criar script da Parte 2" -ForegroundColor Red
}

Write-Host "`nApós reinicialização, execute: PowerShell.exe -ExecutionPolicy Bypass -File C:\gestao\ADConfig_Part2.ps1" -ForegroundColor Yellow
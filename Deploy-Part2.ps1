#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Parte 2 - Configuração pós-instalação do Active Directory
.DESCRIPTION
    Realiza configuração pós-instalação: OUs, usuários, grupos, GPOs, DNS, etc.
    
.PARAMETER ConfigFile
    Caminho para o arquivo de configuração (padrão: Config/Default.psd1)
    
.NOTES
    Autor: BRMC IT Team
    Versão: 2.0
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
Write-Host "║  CONFIGURAÇÃO PÓS-INSTALAÇÃO - VERSÃO 2.0 MODULAR         ║" -ForegroundColor Cyan
Write-Host "║  Parte 2 - Após Domain Controller                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# =====================================================
# CARREGAR FUNÇÕES
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
    # implementar com ADDeployment.Validação.psm1 futuramente
    Write-Host "Validation.ps1 carregado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao carregar Validation.ps1: $_" -ForegroundColor Red
    exit 1
}

# =====================================================
# CRIAR LOGGER
# =====================================================

$logPath = "$PSScriptRoot\Logs\ADDeployment_Part2_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

try {
    $logger = [ADLogger]::new($logPath, $true, $true)
    $logger.Info("═══════════════════════════════════════════════════════════")
    $logger.Info("CONFIGURAÇÃO PÓS-INSTALAÇÃO - VERSÃO 2.0 MODULAR")
    $logger.Info("Parte 2 - Após Domain Controller")
    $logger.Info("═══════════════════════════════════════════════════════════")
    Write-Host "Logger inicializado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao criar logger: $_" -ForegroundColor Red
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
# FASE 4: CONFIGURAÇÃO DO DNS
# =====================================================

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
Write-Host "FASE 4: CONFIGURAÇÃO DO DNS" -ForegroundColor Yellow
Write-Host ("=" * 64) -ForegroundColor Cyan

$logger.Info("Iniciando Fase 4: Configuração do DNS")

try {
    $domainDN = "DC=$($config.Domain.Name -replace '\.', ',DC=')"
    
    Write-Host "`nConfigurando encaminhadores DNS..." -ForegroundColor Yellow
    $logger.Info("Configurando encaminhadores DNS")
    
    Set-DnsServerForwarder -IPAddress $config.Advanced.DNSForwarders -ErrorAction Stop
    $logger.Success("Encaminhadores DNS configurados: $($config.Advanced.DNSForwarders -join ', ')")
    Write-Host "Encaminhadores DNS configurados" -ForegroundColor Green
    
} catch {
    $logger.Error("Erro na Fase 4: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
}

# =====================================================
# FASE 5: CRIAR ESTRUTURA DE OUs
# =====================================================

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
Write-Host "FASE 5: CRIAÇÃO DA ESTRUTURA DE OUs" -ForegroundColor Yellow
Write-Host ("=" * 64) -ForegroundColor Cyan

$logger.Info("Iniciando Fase 5: Criação da estrutura de OUs")

try {
    $domainDN = "DC=$($config.Domain.Name -replace '\.', ',DC=')"
    $ouPrefix = $config.OrganizationalUnits.Pattern
    
    Write-Host "`nCriando OUs..." -ForegroundColor Yellow
    $logger.Info("Criando estrutura de OUs no domínio $domainDN")
    
    $ous = @(
        @{ Name = $config.OrganizationalUnits.Computers; Path = $domainDN }
        @{ Name = "Desktops"; Path = "OU=$($config.OrganizationalUnits.Computers),$domainDN" }
        @{ Name = "Laptops"; Path = "OU=$($config.OrganizationalUnits.Computers),$domainDN" }
        @{ Name = $config.OrganizationalUnits.Users; Path = $domainDN }
        @{ Name = "Administrativos"; Path = "OU=$($config.OrganizationalUnits.Users),$domainDN" }
        @{ Name = "Operacionais"; Path = "OU=$($config.OrganizationalUnits.Users),$domainDN" }
        @{ Name = $config.OrganizationalUnits.Groups; Path = $domainDN }
        @{ Name = $config.OrganizationalUnits.Servers; Path = $domainDN }
    )
    
    foreach ($ou in $ous) {
        try {
            New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
            $logger.Success("OU criada: $($ou.Name)")
            Write-Host "OU criada: $($ou.Name)" -ForegroundColor Green
        } catch {
            if ($_ -match "already exists") {
                $logger.Info("OU já existe: $($ou.Name)")
                Write-Host "OU já existe: $($ou.Name)" -ForegroundColor Gray
            } else {
                throw $_
            }
        }
    }
    
    $logger.Success("Estrutura de OUs criada com sucesso")
    
} catch {
    $logger.Error("Erro na Fase 5: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
}

# =====================================================
# FASE 6: CRIAR GRUPOS DE SEGURANÇA
# =====================================================

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
Write-Host "FASE 6: CRIAÇÃO DE GRUPOS" -ForegroundColor Yellow
Write-Host ("=" * 64) -ForegroundColor Cyan

$logger.Info("Iniciando Fase 6: Criação de grupos de segurança")

try {
    $domainDN = "DC=$($config.Domain.Name -replace '\.', ',DC=')"
    $groupsOU = "OU=$($config.OrganizationalUnits.Groups),$domainDN"
    
    Write-Host "`nCriando grupos de segurança..." -ForegroundColor Yellow
    $logger.Info("Criando grupos no OU: $groupsOU")
    
    foreach ($group in $config.Groups) {
        try {
            New-ADGroup `
                -Name $group.Name `
                -SamAccountName $group.Name `
                -GroupScope $group.Scope `
                -GroupCategory $group.Category `
                -DisplayName $group.Name `
                -Path $groupsOU `
                -Description $group.Description `
                -ErrorAction Stop
            
            $logger.Success("Grupo criado: $($group.Name)")
            Write-Host "Grupo criado: $($group.Name)" -ForegroundColor Green
        } catch {
            if ($_ -match "already exists") {
                $logger.Info("Grupo já existe: $($group.Name)")
                Write-Host "Grupo já existe: $($group.Name)" -ForegroundColor Gray
            } else {
                throw $_
            }
        }
    }
    
    $logger.Success("Grupos de segurança criados com sucesso")
    
} catch {
    $logger.Error("Erro na Fase 6: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
}

# =====================================================
# FASE 7: CRIAR USUÁRIOS
# =====================================================

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
Write-Host "FASE 7: CRIAÇÃO DE USUÁRIOS" -ForegroundColor Yellow
Write-Host ("=" * 64) -ForegroundColor Cyan

$logger.Info("Iniciando Fase 7: Criação de usuários")

try {
    $domainDN = "DC=$($config.Domain.Name -replace '\.', ',DC=')"
    $usersOU = "OU=Operacionais,OU=$($config.OrganizationalUnits.Users),$domainDN"
    
    Write-Host "`nCriando usuários..." -ForegroundColor Yellow
    $logger.Info("Criando usuários no OU: $usersOU")
    
    # Solicitar senha padrão se não estiver configurada
    if ([string]::IsNullOrWhiteSpace($config.Passwords.DefaultUser)) {
        do {
            $userPassword = Read-Host "Digite a senha padrão para os usuários (mínimo 8 caracteres)" -AsSecureString
            $userPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($userPassword))
            
            if ($userPasswordPlain.Length -lt 8) {
                Write-Host "A senha deve ter no mínimo 8 caracteres" -ForegroundColor Yellow
            }
        } while ($userPasswordPlain.Length -lt 8)
    } else {
        $userPassword = ConvertTo-SecureString $config.Passwords.DefaultUser -AsPlainText -Force
    }
    
    foreach ($user in $config.Users) {
        try {
            $username = [ADValidator]::GenerateUsername($user.FirstName, $user.LastName, $config.Naming.UserNameFormat)
            
            New-ADUser `
                -Name "$($user.FirstName) $($user.LastName)" `
                -GivenName $user.FirstName `
                -Surname $user.LastName `
                -SamAccountName $username `
                -UserPrincipalName "$username@$($config.Domain.Name)" `
                -EmailAddress $user.Email `
                -Department $user.Department `
                -Path $usersOU `
                -AccountPassword $userPassword `
                -Enabled $true `
                -ChangePasswordAtLogon $true `
                -PasswordNeverExpires $false `
                -ErrorAction Stop
            
            $logger.Success("Usuário criado: $username ($($user.FirstName) $($user.LastName))")
            Write-Host "Usuário criado: $username" -ForegroundColor Green
            
            # Adicionar ao grupo padrão
            Add-ADGroupMember -Identity "GRP-Usuarios-Padrao" -Members $username -ErrorAction SilentlyContinue
            
        } catch {
            if ($_ -match "already exists") {
                $logger.Info("Usuário já existe: $username")
                Write-Host "Usuário já existe: $username" -ForegroundColor Gray
            } else {
                throw $_
            }
        }
    }
    
    $logger.Success("Usuários criados com sucesso")
    
} catch {
    $logger.Error("Erro na Fase 7: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
}

# =====================================================
# FASE 8: CONFIGURAR POLÍTICAS DE GRUPO
# =====================================================

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
Write-Host "FASE 8: CONFIGURAÇÃO DE POLÍTICAS" -ForegroundColor Yellow
Write-Host ("=" * 64) -ForegroundColor Cyan

$logger.Info("Iniciando Fase 8: Configuração de políticas")

try {
    $domainDN = "DC=$($config.Domain.Name -replace '\.', ',DC=')"
    
    Write-Host "`nConfigurando política de senhas..." -ForegroundColor Yellow
    $logger.Info("Configurando política de senhas do domínio")
    
    Set-ADDefaultDomainPasswordPolicy `
        -Identity $config.Domain.Name `
        -MinPasswordLength $config.PasswordPolicy.MinLength `
        -MaxPasswordAge (New-TimeSpan -Days $config.PasswordPolicy.MaxAge) `
        -MinPasswordAge (New-TimeSpan -Days $config.PasswordPolicy.MinAge) `
        -PasswordHistoryCount $config.PasswordPolicy.HistoryCount `
        -ComplexityEnabled $config.PasswordPolicy.ComplexityEnabled `
        -ReversibleEncryptionEnabled $false `
        -LockoutThreshold $config.LockoutPolicy.Threshold `
        -LockoutDuration (New-TimeSpan -Minutes $config.LockoutPolicy.Duration) `
        -LockoutObservationWindow (New-TimeSpan -Minutes $config.LockoutPolicy.Window) `
        -ErrorAction Stop
    
    $logger.Success("Política de senhas configurada")
    Write-Host "Política de senhas configurada" -ForegroundColor Green
    
    # Criar GPOs
    Write-Host "`nCriando Políticas de Grupo..." -ForegroundColor Yellow
    $logger.Info("Criando GPOs")
    
    $gpoNames = @(
        "Politica-Auditoria"
        "Config-Workstations"
        "Restricoes-Usuario"
    )
    
    foreach ($gpoName in $gpoNames) {
        try {
            $gpo = New-GPO -Name "$($config.OrganizationalUnits.Pattern)-$gpoName" -ErrorAction Stop
            $logger.Success("GPO criada: $($gpo.DisplayName)")
            Write-Host "GPO criada: $($gpo.DisplayName)" -ForegroundColor Green
        } catch {
            if ($_ -match "already exists") {
                $logger.Info("GPO já existe: $gpoName")
            } else {
                throw $_
            }
        }
    }
    
    $logger.Success("Políticas de grupo configuradas com sucesso")
    
} catch {
    $logger.Error("Erro na Fase 8: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
}

# =====================================================
# FASE 9: INSTALAR DHCP (SE HABILITADO)
# =====================================================

if ($config.Services.InstallDHCP) {
    Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
    Write-Host "FASE 9: INSTALAÇÃO DE DHCP" -ForegroundColor Yellow
    Write-Host ("=" * 64) -ForegroundColor Cyan
    
    $logger.Info("Iniciando Fase 9: Instalação de DHCP")
    
    try {
        Write-Host "`nInstalando DHCP..." -ForegroundColor Yellow
        $logger.Info("Instalando serviço DHCP")
        
        Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction Stop
        $logger.Success("DHCP instalado")
        Write-Host "DHCP instalado com sucesso" -ForegroundColor Green
        
        Write-Host "`nAutorizando DHCP no AD..." -ForegroundColor Yellow
        Add-DhcpServerInDC -DnsName "$($config.Server.Name).$($config.Domain.Name)" `
                          -IPAddress $config.Network.ServerIP `
                          -ErrorAction Stop
        
        $logger.Success("DHCP autorizado no AD")
        Write-Host "DHCP autorizado" -ForegroundColor Green
        
    } catch {
        $logger.Error("Erro na Fase 9: $_")
        Write-Host "Erro: $_" -ForegroundColor Red
    }
}

# =====================================================
# FASE 10: VALIDAÇÃO FINAL
# =====================================================

Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
Write-Host "FASE 10: VALIDAÇÃO FINAL" -ForegroundColor Yellow
Write-Host ("=" * 64) -ForegroundColor Cyan

$logger.Info("Iniciando Fase 10: Validação final")

try {
    Write-Host "`nValidando instalação..." -ForegroundColor Yellow
    
    $domainDN = "DC=$($config.Domain.Name -replace '\.', ',DC=')"
    
    # Contar objetos criados
    $userCount = (Get-ADUser -Filter * -SearchBase "OU=$($config.OrganizationalUnits.Users),$domainDN" -ErrorAction SilentlyContinue | Measure-Object).Count
    $ouCount = (Get-ADOrganizationalUnit -Filter * -SearchBase $domainDN -ErrorAction SilentlyContinue | Measure-Object).Count
    $groupCount = (Get-ADGroup -Filter * -SearchBase "OU=$($config.OrganizationalUnits.Groups),$domainDN" -ErrorAction SilentlyContinue | Measure-Object).Count
    
    Write-Host "`nResumo da Implementação:" -ForegroundColor Yellow
    Write-Host "Domínio: $($config.Domain.Name)" -ForegroundColor Gray
    Write-Host "NetBIOS: $($config.Domain.NetBIOS)" -ForegroundColor Gray
    Write-Host "Servidor: $($config.Server.Name)" -ForegroundColor Gray
    Write-Host "Usuários criados: $userCount" -ForegroundColor Gray
    Write-Host "OUs criadas: $ouCount" -ForegroundColor Gray
    Write-Host "Grupos criados: $groupCount" -ForegroundColor Gray
    
    $logger.Success("Validação concluída")
    $logger.Info("Usuários: $userCount | OUs: $ouCount | Grupos: $groupCount")
    
} catch {
    $logger.Error("Erro na Fase 10: $_")
    Write-Host "Erro: $_" -ForegroundColor Red
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
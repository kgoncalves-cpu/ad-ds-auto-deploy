<#
.SYNOPSIS
    Funções de Políticas e Configuração do Active Directory
.DESCRIPTION
    Funções para políticas de senha, GPOs, DHCP e validação
    Responsabilidades: Segurança e configuração de serviços
.NOTES
    Requer: Active Directory Module, Group Policy Module, PowerShell 5.0+
#>

# =====================================================
# FUNÇÃO: Configurar Políticas de AD
# =====================================================

function Set-ADPasswordPolicies {
    <#
    .SYNOPSIS
        Configura políticas de senha e cria GPOs
    .PARAMETER Config
        Hashtable com configuração completa
    .PARAMETER DomainDN
        Distinguished Name do domínio
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        Set-ADPasswordPolicies -Config $config -DomainDN $domainDN -Logger $logger
    .OUTPUTS
        [hashtable] com resultado { Success, PoliciesConfigured, GPOsCreated, Message }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainDN,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
        Write-Host "FASE 8: CONFIGURAÇÃO DE POLÍTICAS" -ForegroundColor Yellow
        Write-Host ("=" * 64) -ForegroundColor Cyan
        
        Write-Host "`nConfigurando política de senhas..." -ForegroundColor Yellow
        $Logger.Info("Configurando política de senhas do domínio")
        
        Set-ADDefaultDomainPasswordPolicy `
            -Identity $Config.Domain.Name `
            -MinPasswordLength $Config.PasswordPolicy.MinLength `
            -MaxPasswordAge (New-TimeSpan -Days $Config.PasswordPolicy.MaxAge) `
            -MinPasswordAge (New-TimeSpan -Days $Config.PasswordPolicy.MinAge) `
            -PasswordHistoryCount $Config.PasswordPolicy.HistoryCount `
            -ComplexityEnabled $Config.PasswordPolicy.ComplexityEnabled `
            -ReversibleEncryptionEnabled $false `
            -LockoutThreshold $Config.LockoutPolicy.Threshold `
            -LockoutDuration (New-TimeSpan -Minutes $Config.LockoutPolicy.Duration) `
            -LockoutObservationWindow (New-TimeSpan -Minutes $Config.LockoutPolicy.Window) `
            -ErrorAction Stop
        
        $Logger.Success("Política de senhas configurada")
        Write-Host "✅ Política de senhas configurada" -ForegroundColor Green
        
        Write-Host "`nCriando Políticas de Grupo..." -ForegroundColor Yellow
        $Logger.Info("Criando GPOs")
        
        $gpoNames = @(
            "Politica-Auditoria"
            "Config-Workstations"
            "Restricoes-Usuario"
        )
        
        $gpoCount = 0
        
        foreach ($gpoName in $gpoNames) {
            try {
                $gpo = New-GPO -Name "$($Config.OrganizationalUnits.Pattern)-$gpoName" -ErrorAction Stop
                $Logger.Success("GPO criada: $($gpo.DisplayName)")
                Write-Host "✅ GPO criada: $($gpo.DisplayName)" -ForegroundColor Green
                $gpoCount++
                
            } catch {
                if ($_ -match "already exists") {
                    $Logger.Info("GPO já existe: $gpoName")
                    Write-Host "⏭️  GPO já existe: $gpoName" -ForegroundColor Gray
                } else {
                    throw $_
                }
            }
        }
        
        $Logger.Success("Políticas de grupo configuradas/validadas")
        
        return @{
            Success             = $true
            PoliciesConfigured  = $true
            GPOsCreated         = $gpoCount
            Message             = "Políticas configuradas com sucesso (GPOs: $gpoCount)"
        }
        
    } catch {
        $Logger.Error("Erro na configuração de políticas: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
        throw
    }
}

# =====================================================
# FUNÇÃO: Instalar DHCP
# =====================================================

function Install-ADDHCPService {
    <#
    .SYNOPSIS
        Instala e configura serviço DHCP
    .PARAMETER Config
        Hashtable com configuração completa
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        Install-ADDHCPService -Config $config -Logger $logger
    .OUTPUTS
        [hashtable] com resultado { Success, Installed, Message }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        if (-not $Config.Services.InstallDHCP) {
            $Logger.Info("DHCP não está habilitado na configuração - pulando")
            Write-Host "`n[INFO] DHCP não está habilitado na configuração" -ForegroundColor Gray
            
            return @{
                Success   = $true
                Installed = $false
                Message   = "DHCP não estava habilitado - pulado"
            }
        }
        
        Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
        Write-Host "FASE 9: INSTALAÇÃO DE DHCP" -ForegroundColor Yellow
        Write-Host ("=" * 64) -ForegroundColor Cyan
        
        Write-Host "`nInstalando DHCP..." -ForegroundColor Yellow
        $Logger.Info("Instalando serviço DHCP")
        
        Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction Stop
        $Logger.Success("DHCP instalado")
        Write-Host "✅ DHCP instalado com sucesso" -ForegroundColor Green
        
        Write-Host "`nAutorizando DHCP no AD..." -ForegroundColor Yellow
        Add-DhcpServerInDC -DnsName "$($Config.Server.Name).$($Config.Domain.Name)" `
                          -IPAddress $Config.Network.ServerIP `
                          -ErrorAction Stop
        
        $Logger.Success("DHCP autorizado no AD")
        Write-Host "✅ DHCP autorizado" -ForegroundColor Green
        
        return @{
            Success   = $true
            Installed = $true
            Message   = "DHCP instalado e autorizado com sucesso"
        }
        
    } catch {
        $Logger.Error("Erro na instalação de DHCP: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
        throw
    }
}

# =====================================================
# FUNÇÃO: Validação Final
# =====================================================

function Test-ADPostConfigValidation {
    <#
    .SYNOPSIS
        Valida configuração pós-instalação
    .PARAMETER Config
        Hashtable com configuração completa
    .PARAMETER DomainDN
        Distinguished Name do domínio
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        Test-ADPostConfigValidation -Config $config -DomainDN $domainDN -Logger $logger
    .OUTPUTS
        [hashtable] com resultado { Success, UserCount, OUCount, GroupCount }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainDN,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
        Write-Host "FASE 10: VALIDAÇÃO FINAL" -ForegroundColor Yellow
        Write-Host ("=" * 64) -ForegroundColor Cyan
        
        Write-Host "`nValidando instalação..." -ForegroundColor Yellow
        
        $userCount = (Get-ADUser -Filter * `
            -SearchBase "OU=$($Config.OrganizationalUnits.Users),$DomainDN" `
            -ErrorAction SilentlyContinue | Measure-Object).Count
        
        $ouCount = (Get-ADOrganizationalUnit -Filter * `
            -SearchBase $DomainDN `
            -ErrorAction SilentlyContinue | Measure-Object).Count
        
        $groupCount = (Get-ADGroup -Filter * `
            -SearchBase "OU=$($Config.OrganizationalUnits.Groups),$DomainDN" `
            -ErrorAction SilentlyContinue | Measure-Object).Count
        
        Write-Host "`nResumo da Implementação:" -ForegroundColor Yellow
        Write-Host "Domínio: $($Config.Domain.Name)" -ForegroundColor Gray
        Write-Host "NetBIOS: $($Config.Domain.NetBIOS)" -ForegroundColor Gray
        Write-Host "Servidor: $($Config.Server.Name)" -ForegroundColor Gray
        Write-Host "Usuários criados: $userCount" -ForegroundColor Gray
        Write-Host "OUs criadas: $ouCount" -ForegroundColor Gray
        Write-Host "Grupos criados: $groupCount" -ForegroundColor Gray
        
        $Logger.Success("Validação concluída")
        $Logger.Info("Usuários: $userCount | OUs: $ouCount | Grupos: $groupCount")
        
        return @{
            Success    = $true
            UserCount  = $userCount
            OUCount    = $ouCount
            GroupCount = $groupCount
            Message    = "Validação concluída com sucesso"
        }
        
    } catch {
        $Logger.Error("Erro na validação final: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
        throw
    }
}

# =====================================================
# FUNÇÃO: Executar Todas as Fases
# =====================================================

function Invoke-ADPostConfiguration {
    <#
    .SYNOPSIS
        Executa todas as fases de pós-configuração
    .PARAMETER Config
        Hashtable com configuração completa
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        Invoke-ADPostConfiguration -Config $config -Logger $logger
    .OUTPUTS
        [hashtable] com resultado consolidado
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
        Write-Host "INICIANDO CONFIGURAÇÃO PÓS-INSTALAÇÃO" -ForegroundColor Yellow
        Write-Host ("=" * 64) -ForegroundColor Cyan
        
        $Logger.Info("Iniciando configuração pós-instalação")
        
        $domainDN = "DC=$($Config.Domain.Name -replace '\.', ',DC=')"
        $Logger.Info("DN do domínio: $domainDN")
        
        # FASE 4: DNS
        Invoke-ADDNSConfiguration -DNSForwarders $Config.Advanced.DNSForwarders -Logger $Logger
        
        # FASE 5: OUs
        New-ADOrganizationalUnitStructure -Config $Config -DomainDN $domainDN -Logger $Logger
        
        # FASE 6: Grupos
        New-ADSecurityGroups -Groups $Config.Groups -OrganizationalUnits $Config.OrganizationalUnits `
            -DomainDN $domainDN -Logger $Logger
        
        # FASE 7: Usuários
        New-ADUsers -Users $Config.Users -Config $Config -DomainDN $domainDN -Logger $Logger
        
        # FASE 8: Políticas
        Set-ADPasswordPolicies -Config $Config -DomainDN $domainDN -Logger $Logger
        
        # FASE 9: DHCP
        Install-ADDHCPService -Config $Config -Logger $Logger
        
        # FASE 10: Validação
        $validation = Test-ADPostConfigValidation -Config $Config -DomainDN $domainDN -Logger $Logger
        
        $Logger.Success("Todas as fases de pós-configuração concluídas com sucesso")
        
        return @{
            Success = $true
            Message = "Configuração pós-instalação concluída com sucesso"
            Validation = $validation
        }
        
    } catch {
        $Logger.Error("Erro na configuração pós-instalação: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
        throw
    }
}
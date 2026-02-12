<#
.SYNOPSIS
    Módulo de configuração pós-instalação do Active Directory
.DESCRIPTION
    Responsável por OUs, grupos, usuários, políticas, DNS e DHCP
.NOTES
    Parte do ADDeployment Framework
    Versão: 1.0
    Requer: Windows Server 2022 com AD DS instalado
#>
# =====================================================
# IMPORTAR DEPENDÊNCIAS
# =====================================================

Import-Module -Name "$PSScriptRoot\ADDeployment.Validate.psm1" -ErrorAction Stop

# =====================================================
# FUNÇÃO: Configurar DNS
# =====================================================

function Invoke-ADDNSConfiguration {
    <#
    .SYNOPSIS
        Configura encaminhadores DNS
    .DESCRIPTION
        Define DNS forwarders para resolução externa
    .PARAMETER DNSForwarders
        Array com IPs de DNS forwarders
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        Invoke-ADDNSConfiguration -DNSForwarders @("8.8.8.8", "1.1.1.1") -Logger $logger
    .OUTPUTS
        [hashtable] com resultado { Success, Message }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string[]]$DNSForwarders,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`nConfigurando encaminhadores DNS..." -ForegroundColor Yellow
        $Logger.Info("Configurando encaminhadores DNS")
        
        Set-DnsServerForwarder -IPAddress $DNSForwarders -ErrorAction Stop
        $Logger.Success("Encaminhadores DNS configurados: $($DNSForwarders -join ', ')")
        Write-Host "✅ Encaminhadores DNS configurados" -ForegroundColor Green
        
        return @{
            Success = $true
            Message = "DNS forwarders configurados com sucesso"
        }
        
    } catch {
        $Logger.Error("Erro ao configurar DNS: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
        throw
    }
}

# =====================================================
# FUNÇÃO: Criar Estrutura de OUs
# =====================================================

function New-ADOrganizationalUnitStructure {
    <#
    .SYNOPSIS
        Cria estrutura de Organizational Units
    .DESCRIPTION
        Cria OUs conforme especificado na configuração
    .PARAMETER Config
        Hashtable com configuração carregada
    .PARAMETER DomainDN
        Distinguished Name do domínio
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        New-ADOrganizationalUnitStructure -Config $config -DomainDN $domainDN -Logger $logger
    .OUTPUTS
        [hashtable] com resultado { Success, CreatedCount, SkippedCount, Message }
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
        Write-Host "FASE 5: CRIAÇÃO DA ESTRUTURA DE OUs" -ForegroundColor Yellow
        Write-Host ("=" * 64) -ForegroundColor Cyan
        
        Write-Host "`nCriando OUs..." -ForegroundColor Yellow
        $Logger.Info("Criando estrutura de OUs no domínio $DomainDN")
        
        $createdCount = 0
        $skippedCount = 0
        
        # Construir array de OUs conforme config
        $ous = @(
            @{ Name = $Config.OrganizationalUnits.Computers; Path = $DomainDN }
            @{ Name = "Desktops"; Path = "OU=$($Config.OrganizationalUnits.Computers),$DomainDN" }
            @{ Name = "Laptops"; Path = "OU=$($Config.OrganizationalUnits.Computers),$DomainDN" }
            @{ Name = $Config.OrganizationalUnits.Users; Path = $DomainDN }
            @{ Name = "Administrativos"; Path = "OU=$($Config.OrganizationalUnits.Users),$DomainDN" }
            @{ Name = "Operacionais"; Path = "OU=$($Config.OrganizationalUnits.Users),$DomainDN" }
            @{ Name = $Config.OrganizationalUnits.Groups; Path = $DomainDN }
            @{ Name = $Config.OrganizationalUnits.Servers; Path = $DomainDN }
        )
        
        foreach ($ou in $ous) {
            try {
                New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path `
                    -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
                
                $Logger.Success("OU criada: $($ou.Name)")
                Write-Host "✅ OU criada: $($ou.Name)" -ForegroundColor Green
                $createdCount++
                
            } catch {
                if ($_ -match "already exists") {
                    $Logger.Info("OU já existe: $($ou.Name)")
                    Write-Host "⏭️  OU já existe: $($ou.Name)" -ForegroundColor Gray
                    $skippedCount++
                } else {
                    throw $_
                }
            }
        }
        
        $Logger.Success("Estrutura de OUs criada/validada")
        
        return @{
            Success      = $true
            CreatedCount = $createdCount
            SkippedCount = $skippedCount
            Message      = "OUs processadas com sucesso (criadas: $createdCount, existentes: $skippedCount)"
        }
        
    } catch {
        $Logger.Error("Erro na criação de OUs: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
        throw
    }
}

# =====================================================
# FUNÇÃO: Criar Grupos de Segurança
# =====================================================

function New-ADSecurityGroups {
    <#
    .SYNOPSIS
        Cria grupos de segurança do AD
    .DESCRIPTION
        Cria grupos conforme especificado na configuração
    .PARAMETER Groups
        Array com definição de grupos
    .PARAMETER OrganizationalUnits
        Hashtable com nomes de OUs
    .PARAMETER DomainDN
        Distinguished Name do domínio
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        New-ADSecurityGroups -Groups $config.Groups -OrganizationalUnits $config.OrganizationalUnits -DomainDN $domainDN -Logger $logger
    .OUTPUTS
        [hashtable] com resultado { Success, CreatedCount, SkippedCount, Message }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [array]$Groups,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$OrganizationalUnits,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainDN,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
        Write-Host "FASE 6: CRIAÇÃO DE GRUPOS" -ForegroundColor Yellow
        Write-Host ("=" * 64) -ForegroundColor Cyan
        
        Write-Host "`nCriando grupos de segurança..." -ForegroundColor Yellow
        $groupsOU = "OU=$($OrganizationalUnits.Groups),$DomainDN"
        $Logger.Info("Criando grupos no OU: $groupsOU")
        
        $createdCount = 0
        $skippedCount = 0
        
        foreach ($group in $Groups) {
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
                
                $Logger.Success("Grupo criado: $($group.Name)")
                Write-Host "✅ Grupo criado: $($group.Name)" -ForegroundColor Green
                $createdCount++
                
            } catch {
                if ($_ -match "already exists") {
                    $Logger.Info("Grupo já existe: $($group.Name)")
                    Write-Host "⏭️  Grupo já existe: $($group.Name)" -ForegroundColor Gray
                    $skippedCount++
                } else {
                    throw $_
                }
            }
        }
        
        $Logger.Success("Grupos de segurança criados/validados")
        
        return @{
            Success      = $true
            CreatedCount = $createdCount
            SkippedCount = $skippedCount
            Message      = "Grupos processados com sucesso (criados: $createdCount, existentes: $skippedCount)"
        }
        
    } catch {
        $Logger.Error("Erro na criação de grupos: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
        throw
    }
}

# =====================================================
# FUNÇÃO: Obter Senha de Usuário
# =====================================================

function Get-ADUserPassword {
    <#
    .SYNOPSIS
        Obtém senha de usuário de forma segura
    .DESCRIPTION
        Carrega de config ou solicita interativamente
    .PARAMETER ConfigPassword
        Senha da configuração (se fornecida)
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        $password = Get-ADUserPassword -ConfigPassword $config.Passwords.DefaultUser -Logger $logger
    .OUTPUTS
        [SecureString] com a senha do usuário
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$ConfigPassword,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        # Se senha está na configuração
        if (-not [string]::IsNullOrWhiteSpace($ConfigPassword)) {
            $Logger.Success("Senha de usuário carregada da configuração")
            Write-Host "✅ Senha de usuário carregada da configuração" -ForegroundColor Green
            return (ConvertTo-SecureString $ConfigPassword -AsPlainText -Force)
        }
        
        # Se modo interativo, pedir ao usuário
        Write-Host "`nDigite a senha padrão para os usuários" -ForegroundColor Yellow
        
        do {
            $userPassword = Read-Host "Senha (mínimo 8 caracteres)" -AsSecureString
            $userPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($userPassword)
            )
            
            if ($userPasswordPlain.Length -lt 8) {
                Write-Host "❌ A senha deve ter no mínimo 8 caracteres" -ForegroundColor Red
            } else {
                Write-Host "✅ Senha confirmada" -ForegroundColor Green
                $Logger.Success("Senha de usuário obtida e validada")
                return $userPassword
            }
            
        } while ($true)
        
    } catch {
        $Logger.Error("Erro ao obter senha de usuário: $_")
        throw
    }
}

# =====================================================
# FUNÇÃO: Criar Usuários do AD
# =====================================================

function New-ADUsers {
    <#
    .SYNOPSIS
        Cria usuários do Active Directory
    .DESCRIPTION
        Cria usuários conforme especificado na configuração
    .PARAMETER Users
        Array com definição de usuários
    .PARAMETER Config
        Hashtable com configuração completa
    .PARAMETER DomainDN
        Distinguished Name do domínio
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        New-ADUsers -Users $config.Users -Config $config -DomainDN $domainDN -Logger $logger
    .OUTPUTS
        [hashtable] com resultado { Success, CreatedCount, SkippedCount, Message }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [array]$Users,
        
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
        Write-Host "FASE 7: CRIAÇÃO DE USUÁRIOS" -ForegroundColor Yellow
        Write-Host ("=" * 64) -ForegroundColor Cyan
        
        Write-Host "`nCriando usuários..." -ForegroundColor Yellow
        $usersOU = "OU=Operacionais,OU=$($Config.OrganizationalUnits.Users),$DomainDN"
        $Logger.Info("Criando usuários no OU: $usersOU")
        
        # Obter senha
        $userPassword = Get-ADUserPassword -ConfigPassword $Config.Passwords.DefaultUser -Logger $Logger
        
        $createdCount = 0
        $skippedCount = 0
        
        foreach ($user in $Users) {
            try {
                # Gerar username usando ADValidator
                $username = [ADValidator]::GenerateUsername(
                    $user.FirstName, 
                    $user.LastName, 
                    $Config.Naming.UserNameFormat
                )
                
                New-ADUser `
                    -Name "$($user.FirstName) $($user.LastName)" `
                    -GivenName $user.FirstName `
                    -Surname $user.LastName `
                    -SamAccountName $username `
                    -UserPrincipalName "$username@$($Config.Domain.Name)" `
                    -EmailAddress $user.Email `
                    -Department $user.Department `
                    -Path $usersOU `
                    -AccountPassword $userPassword `
                    -Enabled $true `
                    -ChangePasswordAtLogon $true `
                    -PasswordNeverExpires $false `
                    -ErrorAction Stop
                
                $Logger.Success("Usuário criado: $username ($($user.FirstName) $($user.LastName))")
                Write-Host "✅ Usuário criado: $username" -ForegroundColor Green
                
                # Adicionar ao grupo padrão
                try {
                    Add-ADGroupMember -Identity "GRP-Usuarios-Padrao" -Members $username -ErrorAction SilentlyContinue
                    $Logger.Info("Usuário adicionado ao grupo padrão")
                } catch {
                    $Logger.Warning("Não foi possível adicionar usuário ao grupo padrão: $_")
                }
                
                $createdCount++
                
            } catch {
                if ($_ -match "already exists") {
                    $Logger.Info("Usuário já existe: $username")
                    Write-Host "⏭️  Usuário já existe: $username" -ForegroundColor Gray
                    $skippedCount++
                } else {
                    throw $_
                }
            }
        }
        
        $Logger.Success("Usuários criados/validados")
        
        return @{
            Success      = $true
            CreatedCount = $createdCount
            SkippedCount = $skippedCount
            Message      = "Usuários processados com sucesso (criados: $createdCount, existentes: $skippedCount)"
        }
        
    } catch {
        $Logger.Error("Erro na criação de usuários: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
        throw
    }
}

# =====================================================
# FUNÇÃO: Configurar Políticas de AD
# =====================================================

function Set-ADPasswordPolicies {
    <#
    .SYNOPSIS
        Configura políticas de senha e cria GPOs
    .DESCRIPTION
        Define políticas de senha e cria Group Policies
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
        
        # Criar GPOs
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
    .DESCRIPTION
        Instala DHCP e autoriza no AD se configurado
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
        # Verificar se DHCP está habilitado
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
    .DESCRIPTION
        Conta e exibe objetos criados no AD
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
        
        # Contar objetos criados
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
    .DESCRIPTION
        Orquestra execução de todas as fases 4-10
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
        
        # Construir DN do domínio
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

# =====================================================
# EXPORTAR FUNÇÕES PÚBLICAS
# =====================================================

Export-ModuleMember -Function @(
    'Invoke-ADDNSConfiguration',
    'New-ADOrganizationalUnitStructure',
    'New-ADSecurityGroups',
    'Get-ADUserPassword',
    'New-ADUsers',
    'Set-ADPasswordPolicies',
    'Install-ADDHCPService',
    'Test-ADPostConfigValidation',
    'Invoke-ADPostConfiguration'
)
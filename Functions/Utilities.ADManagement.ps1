
<#
.SYNOPSIS
    Funções de Gerenciamento do Active Directory
.DESCRIPTION
    Funções para DNS, OUs, Grupos e Usuários
    Responsabilidades: Configuração de estrutura AD
.NOTES
    Requer: Active Directory Module, PowerShell 5.0+
    Dependências: ADValidator (via ADDeployment.Validate.psm1)
#>

# =====================================================
# FUNÇÃO: Configurar DNS
# =====================================================

function Invoke-ADDNSConfiguration {
    <#
    .SYNOPSIS
        Configura encaminhadores DNS
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
        if (-not [string]::IsNullOrWhiteSpace($ConfigPassword)) {
            $Logger.Success("Senha de usuário carregada da configuração")
            Write-Host "✅ Senha de usuário carregada da configuração" -ForegroundColor Green
            return (ConvertTo-SecureString $ConfigPassword -AsPlainText -Force)
        }
        
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
        
        $userPassword = Get-ADUserPassword -ConfigPassword $Config.Passwords.DefaultUser -Logger $Logger
        
        $createdCount = 0
        $skippedCount = 0
        
        foreach ($user in $Users) {
            try {
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


#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
Import-Module GroupPolicy

function Write-Log {
    param([string]$Message,[ValidateSet('Info','Success','Warning','Error')]$Level='Info')
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $msg = "[$ts] [$Level] $Message"
    switch ($Level) {
        'Info'    { Write-Host $msg -ForegroundColor Cyan }
        'Success' { Write-Host $msg -ForegroundColor Green }
        'Warning' { Write-Host $msg -ForegroundColor Yellow }
        'Error'   { Write-Host $msg -ForegroundColor Red }
    }
}

Write-Log 'Iniciando Parte 2 - Pós-instalação' -Level Info
$config = Import-Clixml -Path 'C:\gestao\ADConfig_Config.xml'
$domainDN = "DC=" + ($config.DomainName -replace '\.',',DC=')
$ouPrefix = $config.DomainNetBIOS

# FASE 5: DNS (forwarders e zonas reversas)
Write-Log 'Configurando encaminhadores DNS...' -Level Info
try {
    Set-DnsServerForwarder -IPAddress $config.DNSForwarders -ErrorAction Stop
    Write-Log 'Encaminhadores configurados' -Level Success
} catch { Write-Log "Falha ao configurar encaminhadores: $_" -Level Warning }

Write-Log 'Criando zonas reversas...' -Level Info
foreach ($seg in $config.NetworkSegments) {
    try {
        # Usa NetworkID com base e CIDR: ex 10.2.60.0/24
        Add-DnsServerPrimaryZone -NetworkID ("$($seg.Network)/$($seg.CIDR)") -ReplicationScope Forest -ErrorAction Stop
        Write-Log "Zona reversa criada: $($seg.Network)/$($seg.CIDR)" -Level Success
    } catch { Write-Log "Zona reversa já existe ou erro: $_" -Level Warning }
}

# FASE 6: OUs
Write-Log 'Criando OUs...' -Level Info
$ous = @(
    @{Name="$ouPrefix-Computadores";    Path=$domainDN},
    @{Name="$ouPrefix-Desktops";        Path="OU=$ouPrefix-Computadores,$domainDN"},
    @{Name="$ouPrefix-Laptops";         Path="OU=$ouPrefix-Computadores,$domainDN"},
    @{Name="$ouPrefix-Usuarios";        Path=$domainDN},
    @{Name="$ouPrefix-Administrativos"; Path="OU=$ouPrefix-Usuarios,$domainDN"},
    @{Name="$ouPrefix-Operacionais";    Path="OU=$ouPrefix-Usuarios,$domainDN"},
    @{Name="$ouPrefix-Grupos";          Path=$domainDN},
    @{Name="$ouPrefix-Servidores";      Path=$domainDN}
)
foreach ($ou in $ous) {
    try {
        New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
        Write-Log "OU criada: $($ou.Name)" -Level Success
    } catch { Write-Log "OU existente ou erro: $_" -Level Warning }
}

# FASE 7: Usuários
Write-Log 'Criando usuários...' -Level Info
$usersOU = "OU=$ouPrefix-Operacionais,OU=$ouPrefix-Usuarios,$domainDN"
foreach ($user in $config.Users) {
    try {
        New-ADUser -Name $user.FullName -SamAccountName $user.Username -UserPrincipalName "$($user.Username)@$($config.DomainName)" 
            -Path $usersOU -AccountPassword $config.UserPassword -Enabled $true -ChangePasswordAtLogon $true -ErrorAction Stop
        Write-Log "Usuário criado: $($user.Username)" -Level Success
    } catch { Write-Log "Erro ao criar usuário $($user.Username): $_" -Level Error }
}

# FASE 8: Grupos
Write-Log 'Criando grupos...' -Level Info
$groupsOU = "OU=$ouPrefix-Grupos,$domainDN"
$groups = @(
    @{Name='GRP-Usuarios-Padrao'; Description='Grupo padrão de usuários'},
    @{Name='GRP-Administradores-TI'; Description='Administradores de TI'},
    @{Name='GRP-Gerencia'; Description='Gerência'}
)
foreach ($g in $groups) {
    try {
        New-ADGroup -Name $g.Name -GroupScope Global -GroupCategory Security -Path $groupsOU -Description $g.Description -ErrorAction Stop
        Write-Log "Grupo criado: $($g.Name)" -Level Success
    } catch { Write-Log "Grupo existente ou erro: $_" -Level Warning }
}
# Adicionar usuários ao grupo padrão com objetos AD
foreach ($user in $config.Users) {
    try {
        $u = Get-ADUser -Identity $user.Username -ErrorAction Stop
        Add-ADGroupMember -Identity 'GRP-Usuarios-Padrao' -Members $u -ErrorAction Stop
    } catch { Write-Log "Falha ao adicionar $($user.Username) ao GRP-Usuarios-Padrao: $_" -Level Warning }
}

# FASE 9: Políticas de domínio
Write-Log 'Aplicando política de senha e bloqueio no domínio...' -Level Info
try {
    Set-ADDefaultDomainPasswordPolicy -Identity $config.DomainName 
        -MinPasswordLength $config.PasswordPolicy.MinLength 
        -MaxPasswordAge (New-TimeSpan -Days $config.PasswordPolicy.MaxAge) 
        -MinPasswordAge (New-TimeSpan -Days $config.PasswordPolicy.MinAge) 
        -PasswordHistoryCount $config.PasswordPolicy.HistoryCount 
        -ComplexityEnabled $true -ReversibleEncryptionEnabled $false 
        -LockoutThreshold $config.LockoutPolicy.Threshold 
        -LockoutDuration (New-TimeSpan -Minutes $config.LockoutPolicy.Duration) 
        -LockoutObservationWindow (New-TimeSpan -Minutes $config.LockoutPolicy.Window) -ErrorAction Stop
    Write-Log 'Políticas de senha/bloqueio aplicadas' -Level Success
} catch { Write-Log "Erro ao aplicar políticas: $_" -Level Error }

# GPOs de estrutura (links)
try {
    $gpoAudit = New-GPO -Name "$ouPrefix-Politica-Auditoria" -ErrorAction Stop
    $gpoAudit | New-GPLink -Target $domainDN -ErrorAction Stop
} catch { Write-Log "GPO Auditoria já existe ou erro: $_" -Level Warning }
try {
    $gpoWS = New-GPO -Name "$ouPrefix-Config-Workstations" -ErrorAction Stop
    $gpoWS | New-GPLink -Target "OU=$ouPrefix-Computadores,$domainDN" -ErrorAction Stop
} catch { Write-Log "GPO Workstations já existe ou erro: $_" -Level Warning }
try {
    $gpoUsers = New-GPO -Name "$ouPrefix-Restricoes-Usuario" -ErrorAction Stop
    $gpoUsers | New-GPLink -Target "OU=$ouPrefix-Usuarios,$domainDN" -ErrorAction Stop
} catch { Write-Log "GPO Usuários já existe ou erro: $_" -Level Warning }

# FASE 10: DHCP (opcional)
if ($config.InstallDHCP) {
    Write-Log 'Instalando DHCP...' -Level Info
    try {
        # Preferir ServerManager
        if ((Get-WindowsFeature DHCP).Installed -eq $false) {
            Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null
        }
    } catch {
        # Fallback DISM
        Write-Log 'Falha ServerManager, tentando DISM para DHCP' -Level Warning
        $p = Start-Process -FilePath dism.exe -ArgumentList '/Online','/Enable-Feature','/FeatureName:DHCPServer','/All','/NoRestart' -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -ne 0) { Write-Log "Falha DISM DHCP: ExitCode $($p.ExitCode)" -Level Error }
    }
    try {
        Add-DhcpServerInDC -DnsName "$($config.ServerName).$($config.DomainName)" -IPAddress $config.ServerIP -ErrorAction Stop
        Write-Log 'Servidor DHCP autorizado no AD' -Level Success
    } catch { Write-Log "Falha ao autorizar DHCP: $_" -Level Warning }

    foreach ($seg in $config.NetworkSegments) {
        try {
            $scopeName = "Escopo-$($seg.Network)"
            Add-DhcpServerv4Scope -Name $scopeName -StartRange $seg.Network.Replace('.0','.100') -EndRange $seg.Network.Replace('.0','.200') 
                -SubnetMask $seg.Mask -State Active -LeaseDuration (New-TimeSpan -Days 8) -ErrorAction Stop
            Set-DhcpServerv4OptionValue -ScopeId $seg.Network -Router $seg.Gateway -DnsServer $config.ServerIP -DnsDomain $config.DomainName -ErrorAction Stop
            Write-Log "Escopo DHCP criado: $scopeName" -Level Success
        } catch { Write-Log "Falha escopo DHCP $($seg.Network): $_" -Level Error }
    }
}


# VALIDAÇÃO DE SERVIÇOS
Write-Log 'Validando serviços...' -Level Info
`$serviceNames = @('NTDS','DNS','Netlogon','W32Time')

foreach (`$svcName in `$serviceNames) {
    `$svc = Get-Service -Name `$svcName -ErrorAction SilentlyContinue
    if (`$svc -and `$svc.Status -eq 'Running') {
        Write-Log ("Serviço {0}: Running" -f `$svcName) -Level Success
    } else {
        Write-Log ("Serviço {0}: PROBLEMA" -f `$svcName) -Level Error
    }
}



# Documentação
Write-Log 'Gerando documentação...' -Level Info
$doc = @()
$doc += "DOMÍNIO: $($config.DomainName) (NetBIOS: $($config.DomainNetBIOS))"
$doc += "SERVIDOR: $($config.ServerName) - IP: $($config.ServerIP)"
$doc += "SEGMENTOS:"
foreach ($seg in $config.NetworkSegments) { $doc += " - $($seg.Network)/$($seg.CIDR) (Mask $($seg.Mask)) GW $($seg.Gateway)" }
$doc += "USUÁRIOS:"
foreach ($u in $config.Users) { $doc += " - $($u.Username) ($($u.FullName))" }
$docPath = "C:\AD_Implementation_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$doc -join "
" | Out-File -FilePath $docPath -Encoding UTF8
Write-Log "Documentação salva em $docPath" -Level Success

Write-Host "
Concluído. Pressione qualquer tecla para sair..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

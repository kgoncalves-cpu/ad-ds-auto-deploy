<#
.SYNOPSIS
    Módulo de preparação e setup do servidor para AD Deployment
.DESCRIPTION
    Responsável por renomear servidor, configurar rede e gerenciar reboots
.NOTES
    Parte do ADDeployment Framework
    Versão: 1.0
    Requer: Privilégios administrativos
#>

# =====================================================
# FUNÇÃO: Renomear Servidor
# =====================================================

function Rename-ADServer {
    <#
    .SYNOPSIS
        Renomeia o servidor se necessário
    .DESCRIPTION
        Compara nome atual com configurado e executa rename se diferente
    .PARAMETER ServerName
        Nome desejado do servidor
    .PARAMETER Logger
        Objeto logger para registrar operações
    .PARAMETER State
        Objeto state para marcar aplicação
    .OUTPUTS
        [hashtable] com resultados { Success, RequiresReboot, OldName, NewName }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger,
        
        [Parameter(Mandatory = $true)]
        [object]$State
    )
    
    try {
        $result = @{
            Success          = $false
            RequiresReboot   = $false
            OldName          = $env:COMPUTERNAME
            NewName          = $ServerName
            Message          = ""
        }
        
        # Validar se nome já está correto
        if ($env:COMPUTERNAME -eq $ServerName) {
            $Logger.Info("Servidor já possui o nome correto: $ServerName")
            Write-Host "✅ Servidor já possui o nome correto: $ServerName" -ForegroundColor Green
            $State.MarkRenameApplied()
            $result.Success = $true
            return $result
        }
        
        # Executar rename
        Write-Host "`nRenomeando servidor..." -ForegroundColor Yellow
        $Logger.Info("Renomeando servidor de $($env:COMPUTERNAME) para $ServerName")
        
        Rename-Computer -NewName $ServerName -Force -ErrorAction Stop
        
        $Logger.Success("Servidor renomeado com sucesso")
        Write-Host "✅ Servidor renomeado: $ServerName" -ForegroundColor Green
        
        $State.MarkRenameApplied()
        
        $result.Success = $true
        $result.RequiresReboot = $true
        $result.Message = "Rename aplicado - reboot obrigatório"
        
        return $result
        
    } catch {
        $Logger.Error("Erro ao renomear servidor: $_")
        throw
    }
}

# =====================================================
# FUNÇÃO: Configurar IP Estático
# =====================================================

function Set-ADStaticIPAddress {
    <#
    .SYNOPSIS
        Configura IP estático no adaptador de rede
    .DESCRIPTION
        Remove DHCP e aplica configuração de IP estático com DNS
    .PARAMETER ServerIP
        Endereço IP do servidor
    .PARAMETER PrefixLength
        Comprimento do prefixo CIDR (0-32)
    .PARAMETER Gateway
        Gateway padrão
    .PARAMETER DNSServers
        Array com IPs de DNS
    .PARAMETER Logger
        Objeto logger para registrar operações
    .OUTPUTS
        [bool] $true se bem-sucedido
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerIP,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 32)]
        [int]$PrefixLength,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Gateway,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string[]]$DNSServers,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`nConfigurando IP estático..." -ForegroundColor Yellow
        $Logger.Info("Configurando IP estático: $ServerIP")
        
        # Encontrar adaptador de rede ativo
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        
        if ($null -eq $adapter) {
            throw "Nenhum adaptador de rede ativo encontrado"
        }
        
        $Logger.Info("Adaptador encontrado: $($adapter.Name) (Index: $($adapter.ifIndex))")
        
        # Remover configurações antigas
        Write-Host "  Removendo configuração anterior..." -ForegroundColor Gray
        Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
        
        # Aplicar novo IP
        Write-Host "  Aplicando IP estático..." -ForegroundColor Gray
        New-NetIPAddress -InterfaceIndex $adapter.ifIndex `
                        -IPAddress $ServerIP `
                        -PrefixLength $PrefixLength `
                        -DefaultGateway $Gateway -ErrorAction Stop
        
        # Configurar DNS
        Write-Host "  Configurando DNS..." -ForegroundColor Gray
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex `
                                   -ServerAddresses $DNSServers -ErrorAction Stop
        
        $Logger.Info("Configurações de rede aplicadas:")
        $Logger.Info("  IP: $ServerIP")
        $Logger.Info("  PrefixLength: $PrefixLength")
        $Logger.Info("  Gateway: $Gateway")
        $Logger.Info("  DNS: $($DNSServers -join ', ')")
        
        return $true
        
    } catch {
        $Logger.Error("Erro ao configurar IP estático: $_")
        throw
    }
}

# =====================================================
# FUNÇÃO: Validar IP Aplicado
# =====================================================

function Test-ADIPAddressApplied {
    <#
    .SYNOPSIS
        Valida se a configuração de IP foi aplicada corretamente
    .DESCRIPTION
        Verifica IP e PrefixLength aplicados vs esperados
    .PARAMETER ExpectedIP
        IP esperado
    .PARAMETER ExpectedPrefixLength
        PrefixLength esperado
    .PARAMETER Logger
        Objeto logger para registrar operações
    .OUTPUTS
        [bool] $true se configuração está correta
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExpectedIP,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 32)]
        [int]$ExpectedPrefixLength,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`nValidando configuração de IP aplicada..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        
        # Obter adaptador ativo
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        $appliedIP = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        
        if ($appliedIP.IPAddress -ne $ExpectedIP) {
            throw "IP não foi aplicado corretamente. Esperado: $ExpectedIP, Obtido: $($appliedIP.IPAddress)"
        }
        
        $Logger.Success("IP aplicado corretamente: $($appliedIP.IPAddress)/$($appliedIP.PrefixLength)")
        Write-Host "✅ IP aplicado corretamente: $($appliedIP.IPAddress)/$($appliedIP.PrefixLength)" -ForegroundColor Green
        
        # Verificar PrefixLength
        if ($appliedIP.PrefixLength -ne $ExpectedPrefixLength) {
            $Logger.Warning("AVISO: PrefixLength foi alterado pelo Windows!")
            $Logger.Warning("  Esperado: $ExpectedPrefixLength")
            $Logger.Warning("  Aplicado: $($appliedIP.PrefixLength)")
            Write-Host "⚠️  PrefixLength alterado: esperado $ExpectedPrefixLength, aplicado $($appliedIP.PrefixLength)" -ForegroundColor Yellow
            
            # Tentar corrigir
            Write-Host "  Tentando corrigir PrefixLength..." -ForegroundColor Yellow
            Remove-NetIPAddress -IPAddress $ExpectedIP -Confirm:$false -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            
            # Re-aplicar com PrefixLength correto (será obtido via gateway)
            $segment = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
            
            if ($segment) {
                New-NetIPAddress -InterfaceIndex $adapter.ifIndex `
                                -IPAddress $ExpectedIP `
                                -PrefixLength $ExpectedPrefixLength `
                                -DefaultGateway $segment.NextHop -ErrorAction Stop
                $Logger.Info("PrefixLength reconfigurado para: $ExpectedPrefixLength")
            }
        }
        
        return $true
        
    } catch {
        $Logger.Error("Erro ao validar IP: $_")
        throw
    }
}

# =====================================================
# FUNÇÃO: Executar FASE 2 Completa
# =====================================================

function Invoke-ADServerSetup {
    <#
    .SYNOPSIS
        Executa toda a Fase 2 de preparação do servidor
    .DESCRIPTION
        Renomeia servidor, configura IP e valida aplicação
    .PARAMETER Config
        Hashtable com configuração carregada
    .PARAMETER Logger
        Objeto logger para registrar operações
    .PARAMETER State
        Objeto state para rastrear progresso
    .PARAMETER EffectiveMode
        Modo de execução: Interactive ou Automated
    .EXAMPLE
        Invoke-ADServerSetup -Config $config -Logger $logger -State $state -EffectiveMode "Interactive"
    .OUTPUTS
        [hashtable] com resultado { Success, RequiresReboot, Message }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger,
        
        [Parameter(Mandatory = $true)]
        [object]$State,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Interactive", "Automated")]
        [string]$EffectiveMode
    )
    
    try {
        Write-Host "`n" + ("=" * 64) -ForegroundColor Cyan
        Write-Host "FASE 2: PREPARAÇÃO DO SERVIDOR" -ForegroundColor Yellow
        Write-Host ("=" * 64) -ForegroundColor Cyan
        
        $Logger.Info("Iniciando Fase 2: Preparação do Servidor")
        
        # PASSO 1: Renomear servidor
        $renameResult = Rename-ADServer -ServerName $Config.Server.Name -Logger $Logger -State $State
        
        if ($renameResult.RequiresReboot) {
            Write-Host "`n" + ("=" * 64) -ForegroundColor Red
            Write-Host "REBOOT OBRIGATÓRIO #1 - RENAME DO SERVIDOR" -ForegroundColor Red
            Write-Host ("=" * 64) -ForegroundColor Red
            
            Write-Host "`nO Windows exige um reboot para aplicar a mudança de nome" -ForegroundColor White
            
            # Solicitar reboot
            $rebootChoice = if ($EffectiveMode -eq "Interactive") {
                Read-Host "`nDeseja reiniciar agora? (S/N)"
            } else {
                Write-Host "`nModo AUTOMÁTICO: Reiniciando automaticamente em 10 segundos..." -ForegroundColor Yellow
                $Logger.Info("Reboot automático em 10 segundos (modo automático)")
                "S"
            }
            
            if ($rebootChoice -eq 'S' -or $rebootChoice -eq 's') {
                $Logger.Info("Iniciando reboot #1 em 10 segundos")
                Write-Host "`nServidor será reiniciado em 10 segundos..." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
                Restart-Computer -Force
                exit 0
            } else {
                Write-Host "`nReinicie manualmente o servidor para continuar" -ForegroundColor Yellow
                $Logger.Warning("Reboot adiado pelo usuário")
                exit 0
            }
        }
        
        # PASSO 2: Configurar IP estático
        $segment = $Config.Network.Segments[0]
        $prefixLength = $segment.CIDR
        
        # Validar CIDR
        if ($prefixLength -lt 0 -or $prefixLength -gt 32) {
            throw "CIDR inválido: $prefixLength. Deve estar entre 0 e 32"
        }
        
        # Aplicar configuração de IP
        Set-ADStaticIPAddress -ServerIP $Config.Network.ServerIP `
                             -PrefixLength $prefixLength `
                             -Gateway $segment.Gateway `
                             -DNSServers @($Config.Network.PrimaryDNS, $Config.Network.SecondaryDNS) `
                             -Logger $Logger
        
        # PASSO 3: Validar aplicação
        Test-ADIPAddressApplied -ExpectedIP $Config.Network.ServerIP `
                               -ExpectedPrefixLength $prefixLength `
                               -Logger $Logger
        
        $Logger.Success("IP estático configurado: $($Config.Network.ServerIP)/$prefixLength")
        Write-Host "✅ IP estático configurado com sucesso" -ForegroundColor Green
        
        $State.SetPhase(2)
        
        return @{
            Success        = $true
            RequiresReboot = $false
            Message        = "Fase 2 concluída com sucesso"
        }
        
    } catch {
        $Logger.Error("Erro na Fase 2: $_")
        Write-Host "❌ Erro: $_" -ForegroundColor Red
        throw
    }
}

# =====================================================
# EXPORTAR FUNÇÕES PÚBLICAS
# =====================================================

Export-ModuleMember -Function @(
    'Rename-ADServer',
    'Set-ADStaticIPAddress',
    'Test-ADIPAddressApplied',
    'Invoke-ADServerSetup'
)
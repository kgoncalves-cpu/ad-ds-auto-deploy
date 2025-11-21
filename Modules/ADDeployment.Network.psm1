# Modules/ADDeployment.Network.psm1

using module ..\Functions\Logging.ps1
using module ..\Functions\Validation.ps1

class NetworkConfiguration {
    [ADLogger] $Logger
    [hashtable] $NetworkConfig
    
    NetworkConfiguration([hashtable]$networkConfig, [ADLogger]$logger) {
        $this.NetworkConfig = $networkConfig
        $this.Logger = $logger
    }
    
    [void] ConfigureStaticIP() {
        try {
            $this.Logger.Info("Configurando IP estático...")
            
            $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
            
            if ($null -eq $adapter) {
                throw "Nenhum adaptador de rede ativo encontrado"
            }
            
            # Remover configurações anteriores
            Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
            Remove-NetRoute -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
            
            # Obter informações
            $segment = $this.NetworkConfig.Segments[0]
            $ipAddress = $this.NetworkConfig.ServerIP
            $prefixLength = $segment.CIDR
            $gateway = $segment.Gateway
            $dns = $this.NetworkConfig.PrimaryDNS
            
            # Configurar IP
            New-NetIPAddress -InterfaceIndex $adapter.ifIndex `
                           -IPAddress $ipAddress `
                           -PrefixLength $prefixLength `
                           -DefaultGateway $gateway -ErrorAction Stop
            
            # Configurar DNS
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex `
                                      -ServerAddresses $dns -ErrorAction Stop
            
            $this.Logger.Success("IP configurado: $ipAddress/$prefixLength com gateway $gateway")
        } catch {
            $this.Logger.Error("Erro ao configurar IP: $_")
            throw
        }
    }
    
    [void] ValidateNetworkConfiguration() {
        try {
            $this.Logger.Info("Validando configuração de rede...")
            
            foreach ($segment in $this.NetworkConfig.Segments) {
                if (-not [ADValidator]::ValidateIPAddress($segment.Network)) {
                    throw "IP de rede inválido: $($segment.Network)"
                }
                
                if (-not [ADValidator]::ValidateIPAddress($segment.Gateway)) {
                    throw "Gateway inválido: $($segment.Gateway)"
                }
            }
            
            if (-not [ADValidator]::ValidateIPAddress($this.NetworkConfig.ServerIP)) {
                throw "IP do servidor inválido: $($this.NetworkConfig.ServerIP)"
            }
            
            $this.Logger.Success("Configuração de rede validada com sucesso")
        } catch {
            $this.Logger.Error("Erro na validação: $_")
            throw
        }
    }
}

Export-ModuleMember -Class NetworkConfiguration
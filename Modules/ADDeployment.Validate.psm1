<#
.SYNOPSIS
    Módulo de validação para AD Deployment
.DESCRIPTION
    Fornece validadores e funções de verificação de configuração
.NOTES
    Parte do ADDeployment Framework
    Versão: 1.0
#>

# =====================================================
# CLASSE: ADValidator (Moved from Validation.ps1)
# =====================================================

class ADValidator {
    
    static [bool] ValidateDomainName([string]$domainName) {
        return $domainName -match '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    }
    
    static [bool] ValidateIPAddress([string]$ip) {
        return $ip -match '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    }
    
    static [int] ValidateCIDR([int]$cidr) {
        if ($cidr -ge 0 -and $cidr -le 32) {
            return $cidr
        }
        return $null
    }
    
    static [int] ConvertMaskToCIDR([string]$mask) {
        try {
            $octets = $mask -split '\.'
            
            if ($octets.Count -ne 4) {
                return $null
            }
            
            $binary = ''
            foreach ($octet in $octets) {
                $octetValue = [int]$octet
                
                if ($octetValue -lt 0 -or $octetValue -gt 255) {
                    return $null
                }
                
                $binary += [Convert]::ToString($octetValue, 2).PadLeft(8, '0')
            }
            
            $cidr = 0
            foreach ($bit in $binary.ToCharArray()) {
                if ($bit -eq '1') {
                    $cidr++
                } else {
                    break
                }
            }
            
            $expectedMask = ('1' * $cidr) + ('0' * (32 - $cidr))
            if ($binary -eq $expectedMask) {
                return $cidr
            }
            
            return $null
        } catch {
            return $null
        }
    }
    
    static [string] ConvertCIDRToMask([int]$cidr) {
        $maskMap = @{
            0  = "0.0.0.0"; 8  = "255.0.0.0"; 16 = "255.255.0.0"; 24 = "255.255.255.0"
            1  = "128.0.0.0"; 9  = "255.128.0.0"; 17 = "255.255.128.0"; 25 = "255.255.255.128"
            2  = "192.0.0.0"; 10 = "255.192.0.0"; 18 = "255.255.192.0"; 26 = "255.255.255.192"
            3  = "224.0.0.0"; 11 = "255.224.0.0"; 19 = "255.255.224.0"; 27 = "255.255.255.224"
            4  = "240.0.0.0"; 12 = "255.240.0.0"; 20 = "255.255.240.0"; 28 = "255.255.255.240"
            5  = "248.0.0.0"; 13 = "255.248.0.0"; 21 = "255.255.248.0"; 29 = "255.255.255.248"
            6  = "252.0.0.0"; 14 = "255.252.0.0"; 22 = "255.255.252.0"; 30 = "255.255.255.252"
            7  = "254.0.0.0"; 15 = "255.254.0.0"; 23 = "255.255.254.0"; 31 = "255.255.255.254"
            32 = "255.255.255.255"
        }
        
        if ($maskMap.ContainsKey($cidr)) {
            return $maskMap[$cidr]
        }
        
        return ""
    }
    
    static [string] GenerateUsername([string]$firstName, [string]$lastName, [string]$format) {
        if ([string]::IsNullOrWhiteSpace($firstName) -or [string]::IsNullOrWhiteSpace($lastName)) {
            return ""
        }
        
        $username = switch ($format) {
            "firstname.lastname" { "$firstName.$lastName".ToLower() }
            "firstname_lastname" { "$firstName`_$lastName".ToLower() }
            default { "$firstName.$lastName".ToLower() }
        }
        
        return $username
    }
    
    static [bool] ValidateIPInSegment([string]$ipAddress, [string]$networkAddress, [int]$cidr) {
        try {
            $ip = [System.Net.IPAddress]::Parse($ipAddress)
            $net = [System.Net.IPAddress]::Parse($networkAddress)
            
            $ipBytes = $ip.GetAddressBytes()
            $netBytes = $net.GetAddressBytes()
            
            [Array]::Reverse($ipBytes)
            [Array]::Reverse($netBytes)
            
            $ipLong = [System.BitConverter]::ToInt32($ipBytes, 0)
            $netLong = [System.BitConverter]::ToInt32($netBytes, 0)
            
            $maskBits = -bnot [int][Math]::Pow(2, (32 - $cidr)) + 1
            
            return ($ipLong -band $maskBits) -eq ($netLong -band $maskBits)
        } catch {
            return $false
        }
    }
    
    static [object] GetSegmentInfo([string]$networkAddress, [int]$cidr) {
        try {
            $net = [System.Net.IPAddress]::Parse($networkAddress)
            $netBytes = $net.GetAddressBytes()
            
            [Array]::Reverse($netBytes)
            $netLong = [System.BitConverter]::ToInt32($netBytes, 0)
            
            $maskBits = -bnot [int][Math]::Pow(2, (32 - $cidr)) + 1
            $broadcastLong = $netLong -bor (-bnot $maskBits)
            
            $networkLong = $netLong -band $maskBits
            $firstUsable = $networkLong + 1
            $lastUsable = $broadcastLong - 1
            
            $firstBytes = [System.BitConverter]::GetBytes($firstUsable)
            [Array]::Reverse($firstBytes)
            $firstIP = New-Object System.Net.IPAddress($firstBytes)
            
            $lastBytes = [System.BitConverter]::GetBytes($lastUsable)
            [Array]::Reverse($lastBytes)
            $lastIP = New-Object System.Net.IPAddress($lastBytes)
            
            return @{
                FirstIP = $firstIP.ToString()
                LastIP = $lastIP.ToString()
                TotalHosts = $broadcastLong - $networkLong - 1
            }
        } catch {
            return $null
        }
    }
}

# =====================================================
# FUNÇÃO: Validar Valores de Configuração
# =====================================================

function Invoke-ADConfigValidation {
    <#
    .SYNOPSIS
        Valida valores críticos da configuração
    .DESCRIPTION
        Verifica domínio, IP, rede e consistência CIDR/Máscara
    .PARAMETER Config
        Hashtable com configuração a validar
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        Invoke-ADConfigValidation -Config $config -Logger $logger
    .OUTPUTS
        [bool] $true se válido, lança erro caso contrário
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
        $Logger.Info("Iniciando validação de valores de configuração")
        
        # Validar nome de domínio
        Write-Host "`nValidando domínio..." -ForegroundColor Yellow
        if (-not [ADValidator]::ValidateDomainName($Config.Domain.Name)) {
            throw "Nome de domínio inválido: $($Config.Domain.Name)"
        }
        Write-Host "✅ Domínio válido: $($Config.Domain.Name)" -ForegroundColor Green
        $Logger.Success("Domínio validado: $($Config.Domain.Name)")
        
        # Validar IP do servidor
        Write-Host "`nValidando IP do servidor..." -ForegroundColor Yellow
        if (-not [ADValidator]::ValidateIPAddress($Config.Network.ServerIP)) {
            throw "IP do servidor inválido: $($Config.Network.ServerIP)"
        }
        Write-Host "✅ IP válido: $($Config.Network.ServerIP)" -ForegroundColor Green
        $Logger.Success("IP do servidor validado: $($Config.Network.ServerIP)")
        
        # Validar redes
        Write-Host "`nValidando redes..." -ForegroundColor Yellow
        foreach ($segment in $Config.Network.Segments) {
            if (-not [ADValidator]::ValidateIPAddress($segment.Network)) {
                throw "IP de rede inválido: $($segment.Network)"
            }
            Write-Host "✅ Rede válida: $($segment.Network)/$($segment.CIDR)" -ForegroundColor Green
        }
        $Logger.Success("Redes validadas com sucesso")
        
        # Validar consistência CIDR/Máscara
        Write-Host "`nValidando consistência entre CIDR e máscara..." -ForegroundColor Yellow
        
        foreach ($segment in $Config.Network.Segments) {
            $calculatedMask = [ADValidator]::ConvertCIDRToMask($segment.CIDR)
            
            if ([string]::IsNullOrEmpty($calculatedMask)) {
                throw "CIDR inválido: $($segment.CIDR). Deve estar entre 0 e 32"
            }
            
            if ($calculatedMask -ne $segment.Mask) {
                $Logger.Warning("Inconsistência detectada: CIDR $($segment.CIDR) deveria gerar máscara $calculatedMask, mas config contém $($segment.Mask)")
                Write-Host "⚠️  Ajustando máscara de config para: $calculatedMask" -ForegroundColor Yellow
                $segment.Mask = $calculatedMask
            }
            
            Write-Host "✅ CIDR/Máscara válido: $($segment.CIDR) = $($segment.Mask)" -ForegroundColor Green
        }
        $Logger.Success("Validação de CIDR/Máscara concluída")
        
        return $true
        
    } catch {
        $Logger.Error("Erro na validação de configuração: $_")
        throw
    }
}

# =====================================================
# FUNÇÃO: Obter Confirmação do Usuário
# =====================================================

function Get-ADDeploymentConfirmation {
    <#
    .SYNOPSIS
        Solicita confirmação do usuário antes de prosseguir
    .DESCRIPTION
        Exibe sumário e aguarda confirmação (S/N)
    .PARAMETER Config
        Hashtable com configuração
    .PARAMETER EffectiveMode
        Modo de execução: Interactive ou Automated
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        $confirmed = Get-ADDeploymentConfirmation -Config $config -EffectiveMode "Interactive" -Logger $logger
    .OUTPUTS
        [bool] $true se confirmado, $false se cancelado
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Interactive", "Automated")]
        [string]$EffectiveMode,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        if ($EffectiveMode -eq "Interactive") {
            Write-Host ("`n" + ("=" * 64)) -ForegroundColor Cyan
            Write-Host "RESUMO DA CONFIGURAÇÃO" -ForegroundColor White
            Write-Host "=" * 64 -ForegroundColor Cyan
            Write-Host "  Domínio: $($Config.Domain.Name)" -ForegroundColor Gray
            Write-Host "  NetBIOS: $($Config.Domain.NetBIOS)" -ForegroundColor Gray
            Write-Host "  Servidor: $($Config.Server.Name)" -ForegroundColor Gray
            Write-Host "  IP: $($Config.Network.ServerIP)" -ForegroundColor Gray
            Write-Host ("=" * 64) -ForegroundColor Cyan
            
            $response = Read-Host "`nDeseja continuar com a implementação? (S/N)"
            
            if ($response -ne 'S' -and $response -ne 's') {
                $Logger.Warning("Implementação cancelada pelo usuário")
                return $false
            }
            
            $Logger.Info("Implementação confirmada pelo usuário")
            return $true
            
        } else {
            Write-Host ("`n" + ("=" * 64)) -ForegroundColor Cyan
            Write-Host "Modo AUTOMÁTICO - continuando sem confirmação..." -ForegroundColor Green
            $Logger.Info("Modo automático: continuando sem prompt de usuário")
            Start-Sleep -Seconds 3
            return $true
        }
        
    } catch {
        $Logger.Error("Erro ao obter confirmação: $_")
        throw
    }
}

# =====================================================
# FUNÇÃO: Validar IP em Segmento
# =====================================================

function Test-ADIPInSegment {
    <#
    .SYNOPSIS
        Valida se um IP pertence a um segmento de rede
    .DESCRIPTION
        Verifica se IP está dentro da faixa de rede especificada
    .PARAMETER IPAddress
        Endereço IP a validar
    .PARAMETER NetworkAddress
        Endereço de rede
    .PARAMETER CIDR
        Notação CIDR da rede
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        Test-ADIPInSegment -IPAddress "172.22.149.244" -NetworkAddress "172.22.144.0" -CIDR 20 -Logger $logger
    .OUTPUTS
        [bool] $true se IP está na rede, $false caso contrário
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$IPAddress,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$NetworkAddress,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 32)]
        [int]$CIDR,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        $result = [ADValidator]::ValidateIPInSegment($IPAddress, $NetworkAddress, $CIDR)
        
        if ($result) {
            $Logger.Success("IP $IPAddress validado no segmento $NetworkAddress/$CIDR")
        } else {
            $Logger.Warning("IP $IPAddress NÃO está no segmento $NetworkAddress/$CIDR")
        }
        
        return $result
        
    } catch {
        $Logger.Error("Erro ao validar IP em segmento: $_")
        throw
    }
}

# =====================================================
# EXPORTAR FUNÇÕES PÚBLICAS
# =====================================================

Export-ModuleMember -Function @(
    'Invoke-ADConfigValidation',
    'Get-ADDeploymentConfirmation',
    'Test-ADIPInSegment'
)
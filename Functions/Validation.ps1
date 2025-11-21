<#
.SYNOPSIS
    Validação de Dados - Validadores para entrada
.DESCRIPTION
    Fornece classe ADValidator para validações de domínio, IP, CIDR, etc.
.NOTES
    Requer: PowerShell 5.0+
#>

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
<#
.SYNOPSIS
    Funções Utilitárias - Funções auxiliares gerais
.DESCRIPTION
    Conjunto de funções auxiliares para operações comuns
.NOTES
    Requer: PowerShell 5.0+
#>

function Test-NetworkConnectivity {
    param(
        [string]$IPAddress,
        [int]$Port = 53
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $result = $tcpClient.BeginConnect($IPAddress, $Port, $null, $null)
        $success = $result.AsyncWaitHandle.WaitOne(1000, $false)
        
        if ($success) {
            $tcpClient.EndConnect($result)
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        if ($tcpClient) {
            $tcpClient.Close()
        }
    }
}

function Get-NetworkAdapter {
    return Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
}

function Test-AdminRights {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
<#
.SYNOPSIS
    Funções Utilitárias - Repositório centralizado
.DESCRIPTION
    Funções auxiliares gerais para operações comuns
    Responsabilidades: Rede, Sistema, Validações Básicas
.NOTES
    Requer: PowerShell 5.0+
#>

# =====================================================
# SEÇÃO 1: Funções de Rede
# =====================================================

function Test-NetworkConnectivity {
    <#
    .SYNOPSIS
        Testa conectividade de rede para IP e porta específicos
    .PARAMETER IPAddress
        Endereço IP a testar
    .PARAMETER Port
        Porta para teste (padrão: 53 DNS)
    .OUTPUTS
        [bool] $true se conectado
    #>
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
    <#
    .SYNOPSIS
        Obtém o adaptador de rede ativo
    .OUTPUTS
        [PSObject] Adaptador de rede ativo
    #>
    return Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
}

# =====================================================
# SEÇÃO 2: Funções de Sistema
# =====================================================

function Test-AdminRights {
    <#
    .SYNOPSIS
        Verifica se script está rodando como administrador
    .OUTPUTS
        [bool] $true se admin
    #>
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

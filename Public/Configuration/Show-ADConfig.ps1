<#
.SYNOPSIS
    Exibe configuração carregada no console
.DESCRIPTION
    Formata e exibe valores principais da configuração
.PARAMETER Config
    Hashtable com configuração carregada
.PARAMETER Logger
    Objeto logger para registrar operações
.EXAMPLE
    Show-ADConfig -Config $config -Logger $logger
.OUTPUTS
    $null (apenas saída visual)
#>
function Show-ADConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`nConfiguração Carregada:" -ForegroundColor Yellow
        Write-Host "  Domínio: $($Config.Domain.Name)" -ForegroundColor Gray
        Write-Host "  NetBIOS: $($Config.Domain.NetBIOS)" -ForegroundColor Gray
        Write-Host "  Servidor: $($Config.Server.Name)" -ForegroundColor Gray
        Write-Host "  IP: $($Config.Network.ServerIP)" -ForegroundColor Gray
        Write-Host "  CIDR: $($Config.Network.Segments[0].CIDR)" -ForegroundColor Gray
        Write-Host "  Máscara: $($Config.Network.Segments[0].Mask)" -ForegroundColor Gray
        Write-Host "  DHCP: $(if($Config.Services.InstallDHCP){'Sim'}else{'Não'})" -ForegroundColor Gray
        
        $Logger.Info("Configuração exibida para o usuário")
        
    } catch {
        $Logger.Error("Erro ao exibir configuração: $_")
        throw
    }
}
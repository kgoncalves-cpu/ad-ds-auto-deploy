<#
.SYNOPSIS
    Carrega arquivo de configuração PowerShell Data File
.DESCRIPTION
    Importa e valida arquivo .psd1 de configuração
.PARAMETER ConfigFile
    Caminho para arquivo de configuração
.PARAMETER Logger
    Objeto logger para registrar operações
.EXAMPLE
    $config = Import-ADConfig -ConfigFile ".\Config\Default.psd1" -Logger $logger
.OUTPUTS
    [hashtable] Configuração carregada
#>
function Import-ADConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigFile,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        $Logger.Info("Iniciando carregamento de configuração: $ConfigFile")
        
        if (-not (Test-Path $ConfigFile)) {
            throw "Arquivo de configuração não encontrado: $ConfigFile"
        }
        
        $config = Import-PowerShellDataFile -Path $ConfigFile
        
        if ($null -eq $config) {
            throw "Arquivo de configuração vazio ou inválido"
        }
        
        $Logger.Success("Configuração carregada com sucesso: $ConfigFile")
        return $config
        
    } catch {
        $Logger.Error("Erro ao carregar configuração: $_")
        throw
    }
}
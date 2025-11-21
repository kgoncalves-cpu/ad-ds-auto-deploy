<#
.SYNOPSIS
    Módulo Core - Gerenciamento central de configuração
.DESCRIPTION
    Responsável pela carga e gerenciamento da configuração geral.
.NOTES
    Requer: PowerShell 5.0+
    Este é um módulo legítimo (.psm1) que pode usar Export-ModuleMember
#>

# Definir classes
class ADConfigurationManager {
    [hashtable] $Configuration
    [object] $Logger
    [string] $ConfigPath
    
    ADConfigurationManager([string]$configFile, [object]$logger) {
        $this.ConfigPath = $configFile
        $this.Logger = $logger
        $this.LoadConfiguration()
    }
    
    [void] LoadConfiguration() {
        try {
            if (-not (Test-Path $this.ConfigPath)) {
                throw "Arquivo não encontrado: $($this.ConfigPath)"
            }
            
            $this.Configuration = Import-PowerShellDataFile -Path $this.ConfigPath
            $this.Logger.Success("Configuração carregada")
        } catch {
            $this.Logger.Error("Erro ao carregar: $_")
            throw
        }
    }
}

# Exportar (correto para .psm1)
Export-ModuleMember -Class ADConfigurationManager
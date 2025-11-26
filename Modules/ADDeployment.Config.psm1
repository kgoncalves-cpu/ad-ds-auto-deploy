<#
.SYNOPSIS
    Módulo de gerenciamento de configuração para AD Deployment
.DESCRIPTION
    Responsável por carregar, validar e exibir configurações do deployment
.NOTES
    Parte do ADDeployment Framework
    Versão: 1.0
#>

# =====================================================
# FUNÇÃO: Carregar Configuração
# =====================================================

function Import-ADConfig {
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
        
        # Validar existência do arquivo
        if (-not (Test-Path $ConfigFile)) {
            throw "Arquivo de configuração não encontrado: $ConfigFile"
        }
        
        # Carregar arquivo
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

# =====================================================
# FUNÇÃO: Exibir Configuração
# =====================================================

function Show-ADConfig {
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        Write-Host "`nConfigração Carregada:" -ForegroundColor Yellow
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

# =====================================================
# FUNÇÃO: Validar Estrutura da Configuração
# =====================================================

function Test-ADConfigStructure {
    <#
    .SYNOPSIS
        Valida estrutura obrigatória da configuração
    .DESCRIPTION
        Verifica se todas as seções obrigatórias existem
    .PARAMETER Config
        Hashtable com configuração a validar
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        Test-ADConfigStructure -Config $config -Logger $logger
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
    
    $requiredSections = @(
        'Domain',
        'Network',
        'Server',
        'Users',
        'Passwords',
        'Services',
        'Advanced'
    )
    
    $requiredDomainKeys = @('Name', 'NetBIOS')
    $requiredNetworkKeys = @('ServerIP', 'Segments', 'PrimaryDNS', 'SecondaryDNS')
    $requiredServerKeys = @('Name')
    $requiredAdvancedKeys = @('ForestMode', 'DomainMode')
    
    try {
        $Logger.Info("Validando estrutura de configuração")
        
        # Validar seções principais
        foreach ($section in $requiredSections) {
            if (-not $Config.ContainsKey($section)) {
                throw "Seção obrigatória ausente: [$section]"
            }
        }
        
        # Validar chaves do Domain
        foreach ($key in $requiredDomainKeys) {
            if (-not $Config.Domain.ContainsKey($key)) {
                throw "Chave obrigatória ausente em [Domain]: $key"
            }
        }
        
        # Validar chaves do Network
        foreach ($key in $requiredNetworkKeys) {
            if (-not $Config.Network.ContainsKey($key)) {
                throw "Chave obrigatória ausente em [Network]: $key"
            }
        }
        
        # Validar chaves do Server
        foreach ($key in $requiredServerKeys) {
            if (-not $Config.Server.ContainsKey($key)) {
                throw "Chave obrigatória ausente em [Server]: $key"
            }
        }
        
        # Validar chaves do Advanced
        foreach ($key in $requiredAdvancedKeys) {
            if (-not $Config.Advanced.ContainsKey($key)) {
                throw "Chave obrigatória ausente em [Advanced]: $key"
            }
        }
        
        # Validar que Segments não está vazio
        if ($Config.Network.Segments.Count -eq 0) {
            throw "Network.Segments não pode estar vazio"
        }
        
        $Logger.Success("Estrutura de configuração validada com sucesso")
        return $true
        
    } catch {
        $Logger.Error("Erro na validação de estrutura: $_")
        throw
    }
}

# =====================================================
# FUNÇÃO: Obter Modo de Execução
# =====================================================

function Get-ADExecutionMode {
    <#
    .SYNOPSIS
        Determina o modo de execução efetivo
    .DESCRIPTION
        Verifica se é execução automática (pós-reboot) ou interativa
    .PARAMETER Mode
        Modo solicitado: Interactive ou Automated
    .PARAMETER AutoContinue
        Flag de continuação automática
    .PARAMETER Logger
        Objeto logger para registrar operações
    .EXAMPLE
        $effectiveMode = Get-ADExecutionMode -Mode "Interactive" -AutoContinue $true -Logger $logger
    .OUTPUTS
        [string] Modo efetivo: "Interactive" ou "Automated"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Interactive", "Automated")]
        [string]$Mode,
        
        [Parameter(Mandatory = $true)]
        [bool]$AutoContinue,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        $isAutomaticExecution = -not ([Environment]::UserInteractive)
        $effectiveMode = if ($isAutomaticExecution -and $AutoContinue) { "Automated" } else { $Mode }
        
        if ($effectiveMode -eq "Automated") {
            Write-Host "Modo AUTOMÁTICO detectado (pós-reboot) - sem prompts interativos" -ForegroundColor Yellow
            $Logger.Info("Modo de execução: AUTOMÁTICO (detecção de reboot)")
        } else {
            Write-Host "Modo INTERATIVO - aguardando confirmações do usuário" -ForegroundColor White
            $Logger.Info("Modo de execução: INTERATIVO")
        }
        
        return $effectiveMode
        
    } catch {
        $Logger.Error("Erro ao determinar modo de execução: $_")
        throw
    }
}

# Exportar funções públicas
Export-ModuleMember -Function @(
    'Import-ADConfig',
    'Show-ADConfig',
    'Test-ADConfigStructure',
    'Get-ADExecutionMode'
)
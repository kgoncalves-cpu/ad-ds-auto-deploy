<#
.SYNOPSIS
    Gerencia senhas de forma segura usando SecretManagement
.DESCRIPTION
    Armazena e recupera senhas de forma criptografada
.NOTES
    Requer: Microsoft.PowerShell.SecretManagement module
#>

function Set-ADDeploymentSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SecretName,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$SecretValue,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        # Verificar se módulo está disponível
        if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
            $Logger.Warning("Microsoft.PowerShell.SecretManagement não instalado - usando plaintext")
            return $SecretValue
        }
        
        # Verificar se vault existe
        $vault = Get-SecretVault -Name ADDeployment -ErrorAction SilentlyContinue
        if (-not $vault) {
            Register-SecretVault -Name ADDeployment -ModuleName SecretStore -DefaultVault -ErrorAction SilentlyContinue
        }
        
        Set-Secret -Name $SecretName -Secret $SecretValue -Vault ADDeployment -ErrorAction Stop
        $Logger.Success("Credencial '$SecretName' armazenada com segurança")
        
    } catch {
        $Logger.Warning("Erro ao armazenar segredo: $_ - usando alternativa")
        return $SecretValue
    }
}

function Get-ADDeploymentSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SecretName,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger,
        
        [Parameter(Mandatory = $false)]
        [switch]$AsPlainText
    )
    
    try {
        $vault = Get-SecretVault -Name ADDeployment -ErrorAction SilentlyContinue
        
        if ($vault) {
            $secret = Get-Secret -Name $SecretName -Vault ADDeployment -AsPlainText:$AsPlainText -ErrorAction Stop
            $Logger.Info("Segredo '$SecretName' recuperado com sucesso")
            return $secret
        } else {
            $Logger.Warning("Vault ADDeployment não configurado")
            return $null
        }
        
    } catch {
        $Logger.Error("Erro ao recuperar segredo: $_")
        return $null
    }
}

function Test-ADDeploymentSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
            $Logger.Warning("Microsoft.PowerShell.SecretManagement não está instalado")
            return $false
        }
        
        $vault = Get-SecretVault -Name ADDeployment -ErrorAction SilentlyContinue
        if ($vault) {
            $Logger.Success("Vault ADDeployment está configurado e acessível")
            return $true
        } else {
            $Logger.Info("Vault ADDeployment não configurado - criando...")
            Register-SecretVault -Name ADDeployment -ModuleName SecretStore -DefaultVault -ErrorAction Stop
            return $true
        }
        
    } catch {
        $Logger.Error("Erro ao verificar vault: $_")
        return $false
    }
}
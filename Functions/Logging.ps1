<#
.SYNOPSIS
    Sistema de Logging - Log com múltiplos níveis
.DESCRIPTION
    Fornece classe ADLogger para logging em console e arquivo
.NOTES
    Requer: PowerShell 5.0+
#>

class ADLogger {
    [string] $LogFilePath
    [bool] $ConsoleOutput
    [bool] $FileOutput
    
    ADLogger([string]$logPath, [bool]$console, [bool]$file) {
        $this.LogFilePath = $logPath
        $this.ConsoleOutput = $console
        $this.FileOutput = $file
        
        $logDirectory = Split-Path -Parent $logPath
        if (-not (Test-Path $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        }
    }
    
    [void] Info([string]$message) {
        $this.Log($message, "Info", "Cyan")
    }
    
    [void] Success([string]$message) {
        $this.Log($message, "Success", "Green")
    }
    
    [void] Warning([string]$message) {
        $this.Log($message, "Warning", "Yellow")
    }
    
    [void] Error([string]$message) {
        $this.Log($message, "Error", "Red")
    }
    
    [void] Debug([string]$message) {
        $this.Log($message, "Debug", "Gray")
    }
    
    hidden [void] Log([string]$message, [string]$level, [string]$color) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$level] $message"
        
        if ($this.ConsoleOutput) {
            Write-Host $logMessage -ForegroundColor $color
        }
        
        if ($this.FileOutput) {
            try {
                Add-Content -Path $this.LogFilePath -Value $logMessage -ErrorAction SilentlyContinue
            } catch {
                # Ignorar erros de escrita silenciosamente
            }
        }
    }
}
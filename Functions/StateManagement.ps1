<#
.SYNOPSIS
    Gerenciamento de Estado - Rastreia execução das fases do deployment
.DESCRIPTION
    Mantém registro do estado do deployment para automação das próximas fases
.NOTES
    Requer: PowerShell 5.0+
#>

class DeploymentState {
    [string] $StateFilePath
    [hashtable] $State
    
    DeploymentState([string]$stateFile) {
        $this.StateFilePath = $stateFile
        $this.LoadState()
    }
    
    # =====================================================
    # Carregar Estado do Arquivo
    # =====================================================
    
    [void] LoadState() {
        if (Test-Path $this.StateFilePath) {
            try {
                $this.State = Import-Clixml -Path $this.StateFilePath
            } catch {
                $this.InitializeState()
            }
        } else {
            $this.InitializeState()
        }
    }
    
    # =====================================================
    # Inicializar Estado Padrão
    # =====================================================
    
    [void] InitializeState() {
        $this.State = @{
            Phase = 0
            LastRun = $null
            RenameApplied = $false
            ADInstalled = $false
            ADPromoted = $false
            StartTime = Get-Date
            LastUpdate = Get-Date
        }
    }
    
    # =====================================================
    # Salvar Estado no Arquivo
    # =====================================================
    
    [void] SaveState() {
        try {
            $stateDir = Split-Path -Parent $this.StateFilePath
            if (-not (Test-Path $stateDir)) {
                New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
            }
            
            $this.State.LastUpdate = Get-Date
            $this.State | Export-Clixml -Path $this.StateFilePath -Force
        } catch {
            Write-Host "Aviso: Não foi possível salvar estado: $_" -ForegroundColor Yellow
        }
    }
    
    # =====================================================
    # Métodos de Consulta
    # =====================================================
    
    [int] GetPhase() {
        return $this.State.Phase
    }
    
    [void] SetPhase([int]$phase) {
        $this.State.Phase = $phase
        $this.State.LastRun = Get-Date
        $this.SaveState()
    }
    
    [bool] IsRenameApplied() {
        return $this.State.RenameApplied
    }
    
    [void] MarkRenameApplied() {
        $this.State.RenameApplied = $true
        $this.SaveState()
    }
    
    [bool] IsADInstalled() {
        return $this.State.ADInstalled
    }
    
    [void] MarkADInstalled() {
        $this.State.ADInstalled = $true
        $this.SaveState()
    }
    
    [bool] IsADPromoted() {
        return $this.State.ADPromoted
    }
    
    [void] MarkADPromoted() {
        $this.State.ADPromoted = $true
        $this.SaveState()
    }
    
    # =====================================================
    # Métodos Auxiliares
    # =====================================================
    
    [hashtable] GetStatus() {
        return @{
            Phase = $this.State.Phase
            RenameApplied = $this.State.RenameApplied
            ADInstalled = $this.State.ADInstalled
            ADPromoted = $this.State.ADPromoted
            LastUpdate = $this.State.LastUpdate
            ElapsedTime = (Get-Date) - $this.State.StartTime
        }
    }
    
    [void] ResetState() {
        $this.InitializeState()
        $this.SaveState()
    }
}

# Nota: Export-ModuleMember -Class não é suportado no PowerShell 5.0
# A classe DeploymentState fica disponível automaticamente após dot-sourcing
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Script wrapper para execução automática após reboot
.DESCRIPTION
    Este script é registrado no RunOnce para executar automaticamente
    após o reboot do rename do servidor.
.NOTES
    Versão: 1.0
#>

param(
    [string]$ConfigFile = "$PSScriptRoot\Config\Default.psd1",
    [string]$Mode = "Interactive",
    [switch]$AutoContinue
)

Write-Host "`n" + ("=" * 64) -ForegroundColor Green
Write-Host "EXECUÇÃO AUTOMÁTICA - RESUMINDO APÓS REBOOT" -ForegroundColor Green
Write-Host ("=" * 64) -ForegroundColor Green

# Aguardar um pouco para garantir que tudo está pronto
Start-Sleep -Seconds 5

# Executar Deploy.ps1 com os mesmos parâmetros
& "$PSScriptRoot\Deploy.ps1" -ConfigFile $ConfigFile -Mode $Mode -AutoContinue:$AutoContinue
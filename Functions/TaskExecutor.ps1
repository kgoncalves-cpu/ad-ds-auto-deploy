<#
.SYNOPSIS
    Executor de tarefa agendada com logging e visualização de erros
.DESCRIPTION
    Wrapper que executa o Deploy.ps1 com redirecionamento completo de saída
    e garante que janela PowerShell permaneça aberta para diagnóstico.
.NOTES
    Usado pela tarefa agendada no Task Scheduler
#>

param(
    [string]$ScriptPath,
    [string]$ConfigPath,
    [string]$Mode = "Interactive",
    [switch]$AutoContinue
)

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RETOMANDO DEPLOYMENT - EXECUTOR DE TAREFAS                ║" -ForegroundColor Cyan
Write-Host "║  Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`nExecutando script: $ScriptPath" -ForegroundColor Yellow
Write-Host "Com configuração: $ConfigPath" -ForegroundColor Yellow
Write-Host "Modo: $Mode | AutoContinue: $AutoContinue`n" -ForegroundColor Yellow

try {
    # Executar o Deploy.ps1 com os parâmetros
    & $ScriptPath -ConfigFile $ConfigPath -Mode $Mode -AutoContinue:$AutoContinue
    
    Write-Host "`n✅ Deployment concluído com sucesso!" -ForegroundColor Green
} catch {
    Write-Host "`n❌ Erro durante execução: $_" -ForegroundColor Red
    Write-Host "`nPressione ENTER para fechar..." -ForegroundColor Yellow
    Read-Host
}
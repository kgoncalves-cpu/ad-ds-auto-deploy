<#
.SYNOPSIS
    Solicita senha de forma segura
.DESCRIPTION
    Prompta para entrada de senha com validação de força
#>

function Invoke-SecurePasswordPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PromptMessage,
        
        [Parameter(Mandatory = $false)]
        [int]$MinLength = 8,
        
        [Parameter(Mandatory = $false)]
        [switch]$RequireComplexity,
        
        [Parameter(Mandatory = $true)]
        [object]$Logger
    )
    
    try {
        do {
            Write-Host "`n$PromptMessage" -ForegroundColor Yellow
            $password = Read-Host "Senha" -AsSecureString
            
            $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
            )
            
            # Validar comprimento
            if ($passwordPlain.Length -lt $MinLength) {
                Write-Host "❌ A senha deve ter no mínimo $MinLength caracteres" -ForegroundColor Red
                $Logger.Warning("Senha rejeitada: comprimento insuficiente")
                continue
            }
            
            # Validar complexidade se solicitado
            if ($RequireComplexity) {
                $hasUpper = $passwordPlain -match '[A-Z]'
                $hasLower = $passwordPlain -match '[a-z]'
                $hasDigit = $passwordPlain -match '[0-9]'
                $hasSpecial = $passwordPlain -match '[^A-Za-z0-9]'
                
                if (-not ($hasUpper -and $hasLower -and $hasDigit -and $hasSpecial)) {
                    Write-Host "❌ A senha deve conter maiúsculas, minúsculas, números e caracteres especiais" -ForegroundColor Red
                    $Logger.Warning("Senha rejeitada: complexidade insuficiente")
                    continue
                }
            }
            
            # Confirmar senha
            $confirm = Read-Host "Confirme a senha" -AsSecureString
            $confirmPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirm)
            )
            
            if ($passwordPlain -ne $confirmPlain) {
                Write-Host "❌ As senhas não coincidem" -ForegroundColor Red
                $Logger.Warning("Senhas não coincidiram")
                continue
            }
            
            Write-Host "✅ Senha confirmada" -ForegroundColor Green
            $Logger.Info("Senha obtida e validada com sucesso")
            
            return $password
            
        } while ($true)
        
    } catch {
        $Logger.Error("Erro ao obter senha: $_")
        throw
    }
}
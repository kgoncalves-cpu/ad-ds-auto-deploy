# Config/Default.psd1
@{
    # =====================================================
    # CONFIGURAÇÕES DO DOMÍNIO
    # =====================================================
    Domain = @{
        Name = "brmc.local"
        NetBIOS = "BRMC"
        Mode = "WinThreshold"
    }
    
    # =====================================================
    # CONFIGURAÇÕES DE REDE
    # =====================================================
    Network = @{
        Segments = @(
            @{
                Network = "172.22.144.0"
                CIDR = 20
                Mask = "255.255.240.0"
                Gateway = "172.22.144.1"
            }
        )
        ServerIP = "172.22.149.244"
        PrimaryDNS = "127.0.0.1"
        SecondaryDNS = "8.8.8.8"
    }
    
    # =====================================================
    # CONFIGURAÇÕES DO SERVIDOR
    # =====================================================
    Server = @{
        Name = "BRMC-DC01"
        OSVersion = "Windows Server 2022"
    }
    
    # =====================================================
    # CONFIGURAÇÕES DE USUÁRIOS
    # =====================================================
    Users = @(
        @{
            FirstName = "Administrador"
            LastName = "Domínio"
            Department = "TI"
            Email = "admin@brmc.local"
        }
    )
    
    Passwords = @{
        DSRM = ""  # Será preenchido interativamente
        DefaultUser = ""  # Será preenchido interativamente
    }
    
    # =====================================================
    # CONFIGURAÇÕES DE POLÍTICAS
    # =====================================================
    PasswordPolicy = @{
        MinLength = 8
        MaxAge = 90
        MinAge = 1
        HistoryCount = 5
        ComplexityEnabled = $true
    }
    
    LockoutPolicy = @{
        Threshold = 5
        Duration = 30
        Window = 30
    }
    
    # =====================================================
    # CONFIGURAÇÕES DE SERVIÇOS
    # =====================================================
    Services = @{
        InstallDHCP = $false
        InstallDFS = $false
        InstallFRS = $false
        InstallCertificateServices = $false
    }
    
    DHCPScopes = @()  # Será preenchido se InstallDHCP = $true
    
    # =====================================================
    # CONFIGURAÇÕES DE ESTRUTURA
    # =====================================================
    OrganizationalUnits = @{
        Pattern = "BRMC"
        Computers = "BRMC-Computadores"
        Users = "BRMC-Usuarios"
        Groups = "BRMC-Grupos"
        Servers = "BRMC-Servidores"
    }
    
    Groups = @(
        @{
            Name = "GRP-Usuarios-Padrao"
            Scope = "Global"
            Category = "Security"
            Description = "Grupo padrão de usuários"
        }
        @{
            Name = "GRP-Administradores-TI"
            Scope = "Global"
            Category = "Security"
            Description = "Administradores de TI"
        }
        @{
            Name = "GRP-Gerencia"
            Scope = "Global"
            Category = "Security"
            Description = "Gerência"
        }
    )
    
    # =====================================================
    # CONFIGURAÇÕES DE NOMENCLATURA
    # =====================================================
    Naming = @{
        WorkstationPattern = "BRMC-<ID>-<USER>"
        UserNameFormat = "firstname.lastname"  # firstname.lastname ou firstname_lastname
    }
    
    # =====================================================
    # CONFIGURAÇÕES DE LOGGING
    # =====================================================
    Logging = @{
        Level = "Info"  # Info, Warning, Error, Debug
        FilePath = "C:\ADDeployment_Logs"
        ConsoleOutput = $true
        FileOutput = $true
    }
    
    # =====================================================
    # CONFIGURAÇÕES AVANÇADAS
    # =====================================================
    Advanced = @{
        AutoReboot = $true
        RebootDelay = 10
        DNSForwarders = @("8.8.8.8", "1.1.1.1")
        ForestMode = "WinThreshold"
        DomainMode = "WinThreshold"
    }
}

try {
    . "$PSScriptRoot\Functions\StateManagement.ps1" -ErrorAction Stop
    Write-Host "StateManagement.ps1 carregado" -ForegroundColor Green
} catch {
    Write-Host "Erro ao carregar StateManagement.ps1: $_" -ForegroundColor Red
    Write-Host "Caminho tentado: $PSScriptRoot\Functions\StateManagement.ps1" -ForegroundColor Yellow
    Write-Host "Você pode continuar sem este arquivo, mas a automação será afetada" -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}
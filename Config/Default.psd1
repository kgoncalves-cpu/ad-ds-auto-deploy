# Config/Default.psd1
@{
    # =====================================================
    # CONFIGURAÇÕES DO DOMÍNIO
    # =====================================================
    Domain = @{
        Name = "brmc.local"
        NetBIOS = "BRMC"
    }
    
    # =====================================================
    # CONFIGURAÇÕES DE REDE
    # =====================================================
    Network = @{
        Segments = @(
            @{
                Network = "192.168.192.0"
                CIDR = 20
                Mask = "255.255.240.0"
                Gateway = "192.168.192.1"
            }
        )
        ServerIP = "192.168.192.103"
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
        @{
            FirstName = "TI Department"
            LastName = "Domínio"
            Department = "TI"
            Email = "admin@brmc.local"
        }


    )
    
    Passwords = @{
        DSRM = "Servidor#2025"
        DefaultUser = "Utilizador#2025"
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
    
    DHCPScopes = @()
    
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
        UserNameFormat = "firstname.lastname"
    }
    
    # =====================================================
    # CONFIGURAÇÕES DE LOGGING
    # =====================================================
    Logging = @{
        Level = "Info"
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
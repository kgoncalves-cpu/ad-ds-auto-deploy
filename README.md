# Automação de Deployment de Active Directory Domain Controller

## Visão Geral
Este projeto implementa um sistema modular e automatizado para deployment de Active Directory Domain Controller (AD DC) em ambientes Windows Server. Utiliza Configuration-as-Data, Dependency Injection e automação pós-reboot via Task Scheduler.

---

## Funcionalidades Implementadas

### 1. Estrutura Modular
- **Scripts principais:**
  - `Deploy.ps1`: Executa fases iniciais do deployment (validação, preparação do servidor, instalação do AD DS).
  - `Deploy-AutoContinue.ps1`: Retoma automaticamente após reboot.
  - `Deploy-Part2.ps1`: Configurações pós-instalação (DNS, OUs, GPOs, etc.).
- **Funções auxiliares:**
  - `Functions\Logging.ps1`: Sistema de logging para console e arquivos.
  - `Functions\Validation.ps1`: Validação de rede, IPs e configuração.
  - `Functions\StateManagement.ps1`: Gerenciamento de estado entre reboots.

### 2. Automação Pós-Reboot
- Criação automática de tarefa no Task Scheduler para retomar o script após reboot.
- Suporte à execução como SYSTEM.
- Configuração direta via PowerShell.

### 3. Validação de Configuração
- Validação de nome de domínio, NetBIOS, IP, segmentos de rede, máscara de sub-rede e CIDR.
- Logs detalhados para erros de configuração.

### 4. Configuração Centralizada
- Arquivo `Config\Default.psd1` para configurações de domínio, rede, servidor, usuários, políticas, serviços e estrutura organizacional.
- Suporte a múltiplos segmentos de rede.
- Configuração de senhas (DSRM e usuários padrão).

### 5. Logging
- Logs detalhados em `Logs\ADDeployment_*.log`.
- Níveis de log: Info, Warning, Error, Debug.
- Saída simultânea para console e arquivo.

### 6. Gerenciamento de Estado
- Classe `DeploymentState` rastreia progresso entre fases.
- Estado salvo em `Logs\ADDeployment.state`.
- Permite retomar de onde parou após reboot.

---

## Funcionalidades Planejadas

### 1. Configuração Pós-Instalação
- Implementar `Deploy-Part2.ps1` para configuração de DNS, criação de OUs, grupos, usuários e aplicação de GPOs.

### 2. Instalação de Serviços Adicionais
- Suporte a DHCP, DFS, Certificate Services e configuração de escopos DHCP.

### 3. Melhorias na Validação
- Correção de bug no cálculo de range de rede (CIDR).
- Validação de DNS Forwarders.

### 4. Automação Completa
- Execução totalmente autônoma para ambientes de produção.
- Configuração de senhas diretamente no arquivo de configuração.

### 5. Documentação Completa
- Documentação detalhada da estrutura de diretórios, fluxo de execução, configuração de ambiente e troubleshooting.

---

## Estrutura do Projeto

📁 PsScripts/ <br>
├── 📄 Deploy.ps1 &emsp; &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&nbsp;(Script Principal)
├── 📄 Deploy-AutoContinue.ps1 &emsp;(Automação Pós-Reboot) 
├── 📄 Deploy-Part2.ps1&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&nbsp;(Configuração Pós-Instalação) 
├── 📁 Functions/ 
│   ├── 📄 Logging.ps1&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&nbsp;(Sistema de Log) 
│   ├── 📄 Validation.ps1&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;(Validadores) 
│   ├── 📄 StateManagement.ps1&emsp;&emsp;(Gerenciamento de Estado)
│   └── 📄 Utilities.ps1&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;(Funções Auxiliares) 
├── 📁 Config/
│   ├── 📄 Default.psd1&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&nbsp;(Configuração Padrão) 
│   ├── 📄 Test.psd1&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&nbsp;(Ambiente de Teste)
│   └── 📄 Production.psd1&emsp;&emsp;&emsp;&emsp;&emsp;&nbsp;(Ambiente Produção)
└── 📁 Logs/
    └── 📄 ADDeployment_*.log&emsp;&emsp;&emsp;&emsp;(Arquivos de Log)

---

## Fluxo de Execução

1. **Validação:** Verifica configuração de domínio, rede e servidor. Gera logs detalhados para erros.
2. **Preparação do Servidor:** Renomeia o servidor e configura IP estático.
3. **Instalação do AD DS:** Instala recursos necessários e promove o servidor a Domain Controller.
4. **Configuração Pós-Instalação (pendente):** Configura DNS, cria OUs, grupos, usuários e aplica GPOs.

---

## Checklist de Implementação

### ✅ Concluído
- Estrutura modular
- Automação pós-reboot
- Validação de configuração
- Logging detalhado
- Gerenciamento de estado

### 🔧 Pendente
- Configuração pós-instalação
- Suporte a serviços adicionais (DHCP, DFS, etc.)
- Melhorias na validação
- Automação completa
- Documentação detalhada

---

## Suporte

Para diagnosticar problemas:
# Verificar logs
Get-Content -Path "C:\PSScript\Logs\ADDeployment_*.log" -Tail 50

# Verificar estado
Get-Content -Path "C:\PSScript\Logs\ADDeployment.state"

<<<<<<< HEAD

---

**Última Atualização:** 20/11/2025  
**Status:** Em desenvolvimento
=======
Última Atualização: 20/11/2025
Status: Em desenvolvimento
>>>>>>> adf378d5ea38e1873aebc342bd9a9fe30d330665

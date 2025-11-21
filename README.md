📖 Documentação do Programa: Automação de Deployment de Active Directory Domain Controller
📋 Visão Geral
Este projeto implementa um sistema modular e automatizado para deployment de Active Directory Domain Controller (AD DC) em ambientes Windows Server. Ele utiliza conceitos como Configuration-as-Data, Dependency Injection, e Automação Pós-Reboot via Task Scheduler.
---
🚀 Funcionalidades Implementadas
1️⃣ Estrutura Modular
•	Scripts principais:
•	Deploy.ps1: Executa as fases iniciais do deployment (validação, preparação do servidor, instalação do AD DS).
•	Deploy-AutoContinue.ps1: Retoma automaticamente após reboot.
•	Deploy-Part2.ps1: Configurações pós-instalação (DNS, OUs, GPOs, etc.).
•	Funções auxiliares:
•	Functions\Logging.ps1: Sistema de logging para console e arquivos.
•	Functions\Validation.ps1: Validação de rede, IPs e configuração.
•	Functions\StateManagement.ps1: Gerenciamento de estado para rastrear progresso entre reboots.
---
2️⃣ Automação Pós-Reboot
•	Task Scheduler:
•	Criação automática de tarefa para retomar o script após reboot.
•	Suporte a execução como SYSTEM.
•	Configuração direta via PowerShell (sem batch).
---
3️⃣ Validação de Configuração
•	Validação de:
•	Nome do domínio e NetBIOS.
•	IP do servidor e segmentos de rede.
•	Máscara de sub-rede e CIDR.
•	Logs detalhados para erros de configuração.
---
4️⃣ Configuração Centralizada
•	Arquivo Config\Default.psd1:
•	Configurações de domínio, rede, servidor, usuários, políticas, serviços e estrutura organizacional.
•	Suporte a múltiplos segmentos de rede.
•	Configuração de senhas (DSRM e usuários padrão).
---
5️⃣ Logging
•	Logs detalhados em Logs\ADDeployment_*.log.
•	Suporte a níveis de log: Info, Warning, Error, Debug.
•	Saída simultânea para console e arquivo.
---
6️⃣ Gerenciamento de Estado
•	Classe DeploymentState:
•	Rastreia progresso entre fases (validação, rename, instalação do AD, promoção a DC).
•	Salva estado em Logs\ADDeployment.state.
•	Permite retomar de onde parou após reboot.
---
🔧 Funcionalidades Planejadas (Pendentes)
1️⃣ Configuração Pós-Instalação
•	Implementar Deploy-Part2.ps1:
•	Configuração de DNS.
•	Criação de Organizational Units (OUs).
•	Criação de grupos e usuários.
•	Aplicação de Group Policies (GPOs).
---
2️⃣ Instalação de Serviços Adicionais
•	Suporte a:
•	DHCP.
•	DFS.
•	Certificate Services.
•	Configuração de escopos DHCP (se habilitado).
---
3️⃣ Melhorias na Validação
•	Corrigir bug no cálculo de range de rede (CIDR).
•	Adicionar validação de DNS Forwarders.
---
4️⃣ Automação Completa
•	Suporte a execução totalmente autônoma (sem prompts) para ambientes de produção.
•	Configuração de senhas diretamente no arquivo Config\Default.psd1.
---
5️⃣ Documentação Completa
•	Criar documentação detalhada para:
•	Estrutura de diretórios.
•	Fluxo de execução.
•	Configuração de ambiente.
•	Troubleshooting.
---
📊 Estrutura do Projeto

📁 PsScripts/
├── 📄 Deploy.ps1                    (Script Principal)
├── 📄 Deploy-AutoContinue.ps1       (Automação Pós-Reboot)
├── 📄 Deploy-Part2.ps1              (Configuração Pós-Instalação)
├── 📁 Functions/
│   ├── 📄 Logging.ps1               (Sistema de Log)
│   ├── 📄 Validation.ps1            (Validadores)
│   ├── 📄 StateManagement.ps1       (Gerenciamento de Estado)
│   └── 📄 Utilities.ps1             (Funções Auxiliares)
├── 📁 Config/
│   ├── 📄 Default.psd1              (Configuração Padrão)
│   ├── 📄 Test.psd1                 (Ambiente de Teste)
│   └── 📄 Production.psd1           (Ambiente Produção)
└── 📁 Logs/
    └── 📄 ADDeployment_*.log        (Arquivos de Log)

    🚀 Fluxo de Execução
Fases do Deployment
1.	Validação:
•	Verifica configuração de domínio, rede e servidor.
•	Gera logs detalhados para erros.
2.	Preparação do Servidor:
•	Renomeia o servidor.
•	Configura IP estático.
3.	Instalação do AD DS:
•	Instala recursos necessários.
•	Promove o servidor a Domain Controller.
4.	Configuração Pós-Instalação (pendente):
•	Configura DNS.
•	Cria OUs, grupos e usuários.
•	Aplica GPOs.
---
📋 Checklist de Implementação
✅ Concluído
•	Estrutura modular.
•	Automação pós-reboot.
•	Validação de configuração.
•	Logging detalhado.
•	Gerenciamento de estado.
🔧 Pendente
•	Configuração pós-instalação.
•	Suporte a serviços adicionais (DHCP, DFS, etc.).
•	Melhorias na validação.
•	Automação completa.
•	Documentação detalhada.
---
📞 Suporte
Para diagnosticar problemas:
# Verificar logs
Get-Content -Path "C:\PSScript\Logs\ADDeployment_*.log" -Tail 50

# Verificar estado
Get-Content -Path "C:\PSScript\Logs\ADDeployment.state"

Última Atualização: 20/11/2025
Status: Em desenvolvimento
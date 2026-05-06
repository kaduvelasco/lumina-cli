# Lumina CLI

![Bash](https://img.shields.io/badge/Language-Bash-blue)
![Version](https://img.shields.io/badge/Version-2.0.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen)

📄 Versão em português: veja LEIAME.md

CLI modular em Bash para gerenciamento do ecossistema Lumina — ambientes Docker, bancos de dados MariaDB e repositórios Git, integrados em um único ponto de controle.

---

## Sumário

- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Comandos](#comandos)
  - [lumina stack](#lumina-stack)
  - [lumina db](#lumina-db)
  - [lumina git](#lumina-git)
  - [lumina ai](#lumina-ai)
- [Configuração](#configuração)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Autocomplete](#autocomplete)
- [Testes](#testes)
- [Adicionar um novo comando](#adicionar-um-novo-comando)

---

## Pré-requisitos

O lumina-cli é parte de um ecossistema de três projetos:

| Projeto | Finalidade | Necessário para |
|---------|-----------|-----------------|
| **[lumina-stack](https://github.com/kaduvelasco/lumina-stack)** | Cria `~/workspace/docker` com Nginx, MariaDB e PHP | `lumina stack`, `lumina db` |
| **[lumina-dev](https://github.com/kaduvelasco/lumina-dev)** | Instala git, libsecret e ferramentas de desenvolvimento | `lumina git` |
| **lumina-cli** (este repositório) | Interface de controle unificada | — |

Dependências de sistema:

```
bash >= 4.0   docker   docker-compose (V1) ou docker compose (V2)   git
```

O instalador verifica e avisa sobre dependências ausentes.

---

## Instalação

```bash
git clone https://github.com/kaduvelasco/lumina-cli
cd lumina-cli
sudo ./install.sh
```

O instalador:
- Detecta se o lumina já está instalado e, nesse caso, pergunta se deseja atualizar
- Em caso de atualização, remove completamente a versão anterior antes de instalar (sem arquivos órfãos)
- Copia `bin/lumina` para `/usr/local/bin/`
- Instala as bibliotecas em `/usr/local/lib/lumina/`
- Instala os scripts de autocomplete (Bash e Zsh, quando disponíveis)
- Verifica pré-requisitos do ecossistema e avisa sobre o que estiver faltando

---

## Comandos

### lumina stack

Gerencia o ambiente Docker do LuminaStack.

```
lumina stack              Abre o menu interativo
lumina stack start        Inicia o ambiente
lumina stack stop         Finaliza o ambiente (oferece backup antes)
lumina stack logs         Submenu de logs por versão PHP ou Nginx
lumina stack status       Status dos containers e uso de CPU/memória
lumina stack permissions  Corrige permissões em ~/workspace
lumina stack db-info      Exibe host, porta e credenciais do MariaDB
lumina stack --help       Exibe esta ajuda
```

**`lumina stack start`** executa verificações pré-inicialização antes de subir os containers:
- Docker daemon em execução
- Uso de disco abaixo de 85%
- Permissão de escrita no workspace
- Porta 80 livre

**`lumina stack stop`** oferece a opção de executar `lumina db backup` antes de encerrar.

---

### lumina db

Gerencia bancos de dados MariaDB dentro do container.

```
lumina db                    Abre o menu interativo
lumina db backup             Dump completo de todos os bancos para $BACKUP_DIR
lumina db restore            Lista backups disponíveis e importa o selecionado
lumina db remove             Remove bancos individualmente (com confirmação)
lumina db optimize-tables    mariadb-check --optimize em todos os bancos
lumina db optimize-mariadb   Ajusta innodb_buffer_pool_size conforme a RAM do host
lumina db --help             Exibe esta ajuda
```

**Rotação automática de backups:** após cada backup, arquivos excedentes ao limite
`BACKUPS_MANTER` (padrão: 3) são removidos automaticamente do diretório local.

**`optimize-mariadb`** detecta a RAM do sistema e oferece três opções de alocação
(½, ⅓ ou ¼ da RAM) para o `innodb_buffer_pool_size`. A configuração é gravada em
`~/workspace/docker/mariadb/conf.d/moodle-performance.cnf` e o container é reiniciado.

---

### lumina git

Gerencia identidade Git e configurações de repositório.

```
lumina git                    Abre o menu interativo
lumina git configure-global   Configura nome, e-mail e credential helper global
lumina git init               git init -b main e aplica configurações locais
lumina git clone              Clona repositório e aplica configurações locais
lumina git apply-local        Aplica identidade local + gera .gitignore, .aiexclude, .claudeignore e .geminiignore
lumina git --help             Exibe esta ajuda
```

**`apply-local`** (chamado por `init` e `clone`) configura no repositório:
- Identidade local (nome e e-mail independentes da configuração global)
- Credential helper: usa `git-credential-libsecret` se disponível, senão `cache`
- `.gitignore` a partir do template Moodle/PHP incluído
- `.aiexclude`, `.claudeignore` e `.geminiignore` para proteção de dados sensíveis em ferramentas de IA

O credential helper é detectado automaticamente em múltiplos caminhos conhecidos
(Debian/Ubuntu, Fedora, Arch), com fallback para `cache`.

---

### lumina ai

Gerencia arquivos de contexto para assistentes de IA (Claude, Gemini, etc).

```
lumina ai              Abre o menu interativo
lumina ai agents       Gera arquivos de contexto no diretório atual
lumina ai --help       Exibe esta ajuda
```

**`lumina ai agents`** conduz uma pergunta e então gera os arquivos:

**Qual modelo você deseja usar?**

| Opção | Instrução adicionada |
|-------|----------------------|
| Linux Bash | `@instructions/BASH.md` |
| MCP Server | `@instructions/MCP.md` |
| PHP | `@instructions/PHP.md` |
| Moodle | `@instructions/MOODLE.md` |

Para o modelo **Moodle**, o script detecta automaticamente as informações do projeto seguindo esta ordem de prioridade:

1. Lê o arquivo `.moodle-mcp` no diretório atual (contém `MOODLE_PATH`, `MOODLE_VERSION`, `MOODLE_FULLVERSION`)
2. Complementa valores ausentes a partir de `version.php` — versão extraída de `$release` e número de build de `$version`
3. `MOODLE_PATH` assume o diretório atual quando não declarado explicitamente
4. Solicita ao usuário qualquer valor que não possa ser detectado automaticamente

O arquivo `instructions/MOODLE.md` é gerado com os placeholders `{{MOODLE_PATH}}`, `{{MOODLE_VERSION}}` e `{{MOODLE_FULLVERSION}}` substituídos pelos valores reais do projeto.

**Arquivos gerados no diretório atual:**

| Arquivo | Conteúdo |
|---------|----------|
| `CLAUDE.md` | Base + bloco exclusivo Claude (Subagents) + Language-Specific Standards |
| `GEMINI.md` | Base + bloco exclusivo Gemini (Subagents) + Language-Specific Standards |
| `AGENTS.md` | Base + Language-Specific Standards |
| `.windsurfrules` | Idêntico ao AGENTS.md |
| `.cursorrules` | Idêntico ao AGENTS.md |
| `.aiexclude` | Exclusões para ferramentas de IA genéricas |
| `.claudeignore` | Exclusões para Claude |
| `.geminiignore` | Exclusões para Gemini |

Além dos arquivos acima, é criada a pasta `instructions/` com o arquivo de padrões da linguagem selecionada:

| Modelo | Arquivos em `instructions/` |
|--------|------------------------------|
| Linux Bash | `BASH.md` |
| MCP Server | `MCP.md` |
| PHP | `PHP.md` + `php-references/` |
| Moodle | `MOODLE.md` (com versão e path do projeto substituídos) |

---

## Configuração

Na primeira execução, o arquivo `~/.lumina/config.env` é criado automaticamente
com os valores padrão abaixo. Edite-o para ajustar ao seu ambiente:

```bash
# ~/.lumina/config.env

WORKSPACE="$HOME/workspace/docker"      # Diretório raiz do lumina-stack
CONTAINER_NAME="mariadb"                # Nome do container MariaDB
BACKUP_DIR="$HOME/workspace/backups"    # Destino dos backups SQL
BACKUPS_MANTER=3                        # Quantos backups manter localmente
CONF_MOODLE_DIR="$WORKSPACE/mariadb/conf.d"  # Diretório de configuração MariaDB
```

---

## Estrutura do projeto

```
lumina-cli/
├── bin/
│   └── lumina                        # Dispatcher central
├── completions/
│   ├── lumina.bash                   # Autocomplete Bash
│   └── _lumina                       # Autocomplete Zsh
├── guides/
│   └── new-subcommand.md             # Guia para criar novos subcomandos
├── install.sh                        # Instalador (requer sudo)
├── lib/lumina/
│   ├── lib/
│   │   ├── utils.sh                  # Cores, funções de output, detect_pkg_manager
│   │   ├── config.sh                 # Carrega e exporta ~/.lumina/config.env
│   │   └── validators.sh             # require_command, require_container
│   ├── libexec/
│   │   ├── ai.sh                     # Subcomando: lumina ai
│   │   ├── stack.sh                  # Subcomando: lumina stack
│   │   ├── db.sh                     # Subcomando: lumina db
│   │   └── git.sh                    # Subcomando: lumina git
│   └── templates/
│       ├── BASIC.md                  # Base comum para todos os agentes
│       ├── ONLY-CLAUDE.md            # Bloco exclusivo para CLAUDE.md
│       ├── ONLY-GEMINI.md            # Bloco exclusivo para GEMINI.md
│       ├── .gitignore                # Template Moodle/PHP
│       ├── .aiexclude                # Exclusões para ferramentas de IA
│       ├── moodle-performance.cnf    # Template de tuning MariaDB
│       └── instructions/
│           ├── BASH.md               # Padrões Bash/Shell
│           ├── MCP.md                # Padrões MCP Server
│           ├── PHP.md                # Padrões PHP
│           ├── MOODLE.md             # Padrões Moodle Plugin Dev
│           └── php-references/       # Referências PSR
└── tests/
    └── test-runner.sh                # Suíte de testes (45 casos)
```

O dispatcher `bin/lumina` detecta automaticamente qualquer arquivo `.sh` em
`libexec/` e o expõe como subcomando. Para adicionar `lumina foo`, basta criar
`lib/lumina/libexec/foo.sh`.

---

## Autocomplete

**Bash** — ative na sessão atual:
```bash
source /etc/bash_completion.d/lumina
```

Para ativar permanentemente, adicione a linha acima ao seu `~/.bashrc`.

**Zsh** — ative na sessão atual:
```bash
autoload -U compinit && compinit
```

---

## Testes

```bash
bash tests/test-runner.sh
```

A suíte verifica estrutura de arquivos, dependências externas, constantes de cores,
funções de output e carregamento de configuração. Não requer Docker ou MariaDB em
execução.

```
Resultado: 45 aprovados  0 falhos
```

---

## Adicionar um novo comando

Consulte [`guides/new-subcommand.md`](guides/new-subcommand.md) para o guia
completo com template, regras de estilo e exemplo funcional.

O essencial:

1. Crie `lib/lumina/libexec/<comando>.sh` seguindo o template do guia
2. Rode `shellcheck -x lib/lumina/libexec/<comando>.sh` — deve passar sem warnings
3. Rode `bash tests/test-runner.sh` — todos os 45 testes devem continuar passando
4. O novo comando já estará disponível como `lumina <comando>`

---

Made with ❤️ and AI by [Kadu Velasco](https://github.com/kaduvelasco)

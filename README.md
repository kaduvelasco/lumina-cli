# Lumina CLI

![Bash](https://img.shields.io/badge/Language-Bash-blue)
![Version](https://img.shields.io/badge/Version-2.0.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen)

CLI modular em Bash para gerenciamento do ecossistema Lumina — ambientes Docker, bancos de dados MariaDB e repositórios Git, integrados em um único ponto de controle.

---

## Sumário

- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Comandos](#comandos)
  - [lumina stack](#lumina-stack)
  - [lumina db](#lumina-db)
  - [lumina git](#lumina-git)
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
lumina git apply-local        Aplica identidade local + gera .gitignore e .aiexclude
lumina git --help             Exibe esta ajuda
```

**`apply-local`** (chamado por `init` e `clone`) configura no repositório:
- Identidade local (nome e e-mail independentes da configuração global)
- Credential helper: usa `git-credential-libsecret` se disponível, senão `cache`
- `.gitignore` a partir do template Moodle/PHP incluído
- `.aiexclude` para proteção de dados sensíveis em ferramentas de IA

O credential helper é detectado automaticamente em múltiplos caminhos conhecidos
(Debian/Ubuntu, Fedora, Arch), com fallback para `cache`.

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
│   │   ├── stack.sh                  # Subcomando: lumina stack
│   │   ├── db.sh                     # Subcomando: lumina db
│   │   └── git.sh                    # Subcomando: lumina git
│   └── templates/
│       ├── .gitignore                # Template Moodle/PHP
│       ├── .aiexclude                # Exclusões para ferramentas de IA
│       └── moodle-performance.cnf   # Template de tuning MariaDB
└── tests/
    └── test-runner.sh                # Suíte de testes (30 casos)
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
Resultado: 30 aprovados  0 falhos
```

---

## Adicionar um novo comando

Consulte [`guides/new-subcommand.md`](guides/new-subcommand.md) para o guia
completo com template, regras de estilo e exemplo funcional.

O essencial:

1. Crie `lib/lumina/libexec/<comando>.sh` seguindo o template do guia
2. Rode `shellcheck -x lib/lumina/libexec/<comando>.sh` — deve passar sem warnings
3. Rode `bash tests/test-runner.sh` — todos os 30 testes devem continuar passando
4. O novo comando já estará disponível como `lumina <comando>`

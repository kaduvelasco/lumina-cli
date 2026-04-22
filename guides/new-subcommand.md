# Como Criar um Novo Subcomando

Este guia descreve o padrão exato usado nos subcomandos existentes (`db`, `git`, `stack`).
Seguindo-o, o novo comando será detectado automaticamente pelo dispatcher `bin/lumina`
e ficará consistente em comportamento, saída colorida e tratamento de erros.

---

## 1. Criar o arquivo

```
lib/lumina/libexec/<comando>.sh
```

O nome do arquivo define o subcomando. Exemplos:
- `lib/lumina/libexec/moodle.sh` → `lumina moodle`
- `lib/lumina/libexec/deploy.sh` → `lumina deploy`

Não é necessário nenhum registro adicional — o dispatcher detecta o arquivo automaticamente.

---

## 2. Estrutura do arquivo

Cole este template completo e substitua os campos marcados com `< >`:

```bash
#!/usr/bin/env bash
# DESC: <Descrição curta — aparece no lumina --help>
# USAGE: lumina <comando> [<subcomando1>|<subcomando2>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly LIB_DIR="$SCRIPT_DIR/../lib"

if [[ ! -f "$LIB_DIR/utils.sh" ]]; then
    printf '\033[0;31m❌ Erro: lib/utils.sh não encontrado.\033[0m\n' >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$LIB_DIR/utils.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/config.sh"       # Remover se não precisar de WORKSPACE/BACKUP_DIR/etc.
# shellcheck source=/dev/null
source "$LIB_DIR/validators.sh"   # Remover se não precisar de require_command/require_container

trap 'printf "\n"; warn "Operação interrompida."; exit 1' SIGINT SIGTERM

# ==============================================================================
# INTERFACE
# ==============================================================================

show_header() {
    printf '\n%b=====================================%b\n' "$H1" "$NC"
    printf '%b    LUMINA <COMANDO> — <Título>%b\n' "$H1" "$NC"
    printf '%b=====================================%b\n' "$H1" "$NC"
}

show_menu() {
    show_header
    printf '   %b1.%b Primeira ação\n' "$C2" "$NC"
    printf '   %b2.%b Segunda ação\n' "$C2" "$NC"
    printf '   %b0.%b Sair\n' "$C1" "$NC"
    printf '%b=====================================%b\n' "$H2" "$NC"
}

show_help() {
    show_lumina_header
    cat << EOF

lumina <comando> — <Descrição completa>

USO:
  lumina <comando>                Abre o menu interativo
  lumina <comando> <subcomando1>  <Descrição da ação 1>
  lumina <comando> <subcomando2>  <Descrição da ação 2>
EOF
}

# ==============================================================================
# AÇÕES
# ==============================================================================

acao_um() {
    printf "\n"
    info "Executando ação um..."
    # lógica aqui
    success "Ação concluída."
}

acao_dois() {
    printf "\n"
    info "Executando ação dois..."
    # lógica aqui
    success "Ação concluída."
}

# ==============================================================================
# MENU INTERATIVO
# ==============================================================================

_run_menu() {
    while true; do
        show_menu
        read -r -p "Opção: " escolha
        case "$escolha" in
            1) acao_um ;;
            2) acao_dois ;;
            0)
                printf '\n%bAté logo!%b\n\n' "$C2" "$NC"
                exit 0
                ;;
            *)
                warn "Opção inválida."
                sleep 1
                ;;
        esac
    done
}

# ==============================================================================
# PONTO DE ENTRADA
# ==============================================================================

main() {
    carregar_config   # Remover se não usar config.sh

    local cmd="${1:-}"
    case "$cmd" in
        <subcomando1>) acao_um ;;
        <subcomando2>) acao_dois ;;
        -h|--help)     show_help ;;
        "")            _run_menu ;;
        *)             warn "Subcomando desconhecido: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"
```

---

## 3. Regras obrigatórias

### 3.1 Declaração de variáveis readonly (SC2155)

Nunca atribua e declare `readonly` na mesma linha — mascara erros de subshell:

```bash
# ❌ Errado
readonly MINHA_VAR="$(algum_comando)"

# ✅ Correto
MINHA_VAR="$(algum_comando)"
readonly MINHA_VAR
```

### 3.2 Saída colorida com printf (SC2059)

Nunca coloque variáveis de cor diretamente no formato do `printf`:

```bash
# ❌ Errado — variável no formato causa SC2059
printf "${C3}Aviso: %s${NC}\n" "$msg"

# ✅ Correto — usar %b para interpretar escape sequences
printf '%b%s%b\n' "$C3" "$msg" "$NC"
printf '%bAviso: %s%b\n' "$C3" "$msg" "$NC"
```

Use sempre as funções de `utils.sh` para mensagens padrão:

| Função | Cor | Uso |
|--------|-----|-----|
| `success "msg"` | Verde ✅ | Operação concluída |
| `info "msg"` | Azul ℹ️ | Informação neutra |
| `warn "msg"` | Amarelo ⚠️ | Aviso (não fatal) |
| `die "msg"` | Vermelho ❌ | Erro fatal — encerra o script |

### 3.3 Variáveis de cor disponíveis

Declaradas em `utils.sh` e disponíveis após o `source`:

| Variável | Cor | Uso sugerido |
|----------|-----|-------------|
| `$C1` | Vermelho | Erros, opção "Sair" |
| `$C2` | Verde | Opções de menu, sucesso |
| `$C3` | Amarelo | Avisos, destaque de valores |
| `$C4` | Azul | Títulos de seção, info |
| `$C5` | Magenta | Headers de teste, menus |
| `$C6` | Ciano | Dicas, URLs |
| `$H1` | Verde Bold | Títulos principais |
| `$H2` | Verde | Subtítulos |
| `$NC` | Reset | Sempre ao final de um bloco colorido |

### 3.4 Variáveis locais

Todas as variáveis dentro de funções **devem** ser `local`. Variáveis globais
não persistem entre subcomandos (cada `lumina <cmd>` é um processo separado):

```bash
minha_funcao() {
    local resultado
    resultado="$(algum_comando)"
    local outro_valor="texto fixo"
}
```

### 3.5 Source de arquivos dinâmicos

Sempre adicione a diretiva de shellcheck antes de `source` com caminho calculado:

```bash
# shellcheck source=/dev/null
source "$LIB_DIR/utils.sh"
```

### 3.6 Tratamento de interrupção

O trap mínimo abaixo deve estar em todo subcomando com interação do usuário.
Se o comando manipula credenciais ou dados sensíveis, adicione a limpeza no EXIT:

```bash
# Sem dados sensíveis
trap 'printf "\n"; warn "Operação interrompida."; exit 1' SIGINT SIGTERM

# Com dados sensíveis (credenciais, tokens)
trap 'unset MINHA_SENHA MINHA_CHAVE' EXIT
trap 'printf "\n"; warn "Operação interrompida."; exit 1' SIGINT SIGTERM
```

---

## 4. Quando usar cada lib

| Lib | Quando incluir |
|-----|---------------|
| `utils.sh` | **Sempre** — cores, `success/info/warn/die`, `show_lumina_header` |
| `config.sh` | Quando precisar de `$WORKSPACE`, `$BACKUP_DIR`, `$CONTAINER_NAME`, `$BACKUPS_MANTER` |
| `validators.sh` | Quando precisar verificar comandos (`require_command`) ou containers Docker (`require_container`) |

---

## 5. Verificação antes de commitar

```bash
# Rodar shellcheck no novo arquivo
shellcheck -x lib/lumina/libexec/<comando>.sh

# Rodar a suíte de testes (verifica estrutura e dependências)
bash tests/test-runner.sh
```

O shellcheck não deve retornar nenhum warning ou error. Os 30 testes existentes
devem continuar passando — eles verificam estrutura de arquivos, não lógica interna.

---

## 6. Exemplo mínimo funcional

Um subcomando `lumina info` que exibe informações do sistema:

```bash
#!/usr/bin/env bash
# DESC: Exibe informações do sistema e do ambiente Lumina
# USAGE: lumina info [sistema|config]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly LIB_DIR="$SCRIPT_DIR/../lib"

if [[ ! -f "$LIB_DIR/utils.sh" ]]; then
    printf '\033[0;31m❌ Erro: lib/utils.sh não encontrado.\033[0m\n' >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$LIB_DIR/utils.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/config.sh"

trap 'printf "\n"; warn "Operação interrompida."; exit 1' SIGINT SIGTERM

show_help() {
    show_lumina_header
    cat << EOF

lumina info — Informações do sistema e configuração

USO:
  lumina info          Exibe tudo
  lumina info sistema  Informações do SO e Docker
  lumina info config   Configuração atual do Lumina
EOF
}

_info_sistema() {
    printf '\n%bSistema%b\n' "$C4" "$NC"
    printf '   OS     : %b%s%b\n' "$C3" "$(uname -srm)" "$NC"
    printf '   Docker : %b%s%b\n' "$C3" "$(docker --version 2>/dev/null || echo 'não instalado')" "$NC"
    printf '   Git    : %b%s%b\n' "$C3" "$(git --version 2>/dev/null || echo 'não instalado')" "$NC"
}

_info_config() {
    carregar_config
    printf '\n%bConfiguração Lumina%b\n' "$C4" "$NC"
    printf '   WORKSPACE      : %b%s%b\n' "$C3" "$WORKSPACE" "$NC"
    printf '   BACKUP_DIR     : %b%s%b\n' "$C3" "$BACKUP_DIR" "$NC"
    printf '   CONTAINER_NAME : %b%s%b\n' "$C3" "$CONTAINER_NAME" "$NC"
    printf '   BACKUPS_MANTER : %b%s%b\n' "$C3" "$BACKUPS_MANTER" "$NC"
}

main() {
    local cmd="${1:-}"
    case "$cmd" in
        sistema)   _info_sistema ;;
        config)    _info_config ;;
        -h|--help) show_help ;;
        "")        _info_sistema; _info_config ;;
        *)         warn "Subcomando desconhecido: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"
```

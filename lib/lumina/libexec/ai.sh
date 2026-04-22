#!/usr/bin/env bash
# DESC: Gerencia arquivos de contexto para assistentes de IA
# USAGE: lumina ai [agents]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly LIB_DIR="$SCRIPT_DIR/../lib"
readonly TEMPLATES_DIR="$SCRIPT_DIR/../templates"

if [[ ! -f "$LIB_DIR/utils.sh" ]]; then
    printf '\033[0;31m❌ Erro: lib/utils.sh não encontrado.\033[0m\n' >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$LIB_DIR/utils.sh"

trap 'printf "\n"; warn "Operação interrompida."; exit 1' SIGINT SIGTERM

# ==============================================================================
# INTERFACE
# ==============================================================================

show_header() {
    show_lumina_header "LUMINA AI — Context Manager"
}

show_menu() {
    show_header
    printf '   %b1.%b Gerar arquivos de agentes (CLAUDE.md / GEMINI.md / AGENTS.md)\n' "$C2" "$NC"
    printf '   %b0.%b Sair\n' "$C1" "$NC"
    printf '%b=====================================%b\n\n' "$H2" "$NC"
}

show_help() {
    show_lumina_header "LUMINA AI — Context Manager"
    cat << EOF
lumina ai — Gerenciador de contexto para assistentes de IA

USO:
  lumina ai              Abre o menu interativo
  lumina ai agents       Gera CLAUDE.md, GEMINI.md e AGENTS.md no diretório atual

TIPOS DE PROJETO:
  1. Básico      — Diretrizes gerais para qualquer projeto
  2. MCP         — Básico + instruções para Model Context Protocol
  3. BASH/Shell  — Básico + diretrizes para scripts Bash/Shell
EOF
}

# ==============================================================================
# FUNÇÕES AUXILIARES
# ==============================================================================

_ler_template() {
    local file="$TEMPLATES_DIR/$1"
    if [[ ! -f "$file" ]]; then
        die "Template não encontrado: $file"
    fi
    cat "$file"
}

_confirmar_sobrescrita() {
    local arquivo="$1"
    if [[ -f "$arquivo" ]]; then
        warn "O arquivo '$arquivo' já existe neste diretório."
        read -r -p "   Deseja sobrescrever? [s/N]: " confirm
        [[ "$confirm" =~ ^[sS]$ ]] || return 1
    fi
    return 0
}

_gravar_arquivos_ai() {
    local conteudo="$1"
    local arquivos=("CLAUDE.md" "GEMINI.md" "AGENTS.md")
    local gravados=0
    local ignorados=0

    printf "\n"
    for arquivo in "${arquivos[@]}"; do
        if _confirmar_sobrescrita "$arquivo"; then
            printf '%s\n' "$conteudo" > "$arquivo"
            success "$arquivo criado."
            (( gravados++ )) || true
        else
            info "$arquivo mantido sem alterações."
            (( ignorados++ )) || true
        fi
    done

    printf "\n"
    [[ "$gravados" -gt 0 ]] && success "$gravados arquivo(s) gerado(s) em $(pwd)."
    [[ "$ignorados" -gt 0 ]] && info "$ignorados arquivo(s) ignorado(s)."
}

# ==============================================================================
# AÇÃO: agents
# ==============================================================================

criar_agents() {
    show_lumina_header "LUMINA AI — Gerar Arquivos de Agentes"

    printf '%b📁 Diretório atual: %b%s%b\n\n' "$C4" "$C3" "$(pwd)" "$NC"
    printf '%bQual o tipo de projeto?%b\n\n' "$C4" "$NC"
    printf '   %b1.%b Básico\n' "$C2" "$NC"
    printf '   %b2.%b MCP\n' "$C2" "$NC"
    printf '   %b3.%b BASH/Shell\n' "$C2" "$NC"
    printf '\n'
    read -r -p "   Opção [1-3]: " tipo

    local conteudo
    case "$tipo" in
        1)
            info "Gerando arquivos para projeto Básico..."
            conteudo=$(_ler_template "BASIC.md")
            ;;
        2)
            info "Gerando arquivos para projeto MCP..."
            conteudo=$(_ler_template "BASIC.md")
            conteudo+=$'\n'"$(_ler_template "MCP.md")"
            ;;
        3)
            info "Gerando arquivos para projeto BASH/Shell..."
            conteudo=$(_ler_template "BASIC.md")
            conteudo+=$'\n'"$(_ler_template "SHELL.md")"
            ;;
        *)
            warn "Opção inválida."
            return 1
            ;;
    esac

    _gravar_arquivos_ai "$conteudo"
}

# ==============================================================================
# MENU INTERATIVO
# ==============================================================================

_run_menu() {
    while true; do
        show_menu
        read -r -p "Opção: " escolha
        case "$escolha" in
            1) criar_agents ;;
            0)
                printf '\n%bAté logo!%b\n\n' "$C2" "$NC"
                exit 0
                ;;
            *)
                warn "Opção inválida. Digite 1 ou 0."
                sleep 1
                ;;
        esac
    done
}

# ==============================================================================
# PONTO DE ENTRADA
# ==============================================================================

main() {
    local cmd="${1:-}"
    case "$cmd" in
        agents)    criar_agents ;;
        -h|--help) show_help ;;
        "")        _run_menu ;;
        *)         warn "Subcomando desconhecido: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"

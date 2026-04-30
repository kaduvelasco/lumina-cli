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
  lumina ai agents       Gera CLAUDE.md, GEMINI.md, AGENTS.md, .windsurfrules e .cursorrules

MODELOS DISPONÍVEIS:
  1. Linux Bash   — Diretrizes para scripts Bash/Shell
  2. MCP Server   — Diretrizes para Model Context Protocol
  3. PHP          — Diretrizes para desenvolvimento PHP
  4. Moodle       — Diretrizes para desenvolvimento de plugins Moodle
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
    cat -- "$file"
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
    # $1 = conteudo para CLAUDE.md
    # $2 = conteudo para GEMINI.md
    # $3 = conteudo para AGENTS.md, .windsurfrules, .cursorrules
    local conteudo_claude="$1"
    local conteudo_gemini="$2"
    local conteudo_padrao="$3"
    local gravados=0
    local ignorados=0

    printf "\n"

    local arquivo conteudo
    for arquivo in "CLAUDE.md" "GEMINI.md" "AGENTS.md" ".windsurfrules" ".cursorrules"; do
        case "$arquivo" in
            CLAUDE.md)  conteudo="$conteudo_claude" ;;
            GEMINI.md)  conteudo="$conteudo_gemini" ;;
            *)          conteudo="$conteudo_padrao" ;;
        esac

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
    [[ "$gravados" -gt 0 ]] && success "$gravados arquivo(s) gerado(s) em $(pwd)." || true
    [[ "$ignorados" -gt 0 ]] && info "$ignorados arquivo(s) ignorado(s)." || true
}

_gerar_graphignore() {
    local arquivo=".code-review-graphignore"
    local src="$TEMPLATES_DIR/code-review-graphignore"

    if [[ ! -f "$src" ]]; then
        warn "Template não encontrado: $src"
        return 1
    fi

    if _confirmar_sobrescrita "$arquivo"; then
        cp -- "$src" "$arquivo"
        success "$arquivo criado."
    else
        info "$arquivo mantido sem alterações."
    fi
}

_ler_moodle_info() {
    local mcp_file=".moodle-mcp"
    local version_file="version.php"

    MOODLE_PATH="" MOODLE_VERSION="" MOODLE_FULLVERSION=""

    # 1. Tenta ler do .moodle-mcp
    if [[ -f "$mcp_file" ]]; then
        info "Lendo $mcp_file..."
        MOODLE_PATH=$(grep '^MOODLE_PATH=' "$mcp_file" | cut -d'=' -f2- || true)
        MOODLE_VERSION=$(grep '^MOODLE_VERSION=' "$mcp_file" | cut -d'=' -f2- || true)
        MOODLE_FULLVERSION=$(grep '^MOODLE_FULLVERSION=' "$mcp_file" | cut -d'=' -f2- || true)
    fi

    # 2. Complementa com version.php
    if [[ -z "$MOODLE_PATH" ]]; then
        MOODLE_PATH="$(pwd)"
    fi

    if [[ -f "$version_file" ]]; then
        if [[ -z "$MOODLE_VERSION" ]]; then
            MOODLE_VERSION=$(grep '^\$release' "$version_file" \
                | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
        fi
        if [[ -z "$MOODLE_FULLVERSION" ]]; then
            MOODLE_FULLVERSION=$(grep '^\$version' "$version_file" \
                | grep -oE '[0-9]{8,}' | head -1 || true)
        fi
    fi

    # 3. Solicita valores faltantes ao usuário
    if [[ -z "$MOODLE_PATH" ]]; then
        read -r -p "   Caminho do Moodle (MOODLE_PATH): " MOODLE_PATH
    fi
    if [[ -z "$MOODLE_VERSION" ]]; then
        read -r -p "   Versão do Moodle (ex: 4.1.22): " MOODLE_VERSION
    fi
    if [[ -z "$MOODLE_FULLVERSION" ]]; then
        read -r -p "   Versão completa do Moodle (ex: 2022112822): " MOODLE_FULLVERSION
    fi

    if [[ -z "$MOODLE_PATH" || -z "$MOODLE_VERSION" || -z "$MOODLE_FULLVERSION" ]]; then
        die "Informações do Moodle incompletas. Verifique .moodle-mcp ou version.php."
    fi

    success "Moodle $MOODLE_VERSION detectado."
    printf '   %b📁 Path: %b%s%b\n' "$C4" "$C3" "$MOODLE_PATH" "$NC"
}

_copiar_instructions() {
    local modelo="$1"
    local dest_dir
    dest_dir="$(pwd)/instructions"

    mkdir -p -- "$dest_dir"

    case "$modelo" in
        1)
            if _confirmar_sobrescrita "$dest_dir/BASH.md"; then
                cp -- "$TEMPLATES_DIR/instructions/BASH.md" "$dest_dir/BASH.md"
                success "instructions/BASH.md copiado."
            else
                info "instructions/BASH.md mantido sem alterações."
            fi
            ;;
        2)
            if _confirmar_sobrescrita "$dest_dir/MCP.md"; then
                cp -- "$TEMPLATES_DIR/instructions/MCP.md" "$dest_dir/MCP.md"
                success "instructions/MCP.md copiado."
            else
                info "instructions/MCP.md mantido sem alterações."
            fi
            ;;
        3)
            if _confirmar_sobrescrita "$dest_dir/PHP.md"; then
                cp -- "$TEMPLATES_DIR/instructions/PHP.md" "$dest_dir/PHP.md"
                success "instructions/PHP.md copiado."
            else
                info "instructions/PHP.md mantido sem alterações."
            fi
            if [[ -d "$TEMPLATES_DIR/instructions/php-references" ]]; then
                cp -r -- "$TEMPLATES_DIR/instructions/php-references" "$dest_dir/"
                success "instructions/php-references/ copiado."
            fi
            ;;
        4)
            local _p='{{MOODLE_PATH}}'
            local _v='{{MOODLE_VERSION}}'
            local _fv='{{MOODLE_FULLVERSION}}'
            local moodle_tmpl
            moodle_tmpl=$(_ler_template "instructions/MOODLE.md")
            moodle_tmpl="${moodle_tmpl//$_p/$MOODLE_PATH}"
            moodle_tmpl="${moodle_tmpl//$_v/$MOODLE_VERSION}"
            moodle_tmpl="${moodle_tmpl//$_fv/$MOODLE_FULLVERSION}"
            if _confirmar_sobrescrita "$dest_dir/MOODLE.md"; then
                printf '%s\n' "$moodle_tmpl" > "$dest_dir/MOODLE.md"
                success "instructions/MOODLE.md criado."
            else
                info "instructions/MOODLE.md mantido sem alterações."
            fi
            ;;
    esac
}

# ==============================================================================
# AÇÃO: agents
# ==============================================================================

criar_agents() {
    show_lumina_header "LUMINA AI — Gerar Arquivos de Agentes"

    printf '%b📁 Diretório atual: %b%s%b\n\n' "$C4" "$C3" "$(pwd)" "$NC"

    # --- Pergunta 1: modelo ---
    printf '%bQual modelo você deseja usar?%b\n\n' "$C4" "$NC"
    printf '   %b1.%b Linux Bash\n' "$C2" "$NC"
    printf '   %b2.%b MCP Server\n' "$C2" "$NC"
    printf '   %b3.%b PHP\n' "$C2" "$NC"
    printf '   %b4.%b Moodle\n' "$C2" "$NC"
    printf '\n'
    local modelo
    read -r -p "   Opção [1-4]: " modelo

    case "$modelo" in
        1) info "Modelo selecionado: Linux Bash" ;;
        2) info "Modelo selecionado: MCP Server" ;;
        3) info "Modelo selecionado: PHP" ;;
        4)
            info "Modelo selecionado: Moodle"
            printf '\n'
            _ler_moodle_info
            ;;
        *) warn "Opção inválida."; return 1 ;;
    esac

    # --- Pergunta 2: Code Review Graph ---
    printf '\n%bDeseja incluir instruções do Code Review Graph?%b\n\n' "$C4" "$NC"
    printf '   %b1.%b Sim\n' "$C2" "$NC"
    printf '   %b2.%b Não\n' "$C2" "$NC"
    printf '\n'
    local use_graph
    read -r -p "   Opção [1-2]: " use_graph

    case "$use_graph" in
        1) info "Code Review Graph: incluído" ;;
        2) info "Code Review Graph: não incluído" ;;
        *) warn "Opção inválida."; return 1 ;;
    esac

    # --- Montar conteúdo ---
    local conteudo_base conteudo_sufixo
    conteudo_base=$(_ler_template "BASIC.md")

    conteudo_sufixo=$'\n\n## Language-Specific Standards\n\n'
    case "$modelo" in
        1) conteudo_sufixo+='@instructions/BASH.md' ;;
        2) conteudo_sufixo+='@instructions/MCP.md' ;;
        3) conteudo_sufixo+='@instructions/PHP.md' ;;
        4) conteudo_sufixo+='@instructions/MOODLE.md' ;;
    esac

    if [[ "$use_graph" == "1" ]]; then
        conteudo_sufixo+=$'\n\n'"$(_ler_template "CODE-REVIEW-GRAPH.md")"
    fi

    local conteudo_claude conteudo_gemini conteudo_padrao
    conteudo_claude="${conteudo_base}"$'\n\n'"$(_ler_template "ONLY-CLAUDE.md")${conteudo_sufixo}"
    conteudo_gemini="${conteudo_base}"$'\n\n'"$(_ler_template "ONLY-GEMINI.md")${conteudo_sufixo}"
    conteudo_padrao="${conteudo_base}${conteudo_sufixo}"

    # --- Gravar arquivos ---
    _gravar_arquivos_ai "$conteudo_claude" "$conteudo_gemini" "$conteudo_padrao"

    [[ "$use_graph" == "1" ]] && _gerar_graphignore || true

    # --- Copiar instruções ---
    _copiar_instructions "$modelo"
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

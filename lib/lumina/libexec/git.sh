#!/usr/bin/env bash
# DESC: Gerencia identidade Git, repositórios, .gitignore e .aiexclude
# USAGE: lumina git [init|clone|configure-global|apply-local]

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
# shellcheck source=/dev/null
source "$LIB_DIR/validators.sh"

# Caminhos conhecidos do git-credential-libsecret por distro
readonly -a _LIBSECRET_PATHS=(
    "/usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret"
    "/usr/lib/git-core/git-credential-libsecret"
    "/usr/libexec/git-core/git-credential-libsecret"
    "/usr/lib/git/git-credential-libsecret"
)

# ==============================================================================
# INTERFACE
# ==============================================================================

show_header() {
    show_lumina_header "LUMINA GIT — Git Manager"
    printf '   %b📁 Pasta : %b%s%b\n' "$C4" "$C3" "$(pwd)" "$NC"
    local global_user
    global_user=$(git config --global user.name 2>/dev/null || echo "não definido")
    printf '   %b👤 Usuário: %b%s%b\n\n' "$C4" "$C3" "$global_user" "$NC"
}

show_menu() {
    show_header
    printf '   %b1.%b Configurar identidade GLOBAL\n' "$C2" "$NC"
    printf '   %b2.%b Iniciar NOVO repositório aqui\n' "$C2" "$NC"
    printf '   %b3.%b Clonar repositório e configurar\n' "$C2" "$NC"
    printf '   %b4.%b Aplicar identidade neste repo\n' "$C2" "$NC"
    printf '   %b0.%b Sair\n' "$C1" "$NC"
    printf '%b=====================================%b\n' "$H2" "$NC"
}

show_help() {
    show_lumina_header "LUMINA GIT — Git Manager"
    cat << EOF

lumina git — Gerenciador de identidade Git e repositórios

USO:
  lumina git                    Abre o menu interativo
  lumina git configure-global   Configura identidade e credencial global
  lumina git init               Inicia novo repositório e aplica configurações
  lumina git clone              Clona repositório e aplica configurações locais
  lumina git apply-local        Aplica identidade no repositório atual
EOF
}

# ==============================================================================
# FUNÇÕES AUXILIARES
# ==============================================================================

_resolve_credential_helper() {
    for p in "${_LIBSECRET_PATHS[@]}"; do
        if [[ -x "$p" ]]; then
            echo "$p"
            return 0
        fi
    done
    if command -v git-credential-libsecret >/dev/null 2>&1; then
        echo "libsecret"
        return 0
    fi
    echo "cache"
}

# ==============================================================================
# GERAÇÃO DE ARQUIVOS DE PROJETO
# ==============================================================================

_create_gitignore() {
    if [[ -f ".gitignore" ]]; then
        warn ".gitignore já existe neste diretório."
        read -r -p "   Deseja sobrescrever? [s/N]: " confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            info ".gitignore mantido sem alterações."
            return 0
        fi
    fi

    info "Gerando .gitignore (Moodle/Web)..."

    if [[ -f "$TEMPLATES_DIR/.gitignore" ]]; then
        cp "$TEMPLATES_DIR/.gitignore" .gitignore
    else
        warn "Template não encontrado. Gerando versão mínima."
        cat > .gitignore << 'EOF'
.DS_Store
node_modules/
vendor/
/dist/
/build/
.env
.env.*
*.log
/moodledata/
/config.php
EOF
    fi

    success ".gitignore criado."
}

_create_aiexclude() {
    if [[ -f ".aiexclude" ]]; then
        warn ".aiexclude já existe neste diretório."
        read -r -p "   Deseja sobrescrever? [s/N]: " confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            info ".aiexclude mantido sem alterações."
            return 0
        fi
    fi

    info "Gerando .aiexclude (Segurança e Performance IA)..."

    if [[ -f "$TEMPLATES_DIR/.aiexclude" ]]; then
        cp "$TEMPLATES_DIR/.aiexclude" .aiexclude
    else
        warn "Template não encontrado. Gerando versão mínima."
        cat > .aiexclude << 'EOF'
.env
.env.*
*.pem
*.key
/moodledata/
/vendor/
/node_modules/
/.git/
*.log
*.jpg
*.jpeg
*.png
*.gif
EOF
    fi

    success ".aiexclude criado com bloqueio de segurança e mídia."
}

# ==============================================================================
# AÇÕES
# ==============================================================================

apply_local_configs() {
    if [[ ! -d ".git" ]]; then
        die "Esta pasta não é um repositório Git."
    fi

    info "Configurando identidade local do repositório..."

    local current_user current_email
    current_user=$(git config --local user.name 2>/dev/null || echo "não definido")
    current_email=$(git config --local user.email 2>/dev/null || echo "não definido")
    printf '   Identidade atual: %b%s <%s>%b\n' "$C3" "$current_user" "$current_email" "$NC"

    local default_user default_email
    default_user=$(git config --global user.name 2>/dev/null || echo "")
    default_email=$(git config --global user.email 2>/dev/null || echo "")

    read -r -p "   Usuário para este repo [${default_user}]: " user_name
    user_name="${user_name:-$default_user}"

    read -r -p "   E-mail para este repo [${default_email}]: " user_email
    user_email="${user_email:-$default_email}"

    if [[ -z "$user_name" || -z "$user_email" ]]; then
        die "Nome e e-mail não podem ser vazios."
    fi

    _create_gitignore
    _create_aiexclude

    local cred_helper
    cred_helper=$(_resolve_credential_helper)

    git config --local user.name "$user_name"
    git config --local user.email "$user_email"
    git config --local credential.helper "$cred_helper"
    git config --local "credential.https://github.com.username" "$user_name"

    success "Identidade e proteções de IA aplicadas!"
    printf '   👤 %b%s%b | 📧 %b%s%b\n' "$C3" "$user_name" "$NC" "$C3" "$user_email" "$NC"
}

configure_global() {
    info "Configuração Global de Identidade Git"

    local current_user current_email
    current_user=$(git config --global user.name 2>/dev/null || echo "não definido")
    current_email=$(git config --global user.email 2>/dev/null || echo "não definido")
    printf '   Configuração atual: %b%s <%s>%b\n' "$C3" "$current_user" "$current_email" "$NC"

    read -r -p "   Nome global: " g_user
    read -r -p "   E-mail global: " g_email

    if [[ -z "$g_user" || -z "$g_email" ]]; then
        die "Nome e e-mail não podem ser vazios."
    fi

    local cred_helper
    cred_helper=$(_resolve_credential_helper)

    git config --global user.name "$g_user"
    git config --global user.email "$g_email"
    git config --global credential.helper "$cred_helper"

    printf '   %b📌 DICA: Use seu Token (PAT) como senha no primeiro push.%b\n' "$C3" "$NC"
    success "Configuração global atualizada: ${g_user} <${g_email}>"
}

init_repo() {
    if [[ -d ".git" ]]; then
        warn "Esta pasta já é um repositório Git."
        read -r -p "   Deseja reinicializar e reaplicar as configurações? [s/N]: " confirm
        [[ ! "$confirm" =~ ^[sS]$ ]] && return 0
    fi

    info "Iniciando novo repositório Git..."
    git init -b main
    apply_local_configs
}

clone_repo() {
    read -r -p "   URL do repositório: " repo_url

    if [[ -z "$repo_url" ]]; then
        die "URL não pode ser vazia."
    fi

    read -r -p "   Nome da pasta (Enter para usar o padrão): " repo_dir

    if git clone "$repo_url" ${repo_dir:+"$repo_dir"}; then
        local target_dir="${repo_dir:-$(basename "$repo_url" .git)}"
        if [[ -d "$target_dir" ]]; then
            info "Aplicando configurações no repositório clonado..."
            (cd "$target_dir" && apply_local_configs)
        fi
    else
        die "Falha ao clonar. Verifique a URL e sua conexão."
    fi
}

# ==============================================================================
# MENU INTERATIVO
# ==============================================================================

_run_menu() {
    while true; do
        show_menu
        read -r -p "   Escolha uma opção: " opcao

        case "$opcao" in
            1)
                configure_global
                printf '%b──────────────────────────────────%b\n' "$C4" "$NC"
                read -r -p "   Pressione Enter para voltar ao menu..."
                ;;
            2)
                init_repo
                printf '%b──────────────────────────────────%b\n' "$C4" "$NC"
                read -r -p "   Pressione Enter para voltar ao menu..."
                ;;
            3)
                clone_repo
                printf '%b──────────────────────────────────%b\n' "$C4" "$NC"
                read -r -p "   Pressione Enter para voltar ao menu..."
                ;;
            4)
                apply_local_configs
                printf '%b──────────────────────────────────%b\n' "$C4" "$NC"
                read -r -p "   Pressione Enter para voltar ao menu..."
                ;;
            0)
                printf '\n%bAté logo!%b\n\n' "$C2" "$NC"
                exit 0
                ;;
            *)
                warn "Opção inválida. Digite um número de 0 a 4."
                sleep 1
                ;;
        esac
    done
}

# ==============================================================================
# PONTO DE ENTRADA
# ==============================================================================

main() {
    trap 'printf "\n"; warn "Operação interrompida."; exit 1' SIGINT SIGTERM
    require_command "git"

    local cmd="${1:-}"
    case "$cmd" in
        configure-global) configure_global ;;
        init)             init_repo ;;
        clone)            clone_repo ;;
        apply-local)      apply_local_configs ;;
        -h|--help)        show_help ;;
        "")               _run_menu ;;
        *)                warn "Subcomando desconhecido: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"

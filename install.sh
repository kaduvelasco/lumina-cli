#!/usr/bin/env bash
# =============================================================================
# Nome do Script : install.sh
# Versão         : 2.0.0
# =============================================================================

set -euo pipefail

readonly INSTALL_DIR="/usr/local/bin"
readonly COMPLETIONS_BASH_DIR="/etc/bash_completion.d"
readonly COMPLETIONS_ZSH_DIR="/usr/local/share/zsh/site-functions"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/lumina/lib/utils.sh"

_verificar_root() {
    if [[ $EUID -ne 0 ]]; then
        die "Este instalador requer sudo. Execute: sudo ./install.sh"
    fi
}

_ja_instalado() {
    [[ -f "$INSTALL_DIR/lumina" ]]
}

_remover_instalacao() {
    info "Removendo instalação anterior..."
    rm -f  -- "$INSTALL_DIR/lumina"
    rm -rf -- "/usr/local/lib/lumina"
    rm -f  -- "$COMPLETIONS_BASH_DIR/lumina"
    rm -f  -- "$COMPLETIONS_ZSH_DIR/_lumina"
    success "Instalação anterior removida."
}

_verificar_atualizacao() {
    if ! _ja_instalado; then
        return 0
    fi

    warn "Lumina já está instalado."
    printf '%b' "   Deseja atualizar? (${C3}s${RESET}/N): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        printf '\n%bOperação cancelada.%b\n\n' "$C3" "$NC"
        exit 0
    fi

    _remover_instalacao
}

_instalar_binario() {
    info "Instalando lumina em $INSTALL_DIR..."
    install -m 755 "$SCRIPT_DIR/bin/lumina" "$INSTALL_DIR/lumina"
    success "lumina instalado em $INSTALL_DIR/lumina"
}

_instalar_biblioteca() {
    local LIB_DEST="/usr/local/lib/lumina"
    info "Instalando bibliotecas em $LIB_DEST..."
    mkdir -p "$LIB_DEST"
    cp -r "$SCRIPT_DIR/lib/lumina/"* "$LIB_DEST/"
    chmod -R 755 "$LIB_DEST"
    success "Bibliotecas instaladas."
}

_instalar_completions() {
    local BASH_COMP="$SCRIPT_DIR/completions/lumina.bash"
    local ZSH_COMP="$SCRIPT_DIR/completions/_lumina"

    if [[ -f "$BASH_COMP" && -d "$COMPLETIONS_BASH_DIR" ]]; then
        install -m 644 "$BASH_COMP" "$COMPLETIONS_BASH_DIR/lumina"
        success "Autocomplete Bash instalado."
    fi

    if [[ -f "$ZSH_COMP" && -d "$COMPLETIONS_ZSH_DIR" ]]; then
        install -m 644 "$ZSH_COMP" "$COMPLETIONS_ZSH_DIR/_lumina"
        success "Autocomplete Zsh instalado."
    fi
}

_verificar_dependencias() {
    local missing=0
    for cmd in docker git; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            warn "Dependência não encontrada: $cmd"
            (( missing++ )) || true
        fi
    done
    if [[ "$missing" -gt 0 ]]; then
        warn "$missing dependência(s) ausente(s). Instale-as antes de usar o lumina."
    fi
}

_verificar_prerequisitos() {
    # sudo muda $HOME para /root — resolver o home do usuário real
    local real_home="$HOME"
    if [[ -n "${SUDO_USER:-}" ]]; then
        real_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    fi

    local config_file="$real_home/.lumina/config.env"

    printf '\n'
    info "Verificando pré-requisitos do ecossistema Lumina..."

    # lumina-stack — config e workspace
    local workspace=""
    if [[ ! -f "$config_file" ]]; then
        warn "Configuração não encontrada: $config_file não existe."
        printf "   %b→ 'lumina stack' e 'lumina db' não funcionarão sem o lumina-stack.%b\n" "$C3" "$NC"
        printf '   %b  Instale em: https://github.com/kaduvelasco/lumina-stack%b\n' "$C6" "$NC"
    else
        workspace=$(grep -m1 '^WORKSPACE=' "$config_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        workspace="${workspace/#\~/$real_home}"
        if [[ ! -d "$workspace" ]]; then
            warn "lumina-stack não detectado: $workspace não existe."
            printf "   %b→ 'lumina stack' e 'lumina db' não funcionarão sem o lumina-stack.%b\n" "$C3" "$NC"
            printf '   %b  Instale em: https://github.com/kaduvelasco/lumina-stack%b\n' "$C6" "$NC"
            workspace=""
        else
            success "lumina-stack detectado: $workspace encontrado."
        fi
    fi

    # lumina-stack — arquivo .env com credenciais (apenas se o workspace foi encontrado)
    if [[ -n "$workspace" && ! -f "$workspace/.env" ]]; then
        warn "Arquivo .env não encontrado em $workspace."
        printf "   %b→ 'lumina stack db-info' não conseguirá ler as credenciais.%b\n" "$C3" "$NC"
    fi

    # lumina-dev — git
    if ! command -v git >/dev/null 2>&1; then
        warn "git não encontrado."
        printf "   %b→ 'lumina git' não funcionará sem o lumina-dev.%b\n" "$C3" "$NC"
        printf '   %b  Instale em: https://github.com/kaduvelasco/lumina-dev%b\n' "$C6" "$NC"
    else
        success "git detectado: $(git --version)"
    fi

    # lumina-dev — libsecret (opcional, degradação silenciosa)
    if [[ ! -f "/usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret" ]]; then
        warn "libsecret não encontrado. Credenciais Git usarão modo 'cache' em vez de keyring."
        printf '   %b  Instale o lumina-dev para habilitar o armazenamento seguro de credenciais.%b\n' "$C6" "$NC"
    fi
}

_mostrar_instrucoes_pos_install() {
    printf '\n'
    info "Para ativar o autocomplete nesta sessão:"
    printf '   Bash: source /etc/bash_completion.d/lumina\n'
    printf '   Zsh:  autoload -U compinit && compinit\n'
    printf '\n'
    success "Instalação concluída! Execute: lumina --help"
}

main() {
    show_lumina_header
    _verificar_root
    _verificar_atualizacao
    _instalar_binario
    _instalar_biblioteca
    _instalar_completions
    _verificar_dependencias
    _verificar_prerequisitos
    _mostrar_instrucoes_pos_install
}

main "$@"

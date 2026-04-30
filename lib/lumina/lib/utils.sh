#!/usr/bin/env bash
# Cores
readonly C1='\033[0;31m'    # Erro
readonly C2='\033[0;32m'    # Sucesso
readonly C3='\033[0;33m'    # Aviso
readonly C4='\033[38;5;246m' # Info
readonly NC='\033[0m'       # No Color
# shellcheck disable=SC2034
readonly RESET='\033[0m'    # Reset
# shellcheck disable=SC2034
readonly H1='\033[0m'        # Título primário (cor padrão do terminal)
# shellcheck disable=SC2034
readonly H2='\033[0m'        # Título secundário (cor padrão do terminal)

success() { printf '%b✅ %s%b\n' "$C2" "$1" "$NC"; }
info()    { printf '%bℹ️  %s%b\n' "$C4" "$1" "$NC"; }
warn()    { printf '%b⚠️  %s%b\n' "$C3" "$1" "$NC" >&2; }
die()     { printf '%b❌ ERRO: %s%b\n' "$C1" "$1" "$NC" >&2; exit 1; }

show_lumina_header() {
    local subtitle="${1:-LUMINA CLI ENGINE}"
    clear
    printf '%b\n' ""
    printf '%b\n' "░██                            ░██                      "
    printf '%b\n' "░██                                                     "
    printf '%b\n' "░██ ░██    ░██ ░█████████████  ░██░████████   ░██████   "
    printf '%b\n' "░██ ░██    ░██ ░██   ░██   ░██ ░██░██    ░██       ░██  "
    printf '%b\n' "░██ ░██    ░██ ░██   ░██   ░██ ░██░██    ░██  ░███████  "
    printf '%b\n' "░██ ░██   ░███ ░██   ░██   ░██ ░██░██    ░██ ░██   ░██  "
    printf '%b\n' "░██  ░█████░██ ░██   ░██   ░██ ░██░██    ░██  ░█████░██ "
    printf '%b\n' ""
    printf '%b\n' "${H2}${subtitle}${RESET} "
    printf '%b\n' ""
}

# Detecta o gerenciador de pacotes disponível no sistema.
# Imprime o nome (apt|dnf|pacman) em stdout; retorna 1 se nenhum for encontrado.
detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        return 1
    fi
}

# Instala um pacote se ele ainda não estiver disponível.
# Uso: ensure_pkg <pacote> [<comando>]
#   <pacote>   — nome do pacote a instalar
#   <comando>  — comando a verificar (padrão: igual ao pacote)
ensure_pkg() {
    local pkg="$1"
    local cmd="${2:-$1}"

    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi

    local mgr
    if ! mgr=$(detect_pkg_manager); then
        die "Nenhum gerenciador de pacotes suportado encontrado (apt, dnf, pacman)."
    fi

    info "Instalando $pkg via $mgr..."
    case "$mgr" in
        apt)    sudo apt-get install -y "$pkg" ;;
        dnf)    sudo dnf install -y "$pkg" ;;
        pacman) sudo pacman -S --noconfirm "$pkg" ;;
    esac
}

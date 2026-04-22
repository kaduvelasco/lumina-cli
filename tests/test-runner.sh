#!/usr/bin/env bash
# =============================================================================
# Nome do Script : tests/test-runner.sh
# Versão         : 2.0.0
# =============================================================================

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TESTS_DIR
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
readonly ROOT_DIR
readonly LIB_DIR="$ROOT_DIR/lib/lumina/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/utils.sh"

# --- framework mínimo de testes ---

_PASS=0
_FAIL=0

assert_equals() {
    local description="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf '%b  PASS%b  %s\n' "$C2" "$NC" "$description"
        (( _PASS++ )) || true
    else
        printf '%b  FAIL%b  %s\n' "$C1" "$NC" "$description"
        printf "         esperado: '%s'\n" "$expected"
        printf "         obtido:   '%s'\n" "$actual"
        (( _FAIL++ )) || true
    fi
}

assert_file_exists() {
    local description="$1" path="$2"
    if [[ -f "$path" ]]; then
        printf '%b  PASS%b  %s\n' "$C2" "$NC" "$description"
        (( _PASS++ )) || true
    else
        printf '%b  FAIL%b  %s\n' "$C1" "$NC" "$description"
        printf "         arquivo não encontrado: '%s'\n" "$path"
        (( _FAIL++ )) || true
    fi
}

assert_command_exists() {
    local description="$1" cmd="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '%b  PASS%b  %s\n' "$C2" "$NC" "$description"
        (( _PASS++ )) || true
    else
        printf '%b  FAIL%b  %s\n' "$C1" "$NC" "$description"
        printf "         comando não encontrado: '%s'\n" "$cmd"
        (( _FAIL++ )) || true
    fi
}

# --- suítes de testes ---

test_utils_cores() {
    printf '\n%b[utils.sh] Constantes de cores%b\n' "$C5" "$NC"
    assert_equals "C1 definido" '\033[0;31m' "$C1"
    assert_equals "C2 definido" '\033[0;32m' "$C2"
    assert_equals "C3 definido" '\033[0;33m' "$C3"
    assert_equals "C4 definido" '\033[0;34m' "$C4"
    assert_equals "C5 definido" '\033[0;35m' "$C5"
    assert_equals "C6 definido" '\033[0;36m' "$C6"
    assert_equals "H1 definido" '\033[1;32m' "$H1"
    assert_equals "H2 definido" '\033[0;32m' "$H2"
}

test_utils_pkg_manager() {
    printf '\n%b[utils.sh] detect_pkg_manager / ensure_pkg%b\n' "$C5" "$NC"
    local mgr
    mgr=$(detect_pkg_manager 2>/dev/null || echo "nenhum")
    assert_equals "detect_pkg_manager retorna valor não-vazio" "1" "$([[ -n "$mgr" ]] && echo 1 || echo 0)"

    # ensure_pkg não instala nada se o comando já existe
    assert_equals "ensure_pkg: bash já instalado, retorna 0" "0" \
        "$(ensure_pkg bash bash >/dev/null 2>&1; echo $?)"
}

test_utils_funcoes() {
    printf '\n%b[utils.sh] Funções de saída%b\n' "$C5" "$NC"
    assert_equals "success retorna 0" "0" "$(success "ok" >/dev/null 2>&1; echo $?)"
    assert_equals "info retorna 0"    "0" "$(info "ok" >/dev/null 2>&1; echo $?)"
    assert_equals "warn retorna 0"    "0" "$(warn "ok" >/dev/null 2>&1; echo $?)"
}

test_arquivos_lib() {
    printf '\n%b[estrutura] Arquivos de lib%b\n' "$C5" "$NC"
    assert_file_exists "lib/utils.sh existe"      "$LIB_DIR/utils.sh"
    assert_file_exists "lib/config.sh existe"     "$LIB_DIR/config.sh"
    assert_file_exists "lib/validators.sh existe" "$LIB_DIR/validators.sh"
}

test_arquivos_libexec() {
    printf '\n%b[estrutura] Arquivos de libexec%b\n' "$C5" "$NC"
    local LIBEXEC="$ROOT_DIR/lib/lumina/libexec"
    assert_file_exists "libexec/stack.sh existe" "$LIBEXEC/stack.sh"
    assert_file_exists "libexec/db.sh existe"    "$LIBEXEC/db.sh"
    assert_file_exists "libexec/git.sh existe"   "$LIBEXEC/git.sh"
}

test_templates() {
    printf '\n%b[estrutura] Templates%b\n' "$C5" "$NC"
    local TMPL="$ROOT_DIR/lib/lumina/templates"
    assert_file_exists "template .gitignore existe"              "$TMPL/.gitignore"
    assert_file_exists "template .aiexclude existe"              "$TMPL/.aiexclude"
    assert_file_exists "template moodle-performance.cnf existe"  "$TMPL/moodle-performance.cnf"
}

test_binario() {
    printf '\n%b[estrutura] Binário principal%b\n' "$C5" "$NC"
    assert_file_exists "bin/lumina existe" "$ROOT_DIR/bin/lumina"
}

test_dependencias() {
    printf '\n%b[dependências] Comandos externos%b\n' "$C5" "$NC"
    assert_command_exists "bash disponível"   "bash"
    assert_command_exists "git disponível"    "git"
    assert_command_exists "docker disponível" "docker"
}

test_config_carregamento() {
    printf '\n%b[config.sh] Carregamento de configurações%b\n' "$C5" "$NC"
    # shellcheck source=/dev/null
    source "$LIB_DIR/config.sh"
    carregar_config
    assert_equals "WORKSPACE definido"        "1" "$([[ -n "${WORKSPACE:-}" ]] && echo 1 || echo 0)"
    assert_equals "CONTAINER_NAME definido"   "1" "$([[ -n "${CONTAINER_NAME:-}" ]] && echo 1 || echo 0)"
    assert_equals "BACKUP_DIR definido"       "1" "$([[ -n "${BACKUP_DIR:-}" ]] && echo 1 || echo 0)"
    assert_equals "BACKUPS_MANTER definido"   "1" "$([[ -n "${BACKUPS_MANTER:-}" ]] && echo 1 || echo 0)"
}

# --- ponto de entrada ---

main() {
    show_lumina_header
    printf '\n%bExecutando suíte de testes...%b\n' "$C4" "$NC"

    test_utils_cores
    test_utils_funcoes
    test_utils_pkg_manager
    test_arquivos_lib
    test_arquivos_libexec
    test_templates
    test_binario
    test_dependencias
    test_config_carregamento

    printf '\n%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n' "$C5" "$NC"
    printf '  Resultado: %b%d aprovados%b  %b%d falhos%b\n' "$C2" "$_PASS" "$NC" "$C1" "$_FAIL" "$NC"
    printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n' "$C5" "$NC"

    [[ "$_FAIL" -eq 0 ]]
}

main "$@"

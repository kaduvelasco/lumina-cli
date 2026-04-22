#!/usr/bin/env bash
# =============================================================================
# Nome do Script : lib/config.sh
# Versão         : 2.0.0
# =============================================================================

set -euo pipefail

readonly CONFIG_DIR="$HOME/.lumina"
readonly CONFIG_FILE="$CONFIG_DIR/config.env"

# Valores padrão
readonly _DEFAULT_WORKSPACE="$HOME/workspace/docker"
readonly _DEFAULT_CONTAINER="mariadb"
readonly _DEFAULT_BACKUP_DIR="$HOME/workspace/backups"
readonly _DEFAULT_BACKUPS_MANTER=3

_criar_config_padrao() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
# Lumina CLI — Configuração
# Gerado em: $(date +"%Y-%m-%d %H:%M")

WORKSPACE="$_DEFAULT_WORKSPACE"
CONTAINER_NAME="$_DEFAULT_CONTAINER"
BACKUP_DIR="$_DEFAULT_BACKUP_DIR"
BACKUPS_MANTER=$_DEFAULT_BACKUPS_MANTER
CONF_MOODLE_DIR="$_DEFAULT_WORKSPACE/mariadb/conf.d"
EOF
}

carregar_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        _criar_config_padrao
    fi

    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    WORKSPACE="${WORKSPACE:-$_DEFAULT_WORKSPACE}"
    CONTAINER_NAME="${CONTAINER_NAME:-$_DEFAULT_CONTAINER}"
    BACKUP_DIR="${BACKUP_DIR:-$_DEFAULT_BACKUP_DIR}"
    BACKUPS_MANTER="${BACKUPS_MANTER:-$_DEFAULT_BACKUPS_MANTER}"
    CONF_MOODLE_DIR="${CONF_MOODLE_DIR:-$WORKSPACE/mariadb/conf.d}"

    export WORKSPACE CONTAINER_NAME BACKUP_DIR BACKUPS_MANTER CONF_MOODLE_DIR
}

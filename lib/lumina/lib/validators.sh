#!/usr/bin/env bash
# =============================================================================
# Nome do Script : lib/validators.sh
# Versão         : 1.0.0
# =============================================================================

# Funções de validação e verificação de ambiente

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        die "Comando necessário não encontrado: $1. Por favor, instale-o."
    fi
}

require_container() {
    local container_name="$1"
    if ! docker ps --format '{{.Names}}' | grep -Eq "^${container_name}$"; then
        die "Container '${container_name}' não está em execução. Inicie o ambiente primeiro."
    fi
}

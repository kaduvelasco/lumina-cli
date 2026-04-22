#!/usr/bin/env bash
# DESC: Gerencia ambientes Docker (LuminaStack)
# USAGE: lumina stack [start|stop|status|logs|permissions|db-info]

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

# ==============================================================================
# INTERFACE
# ==============================================================================

show_header() {
    printf '\n%b=====================================%b\n' "$H1" "$NC"
    printf '%b      LUMINA STACK MANAGER%b\n' "$H1" "$NC"
    printf '%b=====================================%b\n' "$H1" "$NC"
}

show_menu() {
    show_header
    printf '   %b1.%b Iniciar ambiente\n' "$C2" "$NC"
    printf '   %b2.%b Visualizar logs\n' "$C2" "$NC"
    printf '   %b3.%b Dados do banco (MariaDB)\n' "$C2" "$NC"
    printf '   %b4.%b Finalizar ambiente\n' "$C2" "$NC"
    printf '   %b5.%b Corrigir permissões\n' "$C3" "$NC"
    printf '   %b6.%b Status e recursos\n' "$C4" "$NC"
    printf '   %b0.%b Sair\n' "$C1" "$NC"
    printf '%b=====================================%b\n' "$H2" "$NC"
}

show_help() {
    show_lumina_header
    cat << EOF

lumina stack — Gerenciador do ambiente Docker LuminaStack

USO:
  lumina stack              Abre o menu interativo
  lumina stack start        Inicia o ambiente
  lumina stack stop         Finaliza o ambiente
  lumina stack logs         Submenu de logs por versão PHP
  lumina stack status       Status e uso de recursos
  lumina stack permissions  Corrige permissões do workspace
  lumina stack db-info      Exibe credenciais do MariaDB
EOF
}

# ==============================================================================
# FUNÇÕES AUXILIARES
# ==============================================================================

# Compatibilidade: Docker Compose V2 (plugin) e V1 (binário standalone)
_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose "$@"
    else
        die "docker compose não encontrado. Instale o Docker Compose V2 ou o docker-compose."
    fi
}

_detect_workspace() {
    if [[ ! -d "$WORKSPACE" ]]; then
        warn "Workspace não encontrado em: $WORKSPACE"
        printf '   %b→ Execute o lumina-stack para criar a estrutura do workspace.%b\n' "$C6" "$NC"
        printf '   %b  https://github.com/kaduvelasco/lumina-stack%b\n' "$C6" "$NC"
        read -r -p "   Informe o caminho completo do diretório docker (ou Enter para cancelar): " CUSTOM
        [[ -z "$CUSTOM" ]] && return 1
        CUSTOM="${CUSTOM/#\~/$HOME}"
        if [[ -d "$CUSTOM" ]]; then
            WORKSPACE="$CUSTOM"
        else
            die "Diretório inválido: $CUSTOM"
        fi
    fi

    if [[ ! -f "$WORKSPACE/docker-compose.yml" ]]; then
        die "docker-compose.yml não encontrado em $WORKSPACE. Execute o lumina-stack para configurar o ambiente."
    fi
}

_mostrar_ultimo_backup() {
    local ultimo
    ultimo=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.sql" -printf "%T@\t%p\n" 2>/dev/null \
        | sort -rn | head -1 | cut -f2-)

    printf '%b──────────────────────────────────%b\n' "$C4" "$NC"
    if [[ -n "$ultimo" ]]; then
        local data
        if ! data=$(stat -c %y "$ultimo" 2>/dev/null | cut -d' ' -f1); then
            data=$(date -r "$ultimo" +%Y-%m-%d 2>/dev/null || echo "data desconhecida")
        fi
        printf '   %b💾 Último backup:%b %b%s%b — %s\n' "$C4" "$NC" "$C3" "$data" "$NC" "$(basename "$ultimo")"
    else
        warn "Nenhum backup encontrado em $BACKUP_DIR"
        printf "   %b   Considere executar 'lumina db backup'.%b\n" "$C3" "$NC"
    fi
    printf '%b──────────────────────────────────%b\n' "$C4" "$NC"
}

# ==============================================================================
# PRE-FLIGHT CHECK
# ==============================================================================

pre_flight_check() {
    local issues=0

    # 1. Docker daemon
    if ! docker ps > /dev/null 2>&1; then
        printf '   %b❌ Docker daemon não está rodando (systemctl start docker)%b\n' "$C1" "$NC" >&2
        (( issues++ )) || true
    fi

    # 2. Espaço em disco (avisa acima de 85%)
    local disk_use
    disk_use=$(df "$HOME" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    if [[ -n "$disk_use" && "$disk_use" -gt 85 ]]; then
        warn "Disco com ${disk_use}% de uso — pode faltar espaço para imagens Docker."
        (( issues++ )) || true
    fi

    # 3. Permissão de escrita no workspace
    if [[ -d "$HOME/workspace/www/html" && ! -w "$HOME/workspace/www/html" ]]; then
        warn "Sem permissão de escrita em ~/workspace/www/html"
        printf "      Execute: lumina stack permissions\n"
        (( issues++ )) || true
    fi

    # 4. Porta 80 ocupada — usa ss (sem sudo) com fallback para lsof
    if command -v ss >/dev/null 2>&1; then
        if ss -tlnp 2>/dev/null | grep -q ':80 ' && \
           ! ss -tlnp 2>/dev/null | grep ':80 ' | grep -q nginx; then
            warn "Porta 80 em uso por outro processo (ss -tlnp | grep ':80')"
            (( issues++ )) || true
        fi
    elif command -v lsof >/dev/null 2>&1; then
        if lsof -i :80 2>/dev/null | grep -qv "nginx"; then
            warn "Porta 80 em uso por outro processo (lsof -i :80)"
            (( issues++ )) || true
        fi
    fi

    if [[ "$issues" -gt 0 ]]; then
        printf '   %b%d aviso(s). Continuar mesmo assim? (s/N):%b ' "$C3" "$issues" "$NC"
        local CONTINUE_ANYWAY
        read -r CONTINUE_ANYWAY
        [[ ! "$CONTINUE_ANYWAY" =~ ^[sS]$ ]] && return 1
    fi

    return 0
}

# ==============================================================================
# AÇÕES DA STACK
# ==============================================================================

start_environment() {
    _detect_workspace || return 0

    printf "\n"
    info "Verificações pré-inicialização..."
    if ! pre_flight_check; then
        warn "Inicialização cancelada."
        return 0
    fi

    fix_permissions "silent" || warn "Não foi possível ajustar permissões (continuando mesmo assim)."
    _mostrar_ultimo_backup

    info "Iniciando LuminaStack..."
    cd "$WORKSPACE" || die "Não foi possível acessar o workspace: $WORKSPACE"
    if ! _docker_compose up -d; then
        printf '\n%b❌ Falha ao iniciar a stack. Verifique:%b\n' "$C1" "$NC" >&2
        printf "   • A porta 80 ou 3306 está em uso? (ss -tlnp | grep ':80')\n" >&2
        printf "   • Os volumes estão acessíveis?\n" >&2
        printf "   • O Docker daemon está rodando? (systemctl status docker)\n" >&2
        return 1
    fi

    printf "\n"
    success "Ambiente online!"
    printf '   Acesse: %bhttp://localhost%b para o dashboard\n' "$C3" "$NC"
    printf '   Ou use: %bhttp://phpXX.localhost%b para uma versão específica\n' "$C3" "$NC"
}

stop_environment() {
    _detect_workspace || return 0

    printf "\n"
    warn "Preparando para finalizar o ambiente..."
    printf '   %b💾 Abrir lumina db para backup antes de parar? (%bS%b/n): ' "$C4" "$C2" "$NC"
    read -r DO_BACKUP

    if [[ -z "$DO_BACKUP" || "$DO_BACKUP" =~ ^[sS]$ ]]; then
        if command -v lumina >/dev/null 2>&1; then
            info "Abrindo lumina db..."
            if ! lumina db backup; then
                warn "Backup falhou ou foi cancelado. Continuando com o shutdown."
            fi
        else
            warn "Comando 'lumina' não encontrado no PATH. Backup ignorado."
        fi
    fi

    printf "\n"
    info "Desligando containers..."
    cd "$WORKSPACE" || die "Não foi possível acessar o workspace: $WORKSPACE"
    if ! _docker_compose down --timeout 5 --remove-orphans; then
        die "Erro ao desligar os containers. Verifique com: docker ps"
    fi
    success "LuminaStack finalizado."
}

logs_menu() {
    local log_dir="$HOME/workspace/logs"

    if [[ ! -d "$log_dir" ]]; then
        die "Diretório de logs não encontrado em $log_dir"
    fi

    while true; do
        printf '\n%b===== 📜 Visualizador de Logs =====%b\n' "$C4" "$NC"

        local index=1
        declare -A map=()

        for p in "$log_dir"/php*/; do
            [[ -d "$p" ]] || continue
            local version
            version="${p#"$log_dir"/php}"
            version="${version%/}"
            printf '   %b%d.%b PHP %s\n' "$C2" "$index" "$NC" "$version"
            map[$index]="$(basename "$p")"
            (( index++ )) || true
        done

        if [[ "${#map[@]}" -eq 0 ]]; then
            warn "Nenhum diretório de log PHP encontrado em $log_dir"
        fi

        printf '   %b%d.%b Nginx\n' "$C2" "$index" "$NC"
        map[$index]="nginx"
        printf '   %b0.%b Voltar\n\n' "$C1" "$NC"

        read -r -p "Escolha o serviço: " option
        [[ "$option" == "0" || -z "$option" ]] && break

        local dir="${map[$option]:-}"
        if [[ -n "$dir" && -d "$log_dir/$dir" ]]; then
            printf '%b👀 Lendo logs de %s... (Ctrl+C para sair)%b\n' "$C3" "$dir" "$NC"
            if find "$log_dir/$dir" -maxdepth 1 -name "*.log" -type f | grep -q .; then
                tail -f "$log_dir/$dir"/*.log
            else
                warn "Nenhum log encontrado em $log_dir/$dir"
            fi
        else
            warn "Opção inválida."
        fi

        unset map
        declare -A map=()
    done
}

show_db_info() {
    _detect_workspace || return 0

    printf '\n%b🗄️  Banco de Dados (MariaDB)%b\n' "$C4" "$NC"
    printf '%b──────────────────────────────────%b\n' "$C4" "$NC"
    printf '   📍 Host  : %blocalhost%b\n' "$C3" "$NC"
    printf '   🔌 Porta : %b3306%b\n' "$C3" "$NC"

    if [[ -f "$WORKSPACE/.env" ]]; then
        local db_user db_pass
        db_user=$(grep '^DB_USER=' "$WORKSPACE/.env" | cut -d'=' -f2-)
        db_pass=$(grep '^DB_PASS=' "$WORKSPACE/.env" | cut -d'=' -f2-)
        if [[ -z "$db_user" ]]; then
            warn "DB_USER não encontrado em $WORKSPACE/.env"
        else
            printf '   👤 Usuário: %b%s%b\n' "$C3" "$db_user" "$NC"
        fi
        if [[ -z "$db_pass" ]]; then
            warn "DB_PASS não encontrado em $WORKSPACE/.env"
        else
            printf '   🔑 Senha  : %b%s%b\n' "$C3" "$db_pass" "$NC"
        fi
    else
        warn "Arquivo .env não encontrado em $WORKSPACE"
    fi
    printf '%b──────────────────────────────────%b\n\n' "$C4" "$NC"
}

fix_permissions() {
    local workspace_dir="$HOME/workspace"
    local silent="${1:-}"

    [[ -z "$silent" ]] && info "Ajustando permissões em $workspace_dir..."

    if [[ ! -d "$workspace_dir" ]]; then
        die "Pasta workspace não encontrada em $workspace_dir"
    fi

    if [[ -d "$workspace_dir/www" ]]; then
        sudo chown -R "$USER":www-data "$workspace_dir/www" 2>/dev/null || \
            { [[ -z "$silent" ]] && warn "Não foi possível ajustar dono de $workspace_dir/www (www-data existe?)"; }
        sudo find "$workspace_dir/www" -type d -exec chmod 775 {} + 2>/dev/null || true
        sudo find "$workspace_dir/www" -type f -exec chmod 664 {} + 2>/dev/null || true
    fi

    if [[ -d "$workspace_dir/backups" ]]; then
        sudo chown -R "$USER":www-data "$workspace_dir/backups" 2>/dev/null || \
            { [[ -z "$silent" ]] && warn "Não foi possível ajustar dono de $workspace_dir/backups"; }
        sudo find "$workspace_dir/backups" -type d -exec chmod 775 {} + 2>/dev/null || true
    fi

    # Moodle dataroot precisa de 777 pois o MegaSync não preserva permissões
    if [[ -d "$workspace_dir/www/data" ]]; then
        sudo chmod -R 777 "$workspace_dir/www/data" 2>/dev/null || true
    fi

    [[ -z "$silent" ]] && success "Permissões sincronizadas com sucesso!"
}

show_status() {
    _detect_workspace || return 0

    printf '\n%b🔍 Status da Stack LuminaStack%b\n' "$C4" "$NC"
    printf '%b──────────────────────────────────%b\n' "$C4" "$NC"

    local services=("nginx" "mariadb")
    local php_versions_env
    php_versions_env=$(grep '^PHP_VERSIONS=' "$WORKSPACE/.env" 2>/dev/null | cut -d'=' -f2-) || true
    for v in $php_versions_env; do
        services+=("php${v//./}")
    done

    local any_running=false
    for svc in "${services[@]}"; do
        local status
        status=$(docker ps --filter "name=^${svc}$" --format "{{.Status}}" 2>/dev/null)
        if [[ -n "$status" ]]; then
            printf '   %b●%b %b%-12s%b  %s\n' "$C2" "$NC" "$C3" "$svc" "$NC" "$status"
            any_running=true
        else
            printf '   %b●%b %b%-12s%b  parado\n' "$C1" "$NC" "$C3" "$svc" "$NC"
        fi
    done

    printf '%b──────────────────────────────────%b\n' "$C4" "$NC"

    if [[ "$any_running" == "true" ]]; then
        printf '\n%b📊 Uso de recursos (containers ativos):%b\n' "$C4" "$NC"
        docker stats --no-stream --format \
            "   {{.Name}}\t CPU: {{.CPUPerc}}\t MEM: {{.MemUsage}}" 2>/dev/null \
            | grep -E "$(IFS="|"; echo "${services[*]}")" || true
    fi
    printf "\n"
}

# ==============================================================================
# MENU INTERATIVO
# ==============================================================================

_run_menu() {
    while true; do
        show_menu
        read -r -p "Escolha uma opção: " option

        case "$option" in
            1) start_environment ;;
            2) logs_menu ;;
            3) show_db_info ;;
            4) stop_environment ;;
            5) fix_permissions ;;
            6) show_status ;;
            0)
                printf '\n%bAté logo!%b\n\n' "$C2" "$NC"
                exit 0
                ;;
            *)
                warn "Opção inválida. Digite um número de 0 a 6."
                sleep 1
                ;;
        esac
    done
}

# ==============================================================================
# PONTO DE ENTRADA
# ==============================================================================

main() {
    carregar_config

    local cmd="${1:-}"
    case "$cmd" in
        start)       start_environment ;;
        stop)        stop_environment ;;
        logs)        logs_menu ;;
        status)      show_status ;;
        permissions) fix_permissions ;;
        db-info)     show_db_info ;;
        -h|--help)   show_help ;;
        "")          _run_menu ;;
        *)           warn "Subcomando desconhecido: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"

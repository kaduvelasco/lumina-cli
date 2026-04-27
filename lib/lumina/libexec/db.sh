#!/usr/bin/env bash
# DESC: Gerencia bancos de dados MariaDB
# USAGE: lumina db [backup|restore|remove|optimize-tables|optimize-mariadb]

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
# shellcheck source=/dev/null
source "$LIB_DIR/validators.sh"

trap 'unset DB_USER DB_PASS' EXIT
trap 'printf "\n%b❌ Operação interrompida pelo usuário.%b\n" "$C1" "$NC"; exit 1' SIGINT SIGTERM

# ==============================================================================
# INTERFACE
# ==============================================================================

show_header() {
    show_lumina_header "LUMINA DB — GESTÃO DE DADOS"
}

show_menu() {
    show_header
    printf '   %b1.%b Backup (dump)\n' "$C2" "$NC"
    printf '   %b2.%b Remover bancos\n' "$C2" "$NC"
    printf '   %b3.%b Restaurar (restore)\n' "$C2" "$NC"
    printf '   %b4.%b Verificar / Otimizar tabelas\n' "$C2" "$NC"
    printf '   %b5.%b Otimizar MariaDB para Moodle\n' "$C2" "$NC"
    printf '   %b0.%b Sair\n' "$C1" "$NC"
    printf '%b=====================================%b\n\n' "$H2" "$NC"
}

show_help() {
    show_lumina_header "LUMINA DB — GESTÃO DE DADOS"
    cat << EOF

lumina db — Gerenciador de banco de dados MariaDB

USO:
  lumina db                    Abre o menu interativo
  lumina db backup             Exporta todos os bancos para $BACKUP_DIR
  lumina db restore            Importa backup SQL a partir de lista numerada
  lumina db remove             Remove bancos individualmente (com confirmação)
  lumina db optimize-tables    Executa mariadb-check --optimize em todos os bancos
  lumina db optimize-mariadb   Ajusta innodb_buffer_pool_size conforme a RAM

REQUISITO:
  O container '$CONTAINER_NAME' deve estar em execução.
  Inicie o ambiente com: lumina stack start
EOF
}

# ==============================================================================
# FUNÇÕES AUXILIARES
# ==============================================================================

_ler_credenciais() {
    local tentativas=0
    while [[ "$tentativas" -lt 3 ]]; do
        read -r -p "   👤 Usuário MariaDB: " DB_USER
        if [[ -z "$DB_USER" ]]; then
            warn "Usuário não pode ser vazio."
            (( tentativas++ )) || true; continue
        fi
        if ! [[ "$DB_USER" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            warn "Usuário inválido. Use apenas letras, números, _ e -."
            (( tentativas++ )) || true; continue
        fi
        read -r -s -p "   🔑 Senha MariaDB: " DB_PASS
        printf "\n"
        if [[ -z "$DB_PASS" ]]; then
            warn "Senha não pode ser vazia."
            (( tentativas++ )) || true; continue
        fi
        export DB_USER DB_PASS
        return 0
    done
    die "Falha após 3 tentativas de autenticação."
}

_executar_mysql() {
    # Usa MYSQL_PWD para evitar exposição da senha no ps aux
    docker exec -i -e MYSQL_PWD="$DB_PASS" "$CONTAINER_NAME" \
        mariadb -u "$DB_USER" "$@"
}

_limpar_backups_antigos() {
    local total
    total=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.sql" | wc -l)

    if [[ "$total" -gt "$BACKUPS_MANTER" ]]; then
        local remover
        remover=$(( total - BACKUPS_MANTER ))
        printf "\n"
        info "Mantendo os $BACKUPS_MANTER backups mais recentes..."
        while IFS= read -r arquivo; do
            if rm "$arquivo"; then
                printf "   Removido: %s\n" "$(basename "$arquivo")"
            else
                warn "Erro ao remover: $(basename "$arquivo")"
            fi
        done < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.sql" -printf "%T@\t%p\n" \
            | sort -rn | tail -n "$remover" | cut -f2-)
        success "$remover arquivo(s) antigo(s) removido(s) localmente."
        printf '   %b(O histórico completo permanece no Mega)%b\n' "$C6" "$NC"
    fi
}

_detect_system_ram() {
    local total_ram_mb
    total_ram_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    if [[ -n "$total_ram_mb" && "$total_ram_mb" -gt 0 ]]; then
        echo "$total_ram_mb"
        return 0
    fi
    return 1
}

_prompt_buffer_pool() {
    local total_ram_mb="$1"
    printf '%bQuanto desta RAM deseja dedicar ao Buffer Pool do MariaDB?%b\n' "$C4" "$NC"
    printf '   %b1.%b 1/2 da RAM — %dMB  (Ideal para DB dedicado)\n' "$C2" "$NC" "$(( total_ram_mb / 2 ))"
    printf '   %b2.%b 1/3 da RAM — %dMB  (Equilibrado - Recomendado)\n' "$C2" "$NC" "$(( total_ram_mb / 3 ))"
    printf '   %b3.%b 1/4 da RAM — %dMB  (Econômico)\n' "$C2" "$NC" "$(( total_ram_mb / 4 ))"
    printf "\n"
    read -r -p "   Opção [1-3]: " escolha_ram
    case "$escolha_ram" in
        1) echo $(( total_ram_mb / 2 )) ;;
        2) echo $(( total_ram_mb / 3 )) ;;
        3) echo $(( total_ram_mb / 4 )) ;;
        *)
            warn "Opção inválida. Usando 1/3 como padrão."
            echo $(( total_ram_mb / 3 ))
            ;;
    esac
}

_write_mariadb_config() {
    local buffer_pool_mb="$1"
    mkdir -p "$CONF_MOODLE_DIR"

    local tmpl="$SCRIPT_DIR/../templates/moodle-performance.cnf"
    if [[ -f "$tmpl" ]]; then
        sed "s/BUFFER_POOL_MB_PLACEHOLDER/${buffer_pool_mb}M/" "$tmpl" \
            > "$CONF_MOODLE_DIR/moodle-performance.cnf"
    else
        # fallback inline caso o template não esteja disponível
        cat > "$CONF_MOODLE_DIR/moodle-performance.cnf" << EOF
[mariadb]
max_allowed_packet = 64M
innodb_buffer_pool_size = ${buffer_pool_mb}M
innodb_log_file_size = 256M
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit = 2
binlog_format = ROW
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
EOF
    fi
}

# ==============================================================================
# AÇÕES DE BANCO
# ==============================================================================

executar_backup() {
    require_container "$CONTAINER_NAME"
    mkdir -p "$BACKUP_DIR"

    local timestamp file_name full_path
    timestamp=$(date +"%Y%m%d-%H%M")
    file_name="backup_full_${timestamp}.sql"
    full_path="$BACKUP_DIR/$file_name"

    printf "\n"
    info "Executando Backup Completo (MariaDB)..."
    printf '   📁 Destino: %b%s%b\n\n' "$C3" "$full_path" "$NC"

    _ler_credenciais

    if docker exec -e MYSQL_PWD="$DB_PASS" "$CONTAINER_NAME" \
        mariadb-dump -u "$DB_USER" --all-databases > "$full_path"; then
        printf "\n"
        success "Backup concluído com sucesso!"
        printf '   📄 Arquivo: %b%s%b\n' "$C3" "$file_name" "$NC"
        _limpar_backups_antigos
    else
        warn "Erro ao realizar o backup."
        [[ -f "$full_path" ]] && rm -f "$full_path"
    fi

    unset DB_USER DB_PASS
    printf "\n"
    read -r -p "Pressione Enter para continuar..."
}

remover_bancos() {
    require_container "$CONTAINER_NAME"

    printf '\n%b⚠️  REMOÇÃO DE BANCOS — Use com cuidado!%b\n\n' "$C1" "$NC"
    _ler_credenciais
    printf "\n"

    local db_output
    if ! db_output=$(_executar_mysql -e "SHOW DATABASES;" 2>&1); then
        warn "Falha ao conectar ao banco. Verifique as credenciais."
        read -r -p "Pressione Enter para continuar..."
        return
    fi

    local dbs
    dbs=$(printf '%s\n' "$db_output" \
        | grep -Ev "^(Database|mysql|information_schema|performance_schema|sys)$")

    if [[ -z "$dbs" ]]; then
        info "Nenhum banco de dados personalizado encontrado."
    else
        while IFS= read -r db; do
            read -r -p "   Remover o banco '${C3}${db}${NC}'? (s/N): " resp
            if [[ "$resp" =~ ^[sS]$ ]]; then
                _executar_mysql -e "DROP DATABASE \`${db}\`;"
                success "Banco '$db' removido."
            fi
        done <<< "$dbs"
    fi

    unset DB_USER DB_PASS
    printf "\n"
    read -r -p "Pressione Enter para continuar..."
}

executar_restore() {
    require_container "$CONTAINER_NAME"

    printf "\n"
    info "Executando Restore"
    printf '   📁 Buscando backups em: %b%s%b\n\n' "$C3" "$BACKUP_DIR" "$NC"

    mapfile -t arquivos < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.sql" \
        -printf "%T@\t%p\n" 2>/dev/null | sort -rn | cut -f2-)

    if [[ "${#arquivos[@]}" -eq 0 ]]; then
        warn "Nenhum arquivo SQL encontrado em $BACKUP_DIR"
        read -r -p "Pressione Enter para continuar..."
        return
    fi

    for i in "${!arquivos[@]}"; do
        printf '   %b%d.%b %s\n' "$C2" "$(( i + 1 ))" "$NC" "$(basename "${arquivos[$i]}")"
    done
    printf "\n"

    local num
    read -r -p "Selecione o arquivo [1-${#arquivos[@]}]: " num

    if ! [[ "$num" =~ ^[0-9]+$ ]] || [[ "$num" -lt 1 ]] || [[ "$num" -gt "${#arquivos[@]}" ]]; then
        warn "Opção inválida."
        read -r -p "Pressione Enter para continuar..."
        return
    fi

    local file_full="${arquivos[$(( num - 1 ))]}"

    if [[ ! -f "$file_full" ]]; then
        warn "Arquivo não encontrado ou inacessível."
        read -r -p "Pressione Enter para continuar..."
        return
    fi

    printf '\n   Arquivo selecionado: %b%s%b\n\n' "$C3" "$(basename "$file_full")" "$NC"
    printf '   %b⚠️  O restore requer um usuário com privilégio CREATE DATABASE.%b\n' "$C3" "$NC"
    printf "   %b   Use 'root' ou um superusuário do MariaDB.%b\n\n" "$C3" "$NC"

    _ler_credenciais
    printf "\n"
    info "Restaurando... Isso pode levar alguns minutos."

    if docker exec -i -e MYSQL_PWD="$DB_PASS" "$CONTAINER_NAME" \
        mariadb -u "$DB_USER" < "$file_full"; then
        success "Restore concluído com sucesso!"
    else
        warn "Erro durante o restore."
    fi

    unset DB_USER DB_PASS
    printf "\n"
    read -r -p "Pressione Enter para continuar..."
}

verificar_tabelas() {
    require_container "$CONTAINER_NAME"

    printf "\n"
    info "Verificando e Otimizando Tabelas"
    printf "\n"
    _ler_credenciais
    printf "\n"

    docker exec -i -e MYSQL_PWD="$DB_PASS" "$CONTAINER_NAME" \
        mariadb-check -u "$DB_USER" --all-databases --optimize

    unset DB_USER DB_PASS
    printf "\n"
    read -r -p "Pressione Enter para continuar..."
}

otimizar_mariadb() {
    require_container "$CONTAINER_NAME"

    printf "\n"
    info "Otimizando MariaDB para Moodle"
    printf "\n"

    local total_ram_mb
    if total_ram_mb=$(_detect_system_ram); then
        success "RAM detectada: ${total_ram_mb}MB (~$(( total_ram_mb / 1024 ))GB)"
        printf "\n"
    else
        warn "Não foi possível detectar a RAM automaticamente."
        local total_ram_gb
        read -r -p "   Informe a quantidade de RAM em GB (ex: 12): " total_ram_gb
        while ! [[ "$total_ram_gb" =~ ^[0-9]+$ ]] || [[ "$total_ram_gb" -lt 1 ]]; do
            warn "Valor inválido. Digite apenas números inteiros."
            read -r -p "   Informe a quantidade de RAM em GB: " total_ram_gb
        done
        total_ram_mb=$(( total_ram_gb * 1024 ))
    fi

    local buffer_pool_mb
    buffer_pool_mb=$(_prompt_buffer_pool "$total_ram_mb")

    printf "\n"
    info "Configurando innodb_buffer_pool_size para: ${buffer_pool_mb}MB"
    _write_mariadb_config "$buffer_pool_mb"

    warn "Reiniciando container para carregar as novas configurações..."
    if docker restart "$CONTAINER_NAME"; then
        success "Configurações aplicadas com sucesso."
    else
        warn "Falha ao reiniciar o container. Verifique com: docker ps"
    fi

    printf "\n"
    read -r -p "Pressione Enter para continuar..."
}

# ==============================================================================
# MENU INTERATIVO
# ==============================================================================

_run_menu() {
    while true; do
        show_menu
        read -r -p "Opção: " escolha
        case "$escolha" in
            1) executar_backup ;;
            2) remover_bancos ;;
            3) executar_restore ;;
            4) verificar_tabelas ;;
            5) otimizar_mariadb ;;
            0)
                printf '\n%bAté logo!%b\n\n' "$C2" "$NC"
                exit 0
                ;;
            *)
                warn "Opção inválida. Digite um número de 0 a 5."
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
        backup)           executar_backup ;;
        restore)          executar_restore ;;
        remove)           remover_bancos ;;
        optimize-tables)  verificar_tabelas ;;
        optimize-mariadb) otimizar_mariadb ;;
        -h|--help)        show_help ;;
        "")               _run_menu ;;
        *)                warn "Subcomando desconhecido: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"

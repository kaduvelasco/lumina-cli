# Bash/Shell Development — Lumina Standard

Bash/Shell development standards for the Lumina ecosystem.
Focused on defensive scripts, performance, and a consistent interface.
Use for creating automation scripts, CLI tools, and installers.

---

## Language

| Context | Language |
|---|---|
| Responses to the user | Brazilian Portuguese (pt-BR) |
| Code comments | English |

---

## Boilerplate

Every script must start with this exact structure.

```bash
#!/usr/bin/env bash
# =============================================================================
# Script Name : script-name.sh
# Description : Brief description of the purpose
# Version     : 1.0.0
# =============================================================================
set -Eeuo pipefail
shopt -s inherit_errexit

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# --- Cleanup and Errors ---
trap 'printf "\n\033[0;31m❌ Error at %s:%d\033[0m\n" "${BASH_SOURCE[0]}" "$LINENO" >&2' ERR
trap '[[ -n "${_tmpdir:-}" ]] && rm -rf -- "$_tmpdir"' EXIT

# --- Dependency Loading ---
for _lib in utils.sh system.sh; do
    if [[ ! -f "$SCRIPT_DIR/lib/$_lib" ]]; then
        printf '\033[0;31m❌ Fatal error: lib/%s not found.\033[0m\n' "$_lib" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/$_lib"
done
unset _lib

# --- Functions ---
main() {
    detect_pkg_manager
    show_header "Optional Subtitle"
    # Logic here
}

main "$@"
```

---

## Defensive Shell — Golden Rules

1. **Always quote variables:** `"$var"`, `"${array[@]}"`, `"$(command)"`.

2. **Local scope in functions:** use `local` for variables, `local -r` for constants.

3. **Preserve exit codes** — separate declaration from assignment:
   ```bash
   local result
   result=$(command_that_might_fail)
   ```

4. **Flag protection** — terminate options with `--` before variable arguments:
   ```bash
   rm -rf -- "$path"
   grep -F -- "$search" "$file"
   ```

5. **Printf over echo** — use `printf '%b\n'` for colorized output, `printf '%s\n'` for literal text.

---

## Lumina Interface (`lib/utils.sh`)

### Color palette

Never redefine colors. Use the variables exported by `utils.sh`:

| Variable | Color | Usage |
|---|---|---|
| `${C1}` | Red | Error |
| `${C2}` | Green | Success |
| `${C3}` | Yellow | Warning |
| `${C4}` | Gray (#999999) | Info |
| `${H1}`, `${H2}` | Default terminal | Headers |
| `${RESET}` | — | Reset |

### Output functions

| Function | Description |
|---|---|
| `die "msg"` | Fatal error + exit |
| `warn "msg"` | Warning to stderr |
| `info "msg"` | Information to stdout |
| `success "msg"` | Success confirmation |

### Confirmations

Standard: `y` or `s` confirms, any other key cancels.

```bash
printf '%s' "Continue? (${C3}y${RESET}/N): "
read -r confirm
[[ ! "$confirm" =~ ^[yYsS]$ ]] && return 0
```

### Default header

```bash
# =============================================================================
# Exibe o cabeçalho ASCII padrão Lumina. $1 = subtítulo (opcional).
# =============================================================================
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
```

```bash
show_header() {
    show_lumina_header "LuminaDev — Workstation Setup"
}
```

---

## Production Patterns

### Atomic write

Prevents file corruption on write failures.

```bash
atomic_write() {
    local tmp; tmp=$(mktemp)
    cat > "$tmp"
    mv -- "$tmp" "$1"
    chmod 644 "$1"
}

generate_config | atomic_write "/etc/app/config.conf"
```

### Safe iteration (NUL-delimited)

Handles filenames containing spaces or newlines.

```bash
while IFS= read -r -d '' f; do
    process "$f"
done < <(find . -type f -name "*.log" -print0)
```

### Dependency check

```bash
require_cmd() {
    command -v "$1" &>/dev/null || die "Missing dependency: $1"
}
```

### Sensitive files (credentials)

Create with restricted permissions **before** writing data.

```bash
local secret_file="$HOME/.secrets"
(umask 077; touch "$secret_file")
printf 'TOKEN=%q\n' "$user_token" >> "$secret_file"
```

---

## Quality

- **ShellCheck:** `--severity=warning --shell=bash --exclude=SC1091`
  - Suppress SC1091 only where sourcing is dynamic.
- **shfmt:** `shfmt -i 4 -ci` for consistent formatting.
- All scripts must pass ShellCheck with zero warnings before being considered complete.

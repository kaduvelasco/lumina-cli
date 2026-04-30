# Contributing to Lumina CLI

📄 Portuguese version: see CONTRIBUINDO.md

Thank you for your interest in contributing to Lumina CLI! This document provides guidelines and instructions for contributing to the project.

---

## Getting Started

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-username/lumina-cli.git
   cd lumina-cli
   ```

### Install Dependencies

Lumina CLI requires:
- `bash >= 4.0`
- `docker` and `docker-compose` (or `docker compose` v2)
- `git`

The project has no external Bash dependencies beyond the standard library. Development tools include:
- `shellcheck` — for code analysis
- `shfmt` — for code formatting

Install development tools:
```bash
# Debian/Ubuntu
sudo apt-get install shellcheck shfmt

# Fedora
sudo dnf install ShellCheck shfmt

# macOS
brew install shellcheck shfmt
```

---

## Code Standards

Lumina CLI follows strict Bash standards to ensure defensive, maintainable code.

### Bash Version and Safety

Every script must start with:
```bash
#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit
```

- `set -e` — exit on error
- `set -u` — error on undefined variables
- `set -o pipefail` — propagate errors through pipes
- `shopt -s inherit_errexit` — inherit errexit in command substitutions

### Variable Handling

1. **Always quote variables:**
   ```bash
   # Good
   echo "$var"
   echo "${array[@]}"
   echo "$(command)"

   # Bad
   echo $var
   echo $@
   echo $(command)
   ```

2. **Local scope in functions:**
   ```bash
   my_function() {
       local var="value"
       local -r constant="immutable"
       # ...
   }
   ```

3. **Separate declaration from assignment in command substitutions:**
   ```bash
   # Good
   local result
   result=$(some_command)

   # Bad
   local result=$(some_command)  # Loses the exit code
   ```

### Flag Protection

Terminate option flags with `--` before arguments to prevent injection:
```bash
# Good
rm -rf -- "$path"
grep -F -- "$search" "$file"

# Bad
rm -rf $path          # Vulnerable to word splitting
grep -F $search "$file"
```

### Output Functions

Use `printf` instead of `echo` for better portability:
```bash
# Colorized output
printf '%b\n' "${C1}Error message${RESET}"

# Literal text
printf '%s\n' "Literal string"

# Formatted output
printf '%s: %d\n' "Count" 42
```

Import color variables from `utils.sh`:
```bash
# Available variables:
# ${C1} — Red (errors)
# ${C2} — Green (success)
# ${C3} — Yellow (warnings)
# ${C4} — Blue (info)
# ${H1}, ${H2} — Headers
# ${RESET} — Reset colors
```

### ShellCheck

All scripts must pass ShellCheck with zero warnings:
```bash
shellcheck -x lib/lumina/libexec/your-command.sh
```

Flags:
- `-x` — follow sourced files
- `--severity=warning` — enforce warnings as errors
- `--shell=bash` — target Bash

Exclude only `SC1091` (sourcing is dynamic) when absolutely necessary.

### Code Formatting

Use `shfmt` for consistent formatting:
```bash
shfmt -i 4 -ci -w lib/lumina/libexec/your-command.sh
```

Flags:
- `-i 4` — indent 4 spaces
- `-ci` — continue indentation on multi-line commands
- `-w` — write in-place

---

## Project Structure

```
lumina-cli/
├── bin/lumina                      # Entry point dispatcher
├── completions/                    # Bash and Zsh autocomplete
├── guides/                         # Documentation and guides
├── install.sh                      # Installation script
├── lib/lumina/
│   ├── lib/
│   │   ├── utils.sh                # Colors, output functions
│   │   ├── config.sh               # Configuration loader
│   │   └── validators.sh           # Validation helpers
│   ├── libexec/                    # Subcommand implementations
│   └── templates/                  # AI agent templates
└── tests/
    └── test-runner.sh              # Test suite
```

### How Subcommands Work

The dispatcher `bin/lumina` automatically discovers scripts in `lib/lumina/libexec/`
and exposes them as subcommands. To add `lumina foo`, create `lib/lumina/libexec/foo.sh`.

---

## Adding a New Subcommand

### Step 1: Create the Script

Create `lib/lumina/libexec/<command>.sh` following this boilerplate:

```bash
#!/usr/bin/env bash
# =============================================================================
# Script Name : command.sh
# Description : Brief description of the subcommand
# Version     : 1.0.0
# =============================================================================
set -euo pipefail
shopt -s inherit_errexit

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# --- Cleanup and Errors ---
trap 'printf "\n\033[0;31m%s\033[0m\n" "Error at ${BASH_SOURCE[0]}:$LINENO" >&2' ERR
trap '[[ -n "${_tmpdir:-}" ]] && rm -rf -- "$_tmpdir"' EXIT

# --- Dependency Loading ---
for _lib in utils.sh config.sh validators.sh; do
    if [[ ! -f "$SCRIPT_DIR/../lib/$_lib" ]]; then
        printf '\033[0;31m%s\033[0m\n' "Fatal error: lib/$_lib not found." >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../lib/$_lib"
done
unset _lib

# --- Functions ---

show_help() {
    cat <<EOF
Usage: lumina <command> [options]

Description:
    Brief description of what this command does.

Options:
    --help    Show this help message
EOF
}

main() {
    local action="${1:-}"

    case "$action" in
        --help|-h) show_help ;;
        *)         printf '%s\n' "Invalid action: $action" >&2; exit 1 ;;
    esac
}

main "$@"
```

### Step 2: Follow Code Standards

Ensure your script:
- Uses the boilerplate structure above
- Follows all code standards in the "Code Standards" section
- Includes proper error handling
- Uses only built-in Bash features (no external dependencies unless unavoidable)

### Step 3: Pass ShellCheck

Run ShellCheck and fix all warnings:
```bash
shellcheck -x lib/lumina/libexec/<command>.sh
```

There should be zero warnings before proceeding.

### Step 4: Format with shfmt

```bash
shfmt -i 4 -ci -w lib/lumina/libexec/<command>.sh
```

### Step 5: Run the Test Suite

Ensure all existing tests still pass:
```bash
bash tests/test-runner.sh
```

All 38 tests must pass. If you add new functionality, add corresponding tests in
`tests/test-runner.sh`.

### Step 6: Test Your Command

Your new command is immediately available:
```bash
lumina <command> --help
```

---

## Running Tests

The test suite verifies:
- Script structure and file existence
- External dependency availability
- Color constants
- Output functions
- Configuration loading

Run the full test suite:
```bash
bash tests/test-runner.sh
```

Expected output:
```
Resultado: 38 aprovados  0 falhos
```

All tests must pass before submitting a pull request.

---

## Pull Request Process

### Before Opening a PR

1. Ensure your code follows the "Code Standards" section
2. Pass ShellCheck and shfmt
3. All tests pass (38/38)
4. Test your changes manually

### Opening a PR

1. Create a feature branch: `git checkout -b feature/<feature-name>`
2. Write a clear, descriptive commit message
3. Push your branch: `git push origin feature/<feature-name>`
4. Open a PR with:
   - Clear title describing the change
   - Description of what changed and why
   - Link any related issues
5. Respond to code review feedback promptly

### PR Requirements

- All tests passing
- ShellCheck with zero warnings
- Code formatted with shfmt
- No external dependencies without justification
- Documentation updated (if applicable)

---

## Questions or Issues?

If you have questions or encounter issues, please:
1. Check existing [GitHub Issues](https://github.com/kaduvelasco/lumina-cli/issues)
2. Open a new issue with a clear description
3. Include your shell version, OS, and relevant logs

---

Made with ❤️ and AI by [Kadu Velasco](https://github.com/kaduvelasco)

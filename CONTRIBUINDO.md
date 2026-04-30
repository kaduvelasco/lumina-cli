# Contribuindo com o Lumina CLI

📄 Versão em inglês: veja CONTRIBUTING.md

Obrigado por seu interesse em contribuir com o Lumina CLI! Este documento fornece diretrizes e instruções para contribuir com o projeto.

---

## Começando

### Fazer Fork e Clonar

1. Faça fork do repositório no GitHub
2. Clone seu fork localmente:
   ```bash
   git clone https://github.com/seu-usuario/lumina-cli.git
   cd lumina-cli
   ```

### Instalar Dependências

O Lumina CLI requer:
- `bash >= 4.0`
- `docker` e `docker-compose` (ou `docker compose` v2)
- `git`

O projeto não possui dependências externas de Bash além da biblioteca padrão. As ferramentas de desenvolvimento incluem:
- `shellcheck` — para análise de código
- `shfmt` — para formatação de código

Instale as ferramentas de desenvolvimento:
```bash
# Debian/Ubuntu
sudo apt-get install shellcheck shfmt

# Fedora
sudo dnf install ShellCheck shfmt

# macOS
brew install shellcheck shfmt
```

---

## Padrões de Código

O Lumina CLI segue padrões rigorosos de Bash para garantir código defensivo e mantível.

### Versão do Bash e Segurança

Todo script deve começar com:
```bash
#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit
```

- `set -e` — sair ao encontrar erro
- `set -u` — erro em variáveis indefinidas
- `set -o pipefail` — propagar erros através de pipes
- `shopt -s inherit_errexit` — herdar errexit em substituições de comando

### Manipulação de Variáveis

1. **Sempre citar variáveis:**
   ```bash
   # Bom
   echo "$var"
   echo "${array[@]}"
   echo "$(command)"

   # Ruim
   echo $var
   echo $@
   echo $(command)
   ```

2. **Escopo local em funções:**
   ```bash
   minha_funcao() {
       local var="valor"
       local -r constante="imutável"
       # ...
   }
   ```

3. **Separar declaração de atribuição em substituições de comando:**
   ```bash
   # Bom
   local resultado
   resultado=$(algum_comando)

   # Ruim
   local resultado=$(algum_comando)  # Perde o código de saída
   ```

### Proteção de Flags

Termine opções com `--` antes de argumentos para evitar injeção:
```bash
# Bom
rm -rf -- "$path"
grep -F -- "$search" "$file"

# Ruim
rm -rf $path          # Vulnerável a word splitting
grep -F $search "$file"
```

### Funções de Output

Use `printf` em vez de `echo` para melhor portabilidade:
```bash
# Output colorizado
printf '%b\n' "${C1}Mensagem de erro${RESET}"

# Texto literal
printf '%s\n' "String literal"

# Output formatado
printf '%s: %d\n' "Contagem" 42
```

Importe variáveis de cor de `utils.sh`:
```bash
# Variáveis disponíveis:
# ${C1} — Vermelho (erros)
# ${C2} — Verde (sucesso)
# ${C3} — Amarelo (avisos)
# ${C4} — Azul (informação)
# ${H1}, ${H2} — Cabeçalhos
# ${RESET} — Resetar cores
```

### ShellCheck

Todos os scripts devem passar no ShellCheck com zero avisos:
```bash
shellcheck -x lib/lumina/libexec/seu-comando.sh
```

Flags:
- `-x` — seguir arquivos sourced
- `--severity=warning` — forçar avisos como erros
- `--shell=bash` — alvo Bash

Exclua apenas `SC1091` (sourcing dinâmico) quando absolutamente necessário.

### Formatação de Código

Use `shfmt` para formatação consistente:
```bash
shfmt -i 4 -ci -w lib/lumina/libexec/seu-comando.sh
```

Flags:
- `-i 4` — indentar 4 espaços
- `-ci` — continuar indentação em comandos multi-linha
- `-w` — escrever no arquivo

---

## Estrutura do Projeto

```
lumina-cli/
├── bin/lumina                      # Ponto de entrada dispatcher
├── completions/                    # Autocomplete Bash e Zsh
├── guides/                         # Documentação e guias
├── install.sh                      # Script de instalação
├── lib/lumina/
│   ├── lib/
│   │   ├── utils.sh                # Cores, funções de output
│   │   ├── config.sh               # Carregador de configuração
│   │   └── validators.sh           # Helpers de validação
│   ├── libexec/                    # Implementações de subcomandos
│   └── templates/                  # Templates de agentes IA
└── tests/
    └── test-runner.sh              # Suíte de testes
```

### Como Funcionam os Subcomandos

O dispatcher `bin/lumina` descobre automaticamente scripts em `lib/lumina/libexec/`
e os expõe como subcomandos. Para adicionar `lumina foo`, crie `lib/lumina/libexec/foo.sh`.

---

## Adicionando um Novo Subcomando

### Passo 1: Criar o Script

Crie `lib/lumina/libexec/<comando>.sh` seguindo este boilerplate:

```bash
#!/usr/bin/env bash
# =============================================================================
# Script Name : comando.sh
# Description : Breve descrição do subcomando
# Version     : 1.0.0
# =============================================================================
set -euo pipefail
shopt -s inherit_errexit

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# --- Cleanup and Errors ---
trap 'printf "\n\033[0;31m%s\033[0m\n" "Erro em ${BASH_SOURCE[0]}:$LINENO" >&2' ERR
trap '[[ -n "${_tmpdir:-}" ]] && rm -rf -- "$_tmpdir"' EXIT

# --- Dependency Loading ---
for _lib in utils.sh config.sh validators.sh; do
    if [[ ! -f "$SCRIPT_DIR/../lib/$_lib" ]]; then
        printf '\033[0;31m%s\033[0m\n' "Erro fatal: lib/$_lib não encontrado." >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../lib/$_lib"
done
unset _lib

# --- Functions ---

show_help() {
    cat <<EOF
Uso: lumina <comando> [opções]

Descrição:
    Breve descrição do que este comando faz.

Opções:
    --help    Exibe esta mensagem de ajuda
EOF
}

main() {
    local action="${1:-}"

    case "$action" in
        --help|-h) show_help ;;
        *)         printf '%s\n' "Ação inválida: $action" >&2; exit 1 ;;
    esac
}

main "$@"
```

### Passo 2: Seguir os Padrões de Código

Garanta que seu script:
- Use a estrutura de boilerplate acima
- Siga todos os padrões de código na seção "Padrões de Código"
- Inclua tratamento adequado de erros
- Use apenas recursos built-in do Bash (sem dependências externas, a menos que inevitável)

### Passo 3: Passar no ShellCheck

Execute ShellCheck e corrija todos os avisos:
```bash
shellcheck -x lib/lumina/libexec/<comando>.sh
```

Não deve haver avisos antes de prosseguir.

### Passo 4: Formatar com shfmt

```bash
shfmt -i 4 -ci -w lib/lumina/libexec/<comando>.sh
```

### Passo 5: Executar a Suíte de Testes

Garanta que todos os testes existentes continuem passando:
```bash
bash tests/test-runner.sh
```

Todos os 38 testes devem passar. Se você adicionar novas funcionalidades, adicione
testes correspondentes em `tests/test-runner.sh`.

### Passo 6: Testar Seu Comando

Seu novo comando está imediatamente disponível:
```bash
lumina <comando> --help
```

---

## Executando Testes

A suíte de testes verifica:
- Estrutura e existência de scripts
- Disponibilidade de dependências externas
- Constantes de cores
- Funções de output
- Carregamento de configuração

Execute a suíte de testes completa:
```bash
bash tests/test-runner.sh
```

Saída esperada:
```
Resultado: 38 aprovados  0 falhos
```

Todos os testes devem passar antes de enviar um pull request.

---

## Processo de Pull Request

### Antes de Abrir um PR

1. Garanta que seu código segue a seção "Padrões de Código"
2. Passe no ShellCheck e shfmt
3. Todos os testes passem (38/38)
4. Teste suas mudanças manualmente

### Abrindo um PR

1. Crie uma branch de feature: `git checkout -b feature/<nome-da-feature>`
2. Escreva uma mensagem de commit clara e descritiva
3. Faça push da branch: `git push origin feature/<nome-da-feature>`
4. Abra um PR com:
   - Título claro descrevendo a mudança
   - Descrição do que mudou e por quê
   - Link para issues relacionadas
5. Responda ao feedback de código review prontamente

### Requisitos do PR

- Todos os testes passando
- ShellCheck com zero avisos
- Código formatado com shfmt
- Sem dependências externas sem justificativa
- Documentação atualizada (se aplicável)

---

## Dúvidas ou Problemas?

Se tiver dúvidas ou encontrar problemas:
1. Verifique as [Issues existentes no GitHub](https://github.com/kaduvelasco/lumina-cli/issues)
2. Abra uma nova issue com descrição clara
3. Inclua sua versão do shell, SO e logs relevantes

---

Made with ❤️ and AI by [Kadu Velasco](https://github.com/kaduvelasco)

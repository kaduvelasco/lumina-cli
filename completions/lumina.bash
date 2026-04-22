# Bash completion for lumina CLI

_lumina_completions() {
    local cur prev words
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")

    local commands="stack db git ai"

    local stack_cmds="start stop logs status fix-permissions show-db-info"
    local db_cmds="backup restore remove optimize-tables optimize-mariadb"
    local git_cmds="init clone configure-global apply-local"
    local ai_cmds="agents"

    if [[ ${#words[@]} -eq 2 ]]; then
        # Completar o subcomando principal
        COMPREPLY=( $(compgen -W "$commands --help --version" -- "$cur") )
        return 0
    fi

    case "${words[1]}" in
        stack)
            COMPREPLY=( $(compgen -W "$stack_cmds" -- "$cur") )
            ;;
        db)
            COMPREPLY=( $(compgen -W "$db_cmds" -- "$cur") )
            ;;
        git)
            COMPREPLY=( $(compgen -W "$git_cmds" -- "$cur") )
            ;;
        ai)
            COMPREPLY=( $(compgen -W "$ai_cmds" -- "$cur") )
            ;;
    esac
}

complete -F _lumina_completions lumina

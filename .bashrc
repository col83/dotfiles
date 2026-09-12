
# Disable the terminal bell
set bell-style none
bind 'set bell-style none'

# Interactive shell only
[[ $- != *i* ]] && return


# Aliases

alias cls='printf "\033c"; echo'

if command -v watch >/dev/null 2>&1; then
    alias watch='watch -e -t -c -n 1 -p -x "$@"'
fi

# mount
if command -v udisksctl >/dev/null 2>&1; then
    alias mnt='udisksctl mount -b'
    alias umnt='udisksctl unmount -b'
fi

# fastfetch
if command -v fastfetch >/dev/null 2>&1; then
    ff() {
        echo
        command fastfetch
        echo
    }
fi

# eza replacements
if command -v eza >/dev/null 2>&1; then

    ls() {
        echo
        command eza "$@"
        echo
    }

    ll() {
        echo
        command eza -l "$@"
        echo
    }

    lll() {
        echo
        command eza -la "$@"
        echo
    }

else

    ll() {
        echo
        ls -l --color=auto "$@"
        echo
    }

    lll() {
        echo
        ls -lA --color=auto "$@"
        echo
    }

fi

alias ..='cd ..'

# Greeting
# Disable default greeting/noise
unset MAILCHECK

# Enhanced colorful prompt
__prompt_command() {

    local priv_symbol='$'
    [[ $EUID -eq 0 ]] && priv_symbol='#'

    local color_user_normal='\[\e[32m\]'  # green
    local color_user_root='\[\e[31m\]'    # red
    local color_host='\[\e[36m\]'         # cyan
    local color_path='\[\e[34m\]'         # blue
    local color_home='\[\e[33m\]'         # yellow
    local color_reset='\[\e[0m\]'         # normal

    local user="\u"
    local host="\h"
    host="${host%%.*}"

    local current_path="$PWD"
    local path_color="$color_path"

    if [[ "$current_path" == "$HOME" ]]; then
        current_path='~'
        path_color="$color_home"

    elif [[ "$current_path" == "$HOME/"* ]]; then
        current_path="~/${current_path#"$HOME"/}"
        path_color="$color_home"
    fi

    [[ "$current_path" != "/" ]] && current_path+="/"

    local user_color="$color_user_normal"
    [[ $EUID -eq 0 ]] && user_color="$color_user_root"

    PS1="${user_color}${user}${color_reset}@${color_host}${host}${color_reset} ${path_color}${current_path}${color_reset} ${priv_symbol} "
}

PROMPT_COMMAND="__prompt_command"

# $PATH listing
lspath() {
    echo
    printf '%s\n' "$PATH" |
        tr ':' '\n' |
        while IFS= read -r path; do
            realpath -e -- "$path"
        done |
        sort -u
    echo
}

lspath() {
    local red='\033[31m'
    local yellow='\033[33m'
    local reset='\033[0m'

    declare -A paths

    while IFS= read -r path; do
        [[ -z "$path" ]] && continue

        if [[ -d "$path" ]]; then
            # Existing directory — resolve symlinks
            real=$(realpath -e -- "$path")
            paths["$real"]=ok
        else
            # Missing or invalid PATH entry
            paths["$path"]=missing
        fi
    done < <(printf '%s\n' "$PATH" | tr ':' '\n')

    echo

    for path in "${!paths[@]}"; do
        printf '%s\t%s\n' "${paths[$path]}" "$path"
    done |
        sort -k2 |
        while IFS=$'\t' read -r status path; do
            case "$status" in
                ok)
                    printf '%s\n' "$path"
                    ;;
                missing)
                    printf '%b%s%b\n' "$red" "$path" "$reset"
                    ;;
            esac
        done

    echo
}

# PATH

OLD_PATH=${PATH}

bash_add_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

# Main local binaries
bash_add_path "$HOME/.local/bin"

# Python
bash_add_path "$HOME/.local/bin/uv"

# Android Tools
bash_add_path "$HOME/.local/bin/platform-tools"
bash_add_path "$HOME/.local/bin/otaripper"

export PATH

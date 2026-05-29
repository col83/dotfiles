
# Interactive shell only
[[ $- != *i* ]] && return


# Aliases

alias cls='clear; echo'

if command -v watch >/dev/null 2>&1; then
    alias watch='watch -c -n 1 -p -t -x'
fi

alias mnt='udisksctl mount -b'
alias umnt='udisksctl unmount -b'

# $PATH listing
lspath() {
    echo
    echo $PATH | tr ':' '\n' | sort | uniq
    echo
}

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
        ls -l "$@"
        echo
    }

    lll() {
        echo
        ls -lA "$@"
        echo
    }

fi


# Greeting
# Disable default greeting/noise
unset MAILCHECK

# Prompt
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
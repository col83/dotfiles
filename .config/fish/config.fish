
# Interactive shell only
if status is-interactive

    # Aliases

    alias cls='clear; echo'

    alias watch='watch -c -n 1 -p -t -x'

    alias mnt='udisksctl mount -b'
    alias umnt='udisksctl unmount -b'

    # $PATH listing
    function lspath
        echo
        echo $PATH | tr ' ' '\n' | sort | uniq
        echo
    end

    # fastfetch
    if command -v fastfetch >/dev/null

        function ff
            echo
            command fastfetch
            echo
        end

    end

    # eza replacements
    if command -v eza >/dev/null

        function ls
            echo
            command eza $argv
            echo
        end

        function ll
            echo
            command eza -l $argv
            echo
        end

        function lll
            echo
            command eza -la $argv
            echo
        end

    else

        function ll
            echo
            ls -l $argv
            echo
        end

        function lll
            echo
            ls -lA $argv
            echo
        end

    end

end


# Greeting
# Disable default greeting/noise
set -g fish_greeting ""

# Prompt
function fish_prompt
    set -l priv_symbol '$'
    if test (id -u) -eq 0
        set priv_symbol '#'
    end

    set -l color_user_normal (set_color green)
    set -l color_user_root   (set_color red)
    set -l color_host        (set_color cyan)
    set -l color_path        (set_color blue)
    set -l color_home        (set_color yellow)
    set -l color_reset       (set_color normal)

    set -l user (whoami)
    set -l host (string split -m1 '.' $hostname)[1]

    set -l user_color $color_user_normal
    if test $user = 'root'
        set user_color $color_user_root
    end

    set -l path_color $color_path
    set -l current_path $PWD

    if test $current_path = $HOME
        set current_path '~'
        set path_color $color_home
    else if string match -q "$HOME/*" $current_path
        set current_path (string replace -r "^$HOME/" "~/" $current_path)
        set path_color $color_home
    end

    if test $current_path != '/'
        set current_path "$current_path/"
    end

    string join '' -- \
        $user_color $user $color_reset '@' \
        $color_host $host $color_reset ' ' \
        $path_color $current_path $color_reset ' ' \
        $priv_symbol ' '
end

# PATH

set OLD_PATH $PATH

# Main local binaries
fish_add_path "$HOME/.local/bin"

# Python
fish_add_path "$HOME/.local/bin/uv"

# Android Tools
fish_add_path "$HOME/.local/bin/platform-tools"
fish_add_path "$HOME/.local/bin/otaripper"
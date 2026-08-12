#!/usr/bin/env bash

set -euo pipefail

install_dotfiles() {

    local target="$1"

    cp .bash_profile .bashrc "$target/"

    mkdir -p "$target/.config" "$target/.nano"

    cp -a .config/. "$target/.config/"
    cp -a .nano/. "$target/.nano/"
    cp .nanorc "$target/"
    cp .vimrc "$target/"

}

if [ "$(id -u)" -eq 0 ]; then
    install_dotfiles "/root"
    exit 0
fi

install_dotfiles "$HOME"

# vim: set ts=2 sw=2 et:


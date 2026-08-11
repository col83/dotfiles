#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
clear

_minimal() {

    local packages=(
      bash-completion
      eza
      fd
      fish
      git
      gzip
      less
      mandoc
      termux-services
      unzip
      uv
      wget
      which
      xz-utils
    )

    pkg install -y "${packages[@]}"

}

_base() {

    local packages=(
      android-tools
      bat
      bison
      clang
      cpio
      deno
      ffmpeg
      lz4
      make
      mandoc
      ncurses
      perl
      pkg-config
      python
      shc
      termux-tools
      yt-dlp
    )

    pkg install -y "${packages[@]}"

}


# mirrors
cat <<EOF > $PREFIX/etc/apt/sources.list
deb https://packages.termux.dev/apt/termux-main stable main
deb https://grimler.se/termux/termux-main stable main
EOF

echo; apt update -y
echo; apt install -y ca-certificates
echo; apt upgrade -y; echo
_minimal

echo; echo "Base setup completed."

# sv-enable sshd
# sv-enable ssh-agent

_base

root_packages=(
btop
ethtool
hping3
macchanger
wireless-tools
)


if su -c 'id' >/dev/null 2>&1; then

    echo; echo "Root access granted. Installing root packages."; echo

    # root repo
    # mkdir -p "$PREFIX/etc/apt/sources.list.d"
    # echo "deb https://packages.termux.dev/apt/termux-root root stable" >> "$PREFIX/etc/apt/sources.list.d/root.list"
    pkg install -y root-repo; echo

    pkg update -y; echo; pkg install -y "${root_packages[@]}"

    # echo "su -c 'bash'" > "$HOME/.profile"

else

    echo; echo "No root access. Skipping root packages."; echo

fi

mkdir -p "$HOME/.termux"
cat <<EOF > "$HOME/.termux/termux.properties"
allow-external-apps = true
disable-terminal-session-change-toast = true
terminal-transcript-rows = 3000
terminal-cursor-blink-rate = 1000
EOF

echo "" > "$PREFIX/etc/motd"

echo "y" | termux-setup-storage

echo
if chsh -s "$(command -v fish)"; then
    exit 0
fi

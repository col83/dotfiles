#!/usr/bin/bash
set -euo pipefail


ENABLE_INTEROP=true
SHELL_TO_INSTALL="fish"


if [ ! -f "/etc/wsl-distribution.conf" ]; then
    echo; echo "Not a WSL distribution. Aborting."; echo
    exit 0
fi

if [[ $EUID -ne 0 ]]; then
    echo; echo "Run as root"; echo
    exit 1
fi

LOCKFILE="/etc/wsl.lock"
if [ -f "${LOCKFILE}" ]; then
    echo; echo "Lockfile exists: $LOCKFILE. Aborting."; echo
    exit 0
fi


# dont use "ID_LIKE"
if [ -f "/etc/os-release" ]; then

    # shellcheck disable=SC1091
    source "/etc/os-release"
    OS_ID="${ID}"

elif [ -f "/usr/lib/os-release" ]; then

    # shellcheck disable=SC1091
    source "/usr/lib/os-release"
    OS_ID="${ID}"

else
    echo; echo "ERROR: /etc/os-release not found"; echo
    exit 2
fi


cat << 'EOF' > "$HOME/.profile"

#umask 022

if [ -n "${BASH_VERSION:-}" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

EOF


setup_interop_utils() {

local INTEROP_DIR="$HOME/.local/bin"
mkdir -p "${INTEROP_DIR}"

cat << 'EOF' > "${INTEROP_DIR}/pbcopy"
#!/usr/bin/bash

clip.exe
EOF
chmod +x "${INTEROP_DIR}/pbcopy"

cat << 'EOF' > "${INTEROP_DIR}/pbpaste"
#!/usr/bin/bash

powershell.exe -NoProfile -Command Get-Clipboard | tr -d '\r'
EOF
chmod +x "${INTEROP_DIR}/pbpaste"

cat << 'EOF' > "${INTEROP_DIR}/open"
#!/usr/bin/bash

if [ "$#" -lt 1 ]; then echo "Usage: open <url-or-path>" >&2; exit 1; fi
target="$*"
[ -e "$1" ] && target="$(wslpath -w "$1")"

cmd.exe /c start "" "$target" >/dev/null 2>&1
EOF
chmod +x "${INTEROP_DIR}/open"

cat << 'EOF' > "${INTEROP_DIR}/xdg-open"
#!/usr/bin/bash

exec open "$@"
EOF
chmod +x "${INTEROP_DIR}/xdg-open"

}

setup_network() {

echo; systemctl disable --now systemd-resolved 1>/dev/null
systemctl daemon-reload

chattr -i "/etc/resolv.conf" 2>/dev/null || true
rm -f /etc/resolv.conf
cat >/etc/resolv.conf <<EOF

nameserver 8.8.8.8
nameserver 8.8.4.4
options edns0

EOF
chattr +i "/etc/resolv.conf" 2>/dev/null || true

chattr -i "/etc/hosts" 2>/dev/null || true
cat >/etc/hosts <<EOF

127.0.0.1     localhost
::1           localhost

::1           ip6-localhost ip6-loopback
fe00::0       ip6-localnet
ff00::0       ip6-mcastprefix
ff02::1       ip6-allnodes
ff02::2       ip6-allrouters

0.0.0.0       0.0.0.0

EOF
chattr +i "/etc/hosts" 2>/dev/null || true

}
setup_network


chattr -i "/etc/hostname" 2>/dev/null || true
echo "localhost" > "/etc/hostname"
chattr +i "/etc/hostname" 2>/dev/null || true


cat << 'EOF' > "/etc/wsl.conf"
[boot]
systemd=true

[automount]
enabled=true

[gpu]
enabled=true

[network]
generateHosts=false
generateResolvConf=false
EOF

if [ "${ENABLE_INTEROP}" == true ]; then
    cat << 'EOF' >> "/etc/wsl.conf"

[interop]
enabled=true
appendWindowsPath=false
EOF

    setup_interop_utils
fi

setup_lang() {

if [ ! -f "/etc/locale.gen.bak" ]; then
    cp "/etc/locale.gen" "/etc/locale.gen.bak"
fi

cat << 'EOF' > "/etc/locale.gen"
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
EOF

echo; locale-gen

export LANGUAGE=en_US.UTF-8
echo 'LANG=en_US.UTF-8' > "/etc/locale.conf"

}
setup_lang

# dont use "ID_LIKE"
case "$OS_ID" in
    ubuntu|debian)
        pkg_manager=apt-get
        pkg_manager_args=(install -y -q --no-install-recommends)
        ;;
    arch|blackarch|cachyos)
        pkg_manager=pacman
        pkg_manager_args=(-Syyuu --needed --noconfirm)
        ;;
    *)
        echo; echo "ERROR: unsupported system $OS_ID"
        exit 1
        ;;
esac

echo

# archlinux names for now.
packages=(
7zip
android-file-transfer
android-tools
base-devel
bat
bc
bind
bison
brotli
btop
ca-certificates
cpio
curl
dos2unix
dtc
eza
fd
flex
fzf
git
jq
make
man-db
nano
ncurses
neovim
openssh
pkgconf
pv
ripgrep
rsync
strace
tar
tmux
unzip
vim
wget
which
xdg-user-dirs
zip
zlib
"$SHELL_TO_INSTALL"
)

declare -A pkg_map
case "$OS_ID" in
    ubuntu|debian)
        pkg_map=(
            [android-tools]="adb fastboot"
            [base-devel]="build-essential libelf-dev"
            [bind]="bind9 bind9-dnsutils"
            [dtc]="device-tree-compiler"
            [fd]="fd-find"
            [ncurses]="libncurses-dev libncurses6"
            [openssh]="openssh-client"
        )
        ;;
    arch)
        pkg_map=()
        ;;
esac

setup_system() {

  echo > "/etc/motd"

  setup_system_debian() {

    for file in update-motd.sh Z97-byobu.sh Z99-cloud-locale-test.sh Z99-cloudinit-warnings.sh; do
        rm -f "/etc/profile.d/${file}"
    done

    for dir in ubuntu-advantage update-motd.d; do
        rm -rf "/etc/${dir:?}/"
    done

  }

  setup_system_arch() {

    :

  }

  case "$OS_ID" in
    ubuntu|debian)
        setup_system_debian
        ;;
    arch|blackarch|cachyos)
        setup_system_arch
        ;;
  esac

}
setup_system

# "/etc/apt/sources.list.d/*.sources" always exist.
setup_apt() {

  case "$OS_ID" in
    ubuntu)

        if [ ! -f "/etc/apt/sources.list.d/ubuntu.sources.bak" ]; then
            cp "/etc/apt/sources.list.d/ubuntu.sources" "/etc/apt/sources.list.d/ubuntu.sources.bak"
        fi

        sed -i 's/^# deb-src/deb-src/' "/etc/apt/sources.list.d/ubuntu.sources"

        ;;
    debian)

        if [ ! -f "/etc/apt/sources.list.d/debian.sources.bak" ]; then
            cp "/etc/apt/sources.list.d/debian.sources" "/etc/apt/sources.list.d/debian.sources.bak"
        fi

        sed -i 's/^# deb-src/deb-src/' "/etc/apt/sources.list.d/debian.sources"

        ;;
  esac

  apt-get update -q
  apt-get upgrade -y -q

}

setup_pacman() {

cat << 'EOF' > "/etc/pacman.conf"
[options]
# CacheDir = /var/cache/pacman/pkg/
HoldPkg = pacman glibc

Architecture = auto
Color
VerbosePkgLists
ParallelDownloads = 3
ILoveCandy

SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional
RemoteFileSigLevel = Required

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist
EOF

MONTH=$(date +%m)

cat << EOF > "/etc/pacman.d/mirrorlist"

## Germany
Server = https://mirror.pkgbuild.com/\$repo/os/\$arch

## US
# Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch

## Archive
# Server = https://archive.archlinux.org/repos/2026/${MONTH}/01/\$repo/os/\$arch

EOF

pacman-key --init
pacman-key --populate archlinux
pacman-key --populate "${OS_ID}" 2>/dev/null || true

}

case "$OS_ID" in
    ubuntu|debian)
        setup_apt; echo
        ;;
    arch|blackarch|cachyos)
        setup_pacman; echo
        ;;
esac


resolved_packages=()

for pkg in "${packages[@]}"; do
    if [[ -v pkg_map["$pkg"] ]]; then
        read -r -a mapped_pkgs <<< "${pkg_map[$pkg]}"
        resolved_packages+=("${mapped_pkgs[@]}")
    else
        resolved_packages+=("$pkg")
    fi
done

"$pkg_manager" "${pkg_manager_args[@]}" "${resolved_packages[@]}"; echo


# xdg-user-dirs-update
mkdir -p "$HOME/Documents"

if command -v "$SHELL_TO_INSTALL" >/dev/null 2>&1; then
    new_shell=$(command -v "$SHELL_TO_INSTALL")

    # if shell is fish then just ignore warning
    if [ "$SHELL" != "$new_shell" ]; then
        chsh -s "$new_shell" 1>/dev/null
    fi
fi

touch "${LOCKFILE}"

# not every shell read .profile
if command -v "$SHELL_TO_INSTALL" >/dev/null 2>&1; then
    "$SHELL_TO_INSTALL"
fi


#!/bin/bash
# SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Installs Glance in one go: the packages it's built with (pacman, dnf, zypper or apt), the build
# and install into ~/.local, the plugin path for Plasma, and a restart of Plasma to load it. Built
# here, against this system's own Qt and Plasma: that's why there's no ready-made package. Run it
# again to update. README's Install section has the same steps by hand.
#
#   ./install.sh               everything, asking before the packages and the restart
#   ./install.sh --no-deps     skip the packages (already there, or installed by hand)
#   ./install.sh --no-restart  don't restart Plasma (log out and back in instead)
#   ./install.sh --yes         don't ask
#   ./install.sh --uninstall   remove Glance and its plugin path
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

deps=1
restart=1
assume_yes=0
uninstall=0
for arg in "$@"; do
    case "$arg" in
        --no-deps) deps=0 ;;
        --no-restart) restart=0 ;;
        --yes|-y) assume_yes=1 ;;
        --uninstall) uninstall=1 ;;
        -h|--help) sed -n '5,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done

bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)
step() { echo; echo "${bold}==> $*${normal}"; }
fail() { echo "${bold}Error:${normal} $*" >&2; exit 1; }
ask() {
    # ask "question": yes unless the answer starts with n; --yes or no terminal: yes
    [ "$assume_yes" = 1 ] && return 0
    [ -t 0 ] || return 0
    local answer
    read -r -p "$1 [Y/n] " answer
    [[ ! "$answer" =~ ^[Nn] ]]
}

[ "$(id -u)" -ne 0 ] || fail "run it as yourself, not root: it installs into your home folder (sudo is asked for the packages only)."

env_file="$HOME/.config/plasma-workspace/env/glance.sh"
qml_path="$HOME/.local/lib/qml"

restart_plasma() {
    [ "$restart" = 1 ] || return 0
    command -v systemctl >/dev/null && systemctl --user is-active --quiet plasma-plasmashell 2>/dev/null || {
        echo "Plasma isn't running here as a systemd service: log out and back in to load Glance."
        return 0
    }
    if ask "Restart Plasma now to load it? (the panels redraw for a moment)"; then
        systemctl --user restart plasma-plasmashell
        # KRunner picks up the menu search when it starts again
        command -v kquitapp6 >/dev/null && kquitapp6 krunner >/dev/null 2>&1 || true
    else
        echo "Restart it later with: systemctl --user restart plasma-plasmashell (or log out and back in)"
    fi
}

if [ "$uninstall" = 1 ]; then
    step "Removing Glance"
    make uninstall
    rm -f "$env_file"
    command -v systemctl >/dev/null && systemctl --user unset-environment QML_IMPORT_PATH 2>/dev/null || true
    restart_plasma
    echo; echo "Glance is removed. Its settings stay in Plasma's config until the widget is removed from the panel."
    exit 0
fi

# --- Plasma 6 ---------------------------------------------------------------------------------
if command -v plasmashell >/dev/null; then
    version=$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1 || true)
    case "$version" in
        6.*|"") ;;
        *) fail "Glance needs Plasma 6; this is Plasma $version." ;;
    esac
else
    echo "plasmashell isn't here: Glance runs in Plasma 6. Building anyway."
fi

# --- 1. The packages ----------------------------------------------------------------------------
if [ "$deps" = 1 ]; then
    step "1/4 The build tools and libraries"
    if command -v pacman >/dev/null; then
        cmd=(sudo pacman -S --needed git base-devel cmake extra-cmake-modules qt6-base qt6-declarative
            kwindowsystem kservice kconfig kcoreaddons libplasma libpipewire gettext
            layer-shell-qt kirigami-addons)
    elif command -v dnf >/dev/null; then
        cmd=(sudo dnf install git gcc-c++ make cmake extra-cmake-modules qt6-qtbase-devel qt6-qtdeclarative-devel
            kf6-kwindowsystem-devel kf6-kservice-devel kf6-kconfig-devel kf6-kcoreaddons-devel
            libplasma-devel pipewire-devel gettext layer-shell-qt kf6-kirigami-addons)
    elif command -v zypper >/dev/null; then
        cmd=(sudo zypper install git gcc-c++ make cmake kf6-extra-cmake-modules qt6-base-devel qt6-declarative-devel
            kf6-kwindowsystem-devel kf6-kservice-devel kf6-kconfig-devel kf6-kcoreaddons-devel
            libplasma6-devel pipewire-devel gettext-runtime layer-shell-qt6 kirigami-addons6)
    elif command -v apt-get >/dev/null; then
        cmd=(sudo apt-get install git build-essential cmake extra-cmake-modules qt6-base-dev qt6-declarative-dev
            libkf6windowsystem-dev libkf6service-dev libkf6config-dev libkf6coreaddons-dev
            libplasma-dev libpipewire-0.3-dev gettext layer-shell-qt)
    else
        cmd=()
        echo "No pacman, dnf, zypper or apt here: install the libraries listed under Requirements in"
        echo "README.md yourself, then run ./install.sh --no-deps."
        exit 1
    fi
    [ "$assume_yes" = 1 ] && case "${cmd[1]}" in
        pacman) cmd+=(--noconfirm) ;;
        *) cmd+=(-y) ;;
    esac
    echo "${cmd[*]}"
    if ask "Install these packages? (asks for your password)"; then
        "${cmd[@]}" || fail "the packages didn't install. A name your distribution doesn't have? Install
       that one under its own name (README.md, Requirements), then run ./install.sh --no-deps.
       Tell us in an issue too: https://github.com/divinae/glance-plasmoid/issues"
    else
        echo "Skipped: building with what's there."
    fi
else
    step "1/4 The build tools and libraries: skipped (--no-deps)"
fi

# --- 2. Build and install -------------------------------------------------------------------
step "2/4 Building and installing into ~/.local"
command -v make >/dev/null && command -v cmake >/dev/null || fail "make and cmake are missing: run without --no-deps, or install them."
make install || fail "the build stopped. The lines above name what's missing (a CMake package or a
       header): install it, then run ./install.sh again."
[ -f "$qml_path/com/dv/glance/private/qmldir" ] || fail "the plugin isn't in $qml_path after the install."

# --- 3. The plugin path ---------------------------------------------------------------------
step "3/4 Letting Plasma find the plugin"
mkdir -p "$(dirname "$env_file")"
cat > "$env_file" <<'EOF'
# Glance's plugin (com.dv.glance.private) is in ~/.local/lib/qml: Plasma looks there too.
# Written by Glance's install.sh; ./install.sh --uninstall removes it.
export QML_IMPORT_PATH="$HOME/.local/lib/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
EOF
echo "$env_file (read at each login)"
# For this session as well, so a restart is enough
if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
    current=$(systemctl --user show-environment | sed -n 's/^QML_IMPORT_PATH=//p')
    case ":$current:" in
        *":$qml_path:"*) ;;
        *) systemctl --user set-environment QML_IMPORT_PATH="$qml_path${current:+:$current}" ;;
    esac
fi

# --- 4. Load it -----------------------------------------------------------------------------
step "4/4 Loading it"
restart_plasma

echo
echo "${bold}Glance is installed.${normal} Add it to a vertical panel: right click the panel > Add or Manage"
echo "Widgets, search for Glance and drag it onto the panel. No vertical panel yet: right click the"
echo "desktop > Add Panel > Empty Panel, then in its configuration set Position to Left or Right."
echo "To update later: git pull && ./install.sh"

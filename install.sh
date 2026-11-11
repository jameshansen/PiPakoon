#!/bin/bash
# PiPakoon: installs Pakoon 0, 1 and 2 on 64-bit Raspberry Pi OS.
#
# Run it from the Pi's desktop, from the folder it came in.
# The games go into ~/Games/Pakoon, with one entry in the Games menu and one shortcut on
# the desktop, both opening the launcher. Run it again to reinstall or remove.
set -u
: "${HOME:?}"

TITLE="PiPakoon"
GAME="Pakoon"
HERE=$(dirname "$(readlink -f "$0")")
RUNTIME="$HERE/runtime.tar.xz"
RUNTIME_FILES=267   # entries in runtime.tar.xz, for the progress bar
ICON="$HERE/icon.png"
DEST="$HOME/Games/Pakoon"
# The Pi's taskbar finds a window's icon through a menu entry named after the window,
# and the launcher and the games all call theirs "pakoon". The desktop shortcut carries
# the same name.
MENU="${XDG_DATA_HOME:-$HOME/.local/share}/applications/pakoon.desktop"
SHORTCUT="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")/pakoon.desktop"
# What the games load at run time. Raspberry Pi OS with desktop has all of it.
PACKAGES="libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-ttf-2.0-0 libglu1-mesa libvorbisfile3 fonts-dejavu-core"

if ! command -v zenity >/dev/null || [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  echo "Run this installer from the Raspberry Pi desktop. It needs zenity (sudo apt install zenity)." >&2
  exit 1
fi

# A page with up to three buttons, left to right: --cancel-label, --ok-label, --extra-button.
# OK returns 0. The extra button prints its label and returns 1, like Cancel.
page() { zenity --question --title="$TITLE" --width=560 --icon="$ICON" "$@" 2>/dev/null; }
note() { zenity --info --title="$TITLE" --width=560 --icon="$ICON" --text="$1" 2>/dev/null; }
fail() { zenity --error --title="$TITLE" --width=560 --no-markup --text="$1" 2>/dev/null; exit 1; }
busy() { zenity --progress --title="$TITLE" --width=560 --no-cancel --auto-close "$@" 2>/dev/null; }

# Prints progress for the bar on stdout (a number, or "# text"); errors go to stderr.
install_files() (
  set -e -o pipefail
  mkdir -p "$DEST" "$(dirname "$MENU")" "$(dirname "$SHORTCUT")"
  echo "# Unpacking the games..."
  count=0
  # Settings, scores and progress are files the games add beside their own, so unpacking
  # over an earlier install leaves them in place.
  tar -xvJf "$RUNTIME" -C "$DEST" | while read -r _; do
    count=$((count + 1))
    if [ $((count % 4)) -eq 0 ] && [ "$count" -lt "$RUNTIME_FILES" ]; then echo $((count * 92 / RUNTIME_FILES)); fi
  done
  echo 94
  echo "# Adding the menu entry and the desktop shortcut..."
  cp "$ICON" "$DEST/icon.png"
  cat >"$MENU" <<EOF
[Desktop Entry]
Type=Application
Name=$GAME
Comment=Three driving games by Mikko Oksalahti
Exec="$DEST/pakoon"
Icon=$DEST/icon.png
Terminal=false
Categories=Game;
StartupWMClass=pakoon
EOF
  rm -f "$SHORTCUT"
  cp "$MENU" "$SHORTCUT"
  echo 97
  echo "# Checking that the games start..."
  missing=$(cd "$DEST" && ldd launcher pakoon0/Pakoon pakoon1/Pakoon pakoon2/Pakoon | awk '/not found/ {print $1}' | sort -u | tr '\n' ' ')
  if [ -n "$missing" ]; then
    echo "This Raspberry Pi lacks: $missing" >&2
    echo "Add them with: sudo apt install $PACKAGES" >&2
    exit 1
  fi
  (cd "$DEST" && ./launcher --check) >&2
)

[ "$(dpkg --print-architecture 2>/dev/null)" = arm64 ] ||
  fail "This installer is for 64-bit Raspberry Pi OS. This system is $(uname -m)."
[ -f "$RUNTIME" ] && [ -f "$ICON" ] ||
  fail "A file that belongs next to install.sh is missing. Download the whole package again."

if [ -e "$DEST/pakoon" ]; then
  choice=$(page --text="<b>$GAME is already installed on this Raspberry Pi.</b>\n\nReinstall sets it up again and keeps your settings, scores and progress. Remove deletes the games, along with those, and the shortcuts." \
    --cancel-label="Cancel" --ok-label="Reinstall" --extra-button="Remove")
  status=$?
  if [ "$choice" = "Remove" ]; then
    rm -rf "$DEST" "$MENU" "$SHORTCUT"
    note "$GAME has been removed from this Raspberry Pi."
    exit 0
  fi
  [ "$status" -eq 0 ] || exit 0
else
  page --text="<b>Welcome to the $TITLE Installer</b>\n\nThis installer will set up Pakoon 0, 1 and 2, the driving games by Mikko Oksalahti, on this Raspberry Pi. It puts them in the Games folder in your home folder, adds Pakoon to the Games menu and puts a shortcut on the desktop. The shortcut opens a launcher where you pick the game to play.\n\nThe games take about 50 MB." \
    --cancel-label="Cancel" --ok-label="Install" || exit 0
  [ "$(df -k --output=avail "$HOME" | tail -1)" -ge 100000 ] ||
    fail "There is less than 100 MB free in your home folder. Free up some space and run the installer again."
fi

log=$(mktemp)
{ install_files 2>"$log"; status=$?; echo 100; exit $status; } | busy --percentage=0 --text="Installing $GAME..."
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
  fail "The install did not finish. The games need 64-bit Raspberry Pi OS 13 (trixie) or newer.

$(tail -5 "$log")"
fi
rm -f "$log"

page --text="<b>$GAME is installed.</b>\n\nIt is in the Games menu and on the desktop. Pick Pakoon 0, 1 or 2 in the launcher with the arrow keys and Enter, or with the mouse. In a game, Esc opens its menu, and leaving the game brings the launcher back." \
  --cancel-label="Close" --ok-label="Play Now" && exec setsid "$DEST/pakoon" >/dev/null 2>&1 &

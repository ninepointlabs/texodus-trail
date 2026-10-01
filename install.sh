#!/bin/bash
# Install The Texodus Trail for the current user.
#
#   ./install.sh               install (or update) the game
#   ./install.sh --uninstall   remove it, keep your save and Top Ten
#   ./install.sh --purge       remove it and the save too
#
# Everything lands in your home directory; nothing runs as root:
#
#   ~/.local/share/texodus-trail/                      the game
#   ~/.local/bin/texodus                               launcher symlink
#   ~/.local/share/applications/texodus-trail.desktop  app launcher entry
#   ~/.local/share/icons/hicolor/256x256/apps/texodus-trail.png
#
# Saves live in ~/.local/state/texodus-trail/ and survive reinstalls.

set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
state="${XDG_STATE_HOME:-$HOME/.local/state}"
dest="$data/texodus-trail"
bin="$HOME/.local/bin/texodus"
desktop="$data/applications/texodus-trail.desktop"
icon="$data/icons/hicolor/256x256/apps/texodus-trail.png"
marker="X-Texodus-Trail-Install=1"

die() { echo "install.sh: $*" >&2; exit 1; }

# Only ever delete things we put there.
ours_dir() { [[ -d $1 && ! -L $1 && -f $1/app/shell.qml && -f $1/.texodus-trail ]]; }
ours_link() { [[ -L $1 && $(readlink -- "$1") == "$dest/bin/texodus" ]]; }
ours_desktop() { [[ -f $1 && ! -L $1 ]] && grep -qxF "$marker" -- "$1"; }

stop_game() {
  if command -v quickshell >/dev/null 2>&1 && [[ -d $dest/app ]]; then
    quickshell kill --path "$dest/app" >/dev/null 2>&1 || true
  fi
}

remove() {
  stop_game
  if [[ -e $dest || -L $dest ]]; then
    ours_dir "$dest" && rm -rf -- "$dest" || echo "install.sh: $dest isn't ours; leaving it alone" >&2
  fi
  if [[ -e $bin || -L $bin ]]; then
    ours_link "$bin" && rm -f -- "$bin" || echo "install.sh: $bin isn't ours; leaving it alone" >&2
  fi
  if [[ -e $desktop ]]; then
    ours_desktop "$desktop" && rm -f -- "$desktop" || echo "install.sh: $desktop isn't ours; leaving it alone" >&2
  fi
  [[ -f $icon && ! -L $icon ]] && rm -f -- "$icon"
  return 0
}

case "${1:-}" in
  --uninstall)
    remove
    echo "The Texodus Trail is gone. Your save and Top Ten are still in $state/texodus-trail."
    exit 0
    ;;
  --purge)
    remove
    [[ -d $state/texodus-trail && ! -L $state/texodus-trail ]] && rm -rf -- "$state/texodus-trail"
    echo "The Texodus Trail is gone, save and all. The graves by the road have been paved over."
    exit 0
    ;;
  "") ;;
  *) die "unknown option '$1' (use --uninstall or --purge)" ;;
esac

command -v quickshell >/dev/null 2>&1 || die "quickshell is not installed (it ships with Omarchy; elsewhere: pacman -S quickshell)"
command -v jq >/dev/null 2>&1 || echo "install.sh: jq not found; the window won't auto-float (the game still runs)" >&2

if [[ -e $dest || -L $dest ]] && ! ours_dir "$dest"; then
  die "$dest exists and isn't a Texodus Trail install; move it out of the way first"
fi
if [[ -e $bin || -L $bin ]] && ! ours_link "$bin"; then
  die "$bin exists and isn't our launcher; move it out of the way first"
fi
if [[ -e $desktop ]] && ! ours_desktop "$desktop"; then
  die "$desktop exists and wasn't written by this installer"
fi

stop_game

# Stage next to the destination and swap it in, so a half-copied game never
# exists under the real name.
mkdir -p "$data" "$HOME/.local/bin" "$(dirname "$desktop")" "$(dirname "$icon")"
stage="$(mktemp -d "$data/.texodus-trail.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT
cp -r "$src/app" "$src/bin" "$stage/"
cp "$src/LICENSE" "$src/README.md" "$stage/" 2>/dev/null || true
touch "$stage/.texodus-trail"
chmod 755 "$stage" "$stage/bin/texodus"
if [[ -d $dest ]]; then rm -rf -- "$dest"; fi
mv -T -- "$stage" "$dest"
trap - EXIT

ln -sfn -- "$dest/bin/texodus" "$bin"
cp "$src/assets/icon.png" "$icon"

tmp="$(mktemp "$(dirname "$desktop")/.texodus-trail.XXXXXX")"
cat >"$tmp" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=The Texodus Trail
GenericName=Road trip simulator
Comment=You have died of state income tax. A Californian's journey to Texas.
Exec=$dest/bin/texodus
Icon=texodus-trail
Terminal=false
Categories=Game;
Keywords=oregon;trail;texas;california;game;retro;
StartupNotify=false
$marker
DESKTOP
chmod 644 "$tmp"
mv -T -- "$tmp" "$desktop"

command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$data/icons/hicolor" >/dev/null 2>&1 || true

echo "Installed The Texodus Trail to $dest"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "Note: ~/.local/bin isn't on your PATH; launch it from the app menu or run $bin" ;; esac
echo "Play: texodus   ·   or find \"The Texodus Trail\" in your app launcher (Super + Space)"

#!/usr/bin/env bash
# Check a built AppImage the way a user on some other distribution would
# meet it: no Quickshell, Qt, Omarchy or Hyprland on the machine, an empty
# home directory.
#
#   packaging/appimage/test.sh dist/texodus-trail-<version>-x86_64.AppImage
#
# Needs desktop-file-validate, appstreamcli, Xvfb, xdotool and xprop
# (packaging/appimage/deps.sh installs them); with weston installed it
# also opens the game on a headless Wayland compositor.

set -euo pipefail

img="$(readlink -f "${1:?usage: test.sh <AppImage>}")"
tmp="$(mktemp -d)"
pids=()
cleanup() {
  for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
  wait 2>/dev/null || true
  rm -rf -- "$tmp"
}
trap cleanup EXIT

# CI runners have no FUSE; this is also what users without it do.
export APPIMAGE_EXTRACT_AND_RUN=1
# A user with nothing: empty home, no Omarchy theme, no hyprctl or jq on PATH.
export HOME="$tmp/home"
mkdir -p "$HOME"
unset XDG_STATE_HOME XDG_DATA_HOME XDG_CONFIG_HOME QT_QPA_PLATFORM WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
export XDG_RUNTIME_DIR="$tmp/run"
mkdir -m 700 "$XDG_RUNTIME_DIR"
path=""
IFS=: read -ra dirs <<<"$PATH"
for d in "${dirs[@]}"; do [[ -x $d/hyprctl ]] || path="${path:+$path:}$d"; done
export PATH="$path"
! command -v hyprctl >/dev/null || { echo "hyprctl still on PATH" >&2; exit 1; }

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok   $*"; }

# Logs from the game that mean something is missing or broken. (Quickshell
# prints INFO lines; Qt Multimedia may say there is no sound server.)
bad_log() { grep -E "qml|QML|Cannot load|not installed|could not load|Could not find the Qt platform plugin|TypeError|ReferenceError|undefined|Segmentation|Aborted" "$1" | grep -v "INFO" || true; }

echo "== contents"
(cd "$tmp" && "$img" --appimage-extract >/dev/null)
root="$tmp/squashfs-root"
desktop-file-validate "$root/texodus-trail.desktop" && desktop-file-validate "$root/usr/share/applications/texodus-trail.desktop" &&
  ok "desktop-file-validate: clean"
grep -qx "StartupWMClass=texodus-trail" "$root/texodus-trail.desktop" || fail "StartupWMClass"
version="$(sed -n 's/^X-AppImage-Version=//p' "$root/texodus-trail.desktop")"
[[ -n $version ]] || fail "X-AppImage-Version missing"
ok "X-AppImage-Version=$version, StartupWMClass=texodus-trail"
appstreamcli validate --no-net "$root/usr/share/metainfo/com.ninepointlabs.texodus_trail.metainfo.xml" >/dev/null &&
  ok "appstreamcli validate --no-net: clean"
for s in 16 24 32 48 64 128 256 512; do
  file "$root/usr/share/icons/hicolor/${s}x$s/apps/texodus-trail.png" | grep -q "PNG image data, $s x $s," || fail "icon ${s}x$s"
done
[[ -s $root/usr/share/icons/hicolor/scalable/apps/texodus-trail.svg ]] || fail "scalable icon"
[[ -s $root/texodus-trail.png && $(readlink "$root/.DirIcon") == texodus-trail.png ]] || fail "root icon / .DirIcon"
ok "icons: 16-512 px at the right sizes, scalable SVG, root icon, .DirIcon"
for p in platforms/libqxcb.so platforms/libqwayland.so platforms/libqoffscreen.so wayland-shell-integration/libxdg-shell.so multimedia/libffmpegmediaplugin.so; do
  [[ -f $root/usr/plugins/$p ]] || fail "missing Qt plugin $p"
done
ok "Qt plugins: xcb, wayland (+ xdg-shell), offscreen, FFmpeg multimedia"
for m in QtQuick/Shapes QtMultimedia; do
  [[ -f $root/usr/qml/$m/qmldir ]] || fail "missing QML module $m"
done
ok "QML modules: QtQuick.Shapes, QtMultimedia (Quickshell's own are built into it)"
missing="$(find "$root/usr" -type f -name '*.so*' -exec env LD_LIBRARY_PATH= ldd {} + 2>/dev/null | grep "not found" | sort -u || true)"
[[ -z $missing ]] || fail "libraries not found:"$'\n'"$missing"
ok "every bundled library resolves"

echo "== launcher"
"$img" --version | grep -qx "texodus $version" || fail "--version"
ok "--version: $("$img" --version)"
about="$("$img" --about)"
grep -q "^Built with  Quickshell 0\.3\.2.*, Qt 6\." <<<"$about" || fail "--about: $(grep 'Built with' <<<"$about")"
ok "--about: $(grep 'Built with' <<<"$about" | sed 's/  */ /g')"
if selftest="$("$img" --selftest 2>"$tmp/selftest.log")"; then
  grep -q "texodus: selftest ok" <<<"$selftest" || fail "--selftest: $selftest"
  ok "--selftest (offscreen): $selftest"
elif grep -qx "texodus: this version has no --selftest" "$tmp/selftest.log"; then
  echo "skip --selftest: this release predates it (the X11 and Wayland runs below still play it)"
else
  cat "$tmp/selftest.log" >&2
  fail "--selftest"
fi

echo "== X11 (Xvfb)"
Xvfb :87 -screen 0 1600x1000x24 -nolisten tcp >"$tmp/xvfb.log" 2>&1 &
pids+=($!)
export DISPLAY=:87
for _ in $(seq 50); do xprop -root >/dev/null 2>&1 && break; sleep 0.1; done
"$img" >"$tmp/x11.log" 2>&1 &
pids+=($!)
wid=""
for _ in $(seq 200); do
  wid="$(xdotool search --name '^The Texodus Trail$' 2>/dev/null | head -n 1 || true)"
  [[ -n $wid ]] && break
  sleep 0.1
done
[[ -n $wid ]] || { cat "$tmp/x11.log" >&2; fail "no game window under Xvfb"; }
sleep 3
class="$(xprop -id "$wid" WM_CLASS)"
grep -qx 'WM_CLASS(STRING) = "texodus-trail", "quickshell"' <<<"$class" || fail "WM_CLASS: $class"
ok "window opened; $class"
qs="$(pgrep -n -f -- '--no-duplicate --path .*/usr/share/texodus-trail/app' || true)"
[[ -n $qs ]] || fail "can't find the game process"
leaks="$(tr '\0' '\n' </proc/"$qs"/environ | grep -E '^(LD_LIBRARY_PATH|LD_PRELOAD|QT_PLUGIN_PATH|QML2?_IMPORT_PATH|PYTHONHOME|PYTHONPATH|QT_QPA_PLATFORM_PLUGIN_PATH)=' || true)"
[[ -z $leaks ]] || fail "the game's environment (inherited by its children) has: $leaks"
ok "no bundled library or plugin paths in the environment its children inherit"
[[ -d $HOME/.local/state/texodus-trail ]] || fail "save dir not created (Process child)"
ok "save dir created by its mkdir child: ~/.local/state/texodus-trail"
kill "$qs"
sleep 1
bad="$(bad_log "$tmp/x11.log")"
[[ -z $bad ]] || { cat "$tmp/x11.log" >&2; fail "warnings in the log: $bad"; }
ok "no QML/plugin warnings with no Omarchy theme (built-in colours)"
unset DISPLAY

echo "== Wayland (headless weston)"
if command -v weston >/dev/null 2>&1; then
  weston --backend=headless-backend.so --socket=tt-wl --idle-time=0 >"$tmp/weston.log" 2>&1 &
  pids+=($!)
  for _ in $(seq 50); do [[ -S $XDG_RUNTIME_DIR/tt-wl ]] && break; sleep 0.1; done
  WAYLAND_DISPLAY=tt-wl WAYLAND_DEBUG=client "$img" >"$tmp/wl.log" 2>&1 &
  pids+=($!)
  for _ in $(seq 200); do grep -q 'xdg_toplevel.*set_title("The Texodus Trail")' "$tmp/wl.log" && break; sleep 0.1; done
  sleep 3
  grep -q 'xdg_toplevel.*set_title("The Texodus Trail")' "$tmp/wl.log" || { tail -50 "$tmp/wl.log" >&2; fail "no xdg_toplevel window on Wayland"; }
  grep -q 'xdg_toplevel.*set_app_id("texodus-trail")' "$tmp/wl.log" || fail "Wayland app_id isn't texodus-trail"
  ok "window opened as an xdg_toplevel; app_id \"texodus-trail\""
  qs="$(pgrep -n -f -- '--no-duplicate --path .*/usr/share/texodus-trail/app' || true)"
  [[ -n $qs ]] && kill "$qs"
  sleep 1
  bad="$(grep -v '^\[' "$tmp/wl.log" | grep -v ' -> \| <- \|^ *$' >"$tmp/wl-app.log" || true; bad_log "$tmp/wl-app.log")"
  [[ -z $bad ]] || { cat "$tmp/wl-app.log" >&2; fail "warnings in the log: $bad"; }
  ok "no QML/plugin warnings"
else
  echo "skip weston isn't installed"
fi

echo "== desktop entry"
export XDG_DATA_HOME="$tmp/data"
"$img" --install-desktop-entry >/dev/null
entry="$XDG_DATA_HOME/applications/texodus-trail.desktop"
desktop-file-validate "$entry" || fail "installed desktop file doesn't validate"
grep -qx "Exec=\"$img\"" "$entry" || fail "Exec: $(grep ^Exec= "$entry")"
grep -qx "TryExec=$img" "$entry" || fail "TryExec"
[[ $(find "$XDG_DATA_HOME/icons" -name 'texodus-trail.*' | wc -l) == 9 ]] || fail "icons not installed"
"$img" --install-desktop-entry >/dev/null || fail "--install-desktop-entry isn't idempotent"
ok "--install-desktop-entry: valid entry, Exec=\"\$APPIMAGE\", 9 icons; runs twice"
"$img" --remove-desktop-entry >/dev/null
left="$(find "$XDG_DATA_HOME" -type f ! -name 'mimeinfo.cache' ! -name 'icon-theme.cache')"
[[ -z $left ]] || fail "left behind: $left"
ok "--remove-desktop-entry: everything it added is gone"
echo "do-not-touch" >"$entry"
! "$img" --install-desktop-entry >/dev/null 2>&1 || fail "overwrote a desktop file it didn't write"
! "$img" --remove-desktop-entry >/dev/null 2>&1 || fail "removed a desktop file it didn't write"
grep -qx "do-not-touch" "$entry" || fail "touched a desktop file it didn't write"
ok "leaves a texodus-trail.desktop from another install (install.sh) alone"

echo "all checks passed: $(basename "$img") ($(du -m "$img" | cut -f1) MB)"

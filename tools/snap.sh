#!/bin/bash
# Headless screenshots of the game (no compositor, no window):
#   tools/snap.sh <outdir> wait:2000 shot:title.png start:tech travel:3 shot:road.png ...
# Uses stub Quickshell modules from tools/stub and a throwaway state dir.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$(realpath -m "$1")"; shift
mkdir -p "$out" "$out/state/texodus-trail"
theme="${XDG_STATE_HOME:-$HOME/.local/state}"
export QML_IMPORT_PATH="$here/stub" QML_XHR_ALLOW_FILE_READ=1 QML_XHR_ALLOW_FILE_WRITE=1 QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1
# the stub reads the real theme but keeps saves out of your real state dir
mkdir -p "$out/state/omarchy/current"
ln -sfn "$theme/omarchy/current/theme" "$out/state/omarchy/current/theme"
exec timeout 300 qml6 "$here/snap.qml" -- "$out" "$@" "--env=XDG_STATE_HOME=$out/state" "--env=HOME=$HOME" "--env=USER=$USER"

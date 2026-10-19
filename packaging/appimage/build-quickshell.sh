#!/usr/bin/env bash
# Build Quickshell from source against the Qt in $QT_DIR, with only what The
# Texodus Trail uses: a FloatingWindow on Wayland or X11, FileView, Process,
# IpcHandler (unix sockets), the clipboard. Everything else (layer shell,
# Hyprland/i3 IPC, PipeWire, MPRIS, PAM, polkit, tray, notifications, ...) is
# turned off. (The same script as Hyprfall's AppImage build.)
#
#   QT_DIR=/path/to/qt/6.x.y/gcc_64 packaging/appimage/build-quickshell.sh <work dir> <install prefix>
#
# Ubuntu 22.04's wayland-protocols (1.25) and CLI11 (2.1) are older than
# Quickshell needs, so pinned releases of both are built first.

set -euo pipefail

work="$(mkdir -p "${1:?usage: build-quickshell.sh <work dir> <prefix>}" && cd "$1" && pwd)"
prefix="${2:?usage: build-quickshell.sh <work dir> <prefix>}"
: "${QT_DIR:?set QT_DIR to the Qt install (…/gcc_64)}"

QUICKSHELL_TAG=v0.3.2
QUICKSHELL_COMMIT=4f508be500dea6e5732cc3d50382a0048b17e7b1
WAYLAND_PROTOCOLS_VERSION=1.45
WAYLAND_PROTOCOLS_SHA256=4d2b2a9e3e099d017dc8107bf1c334d27bb87d9e4aff19a0c8d856d17cd41ef0
CLI11_VERSION=2.4.2
CLI11_SHA256=f2d893a65c3b1324c50d4e682c0cdc021dd0477ae2c048544f39eed6654b699a

deps="$work/deps"
jobs="${JOBS:-$(nproc)}"
export CC=gcc-12 CXX=g++-12
export PKG_CONFIG_PATH="$deps/share/pkgconfig:$deps/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

fetch() { # url sha256 file
  [[ -f $3 ]] || curl -fsSLo "$3" "$1"
  echo "$2  $3" | sha256sum -c -
}

cd "$work"

fetch "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/$WAYLAND_PROTOCOLS_VERSION/downloads/wayland-protocols-$WAYLAND_PROTOCOLS_VERSION.tar.xz" \
  "$WAYLAND_PROTOCOLS_SHA256" wayland-protocols.tar.xz
rm -rf wayland-protocols && mkdir wayland-protocols && tar -xf wayland-protocols.tar.xz -C wayland-protocols --strip-components=1
meson setup wayland-protocols/build wayland-protocols --prefix="$deps" -Dtests=false
meson install -C wayland-protocols/build

fetch "https://github.com/CLIUtils/CLI11/archive/refs/tags/v$CLI11_VERSION.tar.gz" "$CLI11_SHA256" cli11.tar.gz
rm -rf cli11 && mkdir cli11 && tar -xzf cli11.tar.gz -C cli11 --strip-components=1
cmake -S cli11 -B cli11/build -G Ninja -DCMAKE_INSTALL_PREFIX="$deps" \
  -DCLI11_BUILD_TESTS=OFF -DCLI11_BUILD_EXAMPLES=OFF -DCLI11_BUILD_DOCS=OFF
cmake --install cli11/build

if [[ ! -d quickshell/.git ]]; then
  git clone --quiet https://git.outfoxxed.me/quickshell/quickshell.git quickshell ||
    git clone --quiet https://github.com/quickshell-mirror/quickshell.git quickshell
fi
git -C quickshell fetch --quiet --tags origin
git -C quickshell checkout --quiet "$QUICKSHELL_COMMIT"
[[ $(git -C quickshell rev-parse "$QUICKSHELL_TAG^{commit}") == "$QUICKSHELL_COMMIT" ]] ||
  { echo "Quickshell $QUICKSHELL_TAG is not $QUICKSHELL_COMMIT" >&2; exit 1; }

cmake -S quickshell -B quickshell/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$QT_DIR;$deps" \
  -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DDISTRIBUTOR="The Texodus Trail AppImage (github.com/ninepointlabs/texodus-trail)" \
  -DCRASH_HANDLER=OFF \
  -DWAYLAND=ON \
  -DWAYLAND_WLR_LAYERSHELL=OFF -DWAYLAND_SESSION_LOCK=OFF -DWAYLAND_TOPLEVEL_MANAGEMENT=OFF \
  -DHYPRLAND=OFF \
  -DSCREENCOPY=OFF -DSCREENCOPY_ICC=OFF -DSCREENCOPY_WLR=OFF -DSCREENCOPY_HYPRLAND_TOPLEVEL=OFF \
  -DX11=ON -DI3=OFF \
  -DSERVICE_STATUS_NOTIFIER=OFF -DSERVICE_PIPEWIRE=OFF -DSERVICE_MPRIS=OFF -DSERVICE_PAM=OFF \
  -DSERVICE_POLKIT=OFF -DSERVICE_GREETD=OFF -DSERVICE_UPOWER=OFF -DSERVICE_NOTIFICATIONS=OFF \
  -DBLUETOOTH=OFF -DNETWORK=OFF
cmake --build quickshell/build -j "$jobs"
cmake --install quickshell/build
install -Dm644 -t "$prefix/share/licenses/quickshell" quickshell/LICENSE quickshell/LICENSE-GPL
LD_LIBRARY_PATH="$QT_DIR/lib" "$prefix/bin/quickshell" --version

#!/usr/bin/env bash
# Build The Texodus Trail AppImage: Quickshell (built from source) and Qt 6
# bundled, so it runs on any x86_64 Linux with glibc 2.35 or newer.
#
#   packaging/appimage/deps.sh            # once, as root, on Ubuntu 22.04
#   packaging/appimage/build.sh <version> [<game dir>]
#
# <game dir> holds the game's app/, bin/ and LICENSE (default: this
# checkout); the AppImage workflow points it at an older tag to backfill an
# AppImage for a release made before this script existed. Everything else
# (icons, desktop file, metainfo, AppRun) comes from this checkout.
#
# Writes dist/texodus-trail-<version>-x86_64.AppImage, .AppImage.zsync and
# .AppImage.sha256. Work files go in build/appimage (WORK_DIR to move it).

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
version="${1:?usage: build.sh <version> [<game dir>]}"
game="$(cd "${2:-$repo}" && pwd)"
work="${WORK_DIR:-$repo/build/appimage}"
dist="$repo/dist"

QT_VERSION=6.10.3
AQTINSTALL_VERSION=3.3.0
# linuxdeploy, its Qt plugin, appimagetool and the AppImage runtime, pinned.
LINUXDEPLOY_URL=https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage
LINUXDEPLOY_SHA256=c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d
LINUXDEPLOY_QT_URL=https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/1-alpha-20250213-1/linuxdeploy-plugin-qt-x86_64.AppImage
LINUXDEPLOY_QT_SHA256=15106be885c1c48a021198e7e1e9a48ce9d02a86dd0a1848f00bdbf3c1c92724
APPIMAGETOOL_URL=https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage
APPIMAGETOOL_SHA256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
RUNTIME_URL=https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64
RUNTIME_SHA256=2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d
UPDATE_INFO="gh-releases-zsync|ninepointlabs|texodus-trail|latest|texodus-trail-*x86_64.AppImage.zsync"

# The tools are AppImages themselves; don't make the build need FUSE.
export APPIMAGE_EXTRACT_AND_RUN=1

grep -q "<release version=\"$version\"" "$repo/packaging/com.ninepointlabs.texodus_trail.metainfo.xml" ||
  { echo "build.sh: add a <release version=\"$version\"> to packaging/com.ninepointlabs.texodus_trail.metainfo.xml" >&2; exit 1; }

mkdir -p "$work/tools" "$dist"
cd "$work"

fetch() { # url sha256 file
  [[ -f $3 ]] && echo "$2  $3" | sha256sum -c --quiet - 2>/dev/null && return 0
  curl -fsSLo "$3" "$1"
  echo "$2  $3" | sha256sum -c --quiet -
  chmod +x "$3"
}
fetch "$LINUXDEPLOY_URL" "$LINUXDEPLOY_SHA256" tools/linuxdeploy-x86_64.AppImage
fetch "$LINUXDEPLOY_QT_URL" "$LINUXDEPLOY_QT_SHA256" tools/linuxdeploy-plugin-qt-x86_64.AppImage
fetch "$APPIMAGETOOL_URL" "$APPIMAGETOOL_SHA256" tools/appimagetool-x86_64.AppImage
fetch "$RUNTIME_URL" "$RUNTIME_SHA256" tools/runtime-x86_64

# Qt, from the official binaries (built on RHEL 9: glibc 2.34)
qt="$work/qt/$QT_VERSION/gcc_64"
if [[ ! -x $qt/bin/qmake ]]; then
  python3 -m venv "$work/venv"
  "$work/venv/bin/pip" install --quiet "aqtinstall==$AQTINSTALL_VERSION"
  "$work/venv/bin/aqt" install-qt linux desktop "$QT_VERSION" linux_gcc_64 -m qtmultimedia qtshadertools -O "$work/qt"
fi

# Quickshell
if [[ ! -x $work/quickshell/bin/quickshell ]]; then
  QT_DIR="$qt" "$here/build-quickshell.sh" "$work/quickshell-src" "$work/quickshell"
fi

# The AppDir: the game laid out like the packages install it, under usr/
appdir="$work/AppDir"
rm -rf "$appdir"
share="$appdir/usr/share"
mkdir -p "$appdir/usr/bin" "$share/texodus-trail" "$share/applications" "$share/metainfo"
cp -r "$game/app" "$game/bin" "$share/texodus-trail/"
echo "$version" >"$share/texodus-trail/VERSION"
install -m644 "$game/LICENSE" "$share/texodus-trail/LICENSE"
install -Dm644 "$game/LICENSE" "$share/licenses/texodus-trail/LICENSE"
cp -r "$work/quickshell/share/licenses/quickshell" "$share/licenses/"
mkdir -p "$share/licenses/qt"
cp /usr/share/common-licenses/{LGPL-3,GPL-3,LGPL-2.1} "$share/licenses/qt/"
cat >"$share/licenses/qt/README" <<EOF
Qt $QT_VERSION (the official binaries from download.qt.io) is used under the
GNU LGPL v3 (LGPL-3, which builds on GPL-3); its source is at
https://download.qt.io/official_releases/qt/${QT_VERSION%.*}/$QT_VERSION/
Qt Multimedia's FFmpeg libraries (libavcodec, libavformat, libavutil,
libswresample, libswscale) are LGPL-2.1-or-later builds; source at
https://ffmpeg.org. The other libraries in usr/lib come from Ubuntu 22.04
packages, with their copyright files in usr/share/doc.
EOF
cp -r "$repo/assets/icons" "$share/"
install -m644 "$repo/packaging/com.ninepointlabs.texodus_trail.metainfo.xml" "$share/metainfo/"
install -m755 "$work/quickshell/bin/quickshell" "$appdir/usr/bin/quickshell"
# for the Qt version in --about
install -m755 "$qt/bin/qtpaths6" "$appdir/usr/bin/qtpaths6"

# Bundle Qt and every library the host can't be trusted to have. The Qt
# plugin deploys the platform plugins (Wayland and xcb), the QML modules the
# game imports (QtQuick, QtQuick.Shapes, QtMultimedia and its FFmpeg backend) and writes
# usr/bin/qt.conf, which is how Qt finds them all at run time.
export PATH="$work/tools:$PATH"
export QMAKE="$qt/bin/qmake"
export LD_LIBRARY_PATH="$qt/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QML_SOURCES_PATHS="$share/texodus-trail/app"
export EXTRA_QT_MODULES="waylandclient;svg;multimedia"
export EXTRA_PLATFORM_PLUGINS="libqwayland.so;libqoffscreen.so"
# The Qt plugin doesn't know Qt 6.10's single Wayland platform plugin, so
# the plugins it loads are added here: xdg-shell (windows), EGL (OpenGL)
# and client-side decorations (title bars on GNOME, which draws none).
for p in wayland-shell-integration/libxdg-shell.so wayland-graphics-integration-client/libqt-plugin-wayland-egl.so \
  wayland-decoration-client/libbradient.so wayland-decoration-client/libadwaita.so; do
  install -Dm755 "$qt/plugins/$p" "$appdir/usr/plugins/$p"
done
"$work/tools/linuxdeploy-x86_64.AppImage" --appdir "$appdir" \
  --executable "$appdir/usr/bin/quickshell" --executable "$appdir/usr/bin/qtpaths6" \
  --deploy-deps-only "$appdir/usr/plugins/wayland-shell-integration" \
  --deploy-deps-only "$appdir/usr/plugins/wayland-graphics-integration-client" \
  --deploy-deps-only "$appdir/usr/plugins/wayland-decoration-client" \
  --plugin qt

# The launcher and desktop entry, added after linuxdeploy so it doesn't
# put its own AppRun in. (Its Qt plugin's AppRun hook isn't needed: qt.conf
# does that job without exporting anything.)
rm -rf "$appdir/AppRun" "$appdir/apprun-hooks"
install -m755 "$here/AppRun" "$appdir/AppRun"
install -m644 "$repo/packaging/texodus-trail.desktop" "$share/applications/texodus-trail.desktop"
echo "X-AppImage-Version=$version" >>"$share/applications/texodus-trail.desktop"
cp "$share/applications/texodus-trail.desktop" "$appdir/texodus-trail.desktop"
cp "$share/icons/hicolor/256x256/apps/texodus-trail.png" "$appdir/texodus-trail.png"
ln -s texodus-trail.png "$appdir/.DirIcon"

# Nothing the game doesn't use: QML modules it never imports, Quick Controls
# styles other than Basic and Fusion (Quickshell's own dialogs use Fusion),
# then every bundled library that nothing left links to.
rm -rf "$appdir/usr/translations" "$appdir/usr/plugins/qmltooling" \
  "$appdir"/usr/qml/QtQuick/{Dialogs,Particles,LocalStorage,VectorImage,tooling} \
  "$appdir"/usr/qml/QtQuick/Controls/{Material,Universal,Imagine,FluentWinUI3,designer} \
  "$appdir/usr/qml/QtQml/XmlListModel"
while :; do
  needed="$({ find "$appdir/usr" -type f \( -name '*.so*' -o -path '*/usr/bin/*' \) -print0 |
    xargs -0 readelf -d 2>/dev/null || true; } | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | sort -u)"
  removed=0
  for lib in "$appdir"/usr/lib/*.so*; do
    if ! grep -qxF "$(basename "$lib")" <<<"$needed"; then
      rm -f "$lib"
      removed=1
    fi
  done
  ((removed)) || break
done

out="$dist/texodus-trail-$version-x86_64.AppImage"
rm -f "$out" "$out.zsync" "$out.sha256"
(cd "$dist" && ARCH=x86_64 VERSION="$version" "$work/tools/appimagetool-x86_64.AppImage" \
  --runtime-file "$work/tools/runtime-x86_64" --updateinformation "$UPDATE_INFO" \
  "$appdir" "$out")
(cd "$dist" && sha256sum "$(basename "$out")" >"$(basename "$out").sha256")
ls -l "$dist"/texodus-trail-"$version"-x86_64.AppImage*

import QtQuick
import Quickshell
import Quickshell.Io

// The current Omarchy theme's colours, read straight from
// ~/.local/state/omarchy/current/theme/colors.toml and re-read whenever the
// theme changes, so `omarchy theme set` restyles the game live. The scenery
// keeps its own sunset palette; everything the player reads (panels, menus,
// highlights) wears the theme.
QtObject {
  id: root

  readonly property string path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/current/theme/colors.toml"

  property color background: "#16161e"
  property color darkBackground: "#101016"
  property color darkerBackground: "#0b0b10"
  property color lighterBackground: "#1f2030"
  property color foreground: "#d6e2ee"
  property color dim: Qt.darker(foreground, 1.6)
  property color accent: "#ff9e64"
  property color selection: "#2e3c64"
  property color muted: "#444b6a"
  property color red: "#f7768e"
  property color green: "#9ece6a"
  property color yellow: "#e0af68"
  property color blue: "#7aa2f7"
  property color cyan: "#7dcfff"
  property color magenta: "#bb9af7"
  property string mode: "dark"

  readonly property string font: "monospace"

  property var _file: FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.apply(text())
  }

  function apply(raw) {
    var map = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([A-Za-z_]+)\s*=\s*"([^"]*)"/)
      if (m) map[m[1]] = m[2]
    }
    function c(key, fallback) { return map[key] && /^#[0-9a-fA-F]{6,8}$/.test(map[key]) ? map[key] : fallback }
    background = c("background", background)
    darkBackground = c("dark_background", Qt.darker(background, 1.2))
    darkerBackground = c("darker_background", Qt.darker(background, 1.45))
    lighterBackground = c("lighter_background", Qt.lighter(background, 1.25))
    foreground = c("foreground", foreground)
    dim = c("dark_foreground", Qt.darker(foreground, 1.6))
    accent = c("accent", accent)
    selection = c("selection", selection)
    muted = c("muted", muted)
    red = c("red", red)
    green = c("green", green)
    yellow = c("yellow", yellow)
    blue = c("blue", blue)
    cyan = c("cyan", cyan)
    magenta = c("magenta", magenta)
    mode = map.mode || "dark"
  }
}

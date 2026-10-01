pragma Singleton
import QtQuick

// Dev stub for tools/snap.qml: env vars arrive as --env=KEY=VALUE arguments.
QtObject {
  function env(name) {
    var args = Qt.application.arguments
    for (var i = 0; i < args.length; i++) {
      var a = String(args[i])
      if (a.indexOf("--env=" + name + "=") === 0) return a.slice(("--env=" + name + "=").length)
    }
    // never let a test touch the real save in ~/.local/state
    if (name === "XDG_STATE_HOME") return "/tmp/texodus-stub-state"
    return ""
  }
}

//@ pragma AppId texodus-trail
// ^ the window's Wayland app_id (Quickshell 0.3+), so docks, launchers and
//   window rules match it to texodus-trail.desktop instead of org.quickshell.
import QtQuick
import Quickshell
import Quickshell.Io

// The Texodus Trail: a standalone Quickshell app. Launch with `texodus`
// (bin/texodus), which runs `quickshell -p` on this directory.
ShellRoot {
  FloatingWindow {
    id: win
    title: "The Texodus Trail"
    implicitWidth: 1280
    implicitHeight: 800
    minimumSize: Qt.size(640, 400)
    color: "#000000"

    onClosed: Qt.quit()

    Theme { id: theme }
    Session { id: session }
    Sfx { id: sfx }

    App {
      id: app
      anchors.fill: parent
      theme: theme
      session: session
      sfx: sfx
      window: win
    }

    // `texodus --selftest`: start a trip, let the real loop run for a second,
    // drive a few days, report, quit. Used by the AppImage build's checks.
    Timer {
      running: Quickshell.env("TEXODUS_SELFTEST") === "1"
      interval: 300
      onTriggered: {
        app.chosenOccupation = "tech"
        app.beginTrip(4)
        app.enterGame()
        session.buy("gas", 150)
        session.buy("snacks", 300)
        app.closeOverlay()
        check.start()
      }
    }
    Timer {
      id: check
      interval: 1200
      onTriggered: {
        for (var i = 0; i < 3 && !session.game.finished; i++) {
          while (session.game.queue.length) session.ack()
          if (session.game.prompt) break
          session.hitTheRoad()
          session.travelDay()
        }
        var g = session.game
        var ok = app.view === "game" && g.miles > 0
        console.info(ok ? "texodus: selftest ok (" + g.miles + " miles, " + app.mode + ", sound " + (sfx.available ? "on" : "off") + ")"
          : "texodus: selftest failed: " + JSON.stringify({ view: app.view, mode: app.mode, miles: g ? g.miles : null }))
        Qt.exit(ok ? 0 : 1)
      }
    }

    // `quickshell ipc -p <app dir> call texodus <fn>`: drive the game from a
    // script. Used by tools/screenshots.sh; handy for raising the window too.
    IpcHandler {
      target: "texodus"

      function key(name: string): string {
        var keys = { space: Qt.Key_Space, enter: Qt.Key_Return, esc: Qt.Key_Escape, up: Qt.Key_Up, down: Qt.Key_Down, left: Qt.Key_Left, right: Qt.Key_Right, tab: Qt.Key_Tab }
        var code = keys[name] !== undefined ? keys[name] : name.toUpperCase().charCodeAt(0)
        var text = keys[name] !== undefined ? (name === "space" ? " " : "") : name
        return app.onKey({ key: code, text: text, modifiers: 0 }) ? "ok" : "ignored"
      }
      function state(): string {
        return JSON.stringify({ view: app.view, overlay: app.overlay, mode: app.mode, miles: session.game ? session.game.miles : 0 })
      }
      function quickstart(occupation: string, month: int): string {
        app.chosenOccupation = occupation || "tech"
        app.beginTrip(month || 3)
        app.enterGame()
        return "ok"
      }
      function travel(days: int): string {
        for (var i = 0; i < days && !session.game.finished; i++) {
          while (session.game.queue.length) session.ack()
          if (session.game.prompt) break
          session.hitTheRoad()
          session.travelDay()
        }
        return app.mode
      }
      function cheat(field: string, value: real): string {
        if (!session.game) return "no game"
        session.game[field] = value
        session.commit()
        return "ok"
      }
      function overlay(name: string): string { app.overlay = name; return "ok" }
      function go(view: string): string { app.view = view; return "ok" }
      function about(): string { app.openAbout(); return app.showAbout ? "ok" : "ignored" }
      // Saves a PNG of the stage; only ever under ~/.cache, only .png.
      function shot(path: string): string {
        var allowed = Quickshell.env("HOME") + "/.cache/"
        if (path.indexOf(allowed) !== 0 || path.indexOf("..") !== -1 || !/\.png$/.test(path)) return "refused: path must be a .png under ~/.cache"
        app.grabStage(path)
        return "ok"
      }
    }
  }
}

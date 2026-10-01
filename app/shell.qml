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

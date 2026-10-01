import QtQuick
import QtQuick.Window
import "../app"
import "../app/Game.js" as Game

// Headless screenshots, no compositor needed:
//   QT_QPA_PLATFORM=offscreen qml6 tools/snap.qml -- <outdir> <step>...
// Each step is view:<name>, key:<name>, start:<occupation>, travel:<n>,
// set:<field>=<value>, overlay:<name>, wait:<ms>, shot:<file.png>.
Window {
  id: win
  width: 1280
  height: 800
  visible: true

  Theme { id: theme }
  Session { id: session; onLoadedChanged: if (loaded) muted = true }
  Sfx { id: sfx; muted: true }

  App {
    id: app
    anchors.fill: parent
    theme: theme
    session: session
    sfx: sfx
  }

  property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1).filter(function(a) { return String(a).indexOf("--env=") !== 0 })
  property string outDir: args[0]
  property int step: 1

  Timer {
    id: runner
    interval: 400
    running: session.loaded
    onTriggered: win.next()
  }

  function key(name) {
    var keys = { space: Qt.Key_Space, enter: Qt.Key_Return, esc: Qt.Key_Escape, up: Qt.Key_Up, down: Qt.Key_Down, left: Qt.Key_Left, right: Qt.Key_Right }
    var code = keys[name] !== undefined ? keys[name] : name.toUpperCase().charCodeAt(0)
    app.onKey({ key: code, text: keys[name] !== undefined ? (name === "space" ? " " : "") : name, modifiers: 0 })
  }

  function next() {
    if (step >= args.length) { Qt.quit(); return }
    try { run(args[step++]) } catch (e) { console.warn("snap: step " + (step - 1) + " failed: " + e); Qt.quit() }
  }

  function run(s) {

    var i = s.indexOf(":")
    var op = s.slice(0, i), arg = s.slice(i + 1)
    var delay = 350
    if (op === "view") app.view = arg
    else if (op === "key") key(arg)
    else if (op === "start") { session.abandon(); app.chosenOccupation = arg; app.rollSuggestions(); app.beginTrip(4); app.enterGame() }
    else if (op === "travel") { for (var d = 0; d < Number(arg); d++) { session.stop(); session.hitTheRoad(); session.travelDay(); while (session.game.queue.length) session.ack(); if (session.game.prompt && session.game.prompt.type === "epitaph") session.epitaph("") } }
    else if (op === "set") { var kv = arg.split("="); session.game[kv[0]] = isNaN(Number(kv[1])) ? kv[1] : Number(kv[1]); session.commit() }
    else if (op === "overlay") app.overlay = arg
    else if (op === "eval") eval(arg)
    else if (op === "wait") delay = Number(arg)
    else if (op === "shot") {
      app.grabStage(outDir + "/" + arg)
      delay = 600
    }
    runner.interval = delay
    runner.restart()
  }
}

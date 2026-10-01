import QtQuick
import Quickshell
import Quickshell.Io
import "Game.js" as Game

// The state layer: the trip in progress, the Top Ten, the graves your past
// parties left by the road, and the sound setting. Everything is saved to
// ~/.local/state/texodus-trail/save.json after every action, so closing
// the window (or the laptop lid) never costs you a mile.
Item {
  id: root

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/texodus-trail"
  readonly property string savePath: stateDir + "/save.json"

  property var game: null
  property var topTen: Game.sanitizeTopTen([])
  property var graves: []
  property bool muted: false
  property bool loaded: false
  property int revision: 0
  property int lastRank: -1
  property string storeError: ""

  property bool dirReady: false
  property bool pendingSave: false

  readonly property bool hasGame: game !== null && game !== undefined
  readonly property bool canContinue: hasGame && !game.finished
  readonly property string mode: Game.mode(game)

  Process {
    id: mkdir
    command: ["mkdir", "-p", root.stateDir]
    running: true
    onExited: function() {
      root.dirReady = true
      saveFile.reload()
    }
  }

  FileView {
    id: saveFile
    path: root.dirReady ? root.savePath : ""
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.applySave(text())
    onLoadFailed: function(error) { root.applySave("") }
    onSaveFailed: function(error) { console.warn("texodus: save failed: " + error) }
  }

  function applySave(raw) {
    if (loaded) return
    var data = null
    try { data = raw && raw.trim() !== "" ? JSON.parse(raw) : null } catch (e) { console.warn("texodus: unreadable save, starting fresh: " + e) }
    if (data && typeof data === "object") {
      topTen = Game.sanitizeTopTen(data.topTen)
      graves = Game.sanitizeGraves(data.graves)
      muted = data.muted === true
      if (data.game) {
        var problem = Game.validate(data.game)
        if (problem === "") game = data.game
        else console.warn("texodus: dropping corrupt save: " + problem)
      }
    }
    loaded = true
    revision += 1
  }

  function save() {
    if (!loaded) return
    if (!dirReady) { pendingSave = true; return }
    saveFile.setText(JSON.stringify({ version: 1, game: game, topTen: topTen, graves: graves, muted: muted }) + "\n")
  }

  onDirReadyChanged: if (dirReady && pendingSave) { pendingSave = false; save() }
  onMutedChanged: if (loaded) save()

  // Every mutation ends here: settle pending epitaphs, record the score once
  // a trip ends, publish a fresh reference so bindings update, and save.
  function commit() {
    if (game) {
      Game.settle(game)
      if (game.finished && !game.scored) {
        var table = topTen.slice()
        lastRank = Game.recordScore(table, game)
        topTen = table
      }
      // graves outlive the trip that dug them
      if (game.graves.length) {
        var known = graves.slice()
        for (var i = 0; i < game.graves.length; i++) {
          var gr = game.graves[i]
          var dup = known.some(function(k) { return k.name === gr.name && k.mile === gr.mile && k.year === gr.year && k.epitaph === gr.epitaph })
          if (!dup) known.push(gr)
        }
        graves = Game.sanitizeGraves(known)
      }
    }
    game = game ? Object.assign({}, game) : null
    revision += 1
    save()
  }

  function act(fn) {
    if (!game) return false
    storeError = ""
    var result = fn(game)
    commit()
    return result
  }

  function newGame(opts) {
    var g = Game.newGame(opts)
    g.knownGraves = graves.slice()
    game = g
    lastRank = -1
    storeError = ""
    commit()
  }

  function abandon() {
    game = null
    revision += 1
    save()
  }

  function ack() { return act(Game.ack) }
  function travelDay() { return act(Game.travelDay) }
  function hitTheRoad() { return act(Game.hitTheRoad) }
  function stop() { return act(Game.stop) }
  function rest(days) { return act(function(g) { return Game.rest(g, days) }) }
  function talk() { return act(Game.talk) }
  function trade() { return act(Game.offerTrade) }
  function answerTrade(yes) { return act(function(g) { return Game.answerTrade(g, yes) }) }
  function setPace(id) { return act(function(g) { return Game.setPace(g, id) }) }
  function setRations(id) { return act(function(g) { return Game.setRations(g, id) }) }
  function special() { return act(Game.doSpecial) }
  function river(choice) { return act(function(g) { return Game.riverChoice(g, choice) }) }
  function epitaph(text) { return act(function(g) { return Game.setEpitaph(g, text) }) }
  function forageResult(lbs, used) { return act(function(g) { return Game.forageResult(g, lbs, used) }) }

  function buy(id, qty) {
    if (!game) return false
    var r = Game.buy(game, id, qty)
    storeError = r.ok ? "" : r.error
    commit()
    return r.ok
  }

  function sell(id, qty) {
    if (!game) return false
    var r = Game.sell(game, id, qty)
    storeError = r.ok ? "" : r.error
    commit()
    return r.ok
  }

  function resetTopTen() {
    topTen = Game.sanitizeTopTen([])
    save()
    revision += 1
  }
}

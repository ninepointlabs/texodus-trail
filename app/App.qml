import QtQuick
import Quickshell
import "Game.js" as Game

// The whole game on one 1280x800 stage, scaled to whatever window Hyprland
// hands us. Top: the road (Scene). Bottom: the console where every menu,
// question and score lives, dressed in the current Omarchy theme.
//
// `view` is the screen outside a trip (title, party setup, Top Ten...).
// Inside a trip the engine's mode() drives what's shown, and `overlay`
// covers the side trips the player opens from camp (store, map, supplies,
// pace, rations, rest, the Food Truck Frenzy).
Item {
  id: app

  property var theme
  property var session
  property var sfx
  property var window: null

  readonly property int stageW: 1280
  readonly property int stageH: 800
  readonly property int sceneH: 450

  property string view: "title"
  property string overlay: ""
  property bool firstStore: false

  readonly property var game: session.revision >= 0 ? session.game : null
  readonly property string mode: view === "game" ? Game.mode(game) : "none"
  readonly property var message: mode === "message" && game ? game.queue[0] : null
  readonly property var prompt: game ? game.prompt : null

  // ----------------------------------------------------------- music ----
  Binding {
    target: app.sfx
    property: "track"
    value: app.view === "game" && app.mode !== "end" ? "travel" : "theme"
  }
  Binding { target: app.sfx; property: "muted"; value: app.session.muted }

  onMessageChanged: if (message) sfx.play(message.sfx)
  onModeChanged: {
    // the trail interrupts whatever side trip was open
    if (mode === "river" || mode === "trade" || mode === "epitaph" || mode === "end") overlay = ""
    if (mode === "end" && game && game.won) sfx.play("fanfare")
    if (mode === "camp" || mode === "travel") Qt.callLater(focusStage)
  }

  function focusStage() { stage.forceActiveFocus() }
  function grabStage(path) {
    if (!stage.grabToImage(function(r) { if (!r.saveToFile(path)) console.warn("texodus: could not save " + path) }))
      console.warn("texodus: grab failed")
  }

  // ---------------------------------------------------------- the clock --
  Timer {
    id: dayTimer
    interval: 1250
    repeat: true
    running: app.view === "game" && app.overlay === "" && app.mode === "travel"
    onTriggered: app.session.travelDay()
  }

  // title screen region tour
  property int titleRegion: 0
  Timer {
    interval: 5200
    repeat: true
    running: app.view === "title" || app.view === "learn" || app.view === "topten"
    onTriggered: app.titleRegion = (app.titleRegion + 1) % 4
  }

  // --------------------------------------------------------- setup state --
  property string chosenOccupation: "tech"
  property var partyNames: ["", "", "", "", ""]
  property var suggestions: []
  property int nameIndex: 0
  property int learnPage: 0
  property int introPage: 0
  property bool showOccupationHelp: false
  property bool showMonthAdvice: false
  property bool showRiverInfo: false

  function capitalized(s) { s = String(s || ""); return s ? s.charAt(0).toUpperCase() + s.slice(1) : "" }

  function rollSuggestions() {
    var pool = Game.NAMES.slice()
    var out = [capitalized(Quickshell.env("USER")) || "You"]
    for (var i = 0; i < 4; i++) out.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0])
    suggestions = out
  }

  function go(next) {
    view = next
    overlay = ""
    sfx.play("select")
    Qt.callLater(function() {
      if (next === "names") nameFields.focusField(0)
      else focusStage()
    })
  }

  function startSetup() {
    chosenOccupation = "tech"
    partyNames = ["", "", "", "", ""]
    rollSuggestions()
    nameIndex = 0
    showOccupationHelp = false
    showMonthAdvice = false
    go("occupation")
  }

  function beginTrip(month) {
    var names = []
    for (var i = 0; i < 5; i++) names.push(String(partyNames[i] || "").trim() || suggestions[i])
    session.newGame({ occupation: chosenOccupation, month: month, names: names, year: new Date().getFullYear() })
    introPage = 0
    go("intro")
  }

  function enterGame() {
    view = "game"
    overlay = "store"
    firstStore = true
    store.reset()
    sfx.play("coin")
    Qt.callLater(focusStage)
  }

  function continueTrip() {
    view = "game"
    overlay = ""
    firstStore = false
    sfx.play("select")
    Qt.callLater(focusStage)
  }

  function closeOverlay() {
    overlay = ""
    firstStore = false
    sfx.play("blip")
    Qt.callLater(focusStage)
  }

  function hitTheRoad() {
    if (session.hitTheRoad()) sfx.play("horn")
  }

  function openForage() {
    if (!game || game.coupons <= 0) return
    overlay = "forage"
    Qt.callLater(function() { forage.start() })
  }

  // ------------------------------------------------------------ menus ----

  readonly property var titleItems: [
    { label: "Travel the trail", value: "new" },
    { label: "Continue your trip", value: "continue", enabled: session.canContinue, detail: session.canContinue ? "mile " + Math.round(session.game.miles) : "" },
    { label: "Learn about the trail", value: "learn" },
    { label: "See the Top Ten Texans", value: "topten" },
    { label: "Turn sound " + (session.muted ? "on" : "off"), value: "sound" },
    { label: "End", value: "quit" }
  ]

  readonly property var occupationItems: {
    var out = []
    for (var i = 0; i < Game.OCCUPATIONS.length; i++) {
      var o = Game.OCCUPATIONS[i]
      out.push({ label: "Be a " + o.name, value: o.id, detail: "×" + o.mult })
    }
    out.push({ label: "Find out the differences between these choices", value: "help" })
    return out
  }

  readonly property var monthItems: {
    var out = []
    for (var i = 0; i < Game.MONTHS.length; i++) out.push({ label: Game.MONTHS[i].name, value: Game.MONTHS[i].month, detail: Game.MONTHS[i].note })
    out.push({ label: "Ask for advice", value: -1 })
    return out
  }

  readonly property var campItems: {
    if (!game) return []
    var sp = Game.specialHere(game)
    var store = Game.storeHere(game)
    var out = [
      { label: "Continue on the trail", value: "go" },
      { label: "Check supplies", value: "supplies" },
      { label: "Look at map", value: "map" },
      { label: "Change pace", value: "pace", detail: Game.paceOf(game).name },
      { label: "Change food rations", value: "rations", detail: Game.rationsOf(game).name },
      { label: "Stop to rest", value: "rest" },
      { label: "Attempt to trade", value: "trade" },
      { label: "Talk to people", value: "talk" },
      { label: store ? "Buy supplies" : "Buy supplies (no store)", value: "store", enabled: !!store, detail: store ? store.split(" (")[0] : "" },
      { label: "Food Truck Frenzy", value: "forage", enabled: game.coupons > 0, detail: game.coupons + " coupons" }
    ]
    if (sp) out.push({ label: "★ " + sp.label, value: "special", key: "s" })
    out.push({ label: "Save & quit to title", value: "quit", key: "q" })
    return out
  }

  readonly property var paceItems: Game.PACES.map(function(p) { return { label: p.name, value: p.id, detail: p.miles + " mi/day" } })
  readonly property var rationItems: Game.RATIONS.map(function(r) { return { label: r.name, value: r.id, detail: r.lbs + " lb/person/day" } })
  readonly property var restItems: [1, 2, 3, 4, 5].map(function(d) { return { label: d + (d === 1 ? " day" : " days"), value: d } })

  readonly property var riverItems: prompt && prompt.type === "river" ? [
    { label: "Attempt to ford the river", value: "ford", detail: "it's a Ford (ish)" },
    { label: "Caulk the Yoo-Haul and float it", value: "caulk", detail: "YouTube certified" },
    { label: "Take the toll bridge", value: "bridge", detail: Game.formatMoney(prompt.toll) },
    { label: "Wait a day to see if conditions improve", value: "wait" },
    { label: "Get more information", value: "info" }
  ] : []

  readonly property var tradeItems: [
    { label: "Deal", value: true, enabled: !!(prompt && prompt.type === "trade" && game && game[prompt.want] >= prompt.wantQty) },
    { label: "No thanks", value: false }
  ]

  readonly property var endItems: [
    { label: "See the Top Ten Texans", value: "topten" },
    { label: "Make the trip again", value: "again" },
    { label: "Back to the title screen", value: "title" }
  ]

  function onTitle(item) {
    switch (item.value) {
    case "new": startSetup(); break
    case "continue": continueTrip(); break
    case "learn": learnPage = 0; go("learn"); break
    case "topten": go("topten"); break
    case "sound": session.muted = !session.muted; sfx.play("select"); break
    case "quit": Qt.quit(); break
    }
  }

  function onOccupation(item) {
    if (item.value === "help") { showOccupationHelp = !showOccupationHelp; sfx.play("blip"); return }
    chosenOccupation = item.value
    go("names")
  }

  function onMonth(item) {
    if (item.value < 0) { showMonthAdvice = !showMonthAdvice; sfx.play("blip"); return }
    beginTrip(item.value)
  }

  function onCamp(item) {
    sfx.play("select")
    switch (item.value) {
    case "go": hitTheRoad(); break
    case "supplies": overlay = "supplies"; break
    case "map": overlay = "map"; break
    case "pace": overlay = "pace"; break
    case "rations": overlay = "rations"; break
    case "rest": overlay = "rest"; break
    case "trade": session.trade(); break
    case "talk": session.talk(); break
    case "store": store.reset(); overlay = "store"; break
    case "forage": openForage(); break
    case "special": session.special(); break
    case "quit": view = "title"; overlay = ""; break
    }
  }

  function onRiver(item) {
    if (item.value === "info") { showRiverInfo = !showRiverInfo; sfx.play("blip"); return }
    showRiverInfo = false
    sfx.play("select")
    session.river(item.value)
  }

  function onEnd(item) {
    sfx.play("select")
    if (item.value === "topten") go("topten")
    else if (item.value === "again") { session.abandon(); startSetup() }
    else { session.abandon(); go("title") }
  }

  // --------------------------------------------------------- keyboard ----

  function onKey(event) {
    var k = event.key
    if (k === Qt.Key_F11) { if (window) window.fullscreen = !window.fullscreen; return true }
    if (k === Qt.Key_Q && (event.modifiers & Qt.ControlModifier)) { Qt.quit(); return true }
    if (k === Qt.Key_M && !(event.modifiers & Qt.ControlModifier) && !textFocus()) { session.muted = !session.muted; return true }

    if (view === "title") return titleMenu.handleKey(event) || (k === Qt.Key_Escape)
    if (view === "occupation") { if (k === Qt.Key_Escape) { go("title"); return true } return occupationMenu.handleKey(event) }
    if (view === "names") { if (k === Qt.Key_Escape) { go("occupation"); return true } return false }
    if (view === "month") { if (k === Qt.Key_Escape) { go("names"); return true } return monthMenu.handleKey(event) }
    if (view === "intro") {
      if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter) { if (introPage < 1) { introPage++; sfx.play("blip") } else enterGame(); return true }
      if (k === Qt.Key_Escape) { if (introPage > 0) introPage--; return true }
      return false
    }
    if (view === "learn") {
      if (k === Qt.Key_Escape) { go("title"); return true }
      if (k === Qt.Key_Left) { learnPage = Math.max(0, learnPage - 1); sfx.play("blip"); return true }
      if (k === Qt.Key_Right || k === Qt.Key_Space || k === Qt.Key_Return) {
        if (learnPage < learnPages.length - 1) { learnPage++; sfx.play("blip") } else go("title")
        return true
      }
      return false
    }
    if (view === "topten") { if (k === Qt.Key_Escape || k === Qt.Key_Return || k === Qt.Key_Space) { go(game && game.finished ? "game" : "title"); return true } return false }

    // ---- in a trip
    if (mode === "message") {
      if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Escape) { if (card.typing) card.advance(); else { session.ack(); sfx.play("blip") } return true }
      return false
    }
    if (overlay === "store") return store.handleKey(event)
    if (overlay === "forage") return false
    if (overlay === "supplies" || overlay === "map") { if (k === Qt.Key_Escape || k === Qt.Key_Return || k === Qt.Key_Space) { closeOverlay(); return true } return false }
    if (overlay === "pace" || overlay === "rations" || overlay === "rest") {
      if (k === Qt.Key_Escape) { closeOverlay(); return true }
      return choiceMenu.handleKey(event)
    }
    switch (mode) {
    case "travel":
      if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Escape) { session.stop(); sfx.play("blip"); return true }
      return false
    case "camp": return campMenu.handleKey(event)
    case "river": return riverMenu.handleKey(event)
    case "trade": return tradeMenu.handleKey(event)
    case "end": return endMenu.handleKey(event)
    }
    return false
  }

  function textFocus() {
    return view === "names" || mode === "epitaph"
  }

  // ------------------------------------------------------------- stage ---

  Rectangle { anchors.fill: parent; color: "#000000" }

  Item {
    id: stage
    width: app.stageW
    height: app.stageH
    anchors.centerIn: parent
    scale: Math.min(app.width / app.stageW, app.height / app.stageH)
    focus: true
    clip: true

    Keys.onPressed: function(event) { if (app.onKey(event)) event.accepted = true }

    // --------------------------------------------------------- the road
    Scene {
      id: scene
      width: app.stageW
      height: app.sceneH
      region: app.game && app.view === "game" ? Game.regionOf(app.game) : ["ca", "az", "nm", "tx"][app.titleRegion]
      weather: app.game && app.view === "game" ? app.game.weather : "Sunny"
      moving: app.view !== "game" ? app.view !== "intro" : app.mode === "travel" && app.overlay === ""
      landmark: app.view === "game" && app.game && app.game.at >= 0 ? Game.LANDMARKS[app.game.at] : null
      atRiver: app.mode === "river"
    }

    // ------------------------------------------------------ title logo
    Item {
      id: logo
      visible: app.view === "title" || app.view === "occupation" || app.view === "names" || app.view === "month"
      anchors.horizontalCenter: scene.horizontalCenter
      y: app.view === "title" ? 46 : 18
      width: logoTitle.width
      height: 200
      scale: app.view === "title" ? 1 : 0.55
      transformOrigin: Item.Top
      Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
      Behavior on y { NumberAnimation { duration: 400 } }

      PixelText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "NINEPOINT LABS PRESENTS"
        px: 2.5
        color: "#f6f1e7"
        shadow: "#000000"
        opacity: app.view === "title" ? 0.85 : 0
      }
      PixelText {
        id: logoTitle
        y: 34
        text: "THE TEXODUS TRAIL"
        px: 10
        color: "#ffe36e"
        lowerColor: "#ff7a1a"
        shadow: "#ff2a6d"
        shadowOffset: 1
        outline: "#1b1424"
        SequentialAnimation on y {
          loops: Animation.Infinite
          NumberAnimation { from: 34; to: 40; duration: 1400; easing.type: Easing.InOutSine }
          NumberAnimation { from: 40; to: 34; duration: 1400; easing.type: Easing.InOutSine }
        }
      }
      PixelText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 130
        text: "YOU HAVE DIED OF STATE INCOME TAX."
        px: 3
        color: "#f6f1e7"
        outline: "#1b1424"
        opacity: app.view === "title" ? 1 : 0
      }
    }

    // ---------------------------------------------------- scene covers
    MapView {
      anchors.fill: scene
      visible: app.view === "game" && app.overlay === "map"
      theme: app.theme
      game: app.game
    }

    ForageGame {
      id: forage
      anchors.fill: scene
      visible: app.overlay === "forage"
      theme: app.theme
      sfx: app.sfx
      coupons: app.game ? app.game.coupons : 0
      onFinished: function(lbs, used) {
        app.overlay = ""
        app.session.forageResult(lbs, used)
        Qt.callLater(app.focusStage)
      }
    }

    Tombstone {
      anchors.fill: scene
      visible: app.view === "game" && app.mode === "epitaph"
      theme: app.theme
      prompt: app.mode === "epitaph" ? app.prompt : null
      onDone: function(text) { app.session.epitaph(text); app.sfx.play("select"); Qt.callLater(app.focusStage) }
    }

    // the end of the road
    Item {
      anchors.fill: scene
      visible: app.view === "game" && app.mode === "end" && app.overlay === ""
      Rectangle { anchors.fill: parent; color: app.game && app.game.won ? "transparent" : "#3a0010"; opacity: 0.72 }
      Rectangle {
        anchors.fill: endBanner
        anchors.margins: -22
        color: "#1b1424"
        opacity: 0.78
        border.color: "#ffe36e"
        border.width: 3
      }
      Column {
        id: endBanner
        anchors.horizontalCenter: parent.horizontalCenter
        y: 46
        spacing: 14
        PixelText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: app.game && app.game.won ? "YOU MADE IT TO AUSTIN!" : "YOU HAVE DIED OF"
          px: 7
          color: "#ffe36e"
          lowerColor: "#ff7a1a"
          shadow: "#ff2a6d"
          outline: "#1b1424"
        }
        PixelText {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: !!(app.game && !app.game.won)
          text: "STATE INCOME TAX"
          px: 7
          color: "#ffe36e"
          lowerColor: "#ff7a1a"
          shadow: "#ff2a6d"
          outline: "#1b1424"
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: !app.game ? "" : app.game.won
            ? "Welcome home, " + app.game.party[0].name + ". The brisket is real. The rent is also real."
            : "(Technically, " + app.game.party[0].name + " died of " + (app.game.deathCause || "the trail") + ", " + Math.round(Game.TRIP_MILES - app.game.miles) + " miles short of Austin.)"
          color: "#f6f1e7"
          font.family: app.theme.font
          font.pixelSize: 20
        }
      }
    }

    // ---------------------------------------------------------- console
    Rectangle {
      id: console_
      y: app.sceneH
      width: app.stageW
      height: app.stageH - app.sceneH
      color: app.theme.darkerBackground
      Rectangle { width: parent.width; height: 4; color: app.theme.accent }
      Rectangle { y: 4; width: parent.width; height: 2; color: "#000000"; opacity: 0.4 }

      readonly property bool showHud: app.view === "game" && app.overlay !== "store" && app.mode !== "end"

      Hud {
        id: hud
        y: 6
        width: parent.width
        visible: console_.showHud
        theme: app.theme
        game: app.game
      }

      Item {
        id: content
        x: 0
        y: console_.showHud ? hud.y + hud.height : 6
        width: parent.width
        height: parent.height - y

        // ------------------------------------------------ title menu
        Item {
          anchors.fill: parent
          visible: app.view === "title"
          Menu {
            id: titleMenu
            x: 120
            y: 34
            theme: app.theme
            items: app.titleItems
            itemWidth: 480
            fontSize: 22
            onActivated: function(i, item) { app.onTitle(item) }
            onHighlighted: app.sfx.play("blip")
          }
          Column {
            x: 700
            y: 40
            width: 480
            spacing: 14
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "It's 2026. Rent is $3,950 for a one-bedroom. Gas is $6.89. Your landlord just texted \"hey quick q.\" There is only one thing left to do."
              color: app.theme.foreground
              font.family: app.theme.font
              font.pixelSize: 17
              lineHeight: 1.2
            }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Load up the Yoo-Haul. Point it east. Don't stop until you smell brisket."
              color: app.theme.accent
              font.family: app.theme.font
              font.pixelSize: 17
              font.bold: true
              lineHeight: 1.2
            }
            Text {
              text: "↑↓ Enter · M mute · F11 fullscreen"
              color: app.theme.dim
              font.family: app.theme.font
              font.pixelSize: 13
            }
          }
        }

        // ------------------------------------------------ occupation
        Item {
          anchors.fill: parent
          visible: app.view === "occupation"
          Text {
            x: 60; y: 22
            text: "Many kinds of people are fleeing California. You may:"
            color: app.theme.foreground
            font.family: app.theme.font
            font.pixelSize: 20
          }
          Menu {
            id: occupationMenu
            x: 80
            y: 66
            theme: app.theme
            items: app.occupationItems
            itemWidth: 590
            onActivated: function(i, item) { app.onOccupation(item) }
            onHighlighted: app.sfx.play("blip")
          }
          Column {
            x: 720
            y: 66
            width: 500
            spacing: 10
            readonly property var occ: Game.OCCUPATIONS[Math.min(occupationMenu.current, Game.OCCUPATIONS.length - 1)]
            visible: !app.showOccupationHelp
            PixelText { text: parent.occ.name; px: 2.5; color: app.theme.accent }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: parent.occ.blurb
              color: app.theme.foreground
              font.family: app.theme.font
              font.pixelSize: 17
              lineHeight: 1.15
            }
            Text {
              text: "Starts with " + Game.formatMoney(parent.occ.cash) + " (" + Game.formatMoney(parent.occ.cash - Game.TRUCK_COST) + " after the Yoo-Haul) · score ×" + parent.occ.mult
              color: app.theme.green
              font.family: app.theme.font
              font.pixelSize: 15
            }
          }
          Text {
            x: 720
            y: 66
            width: 500
            visible: app.showOccupationHelp
            wrapMode: Text.WordWrap
            text: "Traveling to Texas is easier if you have money. The Crypto Bro starts richest, if you trust the coin. The Engineer has steady cash and fixes breakdowns fast. The Influencer gets paid for disasters. The Screenwriter is broke, but earns three times the points at the end. Choose wisely, or at least choose funnily."
            color: app.theme.foreground
            font.family: app.theme.font
            font.pixelSize: 17
            lineHeight: 1.15
          }
        }

        // ---------------------------------------------------- names
        Item {
          id: nameFields
          anchors.fill: parent
          visible: app.view === "names"
          function focusField(i) {
            app.nameIndex = Math.max(0, Math.min(4, i))
            var f = fieldRepeater.itemAt(app.nameIndex)
            if (f) f.focusInput()
          }
          function commit() {
            var next = app.partyNames.slice()
            for (var i = 0; i < 5; i++) next[i] = fieldRepeater.itemAt(i).value
            app.partyNames = next
          }
          Text {
            x: 60; y: 20
            text: app.nameIndex === 0 ? "What is the first name of the Yoo-Haul leader?" : "What are the first names of the four other people in your party?"
            color: app.theme.foreground
            font.family: app.theme.font
            font.pixelSize: 20
          }
          Column {
            x: 80
            y: 64
            spacing: 8
            Repeater {
              id: fieldRepeater
              model: 5
              Row {
                id: fieldRow
                required property int index
                property alias value: input.text
                function focusInput() { input.forceActiveFocus() }
                spacing: 16
                Text {
                  width: 130
                  anchors.verticalCenter: parent.verticalCenter
                  text: fieldRow.index === 0 ? "Leader" : "Passenger " + fieldRow.index
                  color: input.activeFocus ? app.theme.accent : app.theme.dim
                  font.family: app.theme.font
                  font.pixelSize: 17
                }
                Rectangle {
                  width: 360
                  height: 34
                  color: app.theme.background
                  border.color: input.activeFocus ? app.theme.accent : app.theme.muted
                  border.width: 2
                  TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    maximumLength: 18
                    color: app.theme.foreground
                    font.family: app.theme.font
                    font.pixelSize: 18
                    clip: true
                    onActiveFocusChanged: if (activeFocus) app.nameIndex = fieldRow.index
                    Keys.onTabPressed: nameFields.focusField(fieldRow.index + 1)
                    Keys.onBacktabPressed: nameFields.focusField(fieldRow.index - 1)
                    Keys.onUpPressed: nameFields.focusField(fieldRow.index - 1)
                    Keys.onDownPressed: nameFields.focusField(fieldRow.index + 1)
                    Keys.onReturnPressed: {
                      app.sfx.play("blip")
                      if (fieldRow.index < 4) nameFields.focusField(fieldRow.index + 1)
                      else { nameFields.commit(); app.go("month") }
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      visible: !input.text
                      text: app.suggestions[fieldRow.index] || ""
                      color: app.theme.muted
                      font: input.font
                    }
                  }
                }
              }
            }
          }
          Column {
            x: 720
            y: 70
            width: 480
            spacing: 12
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Leave a name blank to use the suggestion. Enter moves to the next passenger; Enter on the last one hits the road. Tab and the arrows move around."
              color: app.theme.foreground
              font.family: app.theme.font
              font.pixelSize: 16
              lineHeight: 1.15
            }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Pro tip: name them after your coworkers. No reason."
              color: app.theme.accent
              font.family: app.theme.font
              font.pixelSize: 16
            }
          }
        }

        // ---------------------------------------------------- month
        Item {
          anchors.fill: parent
          visible: app.view === "month"
          Text {
            x: 60; y: 20
            text: "It is " + new Date().getFullYear() + ". When do you want to leave San Francisco?"
            color: app.theme.foreground
            font.family: app.theme.font
            font.pixelSize: 20
          }
          Menu {
            id: monthMenu
            x: 80
            y: 64
            theme: app.theme
            items: app.monthItems
            itemWidth: 600
            fontSize: 19
            onActivated: function(i, item) { app.onMonth(item) }
            onHighlighted: app.sfx.play("blip")
          }
          Text {
            x: 740
            y: 64
            width: 460
            visible: app.showMonthAdvice
            wrapMode: Text.WordWrap
            text: "You attend a free webinar called \"Moving to Texas: Is It Hot?\" The answer is yes. Leave too late and the desert will cook you like a brisket. Leave in March and you might see snow in Flagstaff. April is the sweet spot. August is a dare."
            color: app.theme.foreground
            font.family: app.theme.font
            font.pixelSize: 17
            lineHeight: 1.15
          }
        }

        // ---------------------------------------------------- intro
        Item {
          anchors.fill: parent
          visible: app.view === "intro"
          Row {
            x: 60
            y: 20
            spacing: 40
            visible: app.introPage === 0
            Rectangle {
              width: 460
              height: 240
              color: "#f6f1e7"
              border.color: "#cfc8bb"
              border.width: 2
              Column {
                x: 20; y: 16
                width: parent.width - 40
                spacing: 6
                Text { text: "YOO-HAUL · RECEIPT #000420"; color: "#1b1424"; font.family: app.theme.font; font.pixelSize: 15; font.bold: true }
                Rectangle { width: parent.width; height: 2; color: "#1b1424" }
                Row { width: parent.width; Text { width: parent.width - 100; text: "26' truck, SF → Austin"; color: "#1b1424"; font.family: app.theme.font; font.pixelSize: 15 } Text { width: 100; horizontalAlignment: Text.AlignRight; text: Game.formatMoney(Game.TRUCK_COST); color: "#1b1424"; font.family: app.theme.font; font.pixelSize: 15 } }
                Row { width: parent.width; Text { width: parent.width - 100; text: "Same truck, Austin → SF"; color: "#7d776d"; font.family: app.theme.font; font.pixelSize: 15 } Text { width: 100; horizontalAlignment: Text.AlignRight; text: Game.formatMoney(Game.TRUCK_RETURN_COST); color: "#7d776d"; font.family: app.theme.font; font.pixelSize: 15 } }
                Text { text: "  (nobody's going that way)"; color: "#7d776d"; font.family: app.theme.font; font.pixelSize: 13; font.italic: true }
                Row { width: parent.width; Text { width: parent.width - 100; text: "Mattress strap"; color: "#1b1424"; font.family: app.theme.font; font.pixelSize: 15 } Text { width: 100; horizontalAlignment: Text.AlignRight; text: "free*"; color: "#1b1424"; font.family: app.theme.font; font.pixelSize: 15 } }
                Rectangle { width: parent.width; height: 2; color: "#1b1424" }
                Row { width: parent.width; Text { width: parent.width - 100; text: "Cash left"; color: "#1b1424"; font.family: app.theme.font; font.pixelSize: 16; font.bold: true } Text { width: 100; horizontalAlignment: Text.AlignRight; text: app.game ? Game.formatMoney(app.game.cash) : ""; color: "#2f6b25"; font.family: app.theme.font; font.pixelSize: 16; font.bold: true } }
                Text { text: "*strap is load-bearing. do not rely on strap."; color: "#7d776d"; font.family: app.theme.font; font.pixelSize: 12 }
              }
            }
            Text {
              width: 600
              wrapMode: Text.WordWrap
              text: "Before leaving San Francisco you rent a 26-foot Yoo-Haul. The one-way price is a war crime, but the guy at the counter, Kyle, says that's \"just supply and demand, bro.\"\n\nNext stop: Costco in Daly City, where Kyle's cousin, also named Kyle, will sell you everything you need for the trip."
              color: app.theme.foreground
              font.family: app.theme.font
              font.pixelSize: 18
              lineHeight: 1.2
            }
          }
          Column {
            x: 60
            y: 24
            width: 1100
            spacing: 14
            visible: app.introPage === 1
            PixelText { text: "COSTCO (DALY CITY)"; px: 3; color: app.theme.accent }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "\"Hi, I'm Kyle. You're going to Texas? Bold. Here's what you'll need:\n\n  · Gas. A Yoo-Haul gets 10 miles a gallon. It's about 1,900 miles. Do the math (I can't).\n  · Snacks. Each person eats 1 to 3 pounds a day.\n  · Sunscreen, for the scorching days. Spare tires and spare parts, for the bad ones.\n  · Coupons, if you want to hit a Food Truck Frenzy on the way.\n\nPrices only go down from here. California charges extra for the vibes.\""
              color: app.theme.foreground
              font.family: app.theme.font
              font.pixelSize: 17
              lineHeight: 1.15
            }
          }
          Text {
            anchors.right: parent.right
            anchors.rightMargin: 40
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            text: "Press SPACE to continue"
            color: app.theme.accent
            font.family: app.theme.font
            font.pixelSize: 16
          }
          MouseArea { anchors.fill: parent; z: -1; onClicked: { if (app.introPage < 1) app.introPage++; else app.enterGame() } }
        }

        // ---------------------------------------------------- learn
        Item {
          anchors.fill: parent
          visible: app.view === "learn"
          Column {
            x: 60
            y: 22
            width: 1160
            spacing: 14
            PixelText { text: app.learnPages[app.learnPage].title; px: 3; color: app.theme.accent }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: app.learnPages[app.learnPage].text
              color: app.theme.foreground
              font.family: app.theme.font
              font.pixelSize: 18
              lineHeight: 1.2
            }
          }
          Text {
            anchors.right: parent.right; anchors.rightMargin: 40
            anchors.bottom: parent.bottom; anchors.bottomMargin: 18
            text: "Page " + (app.learnPage + 1) + " of " + app.learnPages.length + " · ←→ · Esc to go back"
            color: app.theme.dim
            font.family: app.theme.font
            font.pixelSize: 14
          }
        }

        // --------------------------------------------------- top ten
        Item {
          anchors.fill: parent
          visible: app.view === "topten"
          PixelText { x: 60; y: 18; text: "THE TOP TEN TEXANS"; px: 3; color: app.theme.accent }
          Column {
            x: 60
            y: 56
            spacing: 1
            Repeater {
              model: app.session.topTen
              Rectangle {
                required property int index
                required property var modelData
                width: 1160
                height: 24
                color: modelData.mine ? app.theme.selection : index % 2 ? "transparent" : app.theme.background
                Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: (index + 1) + "."; color: app.theme.dim; font.family: app.theme.font; font.pixelSize: 16 }
                Text { x: 60; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: modelData.mine ? app.theme.accent : app.theme.foreground; font.family: app.theme.font; font.pixelSize: 16; font.bold: !!modelData.mine }
                Text { x: 520; width: 100; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: modelData.score.toLocaleString(Qt.locale("en_US"), "f", 0); color: app.theme.yellow; font.family: app.theme.font; font.pixelSize: 16 }
                Text { x: 680; anchors.verticalCenter: parent.verticalCenter; text: modelData.rating; color: app.theme.foreground; font.family: app.theme.font; font.pixelSize: 16 }
              }
            }
          }
          Text {
            anchors.right: parent.right; anchors.rightMargin: 40
            anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            text: "Enter to go back"
            color: app.theme.dim
            font.family: app.theme.font
            font.pixelSize: 14
          }
        }

        // ================================================= in the trip

        // ----------------------------------------------------- store
        StoreView {
          id: store
          anchors.fill: parent
          visible: app.view === "game" && app.overlay === "store" && app.mode !== "message"
          theme: app.theme
          session: app.session
          sfx: app.sfx
          firstStore: app.firstStore
          onClosed: app.closeOverlay()
        }

        // -------------------------------------------------- supplies
        Item {
          anchors.fill: parent
          visible: app.view === "game" && app.overlay === "supplies"
          Row {
            x: 60
            y: 12
            spacing: 60
            Grid {
              columns: 2
              columnSpacing: 30
              rowSpacing: 3
              Repeater {
                model: app.game ? [
                  ["Cash", Game.formatMoney(app.game.cash)],
                  ["Gas", Math.floor(app.game.gas) + " gal"],
                  ["Snacks", app.game.snacks + " lbs"],
                  ["Sunscreen", app.game.sunscreen + " bottles"],
                  ["Spare tires", app.game.tires],
                  ["Spare parts", app.game.parts],
                  ["Coupons", app.game.coupons],
                  ["Hats", app.game.hats]
                ] : []
                Text {
                  required property var modelData
                  required property int index
                  text: modelData[0] + "  " + modelData[1]
                  color: app.theme.foreground
                  font.family: app.theme.font
                  font.pixelSize: 17
                }
              }
            }
            Column {
              spacing: 4
              Repeater {
                model: app.game ? app.game.party : []
                Row {
                  required property var modelData
                  spacing: 14
                  Text { width: 160; text: modelData.name; color: modelData.alive ? app.theme.foreground : app.theme.muted; font.family: app.theme.font; font.pixelSize: 17; font.strikeout: !modelData.alive; elide: Text.ElideRight }
                  Text { width: 100; text: modelData.alive ? Game.healthLabel(modelData.hp) : "R.I.P."; color: !modelData.alive ? app.theme.muted : hud.healthColor(Game.healthLabel(modelData.hp)); font.family: app.theme.font; font.pixelSize: 17 }
                  Text { width: 300; text: !modelData.alive ? "died of " + (modelData.cause || "?") : modelData.sick ? modelData.sick : "fine, honestly"; color: app.theme.dim; font.family: app.theme.font; font.pixelSize: 15; elide: Text.ElideRight }
                }
              }
              Text {
                topPadding: 6
                text: app.game ? "Vibes: " + Game.vibesLabel(app.game.vibes) + " (" + app.game.vibes + ")   Twang: " + Game.twangTitle(app.game.twang) + " (" + app.game.twang + "%)" : ""
                color: app.theme.accent
                font.family: app.theme.font
                font.pixelSize: 16
              }
            }
          }
          Text {
            anchors.right: parent.right; anchors.rightMargin: 40
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            text: "Enter to go back"
            color: app.theme.dim
            font.family: app.theme.font
            font.pixelSize: 14
          }
        }

        // ----------------------------------------------- map legend
        Text {
          x: 60
          y: 20
          width: 1160
          visible: app.view === "game" && app.overlay === "map"
          wrapMode: Text.WordWrap
          text: app.game ? "You are " + Math.round(app.game.miles) + " miles from San Francisco and " + Math.round(Game.TRIP_MILES - app.game.miles) + " miles from Austin. Pink is the road behind you. Blue dots are rivers. Enter to close the map." : ""
          color: app.theme.foreground
          font.family: app.theme.font
          font.pixelSize: 17
        }

        // ----------------------------------------- pace / rations / rest
        Item {
          anchors.fill: parent
          visible: app.view === "game" && (app.overlay === "pace" || app.overlay === "rations" || app.overlay === "rest")
          Text {
            x: 60; y: 14
            text: app.overlay === "pace" ? "Change pace (currently " + (app.game ? Game.paceOf(app.game).name : "") + "):"
              : app.overlay === "rations" ? "Change food rations (currently " + (app.game ? Game.rationsOf(app.game).name : "") + "):"
              : "How many days would you like to rest?"
            color: app.theme.foreground
            font.family: app.theme.font
            font.pixelSize: 19
          }
          Menu {
            id: choiceMenu
            x: 80
            y: 52
            theme: app.theme
            items: app.overlay === "pace" ? app.paceItems : app.overlay === "rations" ? app.rationItems : app.restItems
            menuColumns: app.overlay === "rest" ? 2 : 1
            itemWidth: app.overlay === "rest" ? 260 : 560
            fontSize: 19
            onHighlighted: app.sfx.play("blip")
            onActivated: function(i, item) {
              if (app.overlay === "pace") app.session.setPace(item.value)
              else if (app.overlay === "rations") app.session.setRations(item.value)
              else app.session.rest(item.value)
              app.closeOverlay()
            }
          }
          Text {
            x: 740
            y: 52
            width: 460
            wrapMode: Text.WordWrap
            text: app.overlay === "pace" ? Game.PACES[Math.min(choiceMenu.current, 2)].note
              : app.overlay === "rations" ? Game.RATIONS[Math.min(choiceMenu.current, 2)].note
              : "Resting heals the party and lifts the vibes, but snacks still get eaten. Sick people get better faster in a hammock."
            color: app.theme.dim
            font.family: app.theme.font
            font.pixelSize: 16
            lineHeight: 1.15
          }
        }

        // ---------------------------------------------- forage hint
        Text {
          x: 60
          y: 20
          width: 1160
          visible: app.view === "game" && app.overlay === "forage"
          wrapMode: Text.WordWrap
          text: "Click the food to toss a coupon at it (or aim with the arrows and press Space). Tacos 8 lbs · Kolaches 5 · Burgers 12 · Brisket 30 and fast · Kale salad 0 and disappointing. You can only carry " + Game.FORAGE_CARRY + " lbs back to the truck."
          color: app.theme.foreground
          font.family: app.theme.font
          font.pixelSize: 16
          lineHeight: 1.15
        }

        // ----------------------------------------------------- camp
        Item {
          anchors.fill: parent
          visible: app.view === "game" && app.overlay === "" && (app.mode === "camp" || app.mode === "message")
          Column {
            x: 40
            y: 14
            width: 330
            spacing: 6
            Text {
              text: app.game && app.game.at >= 0 ? Game.LANDMARKS[app.game.at].name : "On the trail"
              color: app.theme.accent
              font.family: app.theme.font
              font.pixelSize: 19
              font.bold: true
              width: parent.width
              elide: Text.ElideRight
            }
            Repeater {
              model: app.game ? [
                ["Pace", Game.paceOf(app.game).name],
                ["Rations", Game.rationsOf(app.game).name],
                ["Vibes", Game.vibesLabel(app.game.vibes)],
                ["Twang", Game.twangTitle(app.game.twang) + " · " + app.game.twang + "%"],
                ["Party", Game.alive(app.game).length + " of 5 alive"]
              ] : []
              Row {
                required property var modelData
                Text { width: 95; text: modelData[0]; color: app.theme.dim; font.family: app.theme.font; font.pixelSize: 16 }
                Text { width: 235; text: modelData[1]; color: app.theme.foreground; font.family: app.theme.font; font.pixelSize: 16; elide: Text.ElideRight }
              }
            }
          }
          Menu {
            id: campMenu
            x: 420
            y: 12
            theme: app.theme
            items: app.campItems
            menuColumns: 2
            itemWidth: 400
            fontSize: 17
            rowHeight: 28
            onActivated: function(i, item) { app.onCamp(item) }
            onHighlighted: app.sfx.play("blip")
          }
        }

        // --------------------------------------------------- travel
        Item {
          anchors.fill: parent
          visible: app.view === "game" && app.overlay === "" && app.mode === "travel"
          Column {
            anchors.centerIn: parent
            spacing: 12
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: app.game ? app.travelLine : ""
              color: app.theme.foreground
              font.family: app.theme.font
              font.pixelSize: 20
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Press SPACE to size up the situation"
              color: app.theme.accent
              font.family: app.theme.font
              font.pixelSize: 17
              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: app.mode === "travel"
                NumberAnimation { to: 0.35; duration: 600 }
                NumberAnimation { to: 1; duration: 600 }
              }
            }
          }
        }

        // ---------------------------------------------------- river
        Item {
          anchors.fill: parent
          visible: app.view === "game" && app.mode === "river" && app.overlay === ""
          Text {
            x: 40
            y: 14
            width: 470
            wrapMode: Text.WordWrap
            text: app.showRiverInfo
              ? "Fording works if the river is under 2.5 feet. Over 4 feet, you will regret it. Caulking floats most of the time and nobody has ever read the instructions. The bridge is safe and costs money. Waiting a day might lower the river. Might."
              : app.prompt && app.prompt.type === "river" ? "You must cross the " + app.prompt.name + ". It is " + app.prompt.width + " feet across and " + app.prompt.depth + " feet deep. The toll bridge costs " + Game.formatMoney(app.prompt.toll) + ". What will you do?" : ""
            color: app.theme.foreground
            font.family: app.theme.font
            font.pixelSize: 17
            lineHeight: 1.15
          }
          Menu {
            id: riverMenu
            x: 560
            y: 12
            theme: app.theme
            items: app.riverItems
            itemWidth: 640
            fontSize: 17
            rowHeight: 28
            onActivated: function(i, item) { app.onRiver(item) }
            onHighlighted: app.sfx.play("blip")
          }
        }

        // ---------------------------------------------------- trade
        Item {
          anchors.fill: parent
          visible: app.view === "game" && app.mode === "trade" && app.overlay === ""
          Text {
            x: 40
            y: 14
            width: 600
            wrapMode: Text.WordWrap
            text: app.prompt && app.prompt.type === "trade"
              ? app.prompt.who + " offers you " + app.prompt.giveQty + " " + app.prompt.giveName + " for " + app.prompt.wantQty + " " + app.prompt.wantName + ". (You have " + Math.floor(app.game[app.prompt.want]) + ".)"
              : ""
            color: app.theme.foreground
            font.family: app.theme.font
            font.pixelSize: 18
            lineHeight: 1.15
          }
          Menu {
            id: tradeMenu
            x: 700
            y: 12
            theme: app.theme
            items: app.tradeItems
            itemWidth: 300
            onActivated: function(i, item) { app.sfx.play("select"); app.session.answerTrade(item.value) }
            onHighlighted: app.sfx.play("blip")
          }
        }

        // ----------------------------------------------------- the end
        Item {
          anchors.fill: parent
          visible: app.view === "game" && app.mode === "end" && app.overlay === ""
          readonly property var breakdown: app.game && app.game.won ? Game.scoreBreakdown(app.game) : null
          Column {
            x: 60
            y: 18
            width: 620
            spacing: 3
            visible: !!parent.breakdown
            Repeater {
              model: parent.parent.breakdown ? parent.parent.breakdown.rows : []
              Row {
                required property var modelData
                Text { width: 480; text: modelData.label; color: app.theme.foreground; font.family: app.theme.font; font.pixelSize: 16 }
                Text { width: 100; horizontalAlignment: Text.AlignRight; text: modelData.pts; color: app.theme.yellow; font.family: app.theme.font; font.pixelSize: 16 }
              }
            }
            Text {
              topPadding: 6
              text: parent.parent.breakdown ? "× " + parent.parent.breakdown.mult + " for being a " + parent.parent.breakdown.occupation + " = " + parent.parent.breakdown.total + " points" : ""
              color: app.theme.accent
              font.family: app.theme.font
              font.pixelSize: 18
              font.bold: true
            }
            Text {
              text: app.game ? "Rating: " + app.game.rating + (app.session.lastRank >= 0 ? " · #" + (app.session.lastRank + 1) + " on the Top Ten!" : "") : ""
              color: app.theme.green
              font.family: app.theme.font
              font.pixelSize: 17
            }
          }
          Column {
            x: 60
            y: 18
            width: 620
            spacing: 4
            visible: !parent.breakdown
            Text { text: "Your party:"; color: app.theme.dim; font.family: app.theme.font; font.pixelSize: 16 }
            Repeater {
              model: app.game && !app.game.won ? app.game.party : []
              Text {
                required property var modelData
                text: modelData.name + " — " + (modelData.alive ? "is stranded in " + Game.STATES[Game.stateAt(app.game.miles)].name + ", living on gas station taquitos" : "died of " + (modelData.cause || "?"))
                color: modelData.alive ? app.theme.foreground : app.theme.red
                font.family: app.theme.font
                font.pixelSize: 16
              }
            }
          }
          Menu {
            id: endMenu
            x: 760
            y: 20
            theme: app.theme
            items: app.endItems
            itemWidth: 420
            onActivated: function(i, item) { app.onEnd(item) }
            onHighlighted: app.sfx.play("blip")
          }
        }
      }

    }

    // sound indicator, top-right corner of the road
    Text {
      x: app.stageW - width - 14
      y: 10
      text: app.session.muted ? "󰝟 muted (M)" : ""
      color: "#f6f1e7"
      style: Text.Outline
      styleColor: "#1b1424"
      font.family: app.theme.font
      font.pixelSize: 13
    }

    // ------------------------------------------------------- the card
    Card {
      id: card
      anchors.fill: parent
      visible: app.mode === "message"
      theme: app.theme
      message: app.message
      onDismissed: { app.session.ack(); app.sfx.play("blip"); Qt.callLater(app.focusStage) }
    }
  }

  readonly property string travelLine: {
    if (!game) return ""
    var lines = {
      ca: ["Cruising past almond orchards and a billboard for a personal injury lawyer.", "Somebody in the back is crying about rent prices. It's you.", "Golden hills, golden hour, golden retriever in the car next to you."],
      az: ["Saguaros wave you through. Arizona doesn't do Daylight Saving, so nobody knows what time it is.", "It's a dry heat. It's 114.", "You pass four signs for THE THING. You will stop. Everybody stops."],
      nm: ["Mesas the color of salsa. The sky is the size of three skies.", "Green chile or red? The answer is Christmas.", "A roadrunner passes you. Meep meep. Humiliating."],
      tx: ["The speed limit is 75 and everybody is doing 90. Including a tractor.", "Every fourth vehicle is a white F-150. Every fifth is also a white F-150.", "You see a sign for Buc-ee's 200 miles away. You can feel it calling."]
    }
    var list = lines[Game.regionOf(game)] || lines.ca
    return "Day " + game.day + " · " + list[game.day % list.length]
  }

  readonly property var learnPages: [
    { title: "THE TRAIL", text: "From 2020 onward, thousands of Californians loaded up rental trucks and drove east, seeking cheaper houses, no state income tax, and breakfast tacos. Many made it. Many more are still at a Buc-ee's somewhere, looking at the jerky wall.\n\nYour job: get your Yoo-Haul from San Francisco to Austin, about 1,880 miles, with as many of your party alive (and as much of your dignity intact) as possible." },
    { title: "SUPPLIES", text: "Gas: 10 miles to the gallon. California gas is $6.89. Arizona, New Mexico and Texas get cheaper and cheaper. Buy enough to reach the next store.\n\nSnacks: everyone eats 1 to 3 pounds a day depending on rations. Run out and people start eating candles.\n\nSunscreen: one bottle a day on scorching days or everybody turns into a lobster. Spare tires and parts: the desert will test you." },
    { title: "PACE & RATIONS", text: "Chill is safe. Hustle is fine. Grindset gets you there fast and makes people sick, sad, and dead.\n\nIntermittent fasting saves snacks but hurts health. Bottomless brunch keeps everyone happy and eats through your supplies.\n\nStop to rest when people get sick. Rest heals. Hammocks heal more." },
    { title: "RIVERS", text: "You'll cross the Colorado River at Needles and the Rio Grande in Albuquerque. Ford shallow rivers. Caulk and float deeper ones (usually fine). Or pay the toll bridge and feel nothing at all.\n\nIf someone dies, you get to write their tombstone. It stays by the road forever, and future trips will pass it." },
    { title: "SCORING", text: "Make it to Austin and you score points for every survivor, by health, plus cash, supplies, Twang (how Texan you've become) and Vibes. Then it's multiplied by your occupation: the Screenwriter earns triple.\n\nTwang goes up when you learn to say y'all, buy a hat, eat a 72 oz steak, and other acts of assimilation." },
    { title: "CONTROLS", text: "Number keys or arrows + Enter pick menu items. The mouse works everywhere.\n\nSpace stops the truck to size up the situation, and dismisses messages.\n\nM mutes the music. F11 goes fullscreen. Ctrl+Q quits. Your trip saves itself after every move, so close the window whenever you want and come back later." }
  ]

  Component.onCompleted: { rollSuggestions(); focusStage() }
}

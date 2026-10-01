import QtQuick

// FOOD TRUCK FRENZY: the hunting minigame, reimagined for people who have
// never hunted anything but a parking spot. Food flies across the road;
// click (or aim with the arrows and press Space) to toss a coupon at it.
// Each toss costs one coupon. Brisket is heavy and fast. Kale is a trap.
Item {
  id: root

  property var theme
  property var sfx
  property int coupons: 0
  property int duration: 30
  signal finished(int lbs, int used)

  property int timeLeft: duration
  property int used: 0
  property int lbs: 0
  property int countdown: 3
  property bool running: false
  property bool over: false
  property point aim: Qt.point(width / 2, height / 2)

  readonly property var kinds: [
    { sprite: "taco", lbs: 8, speed: 1.0, weight: 4 },
    { sprite: "kolache", lbs: 5, speed: 1.25, weight: 3 },
    { sprite: "burger", lbs: 12, speed: 0.95, weight: 2 },
    { sprite: "brisket", lbs: 30, speed: 1.7, weight: 1 },
    { sprite: "salad", lbs: 0, speed: 0.8, weight: 2 }
  ]

  function start() {
    timeLeft = duration
    aim = Qt.point(width / 2, height / 2)
    used = 0
    lbs = 0
    countdown = 3
    running = false
    over = false
    for (var i = 0; i < pool.count; i++) pool.itemAt(i).active = false
    countdownTimer.restart()
    forceActiveFocus()
  }

  function end() {
    if (over) return
    over = true
    running = false
    endTimer.restart()
  }

  function spawn() {
    var total = 0
    for (var k = 0; k < kinds.length; k++) total += kinds[k].weight
    var r = Math.random() * total
    var kind = kinds[0]
    for (var j = 0; j < kinds.length; j++) { r -= kinds[j].weight; if (r < 0) { kind = kinds[j]; break } }
    for (var i = 0; i < pool.count; i++) {
      var t = pool.itemAt(i)
      if (!t.active) { t.launch(kind); return }
    }
  }

  function toss(at) {
    if (!running || used >= coupons) return
    used += 1
    sfx.play("throw")
    flying.launch(at)
    var hit = null
    for (var i = 0; i < pool.count; i++) {
      var t = pool.itemAt(i)
      if (!t.active) continue
      var pad = 14
      if (at.x >= t.x - pad && at.x <= t.x + t.width + pad && at.y >= t.y - pad && at.y <= t.y + t.height + pad) { hit = t; break }
    }
    if (hit) {
      lbs += hit.kind.lbs
      popups.show(at, hit.kind.lbs > 0 ? "+" + hit.kind.lbs + " LBS" : "EW, KALE", hit.kind.lbs > 0)
      sfx.play(hit.kind.lbs > 0 ? "hit" : "bonk")
      hit.active = false
    }
    if (used >= coupons) end()
  }

  Keys.onPressed: function(event) {
    var step = event.modifiers & Qt.ShiftModifier ? 60 : 28
    if (event.key === Qt.Key_Left) aim = Qt.point(Math.max(0, aim.x - step), aim.y)
    else if (event.key === Qt.Key_Right) aim = Qt.point(Math.min(width, aim.x + step), aim.y)
    else if (event.key === Qt.Key_Up) aim = Qt.point(aim.x, Math.max(0, aim.y - step))
    else if (event.key === Qt.Key_Down) aim = Qt.point(aim.x, Math.min(height, aim.y + step))
    else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) toss(aim)
    else if (event.key === Qt.Key_Escape) end()
    else return
    event.accepted = true
  }

  Timer {
    id: countdownTimer
    interval: 700
    repeat: true
    onTriggered: {
      root.countdown -= 1
      root.sfx.play(root.countdown > 0 ? "blip" : "horn")
      if (root.countdown <= 0) { stop(); root.running = true; spawner.restart() }
    }
  }
  Timer {
    id: spawner
    interval: 650
    repeat: true
    running: root.running
    onTriggered: { root.spawn(); interval = 450 + Math.random() * 600 }
  }
  Timer {
    interval: 1000
    repeat: true
    running: root.running
    onTriggered: { root.timeLeft -= 1; if (root.timeLeft <= 0) root.end() }
  }
  Timer {
    id: endTimer
    interval: 1400
    onTriggered: root.finished(root.lbs, root.used)
  }

  // the stage
  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: 0.35
  }

  Repeater {
    id: pool
    model: 10
    PixelArt {
      id: target
      required property int index
      property bool active: false
      property var kind: root.kinds[0]
      property real fromLeft: 1
      property real phase: 0
      property real baseY: 0
      visible: active
      sprite: kind.sprite
      px: 4
      y: baseY + Math.sin(phase * 6.28 * 2) * 18
      function launch(k) {
        kind = k
        fromLeft = Math.random() < 0.5 ? 1 : -1
        baseY = 70 + Math.random() * (root.height - 170)
        mirror = fromLeft < 0
        active = true
        run.duration = (3600 + Math.random() * 1400) / k.speed
        run.from = fromLeft > 0 ? -width - 10 : root.width + 10
        run.to = fromLeft > 0 ? root.width + 10 : -width - 10
        run.restart()
        bob.restart()
      }
      NumberAnimation on x { id: run; running: false; onFinished: target.active = false }
      NumberAnimation on phase { id: bob; running: false; from: 0; to: 1; duration: 2000; loops: Animation.Infinite }
      onActiveChanged: if (!active) { run.stop(); bob.stop() }
    }
  }

  // the coupon in flight
  Rectangle {
    id: flying
    width: 22
    height: 12
    color: "#8fcf5a"
    border.color: "#1b1424"
    border.width: 2
    visible: false
    function launch(at) {
      fly.stop()
      flyX.from = root.width / 2; flyX.to = at.x - width / 2
      flyY.from = root.height; flyY.to = at.y - height / 2
      visible = true
      fly.start()
    }
    ParallelAnimation {
      id: fly
      NumberAnimation { id: flyX; target: flying; property: "x"; duration: 140 }
      NumberAnimation { id: flyY; target: flying; property: "y"; duration: 140 }
      RotationAnimation { target: flying; from: 0; to: 540; duration: 140 }
      onFinished: flying.visible = false
    }
  }

  // "+8 LBS" pop-ups
  Item {
    id: popups
    anchors.fill: parent
    function show(at, text, good) {
      var p = popup.createObject(popups, { x: at.x - 40, y: at.y - 30, text: text, good: good })
    }
    Component {
      id: popup
      PixelText {
        id: pop
        property bool good: true
        px: 3
        color: good ? "#ffe36e" : "#8fcf5a"
        shadow: "#000000"
        NumberAnimation on y { to: pop.y - 60; duration: 800; running: true }
        NumberAnimation on opacity { from: 1; to: 0; duration: 800; running: true; onFinished: pop.destroy() }
      }
    }
  }

  // crosshair
  Item {
    x: root.aim.x - 20
    y: root.aim.y - 20
    width: 40
    height: 40
    visible: root.running
    Rectangle { x: 18; width: 4; height: 14; color: "#ffffff" }
    Rectangle { x: 18; y: 26; width: 4; height: 14; color: "#ffffff" }
    Rectangle { y: 18; width: 14; height: 4; color: "#ffffff" }
    Rectangle { x: 26; y: 18; width: 14; height: 4; color: "#ffffff" }
    Rectangle { x: 17; y: 17; width: 6; height: 6; color: "#ff3b3b" }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.running ? Qt.BlankCursor : Qt.ArrowCursor
    onPositionChanged: function(mouse) { root.aim = Qt.point(mouse.x, mouse.y) }
    onPressed: function(mouse) { root.aim = Qt.point(mouse.x, mouse.y); root.toss(root.aim) }
  }

  // header
  Row {
    x: 30
    y: 18
    spacing: 40
    PixelText { text: "FOOD TRUCK FRENZY"; px: 3.5; color: "#ffe36e"; shadow: "#c24e0c" }
    PixelText { text: "TIME " + root.timeLeft; px: 3.5; color: root.timeLeft <= 5 ? "#ff3b3b" : "#f6f1e7"; shadow: "#000000" }
    PixelText { text: "COUPONS " + (root.coupons - root.used); px: 3.5; color: "#f6f1e7"; shadow: "#000000" }
    PixelText { text: root.lbs + " LBS"; px: 3.5; color: "#8fcf5a"; shadow: "#000000" }
  }

  PixelText {
    anchors.centerIn: parent
    visible: !root.running && !root.over
    text: root.countdown > 0 ? String(root.countdown) : "GO!"
    px: 14
    color: "#ffe36e"
    shadow: "#c24e0c"
    shadowOffset: 1
  }
  PixelText {
    anchors.centerIn: parent
    visible: root.over
    text: root.lbs > 0 ? root.lbs + " LBS BAGGED" : "NOTHING. NADA."
    px: 7
    color: "#ffe36e"
    shadow: "#c24e0c"
  }
}

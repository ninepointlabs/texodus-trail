import QtQuick
import QtQuick.Shapes
import "Game.js" as Game

// The road: a side-scrolling parallax diorama of the drive from the Bay to
// Austin. Sky, sun, three mountain ranges, roadside props, billboards and
// the weather all follow `region`, so California's smoggy pink sunset turns
// into Arizona's red rock, New Mexico's mesas and the big blue Texas sky as
// the miles go by. Everything scrolls off one animated `scroll` value, which
// pauses (rather than resets) when the truck stops.
Item {
  id: root

  property string region: "ca"
  property bool moving: false
  property string weather: "Sunny"
  property var landmark: null
  property bool atRiver: false
  property real speed: 360 // road pixels per second
  property bool showTruck: true

  readonly property real horizon: Math.round(height * 0.58)
  readonly property real roadTop: Math.round(height * 0.76)
  readonly property real roadHeight: Math.round(height * 0.12)
  readonly property real px: 4

  property real scroll: 0
  clip: true

  NumberAnimation on scroll {
    from: 0
    to: 3600000
    duration: 3600000 / root.speed * 1000
    loops: Animation.Infinite
    running: true
    paused: !root.moving
  }

  // ------------------------------------------------------------ palettes --

  readonly property var palettes: ({
    ca: { sky: ["#1e1442", "#6c2a74", "#f2718d", "#ffc58c"], sun: ["#fff27a", "#ff5d9e"], far: "#7b4a92", mid: "#563379", near: "#b88645", ground: ["#d9a45d", "#93622e"], striped: true },
    az: { sky: ["#191c4a", "#64296c", "#ef7247", "#ffcd78"], sun: ["#ffe66d", "#ff6a3d"], far: "#874a6c", mid: "#a5513b", near: "#c86b3e", ground: ["#e2975a", "#a85a2c"], striped: true },
    nm: { sky: ["#14234e", "#3b4b8e", "#f38b68", "#ffd8a0"], sun: ["#fff2a8", "#ff7f6a"], far: "#6c5c9b", mid: "#b0614b", near: "#cf8a55", ground: ["#d8a46a", "#9a6a3e"], striped: true },
    tx: { sky: ["#0c2b6e", "#2a69bd", "#7ab6e8", "#ffe6ad"], sun: ["#fff8c2", "#ffd34d"], far: "#5c7ca7", mid: "#6b8b53", near: "#8ea44e", ground: ["#b8b45e", "#6f7d36"], striped: false }
  })
  readonly property var pal: palettes[region] || palettes.ca

  // ------------------------------------------------------------------ sky --

  Rectangle {
    id: sky
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: root.horizon + 4
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.pal.sky[0]; Behavior on color { ColorAnimation { duration: 2500 } } }
      GradientStop { position: 0.45; color: root.pal.sky[1]; Behavior on color { ColorAnimation { duration: 2500 } } }
      GradientStop { position: 0.8; color: root.pal.sky[2]; Behavior on color { ColorAnimation { duration: 2500 } } }
      GradientStop { position: 1.0; color: root.pal.sky[3]; Behavior on color { ColorAnimation { duration: 2500 } } }
    }
  }

  // stars, fading out as the sky brightens into Texas
  Repeater {
    model: 40
    Rectangle {
      required property int index
      readonly property real seed: Math.abs(Math.sin(index * 91.7) * 1000) % 1
      x: (index * 197.3) % root.width
      y: (index * 53.9) % (root.horizon * 0.45)
      width: seed > 0.8 ? 3 : 2
      height: width
      color: "#fff6d8"
      opacity: root.region === "tx" ? 0 : 0.25 + seed * 0.6
      Behavior on opacity { NumberAnimation { duration: 2500 } }
      SequentialAnimation on scale {
        loops: Animation.Infinite
        running: root.region !== "tx"
        PauseAnimation { duration: 400 + index * 97 % 2000 }
        NumberAnimation { to: 0.3; duration: 500 }
        NumberAnimation { to: 1; duration: 500 }
      }
    }
  }

  // the sun, with a soft glow and those synthwave stripes
  Item {
    id: sun
    width: 190
    height: 190
    x: root.width * 0.66
    y: root.region === "tx" ? root.horizon * 0.18 : root.horizon - height * 0.62
    Behavior on y { NumberAnimation { duration: 2500; easing.type: Easing.InOutQuad } }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 1.9
      height: width
      radius: width / 2
      color: root.pal.sun[1]
      opacity: 0.16
      Behavior on color { ColorAnimation { duration: 2500 } }
    }
    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 1.35
      height: width
      radius: width / 2
      color: root.pal.sun[0]
      opacity: 0.18
      Behavior on color { ColorAnimation { duration: 2500 } }
    }
    Canvas {
      id: sunCanvas
      anchors.fill: parent
      property var colors: root.pal.sun
      property bool striped: root.pal.striped
      onColorsChanged: requestPaint()
      onStripedChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var r = width / 2
        var grad = ctx.createLinearGradient(0, 0, 0, height)
        grad.addColorStop(0, colors[0])
        grad.addColorStop(1, colors[1])
        ctx.fillStyle = grad
        ctx.beginPath()
        ctx.arc(r, r, r, 0, Math.PI * 2)
        ctx.fill()
        if (striped) {
          ctx.globalCompositeOperation = "destination-out"
          // gaps that thicken toward the bottom, on a fixed 16px rhythm
          for (var i = 0, y = r; y < height && i < 12; i++, y += 16)
            ctx.fillRect(0, y, width, Math.min(12, 2 + i * 1.8))
        }
      }
    }
  }

  // drifting clouds
  Repeater {
    model: 4
    Item {
      required property int index
      readonly property real w: 90 + index * 30
      readonly property real speedF: 0.03 + index * 0.012
      x: root.width + 200 - ((root.scroll * speedF + index * 420 + driftOffset) % (root.width + 400))
      y: 30 + index * 34
      property real driftOffset: 0
      NumberAnimation on driftOffset { from: 0; to: 4000; duration: 400000; loops: Animation.Infinite }
      opacity: root.weather === "Smoky" ? 0.4 : 0.85
      Rectangle { x: 0; y: 12; width: parent.w; height: 14; color: "#ffffff"; opacity: root.region === "tx" ? 0.85 : 0.35 }
      Rectangle { x: parent.w * 0.2; y: 4; width: parent.w * 0.45; height: 12; color: "#ffffff"; opacity: root.region === "tx" ? 0.85 : 0.35 }
      Rectangle { x: parent.w * 0.5; y: 0; width: parent.w * 0.3; height: 14; color: "#ffffff"; opacity: root.region === "tx" ? 0.85 : 0.35 }
    }
  }

  // birds flapping by, very slowly
  PixelArt {
    sprite: "bird"
    px: 3
    x: root.width - ((root.scroll * 0.05 + birdDrift) % (root.width + 300))
    y: root.horizon * 0.35
    property real birdDrift: 0
    NumberAnimation on birdDrift { from: 0; to: 3000; duration: 60000; loops: Animation.Infinite }
    SequentialAnimation on scale {
      loops: Animation.Infinite
      NumberAnimation { to: 0.6; duration: 300 }
      NumberAnimation { to: 1; duration: 300 }
    }
  }

  // ------------------------------------------------------------ mountains --

  // A seamless ridge line for one tile width, from a seeded noise walk.
  // Mesas get flat tops in Arizona and New Mexico; Texas is pancake flat.
  function ridge(seed, w, base, amp, style) {
    var pts = []
    var step = 24
    var n = Math.ceil(w / step)
    var vals = []
    var s = seed
    function rnd() { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646 }
    for (var i = 0; i <= n; i++) vals.push(style === "mesa" && i % 5 !== 0 ? vals[i - 1] : rnd())
    vals[n] = vals[0]
    for (var j = 0; j <= n; j++) {
      var v = vals[j]
      if (style === "mesa") v = v > 0.55 ? 0.9 : v > 0.35 ? 0.5 : 0.15
      if (style === "flat") v = 0.2 + v * 0.25
      var smooth = (vals[Math.max(0, j - 1)] + v * 2 + vals[Math.min(n, j + 1)]) / 4
      var vv = style === "mesa" ? v : smooth
      pts.push(Qt.point(j * step, base - vv * amp))
    }
    pts.push(Qt.point(n * step, root.height))
    pts.push(Qt.point(0, root.height))
    pts.push(pts[0])
    return pts
  }

  readonly property string farStyle: region === "tx" ? "flat" : "peaks"
  readonly property string midStyle: region === "az" || region === "nm" ? "mesa" : region === "tx" ? "flat" : "peaks"

  component Ridge: Item {
    id: ridgeLayer
    property Item scene: null
    property real factor: 0.1
    property int seed: 7
    property real base: 0
    property real amp: 60
    property string style: "peaks"
    property color fill: "black"
    readonly property real tileW: Math.ceil(scene.width / 24) * 24
    readonly property var points: scene.ridge(seed, tileW, base, amp, style)
    width: tileW * 2
    height: scene.height
    x: -((scene.scroll * factor) % tileW)

    Repeater {
      model: 2
      Shape {
        required property int index
        x: index * ridgeLayer.tileW
        width: ridgeLayer.tileW
        height: scene.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: 0
          strokeColor: "transparent"
          fillColor: ridgeLayer.fill
          PathPolyline { path: ridgeLayer.points }
        }
      }
    }
    Behavior on fill { ColorAnimation { duration: 2500 } }
  }

  Ridge { scene: root; factor: 0.04; seed: 11; base: root.horizon; amp: root.region === "tx" ? 30 : 120; style: root.farStyle; fill: root.pal.far; opacity: 0.9 }
  Ridge { scene: root; factor: 0.1; seed: 23; base: root.horizon + 6; amp: root.region === "tx" ? 22 : 80; style: root.midStyle; fill: root.pal.mid }
  Ridge { scene: root; factor: 0.22; seed: 37; base: root.horizon + 22; amp: 34; style: "peaks"; fill: root.pal.near }

  // ---------------------------------------------------------------- ground --

  Rectangle {
    id: ground
    y: root.horizon + 22
    width: root.width
    height: root.height - y
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.pal.ground[0]; Behavior on color { ColorAnimation { duration: 2500 } } }
      GradientStop { position: 1.0; color: root.pal.ground[1]; Behavior on color { ColorAnimation { duration: 2500 } } }
    }
  }

  // ground speckle that sells the speed
  Repeater {
    model: 26
    Rectangle {
      required property int index
      readonly property real lane: (index * 37) % 100 / 100
      readonly property real f: 0.4 + lane * 0.9
      x: root.width + 20 - ((root.scroll * f + index * 211) % (root.width + 40))
      y: root.horizon + 30 + lane * (root.roadTop - root.horizon - 40)
      width: 4 + lane * 6
      height: 3
      color: Qt.darker(root.pal.ground[1], 1.2)
      opacity: 0.5
    }
  }

  // --------------------------------------------------------- back props --

  readonly property var backProps: ({
    ca: ["palm", "palm", "joshua", "", "rock", "palm"],
    az: ["saguaro", "joshua", "saguaro", "", "cactus", "rock"],
    nm: ["cactus", "rock", "windmill", "", "cactus", "rock"],
    tx: ["pumpjack", "windmill", "longhorn", "", "pumpjack", "cactus"]
  })

  Repeater {
    model: 7
    PixelArt {
      id: prop
      required property int index
      readonly property real span: root.width + 500
      readonly property real factor: 0.62
      readonly property real travel: root.scroll * factor + index * span / 7 + (index * 73) % 90
      readonly property int lap: Math.floor(travel / span)
      px: 3
      x: root.width + 250 - (travel % span)
      y: root.roadTop - height - 4 - (index % 3) * 10
      z: 1
      function choose() {
        var list = root.backProps[root.region] || root.backProps.ca
        sprite = list[Math.abs(lap * 5 + index * 3) % list.length]
      }
      onLapChanged: choose()
      Component.onCompleted: choose()
      Connections {
        target: root
        function onRegionChanged() { if (prop.x < -prop.width || prop.x > root.width || !root.moving) prop.choose() }
      }
    }
  }

  // ------------------------------------------------------------ billboard --

  readonly property var boards: Game.BILLBOARDS
  Item {
    id: billboard
    readonly property real span: root.width * 2.4
    readonly property real travel: root.scroll * 0.7 + root.width * 0.9
    readonly property int lap: Math.floor(travel / span)
    property string message: ""
    x: root.width + 200 - (travel % span)
    y: root.roadTop - height - 2
    z: 2
    // never stand in front of (or behind) a landmark sign
    visible: !landmarkSign.visible || x + width < landmarkSign.x - 20 || x > landmarkSign.x + landmarkSign.width + 20
    width: board.width
    readonly property real postHeight: 96
    height: board.height + postHeight
    function choose() {
      var list = root.boards[root.region] || root.boards.ca
      message = list[Math.abs(lap * 3 + 1) % list.length]
    }
    onLapChanged: choose()
    Component.onCompleted: choose()
    Connections {
      target: root
      function onRegionChanged() { if (billboard.x < -billboard.width || billboard.x > root.width || !root.moving) billboard.choose() }
    }

    Rectangle { x: board.width * 0.2; y: board.height; width: 8; height: billboard.postHeight; color: "#4a3426" }
    Rectangle { x: board.width * 0.75; y: board.height; width: 8; height: billboard.postHeight; color: "#4a3426" }
    Rectangle {
      id: board
      width: boardText.width + 32
      height: boardText.height + 26
      color: "#1b1430"
      border.color: "#f6f1e7"
      border.width: 4
      PixelText {
        id: boardText
        anchors.centerIn: parent
        text: billboard.message
        px: 2.5
        color: "#ffe36e"
        shadow: "#c24e0c"
      }
      // marquee bulbs
      Repeater {
        model: Math.floor(board.width / 18)
        Rectangle {
          required property int index
          x: 9 + index * 18
          y: -4
          width: 5
          height: 5
          radius: 3
          color: (index + bulbPhase.phase) % 2 ? "#ffe36e" : "#ff7a1a"
        }
      }
    }
  }
  QtObject {
    id: bulbPhase
    property int phase: 0
  }
  Timer { interval: 450; running: true; repeat: true; onTriggered: bulbPhase.phase = (bulbPhase.phase + 1) % 2 }

  // ------------------------------------------------------- landmark signs --

  Item {
    id: landmarkSign
    readonly property bool texas: root.landmark && root.landmark.mile === 1300
    readonly property bool austin: root.landmark && root.landmark.mile >= 1880
    visible: root.landmark !== null && !root.moving && !root.atRiver
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 400 } }
    x: root.width * 0.6
    y: root.roadTop - height + 6
    width: signBoard.width
    height: signBoard.height + 70
    z: 3

    Rectangle { x: signBoard.width * 0.18; y: signBoard.height; width: 10; height: 70; color: "#9aa0ad" }
    Rectangle { x: signBoard.width * 0.78; y: signBoard.height; width: 10; height: 70; color: "#9aa0ad" }
    Rectangle {
      id: signBoard
      width: Math.max(signTitle.width, signSub.width) + 48 + (landmarkSign.texas ? 70 : 0)
      height: signTitle.height + signSub.height + 44
      radius: 8
      color: landmarkSign.texas ? "#1c3f8f" : landmarkSign.austin ? "#7a1f2b" : "#1f6b3a"
      border.color: "#f6f1e7"
      border.width: 4
      PixelArt {
        visible: landmarkSign.texas
        sprite: "star"
        px: 3
        x: 18
        anchors.verticalCenter: parent.verticalCenter
      }
      PixelText {
        id: signTitle
        x: landmarkSign.texas ? 94 : 24
        y: 16
        text: landmarkSign.texas ? "WELCOME TO TEXAS" : landmarkSign.austin ? "AUSTIN CITY LIMITS" : root.landmark ? root.landmark.short : ""
        px: 3.5
        color: "#f6f1e7"
      }
      PixelText {
        id: signSub
        x: signTitle.x
        anchors.top: signTitle.bottom
        anchors.topMargin: 8
        text: landmarkSign.texas ? "DRIVE FRIENDLY - THE TEXAS WAY" : landmarkSign.austin ? "KEEP IT WEIRD · POP 2,473,275 + YOU" : root.landmark ? "MILE " + root.landmark.mile + " · " + Game.STATES[Game.stateAt(root.landmark.mile)].name : ""
        px: 2
        color: "#ffe36e"
      }
    }
  }

  // ----------------------------------------------------------------- road --

  Rectangle {
    id: road
    y: root.roadTop
    width: root.width
    height: root.roadHeight
    color: "#3a3443"
    z: 4
    Rectangle { width: parent.width; height: 4; color: "#5d5568" }
    Rectangle { y: parent.height - 4; width: parent.width; height: 4; color: "#27222f" }
    Item {
      x: -(root.scroll % 96)
      y: parent.height / 2 - 3
      Repeater {
        model: Math.ceil(root.width / 96) + 2
        Rectangle {
          required property int index
          x: index * 96
          width: 48
          height: 6
          color: "#ffd84a"
        }
      }
    }
  }

  // the river, when there's a river
  Item {
    id: river
    visible: root.atRiver
    x: root.width * 0.56
    y: root.horizon + 30
    width: root.width - x
    height: root.height - y
    z: 5
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: "#3fa6d6" }
        GradientStop { position: 1; color: "#1d5a8f" }
      }
    }
    Rectangle { width: 10; height: parent.height; color: "#c79a55" }
    Repeater {
      model: 18
      Rectangle {
        required property int index
        property real phase: 0
        NumberAnimation on phase { from: 0; to: 1; duration: 2400 + index * 90; loops: Animation.Infinite; running: river.visible }
        x: 20 + ((index * 83 + phase * 160) % (river.width - 40))
        y: 14 + (index * 37) % (river.height - 24)
        width: 26
        height: 4
        color: "#d8f3ff"
        opacity: 0.7 * Math.sin(phase * Math.PI)
      }
    }
  }

  // ---------------------------------------------------------------- truck --

  Item {
    id: truck
    visible: root.showTruck
    readonly property real p: root.px
    x: root.width * 0.26
    y: root.roadTop + root.roadHeight * 0.55 - body.height + bob
    width: body.width
    height: body.height
    z: 6
    property real bob: 0
    property int wheelFrame: 0

    Timer {
      interval: 140
      repeat: true
      running: root.moving
      onTriggered: {
        truck.bob = truck.bob === 0 ? -truck.p : 0
        truck.wheelFrame = 1 - truck.wheelFrame
      }
      onRunningChanged: if (!running) truck.bob = 0
    }

    // shadow
    Rectangle {
      x: 4
      y: body.height - 6 - truck.bob
      width: body.width - 4
      height: 10
      radius: 5
      color: "#000000"
      opacity: 0.25
    }

    PixelArt { id: body; sprite: "truck"; px: truck.p }
    // lettering at 3/4 of the art pixel, which is a whole screen pixel at px 4
    PixelText {
      text: "YOO-HAUL"
      px: truck.p * 0.75
      color: "#c24e0c"
      x: Math.round(23 * truck.p - width / 2)
      y: Math.round(9.5 * truck.p - height / 2)
    }
    PixelArt { sprite: truck.wheelFrame ? "wheel1" : "wheel0"; px: truck.p; x: 6 * truck.p; y: 19 * truck.p - truck.bob }
    PixelArt { sprite: truck.wheelFrame ? "wheel1" : "wheel0"; px: truck.p; x: 49 * truck.p; y: 19 * truck.p - truck.bob }

    // exhaust puffs out of the tailpipe
    Repeater {
      model: 4
      Rectangle {
        id: puff
        required property int index
        width: 14
        height: 14
        radius: 7
        color: "#d9d3dd"
        x: -6
        y: 25 * truck.p - 8
        opacity: 0
        SequentialAnimation {
          running: root.moving
          loops: Animation.Infinite
          PauseAnimation { duration: puff.index * 220 }
          ParallelAnimation {
            NumberAnimation { target: puff; property: "x"; from: -6; to: -70; duration: 880 }
            NumberAnimation { target: puff; property: "y"; from: 25 * truck.p - 8; to: 25 * truck.p - 40; duration: 880 }
            NumberAnimation { target: puff; property: "opacity"; from: 0.7; to: 0; duration: 880 }
            NumberAnimation { target: puff; property: "scale"; from: 0.6; to: 2.2; duration: 880 }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------- front props --

  Repeater {
    model: 3
    PixelArt {
      id: front
      required property int index
      readonly property real span: root.width * 1.9
      readonly property real travel: root.scroll * 1.45 + index * span / 3 + 300
      readonly property int lap: Math.floor(travel / span)
      px: 5
      x: root.width + 200 - (travel % span)
      y: root.height - height + 8
      z: 7
      function choose() {
        var list = root.region === "ca" ? ["rock", "", "cactus"] : root.region === "tx" ? ["cactus", "", "rock", ""] : ["cactus", "rock", ""]
        sprite = list[Math.abs(lap * 2 + index) % list.length]
      }
      onLapChanged: choose()
      Component.onCompleted: choose()
    }
  }

  // a tumbleweed now and then, moving or not, because the desert insists
  PixelArt {
    id: tumble
    sprite: "tumbleweed"
    px: 4
    z: 7
    visible: root.region !== "ca"
    x: -100
    y: root.roadTop + root.roadHeight - height
    property real hop: 0
    transform: Translate { y: -tumble.hop }
    SequentialAnimation {
      running: tumble.visible
      loops: Animation.Infinite
      PauseAnimation { duration: 5000 }
      ParallelAnimation {
        NumberAnimation { target: tumble; property: "x"; from: root.width + 40; to: -120; duration: root.moving ? 2600 : 5200 }
        RotationAnimation { target: tumble; from: 0; to: -720; duration: root.moving ? 2600 : 5200 }
        SequentialAnimation {
          loops: 4
          NumberAnimation { target: tumble; property: "hop"; from: 0; to: 28; duration: root.moving ? 320 : 650; easing.type: Easing.OutQuad }
          NumberAnimation { target: tumble; property: "hop"; from: 28; to: 0; duration: root.moving ? 320 : 650; easing.type: Easing.InQuad }
        }
      }
      PauseAnimation { duration: 9000 }
    }
  }

  // -------------------------------------------------------------- weather --

  Rectangle {
    anchors.fill: parent
    z: 8
    color: root.weather === "Smoky" ? "#ff8a3d"
         : root.weather === "Dust storm" ? "#b27a46"
         : root.weather === "Foggy" ? "#e6e2ea"
         : root.weather === "Tornado watch" ? "#3d5a3a"
         : root.weather === "Scorching" ? "#ffb347"
         : root.weather === "Humid" ? "#c8e6f0" : "transparent"
    opacity: root.weather === "Dust storm" ? 0.5 : root.weather === "Foggy" ? 0.4 : root.weather === "Scorching" ? 0.14 : 0.28
    Behavior on color { ColorAnimation { duration: 1200 } }
  }

  // snow, hail, and dust streaks share one particle field
  Item {
    id: field
    anchors.fill: parent
    z: 9
    readonly property string kind: root.weather === "Snowy" ? "snow" : root.weather === "Hail" ? "hail" : root.weather === "Dust storm" ? "dust" : ""
    visible: kind !== ""
    Repeater {
      model: 70
      Rectangle {
        id: flake
        required property int index
        readonly property real seed: (index * 0.6180339) % 1
        property real t: 0
        NumberAnimation on t { from: 0; to: 1; duration: field.kind === "hail" ? 700 + flake.seed * 400 : field.kind === "dust" ? 900 + flake.seed * 600 : 3200 + flake.seed * 2400; loops: Animation.Infinite; running: field.visible }
        width: field.kind === "dust" ? 26 + seed * 30 : field.kind === "hail" ? 6 : 4 + Math.round(seed * 3)
        height: field.kind === "dust" ? 2 : width
        radius: field.kind === "hail" ? 3 : 0
        color: field.kind === "dust" ? "#f1c48a" : "#ffffff"
        opacity: field.kind === "dust" ? 0.6 : 0.9
        readonly property real seed2: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
        x: field.kind === "dust" ? root.width - ((t + seed2) % 1) * (root.width + 100) : (seed * root.width + t * (field.kind === "snow" ? 60 : -40)) % root.width
        y: field.kind === "dust" ? seed * root.height : ((t + seed2) % 1) * root.height
      }
    }
  }

  // heat shimmer on scorching days: the horizon wobbles
  Rectangle {
    visible: root.weather === "Scorching"
    z: 8
    y: root.horizon + 12
    width: root.width
    height: 18
    color: "#fff2c0"
    opacity: 0.22
    SequentialAnimation on y {
      running: root.weather === "Scorching"
      loops: Animation.Infinite
      NumberAnimation { to: root.horizon + 8; duration: 700; easing.type: Easing.InOutSine }
      NumberAnimation { to: root.horizon + 14; duration: 700; easing.type: Easing.InOutSine }
    }
  }

  // ------------------------------------------------------- CRT finishing --

  Canvas {
    anchors.fill: parent
    z: 20
    opacity: 0.09
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.fillStyle = "#000000"
      for (var y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1)
    }
  }
  Rectangle {
    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    height: 60
    z: 20
    gradient: Gradient { GradientStop { position: 0; color: "#66000000" } GradientStop { position: 1; color: "transparent" } }
  }
  Rectangle {
    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
    height: 40
    z: 20
    gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: "#55000000" } }
  }
}

import QtQuick
import "Game.js" as Game

// "Look at map": the southwest drawn like a road atlas from a gas station
// in 1987. State outlines are rough lon/lat polygons, the route follows the
// landmarks, and a little Yoo-Haul sits wherever you are.
Item {
  id: root

  property var theme
  property var game: null

  readonly property var states: [
    { id: "ca", name: "CALIFORNIA", label: [-120.6, 37.4], pts: [[-124.2, 42], [-120, 42], [-120, 39], [-114.6, 35], [-114.7, 32.7], [-117.1, 32.5], [-118.5, 34], [-120.6, 34.6], [-121.9, 36.6], [-122.5, 37.8], [-123.8, 39.8]] },
    { id: "nv", name: "NEVADA", label: [-117.2, 39.6], pts: [[-120, 42], [-114, 42], [-114, 36.1], [-114.6, 35], [-120, 39]] },
    { id: "ut", name: "UTAH", label: [-111.7, 39.4], pts: [[-114, 42], [-111, 42], [-111, 41], [-109.05, 41], [-109.05, 37], [-114, 37]] },
    { id: "co", name: "COLORADO", label: [-105.6, 39.0], pts: [[-109.05, 41], [-102.05, 41], [-102.05, 37], [-109.05, 37]] },
    { id: "az", name: "ARIZONA", label: [-111.9, 33.9], pts: [[-114.8, 37], [-109.05, 37], [-109.05, 31.33], [-111.07, 31.33], [-114.8, 32.5], [-114.6, 35], [-114, 36.1], [-114, 37]] },
    { id: "nm", name: "NEW MEXICO", label: [-106.1, 33.9], pts: [[-109.05, 37], [-103, 37], [-103, 32], [-106.6, 32], [-106.5, 31.8], [-108.2, 31.8], [-108.2, 31.33], [-109.05, 31.33]] },
    { id: "ok", name: "OKLAHOMA", label: [-97.4, 35.6], pts: [[-103, 37], [-94.6, 37], [-94.4, 35.4], [-94.5, 33.6], [-97.5, 33.9], [-100, 34.56], [-100, 36.5], [-103, 36.5]] },
    { id: "tx", name: "TEXAS", label: [-99.3, 31.2], pts: [[-106.6, 32], [-103, 32], [-103, 36.5], [-100, 36.5], [-100, 34.56], [-97.5, 33.9], [-94.0, 33.6], [-94.04, 33.0], [-93.5, 31], [-93.8, 29.7], [-94.7, 29.3], [-97.2, 27.6], [-97.4, 25.9], [-99.1, 26.4], [-100.3, 28.0], [-101.4, 29.8], [-103.0, 29.0], [-104.5, 29.6], [-106.5, 31.8]] }
  ]

  // one lon/lat per landmark, same order as Game.LANDMARKS
  readonly property var stops: [
    [-122.42, 37.77], [-119.02, 35.37], [-117.02, 34.9], [-114.6, 34.85], [-114.05, 35.19],
    [-111.65, 35.2], [-110.7, 35.02], [-106.68, 35.08], [-106.62, 35.09], [-103.72, 35.17],
    [-103.04, 35.18], [-101.83, 35.22], [-101.85, 33.58], [-99.73, 32.45], [-97.74, 30.27]
  ]

  readonly property real lonMin: -124.8
  readonly property real lonMax: -93.2
  readonly property real latMax: 42.2
  readonly property real latMin: 29.4
  readonly property real k: Math.min((width - 60) / (lonMax - lonMin), (height - 20) / ((latMax - latMin) * 1.12))
  readonly property real ox: (width - (lonMax - lonMin) * k) / 2
  readonly property real oy: (height - (latMax - latMin) * 1.12 * k) / 2 + 6

  function project(p) { return Qt.point(ox + (p[0] - lonMin) * k, oy + (latMax - p[1]) * 1.12 * k) }

  // where along the route the truck is, as a point between two stops
  function truckPoint() {
    if (!game) return project(stops[0])
    var L = Game.LANDMARKS
    for (var i = 0; i < L.length - 1; i++) {
      if (game.miles <= L[i + 1].mile) {
        var t = (game.miles - L[i].mile) / Math.max(1, L[i + 1].mile - L[i].mile)
        var a = project(stops[i]), b = project(stops[i + 1])
        return Qt.point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
      }
    }
    return project(stops[stops.length - 1])
  }

  readonly property point truckAt: truckPoint()

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: "#173a5c" }
      GradientStop { position: 1; color: "#0f2a45" }
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    property var g: root.game
    onGChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var fills = { ca: "#e9b97a", nv: "#cfc0a0", ut: "#cfc0a0", co: "#cfc0a0", az: "#e8a06a", nm: "#e6c07c", ok: "#cfc0a0", tx: "#c9d48a" }
      for (var i = 0; i < root.states.length; i++) {
        var s = root.states[i]
        ctx.beginPath()
        for (var j = 0; j < s.pts.length; j++) {
          var p = root.project(s.pts[j])
          if (j === 0) ctx.moveTo(p.x, p.y); else ctx.lineTo(p.x, p.y)
        }
        ctx.closePath()
        ctx.fillStyle = fills[s.id]
        ctx.globalAlpha = ["ca", "az", "nm", "tx"].indexOf(s.id) >= 0 ? 1 : 0.45
        ctx.fill()
        ctx.globalAlpha = 1
        ctx.lineWidth = 2
        ctx.strokeStyle = "#5a3a20"
        ctx.stroke()
      }
      // the route: dashed ahead, solid behind
      var miles = root.game ? root.game.miles : 0
      for (var r = 0; r < root.stops.length - 1; r++) {
        var a = root.project(root.stops[r]), b = root.project(root.stops[r + 1])
        var done = miles >= Game.LANDMARKS[r + 1].mile
        ctx.beginPath()
        ctx.moveTo(a.x, a.y)
        ctx.lineTo(b.x, b.y)
        ctx.lineWidth = done ? 5 : 3
        ctx.strokeStyle = done ? "#c2185b" : "#7b2f4a"
        if (!done) ctx.setLineDash([6, 6]); else ctx.setLineDash([])
        ctx.stroke()
      }
      ctx.setLineDash([])
    }
  }

  Repeater {
    model: root.states
    Text {
      required property var modelData
      readonly property point at: root.project(modelData.label)
      x: at.x - width / 2
      y: at.y - height / 2
      text: modelData.name
      color: "#5a3a20"
      opacity: ["ca", "az", "nm", "tx"].indexOf(modelData.id) >= 0 ? 0.8 : 0.4
      font.family: root.theme.font
      font.pixelSize: modelData.id === "tx" ? 34 : 15
      font.bold: true
      font.letterSpacing: 3
    }
  }

  Repeater {
    model: Game.LANDMARKS
    Item {
      id: stop
      required property int index
      required property var modelData
      readonly property point at: root.project(root.stops[index])
      readonly property bool passed: root.game && root.game.miles >= modelData.mile
      x: at.x
      y: at.y
      Rectangle {
        x: -width / 2
        y: -height / 2
        width: stop.index === 0 || stop.index === Game.LANDMARKS.length - 1 ? 14 : 9
        height: width
        radius: stop.modelData.river ? width / 2 : 0
        color: stop.modelData.river ? "#3fa6d6" : stop.passed ? "#c2185b" : "#f6f1e7"
        border.color: "#1b1424"
        border.width: 2
      }
      Text {
        // stagger labels so the I-40 corridor stays readable
        x: 8
        y: [1, 5, 9, 12].indexOf(stop.index) >= 0 ? 6 : -height - 4
        text: stop.modelData.short
        visible: [3, 7, 10].indexOf(stop.index) === -1
        color: "#1b1424"
        style: Text.Outline
        styleColor: "#f6f1e7"
        font.family: root.theme.font
        font.pixelSize: 15
        font.bold: true
      }
    }
  }

  PixelArt {
    sprite: "truck"
    px: 0.9
    x: root.truckAt.x - width / 2
    y: root.truckAt.y - height - 4
    SequentialAnimation on opacity {
      loops: Animation.Infinite
      NumberAnimation { to: 0.4; duration: 400 }
      NumberAnimation { to: 1; duration: 400 }
    }
  }

  PixelText {
    x: 24
    y: 20
    text: "THE TEXODUS TRAIL · ROAD ATLAS"
    px: 2.5
    color: "#f6f1e7"
    shadow: "#000000"
  }
  Text {
    x: 24
    y: 46
    text: "Not to scale. Not to be trusted. Do not use for actual navigation."
    color: "#f6f1e7"
    opacity: 0.7
    font.family: root.theme.font
    font.pixelSize: 13
    font.italic: true
  }
}

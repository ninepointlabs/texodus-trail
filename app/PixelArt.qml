import QtQuick
import "Sprites.js" as Sprites

// One sprite from Sprites.js, painted once at `px` screen pixels per art
// pixel. Moving it around is free; only changing the sprite repaints.
Canvas {
  id: root

  property string sprite: ""
  property real px: 4
  property bool mirror: false
  // Paint every opaque pixel in this colour instead (silhouettes, shadows).
  property color tint: "transparent"
  readonly property var rows: Sprites.SPRITES[sprite] || []

  width: rows.length ? rows[0].length * px : 0
  height: rows.length * px
  renderStrategy: Canvas.Cooperative
  antialiasing: false
  // nearest-neighbour when the window scales the stage: crisp pixels, no smear
  smooth: false

  onRowsChanged: requestPaint()
  onPxChanged: requestPaint()
  onMirrorChanged: requestPaint()
  onTintChanged: requestPaint()
  onWidthChanged: requestPaint()
  // a Canvas that was hidden when its content changed never paints on its own
  onVisibleChanged: if (visible) requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var r = rows
    if (!r.length) return
    var w = r[0].length
    var useTint = tint.a > 0
    var p = px
    for (var y = 0; y < r.length; y++) {
      var row = r[y]
      var x = 0
      while (x < w) {
        var c = row.charAt(x)
        if (c === ".") { x++; continue }
        // run-length: paint horizontal runs of one colour in one rect
        var run = 1
        while (x + run < w && row.charAt(x + run) === c) run++
        ctx.fillStyle = useTint ? tint : Sprites.PALETTE[c]
        var dx = mirror ? (w - x - run) : x
        ctx.fillRect(Math.floor(dx * p), Math.floor(y * p), Math.ceil(run * p), Math.ceil(p))
        x += run
      }
    }
  }
}

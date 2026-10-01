import QtQuick
import "Sprites.js" as Sprites

// Big chunky headings in the 5x7 bitmap font from Sprites.js, with an
// optional hard drop shadow for that 1985 title-screen look.
Canvas {
  id: root

  property string text: ""
  property real px: 4
  property color color: "white"
  property color shadow: "transparent"
  property int shadowOffset: 1
  property int spacing: 1
  // A second colour for the bottom rows: cheap two-tone chrome lettering.
  property color lowerColor: "transparent"
  // A 1-art-pixel outline all the way around, for text over busy scenery.
  property color outline: "transparent"
  readonly property int pad: outline.a > 0 ? 1 : 0

  readonly property string upper: String(text).toUpperCase()
  readonly property int glyphs: upper.length

  width: Math.max(0, glyphs * (5 + spacing) - spacing + (shadow.a > 0 ? shadowOffset : 0) + pad * 2) * px
  height: (7 + (shadow.a > 0 ? shadowOffset : 0) + pad * 2) * px
  renderStrategy: Canvas.Cooperative
  antialiasing: false
  // nearest-neighbour when the window scales the stage: crisp pixels, no smear
  smooth: false

  onUpperChanged: requestPaint()
  onPxChanged: requestPaint()
  onColorChanged: requestPaint()
  onShadowChanged: requestPaint()
  onLowerColorChanged: requestPaint()
  onOutlineChanged: requestPaint()
  onWidthChanged: requestPaint()
  // a Canvas that was hidden when its content changed never paints on its own
  onVisibleChanged: if (visible) requestPaint()

  function paintText(ctx, ox, oy, fill, lower) {
    var p = px
    for (var i = 0; i < upper.length; i++) {
      var g = Sprites.FONT[upper.charAt(i)] || Sprites.FONT["?"]
      var gx = ox + i * (5 + spacing)
      for (var y = 0; y < 7; y++) {
        ctx.fillStyle = lower && y >= 4 ? lower : fill
        var row = g[y]
        for (var x = 0; x < 5; x++) {
          if (row.charAt(x) === "1") ctx.fillRect(Math.floor((gx + x) * p), Math.floor((oy + y) * p), Math.ceil(p), Math.ceil(p))
        }
      }
    }
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var o = pad
    if (outline.a > 0) {
      var offs = [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1]]
      for (var i = 0; i < offs.length; i++) {
        paintText(ctx, o + offs[i][0], o + offs[i][1], outline, null)
        if (shadow.a > 0) paintText(ctx, o + shadowOffset + offs[i][0], o + shadowOffset + offs[i][1], outline, null)
      }
    }
    if (shadow.a > 0) paintText(ctx, o + shadowOffset, o + shadowOffset, shadow, null)
    paintText(ctx, o, o, color, lowerColor.a > 0 ? lowerColor : null)
  }
}

import QtQuick
import "Game.js" as Game

// The general store, whichever one this is: Costco in Daly City, a
// trading post in Flagstaff, or a Buc-ee's the size of an airport. Pick a
// row, Right/Left (or +/-) to fill the cart, Enter to check out, Escape to
// walk away. Prices follow the state: California charges extra for vibes.
Item {
  id: root

  property var theme
  property var session
  property var sfx
  property bool firstStore: false
  signal closed()

  readonly property var game: session ? session.game : null
  readonly property string storeName: game ? Game.storeHere(game) : ""
  readonly property bool texas: game && Game.regionOf(game) === "tx"

  readonly property var rows: {
    var out = []
    if (!game) return out
    for (var i = 0; i < Game.GOODS.length; i++) {
      var g = Game.GOODS[i]
      out.push({ id: g.id, name: g.name, unit: g.unit, step: g.step, price: Game.price(game, g.id), have: game[g.id], note: g.note })
    }
    if (texas) out.push({ id: "hat", name: "Cowboy hat", unit: "hats", step: 1, price: Game.HAT_PRICE, have: game.hats, note: "Twang +8 per head (up to five). Don't call it a cowboy hat. It's a hat." })
    return out
  }

  property var cart: ({})
  property int current: 0

  readonly property real total: {
    var t = 0
    for (var i = 0; i < rows.length; i++) t += (cart[rows[i].id] || 0) * rows[i].price
    return Math.round(t * 100) / 100
  }

  function reset() { cart = ({}); current = 0 }

  function adjust(delta) {
    var r = rows[current]
    if (!r) return
    var next = Object.assign({}, cart)
    var q = (next[r.id] || 0) + delta * r.step
    next[r.id] = Math.max(0, q)
    cart = next
    sfx.play("blip")
  }

  function checkout() {
    if (total > game.cash + 0.001) { sfx.play("bonk"); session.storeError = "That's " + Game.formatPrice(total) + ". You have " + Game.formatMoney(game.cash) + ". Put something back."; return }
    var bought = false
    for (var i = 0; i < rows.length; i++) {
      var q = cart[rows[i].id] || 0
      if (q > 0) { if (session.buy(rows[i].id, q)) bought = true }
    }
    cart = ({})
    sfx.play(bought ? "coin" : "blip")
  }

  function handleKey(event) {
    var t = String(event.text || "")
    if (event.key === Qt.Key_Up) { current = (current - 1 + rows.length) % rows.length; return true }
    if (event.key === Qt.Key_Down) { current = (current + 1) % rows.length; return true }
    if (event.key === Qt.Key_Right || t === "+" || t === "=") { adjust(1); return true }
    if (event.key === Qt.Key_Left || t === "-" || t === "_") { adjust(-1); return true }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (total > 0) checkout(); else closed(); return true }
    if (event.key === Qt.Key_Escape) { cart = ({}); closed(); return true }
    return false
  }

  Column {
    x: 40
    y: 18
    spacing: 8
    width: root.width - 80

    Row {
      spacing: 20
      PixelText { text: root.storeName; px: 3; color: root.theme.accent; shadow: "#000000" }
      Text {
        anchors.bottom: parent.bottom
        text: Game.formatMoney(root.game ? root.game.cash : 0) + " in your wallet · gas here " + (root.game ? Game.formatPrice(Game.price(root.game, "gas")) : "") + "/gal"
        color: root.theme.green
        font.family: root.theme.font
        font.pixelSize: 17
      }
    }

    Row {
      spacing: 30
      Column {
        id: table
        width: 720
        spacing: 1
        Repeater {
          model: root.rows
          Rectangle {
            id: line
            required property int index
            required property var modelData
            readonly property bool on: root.current === index
            readonly property int qty: root.cart[modelData.id] || 0
            width: table.width
            height: 30
            color: on ? root.theme.selection : "transparent"
            border.width: on ? 2 : 0
            border.color: root.theme.accent
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: line.modelData.name; color: root.theme.foreground; font.family: root.theme.font; font.pixelSize: 18; width: 200; elide: Text.ElideRight }
            Text { x: 220; anchors.verticalCenter: parent.verticalCenter; text: Game.formatPrice(line.modelData.price) + "/" + ({ gal: "gal", lbs: "lb", bottles: "bottle", tires: "tire", parts: "part", coupons: "coupon", hats: "hat" })[line.modelData.unit]; color: root.theme.yellow; font.family: root.theme.font; font.pixelSize: 17 }
            Text { x: 380; anchors.verticalCenter: parent.verticalCenter; text: "have " + Math.floor(line.modelData.have); color: root.theme.dim; font.family: root.theme.font; font.pixelSize: 16 }
            Row {
              x: 470
              anchors.verticalCenter: parent.verticalCenter
              spacing: 10
              Rectangle {
                width: 26; height: 22; color: root.theme.darkerBackground; border.color: root.theme.muted
                Text { anchors.centerIn: parent; text: "−"; color: root.theme.foreground; font.pixelSize: 16; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: { root.current = line.index; root.adjust(-1) } }
              }
              Text { width: 70; horizontalAlignment: Text.AlignHCenter; text: line.qty > 0 ? "+" + line.qty : "·"; color: line.qty > 0 ? root.theme.accent : root.theme.muted; font.family: root.theme.font; font.pixelSize: 18; font.bold: true }
              Rectangle {
                width: 26; height: 22; color: root.theme.darkerBackground; border.color: root.theme.muted
                Text { anchors.centerIn: parent; text: "+"; color: root.theme.foreground; font.pixelSize: 16; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: { root.current = line.index; root.adjust(1) } }
              }
            }
            Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: line.qty > 0 ? Game.formatPrice(line.qty * line.modelData.price) : ""; color: root.theme.foreground; font.family: root.theme.font; font.pixelSize: 17 }
            MouseArea { anchors.fill: parent; z: -1; onClicked: root.current = line.index }
          }
        }
      }

      Column {
        width: 400
        spacing: 10
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: root.rows[root.current] ? root.rows[root.current].note : ""
          color: root.theme.foreground
          font.family: root.theme.font
          font.pixelSize: 16
          lineHeight: 1.15
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          visible: root.firstStore
          text: "Kyle from Costco says: \"Most folks take about 150 gallons, 300 lbs of snacks, a few bottles of sunscreen and a couple spare tires. Gas gets cheaper every state you cross, so don't overdo it here.\""
          color: root.theme.dim
          font.family: root.theme.font
          font.pixelSize: 15
          font.italic: true
        }
        Text {
          text: "Cart: " + Game.formatPrice(root.total)
          color: root.total > (root.game ? root.game.cash : 0) ? root.theme.red : root.theme.green
          font.family: root.theme.font
          font.pixelSize: 20
          font.bold: true
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          visible: root.session && root.session.storeError !== ""
          text: root.session ? root.session.storeError : ""
          color: root.theme.red
          font.family: root.theme.font
          font.pixelSize: 15
        }
        Text {
          text: "↑↓ pick · ←→ or +/− amount · Enter " + (root.total > 0 ? "check out" : "leave") + " · Esc leave"
          color: root.theme.dim
          font.family: root.theme.font
          font.pixelSize: 13
        }
        Row {
          spacing: 12
          Rectangle {
            width: 150; height: 34; color: root.theme.accent
            Text { anchors.centerIn: parent; text: "Check out"; color: root.theme.darkerBackground; font.family: root.theme.font; font.pixelSize: 17; font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.checkout() }
          }
          Rectangle {
            width: 150; height: 34; color: "transparent"; border.color: root.theme.accent; border.width: 2
            Text { anchors.centerIn: parent; text: "Leave store"; color: root.theme.accent; font.family: root.theme.font; font.pixelSize: 17 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.cart = ({}); root.closed() } }
          }
        }
      }
    }
  }
}

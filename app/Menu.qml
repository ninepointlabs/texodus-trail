import QtQuick

// A numbered Oregon-Trail-style menu. Number keys (or each item's own key)
// pick directly; arrows move the highlight; Enter picks; the mouse works too.
// Items: [{ label, detail?, key?, enabled?, value? }]
Grid {
  id: root

  property var theme
  property var items: []
  property int current: 0
  property int fontSize: 20
  property int rowHeight: Math.round(fontSize * 1.6)
  property bool numbered: true
  property real itemWidth: 520
  signal activated(int index, var item)
  signal highlighted(int index)

  property int menuColumns: 1
  rowSpacing: 2
  columnSpacing: 36
  flow: Grid.TopToBottom
  rows: Math.max(1, Math.ceil(items.length / menuColumns))

  function keyFor(i) {
    var it = items[i]
    if (it && it.key) return String(it.key)
    return String((i + 1) % 10)
  }

  function enabledAt(i) { return items[i] && items[i].enabled !== false }

  function move(delta) {
    if (!items.length) return
    var n = items.length
    var i = current
    for (var k = 0; k < n; k++) {
      i = (i + delta + n) % n
      if (enabledAt(i)) break
    }
    current = i
    highlighted(current)
  }

  function choose(i) {
    if (i < 0 || i >= items.length || !enabledAt(i)) return false
    current = i
    activated(i, items[i])
    return true
  }

  // Returns true when the key was ours.
  function handleKey(event) {
    if (event.key === Qt.Key_Up) { move(-1); return true }
    if (event.key === Qt.Key_Down) { move(1); return true }
    if (menuColumns > 1 && event.key === Qt.Key_Left) { if (current - rows >= 0 && enabledAt(current - rows)) { current -= rows; highlighted(current) } return true }
    if (menuColumns > 1 && event.key === Qt.Key_Right) { if (current + rows < items.length && enabledAt(current + rows)) { current += rows; highlighted(current) } return true }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) return choose(current)
    var t = String(event.text || "").toLowerCase()
    if (!t) return false
    for (var i = 0; i < items.length; i++) {
      if (keyFor(i).toLowerCase() === t) return choose(i)
    }
    return false
  }

  onItemsChanged: if (current >= items.length || !enabledAt(current)) { current = 0; if (!enabledAt(0)) move(1) }

  Repeater {
    model: root.items
    Rectangle {
      id: row
      required property int index
      required property var modelData
      readonly property bool active: root.current === index
      readonly property bool on: modelData.enabled !== false
      width: root.itemWidth
      height: root.rowHeight
      color: active && on ? root.theme.selection : "transparent"
      border.width: active && on ? 2 : 0
      border.color: root.theme.accent

      Text {
        id: keyLabel
        visible: root.numbered
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.keyFor(row.index) + "."
        color: row.on ? root.theme.accent : root.theme.muted
        font.family: root.theme.font
        font.pixelSize: root.fontSize
        font.bold: true
      }
      Text {
        x: root.numbered ? 10 + root.fontSize * 1.6 : 12
        width: parent.width - x - (detail.visible ? detail.implicitWidth + 16 : 8)
        anchors.verticalCenter: parent.verticalCenter
        text: row.modelData.label
        elide: Text.ElideRight
        color: !row.on ? root.theme.muted : row.active ? root.theme.foreground : root.theme.foreground
        font.family: root.theme.font
        font.pixelSize: root.fontSize
      }
      Text {
        id: detail
        visible: !!row.modelData.detail
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: row.modelData.detail || ""
        color: row.on ? root.theme.yellow : root.theme.muted
        font.family: root.theme.font
        font.pixelSize: root.fontSize - 3
      }
      // a blinking cursor arrow on the highlighted row
      Text {
        visible: row.active && row.on
        x: -22
        anchors.verticalCenter: parent.verticalCenter
        text: "▶"
        color: root.theme.accent
        font.pixelSize: root.fontSize - 4
        SequentialAnimation on opacity {
          running: row.active
          loops: Animation.Infinite
          NumberAnimation { to: 0.2; duration: 450 }
          NumberAnimation { to: 1; duration: 450 }
        }
      }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.on ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: if (row.on) { root.current = row.index; root.highlighted(row.index) }
        onClicked: root.choose(row.index)
      }
    }
  }
}

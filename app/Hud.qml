import QtQuick
import "Game.js" as Game

// The status strip under the road: where you are on the trail, then date,
// weather, health and the stuff you're running out of.
Item {
  id: root

  property var theme
  property var game: null

  height: 96

  readonly property var next: game ? Game.nextLandmark(game) : null
  readonly property int hp: game ? Game.partyHealth(game) : 0

  function healthColor(label) {
    return label === "Good" ? theme.green : label === "Fair" ? theme.yellow : theme.red
  }

  // ------------------------------------------------------- trail progress
  Item {
    id: trail
    x: 40
    y: 10
    width: root.width - 80
    height: 30

    Rectangle { y: 14; width: parent.width; height: 3; color: root.theme.muted }
    Rectangle {
      y: 14
      width: root.game ? parent.width * Math.min(1, root.game.miles / Game.TRIP_MILES) : 0
      height: 3
      color: root.theme.accent
      Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    }
    Repeater {
      model: Game.LANDMARKS
      Rectangle {
        required property var modelData
        readonly property bool passed: root.game && root.game.miles >= modelData.mile
        x: trail.width * modelData.mile / Game.TRIP_MILES - width / 2
        y: 15.5 - height / 2
        width: modelData.river ? 9 : modelData.mile === 1300 ? 12 : 8
        height: width
        radius: modelData.river ? width / 2 : 0
        rotation: modelData.river ? 0 : 45
        color: modelData.river ? root.theme.blue : passed ? root.theme.accent : root.theme.darkerBackground
        border.color: passed ? root.theme.accent : root.theme.muted
        border.width: 2
      }
    }
    PixelArt {
      sprite: "truck"
      px: 0.6
      x: (root.game ? trail.width * Math.min(1, root.game.miles / Game.TRIP_MILES) : 0) - width + 4
      y: 0
      Behavior on x { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    }
  }

  // ---------------------------------------------------------- the stats
  Row {
    x: 40
    y: 46
    spacing: 0
    width: root.width - 80

    component Stat: Column {
      property string label: ""
      property string value: ""
      property color valueColor: root.theme.foreground
      property real w: 150
      width: w
      spacing: 2
      Text {
        text: label
        color: root.theme.dim
        font.family: root.theme.font
        font.pixelSize: 12
        font.letterSpacing: 1.5
        font.capitalization: Font.AllUppercase
      }
      Text {
        text: value
        color: valueColor
        width: w - 10
        elide: Text.ElideRight
        font.family: root.theme.font
        font.pixelSize: 18
        font.bold: true
      }
    }

    Stat { w: 200; label: "Date"; value: root.game ? Game.dateText(root.game) : "" }
    Stat { w: 150; label: "Weather"; value: root.game ? Game.weather(root.game) : "" }
    Stat { w: 130; label: "Health"; value: Game.healthLabel(root.hp); valueColor: root.healthColor(value) }
    Stat { w: 120; label: "Snacks"; value: root.game ? root.game.snacks + " lbs" : ""; valueColor: root.game && root.game.snacks < 40 ? root.theme.red : root.theme.foreground }
    Stat { w: 110; label: "Gas"; value: root.game ? Math.floor(root.game.gas) + " gal" : ""; valueColor: root.game && root.game.gas < 15 ? root.theme.red : root.theme.foreground }
    Stat { w: 130; label: "Cash"; value: root.game ? Game.formatMoney(root.game.cash) : ""; valueColor: root.theme.green }
    Stat { w: 120; label: "Miles"; value: root.game ? Math.round(root.game.miles) + " / " + Game.TRIP_MILES : "" }
    Stat {
      w: 240
      label: "Next landmark"
      value: root.next && root.game ? root.next.short + " · " + (root.next.mile - Math.round(root.game.miles)) + " mi" : "Austin!"
      valueColor: root.theme.accent
    }
  }

  Rectangle { y: root.height - 2; width: root.width; height: 2; color: root.theme.muted; opacity: 0.6 }
}

import QtQuick
import "Sprites.js" as Sprites

// The pop-up that tells you what just happened on the trail: a pixel icon,
// a chunky title, and the story typed out like it's 1985. Space or Enter
// finishes the typing, then dismisses.
Item {
  id: root

  property var theme
  property var message: null
  signal dismissed()

  readonly property string body: message ? message.text : ""
  property int shown: 0
  readonly property bool typing: shown < body.length

  readonly property color toneColor: !message ? theme.accent
    : message.tone === "good" ? theme.green
    : message.tone === "bad" ? theme.red : theme.accent

  readonly property string art: {
    if (!message) return ""
    if (message.art === "landmark") return "sign"
    if (message.art === "grave") return "tombstone"
    if (message.art === "sick") return "thermo"
    if (message.art === "river") return "wave"
    if (message.art === "selfie") return "phone"
    if (message.art) return message.art
    var t = message.title.toLowerCase()
    if (t.indexOf("tire") >= 0 || t.indexOf("breakdown") >= 0 || t.indexOf("overheat") >= 0) return "wrench"
    if (t.indexOf("snake") >= 0) return "snake"
    if (t.indexOf("taco") >= 0 || t.indexOf("frenzy") >= 0) return "taco"
    if (t.indexOf("potluck") >= 0 || t.indexOf("snack") >= 0) return "brisket"
    if (t.indexOf("encounter") >= 0 || t.indexOf("self-driving") >= 0) return "ufo"
    if (t.indexOf("tumbleweed") >= 0) return "tumbleweed"
    if (t.indexOf("gas") >= 0 || t.indexOf("lucky") >= 0 || t.indexOf("viral") >= 0 || t.indexOf("deal") >= 0 || t.indexOf("residual") >= 0 || t.indexOf("$texit") >= 0 || t.indexOf("tax") >= 0) return "money"
    if (t.indexOf("assimilation") >= 0 || t.indexOf("bless") >= 0 || t.indexOf("bumper") >= 0) return "hat"
    if (t.indexOf("scorching") >= 0 || t.indexOf("rest") >= 0 && t.indexOf("peace") < 0) return "thermo"
    if (message.tone === "bad") return "cone"
    if (message.tone === "good") return "star"
    return "cactus"
  }

  onMessageChanged: { shown = 0; typer.restart() }

  function advance() {
    if (typing) { shown = body.length; return }
    dismissed()
  }

  Timer {
    id: typer
    interval: 16
    repeat: true
    running: root.visible && root.typing
    onTriggered: root.shown = Math.min(root.body.length, root.shown + 2)
  }

  // dim what's behind
  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: 0.45
  }
  MouseArea { anchors.fill: parent; onClicked: root.advance() }

  Item {
    id: box
    width: 820
    height: Math.max(220, textCol.implicitHeight + 64)
    anchors.centerIn: parent
    scale: root.visible ? 1 : 0.85
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    // hard pixel drop shadow
    Rectangle { x: 10; y: 10; width: parent.width; height: parent.height; color: "#000000"; opacity: 0.5 }
    Rectangle {
      anchors.fill: parent
      color: root.theme.background
      border.color: root.toneColor
      border.width: 4
    }
    Rectangle { x: 4; y: 4; width: parent.width - 8; height: 6; color: root.toneColor; opacity: 0.35 }

    Rectangle {
      id: iconWell
      x: 28
      y: 32
      width: 128
      height: 128
      color: root.theme.darkerBackground
      border.color: root.theme.muted
      border.width: 2
      PixelArt {
        id: icon
        sprite: root.art
        px: {
          var r = Sprites.SPRITES[root.art]
          if (!r) return 4
          return Math.max(2, Math.min(6, Math.floor(104 / Math.max(r[0].length, r.length))))
        }
        x: (128 - width) / 2
        property real baseY: (128 - height) / 2
        property real wobble: 0
        y: baseY + wobble
        SequentialAnimation on wobble {
          running: root.visible
          loops: Animation.Infinite
          NumberAnimation { from: -3; to: 3; duration: 700; easing.type: Easing.InOutSine }
          NumberAnimation { from: 3; to: -3; duration: 700; easing.type: Easing.InOutSine }
        }
      }
    }

    Column {
      id: textCol
      x: iconWell.x + iconWell.width + 30
      y: 32
      width: box.width - x - 32
      spacing: 16
      PixelText {
        text: root.message ? root.message.title : ""
        px: (text.length * 6) * 3.5 > textCol.width ? Math.max(2, Math.floor(textCol.width / (text.length * 6) * 2) / 2) : 3.5
        color: root.toneColor
        shadow: "#000000"
      }
      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: root.body.slice(0, root.shown)
        color: root.theme.foreground
        font.family: root.theme.font
        font.pixelSize: 21
        lineHeight: 1.2
      }
      Text {
        text: root.typing ? " " : "Press SPACE to continue"
        color: root.theme.accent
        font.family: root.theme.font
        font.pixelSize: 16
        SequentialAnimation on opacity {
          running: !root.typing && root.visible
          loops: Animation.Infinite
          NumberAnimation { to: 0.3; duration: 500 }
          NumberAnimation { to: 1; duration: 500 }
        }
      }
    }
  }
}

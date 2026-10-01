import QtQuick

// A grave by the side of the road, and a chance to write what goes on it.
// Whatever you type here haunts every future trip that passes this mile.
Item {
  id: root

  property var theme
  property var prompt: null
  signal done(string text)

  function focusInput() { input.forceActiveFocus(); input.selectAll() }
  onPromptChanged: if (prompt) { input.text = prompt.suggestion || ""; Qt.callLater(focusInput) }

  Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.55 }

  Item {
    id: stone
    width: 520
    height: 300
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10

    // the stone itself: a pixel-y rounded top with a hard shadow
    Rectangle { x: 14; y: 14; width: parent.width; height: parent.height; radius: 0; color: "#000000"; opacity: 0.4 }
    Rectangle { x: 60; y: 0; width: parent.width - 120; height: 40; color: "#b7b0a4" }
    Rectangle { x: 24; y: 20; width: parent.width - 48; height: 40; color: "#b7b0a4" }
    Rectangle { x: 0; y: 48; width: parent.width; height: parent.height - 48; color: "#b7b0a4" }
    Rectangle { x: parent.width - 30; y: 48; width: 30; height: parent.height - 48; color: "#7d776d" }
    Rectangle { x: 0; y: parent.height - 18; width: parent.width; height: 18; color: "#4f9b3a" }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 44
      width: parent.width - 80
      spacing: 12
      PixelText { anchors.horizontalCenter: parent.horizontalCenter; text: "HERE LIES"; px: 3; color: "#5a544c" }
      PixelText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.prompt ? root.prompt.name : ""
        px: Math.min(6, 430 / Math.max(1, text.length * 6))
        color: "#3a352f"
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.prompt ? "Died of " + root.prompt.cause + "." : ""
        color: "#3a352f"
        font.family: root.theme.font
        font.pixelSize: 17
        font.italic: true
      }
      Rectangle {
        width: parent.width
        height: 44
        color: "#d6d0c4"
        border.color: input.activeFocus ? root.theme.accent : "#7d776d"
        border.width: 3
        TextInput {
          id: input
          anchors.fill: parent
          anchors.margins: 10
          maximumLength: 60
          color: "#1b1424"
          font.family: root.theme.font
          font.pixelSize: 18
          horizontalAlignment: TextInput.AlignHCenter
          verticalAlignment: TextInput.AlignVCenter
          clip: true
          selectByMouse: true
          Keys.onReturnPressed: root.done(text)
          Keys.onEnterPressed: root.done(text)
        }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Write an epitaph · Enter to bury"
        color: "#5a544c"
        font.family: root.theme.font
        font.pixelSize: 14
      }
    }
  }
}

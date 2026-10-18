import QtQuick
import Quickshell
import Quickshell.Io
import "About.js" as About

// The About screen (F1, or "About" on the title menu): a card like the trail's
// message cards, with the version, license, support address, privacy and
// credits. Keys come from App.qml; the buttons also take a click.
Item {
  id: root

  property var theme
  property bool showLicense: false
  property string copied: ""
  // App.qml opens the mailto: link, so a test can stop it reaching a mail client
  signal openUrl(string url)
  signal closed()

  property string versionText: ""
  property string licenseRaw: ""
  readonly property string version: About.version(versionText)
  readonly property string licenseText: licenseRaw ? About.reflowLicense(licenseRaw)
    : About.ABOUT.license + ", " + About.ABOUT.copyright
  readonly property string quickshellVersion: About.probedVersion(function(a, b) { return Quickshell.hasVersion(a, b) }, 0)
  readonly property string qtVersion: About.probedVersion(function(a, b) { return Quickshell.hasQtVersion(a, b) }, 6)
  readonly property string details: About.details(version, quickshellVersion, qtVersion,
    (Quickshell.env("XDG_CURRENT_DESKTOP") || "unknown desktop") + ", " + Qt.platform.pluginName)

  function localPath(url) {
    var s = String(url)
    return s.indexOf("file://") === 0 ? decodeURIComponent(s.slice(7)) : s
  }

  // VERSION and LICENSE sit next to app/, in the checkout and in an install.
  // Quickshell blackholes Qt.resolvedUrl outside the shell dir, so go from
  // shellDir; the test stub has none and resolves the URL instead.
  readonly property string topDir: Quickshell.shellDir ? Quickshell.shellDir + "/.." : localPath(Qt.resolvedUrl(".."))
  FileView { path: root.topDir + "/VERSION"; printErrors: false; onLoaded: root.versionText = text() }
  FileView { path: root.topDir + "/LICENSE"; printErrors: false; onLoaded: root.licenseRaw = text() }

  function copy(text, what) {
    Quickshell.clipboardText = text
    copied = what
    copiedTimer.restart()
  }
  function copyEmail() { copy(About.ABOUT.supportEmail, "email") }
  function copyDetails() { copy(details, "details") }
  function email() { openUrl(About.supportMailto(version, details)) }
  function toggleLicense() { showLicense = !showLicense }

  Timer { id: copiedTimer; interval: 1500; onTriggered: root.copied = "" }
  onVisibleChanged: { showLicense = false; copied = "" }

  component Label: Text {
    width: 120
    color: root.theme.accent
    font.family: root.theme.font
    font.bold: true
    font.pixelSize: 14
  }
  component Value: Text {
    width: textCol.width - 120 - facts.columnSpacing
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: root.theme.foreground
    font.family: root.theme.font
    font.pixelSize: 14
    lineHeight: 1.05
  }
  component KeyButton: Rectangle {
    id: button
    property string key: ""
    property string label: ""
    signal activated()
    width: buttonText.implicitWidth + 24
    height: buttonText.implicitHeight + 10
    color: mouse.containsMouse ? root.theme.selection : "transparent"
    border.color: root.theme.accent
    border.width: 2
    Text {
      id: buttonText
      anchors.centerIn: parent
      text: button.key + ". " + button.label
      color: root.theme.foreground
      font.family: root.theme.font
      font.bold: true
      font.pixelSize: 14
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.activated()
    }
  }

  // dim what's behind; a click outside the card goes back
  Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.6 }
  MouseArea { anchors.fill: parent; onClicked: root.closed() }

  Item {
    id: box
    width: 1200
    height: textCol.implicitHeight + 56
    anchors.centerIn: parent
    MouseArea { anchors.fill: parent }

    // hard pixel drop shadow
    Rectangle { x: 10; y: 10; width: parent.width; height: parent.height; color: "#000000"; opacity: 0.5 }
    Rectangle {
      anchors.fill: parent
      color: root.theme.background
      border.color: root.theme.accent
      border.width: 4
    }
    Rectangle { x: 4; y: 4; width: parent.width - 8; height: 6; color: root.theme.accent; opacity: 0.35 }

    // the app icon: the Yoo-Haul
    Rectangle {
      id: iconWell
      x: 28
      y: 28
      width: 190
      height: 110
      color: root.theme.darkerBackground
      border.color: root.theme.muted
      border.width: 2
      Item {
        x: (parent.width - truck.width) / 2
        y: (parent.height - truck.height) / 2
        width: truck.width
        height: truck.height
        PixelArt { id: truck; sprite: "truck"; px: 2.5 }
        PixelText { text: "YOO-HAUL"; px: 1.875; color: "#c24e0c"; x: Math.round(23 * truck.px - width / 2); y: Math.round(9.5 * truck.px - height / 2) }
        PixelArt { sprite: "wheel0"; px: truck.px; x: 6 * truck.px; y: 19 * truck.px }
        PixelArt { sprite: "wheel0"; px: truck.px; x: 49 * truck.px; y: 19 * truck.px }
      }
    }

    Column {
      id: textCol
      x: iconWell.x + iconWell.width + 30
      y: 28
      width: box.width - x - 32
      spacing: 10

      Column {
        spacing: 6
        PixelText { text: About.ABOUT.name; px: 4; color: root.theme.accent; shadow: "#000000" }
        Text {
          text: About.ABOUT.tagline
          color: root.theme.foreground
          font.family: root.theme.font
          font.pixelSize: 18
        }
        Text {
          objectName: "aboutVersion"
          text: "Version " + root.version
          color: root.theme.dim
          font.family: root.theme.font
          font.pixelSize: 14
        }
      }

      Grid {
        id: facts
        visible: !root.showLicense
        columns: 2
        columnSpacing: 16
        rowSpacing: 5

        Label { text: "MADE BY" }
        Value { text: About.ABOUT.organization }
        Label { text: "CREATED" }
        Value { text: About.ABOUT.created }
        Label { text: "LICENSE" }
        Value { text: About.ABOUT.license + ", " + About.ABOUT.copyright }
        Label { text: "SUPPORT" }
        Value { text: About.ABOUT.supportEmail }
        Label { text: "PRIVACY" }
        Value { objectName: "aboutPrivacy"; text: About.ABOUT.privacy }
        Label { text: "FINE PRINT" }
        Value { text: About.ABOUT.credits }
        Label { text: "BUILT WITH" }
        Value { text: About.builtWith(root.quickshellVersion, root.qtVersion) }
      }

      Text {
        objectName: "aboutLicenseText"
        visible: root.showLicense
        width: textCol.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: root.licenseText
        color: root.theme.foreground
        font.family: root.theme.font
        font.pixelSize: 14
        lineHeight: 1.05
      }

      Flow {
        width: textCol.width
        spacing: 12
        KeyButton { key: "R"; label: root.showLicense ? "Hide license" : "Read license"; onActivated: root.toggleLicense() }
        KeyButton { key: "E"; label: "Email"; onActivated: root.email() }
        KeyButton { key: "C"; label: root.copied === "email" ? "Copied" : "Copy email"; onActivated: root.copyEmail() }
        KeyButton { key: "V"; label: root.copied === "details" ? "Copied" : "Copy version details"; onActivated: root.copyDetails() }
      }

      Text {
        text: "Esc or F1 to go back"
        color: root.theme.accent
        font.family: root.theme.font
        font.pixelSize: 16
      }
    }
  }
}

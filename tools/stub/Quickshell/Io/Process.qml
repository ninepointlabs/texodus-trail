import QtQuick

// Dev stub: pretends every command succeeded.
QtObject {
  property var command: []
  property bool running: false
  signal exited(int code)
  onRunningChanged: if (running) Qt.callLater(function() { running = false; exited(0) })
  Component.onCompleted: if (running) Qt.callLater(function() { running = false; exited(0) })
}

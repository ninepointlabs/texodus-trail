import QtQuick

// Dev stub: reads and writes through file:// XHR (needs QML_XHR_ALLOW_FILE_*).
QtObject {
  id: root
  property string path: ""
  property bool watchChanges: false
  property bool atomicWrites: false
  property bool printErrors: false
  property string _text: ""
  signal loaded()
  signal loadFailed(var error)
  signal saveFailed(var error)
  signal fileChanged()
  function text() { return _text }
  function reload() {
    if (!path) return
    var x = new XMLHttpRequest()
    x.open("GET", "file://" + path, false)
    try { x.send() } catch (e) { loadFailed(String(e)); return }
    if (x.responseText === "" ) { loadFailed("empty"); return }
    _text = x.responseText
    loaded()
  }
  function setText(t) {
    _text = t
    var x = new XMLHttpRequest()
    x.open("PUT", "file://" + path, false)
    try { x.send(t) } catch (e) { saveFailed(String(e)) }
  }
  onPathChanged: Qt.callLater(reload)
}

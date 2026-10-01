import QtQuick
import QtMultimedia

// The part of the sound system that needs QtMultimedia. Sfx.qml loads it
// with a Loader, so on a system without the module the game simply runs
// silent instead of failing to start.
Item {
  id: root

  property var names: []
  property bool muted: false
  property real musicVolume: 0.55
  property real effectsVolume: 0.8
  property var _effects: ({})

  function play(name) {
    var e = _effects[name]
    if (e) e.play()
  }

  function music(track) {
    if (!track) { player.stop(); return }
    var src = Qt.resolvedUrl("sounds/" + track + ".wav")
    if (String(player.source) !== String(src)) { player.stop(); player.source = src }
    player.play()
  }

  Repeater {
    model: root.names
    Item {
      id: holder
      required property string modelData
      SoundEffect {
        id: effect
        source: Qt.resolvedUrl("sounds/" + holder.modelData + ".wav")
        volume: root.effectsVolume
        muted: root.muted
      }
      Component.onCompleted: {
        var next = Object.assign({}, root._effects)
        next[modelData] = effect
        root._effects = next
      }
    }
  }

  MediaPlayer {
    id: player
    loops: MediaPlayer.Infinite
    audioOutput: AudioOutput {
      volume: root.muted ? 0 : root.musicVolume
    }
  }
}

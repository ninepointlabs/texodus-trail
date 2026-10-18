import QtQuick
import QtTest
import "../app"
import "../app/Game.js" as Game
import "../app/About.js" as About
import Quickshell

// End-to-end: drive the real UI with real key events from the title screen
// to the end of a trip. Run with test/ui.sh (headless, no compositor).
Item {
  id: top
  width: 1280
  height: 800

  Theme { id: theme }
  Session { id: session }
  Sfx { id: sfx; muted: true }
  App { id: app; anchors.fill: parent; theme: theme; session: session; sfx: sfx }

  TestCase {
    name: "TexodusTrail"
    when: windowShown && session.loaded

    function type(text) { for (var i = 0; i < text.length; i++) keyClick(text.charAt(i)) }
    function press(key, times) { for (var i = 0; i < (times || 1); i++) keyClick(key) }

    function test_1_full_trip() {
      session.muted = true
      session.abandon()
      app.view = "title"
      app.focusStage()
      compare(app.view, "title")

      press(Qt.Key_1)
      compare(app.view, "occupation")
      press(Qt.Key_1)
      compare(app.view, "names")
      tryCompare(app, "nameIndex", 0)
      type("Chad")
      press(Qt.Key_Return)
      type("Skyler")
      press(Qt.Key_Return, 4)
      compare(app.view, "month")
      compare(app.partyNames[0], "Chad")
      press(Qt.Key_2)
      compare(app.view, "intro")
      compare(session.game.party[0].name, "Chad")
      compare(session.game.party[1].name, "Skyler")
      press(Qt.Key_Space, 2)
      compare(app.view, "game")
      compare(app.overlay, "store")

      // shop with the keyboard: gas, snacks, sunscreen, tires, parts, coupons
      press(Qt.Key_Right, 18)
      press(Qt.Key_Down); press(Qt.Key_Right, 14)
      press(Qt.Key_Down); press(Qt.Key_Right, 6)
      press(Qt.Key_Down); press(Qt.Key_Right, 2)
      press(Qt.Key_Down); press(Qt.Key_Right, 2)
      press(Qt.Key_Down); press(Qt.Key_Right, 3)
      press(Qt.Key_Return)
      compare(session.game.gas, 180)
      compare(session.game.snacks, 350)
      compare(session.game.coupons, 30)
      verify(session.game.cash > 0)
      press(Qt.Key_Escape)
      compare(app.overlay, "")
      compare(app.mode, "camp")

      // side trips from camp
      press(Qt.Key_2); compare(app.overlay, "supplies"); press(Qt.Key_Return)
      press(Qt.Key_3); compare(app.overlay, "map"); press(Qt.Key_Return)
      press(Qt.Key_4); compare(app.overlay, "pace"); press(Qt.Key_1); compare(session.game.pace, "chill")
      press(Qt.Key_4); press(Qt.Key_2); compare(session.game.pace, "hustle")
      press(Qt.Key_8); compare(app.mode, "message"); press(Qt.Key_Space, 2); compare(app.mode, "camp")

      // Food Truck Frenzy: count down, toss a few coupons, bail out early
      press(Qt.Key_0)
      compare(app.overlay, "forage")
      wait(2600)
      press(Qt.Key_Space, 3)
      press(Qt.Key_Escape)
      tryCompare(app, "overlay", "", 4000)
      compare(session.game.coupons, 27)

      // the trail
      var guard = 0
      var seen = {}
      while (!session.game.finished && guard++ < 900) {
        var m = app.mode
        seen[m] = true
        if (m === "message") press(Qt.Key_Space, 2)
        else if (m === "travel") session.travelDay()
        else if (m === "river") press(session.game.cash >= session.game.prompt.toll ? Qt.Key_3 : Qt.Key_2)
        else if (m === "trade") press(Qt.Key_2)
        else if (m === "epitaph") { type(" RIP"); press(Qt.Key_Return) }
        else if (m === "camp") {
          var g = session.game
          if (Game.specialHere(g)) { press(Qt.Key_S); continue }
          if (Game.storeHere(g) && g.gas < 90 && g.cash > 300) {
            press(Qt.Key_9)
            compare(app.overlay, "store")
            press(Qt.Key_Right, 6)
            if (g.snacks < 150) { press(Qt.Key_Down); press(Qt.Key_Right, 4) }
            press(Qt.Key_Return)
            press(Qt.Key_Escape)
            continue
          }
          if (Game.alive(g).some(function(p) { return p.sick }) && Math.random() < 0.3) { press(Qt.Key_6); press(Qt.Key_2); continue }
          press(Qt.Key_1)
        }
        else fail("unexpected mode " + m)
      }
      verify(session.game.finished, "trip should end")
      while (app.mode === "message" || app.mode === "epitaph") {
        if (app.mode === "epitaph") { press(Qt.Key_Return); continue }
        press(Qt.Key_Space, 2)
      }
      verify(seen.river, "should have met a river")
      compare(app.mode, "end")

      // the end menu: Top Ten and back
      press(Qt.Key_1)
      compare(app.view, "topten")
      press(Qt.Key_Return)
      compare(app.view, "game")
      press(Qt.Key_3)
      compare(app.view, "title")
      compare(session.game, null)
      console.log("trip over; graves dug: " + session.graves.length + "; top score: " + session.topTen[0].score)
    }

    function test_2_mute_toggle() {
      app.view = "title"
      app.focusStage()
      var before = session.muted
      press(Qt.Key_M)
      compare(session.muted, !before)
      press(Qt.Key_M)
      compare(session.muted, before)
    }

    function test_3_about() {
      // nothing may reach a mail client; copies land in the stub's clipboard
      app.externalLinks = false
      session.abandon()
      app.view = "title"
      app.focusStage()

      // from the title menu
      press(Qt.Key_6)
      verify(app.showAbout)
      compare(app.view, "title")
      compare(findChild(app, "aboutVersion").text, "Version dev")
      compare(findChild(app, "aboutPrivacy").text, About.ABOUT.privacy)

      press(Qt.Key_R)
      var license = findChild(app, "aboutLicenseText")
      verify(license.visible)
      verify(license.text.indexOf("MIT License\n\nCopyright (c) 2026 Nine Point Labs\n\nPermission is hereby granted") === 0, license.text.slice(0, 60))
      press(Qt.Key_R)
      verify(!license.visible)

      press(Qt.Key_C)
      compare(Quickshell.clipboardText, "help@ninepointlabs.com")
      press(Qt.Key_V)
      verify(Quickshell.clipboardText.indexOf("The Texodus Trail dev\nQuickshell ?, Qt ?\n") === 0, Quickshell.clipboardText)
      press(Qt.Key_E)
      verify(app.lastExternalUrl.indexOf("mailto:help@ninepointlabs.com?subject=The%20Texodus%20Trail%20dev&body=") === 0, app.lastExternalUrl)

      // menu keys do nothing behind it
      press(Qt.Key_1)
      press(Qt.Key_Return)
      compare(app.view, "title")
      verify(app.showAbout)
      press(Qt.Key_Escape)
      verify(!app.showAbout)
      compare(app.view, "title")

      // from a name field: About takes the keys, Esc puts the cursor back
      press(Qt.Key_1)
      press(Qt.Key_1)
      compare(app.view, "names")
      tryCompare(app, "nameIndex", 0)
      type("Al")
      press(Qt.Key_F1)
      verify(app.showAbout)
      press(Qt.Key_R)
      press(Qt.Key_R)
      press(Qt.Key_Escape)
      verify(!app.showAbout)
      compare(app.view, "names")
      type("ex")
      press(Qt.Key_Return, 5)
      compare(app.view, "month")
      // (the field keeps what test 1 typed; what matters is no R landed in it)
      compare(app.partyNames[0].slice(-4), "Alex")

      // mid-trip, About stops the clock and Esc picks up where it left off
      press(Qt.Key_2)
      press(Qt.Key_Space, 2)
      compare(app.overlay, "store")
      press(Qt.Key_Right, 18)
      press(Qt.Key_Down); press(Qt.Key_Right, 14)
      press(Qt.Key_Return)
      press(Qt.Key_Escape)
      compare(app.mode, "camp")
      press(Qt.Key_1)
      compare(app.mode, "travel")
      press(Qt.Key_F1)
      verify(app.showAbout)
      var day = session.game.day
      wait(1600)
      compare(session.game.day, day)
      compare(app.mode, "travel")
      press(Qt.Key_Space)
      compare(app.mode, "travel", "Space doesn't reach the road behind About")
      press(Qt.Key_F1)
      verify(!app.showAbout)
      tryVerify(function() { return session.game.day > day || app.mode !== "travel" }, 3000, "the clock runs again")
      session.abandon()
      app.view = "title"
    }
  }
}

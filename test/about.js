#!/usr/bin/env node
// About tests: the facts agree with LICENSE, `texodus --about` prints the
// same ones, install.sh ships what About reads, and the privacy text names
// every network host the game, launcher or installer could talk to.
// Run: node test/about.js
"use strict"

const fs = require("fs")
const os = require("os")
const path = require("path")
const vm = require("vm")
const assert = require("assert")
const { execFileSync } = require("child_process")

const root = path.join(__dirname, "..")
const source = fs.readFileSync(path.join(root, "app", "About.js"), "utf8").replace(/^\.pragma library\s*/m, "")
const ctx = {}
vm.runInNewContext(source + "\nthis.A = { ABOUT, probedVersion, version, reflowLicense, builtWith, details, supportMailto }", ctx)
const A = ctx.A
const ABOUT = A.ABOUT

let passed = 0
function test(name, fn) {
  try { fn(); passed++; console.log("ok   " + name) } catch (e) { console.error("FAIL " + name + "\n     " + e.message); process.exitCode = 1 }
}

// every text file under app/ and bin/, plus the installer
function files(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name)
    if (e.isDirectory()) return files(p)
    return /\.(wav|png)$/.test(e.name) ? [] : [p]
  })
}
const code = files(path.join(root, "app")).concat(files(path.join(root, "bin")), [path.join(root, "install.sh")])
  .map((p) => ({ p: path.relative(root, p), text: fs.readFileSync(p, "utf8") }))

test("license facts come from LICENSE", () => {
  const license = fs.readFileSync(path.join(root, "LICENSE"), "utf8")
  assert(license.startsWith(ABOUT.license + "\n"), "LICENSE starts with " + ABOUT.license)
  assert(license.includes(ABOUT.copyright.replace("©", "Copyright (c)") + "\n"), "LICENSE says " + ABOUT.copyright)
  assert.strictEqual(ABOUT.organization, "Nine Point Labs")
  assert.strictEqual(ABOUT.supportEmail, "help@ninepointlabs.com")
  const reflowed = A.reflowLicense(license)
  assert(reflowed.startsWith("MIT License\n\nCopyright (c) 2026 Nine Point Labs\n\nPermission is hereby granted"), reflowed.slice(0, 80))
})

test("it's Nine Point Labs, three words", () => {
  for (const p of ["LICENSE", "README.md", "docs/index.html", "docs/site.js"]) {
    // skip what a trimmed checkout or install doesn't have
    if (!fs.existsSync(path.join(root, p))) continue
    assert(!/ninepoint labs/i.test(fs.readFileSync(path.join(root, p), "utf8")), p)
  }
  for (const f of code) assert(!/ninepoint labs/i.test(f.text), f.p)
})

test("the privacy text names every network host in app/, bin/ and install.sh", () => {
  assert(/no network access/.test(ABOUT.privacy))
  for (const f of code) {
    for (const m of f.text.matchAll(/\b[a-z][a-z0-9+.-]*:\/\/([^/\s"'`)<>\\]+)/gi)) {
      const host = m[1].replace(/:\d+$/, "").toLowerCase()
      assert(ABOUT.privacy.includes(host), f.p + " mentions " + m[0] + ", which the privacy text in app/About.js doesn't name")
    }
    // a host can hide in a string the matcher above misses; so can a socket
    const api = f.text.match(/\b(XMLHttpRequest|WebSocket|QtWebSockets|QtNetwork|NetworkAccessManager|curl|wget|nc|ncat|socat)\b/)
    assert(!api, f.p + " uses " + (api && api[1]) + ", but the privacy text says there is no network access")
  }
})

test("the privacy text matches where the save lives", () => {
  const sessionQml = fs.readFileSync(path.join(root, "app", "Session.qml"), "utf8")
  assert(sessionQml.includes('"/.local/state") + "/texodus-trail"') && sessionQml.includes('"/save.json"'), "Session.qml save path moved")
  assert(ABOUT.privacy.includes("~/.local/state/texodus-trail/save.json"))
})

test("About finds VERSION and LICENSE from Quickshell.shellDir", () => {
  // real Quickshell turns Qt.resolvedUrl("../X") outside the shell dir into
  // qrc:/qs-blackhole, so the files would never load in the installed game
  const card = fs.readFileSync(path.join(root, "app", "AboutCard.qml"), "utf8")
  assert(/Quickshell\.shellDir \+ "\/\.\."/.test(card), "AboutCard.qml should start from Quickshell.shellDir")
  assert(card.includes('topDir + "/VERSION"') && card.includes('topDir + "/LICENSE"'))
})

test("version, details and the support email", () => {
  assert.strictEqual(A.version(""), "dev")
  assert.strictEqual(A.version("0.1.0\n"), "0.1.0")
  assert.strictEqual(A.version("<oops>"), "dev")
  assert.strictEqual(A.probedVersion((a, b) => b <= 11, 6), "6.11")
  assert.strictEqual(A.probedVersion(() => false, 0), "")
  const details = A.details("dev", "0.3", "6.11", "Hyprland, wayland")
  assert.strictEqual(details, "The Texodus Trail dev\nQuickshell 0.3, Qt 6.11\nHyprland, wayland")
  assert.strictEqual(A.supportMailto("dev", details),
    "mailto:help@ninepointlabs.com?subject=The%20Texodus%20Trail%20dev&body=%0A%0A--%0AThe%20Texodus%20Trail%20dev%0AQuickshell%200.3%2C%20Qt%206.11%0AHyprland%2C%20wayland")
})

test("install.sh ships About.js and LICENSE where About and --about read them", () => {
  // a throwaway home: nothing lands in the real ~/.local
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "texodus-install-"))
  try {
    const env = Object.assign({}, process.env, {
      HOME: home, XDG_DATA_HOME: path.join(home, ".local", "share"), XDG_STATE_HOME: path.join(home, ".local", "state")
    })
    execFileSync(path.join(root, "install.sh"), [], { env, stdio: "pipe" })
    const dest = path.join(home, ".local", "share", "texodus-trail")
    assert.strictEqual(fs.readFileSync(path.join(dest, "LICENSE"), "utf8"), fs.readFileSync(path.join(root, "LICENSE"), "utf8"))
    assert.strictEqual(fs.readFileSync(path.join(dest, "app", "About.js"), "utf8"), fs.readFileSync(path.join(root, "app", "About.js"), "utf8"))
    assert(fs.existsSync(path.join(dest, "app", "AboutCard.qml")))
    const about = execFileSync(path.join(home, ".local", "bin", "texodus"), ["--about"], { encoding: "utf8", env })
    // install.sh stamps VERSION from the release tag; without git or a tag it's "dev"
    let expected = "dev"
    try {
      expected = execFileSync("git", ["-C", root, "describe", "--tags", "--match", "v[0-9]*", "--dirty"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim().replace(/^v/, "")
    } catch (e) {}
    if (expected !== "dev") assert.strictEqual(fs.readFileSync(path.join(dest, "VERSION"), "utf8"), expected + "\n")
    else assert(!fs.existsSync(path.join(dest, "VERSION")), "VERSION written without a tag")
    assert(about.startsWith(ABOUT.name + " " + expected + "\n" + ABOUT.tagline + "\n"), about.split("\n")[0])
    assert(about.includes("(full text: " + path.join(fs.realpathSync(dest), "LICENSE") + ")"), about)
  } finally {
    fs.rmSync(home, { recursive: true, force: true })
  }
})

test("texodus --about prints the same facts as the About screen", () => {
  const out = execFileSync(path.join(root, "bin", "texodus"), ["--about"], { encoding: "utf8" })
  for (const key of Object.keys(ABOUT)) assert(out.includes(ABOUT[key]), "--about is missing " + key + ": " + ABOUT[key])
  assert(/^Built with {2}/m.test(out))
})

console.log(passed + " passed")

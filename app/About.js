.pragma library

// The About screen's facts (F1 or "About" on the title menu, and
// `texodus --about` in a terminal). The version comes from a VERSION file
// next to app/ when there is one ("dev" otherwise) and the license text from
// LICENSE beside it. bin/texodus reads the ABOUT lines below with sed, so
// keep each one a single line of `  key: "text",` with no double quotes or
// backslashes inside. test/about.js checks both.

var ABOUT = {
  name: "The Texodus Trail",
  tagline: "The Oregon Trail for the California-to-Texas exodus",
  organization: "Nine Point Labs",
  created: "October 2026", // first commit: 2026-10-01
  license: "MIT License",
  copyright: "© 2026 Nine Point Labs", // as written in LICENSE
  supportEmail: "help@ninepointlabs.com",
  privacy: "No accounts, no telemetry, no network access: the game never connects to the internet, not even to texodous.ninepointlabs.com. Your trip in progress (party names, supplies, epitaphs), the Top Ten, the graves by the road and the sound setting are saved in ~/.local/state/texodus-trail/save.json ($XDG_STATE_HOME/texodus-trail), with your usual file permissions (0644 under umask 022). Your login name is only offered as the leader's name, and saved if you keep it. It reads your Omarchy theme's colors.toml, plays only its own sounds and never uses a microphone. On Hyprland the launcher uses hyprctl to float, size and focus its own window. Scripts can drive it over quickshell ipc, which is how it takes a screenshot, and only to a .png under ~/.cache. The clipboard and your mail client are used only when you press Copy or Email in About. The one web address it mentions, quickshell.org, is printed by install.sh when Quickshell is missing.",
  credits: "A loving parody: Yoo-Haul isn't a real company, Kyle isn't a real Kyle, and no Californians or Texans were harmed in the making of this game. Inspired by The Oregon Trail (MECC, 1971/1985). The pixel art, lettering, chiptune music and sound effects are original, drawn and synthesised by tools/sprites.py and tools/make-sounds.py; other text uses your system monospace font."
}

// Highest minor version `has(major, minor)` accepts, as "major.minor"
// (Quickshell.hasVersion / hasQtVersion only answer yes or no), or "".
function probedVersion(has, major) {
  if (typeof has !== "function" || !has(major, 0)) return ""
  var minor = 0
  while (minor < 99 && has(major, minor + 1)) minor++
  return major + "." + minor
}

// "0.1.0" from the VERSION file's text, or "dev" when there isn't one.
function version(text) {
  var v = String(text || "").trim()
  return /^[0-9A-Za-z.+~-]{1,32}$/.test(v) ? v : "dev"
}

// One paragraph per line, so the license wraps to the card's width.
function reflowLicense(text) {
  var paragraphs = String(text || "").split(/\n\s*\n/)
  var out = []
  for (var i = 0; i < paragraphs.length; i++) {
    var p = paragraphs[i].replace(/\s+/g, " ").trim()
    if (p !== "") out.push(p)
  }
  return out.join("\n\n")
}

function builtWith(quickshell, qt) {
  return "Quickshell " + (quickshell || "?") + ", Qt " + (qt || "?")
}

// Version details for a support email.
function details(version, quickshell, qt, desktop) {
  return ABOUT.name + " " + version + "\n" + builtWith(quickshell, qt) + "\n" + (desktop || "unknown desktop")
}

function supportMailto(version, details) {
  return "mailto:" + ABOUT.supportEmail + "?subject=" + encodeURIComponent(ABOUT.name + " " + version)
    + "&body=" + encodeURIComponent("\n\n--\n" + details)
}

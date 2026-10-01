#!/usr/bin/env node
// Export the game's pixel art (app/Sprites.js) as crisp SVGs for the
// website in docs/: every sprite, the Yoo-Haul with its wheels and
// lettering, and the title logo in the game's 5x7 font.
//
//   node tools/make-site-art.js
const fs = require("fs")
const path = require("path")

const root = path.join(__dirname, "..")
const src = fs.readFileSync(path.join(root, "app/Sprites.js"), "utf8").replace(/^\.pragma.*$/m, "")
const lib = {}
new Function("lib", src + "\nlib.SPRITES = SPRITES; lib.PALETTE = PALETTE; lib.FONT = FONT")(lib)
const out = path.join(root, "docs/art")
fs.mkdirSync(out, { recursive: true })

// Horizontal runs of one colour become one rect.
function spriteRects(rows, ox, oy, scale, tint) {
  let s = ""
  rows.forEach((row, y) => {
    let x = 0
    while (x < row.length) {
      const c = row[x]
      if (c === ".") { x++; continue }
      let run = 1
      while (x + run < row.length && row[x + run] === c) run++
      s += `<rect x="${ox + x * scale}" y="${oy + y * scale}" width="${run * scale}" height="${scale}" fill="${tint || lib.PALETTE[c]}"/>`
      x += run
    }
  })
  return s
}

function textRects(text, ox, oy, scale, fill, lower) {
  let s = ""
  const up = String(text).toUpperCase()
  for (let i = 0; i < up.length; i++) {
    const g = lib.FONT[up[i]] || lib.FONT["?"]
    for (let y = 0; y < 7; y++) for (let x = 0; x < 5; x++) {
      if (g[y][x] === "1") s += `<rect x="${ox + (i * 6 + x) * scale}" y="${oy + y * scale}" width="${scale}" height="${scale}" fill="${lower && y >= 4 ? lower : fill}"/>`
    }
  }
  return s
}

function svg(w, h, body, title) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" shape-rendering="crispEdges"${title ? ` role="img" aria-label="${title}"` : ` aria-hidden="true"`}>${body}</svg>\n`
}

for (const name of Object.keys(lib.SPRITES)) {
  const rows = lib.SPRITES[name]
  fs.writeFileSync(path.join(out, name + ".svg"), svg(rows[0].length, rows.length, spriteRects(rows, 0, 0, 1)))
}

// The truck as the Scene draws it: body, two wheels, lettering at 3/4 scale.
{
  const body = lib.SPRITES.truck
  const label = "YOO-HAUL"
  const lw = (label.length * 6 - 1) * 0.75
  let s = spriteRects(body, 0, 0, 1)
  s += textRects(label, 23 - lw / 2, 9.5 - 7 * 0.75 / 2, 0.75, "#c24e0c")
  s += `<g class="wheel">${spriteRects(lib.SPRITES.wheel0, 6, 19, 1)}</g>`
  s += `<g class="wheel">${spriteRects(lib.SPRITES.wheel0, 49, 19, 1)}</g>`
  fs.writeFileSync(path.join(out, "yoohaul.svg"), svg(body[0].length, 31, s, "A Yoo-Haul with a mattress strapped to the roof"))
}

// The title logo: yellow over orange, pink drop shadow, dark outline.
function logo(text, file) {
  const w = text.length * 6 - 1 + 1 + 2, h = 7 + 1 + 2
  const offs = [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1]]
  let s = ""
  for (const [dx, dy] of offs) {
    s += textRects(text, 1 + dx, 1 + dy, 1, "#1b1424")
    s += textRects(text, 2 + dx, 2 + dy, 1, "#1b1424")
  }
  s += textRects(text, 2, 2, 1, "#ff2a6d")
  s += textRects(text, 1, 1, 1, "#ffe36e", "#ff7a1a")
  fs.writeFileSync(path.join(out, file), svg(w, h, s, text))
}
logo("THE TEXODUS TRAIL", "logo.svg")
logo("TEXODUS", "logo-short.svg")

console.log("wrote", fs.readdirSync(out).length, "files to docs/art")

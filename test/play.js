#!/usr/bin/env node
// Plays thousands of random trips against the engine and checks the state
// invariants after every action. Run: node test/play.js [games]
"use strict"

const fs = require("fs")
const path = require("path")
const vm = require("vm")

const source = fs.readFileSync(path.join(__dirname, "..", "app", "Game.js"), "utf8").replace(/^\.pragma library\s*/m, "")
const ctx = {}
vm.runInNewContext(source + "\nthis.Game = { newGame, mode, ack, buy, sell, setPace, setRations, hitTheRoad, stop, rest, talk, offerTrade, answerTrade, canForage, forageResult, doSpecial, specialHere, storeHere, riverChoice, setEpitaph, settle, travelDay, validate, recordScore, sanitizeTopTen, sanitizeGraves, scoreBreakdown, price, alive, OCCUPATIONS, MONTHS, PACES, RATIONS, GOODS, TRIP_MILES }", ctx)
const Game = ctx.Game

const games = Number(process.argv[2] || 3000)
const stats = { won: 0, lost: 0, actions: 0, modes: {}, causes: {}, maxScore: 0, days: [], rivers: 0, specials: 0, events: 0 }
let failures = 0

function rnd(n) { return Math.floor(Math.random() * n) }
function pickOne(list) { return list[rnd(list.length)] }

function check(g, where, seed) {
  Game.settle(g)
  const err = Game.validate(g)
  if (err) {
    failures++
    if (failures < 12) console.error(`INVARIANT "${err}" after ${where} (seed ${seed}, day ${g.day}, mile ${g.miles}, mode ${Game.mode(g)})`)
    return false
  }
  // JSON round-trip must be lossless: the game is saved after every action
  const copy = JSON.parse(JSON.stringify(g))
  if (Game.validate(copy) !== "") { failures++; console.error("round-trip broke the save at " + where) }
  return true
}

// A "sensible" player: stocks up at stores, rests when sick, otherwise drives.
function shop(g, seed) {
  const want = { gas: 120, snacks: 300, sunscreen: 6, tires: 2, parts: 2, coupons: 20 }
  for (const id of Object.keys(want)) {
    const step = Game.GOODS.find(x => x.id === id).step
    let guard = 0
    while (g[id] < want[id] && guard++ < 40) {
      const r = Game.buy(g, id, step)
      if (!r.ok) break
    }
  }
  if (Math.random() < 0.3) Game.buy(g, "hat", 1)
  check(g, "shop", seed)
}

function playOne(seed) {
  const occ = pickOne(Game.OCCUPATIONS).id
  const month = pickOne(Game.MONTHS).month
  const g = Game.newGame({ occupation: occ, month, names: ["Tester"] }, seed)
  g.knownGraves = [{ name: "Old Chad", epitaph: "RIP", mile: 300, year: 2025 }]
  check(g, "newGame", seed)
  const careful = Math.random() < 0.6
  let guard = 0
  while (!g.finished && guard++ < 4000) {
    const m = Game.mode(g)
    stats.modes[m] = (stats.modes[m] || 0) + 1
    stats.actions++
    switch (m) {
    case "message":
      Game.ack(g)
      break
    case "river":
      Game.riverChoice(g, pickOne(careful ? ["bridge", "bridge", "wait", "caulk"] : ["ford", "caulk", "bridge", "wait"]))
      stats.rivers++
      break
    case "trade":
      Game.answerTrade(g, Math.random() < 0.5)
      break
    case "epitaph":
      Game.setEpitaph(g, Math.random() < 0.5 ? "" : "Here lies a fuzz test.")
      break
    case "camp": {
      if (Game.storeHere(g) && (careful || Math.random() < 0.5)) shop(g, seed)
      if (Game.specialHere(g) && Math.random() < 0.7) { Game.doSpecial(g); stats.specials++; break }
      const r = Math.random()
      if (r < 0.04) Game.talk(g)
      else if (r < 0.07) Game.offerTrade(g)
      else if (r < 0.1 && Game.canForage(g)) Game.forageResult(g, rnd(160), rnd(g.coupons + 1))
      else if (r < 0.14 || (careful && Game.alive(g).some(p => p.sick) && Math.random() < 0.4)) Game.rest(g, 1 + rnd(3))
      else if (r < 0.17) Game.setPace(g, pickOne(Game.PACES).id)
      else if (r < 0.2) Game.setRations(g, pickOne(Game.RATIONS).id)
      else if (!Game.hitTheRoad(g) && g.gas <= 0) Game.buy(g, "gas", 10)
      break
    }
    case "travel":
      Game.travelDay(g)
      break
    default:
      failures++
      console.error("unknown mode " + m)
      return
    }
    if (!check(g, m, seed)) return
  }
  if (!g.finished) { failures++; console.error(`game ${seed} never finished (mile ${g.miles}, mode ${Game.mode(g)})`); return }
  stats.events += g.stats.events
  stats.days.push(g.day)
  if (g.won) {
    stats.won++
    stats.maxScore = Math.max(stats.maxScore, g.score)
    const b = Game.scoreBreakdown(g)
    if (b.total !== g.score) { failures++; console.error("score mismatch") }
  } else {
    stats.lost++
    stats.causes[g.deathCause || "?"] = (stats.causes[g.deathCause || "?"] || 0) + 1
  }
  const top = Game.sanitizeTopTen([])
  Game.recordScore(top, g)
  if (top.length > 10) { failures++; console.error("top ten overflow") }
  if (Game.sanitizeGraves(g.graves).length !== Math.min(12, g.graves.length)) { failures++; console.error("graves lost on sanitize") }
}

for (let i = 0; i < games; i++) playOne(1000 + i)

stats.days.sort((a, b) => a - b)
console.log(JSON.stringify({
  games, failures, won: stats.won, lost: stats.lost,
  winRate: (stats.won / games).toFixed(2),
  medianDays: stats.days[Math.floor(stats.days.length / 2)],
  maxScore: stats.maxScore,
  avgEvents: (stats.events / games).toFixed(1),
  topCauses: Object.entries(stats.causes).sort((a, b) => b[1] - a[1]).slice(0, 6),
  modes: stats.modes
}, null, 1))
process.exit(failures ? 1 : 0)

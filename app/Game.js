.pragma library

// The Texodus Trail: the game engine.
//
// Pure functions over one plain-JSON state object, so the QML front end can
// save it after every action and node can fuzz it (test/play.js). Nothing in
// here touches QML, the clock, or Math.random(): every roll goes through the
// seeded generator stored on the state, so a saved game resumes exactly.
//
// The UI asks mode(g) what to show:
//   "end"      the trip is over (g.won tells you how it went)
//   "message"  g.queue[0] is a card to read; ack() dismisses it
//   <prompt>   g.prompt.type: "river", "trade", "steak", "epitaph"
//   "camp"     stopped; the size-up-the-situation menu
//   "travel"   rolling; the UI calls travelDay() on a timer

// ------------------------------------------------------------------ data --

var TRUCK_COST = 4812
var TRUCK_RETURN_COST = 612
var MPG = 10
var FORAGE_CARRY = 100
var TRIP_MILES = 1880

var OCCUPATIONS = [
  { id: "tech", name: "Laid-off FAANG Engineer", cash: 12000, mult: 1,
    blurb: "Severance, a drawer full of conference hoodies, and RSUs that vested the morning after the layoff email. Knows their way around a broken alternator (watched a video once)." },
  { id: "influencer", name: "Lifestyle Influencer", cash: 8000, mult: 2,
    blurb: "38,000 followers, eleven of them human. Vibes drop slower, and every disaster is content." },
  { id: "crypto", name: "Crypto Bro", cash: 15000, mult: 1.5,
    blurb: "Rich on paper. The paper is a memecoin called $TEXIT and it moves 10% a day in either direction. WAGMI." },
  { id: "writer", name: "Hollywood Screenwriter", cash: 6000, mult: 3,
    blurb: "Your pilot about a dentist who solves crimes is \"in development.\" Broke, brave, triple points. Hard mode." }
]

var MONTHS = [
  { month: 2, name: "March", note: "Mild. Bluebonnets waiting." },
  { month: 3, name: "April", note: "Perfect. Suspiciously perfect." },
  { month: 4, name: "May", note: "Warm. Texas is pre-heating." },
  { month: 5, name: "June", note: "Hot. Bring sunscreen." },
  { month: 6, name: "July", note: "Very hot. Bring more sunscreen." },
  { month: 7, name: "August", note: "Texas. In August. Bold." }
]

var PACES = [
  { id: "chill", name: "Chill", miles: 140, health: 0, note: "Scenic. Stops at every World's Largest Thing." },
  { id: "hustle", name: "Hustle", miles: 210, health: -3, note: "Rise and grind, but like, reasonably." },
  { id: "grindset", name: "Grindset", miles: 300, health: -7, note: "Sigma mode. No bathroom breaks. Bad idea." }
]

var RATIONS = [
  { id: "fasting", name: "Intermittent fasting", lbs: 1, health: -4, note: "It's not starving, it's a protocol." },
  { id: "sensible", name: "Sensible", lbs: 2, health: 0, note: "Three meals. Some of them beige." },
  { id: "brunch", name: "Bottomless brunch", lbs: 3, health: 2, note: "Mimosas not included. Morale is." }
]

var STATES = {
  ca: { name: "California", gas: 6.89, factor: 1.6 },
  az: { name: "Arizona", gas: 4.19, factor: 1.15 },
  nm: { name: "New Mexico", gas: 3.59, factor: 1.0 },
  tx: { name: "Texas", gas: 2.79, factor: 0.85 }
}

var GOODS = [
  { id: "gas", name: "Gasoline", unit: "gal", step: 10, base: 0, note: "A 26-foot Yoo-Haul gets 10 mpg. Downhill. With a tailwind." },
  { id: "snacks", name: "Snacks", unit: "lbs", step: 25, base: 2.5, note: "Each person eats 1-3 lbs a day, depending on how you ration it." },
  { id: "sunscreen", name: "Sunscreen", unit: "bottles", step: 1, base: 10, note: "One bottle a day keeps the party alive when it's scorching." },
  { id: "tires", name: "Spare tires", unit: "tires", step: 1, base: 180, note: "The desert eats tires. Bring a couple." },
  { id: "parts", name: "Spare parts", unit: "parts", step: 1, base: 120, note: "Belts, hoses, a mystery alternator. Fixes most breakdowns." },
  { id: "coupons", name: "Coupons", unit: "coupons", step: 10, base: 0.8, note: "One coupon per toss during a Food Truck Frenzy." }
]

var HAT_PRICE = 40

// Landmarks along I-40 and friends. "state" is the state you are in on the
// way to it; "store" names the shop, "river" makes it a crossing, "special"
// is the one silly thing you can do there.
var LANDMARKS = [
  { name: "San Francisco, CA", short: "San Francisco", mile: 0, state: "ca", store: "Costco (Daly City)",
    text: "The fog rolls in. Your landlord texts \"hey quick q\" for the last time. Behind you: a one-bedroom that rented for $3,950 and a sourdough starter you could not bring yourself to pack." },
  { name: "Bakersfield, CA", short: "Bakersfield", mile: 280, state: "ca",
    text: "Smells like cattle and crude oil. Still California, technically. Someone in a gas station parking lot is playing Buck Owens and it is, honestly, a bop." },
  { name: "Barstow, CA", short: "Barstow", mile: 410, state: "ca", store: "Barstow Station",
    special: "innout",
    text: "The last outpost. A sign says LAST IN-N-OUT FOR A VERY LONG TIME and people are weeping in the drive-thru. Fear and loathing optional." },
  { name: "Colorado River (Needles)", short: "Colorado River", mile: 555, state: "ca", river: { minDepth: 2, maxDepth: 7, toll: 40 },
    text: "The Colorado River. On the far bank: Arizona, where it is somehow even hotter and nobody does Daylight Saving Time." },
  { name: "Kingman, AZ", short: "Kingman", mile: 615, state: "az",
    text: "Route 66. Get your kicks. There is a neon sign shaped like a cowboy and it has seen things." },
  { name: "Flagstaff, AZ", short: "Flagstaff", mile: 760, state: "az", store: "Flagstaff Trading Post",
    text: "Pine trees! Altitude! Possibly snow, which half your party has only seen at Tahoe on a work offsite." },
  { name: "Winslow, AZ", short: "Winslow", mile: 820, state: "az", special: "corner",
    text: "Well, you're standin' on a corner in Winslow, Arizona. There is a flatbed Ford. Nobody is slowing down to take a look at you." },
  { name: "Rio Grande (Albuquerque)", short: "Rio Grande", mile: 1080, state: "nm", river: { minDepth: 1, maxDepth: 5, toll: 25 },
    text: "The Rio Grande, which is less grande than advertised. A guy in a pork pie hat on the bridge is watching you very carefully." },
  { name: "Albuquerque, NM", short: "Albuquerque", mile: 1085, state: "nm", store: "Los Pollos Grocery",
    text: "Should have taken that left turn here, a cartoon rabbit once said. Green chile on everything. The hot air balloons look like a screensaver." },
  { name: "Tucumcari, NM", short: "Tucumcari", mile: 1260, state: "nm",
    text: "TUCUMCARI TONITE! say two thousand motel signs, all lit, none with vacancies you would want." },
  { name: "Texas State Line", short: "Texas Line", mile: 1300, state: "nm", special: "selfie",
    text: "WELCOME TO TEXAS. DRIVE FRIENDLY - THE TEXAS WAY. The sky gets bigger. The trucks get bigger. Your state income tax, for the first time in your adult life, is zero." },
  { name: "Amarillo, TX", short: "Amarillo", mile: 1375, state: "tx", store: "Buc-ee's", special: "steak",
    text: "A billboard: FREE 72 OZ STEAK (if you eat it in an hour). Across the road, a Buc-ee's the size of a regional airport. The beaver is smiling at you. The beaver knows." },
  { name: "Lubbock, TX", short: "Lubbock", mile: 1495, state: "tx",
    text: "Home of Buddy Holly. Somebody's radio plays Peggy Sue. Cotton fields to the horizon and a wind that has opinions." },
  { name: "Abilene, TX", short: "Abilene", mile: 1660, state: "tx", store: "Abilene Feed & Supply",
    text: "Abilene, Abilene, prettiest town I've ever seen. The feed store also sells phone chargers and fireworks. Freedom." },
  { name: "Austin, TX", short: "Austin", mile: 1880, state: "tx",
    text: "You made it. Rent is $2,400, the traffic is somehow worse, and your new neighbor is from Palo Alto. He hands you a kombucha. Welcome home." }
]

var NAMES = ["Chad", "Skyler", "Brayden", "Aspen", "Kale", "Saffron", "Juniper", "Tanner", "Sage", "Bodhi", "Harper", "Kinsley", "Paisley", "Ryder", "Wren", "Jaxon", "Indigo", "Maverick", "Sequoia", "Blaise"]

var AILMENTS = [
  { cause: "dysentery", text: "has dysentery", days: 5, where: "" },
  { cause: "dysentery (gas station sushi)", text: "ate gas station sushi", days: 4, where: "" },
  { cause: "a sunburn of biblical proportions", text: "has a sunburn of biblical proportions", days: 4, where: "az nm tx" },
  { cause: "In-N-Out withdrawal", text: "is going through In-N-Out withdrawal", days: 6, where: "az nm tx" },
  { cause: "heat exhaustion", text: "has heat exhaustion", days: 3, where: "az nm tx" },
  { cause: "a rattlesnake bite", text: "was bitten by a rattlesnake", days: 5, where: "az nm tx" },
  { cause: "doomscroller's thumb", text: "has doomscroller's thumb", days: 3, where: "" },
  { cause: "a broken heart", text: "is heartbroken (left their sourdough starter in Oakland)", days: 4, where: "ca az" },
  { cause: "exhaustion", text: "is exhausted", days: 3, where: "" },
  { cause: "Valley Fever", text: "has Valley Fever", days: 6, where: "ca az" },
  { cause: "a self-diagnosed gluten exposure", text: "has a self-diagnosed gluten exposure", days: 3, where: "" },
  { cause: "the meat sweats", text: "has the meat sweats", days: 3, where: "tx" },
  { cause: "ERCOT-induced anxiety", text: "has ERCOT-induced anxiety", days: 4, where: "tx" },
  { cause: "a mild case of nostalgia", text: "won't stop talking about Dolores Park", days: 3, where: "" },
  { cause: "allergies to literally everything", text: "is allergic to cedar, which is all of Texas", days: 4, where: "tx" }
]

var EPITAPHS = [
  "Should have bought Bitcoin in 2011.",
  "Finally free of state income tax.",
  "Said \"hella\" until the very end.",
  "Gone to the great Whole Foods in the sky.",
  "Their Zillow alerts are finally off.",
  "Died doing what they loved: complaining about rent.",
  "Rent-controlled forever.",
  "This is fine.",
  "Be excellent to each other.",
  "Never got to try Whataburger.",
  "Their LinkedIn still says Open to Work.",
  "I'll be back. (They will not be back.)"
]

var RATINGS = [
  { min: 6000, title: "Certified Texan (bless your heart)" },
  { min: 3500, title: "Honorary Texan" },
  { min: 1800, title: "Transplant" },
  { min: 800, title: "Tourist with a Yoo-Haul" },
  { min: 0, title: "Still Says \"Hella\"" }
]

var DEFAULT_TOP_TEN = [
  { name: "A Podcaster You've Heard Of", score: 7650, rating: "Certified Texan (bless your heart)" },
  { name: "Some Guy From Palo Alto", score: 5200, rating: "Honorary Texan" },
  { name: "Your Old Roommate", score: 4410, rating: "Honorary Texan" },
  { name: "The Kombucha Guy", score: 3600, rating: "Honorary Texan" },
  { name: "A Very Large Cybertruck", score: 2900, rating: "Transplant" },
  { name: "Three Raccoons in a Trenchcoat", score: 2400, rating: "Transplant" },
  { name: "Your Former Landlord", score: 1900, rating: "Transplant" },
  { name: "Doc Brown (wrong year)", score: 1500, rating: "Tourist with a Yoo-Haul" },
  { name: "Ferris (day off)", score: 1100, rating: "Tourist with a Yoo-Haul" },
  { name: "A Lost Tesla on Autopilot", score: 600, rating: "Still Says \"Hella\"" }
]

var TALK = [
  [ "A woman in a Patagonia vest tells you: \"We're leaving too. Everyone's leaving. The last person out, please turn off the high-speed rail. Oh wait.\"",
    "Your former landlord, jogging past: \"Rent's going up 30% anyway. Good luck out there, champ.\"",
    "A guy selling oranges at an off-ramp says: \"Texas? Bold. I hear they have weather there. Like, all of it.\"" ],
  [ "A trucker named Big Earl tells you: \"Pace yourself. Folks who go Grindset end up in the ditch talking to cactuses.\"",
    "An old farmer says: \"Y'all need more water than you think. And more snacks than that.\"",
    "A kid on a bike: \"Is that a Yoo-Haul? Are you guys moving to Austin? Everyone is moving to Austin.\"" ],
  [ "A woman in the In-N-Out line, sobbing: \"There's no Double-Double where you're going. Order two. Order four.\"",
    "A man in a cowboy hat (from Fresno): \"Gas only gets cheaper from here. Don't overfill in California.\"",
    "A tour bus driver: \"Calico ghost town's up the road. Most realistic Bay Area rent simulator I've ever seen.\"" ],
  [ "A ranger tells you: \"The bridge is safe but costs money. Fording works if it's shallow. Caulking works if you watched the whole video.\"",
    "A guy fishing: \"Lost a whole Tesla here last week. Floated great until it didn't.\"",
    "A lizard. It doesn't say anything. It just judges you." ],
  [ "A man at a diner says: \"Route 66 is America's Main Street. Also its main parking lot.\"",
    "A waitress: \"Hon, you look like you need pie. Everyone looks like they need pie.\"",
    "A biker named Gandalf (not his real name, it is his real name): \"Ride free. Hydrate.\"" ],
  [ "A ski bum says: \"Snow? Out here? Sure. Pack a jacket, Californian. No, a real one.\"",
    "A geologist: \"The Grand Canyon is a 90 minute detour. You won't take it. Nobody takes it.\"",
    "A guy at the trading post: \"Arizona gas is cheaper than California. New Mexico's cheaper still. Texas? Practically free.\"" ],
  [ "A man on the corner says: \"Take it easy. Don't let the sound of your own wheels drive you crazy.\"",
    "A girl in a flatbed Ford slows down to take a look at you. She keeps driving. Iconic.",
    "A souvenir shop owner: \"Every day, somebody stands on this corner. Every day, somebody sings it badly.\"" ],
  [ "A bald chemistry teacher (retired) tells you: \"Cross the bridge. Pay the toll. Never ford a river you don't respect.\"",
    "A lawyer on a billboard: \"Better call... no, you know what, just call anybody. Hydrate.\"",
    "A fisherman: \"Rio Grande means Big River. Marketing.\"" ],
  [ "A balloon pilot says: \"Sometimes I just float east for a while. Can't blame you.\"",
    "A man in a restaurant apron, very calm: \"The chicken here is excellent. Don't ask about the basement.\"",
    "A lady selling green chile: \"Put it on your eggs. Put it on your burger. Put it in your heart.\"" ],
  [ "A motel clerk: \"We have rooms. We have neon. We have a pool shaped like a guitar and nobody knows why.\"",
    "A trucker: \"Texas is close. You can smell the brisket from here. That's not a joke. Sniff.\"",
    "A retiree from Sacramento: \"Made it out in '09. Never looked back. Okay I look back sometimes.\"" ],
  [ "A state trooper (very polite): \"Welcome to Texas. Speed limit's 75. Everybody does 85. Don't do 95.\"",
    "A man in a giant belt buckle: \"First thing, get a hat. Second thing, don't call it a 'cowboy hat.' It's a hat.\"",
    "A sign: DON'T MESS WITH TEXAS. A second, smaller sign: THAT MEANS LITTERING, CALIFORNIA." ],
  [ "A Buc-ee's employee says: \"We have 120 gas pumps and the cleanest bathrooms in human history. Stay a while. Stay forever.\"",
    "A man finishing a 72 oz steak: \"Don't drink the water. It takes up steak room.\"",
    "A woman in boots: \"Bless your heart, y'all made it all the way from San Francisco? In that?\"" ],
  [ "A local tells you: \"Buddy Holly was from here. Everybody's got a guitar and an opinion.\"",
    "A cotton farmer: \"Wind'll blow your Yoo-Haul halfway to Oklahoma. Hold onto your mattress.\"",
    "A college kid: \"Austin? Oh you'll love it. If you can afford it. You can't, but you'll love it.\"" ],
  [ "An old cowboy says: \"Three hours to Austin. Austin's just California with brisket, son.\"",
    "The feed store owner: \"Buy your sunscreen. Hill Country sun is personal.\"",
    "A little girl: \"My mom says Californians tip good. Do you tip good?\"" ],
  [ "Your new neighbor: \"Hey! I'm also from the Bay! Small world! Do you want to start a running club?\"",
    "A man on a scooter: \"Keep Austin Weird. Also, could you not.\"",
    "A food truck: \"Breakfast tacos, nine dollars. Welcome home.\"" ]
]

var TRADERS = [
  "A guy in a Patagonia vest",
  "A retired dentist in a Cybertruck",
  "A woman selling healing crystals",
  "Big Earl, a trucker",
  "A Buc-ee's employee on break",
  "A van-life couple from Portland",
  "A man who insists he's a Navy SEAL",
  "Three kids running a lemonade stand",
  "A tumbleweed (it's got a guy inside)"
]

var BILLBOARDS = {
  ca: [ "LAST IN-N-OUT FOR 1,400 MILES", "LEAVING CALIFORNIA? PLEASE TURN OFF THE LIGHTS", "GAS $6.89 · SORRY", "THE 5 IS CLOSED. ALSO THE 10." ],
  az: [ "NO DAYLIGHT SAVING. NO PROBLEMS.", "THE THING? 300 MILES. YOU WILL STOP.", "IT'S A DRY HEAT (IT'S 118)" ],
  nm: [ "SHOULD'VE TAKEN A LEFT AT ALBUQUERQUE", "TUCUMCARI TONITE!", "GREEN OR RED? (BOTH)" ],
  tx: [ "BUC-EE'S 262 MI · YOU CAN HOLD IT", "DON'T MESS WITH TEXAS", "WELCOME Y'ALL · EVERYONE HERE IS FROM CALIFORNIA", "FREE 72 OZ STEAK*", "KEEP AUSTIN WEIRD (ALSO AFFORDABLE, PLEASE)" ]
}

// ----------------------------------------------------------------- random --

function rand(g) {
  // mulberry32, state kept on the game so a reload resumes the same stream
  var t = (g.rng = (g.rng + 0x6D2B79F5) >>> 0)
  t = Math.imul(t ^ (t >>> 15), t | 1)
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}
function rint(g, lo, hi) { return lo + Math.floor(rand(g) * (hi - lo + 1)) }
function pick(g, list) { return list[Math.floor(rand(g) * list.length)] }
function chance(g, p) { return rand(g) < p }

// ---------------------------------------------------------------- helpers --

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

function formatMoney(n) {
  n = Math.round(Number(n) || 0)
  var neg = n < 0
  var s = String(Math.abs(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  return (neg ? "-$" : "$") + s
}

function formatPrice(n) {
  n = Number(n) || 0
  if (n >= 100 || Math.abs(n - Math.round(n)) < 0.005) return formatMoney(n)
  return "$" + n.toFixed(2)
}

function occupation(g) {
  for (var i = 0; i < OCCUPATIONS.length; i++) if (OCCUPATIONS[i].id === g.occupation) return OCCUPATIONS[i]
  return OCCUPATIONS[0]
}

function alive(g) { return g.party.filter(function(m) { return m.alive }) }
function leader(g) { return g.party[0] }

function stateAt(mile) {
  if (mile < 556) return "ca"
  if (mile < 960) return "az"
  if (mile < 1300) return "nm"
  return "tx"
}

function regionOf(g) { return stateAt(g.miles) }

function nextLandmarkIndex(g) {
  for (var i = 0; i < LANDMARKS.length; i++) if (LANDMARKS[i].mile > g.miles) return i
  return -1
}

function nextLandmark(g) {
  var i = nextLandmarkIndex(g)
  return i >= 0 ? LANDMARKS[i] : null
}

function currentLandmark(g) {
  return g.at >= 0 ? LANDMARKS[g.at] : null
}

function storeHere(g) {
  var lm = currentLandmark(g)
  return lm && lm.store ? lm.store : ""
}

function specialHere(g) {
  var lm = currentLandmark(g)
  if (!lm || !lm.special) return null
  if (g.specialsDone.indexOf(lm.special) !== -1) return null
  return SPECIALS[lm.special]
}

function dateOf(g, offset) {
  var d = new Date(Date.UTC(g.year, g.startMonth, 1))
  d.setUTCDate(d.getUTCDate() + g.day + (offset || 0))
  return d
}

var MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

function dateText(g) {
  var d = dateOf(g)
  return MONTH_NAMES[d.getUTCMonth()] + " " + d.getUTCDate() + ", " + d.getUTCFullYear()
}

function healthLabel(hp) {
  if (hp >= 75) return "Good"
  if (hp >= 50) return "Fair"
  if (hp >= 25) return "Poor"
  return "Very poor"
}

function partyHealth(g) {
  var a = alive(g)
  if (!a.length) return 0
  var sum = 0
  for (var i = 0; i < a.length; i++) sum += a[i].hp
  return Math.round(sum / a.length)
}

function weather(g) {
  return g.weather || "Sunny"
}

function rollWeather(g) {
  var r = regionOf(g)
  var month = dateOf(g).getUTCMonth()
  var heat = month - 2 // 0 in March .. 5 in August
  var roll = rand(g)
  if (r === "ca") {
    if (roll < 0.18) return "Smoky"
    if (roll < 0.25) return "Foggy"
    return heat >= 3 ? "Hot" : "Sunny"
  }
  if (r === "az" || r === "nm") {
    if (g.miles > 700 && g.miles < 900 && month < 4 && roll < 0.3) return "Snowy"
    if (roll < 0.12) return "Dust storm"
    if (heat >= 3 && roll < 0.75) return "Scorching"
    return roll < 0.55 ? "Hot" : "Sunny"
  }
  // Texas: all of it, at once
  if (roll < 0.1) return "Hail"
  if (roll < 0.18) return "Tornado watch"
  if (heat >= 2 && roll < 0.8) return "Scorching"
  return roll < 0.6 ? "Hot" : "Humid"
}

function gasPrice(g) {
  return STATES[regionOf(g)].gas
}

function price(g, goodId) {
  var st = STATES[regionOf(g)]
  if (goodId === "gas") return st.gas
  for (var i = 0; i < GOODS.length; i++) if (GOODS[i].id === goodId) return Math.round(GOODS[i].base * st.factor * 100) / 100
  return 0
}

function twangTitle(t) {
  if (t >= 90) return "Fixin' to"
  if (t >= 70) return "Says y'all"
  if (t >= 45) return "Owns boots"
  if (t >= 20) return "Tried brisket"
  return "Says hella"
}

function vibesLabel(v) {
  if (v >= 80) return "Immaculate"
  if (v >= 60) return "Good"
  if (v >= 40) return "Mid"
  if (v >= 20) return "Rough"
  return "Cooked"
}

// --------------------------------------------------------------- new game --

function newGame(opts, seed) {
  opts = opts || {}
  var occ = null
  for (var i = 0; i < OCCUPATIONS.length; i++) if (OCCUPATIONS[i].id === opts.occupation) occ = OCCUPATIONS[i]
  if (!occ) occ = OCCUPATIONS[0]
  var names = Array.isArray(opts.names) ? opts.names.slice(0, 5) : []
  while (names.length < 5) names.push("")
  var g = {
    v: 1,
    rng: (seed === undefined ? Math.floor(Math.random() * 4294967296) : seed) >>> 0,
    occupation: occ.id,
    year: Number(opts.year) || 2026,
    startMonth: 3,
    day: 0,
    miles: 0,
    at: 0,
    cash: occ.cash - TRUCK_COST,
    gas: 0, snacks: 0, sunscreen: 0, tires: 0, parts: 0, coupons: 0,
    hats: 0,
    pace: "hustle",
    rations: "sensible",
    vibes: 70,
    twang: 0,
    weather: "Foggy",
    party: [],
    queue: [],
    prompt: null,
    stopped: true,
    finished: false,
    won: false,
    scored: false,
    score: 0,
    rating: "",
    deathCause: "",
    specialsDone: [],
    talked: {},
    tradedDay: -1,
    graves: [],
    passedGraves: [],
    stats: { days: 0, events: 0, foraged: 0, rivers: 0, flats: 0 },
    log: []
  }
  for (var m = 0; m < MONTHS.length; m++) if (MONTHS[m].month === opts.month) g.startMonth = opts.month
  for (var n = 0; n < 5; n++) {
    var nm = String(names[n] || "").trim().slice(0, 18)
    if (!nm) nm = n === 0 ? "You" : NAMES[(n * 3 + g.rng) % NAMES.length]
    g.party.push({ name: nm, hp: 100, alive: true, sick: null, sickDays: 0 })
  }
  // never two of the same default name
  var seen = {}
  for (var p = 0; p < g.party.length; p++) {
    var base = g.party[p].name
    var k = 2
    while (seen[g.party[p].name]) g.party[p].name = base + " " + (k++)
    seen[g.party[p].name] = true
  }
  return g
}

// ---------------------------------------------------------------- queries --

function mode(g) {
  if (!g) return "none"
  if (g.queue && g.queue.length) return "message"
  if (g.finished) return "end"
  if (g.prompt) return g.prompt.type
  return g.stopped ? "camp" : "travel"
}

function say(g, title, text, tone, sfx, art) {
  g.queue.push({ title: title, text: text, tone: tone || "neutral", sfx: sfx || "", art: art || "" })
  g.log.push(title + ": " + text)
  if (g.log.length > 60) g.log.splice(0, g.log.length - 60)
}

function ack(g) {
  if (g.queue.length) g.queue.shift()
  return true
}

// -------------------------------------------------------------- the store --

function buy(g, goodId, qty) {
  qty = Math.floor(Number(qty) || 0)
  if (!storeHere(g)) return { ok: false, error: "There's no store here. There's barely a here here." }
  if (qty <= 0) return { ok: false, error: "Enter how many." }
  var cost
  if (goodId === "hat") {
    if (regionOf(g) !== "tx") return { ok: false, error: "Hats are a Texas thing. You'll know when." }
    cost = HAT_PRICE * qty
    if (cost > g.cash + 0.001) return { ok: false, error: "Not enough cash. That's " + formatMoney(cost) + "." }
    g.cash -= cost
    var before = g.hats
    g.hats += qty
    var gained = 0
    for (var h = before; h < g.hats && h < 5; h++) gained += 8
    g.twang = clamp(g.twang + gained, 0, 100)
    g.vibes = clamp(g.vibes + 4 * qty, 0, 100)
    return { ok: true, cost: cost }
  }
  var unit = price(g, goodId)
  if (!unit) return { ok: false, error: "They don't sell that here." }
  cost = Math.round(unit * qty * 100) / 100
  if (cost > g.cash + 0.001) return { ok: false, error: "Not enough cash. That's " + formatPrice(cost) + "." }
  g.cash = Math.round((g.cash - cost) * 100) / 100
  g[goodId] += qty
  return { ok: true, cost: cost }
}

function sell(g, goodId, qty) {
  qty = Math.floor(Number(qty) || 0)
  if (!storeHere(g)) return { ok: false, error: "No store here." }
  if (qty <= 0 || g[goodId] === undefined || g[goodId] < qty) return { ok: false, error: "You don't have that many." }
  var unit = price(g, goodId) * 0.5
  g[goodId] -= qty
  g.cash = Math.round((g.cash + unit * qty) * 100) / 100
  return { ok: true }
}

// ------------------------------------------------------------- camp menu --

function setPace(g, id) {
  for (var i = 0; i < PACES.length; i++) if (PACES[i].id === id) { g.pace = id; return true }
  return false
}

function setRations(g, id) {
  for (var i = 0; i < RATIONS.length; i++) if (RATIONS[i].id === id) { g.rations = id; return true }
  return false
}

function paceOf(g) { for (var i = 0; i < PACES.length; i++) if (PACES[i].id === g.pace) return PACES[i]; return PACES[1] }
function rationsOf(g) { for (var i = 0; i < RATIONS.length; i++) if (RATIONS[i].id === g.rations) return RATIONS[i]; return RATIONS[1] }

function hitTheRoad(g) {
  if (g.finished || g.prompt || g.queue.length) return false
  if (g.at === 0 && g.gas <= 0) {
    say(g, "Hold up", "You have zero gallons of gas. The Yoo-Haul runs on gas, not vibes. Hit the store first.", "bad", "bonk")
    return false
  }
  g.stopped = false
  return true
}

function stop(g) {
  if (g.finished) return false
  g.stopped = true
  return true
}

function rest(g, days) {
  days = clamp(Math.floor(Number(days) || 1), 1, 9)
  for (var d = 0; d < days && !g.finished && !g.prompt; d++) {
    passDay(g, { resting: true, miles: 0 })
  }
  if (!g.finished) {
    var a = alive(g)
    say(g, "Rest stop", "You rested for " + days + (days === 1 ? " day" : " days") + ". Party health: " + healthLabel(partyHealth(g)) + ". " + (a.length > 1 ? pick(g, ["Someone found a hammock.", "Everyone binged a whole season of something.", "Nobody checked Slack. Healing.", "You played Uno. Friendships were tested."]) : "It was quiet. Too quiet."), "good", "rest")
  }
  return true
}

function talk(g) {
  var idx = g.at >= 0 ? g.at : Math.max(0, nextLandmarkIndex(g) - 1)
  var lines = TALK[idx] || TALK[0]
  var key = String(idx)
  var n = g.talked[key] || 0
  g.talked[key] = n + 1
  say(g, "Talk to people", lines[n % lines.length], "neutral", "blip")
  if (n < lines.length) g.vibes = clamp(g.vibes + 2, 0, 100)
  return true
}

// ---------------------------------------------------------------- trading --

var TRADE_ITEMS = [
  { id: "gas", name: "gallons of gas", lo: 10, hi: 40 },
  { id: "snacks", name: "lbs of snacks", lo: 25, hi: 80 },
  { id: "sunscreen", name: "bottles of sunscreen", lo: 1, hi: 4 },
  { id: "tires", name: "spare tires", lo: 1, hi: 2 },
  { id: "parts", name: "spare parts", lo: 1, hi: 2 },
  { id: "coupons", name: "coupons", lo: 10, hi: 30 }
]

function offerTrade(g) {
  if (g.tradedDay === g.day) {
    say(g, "Trade", "Nobody else wants to trade today. Word has spread about your haggling.", "neutral", "blip")
    return false
  }
  g.tradedDay = g.day
  passDay(g, { resting: true, miles: 0, quiet: true })
  if (g.finished || g.prompt) return true
  var want = pick(g, TRADE_ITEMS)
  var give = pick(g, TRADE_ITEMS.filter(function(t) { return t.id !== want.id }))
  var o = {
    type: "trade",
    who: pick(g, TRADERS),
    give: give.id, giveName: give.name, giveQty: rint(g, give.lo, give.hi),
    want: want.id, wantName: want.name, wantQty: rint(g, want.lo, want.hi)
  }
  o.canAfford = g[o.want] >= o.wantQty
  g.prompt = o
  return true
}

function answerTrade(g, yes) {
  var o = g.prompt
  if (!o || o.type !== "trade") return false
  g.prompt = null
  if (!yes) {
    say(g, "Trade", o.who + " shrugs. \"Your loss, chief.\"", "neutral", "blip")
    return true
  }
  if (g[o.want] < o.wantQty) {
    say(g, "Trade", "You don't have " + o.wantQty + " " + o.wantName + ". " + o.who + " leaves, visibly disappointed in you as a person.", "bad", "bonk")
    return true
  }
  g[o.want] -= o.wantQty
  g[o.give] += o.giveQty
  say(g, "Deal!", "You traded " + o.wantQty + " " + o.wantName + " for " + o.giveQty + " " + o.giveName + ". " + pick(g, ["Handshake. Firm. Slightly damp.", "They also gave you a business card for their podcast.", "\"Pleasure doin' business,\" they say, and moonwalk away.", "You are pretty sure you got hustled. Still feels great."]), "good", "coin")
  return true
}

// ---------------------------------------------------------------- foraging --

function canForage(g) { return g.coupons > 0 && !g.finished }

// The minigame lives in the UI. It reports pounds bagged and coupons tossed.
function forageResult(g, lbs, used) {
  lbs = Math.max(0, Math.floor(Number(lbs) || 0))
  used = clamp(Math.floor(Number(used) || 0), 0, g.coupons)
  g.coupons -= used
  var kept = Math.min(lbs, FORAGE_CARRY)
  g.snacks += kept
  g.stats.foraged += kept
  var text
  if (lbs === 0) text = "You bagged nothing. A taco truck honked at you on the way out. Rude, but fair."
  else if (lbs > FORAGE_CARRY) text = "You bagged " + lbs + " lbs of food, but the Yoo-Haul is full of air fryers and a Peloton nobody rides, so you could only fit " + FORAGE_CARRY + " lbs. The rest goes to some very happy coyotes."
  else text = "You bagged " + lbs + " lbs of food. " + pick(g, ["The brisket alone has a fan club now.", "Kale salad count: zero. Good.", "Somebody should frame that kolache."])
  passDay(g, { resting: false, miles: 0, quiet: true })
  say(g, "Food Truck Frenzy", text, lbs > 0 ? "good" : "bad", lbs > 0 ? "coin" : "bonk")
  return kept
}

// ---------------------------------------------------------------- specials --

var SPECIALS = {
  innout: { label: "Eat at In-N-Out one last time ($48)", cost: 48 },
  corner: { label: "Stand on the corner (free)", cost: 0 },
  selfie: { label: "Take a selfie with the WELCOME TO TEXAS sign", cost: 0 },
  steak: { label: "Attempt the 72 oz steak challenge ($72)", cost: 72 }
}

function doSpecial(g) {
  var lm = currentLandmark(g)
  var sp = specialHere(g)
  if (!lm || !sp) return false
  if (sp.cost > g.cash) {
    say(g, "Can't afford it", "That's " + formatMoney(sp.cost) + ". You have " + formatMoney(g.cash) + ". The dream will have to wait.", "bad", "bonk")
    return false
  }
  g.specialsDone.push(lm.special)
  if (lm.special === "innout") {
    g.cash -= 48
    g.vibes = clamp(g.vibes + 20, 0, 100)
    alive(g).forEach(function(m) { m.hp = clamp(m.hp + 10, 0, 100); if (m.sick && m.sick.indexOf("In-N-Out") >= 0) { m.sick = null; m.sickDays = 0 } })
    say(g, "Double-Double, Animal Style", "Five Double-Doubles, animal-style fries, and a secret-menu item you're legally not allowed to describe. Somebody cried. It was you. Vibes +20, everyone feels better.", "good", "fanfare", "burger")
  } else if (lm.special === "corner") {
    g.vibes = clamp(g.vibes + 12, 0, 100)
    say(g, "Take It Easy", "You stand on the corner. A girl, my Lord, in a flatbed Ford slows down to take a look at you. The whole party sings the harmony part. Badly. Vibes +12.", "good", "fanfare")
  } else if (lm.special === "selfie") {
    g.twang = clamp(g.twang + 10, 0, 100)
    g.vibes = clamp(g.vibes + 8, 0, 100)
    if (g.occupation === "influencer") {
      g.cash += 400
      say(g, "Content!", "Your WELCOME TO TEXAS selfie gets 2.1 million views. A boot brand sends you $400 and a discount code. Twang +10, Vibes +8.", "good", "fanfare", "selfie")
    } else {
      say(g, "Say Cheese(steak)", "The selfie is perfect. Everyone is squinting and the sign is cut off. Your mom comments \"Who is this\". Twang +10, Vibes +8.", "good", "fanfare", "selfie")
    }
  } else if (lm.special === "steak") {
    var eater = alive(g).slice().sort(function(a, b) { return b.hp - a.hp })[0]
    var odds = 0.15 + eater.hp / 300 + (g.rations === "fasting" ? 0.15 : 0) + g.twang / 400
    g.cash -= 72
    if (chance(g, odds)) {
      g.cash += 72
      g.twang = clamp(g.twang + 25, 0, 100)
      g.vibes = clamp(g.vibes + 20, 0, 100)
      say(g, "LEGEND", eater.name + " eats the entire 72 oz steak, the shrimp cocktail, the baked potato, the salad, and the roll in 51 minutes. The restaurant rings a bell. A man in a ten-gallon hat salutes. Your $72 is refunded. Twang +25.", "good", "fanfare", "steak")
    } else {
      eater.hp = clamp(eater.hp - 15, 1, 100)
      eater.sick = "has the meat sweats"
      eater.sickDays = 3
      g.vibes = clamp(g.vibes + 5, 0, 100)
      g.twang = clamp(g.twang + 8, 0, 100)
      say(g, "Defeated by Beef", eater.name + " gets through 41 ounces before staring into the middle distance and whispering \"rosebud.\" No refund. " + eater.name + " has the meat sweats. Still, respect. Twang +8.", "bad", "bonk", "steak")
    }
  }
  return true
}

// ------------------------------------------------------------------ rivers --

function arriveAtRiver(g, lm) {
  // a death on the way in still gets its epitaph, right after the crossing
  if (g.prompt && g.prompt.type === "epitaph") g.pendingGraves = [{ name: g.prompt.name, cause: g.prompt.cause }].concat(g.pendingGraves || [])
  var r = lm.river
  var depth = Math.round((r.minDepth + rand(g) * (r.maxDepth - r.minDepth)) * 10) / 10
  var width = rint(g, 180, 620)
  g.prompt = { type: "river", name: lm.short, depth: depth, width: width, toll: r.toll + rint(g, 0, 3) * 5 }
}

function riverChoice(g, choice) {
  var p = g.prompt
  if (!p || p.type !== "river") return false
  if (choice === "wait") {
    passDay(g, { resting: true, miles: 0, quiet: true })
    if (g.finished) { g.prompt = null; return true }
    p.depth = Math.max(0.8, Math.round((p.depth + (rand(g) - 0.55) * 1.6) * 10) / 10)
    say(g, "You wait a day", "The river is now " + p.depth + " ft deep. " + pick(g, ["A duck stares at you.", "Someone across the bank waves. You wave back. Bonding.", "You skip rocks. Seven skips! Personal best.", "Nothing happens. It is beautiful."]), "neutral", "blip")
    return true
  }
  if (choice === "bridge") {
    if (g.cash < p.toll) {
      say(g, "Toll bridge", "The toll is " + formatMoney(p.toll) + ". You have " + formatMoney(g.cash) + ". The guy in the booth suggests you \"figure it out.\"", "bad", "bonk")
      return false
    }
    g.cash -= p.toll
    g.prompt = null
    g.stats.rivers++
    say(g, "Across!", "You pay the " + formatMoney(p.toll) + " toll. A man named Dale also charges you nothing but insists on telling you about his divorce. You cross safely. Boring. Perfect.", "good", "splash", "river")
    finishRiver(g)
    return true
  }
  var lossOdds
  if (choice === "ford") lossOdds = p.depth < 2.5 ? 0.05 : p.depth < 4 ? 0.4 : 0.8
  else lossOdds = 0.18 + (p.depth > 5 ? 0.1 : 0)
  g.prompt = null
  g.stats.rivers++
  if (!chance(g, lossOdds)) {
    say(g, "Across!", choice === "ford"
      ? "You ford it. In a Ford. (It's a Yoo-Haul, but the spirit is there.) Everything stays dry except the mattress, which was already like that."
      : "You caulk the Yoo-Haul with three tubes of silicone and a YouTube tutorial at 2x speed. It floats! It floats like a beautiful 26-foot duck.", "good", "splash", "river")
  } else {
    var lost = []
    var lose = function(id, name, frac) {
      var n = Math.floor(g[id] * frac)
      if (n > 0) { g[id] -= n; lost.push(n + " " + name) }
    }
    lose("snacks", "lbs of snacks", 0.2 + rand(g) * 0.3)
    lose("gas", "gallons of gas (don't ask)", 0.1 + rand(g) * 0.2)
    lose("sunscreen", "sunscreen", 0.3)
    if (chance(g, 0.5)) lose("tires", "spare tire", 0.5)
    lost.push(pick(g, ["Brayden's AirPods", "the air fryer", "a box labeled MISC CABLES", "the Peloton (good riddance)", "your diploma"]))
    var text = (choice === "ford" ? "The Yoo-Haul tips at the deep part. " : "Your caulk job springs a leak halfway across. ") + "You lost: " + lost.join(", ") + "."
    var drown = alive(g).filter(function(m, i) { return i > 0 })
    if (p.depth > 4 && drown.length && chance(g, choice === "ford" ? 0.25 : 0.1)) {
      var victim = pick(g, drown)
      text += " " + victim.name + " was swept downstream while trying to film it."
      kill(g, victim, "drowning (while vlogging)")
    }
    g.vibes = clamp(g.vibes - 10, 0, 100)
    say(g, "Splash!", text, "bad", "splash", "river")
  }
  finishRiver(g)
  return true
}

function finishRiver(g) {
  // You are now on the far bank: nudge past the river so travel resumes.
  g.miles += 1
  g.at = -1
  g.stopped = true
}

// ----------------------------------------------------------------- deaths --

function kill(g, m, cause) {
  if (!m.alive) return
  m.alive = false
  m.hp = 0
  m.cause = cause
  m.sick = null
  say(g, "Rest in Peace", m.name + " has died of " + cause + ".", "bad", "death", "grave")
  if (m === leader(g)) {
    g.deathCause = cause
    gameOver(g)
    return
  }
  g.pendingGraves = (g.pendingGraves || []).concat([{ name: m.name, cause: cause }])
  settle(g)
}

// Deaths that happen while another prompt is up wait their turn for an
// epitaph. Every action ends here so none is ever skipped.
function settle(g) {
  if (!g || g.prompt || g.finished && !g.won) return g
  if (g.pendingGraves && g.pendingGraves.length) {
    var next = g.pendingGraves.shift()
    g.prompt = { type: "epitaph", name: next.name, cause: next.cause, suggestion: pick(g, EPITAPHS) }
  }
  return g
}

function setEpitaph(g, text) {
  var p = g.prompt
  if (!p || p.type !== "epitaph") return false
  var t = String(text || "").trim().slice(0, 60) || p.suggestion
  g.graves.push({ name: p.name, cause: p.cause, epitaph: t, mile: Math.round(g.miles), year: g.year })
  g.prompt = null
  settle(g)
  checkEnd(g)
  return true
}

function checkEnd(g) {
  if (g.finished) return
  if (!alive(g).length || !leader(g).alive) gameOver(g)
}

function gameOver(g) {
  if (g.finished) return
  g.finished = true
  g.won = false
  g.stopped = true
  // nobody is left to cross the river or write the epitaphs
  g.prompt = null
  g.pendingGraves = []
  g.score = 0
  g.rating = "Deceased"
}

// ------------------------------------------------------------------ score --

function scoreBreakdown(g) {
  var rows = []
  var a = alive(g)
  var hpPts = 0
  for (var i = 0; i < a.length; i++) {
    var l = healthLabel(a[i].hp)
    hpPts += l === "Good" ? 500 : l === "Fair" ? 400 : l === "Poor" ? 300 : 200
  }
  rows.push({ label: a.length + " survivor" + (a.length === 1 ? "" : "s") + " (by health)", pts: hpPts })
  rows.push({ label: "Cash left (" + formatMoney(g.cash) + ")", pts: Math.max(0, Math.floor(g.cash / 5)) })
  rows.push({ label: "Gas (" + Math.floor(g.gas) + " gal)", pts: Math.floor(g.gas) })
  rows.push({ label: "Snacks (" + g.snacks + " lbs)", pts: Math.floor(g.snacks / 25) })
  rows.push({ label: "Spare tires and parts", pts: (g.tires + g.parts) * 25 })
  rows.push({ label: "Twang (" + g.twang + "%)", pts: g.twang * 10 })
  rows.push({ label: "Vibes (" + vibesLabel(g.vibes) + ")", pts: g.vibes * 5 })
  var sum = 0
  for (var r = 0; r < rows.length; r++) sum += rows[r].pts
  var occ = occupation(g)
  return { rows: rows, subtotal: sum, mult: occ.mult, occupation: occ.name, total: Math.round(sum * occ.mult) }
}

function ratingFor(score) {
  for (var i = 0; i < RATINGS.length; i++) if (score >= RATINGS[i].min) return RATINGS[i].title
  return RATINGS[RATINGS.length - 1].title
}

function arrive(g) {
  g.finished = true
  g.won = true
  g.stopped = true
  var b = scoreBreakdown(g)
  g.score = b.total
  g.rating = ratingFor(g.score)
}

// -------------------------------------------------------------- the days --

function passDay(g, opts) {
  opts = opts || {}
  g.day += 1
  g.stats.days += 1
  g.weather = rollWeather(g)
  var pace = paceOf(g)
  var rat = rationsOf(g)
  var party = alive(g)

  // food
  var need = party.length * rat.lbs
  var starving = false
  if (g.snacks >= need) g.snacks -= need
  else { starving = true; g.snacks = 0 }

  // sunscreen on scorching days
  var burned = false
  if (g.weather === "Scorching") {
    if (g.sunscreen > 0) g.sunscreen -= 1
    else burned = true
  }

  // crypto bro portfolio
  if (g.occupation === "crypto" && g.cash > 0) {
    var swing = (rand(g) - 0.47) * 0.2
    g.cash = Math.round(g.cash * (1 + swing))
  }

  // health
  for (var i = 0; i < party.length; i++) {
    var m = party[i]
    var d = -1 + rat.health
    if (!opts.resting) d += pace.health
    else d += 8
    if (starving) d -= 12
    if (burned) d -= 5
    if (g.weather === "Smoky" || g.weather === "Dust storm") d -= 2
    if (g.weather === "Snowy") d -= 1
    if (g.vibes < 20) d -= 2
    if (m.sick) {
      d -= opts.resting ? 2 : 6
      m.sickDays -= opts.resting ? 2 : 1
      if (m.sickDays <= 0) { m.sick = null; m.sickDays = 0 }
    }
    m.hp = clamp(m.hp + d, 0, 100)
  }

  // vibes drift
  var vd = opts.resting ? 3 : -1
  if (g.occupation === "influencer") vd += 1
  if (starving) vd -= 6
  if (g.pace === "grindset") vd -= 2
  if (g.rations === "brunch") vd += 1
  g.vibes = clamp(g.vibes + vd, 0, 100)

  // new illness
  for (var j = 0; j < party.length; j++) {
    var p = party[j]
    if (p.sick) continue
    var risk = 0.025 + (p.hp < 50 ? 0.04 : 0) + (g.rations === "fasting" ? 0.02 : 0) + (!opts.resting && g.pace === "grindset" ? 0.03 : 0) + (burned ? 0.03 : 0)
    if (opts.resting) risk *= 0.4
    if (chance(g, risk)) {
      var reg = regionOf(g)
      var options = AILMENTS.filter(function(a) { return a.where === "" || a.where.indexOf(reg) >= 0 })
      var a = pick(g, options)
      p.sick = a.text
      p.sickCause = a.cause
      p.sickDays = a.days
      say(g, "Uh oh", p.name + " " + a.text + ".", "bad", "bonk", "sick")
    }
  }

  if (starving && !opts.quiet) say(g, "Out of snacks", "You have no food. Somebody is eating ketchup packets. Somebody else is eating a candle that smells like a cookie. Buy, trade, or forage!", "bad", "bonk")
  if (burned && !opts.quiet) say(g, "Scorching", "It's " + rint(g, 109, 118) + "°F and you're out of sunscreen. Everyone is turning the color of a Tesla in Ultra Red.", "bad", "bonk")

  // deaths
  for (var k = 0; k < g.party.length; k++) {
    var q = g.party[k]
    if (q.alive && q.hp <= 0) {
      var cause = q.sickCause && q.sick ? q.sickCause : starving ? "starvation (snack-related)" : burned ? "sunstroke" : "exhaustion"
      kill(g, q, cause)
      if (g.finished) return
    }
  }
  checkEnd(g)
}

// One day on the road. Returns the miles driven.
function travelDay(g) {
  if (g.finished || g.stopped || g.prompt || g.queue.length) return 0
  g.at = -1
  var pace = paceOf(g)
  var miles = pace.miles + rint(g, -15, 15)
  if (g.weather === "Snowy") miles = Math.round(miles * 0.6)
  if (g.weather === "Dust storm") miles = Math.round(miles * 0.7)

  var nextIdx = nextLandmarkIndex(g)
  var next = nextIdx >= 0 ? LANDMARKS[nextIdx] : null
  var toNext = next ? next.mile - g.miles : 0
  var arriving = next && miles >= toNext
  if (arriving) miles = toNext

  // gas
  var gasNeed = miles / MPG
  var outOfGas = false
  if (g.gas < gasNeed) {
    miles = Math.floor(g.gas * MPG)
    g.gas = 0
    outOfGas = true
    arriving = next && miles >= toNext
  } else {
    g.gas = Math.round((g.gas - gasNeed) * 10) / 10
  }

  var startMiles = g.miles
  g.miles += miles
  passDay(g, { resting: false, miles: miles })
  if (g.finished) return miles

  if (outOfGas) {
    g.stopped = true
    rescueGas(g)
  }

  // graves from earlier trips
  graveCheck(g, startMiles, g.miles)

  // something happens on the way, even on days you reach a landmark
  if (!outOfGas && !g.finished && miles > 0 && !(next && next.mile >= TRIP_MILES && arriving)) randomEvent(g)
  if (g.finished) return miles

  if (arriving) {
    g.at = nextIdx
    g.stopped = true
    if (next.mile >= TRIP_MILES) {
      say(g, "AUSTIN, TX", next.text, "good", "fanfare", "landmark")
      arrive(g)
      return miles
    }
    if (next.mile === 1300) g.twang = clamp(g.twang + 15, 0, 100)
    say(g, next.name.toUpperCase(), next.text, "neutral", "arrive", "landmark")
    if (next.river) arriveAtRiver(g, next)
  }
  return miles
}

function rescueGas(g) {
  if (chance(g, 0.55)) {
    var gal = rint(g, 10, 20)
    g.gas += gal
    var helper = regionOf(g) === "tx" ? "A man in a lifted F-250 named Bubba" : pick(g, ["A trucker named Big Earl", "A retired couple in an RV called The Nest Egg", "A very quiet nun"])
    say(g, "Out of gas!", "The Yoo-Haul coughs and rolls to a stop. " + helper + " pulls over and gives you " + gal + " gallons for free. \"Pay it forward,\" they say. You will. Probably.", "good", "coin")
  } else {
    var lostDays = rint(g, 1, 2)
    for (var i = 0; i < lostDays && !g.finished; i++) passDay(g, { resting: false, miles: 0, quiet: true })
    var cost = Math.round(8 * gasPrice(g) * 2)
    var tail
    if (g.cash >= cost) { g.cash -= cost; g.gas += 8; tail = " and charges you double: " + formatMoney(cost) + " for 8 gallons." }
    else { g.gas += 4; tail = ". You're broke, so he gives you 4 gallons and a long look." }
    say(g, "Out of gas!", "You run out of gas in the middle of nowhere. Nobody stops for " + lostDays + (lostDays === 1 ? " day" : " days") + ". Someone films you for TikTok. Eventually a gas station attendant drives out a can" + tail, "bad", "bonk")
  }
}

function graveCheck(g, from, to) {
  var all = (g.knownGraves || []).concat(g.graves)
  for (var i = 0; i < all.length; i++) {
    var gr = all[i]
    var key = gr.name + "@" + gr.mile + "@" + gr.year
    if (gr.mile > from && gr.mile <= to && g.passedGraves.indexOf(key) === -1) {
      g.passedGraves.push(key)
      say(g, "A Grave", "You pass a tombstone by the road. It reads: \"Here lies " + gr.name + ". " + gr.epitaph + "\"", "neutral", "death", "grave")
      return
    }
  }
}

// ---------------------------------------------------------------- events --

function someone(g, exceptLeader) {
  var a = alive(g).filter(function(m, i) { return !exceptLeader || m !== leader(g) })
  if (!a.length) a = alive(g)
  return pick(g, a)
}

var EVENTS = [
  { w: 3, when: function(g) { return g.tires >= 0 }, run: function(g) {
      g.stats.flats++
      if (g.tires > 0) { g.tires--; return ["Flat tire!", "A tire blows out on a piece of rebar the size of a surfboard. You put on a spare. " + someone(g).name + " supervises from a lawn chair.", "bad", "pop"] }
      passDay(g, { resting: false, miles: 0, quiet: true })
      return ["Flat tire!", "A tire blows out and you have no spares. You lose a day limping to a tire shop where a man named Hector fixes it for cash and mild judgment.", "bad", "pop"]
  } },
  { w: 2, run: function(g) {
      if (g.parts > 0) { g.parts--; return ["Breakdown!", "The alternator dies. " + (g.occupation === "tech" ? "You fix it in twenty minutes and refer to it as \"a hotfix.\"" : "You swap it with a spare part and some YouTube.") , "bad", "clunk"] }
      var days = g.occupation === "tech" ? 1 : 2
      for (var i = 0; i < days && !g.finished; i++) passDay(g, { resting: false, miles: 0, quiet: true })
      return ["Breakdown!", "The alternator dies and you have no spare parts. You lose " + days + (days === 1 ? " day" : " days") + " waiting for a tow truck. The driver plays Smash Mouth the entire time.", "bad", "clunk"]
  } },
  { w: 2, when: function(g) { return regionOf(g) === "ca" }, run: function(g) {
      var t = Math.min(rint(g, 4, 9) * 100, Math.max(0, Math.floor(g.cash)))
      g.cash -= t
      if (t === 0) return ["Franchise Tax Board", "The California Franchise Tax Board sends a letter asking where you think you're going. You're broke, so they settle for a sternly worded follow-up letter.", "neutral", "bonk"]
      return ["Franchise Tax Board", "A letter arrives from the California Franchise Tax Board. They would like to know where you think you're going. You owe " + formatMoney(t) + " for \"the vibes.\"", "bad", "bonk"]
  } },
  { w: 2, when: function(g) { return regionOf(g) === "ca" }, run: function(g) {
      return ["Earthquake!", "A 4.6 magnitude earthquake. Nobody in your party even looks up from their phone. Native Californian behavior. One more for the road.", "neutral", "rumble"]
  } },
  { w: 2, when: function(g) { return regionOf(g) === "ca" }, run: function(g) {
      g.vibes = clamp(g.vibes - 5, 0, 100)
      return ["DMV Update", "The DMV finally emails you. Your appointment to update your address is available! It's in March 2029. Vibes -5.", "bad", "bonk"]
  } },
  { w: 2, when: function(g) { return regionOf(g) === "ca" }, run: function(g) {
      var n = someone(g)
      return ["Wildfire smoke", "The sky is orange. The sun is a red dot. " + n.name + " says it's \"actually kind of pretty\" and everyone glares at them.", "neutral", "rumble"]
  } },
  { w: 2, run: function(g) {
      for (var i = 0; i < 2 && !g.finished; i++) passDay(g, { resting: false, miles: 0, quiet: true })
      return ["Wrong turn", "You trusted the map app that shall not be named. It sent you down a dirt road to a llama farm. You lose 2 days. The llamas were nice though.", "bad", "bonk"]
  } },
  { w: 2, run: function(g) {
      var n = someone(g, true)
      n.hp = clamp(n.hp - 10, 1, 100)
      return ["Tumbleweed!", "A tumbleweed the size of a Prius smacks into the windshield. " + n.name + " screams for nine seconds straight.", "bad", "pop"]
  } },
  { w: 2, run: function(g) {
      var lbs = Math.min(g.snacks, rint(g, 15, 40))
      g.snacks -= lbs
      return ["Thief!", "A thief raids the Yoo-Haul overnight and takes " + lbs + " lbs of snacks. He leaves a thank-you note and a Venmo request for \"gas money.\"", "bad", "bonk"]
  } },
  { w: 2, run: function(g) {
      var gal = rint(g, 5, 15)
      g.gas += gal
      return ["Lucky find", "You find a full gas can by the road labeled DON'T TOUCH, CARL. You are not Carl. +" + gal + " gallons.", "good", "coin"]
  } },
  { w: 2, run: function(g) {
      g.vibes = clamp(g.vibes + 10, 0, 100)
      return ["Abandoned Peloton", "You find an abandoned Peloton on the side of the highway, still running a class. The instructor is very encouraging. Everyone feels seen. Vibes +10.", "good", "coin"]
  } },
  { w: 2, run: function(g) {
      var lbs = rint(g, 20, 45)
      g.snacks += lbs
      return ["Good tacos!", "You find a taco truck in a gas station parking lot. Best tacos of your entire life. You buy " + lbs + " lbs for the road and propose to the cook.", "good", "coin"]
  } },
  { w: 2, run: function(g) {
      g.vibes = clamp(g.vibes + 6, 0, 100)
      return ["Road trip playlist", "Somebody puts on Don't Stop Believin'. Everybody sings. Even the Yoo-Haul. Vibes +6.", "good", "fanfare"]
  } },
  { w: 2, when: function(g) { return g.occupation === "influencer" }, run: function(g) {
      var c = rint(g, 2, 7) * 100
      g.cash += c
      return ["Viral!", "Your \"day in my life leaving California\" TikTok goes viral. An air fryer brand pays you " + formatMoney(c) + " to say their name three times. You say it four.", "good", "coin"]
  } },
  { w: 2, when: function(g) { return g.occupation === "crypto" }, run: function(g) {
      if (chance(g, 0.5)) { var c = rint(g, 5, 15) * 100; g.cash += c; return ["$TEXIT is pumping", "Your memecoin $TEXIT goes up 400% because a celebrity posted a cowboy emoji. You cash out " + formatMoney(c) + ". WAGMI.", "good", "coin"] }
      var l = Math.min(Math.max(0, g.cash), rint(g, 5, 15) * 100)
      g.cash -= l
      return ["$TEXIT got rugged", "The developer of $TEXIT posts \"gm\" and vanishes. You lose " + formatMoney(l) + ". NGMI.", "bad", "bonk"]
  } },
  { w: 1, when: function(g) { return g.occupation === "writer" }, run: function(g) {
      g.cash += 250
      return ["Residuals!", "A residual check catches up with you: $250 for a 2009 episode of a medical drama where you wrote the line \"Stat!\"", "good", "coin"]
  } },
  { w: 2, when: function(g) { return regionOf(g) !== "ca" }, run: function(g) {
      var n = someone(g, true)
      n.sick = "was bitten by a rattlesnake"
      n.sickCause = "a rattlesnake bite"
      n.sickDays = 4
      n.hp = clamp(n.hp - 15, 1, 100)
      return ["Snake!", n.name + " tries to take a selfie with a rattlesnake. The rattlesnake did not consent.", "bad", "pop"]
  } },
  { w: 2, when: function(g) { return regionOf(g) === "az" || regionOf(g) === "nm" }, run: function(g) {
      passDay(g, { resting: false, miles: 0, quiet: true })
      return ["Haboob!", "A wall of dust a mile high rolls across the desert. You pull over and wait it out. The Yoo-Haul is now beige. Everything is beige. You lose a day.", "bad", "rumble"]
  } },
  { w: 2, when: function(g) { return regionOf(g) === "nm" }, run: function(g) {
      var n = someone(g, true)
      n.hp = clamp(n.hp + 10, 0, 100)
      g.vibes = clamp(g.vibes + 8, 0, 100)
      return ["Close encounter", "Lights in the sky near Roswell. " + n.name + " is beamed up for 20 minutes and returned with better posture and an improved credit score.", "good", "ufo"]
  } },
  { w: 2, when: function(g) { return g.miles > 600 }, run: function(g) {
      g.twang = clamp(g.twang + 8, 0, 100)
      return ["Assimilation", "A trucker named Big Earl teaches you to say \"y'all\" correctly. It's one syllable. You've been doing it wrong. Twang +8.", "good", "fanfare"]
  } },
  { w: 2, when: function(g) { return regionOf(g) === "tx" }, run: function(g) {
      g.vibes = clamp(g.vibes - 4, 0, 100)
      g.twang = clamp(g.twang + 4, 0, 100)
      return ["Bless your heart", "A sweet old lady at a gas station hears your plan to \"disrupt\" the local coffee scene and says \"well, bless your heart.\" You will be thinking about it for weeks.", "neutral", "blip"]
  } },
  { w: 2, when: function(g) { return regionOf(g) === "tx" }, run: function(g) {
      return ["Bumper sticker", "The truck in front of you has a sticker: DON'T CALIFORNIA MY TEXAS. You quietly cover your California plates with a cowboy hat. It does not help.", "neutral", "blip"]
  } },
  { w: 2, when: function(g) { return regionOf(g) === "tx" }, run: function(g) {
      g.vibes = clamp(g.vibes - 8, 0, 100)
      return ["Grid alert", "ERCOT issues a conservation alert. Every gas station has its lights off. You are, for one magical night, living off-grid. Vibes -8.", "bad", "rumble"]
  } },
  { w: 2, when: function(g) { return regionOf(g) === "tx" }, run: function(g) {
      var lbs = rint(g, 25, 50)
      g.snacks += lbs
      g.twang = clamp(g.twang + 5, 0, 100)
      return ["Church potluck", "A church in a tiny town invites you to their potluck. You leave with " + lbs + " lbs of casserole, three invitations to Bible study, and a recipe for sheet cake.", "good", "coin"]
  } },
  { w: 1, when: function(g) { return regionOf(g) === "tx" }, run: function(g) {
      var lost = Math.min(g.sunscreen, 2)
      g.sunscreen -= lost
      return ["Hail!", "Hailstones the size of golf balls. Then the sun comes out. Then a light drizzle. Then more sun. Texas weather has the attention span of a toddler. " + (lost ? "You lost " + lost + " bottles of sunscreen somehow." : ""), "bad", "rumble"]
  } },
  { w: 2, run: function(g) {
      g.vibes = clamp(g.vibes - 6, 0, 100)
      return ["Zoom call", "Your old manager schedules a \"quick sync\" while you're driving. It is 90 minutes. It could have been an email. Vibes -6.", "bad", "bonk"]
  } },
  { w: 2, run: function(g) {
      g.vibes = clamp(g.vibes - 4, 0, 100)
      return ["Landlord text", "Your old landlord texts: \"Hey, the security deposit... so about that.\" You'll never see that $4,000 again. You knew. Vibes -4.", "bad", "bonk"]
  } },
  { w: 1, run: function(g) {
      var n = someone(g)
      return ["Self-driving car", "A driverless car follows you for 40 miles. It has nobody inside. It seems lonely. " + n.name + " names it Kevin.", "neutral", "ufo"]
  } },
  { w: 1, run: function(g) {
      var a = alive(g)
      for (var i = 0; i < a.length; i++) a[i].hp = clamp(a[i].hp + 8, 0, 100)
      return ["Hot springs", "You find a roadside hot spring with nobody in it. Everybody soaks. It's the best day of the trip. Health up all around.", "good", "rest"]
  } },
  { w: 1, run: function(g) {
      if (g.tires > 0 && g.parts > 0) { g.parts--; return ["Overheating", "The Yoo-Haul starts steaming like a pressure cooker. A spare part and a gallon of water later, it's fine. Mostly.", "bad", "clunk"] }
      g.vibes = clamp(g.vibes - 5, 0, 100)
      return ["Overheating", "The Yoo-Haul overheats. You turn the heater on full blast to cool the engine. It's 110°F inside. Nobody speaks for an hour.", "bad", "clunk"]
  } }
]

function randomEvent(g) {
  if (!chance(g, 0.5)) return false
  var options = EVENTS.filter(function(e) { return !e.when || e.when(g) })
  var total = 0
  for (var i = 0; i < options.length; i++) total += options[i].w
  var roll = rand(g) * total
  var ev = options[options.length - 1]
  for (var j = 0; j < options.length; j++) { roll -= options[j].w; if (roll < 0) { ev = options[j]; break } }
  var out = ev.run(g)
  if (!out) return false
  g.stats.events++
  say(g, out[0], out[1], out[2], out[3])
  checkEnd(g)
  return true
}

// ------------------------------------------------------------- top ten ----

function sanitizeTopTen(list) {
  if (!Array.isArray(list) || !list.length) return DEFAULT_TOP_TEN.slice()
  var out = []
  for (var i = 0; i < list.length && out.length < 10; i++) {
    var e = list[i]
    if (e && typeof e.name === "string" && typeof e.score === "number" && isFinite(e.score))
      out.push({ name: e.name.slice(0, 40), score: Math.round(e.score), rating: String(e.rating || ratingFor(e.score)), mine: e.mine === true })
  }
  out.sort(function(a, b) { return b.score - a.score })
  return out.length ? out : DEFAULT_TOP_TEN.slice()
}

function recordScore(list, g) {
  g.scored = true
  if (!g.won) return -1
  var name = leader(g).name
  var entry = { name: name, score: g.score, rating: g.rating, mine: true }
  list.push(entry)
  list.sort(function(a, b) { return b.score - a.score })
  var rank = list.indexOf(entry)
  while (list.length > 10) list.pop()
  return rank < 10 ? rank : -1
}

function sanitizeGraves(list) {
  if (!Array.isArray(list)) return []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var gr = list[i]
    if (gr && typeof gr.name === "string" && typeof gr.mile === "number" && isFinite(gr.mile))
      out.push({ name: gr.name.slice(0, 18), cause: String(gr.cause || "").slice(0, 60), epitaph: String(gr.epitaph || "").slice(0, 60), mile: clamp(Math.round(gr.mile), 0, TRIP_MILES), year: Number(gr.year) || 2026 })
  }
  // only the most recent dozen haunt the trail
  return out.slice(Math.max(0, out.length - 12))
}

// ------------------------------------------------------------ validation --

function validate(g) {
  if (!g || typeof g !== "object") return "not an object"
  if (g.v !== 1) return "bad version"
  var nums = ["cash", "gas", "snacks", "sunscreen", "tires", "parts", "coupons", "miles", "day", "vibes", "twang", "rng", "hats"]
  for (var i = 0; i < nums.length; i++) if (typeof g[nums[i]] !== "number" || !isFinite(g[nums[i]])) return "bad " + nums[i]
  var nonneg = ["gas", "snacks", "sunscreen", "tires", "parts", "coupons", "miles", "day"]
  for (var j = 0; j < nonneg.length; j++) if (g[nonneg[j]] < 0) return "negative " + nonneg[j]
  if (g.vibes < 0 || g.vibes > 100) return "vibes out of range"
  if (g.twang < 0 || g.twang > 100) return "twang out of range"
  if (g.miles > TRIP_MILES + 1) return "past Austin"
  if (!Array.isArray(g.party) || g.party.length !== 5) return "bad party"
  for (var k = 0; k < g.party.length; k++) {
    var m = g.party[k]
    if (!m || typeof m.name !== "string" || typeof m.hp !== "number" || m.hp < 0 || m.hp > 100) return "bad member " + k
    if (!m.alive && m.hp !== 0) return "dead member with hp"
  }
  if (!Array.isArray(g.queue)) return "bad queue"
  if (g.prompt !== null && (typeof g.prompt !== "object" || typeof g.prompt.type !== "string")) return "bad prompt"
  if (!g.finished && !leader(g).alive && !g.prompt) return "leader dead but game on"
  if (g.finished && !g.won && g.prompt) return "prompt left open after game over"
  if (g.won && alive(g).length === 0) return "won with nobody"
  return ""
}

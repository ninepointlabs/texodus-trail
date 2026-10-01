// The Texodus Trail - website. Most of the words below are lifted straight
// from app/Game.js, so the site and the game tell the same jokes.
(function () {
  "use strict"

  var $ = function (s) { return document.querySelector(s) }
  var esc = function (s) { return String(s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c] }) }
  var money = function (n) { return (n < 0 ? "-$" : "$") + Math.abs(Math.round(n)).toLocaleString("en-US") }
  var pick = function (a) { return a[Math.floor(Math.random() * a.length)] }

  // ------------------------------------------------------------- ticker --
  var TICKER = [
    ["SF 1BR RENT", "$3,950/MO", "up"],
    ["GAS (CA)", "$6.89", "up"],
    ["GAS (TX)", "$2.79", "down"],
    ["$TEXIT", "-38% NGMI", "up"],
    ["NEAREST IN-N-OUT", "1,400 MI", "up"],
    ["AUSTIN 1BR RENT", "$2,400 (SOMEHOW)", "up"],
    ["STATE INCOME TAX (TX)", "$0.00", "down"],
    ["PROPERTY TAX (TX)", "DON'T ASK", "up"],
    ["ERCOT", "PLEASE UNPLUG SOMETHING", "up"],
    ["DMV APPOINTMENT", "MARCH 2029", "up"],
    ["BREAKFAST TACO", "$9", "up"],
    ["TRAFFIC ON I-35", "YES", "up"],
    ["YOO-HAUL RETURN FEE", "$612", "up"],
    ["VIBES", "MIXED", "down"],
    ["NEIGHBORS FROM PALO ALTO", "ALL OF THEM", "up"]
  ]
  var tick = TICKER.map(function (t) {
    return "<span>" + esc(t[0]) + " <b class='" + t[2] + "'>" + (t[2] === "up" ? "▲ " : "▼ ") + esc(t[1]) + "</b></span>"
  }).join("")
  $("#ticker").innerHTML = tick + tick

  // ----------------------------------------------------------- fighters --
  var TRUCK_COST = 4812
  var OCCUPATIONS = [
    { id: "tech", name: "Laid-off FAANG Engineer", cash: 12000, mult: 1, level: "Normal (emotionally: hard)",
      blurb: "Severance, a drawer full of conference hoodies, and RSUs that vested the morning after the layoff email. Fixes the alternator and calls it \"a hotfix.\"",
      pick: "Good choice. Update your LinkedIn to \"Open to Brisket.\"" },
    { id: "influencer", name: "Lifestyle Influencer", cash: 8000, mult: 2, level: "Easy-ish",
      blurb: "38,000 followers, eleven of them human. Vibes drop slower, and every disaster is content.",
      pick: "Day in my life: leaving California (gone wrong) (not clickbait)." },
    { id: "crypto", name: "Crypto Bro", cash: 15000, mult: 1.5, level: "Volatile",
      blurb: "Rich on paper. The paper is a memecoin called $TEXIT and it moves 10% a day in either direction. WAGMI.",
      pick: "gm. Your net worth changed twice while you read this." },
    { id: "writer", name: "Hollywood Screenwriter", cash: 6000, mult: 3, level: "Hard mode",
      blurb: "Your pilot about a dentist who solves crimes is \"in development.\" Broke, brave, triple points.",
      pick: "Bold. Your agent will call when you're out of signal range." }
  ]
  $("#fighters-grid").innerHTML = OCCUPATIONS.map(function (o, i) {
    return "<button class='fighter' type='button' aria-pressed='false' data-i='" + i + "'>" +
      "<span class='num'>" + (i + 1) + ".</span><h3>" + esc(o.name) + "</h3><p>" + esc(o.blurb) + "</p>" +
      "<dl><dt>Starting cash</dt><dd>" + money(o.cash) + "</dd>" +
      "<dt>After the Yoo-Haul</dt><dd>" + money(o.cash - TRUCK_COST) + "</dd>" +
      "<dt>Points</dt><dd>&times;" + o.mult + "</dd>" +
      "<dt>Difficulty</dt><dd>" + esc(o.level) + "</dd></dl>" +
      "<span class='pick'></span></button>"
  }).join("")
  document.querySelectorAll(".fighter").forEach(function (b) {
    b.addEventListener("click", function () {
      document.querySelectorAll(".fighter").forEach(function (o) { o.setAttribute("aria-pressed", "false"); o.querySelector(".pick").textContent = "" })
      b.setAttribute("aria-pressed", "true")
      b.querySelector(".pick").textContent = "▶ " + OCCUPATIONS[b.dataset.i].pick
    })
  })

  // -------------------------------------------------------------- route --
  var STATE_NAMES = { ca: "California", az: "Arizona", nm: "New Mexico", tx: "Texas" }
  var ROUTE = [
    [0, "ca", "San Francisco, CA", "The fog rolls in. Your landlord texts \"hey quick q\" for the last time. Behind you: a one-bedroom that rented for $3,950 and a sourdough starter you could not bring yourself to pack.", "Costco"],
    [280, "ca", "Bakersfield, CA", "Smells like cattle and crude oil. Still California, technically. Someone in a gas station parking lot is playing Buck Owens and it is, honestly, a bop."],
    [410, "ca", "Barstow, CA", "The last outpost. A sign says LAST IN-N-OUT FOR A VERY LONG TIME and people are weeping in the drive-thru.", "Store"],
    [555, "ca", "Colorado River (Needles)", "On the far bank: Arizona, where it is somehow even hotter and nobody does Daylight Saving Time.", "River"],
    [615, "az", "Kingman, AZ", "Route 66. Get your kicks. There is a neon sign shaped like a cowboy and it has seen things."],
    [760, "az", "Flagstaff, AZ", "Pine trees! Altitude! Possibly snow, which half your party has only seen at Tahoe on a work offsite.", "Store"],
    [820, "az", "Winslow, AZ", "Well, you're standin' on a corner in Winslow, Arizona. There is a flatbed Ford. Nobody is slowing down to take a look at you."],
    [1080, "nm", "Rio Grande (Albuquerque)", "The Rio Grande, which is less grande than advertised. A guy in a pork pie hat on the bridge is watching you very carefully.", "River"],
    [1085, "nm", "Albuquerque, NM", "Green chile on everything. The hot air balloons look like a screensaver. Should've taken that left turn here.", "Store"],
    [1260, "nm", "Tucumcari, NM", "TUCUMCARI TONITE! say two thousand motel signs, all lit, none with vacancies you would want."],
    [1300, "nm", "Texas State Line", "The sky gets bigger. The trucks get bigger. Your state income tax, for the first time in your adult life, is zero.", "Selfie"],
    [1375, "tx", "Amarillo, TX", "A free 72 oz steak (if you eat it in an hour). Across the road, a gas station the size of a regional airport. The beaver knows.", "Steak"],
    [1495, "tx", "Lubbock, TX", "Home of Buddy Holly. Cotton fields to the horizon and a wind that has opinions."],
    [1660, "tx", "Abilene, TX", "The feed store also sells phone chargers and fireworks. Freedom.", "Store"],
    [1880, "tx", "Austin, TX", "You made it. Rent is $2,400, the traffic is somehow worse, and your new neighbor is from Palo Alto. He hands you a kombucha. Welcome home.", "The end"]
  ]
  $("#route-list").innerHTML = ROUTE.map(function (r) {
    return "<li class='stop " + r[1] + (r[4] === "River" ? " river" : "") + "'>" +
      "<span class='mile'>" + r[0].toLocaleString("en-US") + "<br>mi</span><span class='dot' aria-hidden='true'></span>" +
      "<div><h3>" + esc(r[2]) + (r[4] ? "<span class='tag'>" + esc(r[4]) + "</span>" : "") + "</h3><p>" + esc(r[3]) + "</p></div></li>"
  }).join("")

  // ---------------------------------------------------------- obituary --
  var NAMES = ["Chad", "Skyler", "Brayden", "Aspen", "Kale", "Saffron", "Juniper", "Tanner", "Sage", "Bodhi", "Harper", "Kinsley", "Paisley", "Ryder", "Wren", "Jaxon", "Indigo", "Maverick", "Sequoia", "Blaise"]
  var CAUSES = [
    ["dysentery", ""], ["dysentery (gas station sushi)", ""], ["a sunburn of biblical proportions", "az nm tx"],
    ["In-N-Out withdrawal", "az nm tx"], ["heat exhaustion", "az nm tx"], ["a rattlesnake bite", "az nm tx"],
    ["doomscroller's thumb", ""], ["a broken heart (left their sourdough starter in Oakland)", "ca az"],
    ["Valley Fever", "ca az"], ["a self-diagnosed gluten exposure", ""], ["the meat sweats", "tx"],
    ["ERCOT-induced anxiety", "tx"], ["a mild case of nostalgia", ""], ["allergies to literally everything", "tx"],
    ["drowning (while vlogging)", "ca nm"]
  ]
  var EPITAPHS = [
    "Should have bought Bitcoin in 2011.", "Finally free of state income tax.", "Said \"hella\" until the very end.",
    "Gone to the great Whole Foods in the sky.", "Their Zillow alerts are finally off.", "Died doing what they loved: complaining about rent.",
    "Rent-controlled forever.", "This is fine.", "Be excellent to each other.", "Never got to try Whataburger.",
    "Their LinkedIn still says Open to Work.", "I'll be back. (They will not be back.)"
  ]
  var stateAt = function (m) { return m < 555 ? "ca" : m < 1080 ? "az" : m < 1300 ? "nm" : "tx" }
  var last = ""
  $("#bury").addEventListener("click", function () {
    var c, mile, st
    do {
      c = pick(CAUSES); mile = 20 + Math.floor(Math.random() * 1840); st = stateAt(mile)
    } while (c[1] && c[1].indexOf(st) < 0)
    var name
    do { name = pick(NAMES) } while (name === last)
    last = name
    $("#g-name").textContent = name
    $("#g-cause").textContent = "Died of " + c[0] + "."
    $("#g-epitaph").textContent = "“" + pick(EPITAPHS) + "”"
    $("#g-mile").textContent = "Mile " + mile.toLocaleString("en-US") + " · " + STATE_NAMES[st]
    var g = $("#grave")
    g.classList.remove("thud"); void g.offsetWidth; g.classList.add("thud")
  })

  // -------------------------------------------------------- calculator --
  var HELLA = ["Never", "Ironically", "Sometimes", "Hella often", "It's my whole personality"]
  // gas for 1,880 miles at 10 mpg, priced per state the way the game does it
  var GAS = Math.round((555 * 6.89 + 525 * 4.19 + 220 * 3.59 + 580 * 2.79) / 10)
  function calc() {
    var rent = +$("#rent").value, hella = +$("#hella").value
    var peloton = $("#peloton").checked, crypto = $("#crypto").checked, starter = $("#starter").checked
    $("#rent-out").textContent = money(rent)
    $("#hella-out").textContent = HELLA[hella]
    var saved = (rent - 2400) * 12
    var rows = [["Rent saved, year one", saved, saved >= 0 ? "pos" : "neg"]]
    var costs = [["Yoo-Haul, 26 ft", -TRUCK_COST], ["Return fee (you're never going back)", -612], ["Gas, 188 gal, cheaper every state", -GAS],
      ["A hat (do not call it a cowboy hat)", -40], ["Brisket, year one", -1200], ["Boots you'll wear twice", -280]]
    if (crypto) costs.push(["$TEXIT got rugged", -1337])
    if (hella >= 3) costs.push(["Twang lessons from Big Earl", -150 * hella])
    var total = saved
    costs.forEach(function (c) { rows.push([c[0], c[1], "neg"]); total += c[1] })
    var html = "<h4>YOO-HAUL OF FINANCE</h4><p class='rsub'>Daly City, CA → Austin, TX · 1,880 mi</p>"
    rows.forEach(function (r) { html += "<div class='row'><span>" + esc(r[0]) + "</span><span class='" + r[2] + "'>" + (r[1] > 0 ? "+" : "") + money(r[1]) + "</span></div>" })
    html += "<div class='row'><span>State income tax</span><span class='pos'>gone, baby</span></div>"
    if (peloton) html += "<div class='row'><span>Peloton, left on the shoulder of I-40</span><span class='pos'>priceless</span></div>"
    if (starter) html += "<div class='row'><span>Sourdough starter custody</span><span class='neg'>emotional</span></div>"
    html += "<div class='row'><span>Your new neighbor</span><span>from Palo Alto</span></div>"
    html += "<div class='row total'><span>Net, year one</span><span class='" + (total >= 0 ? "pos" : "neg") + "'>" + money(total) + "</span></div>"
    var verdict
    if (rent < 2400) verdict = "You'd pay MORE in Austin. Where do you live? Stay there. Tell no one."
    else if (total > 15000) verdict = "Move. Your neighbor will be from Palo Alto anyway."
    else if (total > 0) verdict = "Move, but buy the hat first."
    else if (rent > 2400) verdict = "The math says year two. The vibes say now."
    else verdict = "Stay. Or go anyway. Nobody on this trail did the math."
    if (hella === 4) verdict += " Also: you will say y'all wrong. It's one syllable."
    html += "<p class='verdict'>" + esc(verdict) + "</p>"
    $("#receipt").innerHTML = html
  }
  ;["rent", "hella", "peloton", "crypto", "starter"].forEach(function (id) { $("#" + id).addEventListener("input", calc) })
  calc()

  // ------------------------------------------------------------ top ten --
  var TOP_TEN = [
    ["A Podcaster You've Heard Of", 7650, "Certified Texan (bless your heart)"],
    ["Some Guy From Palo Alto", 5200, "Honorary Texan"],
    ["Your Old Roommate", 4410, "Honorary Texan"],
    ["The Kombucha Guy", 3600, "Honorary Texan"],
    ["A Very Large Cybertruck", 2900, "Transplant"],
    ["Three Raccoons in a Trenchcoat", 2400, "Transplant"],
    ["Your Former Landlord", 1900, "Transplant"],
    ["Doc Brown (wrong year)", 1500, "Tourist with a Yoo-Haul"],
    ["Ferris (day off)", 1100, "Tourist with a Yoo-Haul"],
    ["A Lost Tesla on Autopilot", 600, "Still Says \"Hella\""]
  ]
  $("#topten tbody").innerHTML = TOP_TEN.map(function (r, i) {
    return "<tr><td>" + (i + 1) + "</td><td>" + esc(r[0]) + "</td><td>" + r[1].toLocaleString("en-US") + "</td><td>" + esc(r[2]) + "</td></tr>"
  }).join("") + "<tr class='you'><td>11</td><td>You (still in Barstow)</td><td>0</td><td>Still Says \"Hella\"</td></tr>"

  // -------------------------------------------------------------- copy --
  document.querySelectorAll(".copy").forEach(function (b) {
    b.addEventListener("click", function () {
      var done = function () { b.textContent = "Copied!"; setTimeout(function () { b.textContent = "Copy" }, 1600) }
      if (navigator.clipboard) navigator.clipboard.writeText(b.dataset.copy).then(done, function () { b.textContent = "Select it" })
    })
  })

  // ------------------------------------------------------------- toasts --
  var toastTimer
  function toast(msg) {
    var t = $("#toast")
    t.textContent = msg
    t.classList.add("show")
    clearTimeout(toastTimer)
    toastTimer = setTimeout(function () { t.classList.remove("show") }, 3200)
  }
  function hats() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    for (var i = 0; i < 18; i++) {
      var h = document.createElement("img")
      h.src = "art/hat.svg"; h.alt = ""; h.className = "hat-rain"
      h.style.left = Math.random() * 96 + "vw"
      h.style.animationDuration = 2.2 + Math.random() * 2 + "s"
      h.style.animationDelay = Math.random() * .8 + "s"
      document.body.appendChild(h)
      setTimeout(function (el) { el.remove() }.bind(null, h), 5200)
    }
  }

  // Easter eggs: type a word anywhere that isn't a form field.
  var EGGS = {
    yall: function () { toast("Big Earl teaches you to say \"y'all\" correctly. It's one syllable. Twang +8."); hats() },
    hella: function () { toast("You said \"hella.\" Somewhere in Texas, a sweet old lady says \"bless your heart.\"") },
    texit: function () { toast(Math.random() < .5 ? "$TEXIT is pumping. A celebrity posted a cowboy emoji. +400%." : "The developer of $TEXIT posted \"gm\" and vanished. NGMI.") },
    ercot: function () { toast("ERCOT issues a conservation alert. This website is now running on vibes."); document.body.style.filter = "brightness(.55)"; setTimeout(function () { document.body.style.filter = "" }, 2500) },
    kale: function () { toast("Here lies Kale. Should have bought Bitcoin in 2011.") },
    bucees: function () { toast("We have 120 gas pumps and the cleanest bathrooms in human history. Stay a while. Stay forever.") }
  }
  var typed = ""
  document.addEventListener("keydown", function (e) {
    if (e.target.closest("input, textarea, select") || e.ctrlKey || e.metaKey || e.altKey) return
    if (e.key.length !== 1) return
    typed = (typed + e.key.toLowerCase()).replace(/[^a-z]/g, "").slice(-12)
    for (var k in EGGS) if (typed.slice(-k.length) === k) { typed = ""; EGGS[k]() }
  })

  // A trailer gag for the people who scroll past it.
  var video = $("#trailer-video"), warned = false
  if (video && "IntersectionObserver" in window) {
    new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (!e.isIntersecting && !warned && video.currentTime > 0 && !video.ended && !video.paused) {
          warned = true
          toast("You left the trailer running. Like the AC in your old apartment.")
        }
      })
    }, { threshold: 0.1 }).observe(video)
  }
})()

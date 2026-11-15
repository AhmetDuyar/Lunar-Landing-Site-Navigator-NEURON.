# Start view: the red thread. What the challenge asks, the three questions
# NEURON answers, where in the app each requirement is met, and a short glossary.

overviewUI <- function(mission) {
  rb <- mission$analysis$robust
  step <- function(n, view, title, q, ic, body, cta) tags$button(type = "button", class = "ov-step", `data-go` = view,
    div(class = "ov-step-n", n), ic, div(class = "ov-step-q", paste("Step", n, "·", q)), h3(title), p(body), span(class = "ov-step-cta", cta, HTML(" &rarr;")))
  req <- function(asks, how, view, where, status = "ok") tags$tr(
    tags$td(class = "ov-asks", asks),
    tags$td(class = "ov-how", how),
    tags$td(class = "ov-where", tags$button(type = "button", class = "ov-link", `data-go` = view, where)),
    tags$td(class = "ov-status", span(class = paste("ov-dot", status), if (status == "ok") "Done" else "Partly")))
  term <- function(t, d) div(class = "ov-term", strong(t), span(d))

  stat <- function(v, l) div(class = "ov-stat", span(class = "ov-stat-v", v), span(class = "ov-stat-l", l))
  icon <- function(k) HTML(switch(k,
    where = '<svg class="ov-ic" viewBox="0 0 40 40"><circle cx="20" cy="20" r="15"/><circle cx="20" cy="20" r="9"/><path d="M20 3v6M20 31v6M3 20h6M31 20h6"/><circle class="o" cx="24" cy="16" r="3"/></svg>',
    when  = '<svg class="ov-ic" viewBox="0 0 40 40"><path d="M3 27h34"/><path d="M8 27a12 12 0 0 1 24 0"/><circle class="o" cx="27" cy="18" r="3.4"/><path d="M8 33h6M17 33h6M26 33h6"/></svg>',
    sure  = '<svg class="ov-ic" viewBox="0 0 40 40"><path d="M20 4l13 5v9c0 9-6 15-13 18C13 33 7 27 7 18V9z"/><path class="o" d="M13.5 19.5l4.5 4.5 8.5-9"/></svg>'))

  div(class = "ov",
    div(class = "ov-hero",
      div(class = "ov-hero-text",
        div(class = "ov-kicker", "NASA Space Apps Challenge 2026 · Lunar south pole"),
        h1(HTML("Pick a landing site near the lunar south pole, and a date, <span class=\"ov-hl\">in minutes.</span>")),
        p(class = "ov-lead", "At the south pole the Sun never climbs more than about 1.5° above the horizon and Earth hangs low at the edge of the sky. A crater rim can mean months of power; a few kilometres away, permanent shadow. NEURON turns NASA ephemeris and LOLA terrain data into three plain answers."),
        div(class = "ov-cta",
          tags$button(type = "button", class = "ov-btn", `data-go` = "analysis", HTML("Open the map &rarr;")),
          tags$a(class = "ov-btn ghost", href = "#ov-req", "How it meets the challenge")),
        div(class = "ov-stats",
          stat(nrow(mission$sites), "candidate sites"),
          stat(nrow(mission$landings), "landings mapped"),
          stat(format(rb$regions$scenarios, big.mark = ","), "what-if scenarios"),
          stat("7", "independent checks"))),
      hero_stage(mission)),

    div(class = "ov-steps-wrap",
      div(class = "ov-steps",
        step("1", "analysis", "Where can we land?", "Where", icon("where"),
             "A map of the south pole coloured by a landing score: flat ground, long-term sunlight and Earth visibility with real LOLA terrain. Click any pin for its full dossier.", "Open the map"),
        step("2", "compare", "When can we land?", "When", icon("when"),
             "Hour-by-hour Sun and Earth windows for every site and date, how long until sunset and Earthset, and what changes if the launch slips by a month.", "Compare sites and dates"),
        step("3", "story", "How sure are we?", "How sure", icon("sure"),
             sprintf("Seven independent checks, including NASA's own light maps and the spot where IM-1 tipped over, and %s what-if scenarios for the weights and slope limit.", format(rb$regions$scenarios, big.mark = ",")), "See the evidence"))),

    div(class = "ov-sec", id = "ov-req",
      h2("How NEURON answers the challenge"),
      p(class = "ov-sub", "Each objective from the challenge statement, what NEURON does for it, and where to find it."),
      tags$table(class = "ov-table",
        tags$thead(tags$tr(tags$th("The challenge asks for"), tags$th("NEURON"), tags$th("Where"), tags$th(""))),
        tags$tbody(
          req("Curated landing sites and custom coordinates", sprintf("5 published south-pole candidates, all %d previous and planned landings (Apollo, Luna, Chang'e, Chandrayaan, SLIM, CLPS) and any point you click.", nrow(mission$landings)), "analysis", "1 · Where"),
          req("Side-by-side comparison of sites", "Every site as an hour-by-hour bar for the same window, sorted by time with both Sun and Earth up, plus the score table.", "compare", "2 · When"),
          req("Date and time flexibility", "Any start date 2026 to 2030, windows of 7, 14 or 29.5 days, one-click steps of one lunar month, and one site across 12 lunar months.", "compare", "2 · When"),
          req("Sun and Earth position relative to the horizon", "Elevation and azimuth of Sun and Earth, hour by hour, with a time slider and animation.", "analysis", "1 · Where, right panel"),
          req("Time remaining before sunset and Earthset", "Live countdown at the slider time, and for every site from the window start.", "compare", "2 · When"),
          req("Power and communication metrics", "Solar elevation, share of time with Sun, with Earth and with both, longest night, longest radio blackout, best landing window.", "compare", "2 · When"),
          req("Multiple visualisations and temporal dynamics", "3D globe and polar map, colour layers, 12.8 km terrain windows per site, time strips and an animated timeline.", "analysis", "1 · Where"),
          req("Real topography and librations", "JPL DE421 with librations (checked to 0.004°); LOLA 80 m slope; a real 360° skyline from the LOLA elevation model for every point, exact for sites and landings and from a small neural network elsewhere.", "story", "3 · How sure"),
          req("Useful for planners, educators and the public", "Plain-language dossiers, this overview and an illustrated validation story; every number traceable to its source.", "methods", "Sources"))),
      p(class = "ov-note", "The Moon has no atmosphere, so there is no refraction: a body is visible when it is above the local horizon.")),

    div(class = "ov-sec ov-two",
      div(
        h2("What the words mean"),
        div(class = "ov-terms",
          term("Landing score (0 to 100)", "Weighted mean of flat ground, long-term sunlight and Earth visibility. Higher is better. Absolute, so adding a site never changes another."),
          term("Flat ground", "Share of the ground within 1 km below the slope limit (8° by default). Landers tip over on steep ground."),
          term("Long-term sunlight / Earth in view", "Average over 18.6 years with real mountains blocking the view (Mazarico et al. 2011)."),
          term("Mission window", "The days you plan to be on the surface. Its Sun and Earth values come from JPL DE421 and the real LOLA skyline, and tell you when, not where."),
          term("Both up", "Hours with the Sun above the horizon and Earth in view at the same time: power and a direct radio link."),
          term("Longest night / blackout", "Longest continuous stretch without Sun, or without Earth, in the window."),
          term("Skyline (horizon)", "The real edge of the sky seen from a place, set by mountains and crater rims up to 150 km away. Computed from the LOLA elevation model; the Sun counts as up only above it."),
          term("Dossier", "One page per site: why it scores what it scores, the ground around it, light over the year, nearby landings."))),
      div(
        h2("Start in 30 seconds"),
        tags$ol(class = "ov-quick",
          tags$li(strong("Open the map "), "and click the pin ", em("Mons Mouton"), ". Read its dossier: the best published site, and where IM-2 landed."),
          tags$li(strong("Go to When "), "and press ", em("one lunar month →"), " a few times. Watch which sites keep both Sun and Earth."),
          tags$li(strong("Open How sure "), "and scroll to check 6: what our data say where IM-1 tipped over.")),
        h2(class = "ov-h2b", "Data, all from NASA"),
        div(class = "ov-chips",
          span("JPL DE421 ephemeris"), span("LOLA 80 m terrain"), span("Mazarico et al. 2011 light maps"), span("USGS Artemis regions 2024"), span("NASA NSSDCA lander table")),
        tags$button(type = "button", class = "ov-link", `data-go` = "methods", HTML("Every source, file and script &rarr;")))),

    div(class = "ov-end",
      div(class = "ov-end-moon", role = "presentation"),
      div(class = "ov-end-text",
        div(class = "ov-end-k", "Ready for descent"),
        h2("Start with the map. Every number has a source."),
        p("Pick a site, check its window, then see how far the result holds up."),
        div(class = "ov-cta",
          tags$button(type = "button", class = "ov-btn", `data-go` = "analysis", HTML("1 · Where can we land? &rarr;")),
          tags$button(type = "button", class = "ov-btn ghost dark", `data-go` = "story", "3 · How sure are we?")))))
}


# Hero illustration: the Moon seen from 66° S with the Sun grazing the pole
# (data-raw/build_hero.py), and a loupe on the LOLA hillshade 80-90° S with the
# five published sites and the landings near the pole. All positions come from
# data/processed/hero_pins.json, i.e. from the real coordinates.
hero_stage <- function(mission, file = file.path("data", "processed", "hero_pins.json")) {
  if (!file.exists(file)) return(div(class = "ov-stage"))
  hp <- jsonlite::fromJSON(file, simplifyDataFrame = TRUE)
  pins <- hp$pins
  f <- function(x) sprintf("%.1f", x)
  # globe: image box (20,30) size 360, rotated -14° about its centre
  GX <- 20; GY <- 30; GS <- 360; GC <- c(200, 210); TH <- -14 * pi / 180
  gpt <- function(u, v) {
    x <- GX + u * GS - GC[1]; y <- GY + v * GS - GC[2]
    c(GC[1] + x * cos(TH) - y * sin(TH), GC[2] + x * sin(TH) + y * cos(TH))
  }
  # loupe: centre (452,402), radius 140
  LC <- c(452, 410); LR <- 150
  lpt <- function(u, v) c(LC[1] - LR + u * 2 * LR, LC[2] - LR + v * 2 * LR)
  P <- gpt(hp$pole$u, hp$pole$v)
  d <- sqrt(sum((P - LC)^2)); a <- atan2(P[2] - LC[2], P[1] - LC[1]); b <- acos(LR / d)
  t1 <- LC + LR * c(cos(a + b), sin(a + b)); t2 <- LC + LR * c(cos(a - b), sin(a - b))
  # orbit of the Sun as seen from the Moon (illustrative), same tilt as the globe
  sun <- c(GC[1] - 236 * cos(TH), GC[2] - 236 * sin(TH))

  lab <- list(
    CR = c(9, 4, "start", "Connecting Ridge"), HW = c(8, -6, "start", "Haworth"),
    NR1 = c(0, 21, "middle", "Nobile Rim 1"), NR2 = c(-8, 4, "end", "Nobile Rim 2"),
    MM = c(-8, -8, "end", "Mons Mouton · IM-2"),
    change7 = c(-9, 13, "end", "Chang'e 7, planned"), im1 = c(9, 10, "start", "IM-1, tipped over"))
  lp <- pins[!is.na(pins$lu) & pins$id != "im2", ]
  loupe_marks <- vapply(seq_len(nrow(lp)), function(i) {
    p <- lp[i, ]; xy <- lpt(p$lu, p$lv); L <- lab[[p$id]]
    mark <- if (p$kind == "site") sprintf('<circle class="hs-site" cx="%s" cy="%s" r="5.2"/>', f(xy[1]), f(xy[2]))
            else if (p$id == "change7") sprintf('<circle class="hs-plan" cx="%s" cy="%s" r="5.5"/>', f(xy[1]), f(xy[2]))
            else sprintf('<rect class="hs-land" x="%s" y="%s" width="7" height="7" transform="rotate(45 %s %s)"/>', f(xy[1] - 3.5), f(xy[2] - 3.5), f(xy[1]), f(xy[2]))
    txt <- if (is.null(L)) "" else sprintf('<text class="hs-lab%s" x="%s" y="%s" text-anchor="%s">%s</text>',
      if (p$kind == "site") " s" else "", f(xy[1] + as.numeric(L[1])), f(xy[2] + as.numeric(L[2])), L[3], htmltools::htmlEscape(L[4]))
    paste0(mark, txt)
  }, "")
  gl <- pins[pins$kind == "landing" & is.na(pins$lu) & pins$visible, ]
  globe_marks <- vapply(seq_len(nrow(gl)), function(i) {
    xy <- gpt(gl$u[i], gl$v[i])
    sprintf('<rect class="hs-land w" x="%s" y="%s" width="6" height="6" transform="rotate(45 %s %s)"/>', f(xy[1] - 3), f(xy[2] - 3), f(xy[1]), f(xy[2]))
  }, "")
  ch3 <- gl[gl$id == "ch3", ]
  ch3xy <- if (nrow(ch3)) gpt(ch3$u, ch3$v) else NULL

  svg <- paste0(
    '<svg class="hs" viewBox="-70 0 720 600" role="img" aria-label="The Moon seen from 66 degrees south, lit by a Sun grazing the south pole, with a magnified LOLA terrain view of the five candidate sites and nearby landings">',
    '<defs><clipPath id="hs-lc"><circle cx="', LC[1], '" cy="', LC[2], '" r="', LR, '"/></clipPath>',
    '<radialGradient id="hs-sun"><stop offset="0" stop-color="#f26a1b" stop-opacity=".55"/><stop offset="1" stop-color="#f26a1b" stop-opacity="0"/></radialGradient>',
    '<radialGradient id="hs-ls"><stop offset=".78" stop-color="#141414" stop-opacity=".16"/><stop offset="1" stop-color="#141414" stop-opacity="0"/></radialGradient><radialGradient id="hs-halo"><stop offset=".86" stop-color="#141414" stop-opacity=".10"/><stop offset="1" stop-color="#141414" stop-opacity="0"/></radialGradient></defs>',
    # latitude rings behind everything
    '<g class="hs-rings">', paste0(sprintf('<circle cx="200" cy="210" r="%d"/>', c(214, 250, 290)), collapse = ""), '</g>',
    sprintf('<ellipse class="hs-orbit" cx="200" cy="210" rx="236" ry="62" transform="rotate(-14 200 210)"/>'),
    sprintf('<g class="hs-sun"><circle cx="%s" cy="%s" r="30" fill="url(#hs-sun)"/><circle cx="%s" cy="%s" r="8"/></g>', f(sun[1]), f(sun[2]), f(sun[1]), f(sun[2])),
    sprintf('<text class="hs-cap" x="%s" y="%s">SUN</text>', f(sun[1] - 12), f(sun[2] + 26)),
    '<circle cx="200" cy="216" r="196" fill="url(#hs-halo)"/>',
    sprintf('<g transform="rotate(-14 200 210)"><image href="assets/hero_moon.webp" x="%d" y="%d" width="%d" height="%d"/></g>', GX, GY, GS, GS),
    paste(globe_marks, collapse = ""),
    if (!is.null(ch3xy)) sprintf('<text class="hs-lab w" x="%s" y="%s" text-anchor="start">Chandrayaan-2 and 3</text>', f(ch3xy[1] + 8), f(ch3xy[2] + 4)) else "",
    # connector pole -> loupe
    sprintf('<path class="hs-conn" d="M%s %sL%s %sM%s %sL%s %s"/>', f(P[1]), f(P[2]), f(t1[1]), f(t1[2]), f(P[1]), f(P[2]), f(t2[1]), f(t2[2])),
    sprintf('<circle class="hs-pole-pulse" cx="%s" cy="%s" r="9"/><circle class="hs-pole" cx="%s" cy="%s" r="9"/>', f(P[1]), f(P[2]), f(P[1]), f(P[2])),
    sprintf('<text class="hs-lab w" x="%s" y="%s" text-anchor="end">90° S</text>', f(P[1] - 14), f(P[2] + 4)),
    # loupe
    sprintf('<circle cx="%s" cy="%s" r="%s" fill="url(#hs-ls)"/><circle cx="%s" cy="%s" r="%s" fill="#fff"/>', LC[1], LC[2] + 12, LR + 30, LC[1], LC[2], LR + 7),
    sprintf('<image href="assets/hero_loupe.webp" x="%d" y="%d" width="%d" height="%d" clip-path="url(#hs-lc)"/>', LC[1] - LR, LC[2] - LR, 2 * LR, 2 * LR),
    sprintf('<circle class="hs-lring" cx="%s" cy="%s" r="%s"/>', LC[1], LC[2], LR),
    paste(loupe_marks, collapse = ""),
    sprintf('<text class="hs-cap" x="%s" y="%s" text-anchor="middle">LOLA TERRAIN · 80° TO 90° S</text>', LC[1], LC[2] + LR + 22),
    '</svg>')
  div(class = "ov-stage", HTML(svg),
    div(class = "ov-stage-note", span(class = "k site"), "published candidate site", span(class = "k land"), "previous landing",
        span(class = "k plan"), "planned"))
}

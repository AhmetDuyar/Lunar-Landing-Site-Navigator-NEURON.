# NEURON. Lunar Navigator: south-pole landing-site analysis
# Run from this directory: shiny::runApp(".")
library(shiny)

source("data/interfaces.R", local = TRUE)
for (f in c("overview.R", "ui_helpers.R", "explain.R", "help.R", "evidence.R", "dossier.R", "story.R", "compare.R", "mod_controls.R", "mod_globe.R", "mod_panels.R",
            "mod_timeline.R", "mod_methods.R")) source(file.path("R", f), local = TRUE)

mission <- load_mission_data("data")
v <- mission$validation
has_terrain <- !is.null(mission$terrain)
has_illum <- has_terrain && !is.null(mission$terrain$illum)
has_ml <- !is.null(mission$ml)
has_regions <- !is.null(mission$regions)

asset_v <- function(f) sprintf("%s?v=%s", f, format(file.mtime(file.path("www", f)), "%Y%m%d%H%M%S"))

ui <- fluidPage(
  title = "NEURON. Lunar Navigator",
  tags$head(
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$link(rel = "icon", href = "data:,"),
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"),
    # ?v=<file time> forces browsers (and Posit Cloud proxies) to load the current files
    tags$link(rel = "stylesheet", href = asset_v("style.css")),
    tags$script(type = "module", src = asset_v("script.js")),
    tags$script(src = asset_v("dossier.js")),
    tags$script(src = asset_v("story.js"))),

  div(class = "app",
    globeUI("globe"),

    # ---- top bar ---------------------------------------------------------
    div(class = "card brand-card",
      div(class = "brand-name", "NEURON", span(".")),
      div(class = "brand-divider"),
      div(class = "brand-title", "Lunar Navigator"),
      div(class = "brand-sub", "Comparing landing areas by terrain, illumination and Earth visibility")),
    tags$nav(class = "card seg", role = "tablist",
      tags$button(type = "button", class = "view-btn is-active", `data-view` = "start", "Start"),
      tags$button(type = "button", class = "view-btn", `data-view` = "analysis", span(class = "vn", "1"), "Where"),
      tags$button(type = "button", class = "view-btn", `data-view` = "compare", span(class = "vn", "2"), "When"),
      tags$button(type = "button", class = "view-btn", `data-view` = "story", span(class = "vn", "3"), "How sure"),
      tags$button(type = "button", class = "view-btn", `data-view` = "methods", "Sources")),
    div(class = "ctx-bar",
      span(class = "ctx-step", "1 · Where"),
      span("The map colours the south pole by landing score (green = good). Click a pin for its dossier, or anywhere to test your own point. Drag to rotate, scroll to zoom."),
      tags$button(type = "button", class = "ov-link", `data-go` = "compare", HTML("Next: 2 · When &rarr;"))),

    # ---- left column -----------------------------------------------------
    div(class = "col col-left",
      div(class = "card card-controls", controlsUI("controls", has_terrain, has_illum, has_ml, has_regions)),
      div(class = "card card-legend",
        div(class = "legend-title", textOutput("legend_title", inline = TRUE)),
        div(class = "ramp"), div(class = "ramp-ticks", span("0 % · low"), span("50"), span("high · 100 %")),
        p(class = "legend-note", textOutput("legend_note", inline = TRUE)),
        div(class = "scale", div(class = "scale-bar", id = "scale-bar"), span(id = "scale-label", "")))),

    # ---- right column ----------------------------------------------------
    div(class = "col col-right",
      div(class = "card card-compare",
        div(class = "card-head", h2("Site comparison"), span(class = "muted", "Where: score with terrain")),
        comparisonUI("panels")),
      div(class = "card card-visibility", timelineUI("timeline"))),

    # ---- map tools + footer ---------------------------------------------
    div(class = "map-tools",
      tags$button(id = "reset-camera", type = "button", title = "Top-down view of the south pole, 0°E at the top", "South pole"),
      tags$button(id = "orbit-camera", type = "button", title = "Whole Moon", "Globe"),
      span(class = "tool-sep"),
      tags$button(id = "zoom-in", type = "button", class = "icon-btn", title = "Zoom in", `aria-label` = "Zoom in", "+"),
      tags$button(id = "zoom-out", type = "button", class = "icon-btn", title = "Zoom out", `aria-label` = "Zoom out", "−"),
      span(class = "tool-sep"),
      tags$button(id = "help-btn", type = "button", class = "icon-btn", title = "How to use this tool", `aria-label` = "Help", "?")),

    div(class = "card card-details", detailsUI("panels")),
    div(class = "credits",
      sprintf("Ephemeris JPL DE421, validated against IAU 2015 (max Δ %.3f°)", max(v$de421_vs_iau2015_sun_direction_max_deg, v$de421_vs_iau2015_earth_direction_max_deg)),
      " · Imagery NASA SVS / GSFC / ASU · Research prototype, no NASA endorsement implied"),

    div(class = "sheet is-active", `data-view` = "start", overviewUI(mission)),
    div(class = "sheet", `data-view` = "methods", methodsUI("methods", mission)),
    div(class = "sheet story-sheet", `data-view` = "story", storyUI(mission)),
    div(class = "sheet", `data-view` = "compare", compareUI("compare")),
    helpUI(mission$sources, has_ml)
  )
)

server <- function(input, output, session) {
  ctrl <- controlsServer("controls", has_terrain)
  selected <- reactiveVal("CR")
  custom <- reactiveVal(NULL)

  points <- reactive({
    p <- mission$sites
    cp <- custom()
    if (!is.null(cp)) {
      add <- p[1, ]; add[] <- NA
      add$id <- "USR"; add$name <- "Custom point"; add$lat <- cp$lat; add$lon_e <- cp$lon
      p <- rbind(p, add)
    }
    p
  })
  win <- reactive(eph_window(mission$eph, ctrl$start(), ctrl$hours()))
  # WHERE: absolute score from terrain-aware data. WHEN: window metrics (smooth Moon), reported separately.
  ranked <- reactive({
    w <- win(); req(nrow(w) > 0)
    sc <- score_points(point_criteria(points(), mission$terrain, mission$dossiers, ctrl$slope_limit()), ctrl$weights(), mission$sites$id)
    out <- merge(sc, analyse_points(w, points()), by = "id", sort = FALSE)
    attr(out, "slope_limit") <- ctrl$slope_limit(); out
  })
  geom <- reactive({
    p <- points(); s <- p[p$id == selected(), ]; req(nrow(s) == 1)
    site_geometry(win(), s$lat, s$lon_e)
  })
  selected_name <- reactive({ p <- points(); p$name[p$id == selected()] })

  output$legend_title <- renderText(switch(ctrl$heat(),
    ml = "ML · similarity to NASA regions (0–100)", suit = "Landing score (0 to 100)", ltsun = "Sunlight, long-term (%)", ltearth = "Earth in view, long-term (%)", flat = sprintf("Flat ground, slope below %g° (%%)", ctrl$slope_limit()),
    earth = "Window: Earth above horizon, no terrain (%)", sun = "Window: Sun above horizon, no terrain (%)", both = "Window: Sun and Earth, no terrain (%)", none = "Map layer off"))
  output$legend_note <- renderText(switch(ctrl$heat(),
    suit = sprintf("Weighted mean of flat ground (LOLA 80 m, slope below %g°) and long-term Sun and Earth visibility with terrain (Mazarico et al. 2011). The same formula scores the sites, so a site's score equals the colour of the map at its position. Orange = low, green = high.", ctrl$slope_limit()),
    ml = sprintf("Random-forest model trained on the nine NASA Artemis regions (USGS outlines). Score = percentile among all cells: 90 means more NASA-like than 90 %% of the south-polar terrain. Validated on held-out regions (mean AUC %.2f).", if (has_ml) mission$ml$card$validation$mean_auc else NA),
    ltsun = "Average share of time sunlit over 18.6 years with LOLA terrain shadowing (Mazarico et al. 2011). 0 = permanent shadow.",
    ltearth = "Average share of time Earth is visible over 18.6 years with LOLA terrain (Mazarico et al. 2011).",
    flat = "Share of each ~1.5 km cell with LOLA slope below the limit (64 samples per cell). Orange = steep, green = flat.",
    none = "Choose a layer to colour the map.",
    "Smooth-Moon geometry for the selected window: hours with the body above the local horizon, terrain ignored. Near the pole real mountains block or extend the view, so use this for timing only; the score uses the long-term values with terrain. Isolines every 10 %, bold at 50 %."))

  t_idx <- timelineServer("timeline", win, geom, selected_name, ctrl$hours)
  globe <- globeServer("globe", points, selected, win, t_idx, ctrl$layers, ctrl$heat,
                       mission$terrain, ctrl$weights, ctrl$slope_limit, mission$ml, mission$regions, mission$landings)
  panelsServer("panels", mission, points, ranked, selected, geom, reactive(input$details_tab))

  compareServer("compare", mission, points, win, ctrl$start, ctrl$hours, mission$horizons,
    set_window = function(d, h) {
      updateDateInput(session, "controls-start", value = d)
      if (!is.null(h)) updateSelectInput(session, "controls-duration", selected = h)
    })

  observeEvent(input$dossier_open, {
    id <- input$dossier_open$id
    d <- tryCatch(build_dossier(id, mission, points(), ctrl$weights(), win(), ctrl$start(), mission$sources, ctrl$slope_limit()),
                  error = function(e) { message("dossier: ", conditionMessage(e)); NULL })
    req(d)
    d$slope_limit <- ctrl$slope_limit()
    session$sendCustomMessage("lunar:dossier", d)
  })
  observeEvent(input$pick_site, if (input$pick_site %in% points()$id) selected(input$pick_site))
  observeEvent(globe$picked(), if (globe$picked() %in% points()$id) selected(globe$picked()))
  observeEvent(globe$ground(), {
    g <- globe$ground()
    custom(list(lat = round(g$lat, 4), lon = round(g$lon %% 360, 4)))
    selected("USR")
  })
}

shinyApp(ui, server)

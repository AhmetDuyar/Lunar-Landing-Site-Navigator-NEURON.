# Left floating card: mission window, map layers, decision weights.

controlsUI <- function(id, has_terrain = FALSE, has_illum = FALSE, has_ml = FALSE, has_regions = FALSE) {
  ns <- NS(id)
  w <- function(key, label, hint, value) {
    div(class = "weight-row",
      div(class = "weight-head", span(label), span(class = "hint", hint)),
      sliderInput(ns(key), NULL, min = 0, max = 5, value = value, step = 1, ticks = FALSE))
  }
  layer_choices <- c(
    if (has_ml) c("ML · NASA-likeness" = "ml"),
    if (has_terrain) c("Landing score" = "suit", "Flat ground (%)" = "flat"),
    if (has_illum) c("Sunlight, long-term (%)" = "ltsun", "Earth in view, long-term (%)" = "ltearth"),
    "Window: Sun, no terrain" = "sun", "Window: Earth, no terrain" = "earth", "Window: both, no terrain" = "both", "None" = "none")
  tagList(
    div(class = "card-section",
      h3("Mission window"),
      div(class = "field-row",
        div(class = "field",
          tags$label(`for` = ns("start"), "Start (UTC)"),
          dateInput(ns("start"), NULL, value = as.Date("2026-11-14"),
                    min = as.Date("2026-01-01"), max = as.Date("2030-11-30"),
                    format = "yyyy-mm-dd", weekstart = 1)),
        div(class = "field",
          tags$label(`for` = ns("duration"), "Duration"),
          selectInput(ns("duration"), NULL, selectize = FALSE,
            choices = c("7 days" = 168, "14 days" = 336, "29.5 days" = 708), selected = 708)))),
    div(class = "card-section",
      h3("Colour the map by"),
      radioButtons(ns("heat"), NULL, choices = layer_choices, selected = if (has_terrain) "suit" else "none"),
      p(class = "hint layer-note", "The first four answer where to land (long-term, real terrain). Window layers show your mission dates on a smooth Moon."),
      if (has_terrain) div(class = "field inline-field",
        tags$label(`for` = ns("slope_limit"), "Max. landing slope"),
        selectInput(ns("slope_limit"), NULL, selectize = FALSE, width = "92px",
          choices = c("5°" = 5, "8°" = 8, "10°" = 10, "15°" = 15), selected = 8),
        span(class = "hint", "assumption")),
      tags$details(class = "map-opts", tags$summary("Map display options"),
      div(class = "check-grid",
        checkboxInput(ns("grid"), "Graticule", TRUE),
        checkboxInput(ns("labels"), "Site labels", TRUE),
        checkboxInput(ns("lighting"), "Sun shading", FALSE),
        checkboxInput(ns("imagery"), "Imagery", TRUE),
        if (has_terrain) checkboxInput(ns("hill"), "LOLA relief", TRUE),
        if (has_regions) checkboxInput(ns("regions"), "Artemis regions", TRUE),
        checkboxInput(ns("landings"), "Previous landings", TRUE)),
      div(class = "land-key", span(class = "k landed"), "landed", span(class = "k tipped"), "tipped over", span(class = "k crashed", "×"), "crashed",
          span(class = "k planned"), "planned"))),
    div(class = "card-section",
      h3("Score weights"),
      w("w_terrain", "Terrain safety", "flat ground", 4),
      w("w_sun", "Power", "long-term Sun", 3),
      w("w_earth", "Direct-to-Earth", "long-term Earth", 3),
      p(class = "hint weights-note", "Score = weighted mean of the three, 0 to 100. The mission window above sets when to land, not where."))
  )
}

controlsServer <- function(id, has_terrain = FALSE) {
  moduleServer(id, function(input, output, session) {
    list(
      start = reactive({ req(input$start); input$start }),
      hours = reactive(as.numeric(input$duration %||% 708)),
      weights = reactive(c(terrain = input$w_terrain %||% 4, sun = input$w_sun %||% 3, earth = input$w_earth %||% 3)),
      slope_limit = reactive(as.numeric(input$slope_limit %||% 8)),
      heat = reactive(input$heat %||% "none"),
      layers = reactive(list(landings = isTRUE(input$landings), grid = isTRUE(input$grid), labels = isTRUE(input$labels),
                             lighting = isTRUE(input$lighting), imagery = isTRUE(input$imagery),
                             hill = has_terrain && isTRUE(input$hill), regions = isTRUE(input$regions)))
    )
  })
}

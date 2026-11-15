# Right floating card: Sun/Earth elevation over the window with a time scrubber.

timelineUI <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "card-head",
      h2("When: mission window"),
      span(class = "prov prov-window", "DE421 + LOLA skyline")),
    uiOutput(ns("title"), class = "tl-title"),
    uiOutput(ns("countdown")),
    div(class = "legend",
      span(class = "lg lg-sun", "Sun elevation"),
      span(class = "lg lg-earth", "Earth elevation"),
      span(class = "lg-note", "0° = real skyline (LOLA terrain)")),
    uiOutput(ns("chart"), class = "chart-wrap"),
    div(class = "scrub", sliderInput(ns("t"), NULL, min = 0, max = 707, value = 0, step = 1, ticks = FALSE,
        animate = animationOptions(interval = 90, loop = TRUE))),
    uiOutput(ns("readout"), class = "readout")
  )
}

timelineServer <- function(id, win, geom, selected_name, hours) {
  moduleServer(id, function(input, output, session) {
    observeEvent(list(hours(), win()), {
      updateSliderInput(session, "t", max = nrow(win()) - 1, value = min(input$t %||% 0, nrow(win()) - 1))
    })
    t_idx <- reactive({ n <- nrow(win()); max(1, min(n, (input$t %||% 0) + 1)) })
    output$title <- renderUI({
      w <- win()
      tagList(strong(selected_name()),
        span(sprintf("%s to %s", format(w$utc[1], "%d %b %Y"), format(w$utc[nrow(w)], "%d %b %Y"))))
    })
    output$chart <- renderUI(elevation_svg(geom()))
    observe(session$sendCustomMessage("timeline:cursor", list(i = t_idx() - 1)))
    output$readout <- renderUI({
      g <- geom(); i <- t_idx()
      tagList(
        span(class = "ts", format(g$utc[i], "%d %b %Y, %H:%M UTC")),
        span(class = "r-sun", sprintf("Sun %+.2f° above skyline · az %.0f°", g$sun_el[i], g$sun_az[i])),
        span(class = "r-earth", sprintf("Earth %+.2f° · az %.0f°", g$earth_el[i], g$earth_az[i])),
        span(class = "r-src", switch(attr(g, "horizon") %||% "smooth", exact = "exact LOLA horizon", model = "ML horizon (surrogate)", "smooth Moon")))
    })
    output$countdown <- renderUI(countdown_ui(geom(), t_idx()))
    t_idx
  })
}

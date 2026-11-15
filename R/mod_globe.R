# Three.js map bridge: markers, layers, Sun/Earth direction, visibility raster.

globeUI <- function(id) {
  ns <- NS(id)
  div(id = ns("canvas"), class = "map-stage", `data-ready-input` = ns("ready"),
      `data-pick-input` = ns("picked"), `data-ground-input` = ns("ground"),
      div(class = "map-status", role = "status", "Loading lunar map…"),
      div(class = "map-labels", `aria-hidden` = "true"),
      div(class = "map-pins"))
}

globeServer <- function(id, points, selected, win, t_idx, layers, heat, terrain = NULL,
                        weights = reactive(c(terrain = 1, sun = 1, earth = 1)), slope_limit = reactive(8), ml = NULL, regions = NULL, landings = NULL) {
  moduleServer(id, function(input, output, session) {
    ready <- reactive(isTRUE(input$ready))
    observe({
      req(ready())
      p <- points()
      session$sendCustomMessage("lunar:sites", list(
        container = session$ns("canvas"),
        sites = lapply(seq_len(nrow(p)), function(i) list(id = p$id[i], name = p$name[i], lat = p$lat[i], lon = p$lon_e[i])),
        selected = selected(), layers = layers(),
        landings = if (!is.null(landings)) lapply(seq_len(nrow(landings)), function(i) {
          l <- landings[i, ]
          near_site <- any(gc_km(l$lat, l$lon, p$lat, p$lon_e) < 2)
          list(id = l$id, mission = l$mission, year = substr(l$date, 1, 4), outcome = l$outcome,
               lat = l$lat, lon = l$lon, polar = l$lat < -60, merge = near_site,
               major = isTRUE(l$crewed) || as.integer(substr(l$date, 1, 4)) >= 2013)
        }) else list(),
        regions = if (!is.null(regions)) lapply(regions, function(r) list(name = r$name, lon = unlist(r$lon), lat = unlist(r$lat), centroid = unlist(r$centroid))) else list()))
    })
    observe({
      req(ready())
      w <- win(); i <- t_idx(); req(i <= nrow(w))
      e <- c(w$earth_x_km[i], w$earth_y_km[i], w$earth_z_km[i])
      session$sendCustomMessage("lunar:time", list(
        container = session$ns("canvas"),
        sun = c(w$sun_x[i], w$sun_y[i], w$sun_z[i]), earth = e / sqrt(sum(e^2))))
    })
    grid <- reactive(heat_grid(win()))
    ggrid <- reactive(global_grid(win()))
    observe({
      req(ready())
      key <- heat()
      payload <- if (key == "none") NULL
        else if (key %in% c("earth", "sun", "both")) {
          g <- grid(); gg <- ggrid()
          list(n = g$n, extent = g$extent, values = g[[key]], lines = TRUE,
               global = list(w = gg$w, h = gg$h, values = gg[[key]]))
        }
        else if (!is.null(terrain) && key == "flat") list(n = terrain$n, extent = HEAT_EXTENT_DEG,
                    values = terrain$grid[[paste0("flat_lt", slope_limit())]], lines = FALSE)
        else if (!is.null(ml) && key == "ml") list(n = TERRAIN_GRID_N, extent = HEAT_EXTENT_DEG, values = ml$grid$ml_score, lines = FALSE)
        else if (!is.null(terrain$illum) && key %in% c("ltsun", "ltearth")) list(n = terrain$n, extent = HEAT_EXTENT_DEG,
                    values = terrain$illum$grid[[if (key == "ltsun") "sun_avg" else "earth_avg"]], lines = FALSE)
        else if (!is.null(terrain) && key == "suit") {
          w <- weights()
          sg <- suitability_grid(grid(), terrain, w_sun = w[["sun"]], w_earth = w[["earth"]], w_terrain = w[["terrain"]], slope_limit = slope_limit())
          list(n = sg$n, extent = sg$extent, values = sg$values, lines = FALSE)
        }
      session$sendCustomMessage("lunar:heat", c(list(container = session$ns("canvas")),
        if (is.null(payload)) list(values = NULL) else payload))
    })
    list(picked = reactive(input$picked), ground = reactive(input$ground))
  })
}

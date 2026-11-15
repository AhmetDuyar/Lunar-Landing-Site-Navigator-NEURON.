# Compare view: rapid scenario comparison, the core ask of the challenge.
#   Sites mode: every candidate (plus custom point and selected landings) for the
#               current mission window, one hour-by-hour strip each.
#   Dates mode: one site across the next 12 lunar months, one strip per month.
# Strip colours: orange = Sun and Earth up, light orange = Sun only,
# grey = Earth only, black = neither. Geometry: JPL DE421 (R/interfaces.R).

STRIP_COL <- c("#141414", "#f9c09a", "#969696", "#f26a1b")   # code 0..3

strip_svg <- function(g, W = 560, H = 22, ticks = TRUE) {
  code <- (g$sun_el > 0) + 2L * (g$earth_el > 0)
  n <- length(code); r <- rle(code); ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1
  x <- function(i) (i - 1) / n * W
  rects <- paste(sprintf('<rect x="%.2f" y="0" width="%.2f" height="%d" fill="%s"/>',
                         x(starts), pmax(0.6, x(ends + 1) - x(starts)), H, STRIP_COL[r$values + 1]), collapse = "")
  tk <- ""
  if (ticks) {
    mid <- which(format(g$utc, "%H") == "00"); mid <- mid[(seq_along(mid) - 1) %% 7 == 0]
    tk <- paste(sprintf('<line x1="%.1f" x2="%.1f" y1="0" y2="%d" stroke="#ffffff" stroke-opacity=".55" stroke-width="1"/>', x(mid), x(mid), H), collapse = "")
  }
  HTML(sprintf('<svg class="cmp-strip" width="100%%" height="%d" style="display:block;width:100%%;min-width:300px;height:%dpx" viewBox="0 0 %d %d" preserveAspectRatio="none" role="img" aria-label="Hour-by-hour Sun and Earth visibility">%s%s</svg>', H, H, W, H, rects, tk))
}

day_axis <- function(g, W = 560) {
  n <- nrow(g); mid <- which(format(g$utc, "%H") == "00"); mid <- mid[(seq_along(mid) - 1) %% 7 == 0]
  HTML(sprintf('<svg class="cmp-axis" width="100%%" height="16" style="display:block;width:100%%;min-width:300px" viewBox="0 0 %d 16" preserveAspectRatio="none" aria-hidden="true">%s</svg>', W,
    paste(sprintf('<text x="%.1f" y="12">%s</text>', (mid - 1) / n * W + 2, format(g$utc[mid], "%d %b")), collapse = "")))
}

scenario_row <- function(g, label, sub = NULL, id = NULL, highlight = FALSE) {
  m <- window_metrics(g); bw <- best_window(g)
  up_s <- g$sun_el > 0; up_e <- g$earth_el > 0
  hs <- hours_until_change(up_s, 1); he <- hours_until_change(up_e, 1)
  first <- function(up, h, a, b, body) {
    if (is.na(h)) return(if (up[1]) sprintf("%s up all window", body) else sprintf("%s down all window", body))
    sprintf("%s in %s", if (up[1]) a else b, fmt_dur(h))
  }
  tags$tr(class = paste("cmp-row", if (highlight) "is-best"),
    tags$td(class = "cmp-name", div(strong(label)), if (!is.null(sub)) div(class = "cmp-sub", sub),
            if (!is.null(id)) tags$button(type = "button", class = "cmp-dossier", onclick = sprintf("openDossier('%s')", id), "Dossier")),
    tags$td(class = "cmp-strip-td", strip_svg(g)),
    tags$td(class = "num", sprintf("%.0f %%", m$sun_pct)),
    tags$td(class = "num", sprintf("%.0f %%", m$earth_pct)),
    tags$td(class = "num strong", sprintf("%.0f %%", m$both_pct)),
    tags$td(class = "num", fmt_dur(m$max_night_h)),
    tags$td(class = "num", fmt_dur(m$max_blackout_h)),
    tags$td(class = "cmp-best", if (is.null(bw)) span(class = "muted", "none") else tagList(strong(fmt_dur(bw$hours)), div(class = "cmp-sub", format(bw$start, "from %d %b %H:%M")))),
    tags$td(class = "cmp-first", div(first(up_s, hs, "Sunset", "Sunrise", "Sun")), div(first(up_e, he, "Earthset", "Earthrise", "Earth"))))
}

compareUI <- function(id) {
  ns <- NS(id)
  th <- function(label, tip, cls = NULL) tags$th(class = cls, title = tip, label)
  div(class = "cmp-wrap",
    div(class = "cmp-head",
      div(class = "ctx-step big", "2 · When"),
      h1("When can we land?"),
      p(class = "lead", "Each bar is one site over your mission window, hour by hour. Orange means the Sun powers the lander and Earth is in view for a direct radio link at the same time. Use it to pick a landing date, or to see what changes when the launch slips.")),
    div(class = "cmp-bar",
      div(class = "cmp-field", tags$label(`for` = ns("start"), "Mission start (UTC)"),
          dateInput(ns("start"), NULL, value = as.Date("2026-11-14"), min = as.Date("2026-01-01"), max = as.Date("2030-11-30"), format = "yyyy-mm-dd", weekstart = 1)),
      div(class = "cmp-field", tags$label(`for` = ns("hours"), "On the surface for"),
          selectInput(ns("hours"), NULL, choices = c("7 days" = 168, "14 days" = 336, "29.5 days" = 708), selected = 708, selectize = FALSE)),
      div(class = "cmp-field cmp-shift", tags$label("Launch slips?"),
          div(class = "cmp-step",
            actionButton(ns("prev"), HTML("&larr; 1 lunar month earlier"), class = "cmp-btn"),
            actionButton(ns("nxt"), HTML("1 lunar month later &rarr;"), class = "cmp-btn"))),
      div(class = "cmp-field", tags$label("Compare"),
          radioButtons(ns("mode"), NULL, inline = TRUE, choices = c("all sites" = "sites", "one site over 12 months" = "dates"), selected = "sites")),
      uiOutput(ns("extra"), class = "cmp-field")),
    div(class = "cmp-read",
      div(class = "cmp-legend",
        span(span(class = "sw", style = "background:#f26a1b"), strong("Sun and Earth up"), " power and radio"),
        span(span(class = "sw", style = "background:#f9c09a"), "Sun only"),
        span(span(class = "sw", style = "background:#969696"), "Earth only"),
        span(span(class = "sw", style = "background:#141414"), "neither: night and no radio")),
      uiOutput(ns("geom_note"))),
    uiOutput(ns("table")),
    div(class = "cmp-foot",
      span("Hover a column title for its meaning."),
      tags$button(type = "button", class = "ov-link", `data-go` = "story", HTML("Next: 3 · How sure &rarr;"))))
}

compareServer <- function(id, mission, points, win_base, start, hours, horizons = NULL, set_window = function(d, h) NULL) {
  moduleServer(id, function(input, output, session) {
    # one mission window for the whole app: this page and the map stay in sync
    observeEvent(start(), if (!identical(as.Date(input$start), as.Date(start()))) updateDateInput(session, "start", value = start()))
    observeEvent(hours(), if (!identical(as.numeric(input$hours), as.numeric(hours()))) updateSelectInput(session, "hours", selected = hours()))
    observeEvent(input$start, if (!identical(as.Date(input$start), as.Date(start()))) set_window(input$start, NULL), ignoreInit = TRUE)
    observeEvent(input$hours, if (!identical(as.numeric(input$hours), as.numeric(hours()))) set_window(start(), input$hours), ignoreInit = TRUE)
    step_month <- function(k) {
      d <- start() + round(k * 29.530589)
      d <- max(as.Date("2026-01-01"), min(as.Date("2030-11-30"), d)); set_window(d, NULL)
    }
    observeEvent(input$prev, step_month(-1)); observeEvent(input$nxt, step_month(1))
    shift <- function() 0
    win <- reactive(eph_window(mission$eph, start(), hours()))
    land <- mission$landings
    polar <- if (!is.null(land)) land[land$lat < -60, ] else NULL
    output$extra <- renderUI({
      if (identical(input$mode, "dates")) {
        p <- points(); ch <- setNames(p$id, p$name)
        if (!is.null(land)) ch <- c(ch, setNames(land$id, land$mission))
        selectInput(session$ns("site"), NULL, choices = ch, selected = input$site %||% "MM", width = "260px", selectize = FALSE)
      } else if (!is.null(polar) && nrow(polar))
        checkboxInput(session$ns("with_land"), "Add south-polar landings", TRUE)
    })
    geom_for <- function(w, id, lat, lon) {
      site_geometry(w, lat, lon)
    }
    output$geom_note <- renderUI({
      span(class = "cmp-note", if (isTRUE(mission$has_horizons)) "JPL DE421 with the real LOLA skyline: exact 360° horizon for published sites and landings, ML surrogate for other points between 80° and 90° S." else "Smooth-Moon geometry from JPL DE421: real mountains can block or extend the view.")
    })
    output$table <- renderUI({
      th <- function(label, tip, cls = NULL) tags$th(class = cls, title = tip, label)
      hdr <- tags$thead(tags$tr(th("Site", "Published candidate site or previous landing"), tags$th(class = "cmp-axis-th", day_axis(win())),
        th("Sun", "Share of hours with the Sun above the horizon: solar power", "num"),
        th("Earth", "Share of hours with Earth above the horizon: direct radio link", "num"),
        th("Both", "Share of hours with Sun and Earth up together", "num"),
        th("Longest night", "Longest stretch without Sun: battery and heater sizing", "num"),
        th("Longest blackout", "Longest stretch without Earth: communication gap", "num"),
        th("Best window", "Longest period with Sun and Earth up together, and when it starts"),
        th("At the start", "How long until the Sun or Earth sets (or rises) after the window opens")))
      if (identical(input$mode, "dates")) {
        id <- input$site %||% "MM"; p <- points()
        if (id %in% p$id) { lat <- p$lat[p$id == id]; lon <- p$lon_e[p$id == id]; nm <- p$name[p$id == id] }
        else { L <- land[land$id == id, ]; lat <- L$lat; lon <- L$lon %% 360; nm <- L$mission }
        s0 <- start() + round(shift() * 29.530589)
        rows <- list(); both <- c()
        for (k in 0:11) {
          w <- eph_window(mission$eph, s0 + round(k * 29.530589), 708)
          if (nrow(w) < 600) break
          g <- geom_for(w, id, lat, lon); both <- c(both, window_metrics(g)$both_pct)
          rows[[length(rows) + 1]] <- list(g = g, label = format(w$utc[1], "%d %b %Y"))
        }
        best <- which.max(both)
        tagList(h3(class = "cmp-h", nm, span(class = "muted", " · 29.5-day windows")),
          tags$table(class = "cmp-table", tags$thead(tags$tr(tags$th("Start"), tags$th(class = "cmp-axis-th", "29.5 days, hour by hour"),
              tags$th(class = "num", "Sun"), tags$th(class = "num", "Earth"), tags$th(class = "num", "Both"),
              tags$th(class = "num", "Longest night"), tags$th(class = "num", "Longest blackout"), tags$th("Best window"), tags$th("At the start"))),
            tags$tbody(lapply(seq_along(rows), function(k) scenario_row(rows[[k]]$g, rows[[k]]$label, if (k == best) "most Sun + Earth together" else NULL, highlight = k == best)))))
      } else {
        w <- win(); p <- points()
        items <- lapply(seq_len(nrow(p)), function(i) list(id = p$id[i], name = p$name[i], lat = p$lat[i], lon = p$lon_e[i], sub = fmt_lat(p$lat[i], 2)))
        if (isTRUE(input$with_land) && !is.null(polar))
          items <- c(items, lapply(seq_len(nrow(polar)), function(i) list(id = polar$id[i], name = polar$mission[i], lat = polar$lat[i], lon = polar$lon[i] %% 360,
            sub = sprintf("%s · %s", substr(polar$date[i], 1, 4), polar$outcome[i]))))
        gs <- lapply(items, function(it) geom_for(w, it$id, it$lat, it$lon))
        both <- vapply(gs, function(g) window_metrics(g)$both_pct, 0)
        o <- order(-both)
        tagList(h3(class = "cmp-h", format(w$utc[1], "%d %b %Y"), " to ", format(w$utc[nrow(w)], "%d %b %Y"),
                   span(class = "muted", sprintf(" · sorted by time with Sun and Earth up together"))),
          tags$table(class = "cmp-table", hdr,
            tags$tbody(lapply(seq_along(o), function(k) { it <- items[[o[k]]]; scenario_row(gs[[o[k]]], it$name, it$sub, it$id, highlight = k == 1) }))))
      }
    })
  })
}

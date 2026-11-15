# Right floating card: site comparison table + details of the selected site.

comparisonUI <- function(id) uiOutput(NS(id, "table"))
detailsUI <- function(id) uiOutput(NS(id, "details"))

panelsServer <- function(id, mission, points, ranked, selected, geom = NULL, details_tab = reactive("metrics")) {
  moduleServer(id, function(input, output, session) {
    src <- mission$sources

    output$table <- renderUI({
      r <- ranked(); p <- points(); lim <- attr(r, "slope_limit") %||% 8
      r <- r[order(is.na(r$rank), r$rank, -r$score), ]
      rows <- lapply(seq_len(nrow(r)), function(i) {
        row <- r[i, ]; s <- p[p$id == row$id, ]
        tags$tr(class = paste("site-row", if (identical(row$id, selected())) "is-selected"),
          onclick = sprintf("Shiny.setInputValue('pick_site','%s',{priority:'event'})", row$id),
          tags$td(class = "c-rank", if (is.na(row$rank)) HTML("&middot;") else row$rank),
          tags$td(class = "c-site", div(class = "site-name", s$name), div(class = "site-sub", fmt_lat(s$lat, 2))),
          tags$td(class = "num", fmt_num(row$flat_pct, 0, "%")),
          tags$td(class = "num", fmt_num(row$lt_sun, 0, "%")),
          tags$td(class = "num", fmt_num(row$lt_earth, 0, "%")),
          tags$td(class = "num c-score",
            div(class = "score-val", if (is.na(row$score)) "n/a" else sprintf("%.0f", row$score)),
            div(class = "score-track", div(class = "score-fill", style = sprintf("width:%.0f%%", row$score %||% 0)))))
      })
      best <- r[!is.na(r$rank) & r$rank == 1, ][1, ]; bn <- p$name[p$id == best$id]
      tagList(
        tags$table(class = "cmp",
          tags$thead(tags$tr(tags$th("#"), tags$th("Site"),
            tags$th(class = "num", title = "Share of the ground within 1 km below the slope limit (LOLA 80 m)", "Flat"),
            tags$th(class = "num", title = "18.6-year average with terrain (Mazarico et al. 2011)", "Sun"),
            tags$th(class = "num", title = "18.6-year average with terrain (Mazarico et al. 2011)", "Earth"),
            tags$th(class = "num", "Score"))),
          tags$tbody(rows)),
        p(class = "cmp-note", sprintf("Long-term values with real terrain. Flat = ground within 1 km below %g°. Score 0 to 100, absolute: it does not change when other places are added.", lim)),
        div(class = "recommend",
          span(class = "tick", HTML("&#10003;")),
          span("Highest score for current weighting"), strong(bn)),
        if (!is.null(mission$analysis$robust$sites$rank_hist)) {
          st <- mission$analysis$robust$sites; top <- st$table[1, ]
          p(class = "robust-note", sprintf("Robustness: %s is rank 1 in %s %% of %s scenarios (all weightings × slope limits %s°).",
            top$name, format(top$p_rank1), format(st$scenarios, big.mark = ","), paste(st$slope_limits_deg, collapse = "/")),
            tags$a(href = "#", class = "goto-methods", "Details"))
        })
    })

    output$details <- renderUI({
      p <- points(); id <- selected(); s <- p[p$id == id, ]
      req(nrow(s) == 1)
      m <- ranked(); m <- m[m$id == id, ]
      is_user <- identical(id, "USR")
      kind <- if (is_user) "user" else if (s$coord_source == "lroc2025") "measured" else "literature"
      tile <- function(label, value, badge, ref = NULL, sub = NULL) {
        div(class = "tile",
          div(class = "tile-label", label),
          div(class = "tile-value", value),
          div(class = "tile-foot", badge, ref, if (!is.null(sub)) span(class = "tile-sub", sub)))
      }
      lit <- !is_user && !is.na(s$lit_illum_pct)
      tb <- prov_badge("computed", "Computed · terrain")
      wb <- prov_badge("window")
      flat_tile <- tile("Flat ground", fmt_num(m$flat_pct, 0, " %"), tb, ref_tag(src, "lola_pgda"),
        sub = if (is.na(m$flat_pct)) "outside 80 to 90° S" else sprintf("%s, mean slope %s", m$terrain_src, fmt_num(m$slope_deg, 1, "°")))
      sun_tile <- tile("Sunlight · long-term", fmt_num(m$lt_sun, 1, " %"), tb, ref_tag(src, "mazarico2011"),
        sub = if (lit) sprintf("literature %s", fmt_num(s$lit_illum_pct, 1, " %")) else "18.6-yr average")
      earth_tile <- tile("Earth in view · long-term", fmt_num(m$lt_earth, 1, " %"), tb, ref_tag(src, "mazarico2011"), sub = "18.6-yr average")
      tab <- details_tab() %||% "metrics"
      tabbtn <- function(key, label) tags$button(type = "button", class = paste("tab-btn", if (tab == key) "is-active"),
        onclick = sprintf("Shiny.setInputValue('details_tab','%s')", key), label)
      tagList(
        div(class = "detail-head",
          div(class = "detail-title", h2(s$name), span(class = "rank-chip", if (is.na(m$rank)) sprintf("Score %s", if (is.na(m$score)) "n/a" else sprintf("%.0f", m$score)) else sprintf("Rank %d · score %.0f", m$rank, m$score)),
              div(class = "tabs", tabbtn("metrics", "Metrics"), tabbtn("why", "Why here?")),
              tags$button(type = "button", class = "dossier-btn", onclick = sprintf("openDossier('%s')", id), "Open dossier")),
          div(class = "detail-region",
            if (is_user) "Custom point. Click the map to move it"
            else tagList(s$region_status, ref_tag(src, "nasa2024")))),
        if (tab == "why" && !is.null(geom)) div(class = "why", explain_ui(explain_site(id, ranked(), p, mission, geom())))
        else div(class = "tiles",
          tile("Position", HTML(sprintf("%s<br>%s", fmt_lat(s$lat), fmt_lon(s$lon_e))), prov_badge(kind),
               if (!is_user) ref_tag(src, s$coord_source)),
          flat_tile, sun_tile, earth_tile,
          tile("Longest night", fmt_num(m$max_night_h, 0, " h"), wb, sub = "this window"),
          tile("Longest Earth blackout", fmt_num(m$max_blackout_h, 0, " h"), wb, sub = "this window")))
    })
  })
}

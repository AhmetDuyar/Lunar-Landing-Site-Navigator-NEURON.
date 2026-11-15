# Plain-language, data-driven explanation of a site: why (strengths / weaknesses),
# when (best landing window in the mission window) and how (approach lighting).
# Every statement is built from values shown elsewhere in the app; nothing is invented.

best_window <- function(g) {
  ok <- g$sun_el > 0 & g$earth_el > 0
  if (!any(ok)) return(NULL)
  r <- rle(ok); ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1
  k <- which(r$values)[which.max(r$lengths[r$values])]
  i0 <- starts[k]; i1 <- ends[k]
  list(start = g$utc[i0], end = g$utc[i1], hours = i1 - i0 + 1,
       sun_el = g$sun_el[i0], sun_az = g$sun_az[i0], earth_el = g$earth_el[i0])
}

explain_site <- function(id, ranked, points, mission, g) {
  r <- ranked; me <- r[r$id == id, ]; p <- points[points$id == id, ]
  sites <- r[!is.na(r$rank), ]; n <- nrow(sites)
  place <- function(col) if (is.na(me[[col]]) || !(id %in% sites$id)) NA_integer_ else rank(-sites[[col]], ties.method = "min")[sites$id == id]
  of <- function(col) { k <- place(col); if (is.na(k)) "" else sprintf(" (%d of %d published sites)", k, n) }
  lim <- attr(r, "slope_limit") %||% 8
  items <- list()
  add <- function(key, good, text) items[[length(items) + 1]] <<- list(key = key, good = good, text = text)

  if (!is.na(me$flat_pct)) add("terrain", me$flat_pct >= 60,
    sprintf("%s of the ground within %s is below %g° slope; mean slope %s%s. %s",
            fmt_num(me$flat_pct, 0, " %"), sub(" radius| cell", "", me$terrain_src), lim, fmt_num(me$slope_deg, 1, "°"), of("flat_pct"),
            if (me$flat_pct >= 60) "Plenty of room for a landing ellipse." else "Little flat ground: the landing ellipse must be placed precisely."))
  if (!is.na(me$lt_sun)) add("sun", me$lt_sun >= 50,
    sprintf("Sunlit %s of the time on long-term average, with real terrain shadowing%s. %s", fmt_num(me$lt_sun, 0, " %"), of("lt_sun"),
            if (me$lt_sun >= 50) "Good for solar power." else "Limited solar power; batteries must bridge long dark periods."))
  if (!is.na(me$lt_earth)) add("earth", me$lt_earth >= 60,
    sprintf("Earth in view %s of the time on long-term average, with terrain%s. %s", fmt_num(me$lt_earth, 0, " %"), of("lt_earth"),
            if (me$lt_earth >= 60) "Long periods of direct radio contact." else "Direct-to-Earth links often blocked; a relay orbiter is needed."))
  il <- if (!is.null(mission$terrain$illum)) mission$terrain$illum$site[mission$terrain$illum$site$id == id, ] else NULL
  if (!is.null(il) && nrow(il) == 1 && !is.na(il$psr_nearest_km))
    add("psr", il$psr_nearest_km <= 5, sprintf("Nearest permanently shadowed ground %s away. %s", fmt_num(il$psr_nearest_km, 1, " km"),
        if (il$psr_nearest_km <= 5) "Within rover range of cold traps that may hold water ice." else "Cold traps are far; longer traverses needed."))
  rb <- mission$analysis$robust$sites
  if (!is.null(rb$rank_hist) && id %in% rb$table$id) {
    rr <- rb$table[rb$table$id == id, ]
    add("robust", rr$p_top2 >= 50, sprintf("Robustness: rank 1 in %s %%, top 2 in %s %% of %s weightings × slope limits; median rank %g.",
        format(rr$p_rank1), format(rr$p_top2), format(rb$scenarios, big.mark = ","), rr$median_rank))
  }
  bw <- best_window(g)
  list(
    headline = if (is.na(me$score)) sprintf("%s lies outside the 80 to 90° S terrain data; it cannot be scored.", p$name)
      else if (is.na(me$rank)) sprintf("%s scores %.0f of 100 for the current weights (published sites: %.0f to %.0f).", p$name, me$score, min(sites$score), max(sites$score))
      else sprintf("%s scores %.0f of 100 for the current weights, rank %d of %d published sites.", p$name, me$score, me$rank, n),
    strengths = Filter(function(x) isTRUE(x$good), items),
    weaknesses = Filter(function(x) !isTRUE(x$good), items),
    window = bw, night = me$max_night_h, blackout = me$max_blackout_h
  )
}

explain_ui <- function(ex) {
  li <- function(x, cls) tags$li(class = cls, x$text)
  bw <- ex$window
  tagList(
    p(class = "why-head", ex$headline),
    div(class = "why-cols",
      div(h4("Why land here"), if (length(ex$strengths)) tags$ul(class = "why-list", lapply(ex$strengths, li, "pro")) else p(class = "muted small", "No criterion stands out for this window.")),
      div(h4("What speaks against it"), if (length(ex$weaknesses)) tags$ul(class = "why-list", lapply(ex$weaknesses, li, "con")) else p(class = "muted small", "No weak criterion for this window.")),
      div(h4("When and how"), p(class = "why-note", "Mission window, JPL DE421 with the real LOLA skyline: timing only."),
        if (is.null(bw)) p(class = "small", "No period with Sun and Earth above the horizon at the same time in this window.")
        else tags$ul(class = "why-list",
          tags$li(class = "when", sprintf("Longest night in this window %s, longest Earth blackout %s.", fmt_num(ex$night, 0, " h"), fmt_num(ex$blackout, 0, " h"))),
          tags$li(class = "when", sprintf("Longest period with Sun and Earth up together: %s → %s UTC (%d h).",
                                          format(bw$start, "%d %b %H:%M"), format(bw$end, "%d %b %H:%M"), bw$hours)),
          tags$li(class = "when", sprintf("At its start the Sun stands %.1f° high at azimuth %.0f°; Earth %.1f° high.", bw$sun_el, bw$sun_az, bw$earth_el)),
          tags$li(class = "when", sprintf("Approach with the Sun behind the vehicle (heading ≈ %.0f°) keeps the terrain ahead lit, as practised on Apollo; at such low Sun angles long shadows hide hazards, so terrain-relative navigation is essential.",
                                          (bw$sun_az + 180) %% 360))))),
    p(class = "why-foot", "Where: LOLA 80 m and Mazarico et al. (2011) long-term values with terrain. When: JPL DE421 geometry with the LOLA 80 m terrain horizon. 80 m pixels compare areas; they do not show boulders or craters smaller than about 100 m.")
  )
}

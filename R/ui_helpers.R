# Shared UI helpers: provenance badges, reference markers, number formatting,
# and a dependency-free SVG chart for Sun/Earth elevation.

`%||%` <- function(a, b) if (is.null(a)) b else a

fmt_num <- function(x, d = 1, suffix = "") {
  ifelse(is.na(x), "n/a", paste0(formatC(x, format = "f", digits = d, big.mark = ","), suffix))
}
fmt_lat <- function(lat, d = 4) sprintf("%.*f° %s", d, abs(lat), ifelse(lat < 0, "S", "N"))
fmt_lon <- function(lon, d = 4) sprintf("%.*f° E", d, lon)

source_index <- function(sources, id) match(id, sources$sources$id)

ref_tag <- function(sources, id) {
  if (is.null(id) || is.na(id)) return(NULL)
  i <- source_index(sources, id)
  s <- sources$sources[i, ]
  tags$a(class = "ref", href = "#", `data-ref` = id,
         title = sprintf("%s (%s). %s. %s", s$authors, s$year, s$title, s$venue),
         sprintf("[%d]", i))
}

prov_badge <- function(kind, label = NULL) {
  cls <- switch(kind,
    computed = "prov prov-computed", literature = "prov prov-lit",
    official = "prov prov-official", measured = "prov prov-measured",
    user = "prov prov-user", window = "prov prov-window", "prov prov-na")
  txt <- label %||% switch(kind,
    computed = "Computed", literature = "Literature", official = "NASA",
    measured = "Measured", user = "User input", window = "Window · real skyline", "Not ingested")
  span(class = cls, txt)
}

# ---------------------------------------------------------------------------
# Elevation chart (server-side SVG; the time cursor is moved client-side)
# ---------------------------------------------------------------------------
elevation_svg <- function(g, W = 400, H = 200) {
  n <- nrow(g)
  pad <- list(l = 36, r = 4, t = 8, b = 58)
  pw <- W - pad$l - pad$r; ph <- H - pad$t - pad$b
  rng <- range(c(g$sun_el, g$earth_el, -1, 1))
  rng <- c(floor(rng[1]), ceiling(rng[2]))
  ticks <- pretty(rng, n = 4); ticks <- ticks[ticks >= rng[1] & ticks <= rng[2]]
  x <- function(i) pad$l + (i - 1) / max(1, n - 1) * pw
  y <- function(v) pad$t + (rng[2] - v) / diff(rng) * ph
  pts <- function(v) paste(sprintf("%.1f,%.1f", x(seq_len(n)), y(v)), collapse = " ")
  area <- function(v) paste0(sprintf("%.1f,%.1f ", x(1), y(0)), pts(pmax(v, 0)), sprintf(" %.1f,%.1f", x(n), y(0)))
  runs <- function(up) {
    r <- rle(up); ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1
    data.frame(s = starts[r$values], e = ends[r$values])
  }
  bars <- function(up, yy, cls) {
    rr <- runs(up); if (!nrow(rr)) return("")
    paste(sprintf('<rect class="%s" x="%.1f" y="%.1f" width="%.1f" height="6" rx="1"/>',
                  cls, x(rr$s), yy, pmax(1.5, x(rr$e) - x(rr$s) + pw / n)), collapse = "")
  }
  days <- as.numeric(difftime(g$utc[n], g$utc[1], units = "days"))
  step <- if (days <= 8) 1 else if (days <= 15) 2 else 7
  mid <- which(format(g$utc, "%H") == "00")
  di <- mid[(seq_along(mid) - 1) %% step == 0]
  dlab <- sprintf("%d d", round(as.numeric(difftime(g$utc[di], g$utc[1], units = "days"))))
  grid <- paste(sprintf('<line class="grid" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/><text class="axis" x="%d" y="%.1f" text-anchor="end">%s°</text>',
                        pad$l, W - pad$r, y(ticks), y(ticks), pad$l - 6, y(ticks) + 3.5, ticks), collapse = "")
  vgrid <- paste(sprintf('<line class="vgrid" x1="%.1f" x2="%.1f" y1="%d" y2="%d"/><text class="axis" x="%.1f" y="%d" text-anchor="middle">%s</text>',
                         x(di), x(di), pad$t, pad$t + ph, x(di), pad$t + ph + 14, dlab), collapse = "")
  by <- pad$t + ph + 26
  HTML(paste0(
    sprintf('<svg class="elev-chart" viewBox="0 0 %d %d" role="img" aria-label="Sun and Earth elevation over the mission window" data-pl="%d" data-pw="%d" data-n="%d">', W, H, pad$l, pw, n),
    grid, vgrid,
    sprintf('<polygon class="area-sun" points="%s"/>', area(g$sun_el)),
    sprintf('<line class="horizon" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/>', pad$l, W - pad$r, y(0), y(0)),
    sprintf('<polyline class="line-earth" points="%s"/>', pts(g$earth_el)),
    sprintf('<polyline class="line-sun" points="%s"/>', pts(g$sun_el)),
    sprintf('<text class="lane" x="%d" y="%.1f" text-anchor="end">Sun</text>', pad$l - 6, by + 6),
    sprintf('<rect class="lane-bg" x="%d" y="%.1f" width="%d" height="6" rx="1"/>', pad$l, by, pw),
    bars(g$sun_el > 0, by, "bar-sun"),
    sprintf('<text class="lane" x="%d" y="%.1f" text-anchor="end">Earth</text>', pad$l - 6, by + 20),
    sprintf('<rect class="lane-bg" x="%d" y="%.1f" width="%d" height="6" rx="1"/>', pad$l, by + 14, pw),
    bars(g$earth_el > 0, by + 14, "bar-earth"),
    sprintf('<g id="tl-cursor"><line x1="0" x2="0" y1="%d" y2="%.1f"/></g>', pad$t, by + 22),
    "</svg>"))
}

# ---------------------------------------------------------------------------
# Countdowns: hours from index i until a body sets (or rises) in an hourly series
# ---------------------------------------------------------------------------
hours_until_change <- function(up, i) {
  n <- length(up); if (i >= n) return(NA_real_)
  k <- which(up[(i + 1):n] != up[i])
  if (length(k)) k[1] else NA_real_
}
fmt_dur <- function(h) {
  if (is.na(h)) return(NA_character_)
  d <- h %/% 24; r <- h %% 24
  if (d == 0) sprintf("%d h", as.integer(r)) else sprintf("%d d %d h", as.integer(d), as.integer(r))
}
countdown_ui <- function(g, i) {
  one <- function(el, body, set_word, rise_word) {
    up <- el > 0; h <- hours_until_change(up, i); left <- nrow(g) - i
    word <- if (up[i]) set_word else rise_word
    txt <- if (is.na(h)) (if (up[i]) sprintf("up for the rest of the window (%s)", fmt_dur(left)) else sprintf("no %s in the next %s", tolower(word), fmt_dur(left)))
           else tagList(strong(word), paste(" in", fmt_dur(h)))
    div(class = paste("cd", if (up[i]) "is-up" else "is-down", body),
      span(class = "cd-state", if (up[i]) sprintf("%s up", body) else sprintf("%s down", body)),
      span(class = "cd-next", txt))
  }
  div(class = "countdown",
    one(g$sun_el, "Sun", "Sunset", "Sunrise"),
    one(g$earth_el, "Earth", "Earthset", "Earthrise"))
}

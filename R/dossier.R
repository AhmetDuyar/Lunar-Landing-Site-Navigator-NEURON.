# Site dossier: everything needed to explain WHY a place is better or worse,
# assembled on the server and drawn in the browser (www/dossier.js).
# Every number comes from the data loaded in data/interfaces.R; nothing is estimated.

R_MOON_KM <- 1737.4

gc_km <- function(lat1, lon1, lat2, lon2) {
  p1 <- lat1 * DEG; p2 <- lat2 * DEG; dl <- (lon2 - lon1) * DEG
  R_MOON_KM * acos(pmin(1, pmax(-1, sin(p1) * sin(p2) + cos(p1) * cos(p2) * cos(dl))))
}

CRIT_WHY <- c(
  terrain = "Share of the ground within 1 km below the slope limit (LOLA 80 m). Landers tip over on steep or uneven ground.",
  sun = "18.6-year average share of time in sunlight, with real terrain shadowing (Mazarico et al. 2011): solar power.",
  earth = "18.6-year average share of time with Earth above the real horizon (Mazarico et al. 2011): direct radio link.")

# Monthly profile for the 12 synodic months starting at the mission start (DE421 + LOLA skyline)
year_profile <- function(eph, start, lat, lon_e) {
  t0 <- as.POSIXct(paste(format(start), "00:00"), tz = "UTC"); len <- 29.530589 * 86400
  out <- list()
  for (k in 0:11) {
    a <- t0 + k * len; w <- eph[eph$utc >= a & eph$utc < a + len, , drop = FALSE]
    if (nrow(w) < 600) break
    m <- window_metrics(site_geometry(w, lat, lon_e))
    out[[length(out) + 1]] <- list(label = format(a, "%b %y"), sun = round(m$sun_pct, 1), earth = round(m$earth_pct, 1),
                                   night = m$max_night_h, blackout = m$max_blackout_h)
  }
  out
}

# Hour-by-hour code for the current window: 0 none, 1 Sun only, 2 Earth only, 3 both
hour_strip <- function(g) paste((g$sun_el > 0) + 2L * (g$earth_el > 0), collapse = "")

build_dossier <- function(id, mission, points, weights, win, start, src, slope_limit = 8) {
  sites <- mission$sites; land <- mission$landings
  is_landing <- !is.null(land) && id %in% land$id && !(id %in% points$id)
  pts <- points
  if (is_landing) {
    L <- land[land$id == id, ]
    add <- pts[1, ]; add[] <- NA
    add$id <- id; add$name <- L$mission; add$lat <- L$lat; add$lon_e <- L$lon %% 360
    pts <- rbind(pts[pts$id != "USR", ], add)
  }
  me_p <- pts[pts$id == id, ]; if (nrow(me_p) != 1) return(NULL)
  sc <- score_points(point_criteria(pts, mission$terrain, mission$dossiers, slope_limit), weights, sites$id)
  me <- sc[sc$id == id, ]
  site_sc <- sc[sc$id %in% sites$id, ]
  g <- site_geometry(win, me_p$lat, me_p$lon_e)
  wm <- window_metrics(g)
  scorable <- !is.na(me$score)

  # ---- the three score criteria: this point vs. the published sites --------
  w <- weights[SCORE_CRITERIA$key]; if (sum(w) == 0) w[] <- 1; w <- w / sum(w)
  crit <- list()
  if (scorable) for (i in seq_len(nrow(SCORE_CRITERIA))) {
    k <- SCORE_CRITERIA$key[i]; col <- SCORE_CRITERIA$col[i]; v <- me[[col]]
    oth <- site_sc[site_sc$id != id, ]
    crit[[length(crit) + 1]] <- list(
      key = k, label = SCORE_CRITERIA$label[i], unit = "%", why = CRIT_WHY[[k]], better = "high",
      value = round(v, 1), weight = round(w[[k]], 3), contrib = round(w[[k]] * v, 1),
      place = sum(oth[[col]] > v, na.rm = TRUE) + 1, of = nrow(oth) + 1,
      others = lapply(seq_len(nrow(oth)), function(j) list(id = oth$id[j], name = sites$name[sites$id == oth$id[j]], value = round(oth[[col]][j], 1))))
  }

  # ---- one-sentence verdict ------------------------------------------------
  phr <- function(c) switch(c$key,
    terrain = sprintf("%.0f %% flat ground within 1 km", c$value),
    sun = sprintf("sunlight %.0f %% of the time", c$value),
    earth = sprintf("Earth in view %.0f %% of the time", c$value))
  verdict <- if (!scorable) sprintf("%s lies outside the 80 to 90° S terrain data, so it cannot be scored. The timing information below still applies.", me_p$name) else {
    cb <- vapply(crit, `[[`, 0, "contrib"); vv <- vapply(crit, `[[`, 0, "value"); ww <- vapply(crit, `[[`, 0, "weight")
    wi <- which(ww > 0 & vv < 50)
    ord_c <- setdiff(order(-cb), wi)
    top <- crit[ord_c[seq_len(min(2, length(ord_c)))]]
    head <- if (!is.na(me$rank)) sprintf("%s scores %.0f of 100, rank %d of %d published sites.", me_p$name, me$score, me$rank, nrow(site_sc))
            else sprintf("%s scores %.0f of 100; the published sites score %.0f to %.0f.", me_p$name, me$score, min(site_sc$score), max(site_sc$score))
    paste0(head, if (length(top)) sprintf(" Most points come from %s.", paste(vapply(top, phr, ""), collapse = " and ")) else "",
           if (length(wi)) sprintf(" %s %s.", if (length(wi) > 1) "Its weak points are" else "Its weak point is", paste(vapply(crit[wi], phr, ""), collapse = " and ")) else "")
  }

  # ---- local terrain window (original rasters) ------------------------------
  crop <- if (!is.null(mission$dossiers) && id %in% names(mission$dossiers$points)) mission$dossiers$points[[id]] else NULL

  # ---- previous landings nearby -------------------------------------------
  near <- NULL
  if (!is.null(land)) {
    l2 <- land[land$id != id & land$outcome != "planned", ]
    d <- gc_km(me_p$lat, me_p$lon_e, l2$lat, l2$lon)
    o <- order(d)[1:3]
    near <- lapply(o, function(j) list(id = l2$id[j], mission = l2$mission[j], date = l2$date[j], outcome = l2$outcome[j],
                                       km = round(d[j], if (d[j] < 10) 1 else 0)))
  }

  # ---- landing record and checks against our data ---------------------------
  landing <- NULL
  if (!is.null(land) && id %in% land$id) {
    L <- land[land$id == id, ]
    checks <- character()
    if (!is.null(crop)) {
      s <- crop$point
      checks <- c(checks, sprintf("LOLA 80 m slope at the recorded position: %.1f° (steepest within 100 m: %.1f°).", s$slope, s$slope_max_100m))
      if (L$outcome == "tipped" && s$slope_max_100m >= 8)
        checks <- c(checks, "The lander tipped over; our terrain data show the steep ground it came down on.")
      if (L$outcome == "tipped" && s$slope_max_100m < 8)
        checks <- c(checks, "The lander tipped over although the 80 m terrain is gentle here: the hazard (a small crater or rock) is smaller than one 80 m pixel. Final hazard checks need 1-5 m data.")
    }
    landing <- list(mission = L$mission, agency = L$agency, date = L$date, outcome = L$outcome, crewed = isTRUE(L$crewed),
                    note = L$note, checks = as.list(checks), ref = L$coord_source)
  } else if (!is_landing && !is.null(land)) {
    hit <- land[land$outcome != "planned" & gc_km(me_p$lat, me_p$lon_e, land$lat, land$lon) < 1, ]
    if (nrow(hit)) {
      checks <- character()
      if (!is.null(crop) && hit$outcome[1] == "tipped" && crop$point$slope_max_100m < 8)
        checks <- sprintf("LOLA 80 m slope here is only %.1f° (steepest within 100 m: %.1f°), yet the lander tipped over: the hazard was smaller than one 80 m pixel. Final hazard checks need 1-5 m data.", crop$point$slope, crop$point$slope_max_100m)
      landing <- list(mission = hit$mission[1], agency = hit$agency[1], date = hit$date[1], outcome = hit$outcome[1],
                      crewed = FALSE, note = paste("This candidate point is the measured landing position.", hit$note[1]),
                      checks = as.list(checks), ref = hit$coord_source[1], here = TRUE)
    }
  }


  rk_rows <- merge(sc, analyse_points(win, pts), by = "id", sort = FALSE); attr(rk_rows, "slope_limit") <- slope_limit
  ex <- explain_site(id, rk_rows, pts, mission, g)
  rh <- mission$analysis$robust$sites$rank_hist
  robust <- if (!is.null(rh) && id %in% rh$id) list(hist = unname(unlist(rh[rh$id == id, -1])),
    scenarios = mission$analysis$robust$sites$scenarios, limits = mission$analysis$robust$sites$slope_limits_deg) else NULL
  site_row <- sites[sites$id == id, ]

  list(
    id = id, name = me_p$name,
    kind = if (is_landing) "landing" else if (id == "USR") "custom" else "candidate",
    lat = round(me_p$lat, 4), lon = round(me_p$lon_e, 4),
    status = if (nrow(site_row)) site_row$region_status else NULL,
    scorable = scorable, score = if (scorable) round(me$score, 1) else NULL, rank = if (!is.na(me$rank)) me$rank else NULL,
    n_sites = nrow(site_sc), site_range = round(range(site_sc$score), 1), terrain_src = me$terrain_src,
    verdict = verdict, criteria = crit,
    window = list(horizon = attr(g, "horizon") %||% "smooth", start = format(win$utc[1], "%d %b %Y"), end = format(win$utc[nrow(win)], "%d %b %Y"), hours = nrow(win),
                  sun = round(wm$sun_pct, 1), earth = round(wm$earth_pct, 1), night = wm$max_night_h, blackout = wm$max_blackout_h,
                  strip = hour_strip(g), best = if (!is.null(ex$window)) list(start = format(ex$window$start, "%d %b %H:%M"), hours = ex$window$hours) else NULL),
    year = year_profile(mission$eph, start, me_p$lat, me_p$lon_e),
    crop = crop, near = near, landing = landing, robust = robust,
    strengths = lapply(ex$strengths, `[[`, "text"), weaknesses = lapply(ex$weaknesses, `[[`, "text"),
    refs = list(lola = ref_num(src, "lola_pgda"), mazarico = ref_num(src, "mazarico2011"), de421 = ref_num(src, "de421"),
                nssdca = ref_num(src, "nssdca_artifacts")))
}

ref_num <- function(src, id) { k <- which(src$sources$id == id); if (length(k)) k[1] else NA_integer_ }

# =============================================================================
# NEURON Lunar Navigator - data layer
# -----------------------------------------------------------------------------
# Read-only packaged data. No secrets, no network calls at app start.
#   data/sites.csv                         candidate points + literature values
#   data/sources.json                      provenance registry (every value cites an id)
#   data/processed/ephemeris_moon_me_1h.csv.gz
#                                          Sun/Earth vectors, Moon ME frame (DE421)
#   data/processed/ephemeris_validation.json
#                                          QA of the ephemeris build
# Regenerate processed data with data-raw/build_ephemeris.py.
# =============================================================================

MOON_RADIUS_KM <- 1737.4
DEG <- pi / 180

load_mission_data <- function(path = "data") {
  sources <- jsonlite::fromJSON(file.path(path, "sources.json"), simplifyVector = TRUE)
  sites <- utils::read.csv(file.path(path, "sites.csv"), stringsAsFactors = FALSE,
                           encoding = "UTF-8", na.strings = c("", "NA"))
  eph <- utils::read.csv(file.path(path, "processed", "ephemeris_moon_me_1h.csv.gz"),
                         colClasses = c("character", rep("numeric", 6)))
  eph$utc <- as.POSIXct(eph$utc, format = "%Y-%m-%dT%H:%MZ", tz = "UTC")
  validation <- jsonlite::fromJSON(file.path(path, "processed", "ephemeris_validation.json"))

  # ---- integrity checks: fail loudly, never substitute data ---------------
  src_ids <- sources$sources$id
  stopifnot(
    all(c("id", "name", "lat", "lon_e", "coord_source") %in% names(sites)),
    !anyDuplicated(sites$id),
    all(is.finite(sites$lat)), all(abs(sites$lat) <= 90),
    all(sites$lon_e >= 0 & sites$lon_e < 360),
    all(sites$coord_source %in% src_ids),
    all(is.na(sites$lit_illum_source) | sites$lit_illum_source %in% src_ids),
    all(is.na(sites$lit_illum_pct) | (sites$lit_illum_pct >= 0 & sites$lit_illum_pct <= 100)),
    !anyNA(eph$utc), !is.unsorted(eph$utc),
    all(abs(sqrt(eph$sun_x^2 + eph$sun_y^2 + eph$sun_z^2) - 1) < 1e-4),
    isTRUE(validation$passed)
  )
  terrain <- load_terrain(path)
  ml <- load_ml(path)
  f_reg <- file.path(path, "processed", "artemis_regions.json")
  regions <- if (file.exists(f_reg)) jsonlite::fromJSON(f_reg, simplifyVector = FALSE) else NULL
  if (!is.null(regions)) sources$sources$status[sources$sources$id == "mcclernan2024"] <- "ingested"
  if (!is.null(terrain)) sources$sources$status[sources$sources$id == "lola_pgda"] <- "ingested"
  if (!is.null(terrain$illum)) sources$sources$status[sources$sources$id == "mazarico2011"] <- "ingested"
  landings <- load_landings(path, src_ids)
  dossiers <- load_dossiers(path)
  has_hz <- load_horizons(path)
  list(has_horizons = has_hz, sites = sites, sources = sources, eph = eph, validation = validation, terrain = terrain, ml = ml, regions = regions,
       analysis = load_analysis(path), landings = landings, dossiers = dossiers)
}

# Previous (and one planned) lunar landings: NASA NSSDCA artifact table, see data/sources.json
load_landings <- function(path = "data", src_ids = NULL) {
  f <- file.path(path, "landings.csv"); if (!file.exists(f)) return(NULL)
  l <- utils::read.csv(f, stringsAsFactors = FALSE, encoding = "UTF-8")
  stopifnot(!anyDuplicated(l$id), all(abs(l$lat) <= 90), all(abs(l$lon) <= 180),
            all(l$outcome %in% c("landed", "tipped", "crashed", "planned")),
            is.null(src_ids) || all(l$coord_source %in% src_ids))
  l
}

# High-resolution windows around sites and south-polar landings (data-raw/build_dossiers.R)
load_dossiers <- function(path = "data") {
  f <- file.path(path, "processed", "dossiers.json.gz"); if (!file.exists(f)) return(NULL)
  con <- gzfile(f); on.exit(close(con))
  jsonlite::fromJSON(paste(readLines(con, warn = FALSE), collapse = ""), simplifyVector = TRUE)
}

# Evidence from data-raw/analysis_regions.R and analysis_robustness.R (optional)
load_analysis <- function(path = "data") {
  f <- file.path(path, "processed", c("deep_dive_nr2.json", "nr2_published_points.csv", "region_stats.csv", "robustness.json"))
  if (!all(file.exists(f))) return(NULL)
  list(deep = jsonlite::fromJSON(f[1]), points = utils::read.csv(f[2]), regions = utils::read.csv(f[3], stringsAsFactors = FALSE),
       robust = jsonlite::fromJSON(f[4]))
}

# ML products from data-raw/build_ml.R (optional)
load_ml <- function(path = "data") {
  f <- file.path(path, "processed", c("ml_grid.csv.gz", "ml_model_card.json", "artemis_regions.json"))
  if (!all(file.exists(f))) return(NULL)
  grid <- utils::read.csv(f[1])
  stopifnot(nrow(grid) == TERRAIN_GRID_N^2, "ml_score" %in% names(grid))
  list(grid = grid, card = jsonlite::fromJSON(f[2]), regions = jsonlite::fromJSON(f[3], simplifyVector = FALSE))
}

# Terrain products from data-raw/build_terrain.R (LOLA, Barker et al. 2023).
# Optional: the app runs without them and shows "Pipeline planned" instead.
TERRAIN_GRID_N <- 400
load_terrain <- function(path = "data") {
  f_grid <- file.path(path, "processed", "terrain_grid.csv.gz")
  f_site <- file.path(path, "processed", "site_terrain.csv")
  f_prov <- file.path(path, "processed", "terrain_provenance.json")
  if (!all(file.exists(c(f_grid, f_site, f_prov)))) return(NULL)
  grid <- utils::read.csv(f_grid)
  site <- utils::read.csv(f_site, stringsAsFactors = FALSE)
  prov <- jsonlite::fromJSON(f_prov)
  stopifnot(nrow(grid) == TERRAIN_GRID_N^2,
            all(c("slope_median", "flat_lt5", "flat_lt8", "flat_lt10", "flat_lt15") %in% names(grid)),
            all(grid$slope_median >= 0 | is.na(grid$slope_median)),
            all(c("id", "slope_mean_1km", "flat_lt8_1km") %in% names(site)))
  f_ig <- file.path(path, "processed", "illum_grid.csv.gz")
  f_is <- file.path(path, "processed", "site_illum.csv")
  illum <- NULL
  if (file.exists(f_ig) && file.exists(f_is)) {
    ig <- utils::read.csv(f_ig); is <- utils::read.csv(f_is, stringsAsFactors = FALSE)
    stopifnot(nrow(ig) == TERRAIN_GRID_N^2, all(c("sun_avg", "earth_avg", "psr_pct") %in% names(ig)),
              all(c("id", "sun_avg_point", "earth_avg_point") %in% names(is)))
    f_iv <- file.path(path, "processed", "illum_validation.json")
    illum <- list(grid = ig, site = is, validation = if (file.exists(f_iv)) jsonlite::fromJSON(f_iv) else NULL)
  }
  list(grid = grid, site = site, prov = prov, n = TERRAIN_GRID_N, illum = illum)
}

# Index of the terrain-grid cell that contains a lat/lon point (NA outside 80-90 S).
terrain_cell <- function(lat, lon, n = TERRAIN_GRID_N, extent = HEAT_EXTENT_DEG) {
  r <- (90 + lat) / extent * 0.5
  if (is.na(r) || r > 0.5) return(NA_integer_)
  u <- 0.5 + r * cos(lon * DEG); v <- 0.5 + r * sin(lon * DEG)
  j <- min(n, max(1, ceiling(u * n))); k <- min(n, max(1, ceiling(v * n)))
  (k - 1) * n + j
}

# Bilinear resampling of a row-major n x n grid to m x m (same UV convention).
resample_grid <- function(x, n, m) {
  z <- matrix(x, n, n, byrow = TRUE)                    # z[row k (v), col j (u)]
  pos <- ((seq_len(m) - 0.5) / m) * n + 0.5             # target centres in source index units
  i0 <- pmin(pmax(floor(pos), 1), n - 1); f <- pmin(pmax(pos - i0, 0), 1)
  out <- matrix(NA_real_, m, m)
  for (a in seq_len(m)) {
    r1 <- z[i0[a], ]; r2 <- z[i0[a] + 1, ]
    row <- (1 - f[a]) * r1 + f[a] * r2
    out[a, ] <- (1 - f) * row[i0] + f * row[i0 + 1]
  }
  as.vector(t(out))
}

# Slice the hourly ephemeris to a mission window ------------------------------
eph_window <- function(eph, start, hours) {
  t0 <- as.POSIXct(paste(format(start), "00:00"), tz = "UTC")
  eph[eph$utc >= t0 & eph$utc < t0 + hours * 3600, , drop = FALSE]
}

# Local topocentric geometry for one surface point -----------------------------
# With terrain = TRUE and a horizon available (80 to 90 deg S), sun_el / earth_el are
# elevations ABOVE THE REAL SKYLINE (LOLA terrain horizon); the geometric values stay
# in sun_el_geo / earth_el_geo. Otherwise the horizon is the plane tangent to the sphere.
site_geometry <- function(win, lat, lon, terrain = TRUE) {
  g <- site_geometry_smooth(win, lat, lon)
  hz <- if (terrain) point_horizon(lat, lon) else NULL
  g$sun_el_geo <- g$sun_el; g$earth_el_geo <- g$earth_el
  g$sun_hz <- 0; g$earth_hz <- 0
  if (!is.null(hz)) {
    g$sun_hz <- horizon_at(hz$hz, g$sun_az); g$earth_hz <- horizon_at(hz$hz, g$earth_az)
    g$sun_el <- g$sun_el - g$sun_hz; g$earth_el <- g$earth_el - g$earth_hz
  }
  attr(g, "horizon") <- if (is.null(hz)) "smooth" else hz$src
  g
}

site_geometry_smooth <- function(win, lat, lon) {
  la <- lat * DEG; lo <- lon * DEG
  up <- c(cos(la) * cos(lo), cos(la) * sin(lo), sin(la))
  east <- c(-sin(lo), cos(lo), 0)
  north <- c(-sin(la) * cos(lo), -sin(la) * sin(lo), cos(la))
  p <- MOON_RADIUS_KM * up

  s <- cbind(win$sun_x, win$sun_y, win$sun_z)               # unit vectors
  e <- cbind(win$earth_x_km - p[1], win$earth_y_km - p[2], win$earth_z_km - p[3])
  e_rng <- sqrt(rowSums(e^2)); e <- e / e_rng                # topocentric (parallax)

  elaz <- function(u) {
    el <- asin(pmin(1, pmax(-1, u %*% up))) / DEG
    az <- (atan2(u %*% east, u %*% north) / DEG) %% 360
    list(el = as.vector(el), az = as.vector(az))
  }
  sun <- elaz(s); earth <- elaz(e)
  data.frame(utc = win$utc, sun_el = sun$el, sun_az = sun$az,
             earth_el = earth$el, earth_az = earth$az, earth_range_km = e_rng)
}

longest_run_hours <- function(x) {
  if (!length(x) || !any(x)) return(0)
  r <- rle(x); max(r$lengths[r$values])
}

window_metrics <- function(g) {
  sun_up <- g$sun_el > 0; earth_up <- g$earth_el > 0
  data.frame(
    sun_pct = 100 * mean(sun_up),
    earth_pct = 100 * mean(earth_up),
    both_pct = 100 * mean(sun_up & earth_up),
    max_night_h = longest_run_hours(!sun_up),
    max_blackout_h = longest_run_hours(!earth_up),
    sun_el_max = max(g$sun_el),
    earth_el_max = max(g$earth_el),
    earth_range_min = min(g$earth_range_km),
    earth_range_max = max(g$earth_range_km)
  )
}

analyse_points <- function(win, points) {
  rows <- lapply(seq_len(nrow(points)), function(i) {
    cbind(id = points$id[i], window_metrics(site_geometry(win, points$lat[i], points$lon_e[i])))
  })
  do.call(rbind, rows)
}

# Landing-site score ------------------------------------------------------------
# WHERE to land is decided only by terrain-aware data:
#   terrain  share of the ground within 1 km below the slope limit (LOLA 80 m)
#   sun      18.6-year average Sun visibility with terrain shadowing (Mazarico et al. 2011)
#   earth    18.6-year average Earth visibility with terrain (Mazarico et al. 2011)
# All three are percentages, so the score is their weighted mean (0-100). It is
# absolute: adding or removing a place never changes another place's score.
# This is the same formula as the "Landing suitability" map and the region analysis.
# WHEN to land (mission window, DE421 geometry on a smooth Moon) is reported
# separately and does not enter the score.
SCORE_CRITERIA <- data.frame(
  key   = c("terrain", "sun", "earth"),
  col   = c("flat_pct", "lt_sun", "lt_earth"),
  label = c("Flat ground", "Sunlight, long-term", "Earth in view, long-term"),
  stringsAsFactors = FALSE)

# Criteria for every point. Published sites and south-polar landings: every original
# pixel within 1 km (data-raw/build_dossiers.R). Other points: the ~1.5 km grid cell.
point_criteria <- function(points, terrain, dossiers, slope_limit = 8) {
  out <- data.frame(id = points$id, flat_pct = NA_real_, lt_sun = NA_real_, lt_earth = NA_real_,
                    slope_deg = NA_real_, terrain_src = NA_character_, stringsAsFactors = FALSE)
  key <- paste0("lt", slope_limit)
  for (i in seq_len(nrow(points))) {
    id <- points$id[i]
    if (!is.null(dossiers) && id %in% names(dossiers$points)) {
      q <- dossiers$points[[id]]$point
      out[i, c("flat_pct", "lt_sun", "lt_earth", "slope_deg")] <- c(q$flat_1km[[key]], q$sun, q$earth, q$slope_mean_1km)
      out$terrain_src[i] <- "1 km radius"
    } else if (!is.null(terrain)) {
      cell <- terrain_cell(points$lat[i], points$lon_e[i])
      if (!is.na(cell) && !is.na(terrain$grid$slope_median[cell])) {
        out$flat_pct[i] <- terrain$grid[[paste0("flat_lt", slope_limit)]][cell]
        out$slope_deg[i] <- terrain$grid$slope_median[cell]
        if (!is.null(terrain$illum)) { out$lt_sun[i] <- terrain$illum$grid$sun_avg[cell]; out$lt_earth[i] <- terrain$illum$grid$earth_avg[cell] }
        out$terrain_src[i] <- "~1.5 km cell"
      }
    }
  }
  out
}

# weights: named c(terrain, sun, earth); returns criteria + score + rank among the published sites
score_points <- function(crit, weights, site_ids) {
  w <- weights[SCORE_CRITERIA$key]; if (sum(w) == 0) w[] <- 1
  X <- as.matrix(crit[, SCORE_CRITERIA$col])
  crit$score <- as.vector(X %*% w) / sum(w)
  crit$rank <- NA_integer_
  k <- crit$id %in% site_ids & !is.na(crit$score)
  crit$rank[k] <- rank(-crit$score[k], ties.method = "min")
  crit
}

# Visibility raster over the south-polar region ------------------------------
# Grid in azimuthal-equidistant polar coordinates (same UV convention as the
# cap texture: u -> 0°E, v -> 90°E, centre = pole). Returns row-major values
# with row k at v = (k + .5)/n, i.e. ready for a WebGL DataTexture.
HEAT_EXTENT_DEG <- 10
heat_grid <- function(win, n = 120, extent = HEAT_EXTENT_DEG) {
  c0 <- (seq_len(n) - 0.5) / n - 0.5
  g <- expand.grid(u = c0, v = c0)              # u varies fastest -> row-major in v
  r <- sqrt(g$u^2 + g$v^2)
  inside <- r <= 0.5 * sqrt(2)                  # full square; the viewer masks the disc
  lat <- (-90 + r / 0.5 * extent) * DEG
  lon <- atan2(g$v, g$u)
  U <- cbind(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))[inside, , drop = FALSE]
  S <- cbind(win$sun_x, win$sun_y, win$sun_z)
  E <- cbind(win$earth_x_km, win$earth_y_km, win$earth_z_km)
  sun_up <- (U %*% t(S)) > 0                     # Sun at infinity (parallax < 0.001°)
  earth_up <- (U %*% t(E)) > MOON_RADIUS_KM      # (E - R·U)·U > 0
  out <- function(x) { v <- rep(NA_real_, n * n); v[inside] <- round(x, 1); v }
  list(n = n, extent = extent,
       sun = out(100 * rowMeans(sun_up)),
       earth = out(100 * rowMeans(earth_up)),
       both = out(100 * rowMeans(sun_up & earth_up)))
}

# Whole-Moon visibility raster (equirectangular, row k at latitude -90 + (k+.5)*180/h,
# column j at longitude -180 + (j+.5)*360/w; matches SphereGeometry UVs). Chunked to
# keep memory low. Terrain-free geometry, same method as heat_grid().
global_grid <- function(win, w = 240, h = 120) {
  lat <- (-90 + (seq_len(h) - 0.5) * 180 / h) * DEG
  lon <- (-180 + (seq_len(w) - 0.5) * 360 / w) * DEG
  g <- expand.grid(lon = lon, lat = lat)                 # lon fastest -> row-major by latitude
  U <- cbind(cos(g$lat) * cos(g$lon), cos(g$lat) * sin(g$lon), sin(g$lat))
  S <- t(cbind(win$sun_x, win$sun_y, win$sun_z))
  E <- t(cbind(win$earth_x_km, win$earth_y_km, win$earth_z_km))
  sun <- earth <- both <- numeric(nrow(U))
  for (idx in split(seq_len(nrow(U)), ceiling(seq_len(nrow(U)) / 4000))) {
    su <- (U[idx, , drop = FALSE] %*% S) > 0
    eu <- (U[idx, , drop = FALSE] %*% E) > MOON_RADIUS_KM
    sun[idx] <- rowMeans(su); earth[idx] <- rowMeans(eu); both[idx] <- rowMeans(su & eu)
  }
  list(w = w, h = h, sun = round(100 * sun, 1), earth = round(100 * earth, 1), both = round(100 * both, 1))
}

# Landing suitability (0-100) on the terrain grid ----------------------------
# Weighted mean of three normalised layers, each 0-100:
#   flat  = share of the cell below the slope limit (LOLA)
#   sun   = share of window hours with the Sun above the horizon (DE421)
#   earth = share of window hours with Earth above the horizon (DE421)
# With Mazarico et al. (2011) maps available, sun/earth are the terrain-aware
# 18.6-year averages; otherwise the terrain-free mission-window geometry.
suitability_grid <- function(hg, terrain, w_sun, w_earth, w_terrain, slope_limit = 8) {
  n <- terrain$n
  flat <- terrain$grid[[paste0("flat_lt", slope_limit)]]
  if (!is.null(terrain$illum)) { sun <- terrain$illum$grid$sun_avg; earth <- terrain$illum$grid$earth_avg }
  else { sun <- resample_grid(hg$sun, hg$n, n); earth <- resample_grid(hg$earth, hg$n, n) }
  w <- c(w_sun, w_earth, w_terrain); if (sum(w) == 0) w <- c(1, 1, 1)
  s <- (w[1] * sun + w[2] * earth + w[3] * flat) / sum(w)
  list(n = n, extent = HEAT_EXTENT_DEG, values = round(s, 1), flat = flat)
}

# Provider adapters for planned datasets (LOLA, Mazarico 2011, USGS grids). ----
# Call only from preprocessing scripts; never from the running app.
fetch_provider <- function(provider, ...) {
  stop(sprintf("Provider '%s' is not connected. Implement and validate its adapter in data-raw/ first.", provider))
}

# =============================================================================
# Terrain horizons (LOLA 80 m DEM)
#   data/processed/horizons_sites.json  exact 360-deg horizons, curated sites + polar landings
#   data/processed/horizon_mlp.json     small neural network (ML surrogate) + scaler
#   data/processed/dem_1280m.bin.gz     475 x 475 DEM (int16, m) used by the surrogate
# Built by data-raw/build_horizons.py and data-raw/train_horizon_ml.py.
# Every point within the DEM (80 to 90 deg S) gets a horizon: exact for the curated
# sites and landings, predicted by the surrogate for any other point.
# =============================================================================
HZ <- new.env()

load_horizons <- function(path = "data") {
  f1 <- file.path(path, "processed", "horizons_sites.json")
  f2 <- file.path(path, "processed", "horizon_mlp.json")
  f3 <- file.path(path, "processed", "dem_1280m.bin.gz")
  HZ$exact <- NULL; HZ$model <- NULL; HZ$cache <- list()
  if (file.exists(f1)) {
    j <- jsonlite::fromJSON(f1, simplifyVector = TRUE)
    HZ$exact <- lapply(j$points, function(p) list(lat = p$lat, lon = p$lon, hz = as.numeric(p$horizon_deg), name = p$name))
    HZ$meta <- j[setdiff(names(j), "points")]
  }
  if (file.exists(f2) && file.exists(f3)) {
    m <- jsonlite::fromJSON(f2, simplifyVector = FALSE)
    con <- gzfile(f3, "rb"); n <- m$dem$n
    z <- readBin(con, "integer", n = n * n, size = 2, signed = TRUE, endian = "little"); close(con)
    HZ$model <- list(W = lapply(m$weights, function(w) do.call(rbind, lapply(w, unlist))),
                     b = lapply(m$biases, unlist), mu = unlist(m$scaler_mean), sd = unlist(m$scaler_scale),
                     d = unlist(m$feature_distances_m), n = n, px = m$dem$px_m, x0 = m$dem$x0_m,
                     z = matrix(as.numeric(z), n, n, byrow = TRUE), h_obs = m$observer_height_m)
  }
  invisible(!is.null(HZ$exact) || !is.null(HZ$model))
}

.hz_R <- 1737400
.ll_xy <- function(lat, lon) { rho <- 2 * .hz_R * tan((90 + lat) * DEG / 2); cbind(rho * sin(lon * DEG), rho * cos(lon * DEG)) }
.hz_sample <- function(m, x, y) {                       # bilinear, pixel-registered; NA outside
  col <- (x - m$x0) / m$px - 0.5; row <- (-m$x0 - y) / m$px - 0.5
  ok <- col >= 0 & col <= m$n - 1 & row >= 0 & row <= m$n - 1
  c0 <- pmin(pmax(floor(col), 0), m$n - 2); r0 <- pmin(pmax(floor(row), 0), m$n - 2)
  a <- col - c0; b <- row - r0
  v <- (1 - a) * (1 - b) * m$z[cbind(r0 + 1, c0 + 1)] + a * (1 - b) * m$z[cbind(r0 + 1, c0 + 2)] +
       (1 - a) * b * m$z[cbind(r0 + 2, c0 + 1)] + a * b * m$z[cbind(r0 + 2, c0 + 2)]
  ifelse(ok, v, NA_real_)
}
.hz_dest <- function(lat, lon, az, d) {                 # great-circle destination (deg)
  p1 <- lat * DEG; l1 <- lon * DEG; a <- az * DEG; g <- d / .hz_R
  sp2 <- sin(p1) * cos(g) + cos(p1) * sin(g) * cos(a)
  p2 <- asin(pmin(1, pmax(-1, sp2)))
  l2 <- l1 + atan2(sin(a) * sin(g) * cos(p1), cos(g) - sin(p1) * sp2)
  list(lat = p2 / DEG, lon = l2 / DEG)
}

# Surrogate horizon (deg) at 360 azimuths: same features as horizon_lib.features_coarse()
predict_horizon <- function(lat, lon, az = 0:359) {
  m <- HZ$model; if (is.null(m)) return(NULL)
  p0 <- .ll_xy(lat, lon); z0 <- .hz_sample(m, p0[1], p0[2]); if (is.na(z0)) return(NULL)
  r_o <- .hz_R + z0 + m$h_obs
  AZ <- rep(az, each = length(m$d)); DD <- rep(m$d, times = length(az))
  q <- .hz_dest(lat, lon, AZ, DD); xy <- .ll_xy(q$lat, q$lon)
  zt <- .hz_sample(m, xy[, 1], xy[, 2]); g <- DD / .hz_R
  th <- atan2((.hz_R + zt) * cos(g) - r_o, (.hz_R + zt) * sin(g)) / DEG
  th[is.na(th)] <- -5
  TH <- matrix(th, nrow = length(az), byrow = TRUE)
  ring <- .hz_sample(m, p0[1] + c(-1, 0, 1, -1, 0, 1, -1, 0, 1) * m$px, p0[2] + c(-1, -1, -1, 0, 0, 0, 1, 1, 1) * m$px)
  relief <- sqrt(sum((ring - mean(ring, na.rm = TRUE))^2, na.rm = TRUE) / sum(!is.na(ring)))   # population sd (= numpy)
  base <- apply(TH, 1, max)
  X <- cbind(TH, base, z0, relief, 90 + lat, sin(az * DEG), cos(az * DEG))
  X <- sweep(sweep(X, 2, m$mu), 2, m$sd, "/")
  h <- X
  for (k in seq_along(m$W)) { h <- sweep(h %*% m$W[[k]], 2, m$b[[k]], "+"); if (k < length(m$W)) h[h < 0] <- 0 }
  base + as.vector(h)
}

# Horizon for any point: exact if it is a curated site / landing, else surrogate, else NULL
point_horizon <- function(lat, lon) {
  if (!is.finite(lat) || lat > -80) return(NULL)
  lon <- lon %% 360
  for (p in HZ$exact) if (abs(p$lat - lat) < 1e-5 && abs((p$lon %% 360) - lon) < 1e-5) return(list(hz = p$hz, src = "exact"))
  key <- sprintf("%.5f_%.5f", lat, lon)
  if (!is.null(HZ$cache[[key]])) return(HZ$cache[[key]])
  h <- predict_horizon(lat, lon); if (is.null(h)) return(NULL)
  out <- list(hz = h, src = "model"); HZ$cache[[key]] <- out; out
}

horizon_at <- function(hz, az) {
  a <- az %% 360; i0 <- floor(a); f <- a - i0
  hz[i0 %% 360 + 1] * (1 - f) + hz[(i0 + 1) %% 360 + 1] * f
}

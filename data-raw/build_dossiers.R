#!/usr/bin/env Rscript
# =============================================================================
# NEURON Lunar Navigator - site dossiers from the ORIGINAL rasters
# -----------------------------------------------------------------------------
# For every candidate site (data/sites.csv) and every previous or planned
# landing inside the LOLA 80-90 S coverage (data/landings.csv) this script cuts
# a 12.8 x 12.8 km window around the point and stores
#   slope      LOLA LDSM_80S_80MPP_ADJ, native 80 m pixels           (deg)
#   relief     LOLA LDEM_80S_80MPP_ADJ_HILL, native 80 m pixels       (0-255)
#   sun, earth Mazarico et al. 2011 AVGVISIB_75S_120M (+_EARTH),
#              bilinear onto the same 80 m grid                         (% of time)
# plus point statistics (slope at the point and within 100 m, slope histogram
# within 2 km, permanent shadow within 2 km, the best flat spot within 3 km).
#
# Inputs : data-raw/input/ (see README there), data/sites.csv, data/landings.csv
# Output : data/processed/dossiers.json.gz
# Run    : Rscript data-raw/build_dossiers.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(jsonlite) })
MOON_LL <- "+proj=longlat +R=1737400 +no_defs"
HALF <- 6400; RES <- 80; NPX <- 2 * HALF / RES

pick <- function(pat) list.files("data-raw/input", pattern = pat, ignore.case = TRUE, full.names = TRUE)[1]
r_slope <- rast(pick("^LDSM_80S_80MPP_ADJ\\.tiff?$"))
r_hill  <- rast(pick("^LDEM_80S_80MPP_ADJ_HILL\\.tiff?$"))
r_sun   <- rast(pick("^AVGVISIB_75S_120M_201608\\.lbl$"))
r_earth <- rast(pick("^AVGVISIB_75S_120M_201608_EARTH\\.lbl$"))
stopifnot(grepl("lat_0=-90", crs(r_slope, proj = TRUE)), grepl("lat_0=-90", crs(r_sun, proj = TRUE)))

sites <- utils::read.csv("data/sites.csv", stringsAsFactors = FALSE)
land <- utils::read.csv("data/landings.csv", stringsAsFactors = FALSE)
land <- land[land$lat <= -80, ]
pts <- rbind(data.frame(id = sites$id, name = sites$name, kind = "candidate", lat = sites$lat, lon = sites$lon),
             data.frame(id = land$id, name = land$mission, kind = land$outcome, lat = land$lat, lon = land$lon))

enc <- function(x, k) { y <- round(x * k); y[is.na(y)] <- -1; as.integer(y) }

one <- function(i) {
  p <- pts[i, ]
  xy <- project(cbind(p$lon, p$lat), from = MOON_LL, to = crs(r_slope))
  xy_i <- project(cbind(p$lon, p$lat), from = MOON_LL, to = crs(r_sun))
  # template aligned to the LOLA pixel grid
  ox <- xFromCol(r_slope, colFromX(r_slope, xy[1])); oy <- yFromRow(r_slope, rowFromY(r_slope, xy[2]))
  tpl <- rast(ext(ox - HALF, ox + HALF, oy - HALF, oy + HALF), resolution = RES, crs = crs(r_slope))
  sl <- resample(crop(r_slope, tpl, snap = "out"), tpl, method = "near")
  hl <- resample(crop(r_hill, tpl, snap = "out"), tpl, method = "near")
  su <- project(r_sun, tpl, method = "bilinear") * 100
  ea <- project(r_earth, tpl, method = "bilinear") * 100
  su0 <- project(r_sun, tpl, method = "near")            # for permanent shadow (DN = 0)
  vs <- values(sl)[, 1]; vh <- values(hl)[, 1]; vu <- values(su)[, 1]; ve <- values(ea)[, 1]; v0 <- values(su0)[, 1]

  cx <- xFromCol(tpl, seq_len(NPX)); cy <- yFromRow(tpl, seq_len(NPX))
  dx <- rep(cx, times = NPX) - xy[1]; dy <- rep(cy, each = NPX) - xy[2]; d <- sqrt(dx^2 + dy^2)
  at <- which.min(d)
  r2 <- d <= 2000; r3 <- d <= 3000
  hist2 <- tabulate(pmin(floor(vs[r2 & !is.na(vs)]), 30) + 1, 31)
  flat <- function(L, m) round(100 * mean(vs[m] < L, na.rm = TRUE), 1)

  # best flat spot within 3 km: slope < 5 deg everywhere within 100 m, maximise mean(sun, earth)
  k100 <- -2:2; w100 <- outer(k100, k100, function(a, b) ifelse(sqrt(a^2 + b^2) * RES <= 100, 1, NA))  # 80 m pixels within 100 m
  smax100 <- focal(sl, w = w100, fun = "max", na.rm = TRUE)
  vm <- values(smax100)[, 1]
  cand <- which(r3 & vm < 5 & !is.na(vu) & !is.na(ve))
  best <- NULL
  if (length(cand)) {
    k <- cand[which.max((vu[cand] + ve[cand]) / 2)]
    best <- list(dx_m = round(dx[k]), dy_m = round(dy[k]), dist_m = round(d[k]), slope = round(vs[k], 1),
                 slope_max_100m = round(vm[k], 1), sun = round(vu[k], 1), earth = round(ve[k], 1))
  }
  # unit vector towards the pole in image coordinates (x right, y up)
  pole <- -xy[1:2] / sqrt(sum(xy[1:2]^2))

  list(id = p$id, name = p$name, kind = p$kind, lat = p$lat, lon = p$lon,
       n = NPX, res_m = RES, half_m = HALF, pole_dir = round(pole, 4),
       # point values: bilinear at the exact coordinate in the ORIGINAL 120 m rasters (same as build_terrain.R)
       point = list(slope = round(vs[at], 1), slope_max_100m = round(max(vs[d <= 100], na.rm = TRUE), 1),
                    slope_mean_1km = round(mean(vs[d <= 1000], na.rm = TRUE), 2),
                    flat_1km = setNames(as.list(sapply(c(5, 8, 10, 15), function(L) round(100 * mean(vs[d <= 1000] < L, na.rm = TRUE), 1))), paste0("lt", c(5, 8, 10, 15))),
                    sun = round(100 * extract(r_sun, xy_i, method = "bilinear")[, 1], 1),
                    earth = round(100 * extract(r_earth, xy_i, method = "bilinear")[, 1], 1)),
       area_2km = list(flat_lt5 = flat(5, r2), flat_lt8 = flat(8, r2), flat_lt10 = flat(10, r2), flat_lt15 = flat(15, r2),
                       slope_median = round(median(vs[r2], na.rm = TRUE), 1), sun_mean = round(mean(vu[r2], na.rm = TRUE), 1),
                       earth_mean = round(mean(ve[r2], na.rm = TRUE), 1), psr_pct = round(100 * mean(v0[r2] == 0, na.rm = TRUE), 1),
                       slope_hist = hist2),
       best_nearby = best,
       # rows run from north (top, +y) to south; values as integers: slope x10, sun/earth x10, relief 0-255
       slope = enc(vs, 10), relief = enc(vh, 1), sun = enc(vu, 10), earth = enc(ve, 10))
}
out <- lapply(seq_len(nrow(pts)), function(i) { message(pts$name[i]); one(i) })
names(out) <- pts$id
for (o in out) message(sprintf("%-22s flat8 %5.1f mean1km %5.2f slope %5.1f  max100 %5.1f  sun %5.1f  earth %5.1f  psr2km %4.1f", o$name, o$point$flat_1km$lt8, o$point$slope_mean_1km, o$point$slope, o$point$slope_max_100m, o$point$sun, o$point$earth, o$area_2km$psr_pct))
con <- gzfile("data/processed/dossiers.json.gz", "w")
writeLines(toJSON(list(generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  window_km = 2 * HALF / 1000, res_m = RES, sources = c("lola_pgda", "mazarico2011"), points = out), auto_unbox = TRUE, digits = NA, null = "null"), con)
close(con); message("wrote data/processed/dossiers.json.gz")

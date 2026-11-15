#!/usr/bin/env Rscript
# =============================================================================
# NEURON Lunar Navigator - additional validation checks
# -----------------------------------------------------------------------------
# (A) External validity: does the landing score rate NASA's nine independently
#     selected Artemis regions (USGS outlines, McClernan 2024) higher than the
#     rest of the south-polar terrain at the same latitudes? Equal weights,
#     slope limit 8 deg, the app's ~1.5 km grid. Reported: score distributions,
#     medians and AUC (probability that a random cell inside a region scores
#     higher than a random cell outside; 0.5 = no difference).
# (B) Internal consistency: two independent code paths measure the same thing
#     around each published site: build_terrain.R (stratified samples, 1 km) and
#     build_dossiers.R (every 80 m pixel within 1 km).
#
# Inputs : data/processed/terrain_grid.csv.gz, illum_grid.csv.gz, site_terrain.csv,
#          dossiers.json.gz, data-raw/regions_usgs_1km/
# Output : data/processed/validation_checks.json
# Run    : Rscript data-raw/build_validation.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(jsonlite) })
MOON_LL <- "+proj=longlat +R=1737400 +no_defs"
N <- 400; EXTENT <- 10

tg <- utils::read.csv("data/processed/terrain_grid.csv.gz")
ig <- utils::read.csv("data/processed/illum_grid.csv.gz")
c0 <- (seq_len(N) - 0.5) / N; g <- expand.grid(u = c0, v = c0)
rr <- sqrt((g$u - 0.5)^2 + (g$v - 0.5)^2)
cell_ll <- cbind(lon = atan2(g$v - 0.5, g$u - 0.5) * 180 / pi, lat = -90 + rr / 0.5 * EXTENT)

# ---- (A) NASA regions vs. the rest ---------------------------------------------
score <- (tg$flat_lt8 + ig$sun_avg + ig$earth_avg) / 3
shps <- list.files("data-raw/regions_usgs_1km", pattern = "_1km_S_Grid\\.shp$", full.names = TRUE)
inside <- rep(FALSE, nrow(cell_ll))
for (f in shps) {
  reg <- aggregate(vect(f))
  inside <- inside | relate(vect(project(cell_ll, from = MOON_LL, to = crs(reg)), crs = crs(reg)), reg, "intersects")[, 1]
}
band <- range(cell_ll[inside, "lat"])
ok <- !is.na(score) & cell_ll[, "lat"] >= band[1] & cell_ll[, "lat"] <= band[2]
a <- score[ok & inside]; b <- score[ok & !inside]
auc <- (mean(rank(c(a, b))[seq_along(a)]) - (length(a) + 1) / 2) / length(b)   # Mann-Whitney U / (n_a n_b)
wt <- suppressWarnings(wilcox.test(a, b))
brks <- seq(0, 100, by = 5)
h <- function(x) as.vector(table(cut(x, brks, include.lowest = TRUE))) / length(x) * 100
per_crit <- lapply(list(flat_lt8 = tg$flat_lt8, sun = ig$sun_avg, earth = ig$earth_avg), function(v)
  list(inside = round(median(v[ok & inside], na.rm = TRUE), 1), outside = round(median(v[ok & !inside], na.rm = TRUE), 1)))
nasa <- list(
  lat_band = round(band, 2), n_inside = length(a), n_outside = length(b),
  median_inside = round(median(a), 1), median_outside = round(median(b), 1),
  share_inside_above_50 = round(100 * mean(a >= 50), 1), share_outside_above_50 = round(100 * mean(b >= 50), 1),
  auc = round(auc, 3), wilcoxon_p = signif(wt$p.value, 3),
  bins = brks, hist_inside = round(h(a), 2), hist_outside = round(h(b), 2), per_criterion = per_crit,
  note = "Equal weights, slope limit 8 deg, ~1.5 km grid cells, same latitude band as the nine regions. NASA also used criteria we do not model (science value, mission design), so a perfect separation is not expected.")
message(sprintf("NASA regions: median %.1f inside vs %.1f outside, AUC %.3f, p = %.2g", nasa$median_inside, nasa$median_outside, auc, wt$p.value))

# ---- (B) two code paths -----------------------------------------------------------
st <- utils::read.csv("data/processed/site_terrain.csv")
con <- gzfile("data/processed/dossiers.json.gz"); dz <- fromJSON(paste(readLines(con, warn = FALSE), collapse = "")); close(con)
cons <- do.call(rbind, lapply(st$id, function(i) {
  q <- dz$points[[i]]$point; s <- st[st$id == i, ]
  data.frame(id = i, name = dz$points[[i]]$name,
             slope_mean_terrain = s$slope_mean_1km, slope_mean_dossier = q$slope_mean_1km,
             flat8_terrain = s$flat_lt8_1km, flat8_dossier = q$flat_1km$lt8,
             n_samples_terrain = s$n_samples, n_pixels_dossier = round(pi * 1000^2 / 80^2))
}))
cons$d_slope <- round(cons$slope_mean_dossier - cons$slope_mean_terrain, 2)
cons$d_flat8 <- round(cons$flat8_dossier - cons$flat8_terrain, 1)
print(cons)

write_json(list(generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), nasa_regions = nasa,
                consistency = list(rows = cons, max_abs_d_slope = max(abs(cons$d_slope)), max_abs_d_flat8 = max(abs(cons$d_flat8)))),
           "data/processed/validation_checks.json", auto_unbox = TRUE, pretty = TRUE, digits = NA, dataframe = "rows")
message("wrote data/processed/validation_checks.json")

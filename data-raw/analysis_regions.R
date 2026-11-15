#!/usr/bin/env Rscript
# =============================================================================
# NEURON Lunar Navigator - region analysis from the ORIGINAL rasters
# -----------------------------------------------------------------------------
# (A) Statistics for each of the nine NASA candidate regions, computed on every
#     original pixel inside the USGS outline (LOLA slope 80 m, Mazarico 120 m) and,
#     for comparison, on the app's ~1.5 km analysis grid.
# (B) Deep dive Nobile Rim 2: re-evaluate the 12 Nobile Rim 2 (DM2) locations
#     published by Pena-Asensio et al. (2025, Acta Astronautica 226, 469-478,
#     Table 3) against the original rasters.
#     - Their C4 is the Mazarico et al. (2011) Earth-visibility map at 240 m/px,
#       reported as digital numbers (DN; 25000 DN = 100 %).
#     - Their HLS filter: slope 0-5 deg with a 100 m buffer.
#     - Their C3 = average solar illumination x share of permanent shadow within 2 km.
#
# Inputs : data-raw/input/ (LDSM_80S_80MPP_ADJ, AVGVISIB_75S_120M_201608 [+_EARTH]),
#          data-raw/regions_usgs_1km/, data/processed/terrain_grid.csv.gz, illum_grid.csv.gz
# Outputs: data/processed/region_stats.csv, nr2_published_points.csv, deep_dive_nr2.json
# Run:  source("data-raw/analysis_regions.R")
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(jsonlite) })
MOON_LL <- "+proj=longlat +R=1737400 +no_defs"
N <- 400; EXTENT <- 10; SLOPE_LIMITS <- c(5, 8, 10, 15)

pick <- function(pat) list.files("data-raw/input", pattern = pat, ignore.case = TRUE, full.names = TRUE)[1]
r_slope <- rast(pick("^LDSM_80S_80MPP_ADJ\\.tiff?$"))
r_sun <- rast(pick("^AVGVISIB_75S_120M_201608\\.lbl$"))
r_earth <- rast(pick("^AVGVISIB_75S_120M_201608_EARTH\\.lbl$"))
tg <- utils::read.csv("data/processed/terrain_grid.csv.gz")
ig <- utils::read.csv("data/processed/illum_grid.csv.gz")

# app grid cell centres
c0 <- (seq_len(N) - 0.5) / N; g <- expand.grid(u = c0, v = c0)
rr <- sqrt((g$u - 0.5)^2 + (g$v - 0.5)^2)
cell_ll <- cbind(lon = atan2(g$v - 0.5, g$u - 0.5) * 180 / pi, lat = -90 + rr / 0.5 * EXTENT)

shps <- list.files("data-raw/regions_usgs_1km", pattern = "_1km_S_Grid\\.shp$", full.names = TRUE)
name_of <- function(f) gsub("_", " ", sub("_PolarLGRS_ACC_1km_S_Grid\\.shp$", "", basename(f)))

# ---- (A) region statistics -----------------------------------------------------
region_rows <- list(); region_polys <- list()
for (f in shps) {
  nm <- name_of(f); message("region ", nm)
  reg <- aggregate(vect(f))
  region_polys[[nm]] <- reg
  sl <- extract(r_slope, project(reg, crs(r_slope)), ID = FALSE)[, 1]; sl <- sl[!is.na(sl)]
  su <- extract(r_sun, project(reg, crs(r_sun)), ID = FALSE)[, 1]; su <- su[!is.na(su)]
  ea <- extract(r_earth, project(reg, crs(r_earth)), ID = FALSE)[, 1]; ea <- ea[!is.na(ea)]
  inside <- relate(vect(project(cell_ll, from = MOON_LL, to = crs(reg)), crs = crs(reg)), reg, "intersects")[, 1]
  row <- data.frame(region = nm, area_km2 = round(expanse(reg) / 1e6 / 0.994^2),
    raw_slope_px = length(sl), raw_slope_median = median(sl),
    raw_flat_lt5 = 100 * mean(sl < 5), raw_flat_lt8 = 100 * mean(sl < 8),
    raw_flat_lt10 = 100 * mean(sl < 10), raw_flat_lt15 = 100 * mean(sl < 15),
    raw_illum_px = length(su), raw_sun_mean = 100 * mean(su), raw_sun_p90 = 100 * unname(quantile(su, 0.9)),
    raw_earth_mean = 100 * mean(ea), raw_psr_pct = 100 * mean(su == 0),
    grid_cells = sum(inside), grid_slope_median = median(tg$slope_median[inside], na.rm = TRUE),
    grid_flat_lt8 = mean(tg$flat_lt8[inside], na.rm = TRUE), grid_sun_mean = mean(ig$sun_avg[inside], na.rm = TRUE),
    grid_earth_mean = mean(ig$earth_avg[inside], na.rm = TRUE), grid_psr_pct = mean(ig$psr_pct[inside], na.rm = TRUE))
  region_rows[[nm]] <- row
}
rs <- do.call(rbind, region_rows); rownames(rs) <- NULL
num <- vapply(rs, is.numeric, TRUE); rs[num] <- lapply(rs[num], function(x) round(x, 2))
utils::write.csv(rs, "data/processed/region_stats.csv", row.names = FALSE)
print(rs[, c("region", "raw_slope_median", "grid_slope_median", "raw_flat_lt8", "grid_flat_lt8",
             "raw_sun_mean", "grid_sun_mean", "raw_earth_mean", "grid_earth_mean")])

# ---- (B) Nobile Rim 2: published locations -------------------------------------
dms <- function(d, m, s) d + m / 60 + s / 3600
pub <- data.frame(
  id = c(358, 356, 357, 354, 350, 355, 352, 351, 353, 995, 998, 1043),
  pena_rank = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 14, 16),
  lat = -c(dms(84, 12, 5.61), dms(84, 12, 2.71), dms(84, 11, 57.55), dms(84, 11, 59.82), dms(84, 11, 56.91),
           dms(84, 11, 54.65), dms(84, 11, 46.59), dms(84, 11, 51.75), dms(84, 11, 41.43), dms(84, 5, 2.79),
           dms(84, 2, 16.50), dms(83, 46, 3.73)),
  lon = c(dms(60, 41, 59.61), dms(60, 41, 8.51), dms(60, 41, 37.19), dms(60, 40, 17.42), dms(60, 39, 26.35),
          dms(60, 40, 46.11), dms(60, 40, 23.74), dms(60, 39, 55.05), dms(60, 40, 52.41), dms(55, 33, 15.48),
          dms(56, 50, 50.63), dms(56, 39, 32.63)),
  pena_ri = c(0.6916, 0.6869, 0.6711, 0.6684, 0.6610, 0.6487, 0.6455, 0.6408, 0.6220, 0.5353, 0.4916, 0.4373),
  pena_c3 = c(140592.7, 138178.2, 129545.1, 128637.8, 126065.2, 120518.5, 119584.2, 118202.8, 111646.1, 104013.3, 88687.8, 73931.0),
  pena_c4_dn = c(8315, 7746, 7746, 7746, 7016, 7746, 6935, 7016, 6935, 0, 13587, 12981))
ll <- cbind(lon = pub$lon, lat = pub$lat)
xy_s <- project(ll, from = MOON_LL, to = crs(r_slope)); xy_i <- project(ll, from = MOON_LL, to = crs(r_sun))
lattice <- function(radius, step) { d <- seq(-radius, radius, by = step); k <- expand.grid(dx = d, dy = d); k[sqrt(k$dx^2 + k$dy^2) <= radius, ] }
buf100 <- lattice(100, 20); r2km <- lattice(2000, 60)
nr2 <- region_polys[["Nobile Rim 2"]]
pub$inside_2024_outline <- relate(vect(project(ll, from = MOON_LL, to = crs(nr2)), crs = crs(nr2)), nr2, "intersects")[, 1]
for (i in seq_len(nrow(pub))) {
  pub$earth_pct_ours_120m[i] <- 100 * extract(r_earth, xy_i[i, , drop = FALSE], method = "bilinear")[1, 1]
  pub$sun_pct_ours_120m[i] <- 100 * extract(r_sun, xy_i[i, , drop = FALSE], method = "bilinear")[1, 1]
  pub$slope_point_80m[i] <- extract(r_slope, xy_s[i, , drop = FALSE], method = "bilinear")[1, 1]
  pub$slope_max_100m[i] <- max(extract(r_slope, cbind(xy_s[i, 1] + buf100$dx, xy_s[i, 2] + buf100$dy))[, 1], na.rm = TRUE)
  s2 <- extract(r_sun, cbind(xy_i[i, 1] + r2km$dx, xy_i[i, 2] + r2km$dy))[, 1]
  pub$psr_pct_2km[i] <- 100 * mean(s2 == 0, na.rm = TRUE)
}
pub$pena_earth_pct <- pub$pena_c4_dn * 0.00004 * 100               # DN -> percent (PDS scaling)
pub$earth_diff_pp <- pub$earth_pct_ours_120m - pub$pena_earth_pct
pub$c3_ours <- (pub$sun_pct_ours_120m / 100 / 0.00004) * pub$psr_pct_2km   # sun DN x PSR %
num <- vapply(pub, is.numeric, TRUE); pub[num] <- lapply(pub[num], function(x) round(x, 4))
utils::write.csv(pub, "data/processed/nr2_published_points.csv", row.names = FALSE)
print(pub[, c("id", "pena_earth_pct", "earth_pct_ours_120m", "earth_diff_pp", "slope_point_80m", "slope_max_100m", "pena_c3", "c3_ours", "inside_2024_outline")])

ok <- pub$pena_earth_pct > 0 | pub$earth_pct_ours_120m > 0
dd <- list(
  region = "Nobile Rim 2",
  published_source = "Pena-Asensio, Neira-Acosta & Sanchez-Lozano (2025) Acta Astronautica 226, 469-478, Table 3",
  earth = list(n = nrow(pub), pearson_r = round(cor(pub$pena_earth_pct, pub$earth_pct_ours_120m), 3),
               mean_abs_diff_pp = round(mean(abs(pub$earth_diff_pp)), 2), max_abs_diff_pp = round(max(abs(pub$earth_diff_pp)), 2)),
  c3 = list(spearman_rho = round(cor(pub$pena_c3, pub$c3_ours, method = "spearman"), 3),
            pearson_r = round(cor(pub$pena_c3, pub$c3_ours), 3)),
  slope = list(points_below_5deg_point = sum(pub$slope_point_80m < 5), points_below_5deg_100m_max = sum(pub$slope_max_100m < 5), n = nrow(pub)),
  inside_2024_outline = sum(pub$inside_2024_outline),
  region_raw_vs_grid = rs[rs$region == "Nobile Rim 2", ],
  generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
write_json(dd, "data/processed/deep_dive_nr2.json", auto_unbox = TRUE, pretty = TRUE, digits = NA, dataframe = "rows")
str(dd[c("earth", "c3", "slope", "inside_2024_outline")])

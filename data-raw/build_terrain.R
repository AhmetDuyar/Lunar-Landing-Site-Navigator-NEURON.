#!/usr/bin/env Rscript
# =============================================================================
# NEURON Lunar Navigator - terrain preprocessing (LOLA, Barker et al. 2023)
# -----------------------------------------------------------------------------
# Input  (unmodified NASA GSFC PGDA product 90 files, https://pgda.gsfc.nasa.gov/products/90):
#   data-raw/input/LDSM_80S_80MPP_ADJ.tif(f)       slope in degrees, 80 m/px, 80-90 S
#   data-raw/input/LDEM_80S_80MPP_ADJ_HILL.tif(f)  hillshade, 80 m/px, 80-90 S
# Output (small, shipped with the app):
#   www/assets/moon_south_hill.jpg                 hillshade, south-polar azimuthal
#                                                  equidistant, 80-90 S, 3072 px
#   data/processed/terrain_grid.csv.gz             400 x 400 polar grid (same UV
#                                                  convention as heat_grid()):
#                                                  slope median + share of terrain
#                                                  below 5/8/10/15 deg
#   data/processed/site_terrain.csv                slope at each candidate point
#                                                  and within a 1 km radius
#   data/processed/terrain_provenance.json         input checksums, CRS, method
#
#   Optional, Mazarico et al. (2011), PGDA product 69 / PDS LOLA GDR (IMG + LBL pairs):
#   data-raw/input/AVGVISIB_75S_120M_201608.IMG/.LBL         avg. Sun visibility, 18.6 yr
#   data-raw/input/AVGVISIB_75S_120M_201608_EARTH.IMG/.LBL   avg. Earth visibility
#   -> data/processed/illum_grid.csv.gz, site_illum.csv (DN = 0 marks permanent shadow)
#
# Run from the project folder (R >= 4.1):
#   install.packages(c("terra", "jsonlite"))
#   Rscript data-raw/build_terrain.R            # or: source("data-raw/build_terrain.R")
# Runtime ~2-6 min, peak memory ~2 GB. The input files are read, never modified.
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(jsonlite) })

IN_DIR   <- Sys.getenv("TERRAIN_INPUT", "data-raw/input")
HILL_PX  <- 3072          # output hillshade image size
GRID_N   <- 400           # analysis grid size (cells ~1.5 km)
EXTENT   <- 10            # degrees from the pole covered by the products (80-90 S)
SUB      <- 8             # stratified samples per cell edge (8 x 8 = 64 per cell)
SITE_R_M <- 1000          # radius for site statistics
THRESH   <- c(5, 8, 10, 15)
MOON_LL  <- "+proj=longlat +R=1737400 +no_defs"

find_input <- function(pattern) {
  f <- list.files(IN_DIR, pattern = pattern, ignore.case = TRUE, full.names = TRUE)
  if (!length(f)) stop(sprintf("Missing input in %s matching %s", IN_DIR, pattern), call. = FALSE)
  f[1]
}
slope_file <- find_input("^LDSM_80S_80MPP_ADJ\\.tiff?$")
hill_file  <- find_input("^LDEM_80S_80MPP_ADJ_HILL\\.tiff?$")
r_slope <- rast(slope_file)
r_hill  <- rast(hill_file)
for (r in list(r_slope, r_hill)) {
  if (!nzchar(crs(r))) stop("Input GeoTIFF has no CRS; use the original PGDA file.", call. = FALSE)
}
message("slope: ", paste(dim(r_slope)[1:2], collapse = " x "), " px, res ", paste(res(r_slope), collapse = "/"), " m")
message("hill : ", paste(dim(r_hill)[1:2], collapse = " x "), " px, res ", paste(res(r_hill), collapse = "/"), " m")

# UV convention shared with the viewer: u -> 0 deg E, v -> 90 deg E, centre = pole,
# colatitude = r / 0.5 * EXTENT.  Returns lon/lat (deg) for given u, v in [0,1].
uv_to_lonlat <- function(u, v) {
  du <- u - 0.5; dv <- v - 0.5
  r <- sqrt(du^2 + dv^2)
  cbind(lon = atan2(dv, du) * 180 / pi, lat = -90 + r / 0.5 * EXTENT, r = r)
}
to_xy <- function(lonlat, target) project(lonlat[, c("lon", "lat"), drop = FALSE], from = MOON_LL, to = crs(target))
sample_at <- function(r, xy, method = "bilinear") extract(r, xy, method = method)[, 1]
describe_pds <- function(lbl, r) {
  img <- sub("\\.lbl$", ".IMG", lbl, ignore.case = TRUE)
  if (!file.exists(img)) img <- sub("\\.lbl$", ".img", lbl, ignore.case = TRUE)
  list(label = basename(lbl), file = basename(img), bytes = file.size(img), md5 = unname(tools::md5sum(img)),
       crs_proj4 = crs(r, proj = TRUE), dim_px = dim(r)[2:1], res_m = res(r), extent_m = as.vector(ext(r)))
}

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)

# ---- 1. hillshade image ------------------------------------------------------
message("hillshade -> www/assets/moon_south_hill.jpg")
img <- matrix(NA_real_, HILL_PX, HILL_PX)
cols <- (seq_len(HILL_PX) - 0.5) / HILL_PX
for (rows in split(seq_len(HILL_PX), ceiling(seq_len(HILL_PX) / 128))) {
  g <- expand.grid(j = seq_len(HILL_PX), i = rows)
  ll <- uv_to_lonlat(cols[g$j], 1 - (g$i - 0.5) / HILL_PX)       # image row 0 = top = v 1
  val <- rep(NA_real_, nrow(g)); ok <- ll[, "r"] <= 0.5
  val[ok] <- sample_at(r_hill, to_xy(ll[ok, , drop = FALSE], r_hill))
  img[rows, ] <- matrix(val, nrow = length(rows), byrow = TRUE)
}
q <- quantile(img, c(0.005, 0.995), na.rm = TRUE)
img8 <- matrix(round(255 * pmin(1, pmax(0, (img - q[1]) / (q[2] - q[1])))), HILL_PX, HILL_PX)
img8[is.na(img8)] <- 0
out_img <- rast(img8, extent = ext(0, HILL_PX, 0, HILL_PX))
jpg <- "www/assets/moon_south_hill.jpg"
writeRaster(out_img, jpg, filetype = "JPEG", datatype = "INT1U", overwrite = TRUE,
            gdal = c("QUALITY=86", "WORLDFILE=NO"))
unlink(paste0(jpg, ".aux.xml"))

# ---- 2. slope statistics on the analysis grid ---------------------------------
message("slope grid -> data/processed/terrain_grid.csv.gz")
n <- GRID_N
offs <- (seq_len(SUB) - 0.5) / SUB                                  # sub-cell positions
res_list <- vector("list", n)
for (k in seq_len(n)) {                                              # row k: v in [(k-1)/n, k/n]
  g <- expand.grid(su = offs, sv = offs, j = seq_len(n))
  u <- (g$j - 1 + g$su) / n; v <- (k - 1 + g$sv) / n
  ll <- uv_to_lonlat(u, v)
  val <- rep(NA_real_, nrow(g)); ok <- ll[, "r"] <= 0.5
  if (any(ok)) val[ok] <- sample_at(r_slope, to_xy(ll[ok, , drop = FALSE], r_slope), method = "simple")
  m <- matrix(val, nrow = SUB * SUB)                                 # one column per cell
  cnt <- colSums(!is.na(m))
  stats <- data.frame(
    slope_median = ifelse(cnt >= 16, apply(m, 2, median, na.rm = TRUE), NA_real_),
    sapply(THRESH, function(t) ifelse(cnt >= 16, 100 * colMeans(m < t, na.rm = TRUE), NA_real_)))
  names(stats)[-1] <- paste0("flat_lt", THRESH)
  res_list[[k]] <- stats
  if (k %% 50 == 0) message("  row ", k, "/", n)
}
grid <- do.call(rbind, res_list)                                     # row-major, v rows ascending
grid[] <- lapply(grid, function(x) round(x, 1))
gz <- gzfile("data/processed/terrain_grid.csv.gz", "w")
utils::write.csv(grid, gz, row.names = FALSE, na = "")
close(gz)

# ---- 3. candidate sites --------------------------------------------------------
message("sites -> data/processed/site_terrain.csv")
sites <- utils::read.csv("data/sites.csv", stringsAsFactors = FALSE, encoding = "UTF-8")
ll <- cbind(lon = ifelse(sites$lon_e > 180, sites$lon_e - 360, sites$lon_e), lat = sites$lat)
xy <- project(ll, from = MOON_LL, to = crs(r_slope))
step <- 40; d <- seq(-SITE_R_M, SITE_R_M, by = step)
disc <- expand.grid(dx = d, dy = d); disc <- disc[sqrt(disc$dx^2 + disc$dy^2) <= SITE_R_M, ]
site_rows <- lapply(seq_len(nrow(sites)), function(i) {
  p <- cbind(xy[i, 1] + disc$dx, xy[i, 2] + disc$dy)
  s <- sample_at(r_slope, p)
  data.frame(id = sites$id[i],
             slope_point = round(sample_at(r_slope, xy[i, , drop = FALSE]), 2),
             slope_mean_1km = round(mean(s, na.rm = TRUE), 2),
             slope_p90_1km = round(unname(quantile(s, 0.9, na.rm = TRUE)), 2),
             flat_lt8_1km = round(100 * mean(s < 8, na.rm = TRUE), 1),
             n_samples = sum(!is.na(s)))
})
site_terrain <- do.call(rbind, site_rows)
utils::write.csv(site_terrain, "data/processed/site_terrain.csv", row.names = FALSE)
print(site_terrain)

# ---- 3b. long-term illumination (optional, Mazarico et al. 2011) ----------------
find_optional <- function(pattern) {
  f <- list.files(IN_DIR, pattern = pattern, ignore.case = TRUE, full.names = TRUE); if (length(f)) f[1] else NA_character_
}
sun_lbl <- find_optional("^AVGVISIB_75S_120M_201608\\.lbl$")
earth_lbl <- find_optional("^AVGVISIB_75S_120M_201608_EARTH\\.lbl$")
illum_inputs <- NULL
if (!is.na(sun_lbl) && !is.na(earth_lbl)) {
  message("illumination -> data/processed/illum_grid.csv.gz, site_illum.csv")
  r_sun <- rast(sun_lbl); r_earth <- rast(earth_lbl)          # GDAL PDS driver applies SCALING_FACTOR
  for (r in list(r_sun, r_earth)) if (!grepl("lat_0=-90", crs(r, proj = TRUE)))
    stop("Illumination file is not a SOUTH polar product (expected lat_0=-90).", call. = FALSE)
  rows_out <- vector("list", n)
  for (k in seq_len(n)) {
    g <- expand.grid(su = offs, sv = offs, j = seq_len(n))
    ll <- uv_to_lonlat((g$j - 1 + g$su) / n, (k - 1 + g$sv) / n)
    ok <- ll[, "r"] <= 0.5
    vs <- ve <- rep(NA_real_, nrow(g))
    if (any(ok)) {
      xy_k <- to_xy(ll[ok, , drop = FALSE], r_sun)
      vs[ok] <- sample_at(r_sun, xy_k, "simple"); ve[ok] <- sample_at(r_earth, xy_k, "simple")
    }
    ms <- matrix(vs, nrow = SUB * SUB); me <- matrix(ve, nrow = SUB * SUB); cnt <- colSums(!is.na(ms))
    rows_out[[k]] <- data.frame(
      sun_avg = ifelse(cnt >= 16, 100 * colMeans(ms, na.rm = TRUE), NA_real_),
      earth_avg = ifelse(cnt >= 16, 100 * colMeans(me, na.rm = TRUE), NA_real_),
      psr_pct = ifelse(cnt >= 16, 100 * colMeans(ms == 0, na.rm = TRUE), NA_real_))
  }
  ig <- do.call(rbind, rows_out); ig[] <- lapply(ig, function(x) round(x, 1))
  gz <- gzfile("data/processed/illum_grid.csv.gz", "w"); utils::write.csv(ig, gz, row.names = FALSE, na = ""); close(gz)

  xy_s <- project(ll_sites <- cbind(lon = ifelse(sites$lon_e > 180, sites$lon_e - 360, sites$lon_e), lat = sites$lat),
                  from = MOON_LL, to = crs(r_sun))
  dpsr <- seq(-10000, 10000, by = 120); lat_psr <- expand.grid(dx = dpsr, dy = dpsr)
  lat_psr$d <- sqrt(lat_psr$dx^2 + lat_psr$dy^2); lat_psr <- lat_psr[lat_psr$d <= 10000, ]
  site_illum <- do.call(rbind, lapply(seq_len(nrow(sites)), function(i) {
    p1 <- xy_s[i, , drop = FALSE]
    pd <- cbind(p1[1] + disc$dx, p1[2] + disc$dy)
    pp <- cbind(p1[1] + lat_psr$dx, p1[2] + lat_psr$dy)
    psr <- sample_at(r_sun, pp, "simple") == 0
    data.frame(id = sites$id[i],
      sun_avg_point = round(100 * sample_at(r_sun, p1), 1),
      earth_avg_point = round(100 * sample_at(r_earth, p1), 1),
      sun_avg_max_1km = round(100 * max(sample_at(r_sun, pd), na.rm = TRUE), 1),
      psr_nearest_km = if (any(psr, na.rm = TRUE)) round(min(lat_psr$d[which(psr)]) / 1000, 2) else NA_real_)
  }))
  utils::write.csv(site_illum, "data/processed/site_illum.csv", row.names = FALSE)
  print(site_illum)
  illum_inputs <- list(sun = describe_pds(sun_lbl, r_sun), earth = describe_pds(earth_lbl, r_earth))
} else message("illumination: AVGVISIB_75S files not found - skipped")

# ---- 4. provenance -------------------------------------------------------------
describe <- function(f, r) list(
  file = basename(f), bytes = file.size(f), md5 = unname(tools::md5sum(f)),
  crs_proj4 = crs(r, proj = TRUE), dim_px = dim(r)[2:1], res_m = res(r),
  extent_m = as.vector(ext(r)))
prov <- list(
  generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  generator = "data-raw/build_terrain.R",
  terra_version = as.character(packageVersion("terra")),
  source = "Barker, M. K. et al. (2023) A New View of the Lunar South Pole from LOLA, PSJ 4, 183; NASA GSFC PGDA product 90",
  source_page = "https://pgda.gsfc.nasa.gov/products/90",
  inputs = c(list(slope = describe(slope_file, r_slope), hillshade = describe(hill_file, r_hill)),
             if (!is.null(illum_inputs)) list(illum_sun = illum_inputs$sun, illum_earth = illum_inputs$earth)),
  illumination_source = if (!is.null(illum_inputs)) "Mazarico, E. et al. (2011) Icarus 211, 1066-1081; 18.6-year hourly averages; PGDA product 69" else NULL,
  method = list(
    projection = "Inputs sampled at lon/lat of the app's south-polar azimuthal-equidistant grid (80-90 S) via terra::project from the GeoTIFF's own CRS.",
    hillshade = sprintf("%d px image, bilinear sampling, 0.5-99.5 %% stretch to 8 bit.", HILL_PX),
    grid = sprintf("%d x %d cells (~%.2f km); %d stratified nearest-pixel samples per cell; median slope and share below %s deg; cells with < 16 valid samples left empty.",
                   GRID_N, GRID_N, 2 * EXTENT * pi / 180 * 1737.4 / GRID_N, SUB * SUB, paste(THRESH, collapse = "/")),
    sites = sprintf("Bilinear slope at the point and on a %d m lattice within %d m.", step, SITE_R_M)),
  limitations = "LOLA slope at 80 m baseline; boulders and sub-pixel hazards are not resolved. Slope error map (LDSM_..._ERR) not yet used.")
write_json(prov, "data/processed/terrain_provenance.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)
message("done.")

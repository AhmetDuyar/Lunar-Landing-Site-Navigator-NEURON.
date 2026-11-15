#!/usr/bin/env Rscript
# =============================================================================
# NEURON Lunar Navigator - machine-learning model (positive-unlabeled learning)
# -----------------------------------------------------------------------------
# Question the model answers:
#   "Which places at the south pole share the measurable properties of the
#    regions NASA selected as Artemis candidate landing regions?"
# It does NOT claim to know the 'best' site - there is no ground truth for that.
#
# Labels   : cells inside the nine USGS region grids (McClernan 2024,
#            doi:10.5066/P1MEQ6UK) = positive; all other cells = unlabeled.
# Features : per ~1.5 km cell, all from NASA data processed in build_terrain.R
#            (LOLA slope, Mazarico 2011 illumination). Location (lat/lon) is
#            deliberately NOT a feature, so the model learns properties, not
#            coordinates.
# Model    : random forest (ranger), class-balanced; PU scoring (Elkan & Noto 2008).
# Validation: leave-one-region-out (spatial cross-validation): train on 8 regions,
#            test whether the 9th is found.
#
# Inputs : data/processed/terrain_grid.csv.gz, illum_grid.csv.gz
#          data-raw/regions_usgs_1km/*_PolarLGRS_ACC_1km_S_Grid.shp (+ .dbf/.shx/.prj)
# Outputs: data/processed/ml_grid.csv.gz          score 0-100 per cell
#          data/processed/ml_model_card.json      features, CV results, importance
#          data/processed/artemis_regions.json    region outlines (lon/lat) for the map
#
# Run:  install.packages(c("terra", "ranger", "jsonlite"));  source("data-raw/build_ml.R")
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(ranger); library(jsonlite) })
set.seed(20261114)

N <- 400; EXTENT <- 10
MOON_LL <- "+proj=longlat +R=1737400 +no_defs"
REG_DIR <- "data-raw/regions_usgs_1km"

tg <- utils::read.csv("data/processed/terrain_grid.csv.gz")
ig <- utils::read.csv("data/processed/illum_grid.csv.gz")
stopifnot(nrow(tg) == N^2, nrow(ig) == N^2)

# ---- cell centres (same UV convention as the app) ----------------------------
c0 <- (seq_len(N) - 0.5) / N
g <- expand.grid(u = c0, v = c0)                       # u fastest = row-major in v
du <- g$u - 0.5; dv <- g$v - 0.5; r <- sqrt(du^2 + dv^2)
lat <- -90 + r / 0.5 * EXTENT; lon <- atan2(dv, du) * 180 / pi
inside_disc <- r <= 0.5

# ---- features ----------------------------------------------------------------
neigh_mean <- function(x, k) {                          # k x k moving mean (integral image, NA-aware)
  m <- matrix(x, N, N, byrow = TRUE); ok <- !is.na(m); m[!ok] <- 0
  integral <- function(a) { s <- apply(apply(a, 2, cumsum), 1, cumsum); t(s) }
  S <- rbind(0, cbind(0, integral(m))); C <- rbind(0, cbind(0, integral(ok * 1)))
  h <- k %/% 2; i1 <- pmax(1, seq_len(N) - h); i2 <- pmin(N, seq_len(N) + h)
  box <- function(Z) Z[i2 + 1, i2 + 1, drop = FALSE] - Z[i1, i2 + 1, drop = FALSE] - Z[i2 + 1, i1, drop = FALSE] + Z[i1, i1, drop = FALSE]
  bs <- function(Z) outer(seq_len(N), seq_len(N), function(i, j) Z[cbind(i2[i] + 1, i2[j] + 1)] - Z[cbind(i1[i], i2[j] + 1)] - Z[cbind(i2[i] + 1, i1[j])] + Z[cbind(i1[i], i1[j])])
  sm <- bs(S); cn <- bs(C)
  out <- ifelse(cn > 0, sm / cn, NA_real_)
  as.vector(t(out))
}
message("features ...")
X <- data.frame(
  slope_median = tg$slope_median,
  flat_lt8 = tg$flat_lt8,
  flat_lt15 = tg$flat_lt15,
  sun_avg = ig$sun_avg,
  earth_avg = ig$earth_avg,
  psr_pct = ig$psr_pct,
  psr_within_5km = neigh_mean(ig$psr_pct, 7),           # 7 cells ~ 10.6 km window
  slope_within_5km = neigh_mean(tg$slope_median, 7),
  sun_within_5km = neigh_mean(ig$sun_avg, 7))
FEATURE_TEXT <- c(
  slope_median = "Median LOLA slope in the cell (deg)",
  flat_lt8 = "Share of cell below 8 deg slope (%)",
  flat_lt15 = "Share of cell below 15 deg slope (%)",
  sun_avg = "Long-term Sun visibility, terrain-aware (%)",
  earth_avg = "Long-term Earth visibility, terrain-aware (%)",
  psr_pct = "Permanently shadowed share of cell (%)",
  psr_within_5km = "Permanent shadow within ~5 km (%)",
  slope_within_5km = "Mean slope within ~5 km (deg)",
  sun_within_5km = "Mean Sun visibility within ~5 km (%)")
valid <- inside_disc & stats::complete.cases(X)

# ---- labels from the USGS region grids -----------------------------------------
shps <- list.files(REG_DIR, pattern = "_PolarLGRS_ACC_1km_S_Grid\\.shp$", full.names = TRUE)
stopifnot(length(shps) == 9)
region_name <- function(f) gsub("_", " ", sub("_PolarLGRS_ACC_1km_S_Grid\\.shp$", "", basename(f)))
label <- integer(N^2); outlines <- list()
pts_ll <- cbind(lon, lat)
for (i in seq_along(shps)) {
  v <- vect(shps[i]); reg <- aggregate(v)                # dissolve 1 km cells into one polygon
  xy <- project(pts_ll, from = MOON_LL, to = crs(v))
  hit <- relate(vect(xy, crs = crs(v)), reg, "intersects")[, 1]
  label[hit & label == 0] <- i
  ring <- project(densify(reg, 1000), MOON_LL)           # outline for the map, vertex every 1 km
  cc <- crds(as.lines(ring))
  cen <- crds(project(centroids(reg), MOON_LL))
  outlines[[i]] <- list(name = region_name(shps[i]), lon = round(cc[, 1], 4), lat = round(cc[, 2], 4),
                        centroid = round(c(cen[1, 1], cen[1, 2]), 4), area_km2 = round(expanse(reg) / 1e6 * 0.994^-2, 0),
                        cells_1km = nrow(v), source_file = basename(shps[i]))
  message(sprintf("  %-20s %5d grid cells", region_name(shps[i]), sum(label == i)))
}
y <- factor(ifelse(label > 0, "region", "other"), levels = c("other", "region"))

# ---- model helpers ---------------------------------------------------------------
fit_rf <- function(idx, importance = "none") {
  d <- cbind(X[idx, ], y = y[idx])
  w <- ifelse(d$y == "region", sum(d$y == "other") / sum(d$y == "region"), 1)   # class balance
  ranger(y ~ ., data = d, num.trees = 400, probability = TRUE, case.weights = w,
         min.node.size = 25, mtry = 3, importance = importance, seed = 1, num.threads = NULL)
}
auc <- function(pos, neg) {                                 # Mann-Whitney AUC
  r <- rank(c(pos, neg)); np <- length(pos); nn <- length(neg)
  (sum(r[seq_len(np)]) - np * (np + 1) / 2) / (np * nn)
}

# ---- leave-one-region-out validation ----------------------------------------------
message("leave-one-region-out ...")
cv <- lapply(seq_along(shps), function(i) {
  train <- valid & label != i
  m <- fit_rf(which(train))
  test_pos <- which(valid & label == i)
  test_neg <- sample(which(valid & label == 0), min(20000, sum(valid & label == 0)))
  p_pos <- predict(m, X[test_pos, ])$predictions[, "region"]
  p_neg <- predict(m, X[test_neg, ])$predictions[, "region"]
  pct <- vapply(p_pos, function(p) mean(p_neg < p), 0)     # percentile among unlabeled cells
  data.frame(region = region_name(shps[i]), cells = length(test_pos),
             auc = round(auc(p_pos, p_neg), 3), median_percentile = round(100 * median(pct), 1),
             share_top20 = round(100 * mean(pct >= 0.8), 1))
})
cv <- do.call(rbind, cv); print(cv)

# ---- final model on all regions ---------------------------------------------------
message("final model ...")
m <- fit_rf(which(valid), importance = "permutation")
p <- rep(NA_real_, N^2)
p[valid] <- predict(m, X[valid, ])$predictions[, "region"]
c_hat <- mean(m$predictions[y[valid] == "region", "region"], na.rm = TRUE)      # OOB, Elkan-Noto
score <- rep(NA_real_, N^2)
score[valid] <- round(100 * stats::ecdf(p[valid])(p[valid]), 1)                 # percentile 0-100

gz <- gzfile("data/processed/ml_grid.csv.gz", "w")
utils::write.csv(data.frame(ml_score = score, ml_prob = round(p, 4)), gz, row.names = FALSE, na = "")
close(gz)

imp <- sort(m$variable.importance, decreasing = TRUE)
zips <- if (file.exists(file.path(REG_DIR, "source_zips_md5.csv")))
  utils::read.csv(file.path(REG_DIR, "source_zips_md5.csv"), header = FALSE, col.names = c("file", "bytes", "md5")) else NULL
card <- list(
  generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  generator = "data-raw/build_ml.R", ranger_version = as.character(packageVersion("ranger")),
  question = "Which places share the measurable properties of NASA's Artemis candidate landing regions?",
  not_claimed = "The model does not know the best landing site; it learns NASA's selection pattern from terrain and illumination.",
  method = "Positive-unlabeled learning: random forest (400 trees, class-balanced) separating region cells from all other cells; score = percentile of the predicted probability among all valid cells (0-100).",
  labels = list(source = "McClernan (2024) USGS data release doi:10.5066/P1MEQ6UK, 1 km LGRS grids", positive_cells = sum(valid & label > 0),
                unlabeled_cells = sum(valid & label == 0), source_zips = zips),
  features = lapply(names(X), function(k) list(key = k, description = unname(FEATURE_TEXT[k]))),
  excluded_features = "Latitude and longitude (to avoid learning locations instead of properties).",
  validation = list(scheme = "Leave-one-region-out spatial cross-validation", per_region = cv,
                    mean_auc = round(mean(cv$auc), 3), mean_median_percentile = round(mean(cv$median_percentile), 1)),
  importance = data.frame(feature = names(imp), importance = round(unname(imp) / max(imp), 3),
                          description = unname(FEATURE_TEXT[names(imp)])),
  elkan_noto_c = round(c_hat, 3),
  limitations = c("Only nine positive regions; NASA's selection also used criteria not in these data (geology, science, vehicle performance).",
                  "Unlabeled cells are not 'bad' - many were never assessed.",
                  "Features at ~1.5 km resolution; lander-scale hazards (boulders, small craters) are not resolved."))
write_json(card, "data/processed/ml_model_card.json", auto_unbox = TRUE, pretty = TRUE, digits = NA, dataframe = "rows")
write_json(outlines, "data/processed/artemis_regions.json", auto_unbox = TRUE, digits = NA)
message(sprintf("done. mean LORO AUC = %.3f", mean(cv$auc)))

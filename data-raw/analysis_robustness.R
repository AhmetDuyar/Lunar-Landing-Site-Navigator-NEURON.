#!/usr/bin/env Rscript
# =============================================================================
# NEURON Lunar Navigator - robustness of the comparison
# -----------------------------------------------------------------------------
# Does a region / site stay on top when the assumptions change?
#
# (1) Regions (nine NASA candidate regions, statistics from the original rasters,
#     data/processed/region_stats.csv). Score = weighted mean of
#       terrain      = share of the region below the slope limit (LOLA 80 m)
#       illumination = mean long-term Sun visibility (Mazarico 2011, 120 m)
#       earth        = mean long-term Earth visibility (Mazarico 2011, 120 m)
#     Scenarios: 10,000 random weight vectors (uniform on the simplex,
#     Dirichlet(1,1,1)) x slope limits 5/8/10/15 deg = 40,000 scenarios.
#     Also: share of each region's ~1.5 km cells scoring >= 50 (suitable area).
# (2) Candidate sites, the app's landing score: the same three terrain-aware
#     criteria, measured on every original pixel within 1 km of each site
#     (data/processed/dossiers.json.gz from build_dossiers.R). The SAME 10,000
#     weight vectors x slope limits 5/8/10/15 deg = 40,000 scenarios.
#     The score is absolute, so a site's rank can only change through the
#     weights or the slope limit, never through which other places are compared.
#
# Output: data/processed/robustness.json
# Run:    source("data-raw/analysis_robustness.R")   (after analysis_regions.R)
# =============================================================================
suppressPackageStartupMessages({ library(jsonlite); library(terra) })
source("data/interfaces.R")
set.seed(42)
rdirichlet <- function(n, k) { x <- matrix(rexp(n * k), n, k); x / rowSums(x) }

# ---- (1) regions --------------------------------------------------------------
rs <- utils::read.csv("data/processed/region_stats.csv", stringsAsFactors = FALSE)
limits <- c(5, 8, 10, 15); W <- rdirichlet(10000, 3); colnames(W) <- c("terrain", "illumination", "earth")
ranks <- NULL; scen <- NULL
for (L in limits) {
  crit <- cbind(terrain = rs[[paste0("raw_flat_lt", L)]], illumination = rs$raw_sun_mean, earth = rs$raw_earth_mean)
  S <- crit %*% t(W)                                   # regions x scenarios
  R <- apply(-S, 2, rank, ties.method = "min")
  ranks <- cbind(ranks, R)
  scen <- rbind(scen, data.frame(limit = L, W))
}
nreg <- nrow(rs)
region_rank_hist <- data.frame(region = rs$region, t(apply(ranks, 1, function(r) round(100 * tabulate(r, nreg) / length(r), 2))))
names(region_rank_hist) <- c("region", paste0("r", seq_len(nreg)))
reg_tab <- data.frame(region = rs$region,
  p_rank1 = round(100 * rowMeans(ranks == 1), 1),
  p_top3 = round(100 * rowMeans(ranks <= 3), 1),
  median_rank = apply(ranks, 1, median),
  rank_p05 = unname(apply(ranks, 1, quantile, 0.05)), rank_p95 = unname(apply(ranks, 1, quantile, 0.95)),
  rank_equal_weights_8deg = rank(-(rs$raw_flat_lt8 + rs$raw_sun_mean + rs$raw_earth_mean) / 3, ties.method = "min"))
reg_tab <- reg_tab[order(reg_tab$median_rank, -reg_tab$p_top3), ]; rownames(reg_tab) <- NULL
print(reg_tab)

# rank by slope limit at equal weights
by_limit <- sapply(limits, function(L) rank(-(rs[[paste0("raw_flat_lt", L)]] + rs$raw_sun_mean + rs$raw_earth_mean) / 3, ties.method = "min"))
colnames(by_limit) <- paste0("limit_", limits); by_limit <- data.frame(region = rs$region, by_limit)

# one-at-a-time weight sweep (8 deg): weight of one criterion from 0 to 1, others share the rest
sweep <- do.call(rbind, lapply(c("terrain", "illumination", "earth"), function(k) {
  do.call(rbind, lapply(seq(0, 1, by = 0.1), function(w) {
    wv <- rep((1 - w) / 2, 3); names(wv) <- c("terrain", "illumination", "earth"); wv[k] <- w
    s <- rs$raw_flat_lt8 * wv[1] + rs$raw_sun_mean * wv[2] + rs$raw_earth_mean * wv[3]
    data.frame(criterion = k, weight = w, region = rs$region, rank = rank(-s, ties.method = "min"))
  }))
}))

# suitable area share per region (grid cells, score >= 50), over 2,000 scenarios
tg <- utils::read.csv("data/processed/terrain_grid.csv.gz"); ig <- utils::read.csv("data/processed/illum_grid.csv.gz")
N <- 400; c0 <- (seq_len(N) - 0.5) / N; g <- expand.grid(u = c0, v = c0)
rr <- sqrt((g$u - 0.5)^2 + (g$v - 0.5)^2)
cell_ll <- cbind(lon = atan2(g$v - 0.5, g$u - 0.5) * 180 / pi, lat = -90 + rr / 0.5 * 10)
shps <- list.files("data-raw/regions_usgs_1km", pattern = "_1km_S_Grid\\.shp$", full.names = TRUE)
idx <- sample(nrow(scen), 2000)
area_tab <- do.call(rbind, lapply(shps, function(f) {
  reg <- aggregate(vect(f)); nm <- gsub("_", " ", sub("_PolarLGRS_ACC_1km_S_Grid\\.shp$", "", basename(f)))
  inside <- relate(vect(project(cell_ll, from = "+proj=longlat +R=1737400 +no_defs", to = crs(reg)), crs = crs(reg)), reg, "intersects")[, 1]
  share <- vapply(idx, function(i) {
    L <- scen$limit[i]; w <- unlist(scen[i, c("terrain", "illumination", "earth")])
    s <- w[1] * tg[[paste0("flat_lt", L)]][inside] + w[2] * ig$sun_avg[inside] + w[3] * ig$earth_avg[inside]
    100 * mean(s >= 50, na.rm = TRUE)
  }, 0)
  data.frame(region = nm, suitable_share_median = round(median(share), 1),
             suitable_share_p05 = round(unname(quantile(share, 0.05)), 1), suitable_share_p95 = round(unname(quantile(share, 0.95)), 1),
             row.names = NULL)
}))
print(area_tab)

# ---- (2) candidate sites, landing score ------------------------------------------
m <- load_mission_data("data")
site_ranks <- NULL
for (L in limits) {
  cr <- point_criteria(m$sites, m$terrain, m$dossiers, L)
  X <- as.matrix(cr[, SCORE_CRITERIA$col])            # terrain, sun, earth (same order as W)
  S <- X %*% t(W)                                       # sites x scenarios
  site_ranks <- cbind(site_ranks, apply(-S, 2, rank, ties.method = "min"))
}
site_tab <- data.frame(id = m$sites$id, name = m$sites$name,
  p_rank1 = round(100 * rowMeans(site_ranks == 1), 1), p_top2 = round(100 * rowMeans(site_ranks <= 2), 1),
  median_rank = apply(site_ranks, 1, median),
  rank_p05 = unname(apply(site_ranks, 1, quantile, 0.05)), rank_p95 = unname(apply(site_ranks, 1, quantile, 0.95)))
site_tab <- site_tab[order(site_tab$median_rank, -site_tab$p_rank1), ]; rownames(site_tab) <- NULL
nsite <- nrow(m$sites)
rank_hist <- data.frame(id = m$sites$id, t(apply(site_ranks, 1, function(r) round(100 * tabulate(r, nsite) / length(r), 2))))
names(rank_hist) <- c("id", paste0("r", seq_len(nsite)))
print(site_tab)

out <- list(
  generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  regions = list(scenarios = nrow(scen), weights = "uniform on the simplex (Dirichlet 1,1,1)", slope_limits_deg = limits,
                 criteria = c("terrain: share below slope limit (LOLA 80 m)", "illumination: mean long-term Sun visibility (Mazarico 2011)", "earth: mean long-term Earth visibility (Mazarico 2011)"),
                 table = reg_tab, rank_hist = region_rank_hist, by_slope_limit = by_limit, sweep = sweep, suitable_area = area_tab),
  sites = list(scenarios = ncol(site_ranks), weights = "same 10,000 Dirichlet(1,1,1) weight vectors as the regions", slope_limits_deg = limits,
               criteria = SCORE_CRITERIA$label, table = site_tab, rank_hist = rank_hist))
write_json(out, "data/processed/robustness.json", auto_unbox = TRUE, pretty = TRUE, digits = NA, dataframe = "rows")
message("done")

# Validation view: the project told as one scrolling story, from the question to
# the evidence. Text lives here; every number is read from data/processed/ and
# handed to www/story.js as one JSON block, which draws the charts.

story_data <- function(mission) {
  rd <- function(f) { p <- file.path("data", "processed", f); if (file.exists(p)) jsonlite::fromJSON(p) else NULL }
  a <- mission$analysis; dz <- mission$dossiers$points
  tp <- rd("terrain_provenance.json")
  list(
    eph = mission$validation,
    illum = rd("illum_validation.json"),
    checks = rd("validation_checks.json"),
    horizon = rd("horizon_validation.json"),
    hzml = rd("horizon_ml_card.json"),
    nr2 = list(points = a$points, stats = a$deep),
    regions = a$regions,
    robust = a$robust,
    landings = lapply(c("im1", "im2"), function(i) c(dz[[i]]$point[c("slope", "slope_max_100m", "slope_mean_1km", "sun", "earth")],
                                                     list(id = i, name = dz[[i]]$name))),
    inputs = if (!is.null(tp)) lapply(tp$inputs, function(x) list(file = x$file, mb = round(x$bytes / 1e6), res = x$res_m[1], md5 = x$md5)) else NULL,
    n_sources = nrow(mission$sources$sources), n_landings = nrow(mission$landings)
  )
}

storyUI <- function(mission) {
  d <- story_data(mission)
  ck <- d$checks; nasa <- ck$nasa_regions; st <- d$nr2$stats; rb <- d$robust
  eph_max <- max(d$eph$de421_vs_iau2015_sun_direction_max_deg, d$eph$de421_vs_iau2015_earth_direction_max_deg)
  im1 <- d$landings[[1]]
  supx <- function(x) chartr("-0123456789", "\u207b\u2070\u00b9\u00b2\u00b3\u2074\u2075\u2076\u2077\u2078\u2079", as.character(x))
  p_txt <- sprintf("p < 10%s", supx(floor(log10(nasa$wilcoxon_p)) + 1))
  il <- d$illum$rows; cr <- il[il$id == "CR", ]; hw <- il[il$id == "HW", ]
  pct <- function(x) sprintf("%d %%", as.integer(floor(x + 0.5)))   # same rounding as the charts (JS Math.round)
  chapter <- function(num, id, title, ...) tags$section(class = "st-ch", id = paste0("ch-", num), `data-ch` = num,
    div(class = "st-num reveal", num), h2(class = "st-h reveal", title), ...)
  check <- function(id, verdict, cls, title, lead, chart, ...) div(class = "st-check reveal", id = paste0("chk-", id),
    div(class = "st-check-head", span(class = paste("st-verdict", cls), verdict), h3(title)),
    p(class = "st-lead", lead), div(class = "st-chart", `data-chart` = chart), ...)
  kpi <- function(to, dec, unit, label, pre = "") div(class = "st-kpi reveal",
    div(class = "v", span(pre), span(class = "count", `data-to` = to, `data-dec` = dec, "0"), span(class = "u", unit)), div(class = "l", label))

  div(class = "story",
    tags$script(type = "application/json", id = "story-data", HTML(jsonlite::toJSON(d, auto_unbox = TRUE, digits = NA, null = "null", na = "null"))),
    tags$nav(class = "st-rail", lapply(list(c("00", "Question"), c("01", "Data"), c("02", "Method"), c("03", "Validation"),
                                          c("04", "Robustness"), c("05", "Result"), c("06", "Limits")),
      function(x) tags$a(href = paste0("#ch-", x[1]), `data-ch` = x[1], span(class = "dot"), span(class = "t", x[2])))),

    # ---- hero ---------------------------------------------------------------
    tags$header(class = "st-hero", id = "ch-top",
      div(class = "st-moon"),
      div(class = "st-hero-in",
        div(class = "st-kicker reveal", "3 · How sure · the project and its checks"),
        h1(class = "reveal", "Where can we land near the lunar south pole,", tags$br(), span("and how sure are we?")),
        p(class = "st-intro reveal", "We compare potential landing areas by terrain, illumination and Earth visibility, using NASA data only. This page tells how the comparison was built and, above all, how we checked it."),
        div(class = "st-kpis",
          kpi(eph_max, 3, "°", "ephemeris error against an independent model (tolerance 0.01°)"),
          kpi(st$earth$pearson_r, 3, "", "agreement with a published site analysis (12 points)", pre = "r = "),
          kpi(im1$slope, 1, "°", "our slope where IM-1 tipped over; about 12° reported"),
          kpi(rb$sites$table$p_rank1[1], 0, " %", sprintf("of %s scenarios: %s stays rank 1", format(rb$sites$scenarios, big.mark = ","), rb$sites$table$name[1])))),
      div(class = "st-scroll", "Scroll")),

    # ---- 00 question ------------------------------------------------------
    chapter("00", "q", "The question",
      div(class = "st-two",
        div(class = "reveal",
          p(class = "st-body", "Water ice in permanently shadowed craters makes the lunar south pole the target of NASA's Artemis programme, China's Chang'e 7 and several commercial landers. A good landing area needs three things at once: ground flat enough for a lander, sunlight for power, and Earth above the horizon for a direct radio link."),
          p(class = "st-body", "Those three pull in different directions. Crater floors are flat but dark; ridges are sunlit but steep. Our promise is deliberately narrow: ", strong("compare candidate areas transparently, and show how far the comparison can be trusted.")),
        div(class = "st-trio reveal",
          div(class = "st-tri", div(class = "ic", "01"), strong("Flat ground"), span("share of ground within 1 km below the slope limit, LOLA 80 m")),
          div(class = "st-tri", div(class = "ic", "02"), strong("Sunlight"), span("18.6-year average with real terrain shadowing")),
          div(class = "st-tri", div(class = "ic", "03"), strong("Earth in view"), span("18.6-year average above the real horizon")))))),

    # ---- 01 data ------------------------------------------------------------
    chapter("01", "d", "The data, and where it comes from",
      p(class = "st-body reveal", sprintf("Every number in the app traces back to a file, a script and a citation (%d registered sources). The large NASA rasters are processed by scripts exactly as published; checksums are recorded.", d$n_sources)),
      div(class = "st-chart wide", `data-chart` = "pipeline"),
      div(class = "st-files reveal", lapply(d$inputs, function(x) div(class = "st-file", strong(x$file), span(sprintf("%s MB · %s m/px · md5 %s…", x$mb, x$res, substr(x$md5, 1, 8))))))),

    # ---- 02 method ----------------------------------------------------------
    chapter("02", "m", "The method: where and when, kept apart",
      div(class = "st-two",
        div(class = "reveal",
          h3(class = "st-sub", "Where: an absolute score"),
          p(class = "st-body", "Score = weighted mean of the three criteria, 0 to 100. It is absolute: adding or removing a place never changes another place's score. The same formula colours the map and scores the nine NASA regions."),
          div(class = "st-formula", "score = ", span(class = "w", "w"), tags$sub("terrain"), " · flat + ", span(class = "w", "w"), tags$sub("sun"), " · sun + ", span(class = "w", "w"), tags$sub("earth"), " · earth")),
        div(class = "reveal",
          h3(class = "st-sub", "When: the mission window"),
          p(class = "st-body", "Hour-by-hour Sun and Earth positions from JPL DE421 tell when light and radio contact are available. Each position is compared with the real skyline of the place, computed from the LOLA 80 m elevation model in all 360 directions up to 150 km away. The timing decides when to land, never where."),
          p(class = "st-body muted", "An earlier version mixed both and used a relative ranking (TOPSIS). We replaced it after review because relative ranks change when places are added and because window values without terrain overstate sunlight near the pole.")))),

    # ---- 03 validation ------------------------------------------------------
    chapter("03", "v", "Validation: seven independent checks",
      p(class = "st-body reveal", "Each check compares our numbers with something we did not produce ourselves, or with a second, independent computation. Where numbers differ, we say why."),
      check("eph", "Passed", "ok", "1 · Sun and Earth positions",
        sprintf("Hourly Sun and Earth directions 2026 to 2030 (%s epochs) from JPL DE421, cross-checked with the independent IAU 2015 rotation model. Largest difference %.4f°, far below the 0.01° tolerance. Librations and distances fall inside their known physical ranges, and the total lunar eclipse of 3 March 2026 is reproduced (Sun hidden %.2f° behind Earth's %.2f° disc).",
                format(d$eph$n_epochs, big.mark = ","), eph_max, d$eph$eclipse_2026_03_03$min_sun_earth_separation_deg, d$eph$eclipse_2026_03_03$earth_apparent_radius_deg), "eph"),
      check("pub", "Agrees", "ok", "2 · An independent published site analysis",
        sprintf("Peña-Asensio et al. (2025) rank 1,247 locations and report 12 in Nobile Rim 2. Re-evaluated on the original rasters, our Earth visibility matches theirs with r = %.3f (mean difference %.1f pp, maximum %.1f pp; they sampled the 240 m map, we the 120 m map). Their illumination-times-shadow criterion is reproduced in the same order (Spearman ρ = %.2f).",
                st$earth$pearson_r, st$earth$mean_abs_diff_pp, st$earth$max_abs_diff_pp, st$c3$spearman_rho), "earth-scatter"),
      check("con", "Consistent", "ok", "3 · Two code paths, one answer",
        sprintf("The terrain pipeline (stratified samples) and the dossier pipeline (every 80 m pixel) were written separately. Around the five sites they agree within %.2f° mean slope and %.1f pp flat ground. Aggregating to the app's 1.5 km grid changes the nine region statistics by at most about 2 pp.", ck$consistency$max_abs_d_slope, ck$consistency$max_abs_d_flat8), "consistency"),
      check("lit", "Explained difference", "warn", "4 · Long-term sunlight against the literature",
        sprintf("Published illumination values use other elevation models, epochs and observer heights. At Connecting Ridge our best value within 1 km is %.1f pp from the published %.1f %%. At Haworth we stay %.0f pp below the published %.1f %%; the source gives no height or definition we could match, so we keep this as an open difference instead of tuning it away.",
                abs(cr$delta_max_1km_pp), cr$literature_pct, abs(hw$delta_max_1km_pp), hw$literature_pct), "illum"),
      check("nasa", "Plausible", "ok", "5 · Does the score see what NASA saw?",
        sprintf("NASA selected nine Artemis regions with its own, partly different criteria. At the same latitudes, cells inside these regions score higher than the rest (median %.1f vs %.1f, AUC %.2f, %s). The breakdown is the interesting part: NASA's regions see far more of Earth and more Sun, but have less flat ground. They sit on elevated rims, which is why a precise landing spot matters.",
                nasa$median_inside, nasa$median_outside, nasa$auc, p_txt), "nasa"),
      check("land", "Confirmed and limited", "warn", "6 · Real landings",
        sprintf("At the measured IM-1 Odysseus position our 80 m slope is %.1f°; about 12° was reported for the spot where it tipped over. The terrain criterion would have flagged it. At IM-2 Athena the 80 m ground is gentle (%.1f°), yet it tipped over in a small crater: hazards below one 80 m pixel are invisible to this tool.", im1$slope, d$landings[[2]]$slope), "landings"),
      if (!is.null(d$horizon)) check("hz", "Agrees", "ok", "7 · Our skyline against NASA's light maps",
        sprintf("We compute the skyline of %s random places from the LOLA elevation model and count the hours 2026 to 2030 with the Sun above it. Mazarico et al. simulated the same with their own code and years. The two agree with r = %.3f (mean difference %.1f pp); for Earth r = %.3f. Without terrain the same comparison gives r = %.2f: the mountains are the whole story.",
                format(d$horizon$n_points, big.mark = ","), d$horizon$sun_limb_vs_mazarico$r, d$horizon$sun_limb_vs_mazarico$mae_pp,
                d$horizon$earth_limb_vs_mazarico$r, d$horizon$smooth_sun_vs_mazarico$r), "horizon-scatter"),
      if (!is.null(d$hzml)) div(class = "st-check reveal", id = "chk-ml",
        div(class = "st-check-head", span(class = "st-verdict ok", "Machine learning"), h3("A skyline for any point, from a 1 MB terrain file")),
        p(class = "st-lead", sprintf("Exact skylines need the full 231 MB elevation model. A small neural network (%s parameters) predicts them from a 1.28 km version of under 1 MB, so the app can be terrain-aware wherever you click. Tested on 30 km blocks it never saw: average error %.2f°, against %.2f° for the coarse terrain alone and %.1f° for no terrain. Sunlight per place is then off by %.1f pp instead of %.1f pp. On the seven published sites and landings, rims chosen for their light, it is not better than the coarse terrain (%.1f° vs %.1f°), so these always use the exact skyline.",
          format(d$hzml$mlp$parameters, big.mark = ","), d$hzml$cv$mlp$mae_deg, d$hzml$cv$baseline$mae_deg, d$hzml$cv$zero_horizon$mae_deg,
          d$hzml$downstream_300_heldout_points$mlp$sun_mae_pp, d$hzml$downstream_300_heldout_points$baseline$sun_mae_pp,
          d$hzml$sites_out_of_distribution$mean_mlp_mae_deg, d$hzml$sites_out_of_distribution$mean_coarse_mae_deg)),
        div(class = "st-chart", `data-chart` = "ml-bars"),
        if (!is.null(d$hzml$model_choice)) p(class = "st-lead", style = "margin-top:14px", tags$strong("Why a neural network? "),
          sprintf("We tested four models on the same unseen terrain. A random forest (%.2f°) and gradient boosting (%.2f°) are as accurate as the network (%.2f°); a linear model is worse (%.2f°). The network wins on everything else: %.0f KB instead of %.1f MB (boosting) or %.0f MB (forest), it predicts a full skyline about 22 times faster than boosting (%.2f ms vs %.1f ms) as three matrix multiplications in plain R, and its skyline is as smooth as the real one, while the tree models add jumps between neighbouring directions (forest %+.0f %%, boosting %+.0f %%, network %+.0f %%).",
                  d$hzml$model_choice$comparison$random_forest_fold0_mae, d$hzml$model_choice$comparison$gbm_fold0_mae, d$hzml$model_choice$comparison$mlp_fold0_mae,
                  d$hzml$model_choice$comparison$linear_ridge_mae, d$hzml$model_choice$comparison$mlp_json_kb, d$hzml$model_choice$comparison$gbm_size_mb,
                  d$hzml$model_choice$comparison$random_forest_size_mb, d$hzml$model_choice$comparison$predict_ms_360az$nn, d$hzml$model_choice$comparison$predict_ms_360az$gbm, d$hzml$model_choice$comparison$jumpiness_vs_exact_pct$rf, d$hzml$model_choice$comparison$jumpiness_vs_exact_pct$gbm, d$hzml$model_choice$comparison$jumpiness_vs_exact_pct$nn)))),

    # ---- 04 robustness ------------------------------------------------------
    chapter("04", "r", "Robustness: do the answers survive other assumptions?",
      p(class = "st-body reveal", sprintf("Weights express preferences, not facts. So we recompute everything for %s scenarios: every combination of the three weights, each with slope limits of 5, 8, 10 and 15°. Darker cells mean a region or site lands at that rank more often.", format(rb$regions$scenarios, big.mark = ","))),
      div(class = "st-two",
        div(h3(class = "st-sub reveal", "Nine NASA regions"), div(class = "st-chart", `data-chart` = "matrix-regions")),
        div(h3(class = "st-sub reveal", "Five published sites"), div(class = "st-chart", `data-chart` = "matrix-sites")))),

    # ---- 05 result ------------------------------------------------------------
    chapter("05", "res", "What we can say",
      div(class = "st-results",
        div(class = "st-res reveal", div(class = "big", pct(rb$regions$table$p_rank1[1])), strong(rb$regions$table$region[1]), span("is the best of NASA's nine regions in most scenarios and in the top 3 in almost all.")),
        div(class = "st-res reveal", div(class = "big", pct(rb$sites$table$p_rank1[1])), strong(rb$sites$table$name[1]), span("leads the published points. IM-2 landed here, and its tip-over shows why 80 m data are not enough on their own.")),
        div(class = "st-res reveal", div(class = "big", sprintf("%g / 9", rb$regions$table$median_rank[rb$regions$table$region == "Nobile Rim 2"])), strong("Nobile Rim 2"), span("holds the best published spot, but ranks mid-field as a region. A good spot is not the same as a good area.")))),

    # ---- 06 limits ----------------------------------------------------------
    chapter("06", "l", "Limits, stated plainly",
      div(class = "st-limits reveal",
        div(strong("80 m pixels"), span("compare areas; boulders and craters below about 100 m are invisible.")),
        div(strong("Skyline to 150 km"), span("north of about 84° S the elevation model ends at 80° S, so the farthest terrain in that direction is missing.")),
        div(strong("Five published points"), span("are a small set; the region analysis covers nine areas with every original pixel.")),
        div(strong("No new science"), span("Our contribution is integration, transparency, a robustness test and these checks."))),
      div(class = "st-repro reveal", h3(class = "st-sub", "Reproduce"),
        tags$pre("Rscript data-raw/build_terrain.R\nRscript data-raw/analysis_regions.R\nRscript data-raw/build_dossiers.R\nRscript data-raw/analysis_robustness.R\nRscript data-raw/build_validation.R\npython3 data-raw/build_horizons.py ldem.f32\npython3 data-raw/train_horizon_ml.py ldem.f32\npython3 data-raw/build_analysis_report.py")))
  )
}

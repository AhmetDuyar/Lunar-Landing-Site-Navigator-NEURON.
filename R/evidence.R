# Evidence cards: robustness of the ranking and the Nobile Rim 2 deep dive.
# All numbers come from data/processed/ (analysis_regions.R, analysis_robustness.R).

bar_cell <- function(pct) tags$td(class = "num bar-td",
  div(class = "pbar", span(style = sprintf("width:%.0f%%", pct))), span(sprintf("%.0f %%", pct)))

evidenceUI_core <- function(mission, rn) {
  a <- mission$analysis
  if (is.null(a)) return(NULL)
  rb <- a$robust; rt <- rb$regions$table; st <- rb$sites$table; sa <- rb$regions$suitable_area
  rt$spread <- rt$rank_p95 - rt$rank_p05
  best <- rt[1, ]; volatile <- rt[which.max(rt$spread), ]
  dd <- a$deep; pts <- a$points; rs <- a$regions
  nr2 <- rs[rs$region == "Nobile Rim 2", ]
  rank_nr2 <- rt$median_rank[rt$region == "Nobile Rim 2"]
  maxdiff <- function(x, y) max(abs(x - y), na.rm = TRUE)

  tagList(
    div(class = "m-card evidence",
      div(class = "ev-head", span(class = "ev-tag", "Evidence 1"), h3("Does the ranking survive changed assumptions?")),
      p(class = "small muted", sprintf("Regions: %s scenarios: every weighting of terrain, illumination and Earth visibility (uniform random) × slope limits %s°. Sites: %s scenarios, the same weightings and slope limits applied to the landing score of the five published points.",
        format(rb$regions$scenarios, big.mark = ","), paste(rb$regions$slope_limits_deg, collapse = "/"),
        format(rb$sites$scenarios, big.mark = ","))),
      div(class = "ev-findings",
        div(class = "ev-find", strong(best$region), sprintf(" is rank 1 in %.0f %% and in the top 3 in %.0f %% of all region scenarios, the most robust result.", best$p_rank1, best$p_top3)),
        div(class = "ev-find", strong(volatile$region), sprintf(" is the most assumption-sensitive region: its rank spans %g–%g (5–95 %%). It wins only when flat terrain dominates the weighting.", volatile$rank_p05, volatile$rank_p95)),
        div(class = "ev-find", strong(st$name[1]), sprintf(" (IM-2 landing site) leads the candidate points: rank 1 in %.0f %%, top 2 in %.0f %% of %s scenarios.", st$p_rank1[1], st$p_top2[1], format(rb$sites$scenarios, big.mark = ",")))),
      div(class = "m-grid", style = "margin:14px 0 0",
        div(
          h4(class = "sub-h", "Nine NASA regions"),
          tags$table(class = "table-clean",
            tags$thead(tags$tr(tags$th("Region"), tags$th("Rank 1"), tags$th("Top 3"), tags$th(class = "num", "Median"), tags$th(class = "num", "5–95 %"), tags$th(class = "num", "Suitable area*"))),
            tags$tbody(lapply(seq_len(nrow(rt)), function(i) {
              s <- sa[sa$region == rt$region[i], ]
              tags$tr(tags$td(rt$region[i]), bar_cell(rt$p_rank1[i]), bar_cell(rt$p_top3[i]),
                      tags$td(class = "num", rt$median_rank[i]), tags$td(class = "num", sprintf("%g–%g", rt$rank_p05[i], rt$rank_p95[i])),
                      tags$td(class = "num", sprintf("%.0f %% (%.0f–%.0f)", s$suitable_share_median, s$suitable_share_p05, s$suitable_share_p95)))
            }))),
          p(class = "small muted", "* Share of the region's ~1.5 km cells scoring ≥ 50, median and 5–95 % range over 2,000 scenarios.")),
        div(
          h4(class = "sub-h", "Published candidate points"),
          tags$table(class = "table-clean",
            tags$thead(tags$tr(tags$th("Point"), tags$th("Rank 1"), tags$th("Top 2"), tags$th(class = "num", "Median"), tags$th(class = "num", "5–95 %"))),
            tags$tbody(lapply(seq_len(nrow(st)), function(i) tags$tr(tags$td(st$name[i]), bar_cell(st$p_rank1[i]), bar_cell(st$p_top2[i]),
              tags$td(class = "num", st$median_rank[i]), tags$td(class = "num", sprintf("%g–%g", st$rank_p05[i], st$rank_p95[i])))))),
          h4(class = "sub-h", style = "margin-top:14px", "Region rank vs. slope limit (equal weights)"),
          {
            bl <- rb$regions$by_slope_limit
            tags$table(class = "table-clean",
              tags$thead(tags$tr(tags$th("Region"), lapply(rb$regions$slope_limits_deg, function(L) tags$th(class = "num", sprintf("< %g°", L))))),
              tags$tbody(lapply(seq_len(nrow(bl)), function(i) tags$tr(tags$td(bl$region[i]),
                lapply(rb$regions$slope_limits_deg, function(L) tags$td(class = "num", bl[[paste0("limit_", L)]][i]))))))
          }))),

    div(class = "m-card evidence",
      div(class = "ev-head", span(class = "ev-tag", "Evidence 2"), h3("Deep dive: Nobile Rim 2 against original rasters and a published analysis")),
      p(class = "small muted", "Nobile Rim 2 is on NASA's October 2024 list and is the region with the most published point-level values: Peña-Asensio et al. (2025) ", rn("pena2025"),
        " rank 1,247 locations and report 12 in Nobile Rim 2 (all inside the USGS outline ", rn("mcclernan2024"), "). We re-evaluated each of them on the original LOLA 80 m slope ", rn("lola_pgda"),
        " and Mazarico 120 m illumination rasters ", rn("mazarico2011"), "."),
      div(class = "ml-kpis",
        div(class = "ml-kpi", div(class = "v", sprintf("r = %.3f", dd$earth$pearson_r)), div(class = "l", "Earth visibility vs. published (12 points)")),
        div(class = "ml-kpi", div(class = "v", sprintf("%.1f pp", dd$earth$mean_abs_diff_pp)), div(class = "l", sprintf("mean difference (max %.1f pp)", dd$earth$max_abs_diff_pp))),
        div(class = "ml-kpi", div(class = "v", sprintf("%d / %d", dd$slope$points_below_5deg_100m_max, dd$slope$n)), div(class = "l", "meet their < 5° rule in our 80 m slope")),
        div(class = "ml-kpi", div(class = "v", sprintf("ρ = %.2f", dd$c3$spearman_rho)), div(class = "l", "illumination × shadow criterion, rank agreement"))),
      tags$table(class = "table-clean small-table",
        tags$thead(tags$tr(tags$th("ID"), tags$th(class = "num", "Their rank"), tags$th(class = "num", "Lat / Lon"),
          tags$th(class = "num", "Earth, published"), tags$th(class = "num", "Earth, ours"), tags$th(class = "num", "Δ"),
          tags$th(class = "num", "Slope at point"), tags$th(class = "num", "Max slope ≤ 100 m"), tags$th(class = "num", "C3 published"), tags$th(class = "num", "C3 ours"))),
        tags$tbody(lapply(seq_len(nrow(pts)), function(i) tags$tr(class = if (pts$slope_max_100m[i] >= 5) "row-flag",
          tags$td(pts$id[i]), tags$td(class = "num", pts$pena_rank[i]), tags$td(class = "num", sprintf("%.4f / %.4f", pts$lat[i], pts$lon[i])),
          tags$td(class = "num", sprintf("%.1f %%", pts$pena_earth_pct[i])), tags$td(class = "num", sprintf("%.1f %%", pts$earth_pct_ours_120m[i])),
          tags$td(class = "num", sprintf("%+.1f", pts$earth_diff_pp[i])), tags$td(class = "num", sprintf("%.1f°", pts$slope_point_80m[i])),
          tags$td(class = "num", sprintf("%.1f°", pts$slope_max_100m[i])), tags$td(class = "num", format(round(pts$pena_c3[i]), big.mark = ",")),
          tags$td(class = "num", format(round(pts$c3_ours[i]), big.mark = ",")))))),
      div(class = "m-grid", style = "margin:14px 0 0",
        div(
          h4(class = "sub-h", "Why the numbers differ"),
          tags$ul(class = "limits",
            tags$li(strong("Earth visibility (≤ 1.9 pp). "), "Same NASA product, different resolution: the paper samples the 240 m map, we the 120 m map with bilinear interpolation. Their value is a digital number; 25,000 DN = 100 % per the PDS label."),
            tags$li(strong("Illumination × shadow (ours ~10–15 % higher, same order). "), "We mark permanent shadow as Sun DN = 0 on the 120 m map within 2 km; the paper uses a 240 m shadow map. Finer pixels resolve more small shadowed pockets, so the product rises while the ranking stays (ρ = 0.96)."),
            tags$li(strong("Slope, ID 995 (17° in our data). "), "Their filter ran on a 5 m LOLA model with landing polygons as small as 25 m². A flat patch of that size is invisible at 80 m. The same point also has 0 % Earth visibility in both datasets."),
            tags$li(strong("App grid vs. original pixels. "), sprintf("Over all nine regions the ~1.5 km grid differs from the original pixels by at most %.1f° median slope, %.1f pp flat share, %.1f pp Sun and %.1f pp Earth visibility. Aggregation does not change the comparison.",
              maxdiff(rs$raw_slope_median, rs$grid_slope_median), maxdiff(rs$raw_flat_lt8, rs$grid_flat_lt8), maxdiff(rs$raw_sun_mean, rs$grid_sun_mean), maxdiff(rs$raw_earth_mean, rs$grid_earth_mean))))),
        div(
          h4(class = "sub-h", "Best spot ≠ best region"),
          p(class = "small", sprintf("The paper's optimum (ID 358) is flat (%.1f° at the point, ≤ %.1f° within 100 m) with %.0f %% Earth visibility. The region as a whole is rougher: median slope %.1f°, only %.0f %% below 8°, mean Sun %.0f %%, Earth %.0f %% and it ranks %g of 9 in the robustness test.",
            pts$slope_point_80m[1], pts$slope_max_100m[1], pts$earth_pct_ours_120m[1], nr2$raw_slope_median, nr2$raw_flat_lt8, nr2$raw_sun_mean, nr2$raw_earth_mean, rank_nr2)),
          p(class = "small", "Both statements are true at once: a 20–30 km region can hold an excellent landing spot while being average overall. That is why the tool reports point values, region statistics and their robustness side by side."),
          p(class = "small muted", "Reproduce: data-raw/analysis_regions.R and data-raw/analysis_robustness.R (original rasters in data-raw/input).")))))
}

# Evidence 3: what our terrain data say at the places where landers actually came down
landing_check_ui <- function(mission, rn) {
  dz <- mission$dossiers; land <- mission$landings
  if (is.null(dz) || is.null(land)) return(NULL)
  ids <- intersect(c("im1", "im2", "change7"), names(dz$points))
  if (!length(ids)) return(NULL)
  rows <- lapply(ids, function(i) {
    p <- dz$points[[i]]$point; l <- land[land$id == i, ]
    tags$tr(tags$td(l$mission), tags$td(l$date), tags$td(switch(l$outcome, tipped = "Landed, tipped over", planned = "Planned", landed = "Landed", crashed = "Crashed")),
            tags$td(class = "num", sprintf("%.1f°", p$slope)), tags$td(class = "num", sprintf("%.1f°", p$slope_max_100m)),
            tags$td(class = "num", sprintf("%.0f %%", p$sun)), tags$td(class = "num", sprintf("%.0f %%", p$earth)),
            tags$td(switch(i, im1 = tagList("about 12° ", rn("thomson2025")), im2 = "came to rest on its side in a small crater", change7 = "target near Shackleton rim", "")))
  })
  div(class = "m-card evidence",
    div(class = "ev-head", span(class = "ev-tag", "Evidence 3"), h3("Check against real landings")),
    p(class = "small muted", "The same original rasters, read at the positions where landers actually came down (NASA NSSDCA, LROC measurements ", rn("nssdca_artifacts"), ")."),
    tags$table(class = "table-clean",
      tags$thead(tags$tr(tags$th("Mission"), tags$th("Date"), tags$th("Outcome"), tags$th(class = "num", "LOLA slope at point"), tags$th(class = "num", "Steepest within 100 m"),
                         tags$th(class = "num", "Sun, long-term"), tags$th(class = "num", "Earth, long-term"), tags$th("Reported"))),
      tags$tbody(rows)),
    tags$ul(class = "limits",
      tags$li(strong("IM-1 Odysseus. "), sprintf("Our 80 m slope at the landing point is %.1f°, close to the ~12° reported from LROC data. The lander tipped over on exactly this kind of ground, and the terrain criterion in this tool would have flagged it.", dz$points$im1$point$slope)),
      tags$li(strong("IM-2 Athena. "), sprintf("At 80 m the site is gentle (%.1f°), yet Athena tipped over in a small crater. Hazards below one pixel are invisible at this resolution; the tool compares areas, final hazard avoidance needs 1-5 m data.", dz$points$im2$point$slope))))
}

evidenceUI <- function(mission, rn) tagList(evidenceUI_core(mission, rn), landing_check_ui(mission, rn))

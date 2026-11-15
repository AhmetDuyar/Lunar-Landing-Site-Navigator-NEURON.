# Data & Methods view: provenance registry, pipeline, validation, limitations.

methodsUI <- function(id, mission) {
  ns <- NS(id)
  src <- mission$sources$sources
  v <- mission$validation
  status_cls <- function(s) switch(s, ingested = "st st-ok", planned = "st st-plan", "st st-ctx")
  status_txt <- function(s) switch(s, ingested = "In use", planned = "Planned", "Context")

  reg_rows <- lapply(seq_len(nrow(src)), function(i) {
    s <- src[i, ]
    tags$tr(id = paste0("ref-", s$id),
      tags$td(class = "mono", sprintf("[%d]", i)),
      tags$td(div(class = "src-title", s$title),
              div(class = "src-meta", sprintf("%s (%s). %s.", s$authors, s$year, s$venue)),
              tags$a(href = s$url, target = "_blank", rel = "noopener", class = "src-link", s$url),
              tags$dl(class = "src-detail",
                tags$dt("Files"), tags$dd(s$files),
                tags$dt("Processing"), tags$dd(s$processing),
                tags$dt("Code"), tags$dd(tags$code(s$code)),
                tags$dt("Accessed"), tags$dd(s$accessed))),
      tags$td(span(class = "kind", s$kind)),
      tags$td(s$used_for),
      tags$td(class = "small", s$license),
      tags$td(span(class = status_cls(s$status), status_txt(s$status))))
  })

  chk <- function(label, value, expected, ok = TRUE) {
    tags$tr(tags$td(label), tags$td(class = "mono", value), tags$td(class = "mono muted", expected),
            tags$td(span(class = if (ok) "st st-ok" else "st st-bad", if (ok) "Pass" else "Fail")))
  }
  rng <- function(x, d = 3) sprintf("%s … %s", formatC(x[1], format = "f", digits = d), formatC(x[2], format = "f", digits = d))

  regions <- mission$sources$artemis_regions_2024
  rn <- function(id) sprintf("[%d]", match(id, src$id))

  div(class = "methods",
    div(class = "methods-head",
      h2("Data sources and methods"),
      p(class = "lead", strong("We compare potential landing areas by terrain, illumination and Earth visibility."), " Each value is computed here from NASA/JPL data, taken from a cited publication, or marked as not yet available. The checks below show how far the results can be trusted.")),
    div(class = "m-card scope-card",
      h3("What this tool is, and what it is not"),
      div(class = "m-grid", style = "margin:8px 0 0",
        div(h4(class = "sub-h", "Our contribution"),
          tags$ul(class = "limits",
            tags$li("One transparent comparison of candidate areas from NASA data, with every number traceable to a file, a script and a citation."),
            tags$li("A robustness test: does a place stay on top when the weights or the slope limit change?"),
            tags$li("Checks against an independent published analysis and against real landing outcomes."))),
        div(h4(class = "sub-h", "Not our claim"),
          tags$ul(class = "limits",
            tags$li("New lunar science. The underlying products are NASA's (LOLA, Mazarico et al. 2011) and the site studies are published."),
            tags$li("Finding the one best landing spot. 80 m pixels compare areas; hazards below about 100 m (boulders, small craters) are invisible."),
            tags$li("Certification for a specific lander. That needs 1 to 5 m data and the vehicle's own constraints."))))),
    evidenceUI(mission, rn),

    div(class = "m-grid",
      div(class = "m-card",
        h3("Provenance classes"),
        tags$ul(class = "prov-legend",
          tags$li(prov_badge("computed"), "Derived in this app from DE421 geometry. Reproducible with data-raw/build_ephemeris.py."),
          tags$li(prov_badge("measured"), "Observed position of a landed spacecraft (LROC)."),
          tags$li(prov_badge("literature"), "Value copied verbatim from the cited peer-reviewed or conference source."),
          tags$li(prov_badge("official"), "NASA program information."),
          tags$li(prov_badge("na", "Not ingested"), "Required dataset identified, adapter not yet built. Shown as n/a, never estimated."))),
      div(class = "m-card",
        h3("Processing pipeline"),
        tags$ol(class = "pipeline",
          tags$li(strong("Ephemeris. "), paste0("DE421 barycentric Sun, Earth, Moon ", rn("de421"), "; light-time corrected vectors from the Moon's centre; hourly, 2026-01-01 → 2030-12-31 UTC (TDB = UTC + 69.184 s).")),
          tags$li(strong("Lunar frame. "), paste0("ICRF → principal axes via DE421 libration angles (3-1-3), then PA → Mean-Earth rotation ", rn("naif_moon_tf"), ".")),
          tags$li(strong("Independent check. "), paste0("Same vectors rotated with the IAU 2015 model ", rn("iau2015"), "; agreement < 0.01° required.")),
          tags$li(strong("Topocentric geometry. "), "For any point on a 1737.4 km sphere: local east-north-up basis, Earth parallax included; elevation and azimuth per hour."),
          tags$li(strong("Window metrics. "), "Share of hours above horizon, longest continuous runs below horizon, ranges."),
          tags$li(strong("Visibility raster. "), "Same geometry on a 120 × 120 polar grid (80°S–90°S, azimuthal equidistant) for the map layer."),
          tags$li(strong("Score. "), paste0("Weighted mean of flat ground within 1 km (LOLA ", rn("lola_pgda"), "), long-term Sun and long-term Earth visibility with terrain (", rn("mazarico2011"), "). Absolute 0 to 100, identical to the map layer and the region analysis. Window geometry (steps 04 to 06) is used for timing only. Earlier versions used TOPSIS as in ", rn("pena2025"), "; it was replaced because its relative ranks change when places are added."))))),

    div(class = "m-card",
      h3("Ephemeris validation", span(class = "muted small", sprintf(" · %s epochs · generated %s", format(v$n_epochs, big.mark = ","), v$generated_utc))),
      tags$table(class = "table-clean",
        tags$thead(tags$tr(tags$th("Check"), tags$th("Result"), tags$th("Expected"), tags$th("Status"))),
        tags$tbody(
          chk("DE421 vs IAU 2015 · Sun direction, max Δ", sprintf("%.4f°", v$de421_vs_iau2015_sun_direction_max_deg), "< 0.01°"),
          chk("DE421 vs IAU 2015 · Earth direction, max Δ", sprintf("%.4f°", v$de421_vs_iau2015_earth_direction_max_deg), "< 0.01°"),
          chk("Sub-solar latitude range", rng(v$subsolar_latitude_range_deg), "|lat| ≤ 1.6° (lunar obliquity 1.54°)"),
          chk("Sub-Earth latitude (libration)", rng(v$subearth_latitude_range_deg), "|lat| ≤ 7.0°"),
          chk("Sub-Earth longitude (libration)", rng(v$subearth_longitude_range_deg), "|lon| ≤ 8.2°"),
          chk("Earth–Moon centre distance", sprintf("%s … %s km", format(v$earth_moon_distance_range_km[1], big.mark = ","), format(v$earth_moon_distance_range_km[2], big.mark = ",")), "356,000 … 407,000 km"),
          chk("Total lunar eclipse 2026-03-03 · Sun–Earth separation seen from Moon",
              sprintf("%.2f° at %s", v$eclipse_2026_03_03$min_sun_earth_separation_deg, sub("T", " ", v$eclipse_2026_03_03$at_utc)),
              sprintf("Sun fully behind Earth: < %.2f° (Earth radius − Sun radius)", v$eclipse_2026_03_03$earth_apparent_radius_deg - 0.26))))),

    if (!is.null(mission$terrain)) {
      tp <- mission$terrain$prov
      inp <- function(x) tags$tr(tags$td(x$file), tags$td(class = "num", format(x$bytes, big.mark = ",")),
        tags$td(tags$code(x$md5)), tags$td(sprintf("%s m", paste(x$res_m, collapse = " × "))), tags$td(class = "small", x$crs_proj4))
      div(class = "m-card",
        h3("Terrain inputs (LOLA)", span(class = "muted small", sprintf(" · processed %s by %s", tp$generated_utc, tp$generator))),
        tags$table(class = "table-clean",
          tags$thead(tags$tr(tags$th("File (unmodified)"), tags$th(class = "num", "Bytes"), tags$th("MD5"), tags$th("Pixel"), tags$th("CRS"))),
          tags$tbody(inp(tp$inputs$slope), inp(tp$inputs$hillshade))),
        tags$ul(class = "limits", style = "margin-top:10px",
          tags$li(strong("Projection. "), tp$method$projection),
          tags$li(strong("Grid. "), tp$method$grid),
          tags$li(strong("Sites. "), tp$method$sites),
          tags$li(strong("Limitation. "), tp$limitations)))
    },

    if (!is.null(mission$terrain$illum$validation)) {
      iv <- mission$terrain$illum$validation
      r <- iv$rows
      div(class = "m-card",
        h3("Illumination check against literature"),
        p(class = "small muted", iv$method),
        tags$table(class = "table-clean",
          tags$thead(tags$tr(tags$th("Site"), tags$th(class = "num", "Literature"), tags$th("Source / definition"),
                             tags$th(class = "num", "Mazarico, point"), tags$th(class = "num", "Mazarico, max 1 km"), tags$th("Status"))),
          tags$tbody(lapply(seq_len(nrow(r)), function(i) tags$tr(
            tags$td(r$name[i]), tags$td(class = "num", sprintf("%.1f %%", r$literature_pct[i])),
            tags$td(class = "small", rn(r$literature_source[i]), " ", r$literature_definition[i]),
            tags$td(class = "num", sprintf("%.1f %%", r$mazarico_point_pct[i])),
            tags$td(class = "num", sprintf("%.1f %% (%+.1f pp)", r$mazarico_max_1km_pct[i], r$delta_max_1km_pp[i])),
            tags$td(span(class = if (r$agrees_within_10pp_1km[i]) "st st-ok" else "st st-plan",
                         if (r$agrees_within_10pp_1km[i]) "Consistent" else "Discrepancy")))))),
        p(class = "small muted", style = "margin-top:8px", iv$notes))
    },

    if (!is.null(mission$ml)) {
      mc <- mission$ml$card; cvt <- mc$validation$per_region; im <- mc$importance
      div(class = "m-card",
        h3("Machine-learning model"),
        p(class = "ml-question", mc$question),
        p(class = "small muted", mc$not_claimed),
        div(class = "ml-kpis",
          div(class = "ml-kpi", div(class = "v", sprintf("%.2f", mc$validation$mean_auc)), div(class = "l", "mean AUC, held-out region")),
          div(class = "ml-kpi", div(class = "v", sprintf("%.0f", mc$validation$mean_median_percentile)), div(class = "l", "median percentile of held-out cells")),
          div(class = "ml-kpi", div(class = "v", format(mc$labels$positive_cells, big.mark = ",")), div(class = "l", "positive cells (9 regions)")),
          div(class = "ml-kpi", div(class = "v", format(mc$labels$unlabeled_cells, big.mark = ",")), div(class = "l", "unlabeled cells"))),
        div(class = "m-grid", style = "margin-bottom:0",
          div(
            h4(class = "small", style = "margin:0 0 6px", "Method"),
            p(class = "small", mc$method, " ", rn("elkan2008"), " ", rn("ranger2017")),
            p(class = "small", strong("Labels: "), mc$labels$source, " ", rn("mcclernan2024")),
            p(class = "small", strong("Excluded: "), mc$excluded_features),
            h4(class = "small", style = "margin:12px 0 6px", "Feature importance (permutation, normalised)"),
            div(lapply(seq_len(nrow(im)), function(i) div(class = "imp-row",
              span(im$description[i]), div(class = "imp-bar", span(style = sprintf("width:%.0f%%", 100 * max(0, im$importance[i])))),
              span(class = "num", sprintf("%.2f", im$importance[i])))))),
          div(
            h4(class = "small", style = "margin:0 0 6px", "Leave-one-region-out validation"),
            tags$table(class = "table-clean",
              tags$thead(tags$tr(tags$th("Held-out region"), tags$th(class = "num", "Cells"), tags$th(class = "num", "AUC"),
                                 tags$th(class = "num", "Median pct."), tags$th(class = "num", "In top 20 %"))),
              tags$tbody(lapply(seq_len(nrow(cvt)), function(i) tags$tr(
                tags$td(cvt$region[i]), tags$td(class = "num", cvt$cells[i]), tags$td(class = "num", sprintf("%.2f", cvt$auc[i])),
                tags$td(class = "num", sprintf("%.0f", cvt$median_percentile[i])), tags$td(class = "num", sprintf("%.0f %%", cvt$share_top20[i])))))),
            h4(class = "small", style = "margin:12px 0 6px", "Limitations"),
            tags$ul(class = "limits", lapply(mc$limitations, tags$li)))))
    },

    div(class = "m-card",
      h3("Source registry"),
      tags$table(class = "table-clean registry",
        tags$thead(tags$tr(tags$th("#"), tags$th("Source"), tags$th("Type"), tags$th("Used for"), tags$th("Licence / terms"), tags$th("Status"))),
        tags$tbody(reg_rows))),

    div(class = "m-grid",
      div(class = "m-card",
        h3("Artemis candidate regions coverage"),
        p(class = "small muted", paste0("Nine regions announced 28 Oct 2024 ", rn("nasa2024"), ". Regions are ~15 km areas, not points; a region is mapped only where a published point exists.")),
        tags$table(class = "table-clean",
          tags$tbody(lapply(seq_len(nrow(regions)), function(i) {
            mp <- regions$mapped_point[i]
            tags$tr(tags$td(regions$name[i]),
              tags$td(if (!is.null(mission$regions)) span(class = "st st-ok", paste0("Outline ", rn("mcclernan2024"), if (!is.na(mp)) paste(" · point", mp) else ""))
                      else if (is.na(mp)) span(class = "st st-plan", paste("Awaiting region grid", rn("mcclernan2024"))) else span(class = "st st-ok", paste("Mapped ·", mp))))
          })))),
      div(class = "m-card",
        h3("Assumptions & limitations"),
        tags$ul(class = "limits",
          tags$li(strong("Suitability layer. "), "Weighted mean (0–100) of the share of terrain below the slope limit (LOLA), Sun and Earth visibility (terrain-free geometry). The slope limit is a user assumption, not a vehicle specification."),
          tags$li(strong("Terrain horizon. "), "Mission-window elevations are measured above the real skyline: exact 360° horizons from the LOLA 80 m elevation model (2 m observer, 150 km, curvature) for published sites and landings, and a small neural network trained on 20,000 exact horizons for other points between 80° and 90° S (data-raw/build_horizons.py, train_horizon_ml.py). The map's window layers still use a smooth Moon."),
          tags$li(strong("Mission context. "), paste0("Regions were defined for Artemis III. Since Feb 2026, Artemis III is an Earth-orbit test and the first crewed landing is planned as Artemis IV ", rn("artemis2026"), ".")),
          tags$li(strong("Centre-of-disc criterion. "), "Sun/Earth count as visible when their centre is above the horizon; no solar-panel height, no partial disc."),
          tags$li(strong("Not modelled. "), paste0("Boulders, gravity anomalies, trajectory and propellant. These would need sub-metre imagery, GRAIL gravity ", rn("grail_gl0660b"), " and vehicle data, so the app leaves them out rather than guessing.")),
          tags$li(strong("Imagery. "), paste0("Base map from the NASA SVS 8k mosaic ", rn("svs4720"), " (≈ 1.3 km/px in latitude), re-projected to a polar view and contrast-adjusted (data-raw/build_textures.py). Radial streaks near the pole come from the source's polar fill. Orientation only; never used in a calculation.")))))
  )
}

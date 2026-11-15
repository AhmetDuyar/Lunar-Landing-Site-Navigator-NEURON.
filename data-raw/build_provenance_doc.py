#!/usr/bin/env python3
"""Generate DATA_PROVENANCE.md from the machine-readable registry.

Single source of truth: data/sources.json, data/sites.csv and the QA files in
data/processed/. Run after any data change:
    python3 data-raw/build_provenance_doc.py
"""
import csv
import json
import os
from datetime import datetime, timezone

ROOT = os.path.join(os.path.dirname(__file__), "..")
J = lambda *p: os.path.join(ROOT, *p)

reg = json.load(open(J("data", "sources.json"), encoding="utf-8"))
val = json.load(open(J("data", "processed", "ephemeris_validation.json")))
tex = json.load(open(J("data", "processed", "texture_provenance.json")))
sites = list(csv.DictReader(open(J("data", "sites.csv"), encoding="utf-8")))
src = reg["sources"]
terrain_prov = J("data", "processed", "terrain_provenance.json")
terrain = json.load(open(terrain_prov)) if os.path.exists(terrain_prov) else None
if terrain:
    for s_ in src:
        if s_["id"] == "lola_pgda":
            s_["status"] = "ingested"; s_["accessed"] = terrain["generated_utc"][:10]
            s_["code"] = "data-raw/build_terrain.R -> data/processed/terrain_grid.csv.gz, site_terrain.csv, www/assets/moon_south_hill.jpg"
        if s_["id"] == "mazarico2011" and "illum_sun" in terrain["inputs"]:
            s_["status"] = "ingested"; s_["accessed"] = terrain["generated_utc"][:10]
num = {s["id"]: i + 1 for i, s in enumerate(src)}

out = []
w = out.append
w("# Data provenance: NEURON Lunar Navigator\n")
w(f"_Generated {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC from `data/sources.json` by "
  "`data-raw/build_provenance_doc.py`. Do not edit by hand._\n")
w("Every value shown in the app belongs to exactly one class:\n")
w("| Class | Meaning |\n|---|---|")
w("| **Computed** | Derived in this project from the inputs below; reproducible with the scripts in `data-raw/`. |")
w("| **Measured** | Observed position of a landed spacecraft. |")
w("| **Literature** | Copied from the cited publication; the transformation (e.g. DMS → decimal) is stated. |")
w("| **NASA** | Official programme information. |")
w("| **Not ingested** | Dataset identified but not yet processed. Displayed as n/a, never estimated. |\n")
w(f"Reference frame: {reg['frame']}\n")

for status, title in (("ingested", "1. Datasets in use"), ("context", "2. Context sources"), ("planned", "3. Planned datasets (not yet in the app)")):
    rows = [s for s in src if s["status"] == status]
    if not rows:
        continue
    w(f"## {title}\n")
    for s in rows:
        w(f"### [{num[s['id']]}] {s['title']}\n")
        w(f"- **Authors / provider:** {s['authors']} ({s['year']}). {s['venue']}.")
        w(f"- **Source:** <{s['url']}>")
        w(f"- **Licence / terms:** {s['license']}")
        w(f"- **Files taken:** {s.get('files', 'n/a')}")
        w(f"- **Accessed:** {s.get('accessed', 'n/a')}")
        w(f"- **Processing:** {s.get('processing', 'n/a')}")
        w(f"- **Used for:** {s['used_for']}")
        w(f"- **Where in the code:** `{s.get('code', 'n/a')}`\n")

w("## 4. Candidate points\n")
w("| ID | Name | Lat | Lon E | Coordinate source | Literature illumination |\n|---|---|---|---|---|---|")
for r in sites:
    lit = f"{r['lit_illum_pct']} % [{num[r['lit_illum_source']]}]: {r['lit_illum_definition']}" if r["lit_illum_pct"] else "not published"
    w(f"| {r['id']} | {r['name']} | {float(r['lat']):.6f} | {float(r['lon_e']):.6f} | [{num[r['coord_source']]}] {r['coord_kind']} | {lit} |")
w("")

w("## 5. Quality checks\n")
w("### Ephemeris (`data/processed/ephemeris_validation.json`)\n")
w("| Check | Result | Expected |\n|---|---|---|")
w(f"| DE421 vs IAU 2015, Sun direction | {val['de421_vs_iau2015_sun_direction_max_deg']}° | < 0.01° |")
w(f"| DE421 vs IAU 2015, Earth direction | {val['de421_vs_iau2015_earth_direction_max_deg']}° | < 0.01° |")
w(f"| Sub-solar latitude | {val['subsolar_latitude_range_deg']} | within ±1.6° |")
w(f"| Sub-Earth latitude / longitude | {val['subearth_latitude_range_deg']} / {val['subearth_longitude_range_deg']} | within ±7.0° / ±8.2° |")
w(f"| Earth–Moon distance (km) | {val['earth_moon_distance_range_km']} | 356,000–407,000 |")
e = val["eclipse_2026_03_03"]
w(f"| Total lunar eclipse 2026-03-03 | {e['min_sun_earth_separation_deg']}° at {e['at_utc']} | < {round(e['earth_apparent_radius_deg'] - 0.26, 2)}° |")
w(f"\nOverall: **{'PASS' if val['passed'] else 'FAIL'}** · {val['n_epochs']:,} hourly epochs · generated {val['generated_utc']}\n")
w("### Base map (`data/processed/texture_provenance.json`)\n")
w(f"- Source file: `{tex['source_file']}`, SHA-256 `{tex['source_sha256']}`")
w(f"- Obtained via: {tex.get('obtained_via', 'NASA SVS')}")
w(f"- Verification: {tex.get('verification', 'n/a')}")
w(f"- Limitation: {tex['effective_resolution_note']}")
w(f"- Use: {tex['use']}\n")

if terrain:
    w("### Terrain (`data/processed/terrain_provenance.json`)\n")
    w("| Input file (unmodified) | Bytes | MD5 | Pixel size | CRS |\n|---|---|---|---|---|")
    for k in [k for k in ("slope", "hillshade", "illum_sun", "illum_earth") if k in terrain["inputs"]]:
        x = terrain["inputs"][k]
        w(f"| {x['file']} | {x['bytes']:,} | `{x['md5']}` | {' x '.join(str(v) for v in x['res_m'])} m | `{x['crs_proj4']}` |")
    for k, v in terrain["method"].items():
        w(f"- **{k.capitalize()}:** {v}")
    w(f"- **Limitation:** {terrain['limitations']}\n")
else:
    w("### Terrain\n\nNot yet processed. Run `Rscript data-raw/build_terrain.R` with the LOLA files in `data-raw/input/`.\n")

ivp = J("data", "processed", "illum_validation.json")
if os.path.exists(ivp):
    iv = json.load(open(ivp))
    w("### Illumination vs literature (`data/processed/illum_validation.json`)\n")
    w(iv["method"] + "\n")
    w("| Site | Literature | Mazarico point | Mazarico max 1 km | Status |\n|---|---|---|---|---|")
    for r in iv["rows"]:
        w(f"| {r['name']} | {r['literature_pct']} % [{num[r['literature_source']]}] ({r['literature_definition']}) | {r['mazarico_point_pct']} % | {r['mazarico_max_1km_pct']} % ({r['delta_max_1km_pp']:+} pp) | {'consistent' if r['agrees_within_10pp_1km'] else 'DISCREPANCY'} |")
    w("\n" + iv["notes"] + "\n")

if os.path.exists(J("data", "processed", "artemis_regions.json")):
    for s_ in src:
        if s_["id"] == "mcclernan2024":
            s_["status"] = "ingested"; s_["used_for"] = "Exact outlines of the nine candidate regions on the map"
mlp = J("data", "processed", "ml_model_card.json")
if os.path.exists(mlp):
    for s_ in src:
        if s_["id"] == "mcclernan2024": s_["status"] = "ingested"
    mc = json.load(open(mlp))
    w("### Machine-learning model (`data/processed/ml_model_card.json`)\n")
    w(f"- **Question:** {mc['question']}")
    w(f"- **Not claimed:** {mc['not_claimed']}")
    w(f"- **Method:** {mc['method']}")
    w(f"- **Labels:** {mc['labels']['source']}; {mc['labels']['positive_cells']:,} positive / {mc['labels']['unlabeled_cells']:,} unlabeled cells")
    w(f"- **Excluded features:** {mc['excluded_features']}\n")
    w("| Held-out region | Cells | AUC | Median percentile | In top 20 % |\n|---|---|---|---|---|")
    for r in mc["validation"]["per_region"]:
        w(f"| {r['region']} | {r['cells']} | {r['auc']} | {r['median_percentile']} | {r['share_top20']} % |")
    w(f"\nMean AUC **{mc['validation']['mean_auc']}**.\n")
    w("| Feature | Importance |\n|---|---|")
    for r in mc["importance"]:
        w(f"| {r['description']} | {r['importance']} |")
    w("")
    if mc["labels"].get("source_zips"):
        w("Source ZIPs (USGS ScienceBase, unmodified):\n")
        w("| File | Bytes | MD5 |\n|---|---|---|")
        for z in mc["labels"]["source_zips"]:
            w(f"| {z['file']} | {z['bytes']:,} | `{z['md5']}` |")
        w("")

w("## 6. Data flow\n")
w("```text")
w("de421 + jplephem ─┐")
w("moon_080317 rot. ─┼─ data-raw/build_ephemeris.py ─► ephemeris_moon_me_1h.csv.gz ─┐")
w("IAU 2015 (check) ─┘                                ephemeris_validation.json      │")
w("sites.csv (literature / LROC) ───────────────────────────────────────────────────┤")
w("                                                                                 ▼")
w("                       data/interfaces.R: site_geometry(), window_metrics(), heat_grid(), point_criteria(), score_points()")
w("                                                                                 ▼")
w("                                                   app (ranking, timeline, map layer)")
w("AVGVISIB_75S (+_EARTH) ─┐")
w("LDSM/LDEM_HILL 80S ── data-raw/build_terrain.R ─► terrain_grid, site_terrain, hillshade ─► suitability layer, slope criterion")
w("USGS region grids ── data-raw/build_ml.R (+ terrain & illumination grids) ─► ml_grid, model card, region outlines")
w("lroc_color_poles_8k ── data-raw/build_textures.py ─► base map (visual only)")
w("original rasters + USGS outlines + Peña-Asensio Table 3 ── data-raw/analysis_regions.R ─► region_stats, nr2_published_points, deep_dive_nr2")
w("region_stats + ephemeris windows ── data-raw/analysis_robustness.R ─► robustness.json ─► ANALYSIS.md (build_analysis_report.py)")
w("original rasters + sites.csv + landings.csv ── data-raw/build_dossiers.R ─► dossiers.json.gz ─► site dossier (R/dossier.R, www/dossier.js)")
w("NASA NSSDCA lander table ── transcribed ─► data/landings.csv ─► landing markers and dossiers")
w("grids + USGS outlines + dossiers ── data-raw/build_validation.R ─► validation_checks.json ─► Validation view (R/story.R, www/story.js)")
w("```\n")
w("Validation of results against original rasters and a published site analysis, and the robustness test, are documented in [ANALYSIS.md](ANALYSIS.md).\n")
open(J("DATA_PROVENANCE.md"), "w", encoding="utf-8").write("\n".join(out))
print("wrote DATA_PROVENANCE.md,", len(out), "lines")

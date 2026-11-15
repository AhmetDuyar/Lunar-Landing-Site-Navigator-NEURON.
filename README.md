# NEURON. Lunar Navigator

**We compare potential landing areas by terrain, illumination and Earth visibility.**

**NASA Space Apps Challenge 2026 · Team NEURON. · Ahmet Duyar**

Live app: https://kw1fpt-ahmet-duyar.shinyapps.io/neuron-lunar-navigator/

Technical paper: [`docs/NEURON_technical_paper.pdf`](docs/NEURON_technical_paper.pdf) · Presentation (7 slides): [`docs/NEURON_presentation.pdf`](docs/NEURON_presentation.pdf)

An R/Shiny research prototype for the lunar south pole. It evaluates the nine NASA Artemis candidate regions and published landing points with LOLA terrain, Mazarico et al. (2011) illumination and JPL DE421 geometry, checks its numbers against the original rasters and published site analyses (see [ANALYSIS.md](ANALYSIS.md)), and tests whether rankings survive changes in weights, slope limits and mission dates.

**Full data documentation:** [`DATA_PROVENANCE.md`](DATA_PROVENANCE.md): every dataset with source, files, access date, processing, purpose and code location (generated from `data/sources.json` via `python3 data-raw/build_provenance_doc.py`).

## Quick start

```r
install.packages(c("shiny", "jsonlite"))   # once
shiny::runApp(".", launch.browser = TRUE)  # from this folder
```

R ≥ 4.1, a WebGL browser. No API keys, no network calls at runtime.

## What is real in this app

| Layer | Content | Provenance |
|---|---|---|
| Ephemeris | Hourly Sun/Earth vectors 2026–2030 in the Moon Mean-Earth frame | Computed from JPL DE421 incl. lunar librations; PA→ME rotation per NAIF `moon_080317.tf` |
| Validation | DE421 vs independent IAU 2015 rotation model: max Δ 0.004°; libration/obliquity/distance ranges; 2026-03-03 total lunar eclipse reproduced | `data/processed/ephemeris_validation.json` |
| Sites | 5 published points (Connecting Ridge, Haworth, Nobile Rim 1 & 2, Mons Mouton/IM-2 landing) | Koebel et al. 2012; ICES-2024-211; Peña-Asensio et al. 2025; LROC 2025 |
| Regions | Nine Artemis candidate regions (Oct 2024) | NASA news release; George et al., LPSC 2026 |
| Literature values | Terrain-aware long-term illumination where published | Shown separately with citation |
| Score | Weighted mean of flat ground within 1 km (LOLA), long-term Sun and Earth visibility with terrain (Mazarico et al. 2011); absolute 0 to 100; same formula as the map | `point_criteria()`, `score_points()` in `data/interfaces.R` |
| Timing | Mission-window geometry (smooth Moon, no terrain): when Sun and Earth are up; not used in the score | Computed from DE421 |
| Map layer | Earth / Sun visibility raster, 120 × 120 polar grid (80°S–90°S), isolines every 10 % | Computed from the same DE421 geometry (`heat_grid()`) |
| Base map | Greyscale global 4k + south-polar re-projection 4096 px (75°S–90°S) | NASA SVS CGI Moon Kit `lroc_color_poles_8k`; processing in `data-raw/build_textures.py`, provenance in `data/processed/texture_provenance.json` |

Nothing is synthetic. Values that would need datasets not yet ingested (slope, hazards,
permanent shadow) are shown as “n/a” with a *Pipeline planned* badge, never estimated.

## Structure

```text
app.R                         UI composition and reactive wiring
R/
  ui_helpers.R                provenance badges, references, SVG elevation chart
  mod_controls.R              mission window, map layers, three score weights
  mod_globe.R                 Three.js bridge (sites, layers, Sun/Earth direction)
  mod_panels.R                ranked site list + site inspector
  mod_timeline.R              elevation timeline + time scrubber
  mod_methods.R               Data & Methods view (registry, pipeline, validation)
data/
  interfaces.R                loading, integrity checks, geometry, window metrics, landing score
  sites.csv                   candidate points; every row cites a source id
  sources.json                provenance registry (15 sources, status in use / planned)
  processed/
    ephemeris_moon_me_1h.csv.gz   43,824 hourly epochs
    ephemeris_validation.json     QA results shown in the app
data-raw/
  build_ephemeris.py          reproducible build of the processed ephemeris
  build_textures.py           greyscale global map + south-polar projection
www/                          style.css, script.js, assets (NASA base maps, three.js)
```

## Terrain (LOLA): slope, suitability map, relief

Copy the two unmodified PGDA product 90 files (and optionally the two Mazarico 2011 `AVGVISIB_75S` IMG/LBL pairs) into `data-raw/input/` and run once:

```r
install.packages(c("terra", "jsonlite"))
source("data-raw/build_terrain.R")   # ~2–6 min; writes small products to data/processed/ and www/assets/
# python3 data-raw/validate_illumination.py && python3 data-raw/build_provenance_doc.py
```

The app detects the outputs automatically: the *Landing suitability* and *Flat terrain* layers, the slope column in the ranking, slope in the site details and the LOLA relief appear. Without them the app runs and shows *Pipeline planned*.

## Machine-learning model (positive-unlabeled learning)

*Question:* which places share the measurable properties of NASA's nine Artemis candidate regions? Labels are the official USGS 1 km region grids (McClernan 2024, CC0; only the 1 km shapefiles are kept, packed as `data-raw/regions_usgs_1km.zip`; unzip it in `data-raw/` before re-running the scripts, ZIP checksums in `source_zips_md5.csv`). Features are LOLA slope and Mazarico illumination per ~1.5 km cell (no coordinates). A class-balanced random forest (`ranger`) is validated by leaving one region out at a time; results, feature importance and limitations are in `data/processed/ml_model_card.json` and the *Data & Methods* tab.

```r
install.packages(c("terra", "ranger", "jsonlite"))
source("data-raw/build_ml.R")        # after build_terrain.R; ~2–4 min
```

## Terrain horizons and the ML surrogate

Mission-window values (Sun and Earth up, countdown to sunset and Earthset, Compare page, dossier strips) are measured above the **real skyline**:

* `data-raw/build_horizons.py` computes exact 360° horizons from the LOLA 80 m elevation model `LDEM_80S_80MPP_ADJ` (2 m observer, 150 km, lunar curvature) for the curated sites and south-polar landings, plus 20,000 random points for training. Check 7 compares the resulting 2026 to 2030 Sun and Earth visibility with Mazarico et al. at 1,500 points: r = 0.996 (Sun) and r = 0.997 (Earth).
* `data-raw/train_horizon_ml.py` trains a small neural network (3,121 parameters) that predicts the exact horizon from a 1.28 km version of the DEM (< 1 MB, shipped as `data/processed/dem_1280m.bin.gz`). 5-fold spatial cross-validation on 30 km blocks: mean error 0.94° (coarse terrain alone 1.47°, no terrain 5.5°). The app evaluates the network in R for any clicked point (`predict_horizon()` in `data/interfaces.R`); curated sites and landings always use the exact horizon. Model card: `data/processed/horizon_ml_card.json`.

```bash
# DEM as raw float32 (row-major), e.g. with R/terra:  writeBin(as.numeric(values(rast(tif))), "ldem.f32", size = 4)
python3 data-raw/build_horizons.py ldem.f32
python3 data-raw/train_horizon_ml.py ldem.f32
python3 data-raw/summarise_horizons.py
```

## Rebuild the base map

```bash
pip install numpy scipy pillow
python3 data-raw/build_textures.py /path/to/lroc_color_poles_8k.tif   # from svs.gsfc.nasa.gov/4720
```

## Rebuild the ephemeris

```bash
pip install jplephem==2.24 de421==2008.1 numpy
python3 data-raw/build_ephemeris.py   # exits non-zero if any validation check fails
```

## Method in one paragraph

DE421 gives barycentric Sun, Earth and Moon positions (TDB = UTC + 69.184 s). Sun and
Earth are light-time corrected as seen from the Moon's centre and rotated into the
lunar principal-axis frame with DE421's libration angles, then into the Mean-Earth
frame. For any surface point on a 1737.4 km sphere the app builds a local
east-north-up basis, applies Earth parallax and computes hourly elevation and
azimuth. Window metrics are the share of hours with the body's centre above the
horizon and the longest continuous run below it.

## Limitations

- **Terrain-free horizon.** Near the pole, crater rims and massifs dominate real
  illumination. Geometric values are a reference; terrain-aware literature values are
  displayed separately. Next step: LOLA horizon masks (PGDA product 81) and
  Mazarico et al. 2011 illumination maps (PGDA product 69).
- Region outlines (USGS, McClernan 2024, doi:10.5066/P1MEQ6UK) are not yet ingested;
  only regions with a published point are mapped.
- Mission context: since Feb 2026 Artemis III is an Earth-orbit test; the first
  crewed landing is planned as Artemis IV (2028).
- Research prototype, not for operational mission planning. No NASA endorsement implied.

## Attribution

Imagery: NASA SVS CGI Moon Kit (svs.gsfc.nasa.gov/4720), NASA/GSFC/ASU.
three.js r160.1 + OrbitControls, MIT (www/assets/THREE-LICENSE.txt).
Full reference list: Data & Methods tab in the app, or `data/sources.json`.

## What this tool is, and what it is not

**It is** a transparent, reproducible comparison of candidate landing areas built on NASA data (LOLA, Mazarico et al. 2011), the USGS outlines of NASA's nine Artemis regions and published site studies, plus a robustness test and checks against real landings.

**It is not** new lunar science, a landing-site certification, or a claim to find the one best spot. With 80 m pixels it compares areas; boulders and craters smaller than about 100 m are invisible (IM-2 tipped over in one). Final selection needs 1 to 5 m data and the lander's own constraints.

**Where vs. when.** The score uses only terrain-aware long-term data. The mission window (JPL DE421 on a smooth Moon) tells you when Sun and Earth are up and is labelled "no terrain" everywhere.

## Compare view (sites and dates)

The **Compare** tab answers the challenge's core question in one screen: every site as an hour-by-hour strip for the mission window (orange = Sun and Earth up, light orange = Sun only, grey = Earth only, black = neither), with Sun, Earth and both percentages, longest night and blackout, the best landing window and the time until sunset and Earthset. A second mode shows one site across the next 12 lunar months; buttons step the whole comparison by one lunar month. The **When** card on Explore adds a live countdown to sunset and Earthset at the cursor time.

## Validation view

The **Validation** tab tells the project as one scrolling story (question, data, method, six checks, robustness, result, limits). Every chart is drawn from `data/processed/`:

1. Ephemeris DE421 vs IAU 2015 (max 0.004°), librations, eclipse of 3 March 2026.
2. Earth visibility vs Peña-Asensio et al. (2025), 12 points, r = 0.998.
3. Two independent code paths agree within 0.3° slope and 3.6 pp flat ground; 1.5 km grid vs original pixels within ~2 pp.
4. Long-term sunlight vs literature: Connecting Ridge within 2.3 pp, Haworth an open 20 pp difference.
5. NASA's nine regions score higher than the rest of the band (AUC 0.60): more light and Earth view, less flat ground.
6. Real landings: IM-1 11.0° vs ~12° reported; IM-2 shows the 80 m limit.

`Rscript data-raw/build_validation.R` computes checks 3 and 5.

## Evidence (ANALYSIS.md)

Two checks, generated from the original rasters:

1. **Robustness:** `data-raw/analysis_robustness.R`: 40,000 weight × slope-limit scenarios for the nine NASA regions and 24,000 mission-window × weight scenarios for the five candidate points.
2. **Deep dive Nobile Rim 2:** `data-raw/analysis_regions.R`: region statistics on original pixels vs. the app grid, and re-evaluation of the 12 published points of Peña-Asensio et al. (2025).

Run order: `build_terrain.R` → `analysis_regions.R` → `analysis_robustness.R` → `build_analysis_report.py` → `build_provenance_doc.py`. Results appear at the top of *Data & Methods* in the app and in [`ANALYSIS.md`](ANALYSIS.md).

## Site dossier and previous landings

Clicking a pin opens a dossier that explains *why* a place ranks where it does:

- every criterion on one axis with all compared places, and what the current weights reward;
- a 12.8 km window of the original LOLA 80 m slope and relief and the Mazarico 120 m Sun and Earth maps, with the best flat spot within 3 km;
- light and radio contact for the next 12 lunar months and hour by hour for the selected window;
- the rank distribution from the robustness test, strengths, weaknesses and the nearest previous landings.

All previous soft landings, crashes and the planned Chang'e 7 site are on the map (`data/landings.csv`, transcribed from the NASA NSSDCA lander table, LROC positions). South-polar landings get the same terrain window: at IM-1 Odysseus our 80 m slope is 11.0°, matching the ~12° reported for the site where it tipped over.

Build: `Rscript data-raw/build_dossiers.R` (needs the original rasters in `data-raw/input/`) writes `data/processed/dossiers.json.gz`.

## Use of AI

We used Claude (Anthropic) as an AI assistant to optimise the code and the machine-learning models and to help write the documentation, the technical paper and the slides. All data, methods and results come from our own scripts on NASA data and were checked by us.

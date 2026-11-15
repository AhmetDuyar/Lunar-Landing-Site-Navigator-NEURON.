# Data provenance: NEURON Lunar Navigator

_Generated 2026-11-14 08:53 UTC from `data/sources.json` by `data-raw/build_provenance_doc.py`. Do not edit by hand._

Every value shown in the app belongs to exactly one class:

| Class | Meaning |
|---|---|
| **Computed** | Derived in this project from the inputs below; reproducible with the scripts in `data-raw/`. |
| **Measured** | Observed position of a landed spacecraft. |
| **Literature** | Copied from the cited publication; the transformation (e.g. DMS → decimal) is stated. |
| **NASA** | Official programme information. |
| **Not ingested** | Dataset identified but not yet processed. Displayed as n/a, never estimated. |

Reference frame: Moon Mean-Earth/polar-axis (ME) frame realised with JPL DE421; planetocentric latitude, east-positive longitude 0-360; mean radius 1737.4 km.

## 1. Datasets in use

### [1] The Planetary and Lunar Ephemeris DE 421

- **Authors / provider:** Folkner, W. M.; Williams, J. G.; Boggs, D. H. (2009). JPL IPN Progress Report 42-178.
- **Source:** <https://ipnpr.jpl.nasa.gov/progress_report/42-178/178C.pdf>
- **Licence / terms:** NASA/JPL public data; Python packaging de421 2008.1 + jplephem 2.24 (MIT)
- **Files taken:** Python packages de421==2008.1 (jpl-*.npy Chebyshev coefficients) and jplephem==2.24
- **Accessed:** 2026-11-13
- **Processing:** Sun/Earth/Moon positions at TDB = UTC + 69.184 s, light-time corrected, rotated to Moon ME; hourly 2026-01-01 to 2030-12-31
- **Used for:** Sun, Earth and Moon positions and lunar physical librations, 2026-2030, hourly
- **Where in the code:** `data-raw/build_ephemeris.py -> data/processed/ephemeris_moon_me_1h.csv.gz`

### [2] Lunar frames kernel moon_080317.tf (MOON_PA_DE421 to MOON_ME_DE421 rotation)

- **Authors / provider:** NASA JPL Navigation and Ancillary Information Facility (NAIF) (2008). NAIF generic kernels.
- **Source:** <https://naif.jpl.nasa.gov/pub/naif/generic_kernels/fk/satellites/moon_080317.tf>
- **Licence / terms:** NASA public data
- **Files taken:** Rotation angles 67.92/78.56/0.30 arcsec (MOON_PA_DE421 -> MOON_ME_DE421)
- **Accessed:** 2026-11-13
- **Processing:** Applied after the DE421 libration rotation; sign verified against IAU 2015 (max diff 0.004 deg)
- **Used for:** Principal-axis to Mean-Earth frame rotation (67.92, 78.56, 0.30 arcsec)
- **Where in the code:** `data-raw/build_ephemeris.py: rot_icrf_to_me_de421()`

### [3] Report of the IAU Working Group on Cartographic Coordinates and Rotational Elements: 2015

- **Authors / provider:** Archinal, B. A. et al. (2018). Celestial Mechanics and Dynamical Astronomy 130, 22.
- **Source:** <https://doi.org/10.1007/s10569-017-9805-5>
- **Licence / terms:** Published model coefficients
- **Files taken:** Published coefficients (Table: Moon)
- **Accessed:** 2026-11-13
- **Processing:** Independent second orientation model, validation only
- **Used for:** Independent cross-check of DE421 lunar orientation (validation only)
- **Where in the code:** `data-raw/build_ephemeris.py: rot_icrf_to_me_iau(); data/processed/ephemeris_validation.json`

### [4] NASA Provides Update on Artemis III Moon Landing Regions

- **Authors / provider:** NASA (2024). NASA news release, 28 Oct 2024.
- **Source:** <https://www.nasa.gov/news-release/nasa-provides-update-on-artemis-iii-moon-landing-regions/>
- **Licence / terms:** NASA public information
- **Files taken:** n/a
- **Accessed:** 2026-11-14
- **Processing:** Region names transcribed
- **Used for:** List of the nine candidate landing regions
- **Where in the code:** `data/sources.json: artemis_regions_2024; data/sites.csv: region_status`

### [5] Artemis III Site Selection Update: Downselection from Thirteen to Nine Candidate Regions

- **Authors / provider:** George, T.; Rubio, M. A.; Lawrence, S. J.; Curell, P. (2026). Lunar and Planetary Science Conference (LPSC) 2026, NTRS 20250011660.
- **Source:** <https://ntrs.nasa.gov/citations/20250011660>
- **Licence / terms:** NASA Technical Reports Server
- **Files taken:** n/a
- **Accessed:** 2026-11-14
- **Processing:** Criteria context only (no values used)
- **Used for:** Selection criteria context: terrain hazards, illumination, Direct-to-Earth visibility
- **Where in the code:** `Data & Methods text`

### [7] Analysis of landing site attributes for future missions targeting the rim of the lunar South Pole Aitken basin

- **Authors / provider:** Koebel, D.; Bonerba, M.; Behrenwaldt, D.; Wieser, M.; Borowy, C. (2012). Acta Astronautica 80, 197-215.
- **Source:** <https://www.sciencedirect.com/journal/acta-astronautica/vol/80>
- **Licence / terms:** Cited values only
- **Files taken:** n/a
- **Accessed:** 2026-11-14
- **Processing:** Coordinates 89°28′S 136°40′W converted to decimal (−89.466667, 223.333333 E); 85.7 % copied
- **Used for:** Connecting Ridge coordinates (89°28′S, 136°40′W) and 85.7 % integral illumination
- **Where in the code:** `data/sites.csv row CR`

### [8] Evaluating Potential Landing Regions for Artemis III: Multi-Attribute Decision-Making Framework for Power, ISRU, and Human Factors at the Lunar South Pole

- **Authors / provider:** ICES-2024-211 (2024). 53rd International Conference on Environmental Systems (ICES).
- **Source:** <https://ttu-ir.tdl.org/server/api/core/bitstreams/1602811b-0ad5-4fff-b607-c9c77c99ba2f/content>
- **Licence / terms:** Cited values only
- **Files taken:** n/a
- **Accessed:** 2026-11-14
- **Processing:** Coordinates copied; Sun visibility 0.7032 converted to 70.32 %
- **Used for:** Haworth point and 0.7032 Sun visibility; Nobile Rim 1 landing point
- **Where in the code:** `data/sites.csv rows HW, NR1`

### [9] Evaluating potential landing sites for the Artemis III mission using a multi-criteria decision making approach

- **Authors / provider:** Peña-Asensio, E.; Neira-Acosta, Á.-S.; Sánchez-Lozano, J. M. (2025). Acta Astronautica 226, 469-478.
- **Source:** <https://doi.org/10.1016/j.actaastro.2024.10.049>
- **Licence / terms:** Cited values only
- **Files taken:** n/a
- **Accessed:** 2026-11-14
- **Processing:** Coordinates 84°12′5.61″S 60°41′59.61″E (decimal as published); Table 3 values (Ri, C3, C4 DN) transcribed and re-evaluated on original LOLA/Mazarico rasters (data-raw/analysis_regions.R)
- **Used for:** Nobile Rim 2 optimum point; Table 3 (12 Nobile Rim 2 points) used as published reference in the deep dive. Their TOPSIS ranking was used in earlier versions and replaced by an absolute score.
- **Where in the code:** `data/sites.csv row NR2; data-raw/analysis_regions.R`

### [10] IM-2 Athena Seen Obliquely (LROC featured image 1408)

- **Authors / provider:** LROC Team, NASA/GSFC/Arizona State University (2025). Lunar Reconnaissance Orbiter Camera.
- **Source:** <https://www.lroc.asu.edu/images/1408>
- **Licence / terms:** NASA/GSFC/ASU
- **Files taken:** n/a
- **Accessed:** 2026-11-14
- **Processing:** Coordinates copied
- **Used for:** IM-2 Athena landing position on Mons Mouton (84.7906°S, 29.1957°E)
- **Where in the code:** `data/sites.csv row MM`

### [11] CGI Moon Kit - lroc_color_poles_8k (8192 x 4096)

- **Authors / provider:** NASA Scientific Visualization Studio; NASA/GSFC/Arizona State University (2019). NASA SVS 4720.
- **Source:** <https://svs.gsfc.nasa.gov/4720/>
- **Licence / terms:** NASA imagery; credit required, no endorsement implied
- **Files taken:** lroc_color_poles_8k.tif (SHA-256 in data/processed/texture_provenance.json)
- **Accessed:** 2026-11-14
- **Processing:** Greyscale; global 4k downsample; south-polar azimuthal-equidistant re-projection 75–90°S, contrast and sharpening
- **Used for:** Base map: greyscale global 4k and south-polar re-projection (visual only; source SHA-256 in data/processed/texture_provenance.json)
- **Where in the code:** `data-raw/build_textures.py -> www/assets/moon_global_4k.jpg, moon_south_cap.jpg`

### [12] three.js r160.1 and OrbitControls

- **Authors / provider:** three.js authors (2024). https://threejs.org.
- **Source:** <https://github.com/mrdoob/three.js>
- **Licence / terms:** MIT (www/assets/THREE-LICENSE.txt)
- **Files taken:** www/assets/three.module.js, OrbitControls.js
- **Accessed:** 2026-11-13
- **Processing:** Unmodified except OrbitControls import path
- **Used for:** WebGL globe rendering
- **Where in the code:** `www/script.js`

### [13] A New View of the Lunar South Pole from LOLA: large-area DEM, slope and hillshade, 80–90°S

- **Authors / provider:** Barker, M. K. et al. (2023). Planetary Science Journal 4, 183; NASA GSFC PGDA product 90.
- **Source:** <https://pgda.gsfc.nasa.gov/products/90>
- **Licence / terms:** NASA public data
- **Files taken:** LDSM_80S_80MPP_ADJ.tif(f) (slope, deg) and LDEM_80S_80MPP_ADJ_HILL.tif(f) (hillshade); MD5 recorded in data/processed/terrain_provenance.json
- **Accessed:** 2026-11-14
- **Processing:** Sampled at the app grid via the files own CRS (terra): 400 x 400 grid with median slope and share below 5/8/10/15 deg; 1 km site statistics; 3072 px hillshade image
- **Used for:** Slope criterion in the site ranking, flat-terrain and landing-suitability map layers, relief base map
- **Where in the code:** `data-raw/build_terrain.R -> data/processed/terrain_grid.csv.gz, site_terrain.csv, www/assets/moon_south_hill.jpg`

### [14] Illumination conditions of the lunar polar regions using LOLA topography (18.6-year averages)

- **Authors / provider:** Mazarico, E.; Neumann, G. A.; Smith, D. E.; Zuber, M. T.; Torrence, M. H. (2011). Icarus 211, 1066-1081; PGDA product 69.
- **Source:** <https://pgda.gsfc.nasa.gov/products/69>
- **Licence / terms:** NASA public data
- **Files taken:** AVGVISIB_75S_120M_201608.IMG/.LBL (Sun) and AVGVISIB_75S_120M_201608_EARTH.IMG/.LBL (Earth), 116,250,752 bytes each; permanent shadow = DN 0 in the Sun map (per PDS label)
- **Accessed:** 2026-11-14
- **Processing:** Read through the PDS label (GDAL PDS driver, SCALING_FACTOR 0.00004 applied); 400 x 400 grid mean and permanent-shadow share; site point value, 1 km maximum, nearest permanent shadow within 10 km
- **Used for:** Terrain-aware long-term Sun/Earth visibility: suitability layer, map layers, ranking criteria, site details
- **Where in the code:** `data-raw/build_terrain.R (section 3b) -> data/processed/illum_grid.csv.gz, site_illum.csv`

### [19] Lunar Impact and Landing Sites of Human-Made Objects (Moon artifact table)

- **Authors / provider:** Williams, D. R. (NASA NSSDCA) (2025). NASA Space Science Data Coordinated Archive, page updated 13 Aug 2025.
- **Source:** <https://nssdc.gsfc.nasa.gov/planetary/lunar/lunar_artifact_impacts.html>
- **Licence / terms:** NASA public domain
- **Files taken:** HTML table (transcribed to data/landings.csv)
- **Accessed:** 2026-11-14
- **Processing:** Rows of type soft landing, crewed landing, lander and lander crash transcribed; LM descent stage used for Apollo; west longitudes converted to negative east. Most positions are LROC NAC measurements (Wagner et al. 2017, LROC 2024).
- **Used for:** Positions, dates and outcomes of all previous soft landings and failed landing attempts shown on the map and in the site dossier
- **Where in the code:** `data/landings.csv -> data/interfaces.R load_landings()`

## 2. Context sources

### [6] NASA adds Earth-orbit docking test; first crewed Artemis landing moves to Artemis IV (2028)

- **Authors / provider:** Reuters (2026). Reuters, 27 Feb 2026.
- **Source:** <https://www.yahoo.com/news/articles/nasa-shakes-moon-program-test-151505253.html>
- **Licence / terms:** News report (cited, not reproduced)
- **Files taken:** n/a
- **Accessed:** 2026-11-14
- **Processing:** Mission context only
- **Used for:** Mission context: regions were defined for Artemis III; landing now planned for Artemis IV
- **Where in the code:** `Data & Methods: limitations`

## 3. Planned datasets (not yet in the app)

### [15] JPL lunar gravity field GL0660B (degree and order 660, GRAIL primary mission)

- **Authors / provider:** Konopliv, A. S. et al. (2013). JGR Planets 118, 1415-1434; PDS GRAIL LGRS RDR.
- **Source:** <https://pds-geosciences.wustl.edu/grail/grail-l-lgrs-5-rdr-v1/grail_1001/shadr/jggrx_0660b_sha.xml>
- **Licence / terms:** NASA PDS
- **Files taken:** jggrx_0660b_sha.tab (+ .xml label)
- **Accessed:** n/a
- **Processing:** Evaluate radial gravity anomaly on the analysis grid (truncated degree)
- **Used for:** Local gravity anomaly as a descent/navigation feature
- **Where in the code:** `data-raw/build_gravity.py (to be written)`

### [16] Down Selected Artemis III Candidate Landing Site Navigational Grids

- **Authors / provider:** McClernan, M. T. (2024). U.S. Geological Survey data release.
- **Source:** <https://doi.org/10.5066/P1MEQ6UK>
- **Licence / terms:** CC0 1.0
- **Files taken:** Nine region ZIPs (MD5 in data-raw/regions_usgs_1km/source_zips_md5.csv); only the 1 km LGRS grid shapefiles (*_PolarLGRS_ACC_1km_S_Grid.*) were extracted
- **Accessed:** n/a
- **Processing:** 1 km cells dissolved per region; app grid cells labelled by point-in-polygon in the files own Lunar Polar Stereographic CRS; outlines densified to 1 km and converted to lon/lat
- **Used for:** Exact outlines of the nine candidate regions on the map (ML labels: prepared, model currently disabled)
- **Where in the code:** `data-raw/build_ml.R -> data/processed/artemis_regions.json, ml_grid.csv.gz`

### [17] Learning classifiers from only positive and unlabeled data

- **Authors / provider:** Elkan, C.; Noto, K. (2008). Proc. 14th ACM SIGKDD, 213-220.
- **Source:** <https://doi.org/10.1145/1401890.1401920>
- **Licence / terms:** Cited method
- **Files taken:** n/a
- **Accessed:** 2026-11-14
- **Processing:** Method re-implemented (class-balanced random forest; percentile score)
- **Used for:** Positive-unlabeled learning framework of the ML model
- **Where in the code:** `data-raw/build_ml.R`

### [18] ranger: A Fast Implementation of Random Forests for High Dimensional Data in C++ and R

- **Authors / provider:** Wright, M. N.; Ziegler, A. (2017). Journal of Statistical Software 77(1).
- **Source:** <https://doi.org/10.18637/jss.v077.i01>
- **Licence / terms:** GPL-3 (R package)
- **Files taken:** R package ranger
- **Accessed:** 2026-11-14
- **Processing:** 400 trees, mtry 3, min.node.size 25, class weights, permutation importance
- **Used for:** Random-forest classifier of the ML model
- **Where in the code:** `data-raw/build_ml.R`

## 4. Candidate points

| ID | Name | Lat | Lon E | Coordinate source | Literature illumination |
|---|---|---|---|---|---|
| CR | Connecting Ridge | -89.466667 | 223.333333 | [7] Published landing-site point (89°28′S, 136°40′W) | 85.7 % [7]: Integral solar illumination, Kaguya LALT DEM, 2016 epoch |
| HW | Haworth | -86.805550 | 338.234250 | [8] Published landing-site point (highest Sun visibility in region) | 70.32 % [8]: Sun visibility fraction reported for this point |
| NR1 | Nobile Rim 1 | -85.544190 | 37.626600 | [8] Published landing-site point | not published |
| NR2 | Nobile Rim 2 | -84.201560 | 60.699890 | [9] Published optimum of TOPSIS ranking (1,247 points) | not published |
| MM | Mons Mouton | -84.790600 | 29.195700 | [10] Measured landing position of IM-2 Athena (LROC) | not published |

## 5. Quality checks

### Ephemeris (`data/processed/ephemeris_validation.json`)

| Check | Result | Expected |
|---|---|---|
| DE421 vs IAU 2015, Sun direction | 0.00403° | < 0.01° |
| DE421 vs IAU 2015, Earth direction | 0.00391° | < 0.01° |
| Sub-solar latitude | [-1.588, 1.586] | within ±1.6° |
| Sub-Earth latitude / longitude | [-6.859, 6.857] / [-8.043, 8.051] | within ±7.0° / ±8.2° |
| Earth–Moon distance (km) | [356653, 406677] | 356,000–407,000 |
| Total lunar eclipse 2026-03-03 | 0.423° at 2026-03-03T12:00Z | < 0.69° |

Overall: **PASS** · 43,824 hourly epochs · generated 2026-11-13T23:36:55Z

### Base map (`data/processed/texture_provenance.json`)

- Source file: `lroc_color_poles_8k.tif`, SHA-256 `4af8b0cd4d50c30851359d98e7e72040240dd8d03256b58b345b5b76e9edb4ef`
- Obtained via: Public mirror of the unmodified NASA file (github.com/akshaj99/MoonVis, data/lroc_color_poles_8k.tif) because svs.gsfc.nasa.gov was not reachable from the build environment.
- Verification: Downsampled to 2048x1024 and compared with lroc_color_poles_2k from the same SVS kit: Pearson r = 0.994, mean |diff| = 2.3 / 255 (JPEG recompression). Re-download from SVS and compare SHA-256 before publication.
- Limitation: Source latitude sampling 22.8 px/deg (~1.33 km/px); the cap image is upsampled and cannot show detail finer than the source.
- Use: Visual orientation only; not used in any calculation.

### Terrain (`data/processed/terrain_provenance.json`)

| Input file (unmodified) | Bytes | MD5 | Pixel size | CRS |
|---|---|---|---|---|
| LDSM_80S_80MPP_ADJ.tiff | 241,594,035 | `587f2312781306c22e41320379d9a8c7` | 80 x 80 m | `+proj=stere +lat_0=-90 +lon_0=0 +k=1 +x_0=0 +y_0=0 +R=1737400 +units=m +no_defs` |
| LDEM_80S_80MPP_ADJ_HILL.tiff | 88,474,342 | `a019d01134f0c38ae23f0595c1603494` | 80 x 80 m | `+proj=stere +lat_0=-90 +lon_0=0 +k=1 +x_0=0 +y_0=0 +R=1737400 +units=m +no_defs` |
| AVGVISIB_75S_120M_201608.IMG | 116,250,752 | `00d07bfbb3fd5bee3fb36a4deeaae26c` | 120 x 120 m | `+proj=stere +lat_0=-90 +lon_0=0 +k=1 +x_0=0 +y_0=0 +R=1737400 +units=m +no_defs` |
| AVGVISIB_75S_120M_201608_EARTH.IMG | 116,250,752 | `6a044319dd2e209a3089cd2543b9b2bf` | 120 x 120 m | `+proj=stere +lat_0=-90 +lon_0=0 +k=1 +x_0=0 +y_0=0 +R=1737400 +units=m +no_defs` |
- **Projection:** Inputs sampled at lon/lat of the app's south-polar azimuthal-equidistant grid (80-90 S) via terra::project from the GeoTIFF's own CRS.
- **Hillshade:** 3072 px image, bilinear sampling, 0.5-99.5 % stretch to 8 bit.
- **Grid:** 400 x 400 cells (~1.52 km); 64 stratified nearest-pixel samples per cell; median slope and share below 5/8/10/15 deg; cells with < 16 valid samples left empty.
- **Sites:** Bilinear slope at the point and on a 40 m lattice within 1000 m.
- **Limitation:** LOLA slope at 80 m baseline; boulders and sub-pixel hazards are not resolved. Slope error map (LDSM_..._ERR) not yet used.

### Illumination vs literature (`data/processed/illum_validation.json`)

Mazarico 2011 average Sun visibility (120 m/px, 18.6 yr, surface level) sampled bilinearly at the published point and as maximum on a 40 m lattice within 1 km.

| Site | Literature | Mazarico point | Mazarico max 1 km | Status |
|---|---|---|---|---|
| Connecting Ridge | 85.7 % [7] (Integral solar illumination, Kaguya LALT DEM, 2016 epoch) | 70.9 % | 83.4 % (-2.3 pp) | consistent |
| Haworth | 70.32 % [8] (Sun visibility fraction reported for this point) | 41.4 % | 50.0 % (-20.3 pp) | DISCREPANCY |

Literature values use other DEMs (Kaguya LALT, LOLA 20 m), epochs, heights and definitions; differences of several percentage points are expected. The 1 km maximum accounts for coordinate rounding and the coarser 120 m grid.

## 6. Data flow

```text
de421 + jplephem ─┐
moon_080317 rot. ─┼─ data-raw/build_ephemeris.py ─► ephemeris_moon_me_1h.csv.gz ─┐
IAU 2015 (check) ─┘                                ephemeris_validation.json      │
sites.csv (literature / LROC) ───────────────────────────────────────────────────┤
                                                                                 ▼
                       data/interfaces.R: site_geometry(), window_metrics(), heat_grid(), point_criteria(), score_points()
                                                                                 ▼
                                                   app (ranking, timeline, map layer)
AVGVISIB_75S (+_EARTH) ─┐
LDSM/LDEM_HILL 80S ── data-raw/build_terrain.R ─► terrain_grid, site_terrain, hillshade ─► suitability layer, slope criterion
USGS region grids ── data-raw/build_ml.R (+ terrain & illumination grids) ─► ml_grid, model card, region outlines
lroc_color_poles_8k ── data-raw/build_textures.py ─► base map (visual only)
original rasters + USGS outlines + Peña-Asensio Table 3 ── data-raw/analysis_regions.R ─► region_stats, nr2_published_points, deep_dive_nr2
region_stats + ephemeris windows ── data-raw/analysis_robustness.R ─► robustness.json ─► ANALYSIS.md (build_analysis_report.py)
original rasters + sites.csv + landings.csv ── data-raw/build_dossiers.R ─► dossiers.json.gz ─► site dossier (R/dossier.R, www/dossier.js)
NASA NSSDCA lander table ── transcribed ─► data/landings.csv ─► landing markers and dossiers
grids + USGS outlines + dossiers ── data-raw/build_validation.R ─► validation_checks.json ─► Validation view (R/story.R, www/story.js)
```

Validation of results against original rasters and a published site analysis, and the robustness test, are documented in [ANALYSIS.md](ANALYSIS.md).

## Start view illustration (decoration only)

`data-raw/build_hero.py` renders `www/assets/hero_moon.webp` (orthographic Moon seen from 66° S, Sun at 1.5° S so it grazes the pole) from `moon_global_4k.jpg` plus the LOLA hillshade `moon_south_hill.jpg` inside 80° S, and `www/assets/hero_loupe.webp` (LOLA hillshade 80 to 90° S, 0° E at the top). Pin positions in `data/processed/hero_pins.json` are projected from `data/sites.csv` and `data/landings.csv`. Imagery credit: NASA's Scientific Visualization Studio; NASA/GSFC/ASU (LROC); LOLA (NASA GSFC). Nothing here enters a calculation.

## Terrain horizons (LOLA LDEM 80 m) and ML surrogate

Input: `LDEM_80S_80MPP_ADJ.tif(f)` (LOLA, Barker et al. 2023, NASA GSFC PGDA product 90), 7600 x 7600 px, 80 m, south polar stereographic, R = 1737.4 km. Scripts: `data-raw/horizon_lib.py`, `build_horizons.py`, `train_horizon_ml.py`, `summarise_horizons.py`.
Products: `horizons_sites.json` (exact horizons, 1° steps), `horizon_check7.csv` and `horizon_validation.json` (comparison with Mazarico et al. AVGVISIB 120 m), `horizon_mlp.json` (network weights and scaler), `horizon_ml_card.json` (metrics, importances, limits), `dem_1280m.bin.gz` (16 x 16 block mean of the DEM, int16 metres). Training data stay in `data/cache/` and are not shipped. Limitation: the DEM ends at 80° S, so horizons towards the north of sites near 84° S lack terrain beyond the edge.

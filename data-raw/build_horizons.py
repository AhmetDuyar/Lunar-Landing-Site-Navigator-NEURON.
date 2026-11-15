#!/usr/bin/env python3
"""
NEURON Lunar Navigator - exact terrain horizons and ML training data
====================================================================

Input : data-raw/input/LDEM_80S_80MPP_ADJ.tif(f)  (LOLA, Barker et al. 2023, PGDA 90)
        data-raw/input/AVGVISIB_75S_120M_201608[_EARTH].IMG  (Mazarico et al. 2011)
        data/processed/ephemeris_moon_me_1h.csv.gz (DE421, built by build_ephemeris.py)
Output: data/processed/horizons_sites.json    360-deg horizons, curated sites + polar landings
        data/cache/horizon_training.npz        features/targets for the ML surrogate (not shipped)
        data/processed/horizon_check7.csv      exact-horizon Sun/Earth visibility vs Mazarico

Run   : python3 data-raw/build_horizons.py /path/to/ldem.f32
        (ldem.f32 = the DEM as raw float32 row-major, e.g. written by terra; see README)
"""
import json
import os
import sys
import time

import numpy as np
import pandas as pd
from scipy.ndimage import map_coordinates

sys.path.insert(0, os.path.dirname(__file__))
import horizon_lib as H  # noqa: E402
import sky_lib as S      # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
os.chdir(ROOT)
dem = H.load_dem(sys.argv[1])
rng = np.random.default_rng(20261115)
AZ360 = np.arange(0.0, 360.0, 1.0)
AZ36 = np.arange(0.0, 360.0, 10.0)
EARTH_RADIUS_DEG = 0.95  # mean apparent radius of Earth seen from the Moon (for the Mazarico comparison)

M_SUN = np.memmap("data-raw/input/AVGVISIB_75S_120M_201608.IMG", dtype="<i2", mode="r", shape=(7624, 7624))
M_EARTH = np.memmap("data-raw/input/AVGVISIB_75S_120M_201608_EARTH.IMG", dtype="<i2", mode="r", shape=(7624, 7624))


def mazarico(arr, lat, lon):
    x, y = H.ll_to_xy(lat, lon)
    col = x / 120.0 + 3812 - 0.5
    row = 3812 - y / 120.0 - 0.5
    i0, j0 = int(np.floor(row)), int(np.floor(col))
    blk = np.asarray(arr[i0:i0 + 2, j0:j0 + 2], dtype=np.float32)
    return float(map_coordinates(blk, [[row - i0], [col - j0]], order=1)[0]) * 0.00004 * 100


def visibility(hz, lat, lon):
    sk = S.sky(lat, lon)
    hs = S.horizon_at(hz, sk["sun_az"]); he = S.horizon_at(hz, sk["earth_az"])
    return {"sun_centre": 100 * np.mean(sk["sun_el"] > hs),
            "sun_limb": 100 * np.mean(sk["sun_el"] + S.SUN_RADIUS_DEG > hs),
            "earth_centre": 100 * np.mean(sk["earth_el"] > he),
            "earth_limb": 100 * np.mean(sk["earth_el"] + EARTH_RADIUS_DEG > he),
            "sun_smooth": 100 * np.mean(sk["sun_el"] > 0)}


# ---- 1. curated sites and south-polar landings -------------------------------
sites = pd.read_csv("data/sites.csv")
land = pd.read_csv("data/landings.csv")
pts = [(r.id, r.name, r.lat, r.lon_e, "site") for r in sites.itertuples()]
pts += [(r.id, r.mission, r.lat, r.lon % 360, "landing") for r in land.itertuples() if r.lat <= -80]
out = {}
for pid, name, la, lo, kind in pts:
    hz, z0 = H.horizon(dem, la, lo, AZ360)
    v = visibility(hz, la, lo)
    out[pid] = {"name": name, "kind": kind, "lat": la, "lon": lo, "elev_m": round(z0, 1),
                "horizon_deg": [round(float(h), 2) for h in hz],
                "vis_2026_2030": {k: round(float(x), 2) for k, x in v.items()},
                "mazarico": {"sun": round(mazarico(M_SUN, la, lo), 2), "earth": round(mazarico(M_EARTH, la, lo), 2)}}
    print(f"{pid:10s} sun {v['sun_centre']:5.1f} (Mazarico {out[pid]['mazarico']['sun']:5.1f})  "
          f"earth {v['earth_centre']:5.1f} (Mazarico {out[pid]['mazarico']['earth']:5.1f})")
meta = {"generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "dem": "LDEM_80S_80MPP_ADJ (LOLA 80 m, Barker et al. 2023)", "observer_height_m": H.H_OBS,
        "max_distance_km": 150, "azimuth_step_deg": 1,
        "visibility_definition": "centre above the local terrain horizon; limb variants for comparison with Mazarico",
        "ephemeris_span": "2026-01-01 to 2030-12-31, hourly (DE421)", "points": out}
json.dump(meta, open("data/processed/horizons_sites.json", "w"))

# ---- 2. training sample: uniform in area within 6.5 deg of the pole ----------
NP = int(os.environ.get("NPOINTS", 20000))
r = 6.5 * np.sqrt(rng.uniform(size=NP))
th = rng.uniform(0, 360, size=NP)
lat = -90.0 + r
lon = th
X, Y, G, P = [], [], [], []
HZ360 = {}
t = time.time()
for i in range(NP):
    hz, _ = H.horizon(dem, lat[i], lon[i], AZ360)
    F = H.features(dem, lat[i], lon[i], AZ36)
    X.append(F); Y.append(hz[::10]); P.append(np.full(len(AZ36), i))
    if i < 1500:
        HZ360[i] = hz
    if i % 2000 == 0:
        print(i, round(time.time() - t, 1), "s")
X = np.vstack(X); Y = np.concatenate(Y); P = np.concatenate(P)
xs, ys = H.ll_to_xy(lat, lon)
os.makedirs("data/cache", exist_ok=True)
np.savez_compressed("data/cache/horizon_training.npz", X=X, y=Y, point=P, lat=lat, lon=lon, x=xs, y_m=ys,
                    hz360=np.array([HZ360[i] for i in range(min(1500, NP))]), feature_names=np.array(H.FEATURE_NAMES))

# ---- 3. check 7: exact-horizon visibility vs Mazarico at 1,500 random points ----
rows = []
for i in range(min(1500, NP)):
    v = visibility(HZ360[i], lat[i], lon[i])
    rows.append({"i": i, "lat": lat[i], "lon": lon[i], **v,
                 "maz_sun": mazarico(M_SUN, lat[i], lon[i]), "maz_earth": mazarico(M_EARTH, lat[i], lon[i])})
pd.DataFrame(rows).to_csv("data/processed/horizon_check7.csv", index=False)
print("done", round(time.time() - t, 1), "s")

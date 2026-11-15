#!/usr/bin/env python3
"""
NEURON Lunar Navigator - ML surrogate for terrain horizons
=========================================================

Question: can a small model predict the exact 80 m terrain horizon from a
< 1 MB, 1280 m elevation model, so the app can give a terrain-aware sunset /
Earthset countdown for ANY clicked point?

Targets : exact horizons (build_horizons.py), 20,000 points x 36 azimuths.
Features: 14 per (point, azimuth), all from the 1280 m DEM (horizon_lib.features_coarse).
Models  : baseline (max of the coarse samples), gradient boosting, small MLP.
          Both learn the residual  y - theta_coarse_max.
Validation: 5-fold GroupKFold over 30 km x 30 km spatial blocks (no block is in
          training and test at once), plus downstream Sun/Earth visibility
          2026-2030 at 300 held-out points with full 360-deg predicted horizons.
Outputs : data/processed/horizon_ml_card.json   metrics, importances, limits
          data/processed/horizon_mlp.json       MLP weights + scaler (used by the app)
          data/processed/dem_1280m.bin.gz       475 x 475 int16 DEM (m) for the app
"""
import gzip
import json
import os
import sys
import time

import numpy as np
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.inspection import permutation_importance
from sklearn.model_selection import GroupKFold
from sklearn.neural_network import MLPRegressor
from sklearn.preprocessing import StandardScaler

sys.path.insert(0, os.path.dirname(__file__))
import horizon_lib as H  # noqa: E402
import sky_lib as S      # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
os.chdir(ROOT)
dem = H.load_dem(sys.argv[1])
z16 = dem["levels"][2][0]
D = np.load("data/cache/horizon_training.npz")
lat, lon, xs, ys = D["lat"], D["lon"], D["x"], D["y_m"]
y = D["y"]; point = D["point"]
NP = len(lat)
AZ36 = np.arange(0.0, 360.0, 10.0)

t = time.time()
X = np.vstack([H.features_coarse(z16, lat[i], lon[i], AZ36) for i in range(NP)])
print("features", X.shape, round(time.time() - t, 1), "s")
base = X[:, 8]                        # theta_coarse_max
res = y - base
blocks = (np.floor(xs / 30000).astype(int) * 1000 + np.floor(ys / 30000).astype(int))
groups = blocks[point]
n_blocks = len(np.unique(blocks))


def metrics(y_true, y_pred):
    e = y_pred - y_true
    return {"mae_deg": round(float(np.mean(np.abs(e))), 3), "rmse_deg": round(float(np.sqrt(np.mean(e ** 2))), 3),
            "r2": round(float(1 - np.sum(e ** 2) / np.sum((y_true - y_true.mean()) ** 2)), 4),
            "p95_abs_deg": round(float(np.percentile(np.abs(e), 95)), 3)}


def make_gbm():
    return HistGradientBoostingRegressor(max_iter=400, learning_rate=0.08, max_leaf_nodes=48,
                                         l2_regularization=1.0, random_state=1)


def make_mlp():
    return MLPRegressor(hidden_layer_sizes=(48, 48), activation="relu", alpha=1e-4, batch_size=1024,
                        learning_rate_init=2e-3, max_iter=60, early_stopping=True, n_iter_no_change=6,
                        random_state=1)


pred = {"baseline": base.copy(), "gbm": np.zeros_like(y), "mlp": np.zeros_like(y)}
fold_of_point = np.zeros(NP, int)
gkf = GroupKFold(n_splits=5)
models = {}
for k, (tr, te) in enumerate(gkf.split(X, res, groups)):
    g = make_gbm().fit(X[tr], res[tr]); pred["gbm"][te] = base[te] + g.predict(X[te])
    sc = StandardScaler().fit(X[tr]); m = make_mlp().fit(sc.transform(X[tr]), res[tr])
    pred["mlp"][te] = base[te] + m.predict(sc.transform(X[te]))
    fold_of_point[np.unique(point[te])] = k
    models[k] = (g, sc, m)
    print("fold", k, metrics(y[te], pred["gbm"][te]), metrics(y[te], pred["mlp"][te]))
cv = {k: metrics(y, v) for k, v in pred.items()}
cv["zero_horizon"] = metrics(y, np.zeros_like(y))
print(json.dumps(cv, indent=1))

# ---- downstream: visibility 2026-2030 at 300 held-out points, full 360-deg horizons ----
AZ360 = np.arange(0.0, 360.0, 1.0)
hz360 = D["hz360"]
rng = np.random.default_rng(7)
idx = rng.choice(len(hz360), size=300, replace=False)
rows = []
for i in idx:
    g, sc, m = models[fold_of_point[i]]           # model that never saw this point's block
    F = H.features_coarse(z16, lat[i], lon[i], AZ360)
    hz_b = F[:, 8]; hz_m = hz_b + m.predict(sc.transform(F)); hz_g = hz_b + g.predict(F)
    sk = S.sky(lat[i], lon[i])
    r_ = {}
    for nm, hz in (("exact", hz360[i]), ("baseline", hz_b), ("mlp", hz_m), ("gbm", hz_g), ("smooth", np.zeros(360))):
        hs = S.horizon_at(hz, sk["sun_az"]); he = S.horizon_at(hz, sk["earth_az"])
        r_[nm + "_sun"] = 100 * np.mean(sk["sun_el"] > hs)
        r_[nm + "_earth"] = 100 * np.mean(sk["earth_el"] > he)
        r_[nm + "_sunup"] = sk["sun_el"] > hs
    for nm in ("baseline", "mlp", "gbm", "smooth"):
        r_[nm + "_hour_agree"] = 100 * np.mean(r_[nm + "_sunup"] == r_["exact_sunup"])
    rows.append({k: v for k, v in r_.items() if not k.endswith("_sunup")})
down = {}
for nm in ("baseline", "mlp", "gbm", "smooth"):
    es = np.array([r[nm + "_sun"] - r["exact_sun"] for r in rows])
    ee = np.array([r[nm + "_earth"] - r["exact_earth"] for r in rows])
    ha = np.array([r[nm + "_hour_agree"] for r in rows])
    down[nm] = {"sun_mae_pp": round(float(np.mean(np.abs(es))), 2), "earth_mae_pp": round(float(np.mean(np.abs(ee))), 2),
                "sun_hour_agreement_pct": round(float(np.mean(ha)), 2)}
print(json.dumps(down, indent=1))

# ---- final models on all data, importances, export ----
gbm = make_gbm().fit(X, res)
sub = rng.choice(len(X), size=40000, replace=False)
pim = permutation_importance(gbm, X[sub], res[sub], n_repeats=3, random_state=1, scoring="neg_mean_absolute_error")
imp = sorted(zip(H.COARSE_FEATURE_NAMES, pim.importances_mean), key=lambda z: -z[1])
sc = StandardScaler().fit(X)
mlp = make_mlp().fit(sc.transform(X), res)
mlp_json = {"features": H.COARSE_FEATURE_NAMES, "feature_distances_m": H.FEAT_D.tolist(),
            "scaler_mean": sc.mean_.tolist(), "scaler_scale": sc.scale_.tolist(),
            "weights": [w.tolist() for w in mlp.coefs_], "biases": [b.tolist() for b in mlp.intercepts_],
            "activation": "relu", "output": "horizon_deg = theta_coarse_max + mlp(standardised features)",
            "dem": {"file": "dem_1280m.bin.gz", "n": int(z16.shape[0]), "px_m": 1280.0, "x0_m": H.X0,
                    "projection": "south polar stereographic, R = 1737400 m, lon_0 = 0"},
            "observer_height_m": H.H_OBS}
json.dump(mlp_json, open("data/processed/horizon_mlp.json", "w"))
with gzip.open("data/processed/dem_1280m.bin.gz", "wb") as f:
    f.write(np.round(z16).astype("<i2").tobytes())
n_par = sum(w.size for w in mlp.coefs_) + sum(b.size for b in mlp.intercepts_)

# reference predictions for the R port test
test_pts = [(-85.0, 45.0), (-88.2, 300.0), (-84.7906, 29.1957)]
ref = []
for la, lo in test_pts:
    F = H.features_coarse(z16, la, lo, AZ36)
    ref.append({"lat": la, "lon": lo, "horizon_deg": (F[:, 8] + mlp.predict(sc.transform(F))).round(4).tolist()})

card = {"generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "question": "Predict the exact 80 m terrain horizon from a 1280 m DEM (256x fewer cells) so the app can be terrain-aware at any point.",
        "data": {"points": NP, "azimuths_per_point": 36, "rows": int(len(y)), "area": "83.5 to 90 deg S, uniform in area",
                 "target": "exact horizon, LOLA 80 m DEM, 2 m observer, 150 km, curvature", "spatial_blocks_30km": int(n_blocks)},
        "validation": "5-fold GroupKFold over 30 km x 30 km blocks", "cv": cv, "downstream_300_heldout_points": down,
        "mlp": {"hidden_layers": [48, 48], "parameters": int(n_par)},
        "importance_gbm_permutation_mae": [[n, round(float(v), 4)] for n, v in imp],
        "reference_predictions": ref,
        "limits": ["Horizons towards the north are truncated at the DEM edge (80 deg S).",
                   "Trained on 83.5 to 90 deg S; outside this band the model extrapolates.",
                   "Used only for points without a precomputed exact horizon; curated sites and landings use the exact horizon."]}
json.dump(card, open("data/processed/horizon_ml_card.json", "w"), indent=1)
print("params", n_par); print(imp[:6])

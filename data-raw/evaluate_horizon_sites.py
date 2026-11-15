#!/usr/bin/env python3
"""Adds an out-of-distribution test to the ML card: surrogate vs exact horizon at the curated
sites and polar landings (rims and summits chosen for light, rare in a random sample)."""
import gzip, json, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import horizon_lib as H  # noqa: E402
os.chdir(os.path.join(os.path.dirname(__file__), ".."))
mlp = json.load(open("data/processed/horizon_mlp.json"))
z16 = np.frombuffer(gzip.open("data/processed/dem_1280m.bin.gz").read(), dtype="<i2").reshape(475, 475).astype(float)
def pred(F):
    h = (F - np.array(mlp["scaler_mean"])) / np.array(mlp["scaler_scale"])
    for k, (W, b) in enumerate(zip(mlp["weights"], mlp["biases"])):
        h = h @ np.array(W) + np.array(b)
        if k < len(mlp["weights"]) - 1: h = np.maximum(h, 0)
    return F[:, 8] + h.ravel()
HZ = json.load(open("data/processed/horizons_sites.json"))["points"]
az = np.arange(0.0, 360.0, 1.0); rows = []
for k, v in HZ.items():
    if k == "im2": continue          # same coordinates as Mons Mouton
    ex = np.array(v["horizon_deg"]); F = H.features_coarse(z16, v["lat"], v["lon"], az)
    rows.append({"id": k, "name": v["name"], "coarse_mae_deg": round(float(np.mean(np.abs(F[:, 8] - ex))), 2),
                 "mlp_mae_deg": round(float(np.mean(np.abs(pred(F) - ex))), 2)})
card = json.load(open("data/processed/horizon_ml_card.json"))
card["sites_out_of_distribution"] = {"rows": rows,
    "mean_coarse_mae_deg": round(float(np.mean([r["coarse_mae_deg"] for r in rows])), 2),
    "mean_mlp_mae_deg": round(float(np.mean([r["mlp_mae_deg"] for r in rows])), 2),
    "note": "Published sites are rims and summits selected for light. On these seven places the surrogate is not better than the coarse terrain, so the app always uses the exact horizon for them."}
card["limits"].append("Not better than the coarse terrain at the seven curated sites and landings (out of distribution); the app uses exact horizons there.")
json.dump(card, open("data/processed/horizon_ml_card.json", "w"), indent=1)
print(json.dumps(card["sites_out_of_distribution"], indent=1))

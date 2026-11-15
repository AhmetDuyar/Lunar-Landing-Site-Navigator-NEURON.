#!/usr/bin/env python3
"""Summarise check 7 (exact LOLA horizon vs Mazarico long-term visibility) for the app and paper."""
import json, os
import numpy as np, pandas as pd
os.chdir(os.path.join(os.path.dirname(__file__), ".."))
d = pd.read_csv("data/processed/horizon_check7.csv")
def st(a, b):
    return {"r": round(float(np.corrcoef(d[a], d[b])[0, 1]), 4), "mae_pp": round(float(np.mean(np.abs(d[a] - d[b]))), 2),
            "bias_pp": round(float(np.mean(d[a] - d[b])), 2)}
hs = json.load(open("data/processed/horizons_sites.json"))
sites = [{"id": k, "name": v["name"], "kind": v["kind"], "sun": v["vis_2026_2030"]["sun_centre"],
          "sun_limb": v["vis_2026_2030"]["sun_limb"], "earth": v["vis_2026_2030"]["earth_centre"],
          "earth_limb": v["vis_2026_2030"]["earth_limb"], "smooth_sun": v["vis_2026_2030"]["sun_smooth"],
          "maz_sun": v["mazarico"]["sun"], "maz_earth": v["mazarico"]["earth"]} for k, v in hs["points"].items()]
rng = np.random.default_rng(3); sub = d.iloc[rng.choice(len(d), 400, replace=False)]
out = {"n_points": int(len(d)), "area": "83.5 to 90 deg S, random, uniform in area",
       "period": "2026-2030 hourly (DE421) vs Mazarico et al. multi-year average",
       "sun_limb_vs_mazarico": st("sun_limb", "maz_sun"), "sun_centre_vs_mazarico": st("sun_centre", "maz_sun"),
       "earth_limb_vs_mazarico": st("earth_limb", "maz_earth"), "earth_centre_vs_mazarico": st("earth_centre", "maz_earth"),
       "smooth_sun_vs_mazarico": st("sun_smooth", "maz_sun"),
       "note": "Mazarico counts a pixel lit when any part of the disc is visible; the limb variant uses the same definition.",
       "sites": sites,
       "sample": sub[["sun_limb", "maz_sun", "sun_smooth", "earth_limb", "maz_earth"]].round(2).to_dict(orient="list")}
json.dump(out, open("data/processed/horizon_validation.json", "w"), indent=1)
print(json.dumps({k: v for k, v in out.items() if k not in ("sample", "sites")}, indent=1))
for s in sites: print(s)

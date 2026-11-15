#!/usr/bin/env python3
"""Compare Mazarico et al. (2011) long-term Sun visibility at the candidate points
with the literature values stored in data/sites.csv. Writes
data/processed/illum_validation.json (shown in Data & Methods and DATA_PROVENANCE.md)."""
import csv, json, os
ROOT = os.path.join(os.path.dirname(__file__), "..")
sites = {r["id"]: r for r in csv.DictReader(open(os.path.join(ROOT, "data", "sites.csv"), encoding="utf-8"))}
ill = {r["id"]: r for r in csv.DictReader(open(os.path.join(ROOT, "data", "processed", "site_illum.csv")))}
rows = []
for sid, s in sites.items():
    if not s["lit_illum_pct"] or sid not in ill:
        continue
    lit = float(s["lit_illum_pct"]); pt = float(ill[sid]["sun_avg_point"]); mx = float(ill[sid]["sun_avg_max_1km"])
    rows.append({"id": sid, "name": s["name"], "literature_pct": lit, "literature_source": s["lit_illum_source"],
                 "literature_definition": s["lit_illum_definition"], "mazarico_point_pct": pt,
                 "mazarico_max_1km_pct": mx, "delta_point_pp": round(pt - lit, 1), "delta_max_1km_pp": round(mx - lit, 1),
                 "agrees_within_10pp_1km": abs(mx - lit) <= 10})
out = {"method": "Mazarico 2011 average Sun visibility (120 m/px, 18.6 yr, surface level) sampled bilinearly at the published point and as maximum on a 40 m lattice within 1 km.",
       "notes": "Literature values use other DEMs (Kaguya LALT, LOLA 20 m), epochs, heights and definitions; differences of several percentage points are expected. The 1 km maximum accounts for coordinate rounding and the coarser 120 m grid.",
       "rows": rows}
json.dump(out, open(os.path.join(ROOT, "data", "processed", "illum_validation.json"), "w"), indent=2)
print(json.dumps(rows, indent=2))

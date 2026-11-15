#!/usr/bin/env python3
"""
NEURON Lunar Navigator - hero image for the Start view (visual layer only)
=========================================================================

Renders the Moon as an orthographic sphere seen from 55 deg S, lit by a Sun
low on the lunar equator, so the terminator runs close to the south pole: the
situation the app is about. Uses the two textures already in www/assets
(NASA SVS CGI Moon Kit, LROC; see build_textures.py) and writes

  www/assets/hero_moon.webp            1400 x 1400, transparent outside the disc
  data/processed/hero_pins.json         screen positions (0..1) of the curated
                                        sites and south-polar landings

The image is decoration and orientation only; it never enters a calculation.
Run:  python3 data-raw/build_hero.py
"""
import csv
import json
import os

import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates

ROOT = os.path.join(os.path.dirname(__file__), "..")
A = os.path.join(ROOT, "www", "assets")
N = 1400
LAT0, LON0 = -66.0, 10.0        # view direction (sub-observer point)
SUN_LAT, SUN_LON = -1.5, -80.0  # Sun direction: grazing at the pole, as in southern summer
CAP_DEG = 15.0


def vec(lat, lon):
    la, lo = np.radians(lat), np.radians(lon)
    return np.array([np.cos(la) * np.cos(lo), np.cos(la) * np.sin(lo), np.sin(la)])


D = vec(LAT0, LON0)
north = np.array([0.0, 0.0, 1.0])
U = north - D * (north @ D)
U /= np.linalg.norm(U)            # screen up
E = np.cross(U, D)                # screen right (east to the right when seen from outside)
E = -E if (E @ vec(0, LON0 + 90)) < 0 else E
S = vec(SUN_LAT, SUN_LON)

glob = np.asarray(Image.open(os.path.join(A, "moon_global_4k.jpg")).convert("L"), dtype=np.float32)
cap = np.asarray(Image.open(os.path.join(A, "moon_south_cap.jpg")).convert("L"), dtype=np.float32)
GH, GW = glob.shape
CN = cap.shape[0]

ys, xs = np.mgrid[0:N, 0:N]
x = (xs + 0.5) / N * 2 - 1
y = 1 - (ys + 0.5) / N * 2
rr = x * x + y * y
inside = rr <= 1.0
z = np.sqrt(np.clip(1 - rr, 0, 1))
P = x[..., None] * E + y[..., None] * U + z[..., None] * D
lat = np.degrees(np.arcsin(np.clip(P[..., 2], -1, 1)))
lon = np.degrees(np.arctan2(P[..., 1], P[..., 0]))

# global mosaic (equirectangular, centred on 0 E)
col = ((lon + 180.0) % 360.0) / 360.0 * GW - 0.5
row = (90.0 - lat) / 180.0 * GH - 0.5
tex = map_coordinates(glob, [row, col], order=1, mode="wrap")
# high-resolution polar cap, blended in over the last 3 degrees
colat = lat + 90.0
r = colat / CAP_DEG * 0.5
cu = 0.5 + r * np.cos(np.radians(lon))
cv = 0.5 + r * np.sin(np.radians(lon))
ctex = map_coordinates(cap, [(1 - cv) * CN - 0.5, cu * CN - 0.5], order=1, mode="nearest")
w = np.clip((CAP_DEG - colat) / 3.0, 0, 1)
# (the 75-90 S cap mosaic is darker than the global one; the hillshade below replaces it)
# the mosaic is patchy inside 80 S; use the LOLA hillshade there (same file as the map)
hill = np.asarray(Image.open(os.path.join(A, "moon_south_hill.jpg")).convert("L"), dtype=np.float32)
HN = hill.shape[0]
hr = colat / 10.0 * 0.5
hu = 0.5 + hr * np.cos(np.radians(lon))
hv = 0.5 + hr * np.sin(np.radians(lon))
htex = map_coordinates(hill, [(1 - hv) * HN - 0.5, hu * HN - 0.5], order=1, mode="nearest")
ring = inside & (colat > 9.6) & (colat < 11)
hin = inside & (colat < 9.5)
htex = (htex - htex[hin].mean()) / htex[hin].std() * tex[ring].std() * 1.1 + tex[ring].mean()
wh = np.clip((9.7 - colat) / 3.0, 0, 1)
tex = tex * (1 - wh) + htex * wh

# light: Lambert with a soft terminator, faint earthshine on the night side
mu = P @ S
light = np.clip(mu, 0, 1) ** 0.55
soft = np.clip((mu + 0.025) / 0.05, 0, 1)
light = light * soft
limb = 0.82 + 0.18 * z
lit = (tex / 255.0) * light * limb
night = 0.06 + 0.09 * (tex / 255.0) * (0.6 + 0.4 * z)   # earthshine
val = night * (1 - soft) + (night + lit * 1.05) * soft
val = np.clip(val, 0, 1)

g = (val * 255).astype(np.uint8)
alpha = np.clip((1.0 - np.sqrt(rr)) * N / 2.0 + 0.5, 0, 1)
a = (alpha * 255).astype(np.uint8)
img = Image.merge("LA", (Image.fromarray(g), Image.fromarray(a))).convert("RGBA")
img.save(os.path.join(A, "hero_moon.webp"), "WEBP", quality=80, method=6)


def screen(la, lo):
    p = vec(la, lo)
    return float(0.5 + 0.5 * (p @ E)), float(0.5 - 0.5 * (p @ U)), bool(p @ D > 0)


pins = []
with open(os.path.join(ROOT, "data", "sites.csv"), newline="", encoding="utf-8") as fh:
    for s in csv.DictReader(fh):
        u, v, vis = screen(float(s["lat"]), float(s["lon_e"]))
        pins.append({"kind": "site", "id": s["id"], "name": s["name"], "lat": float(s["lat"]), "lon": float(s["lon_e"]),
                     "u": round(u, 4), "v": round(v, 4), "visible": vis})
with open(os.path.join(ROOT, "data", "landings.csv"), newline="", encoding="utf-8") as fh:
    for s in csv.DictReader(fh):
        la, lo = float(s["lat"]), float(s["lon"])
        if la > -60:
            continue
        u, v, vis = screen(la, lo)
        pins.append({"kind": "landing", "id": s["id"], "name": s["mission"], "lat": la, "lon": lo,
                     "u": round(u, 4), "v": round(v, 4), "visible": vis})
# ---- loupe: LOLA hillshade 80-90 S, rotated so 0 E is at the top ----------
HL = Image.open(os.path.join(A, "moon_south_hill.jpg")).convert("L").rotate(90, resample=Image.BICUBIC)
LN = 900
HL = HL.resize((LN, LN), Image.LANCZOS)
ly, lx = np.mgrid[0:LN, 0:LN]
lr = np.hypot((lx + 0.5) / LN - 0.5, (ly + 0.5) / LN - 0.5) * 2
la = (np.clip((1.0 - lr) * LN / 2.0 + 0.5, 0, 1) * 255).astype(np.uint8)
Image.merge("LA", (HL, Image.fromarray(la))).convert("RGBA").save(os.path.join(A, "hero_loupe.webp"), "WEBP", quality=78, method=6)


def loupe(la_, lo_):
    r_ = (la_ + 90.0) / 10.0 * 0.5
    t = np.radians(lo_)
    return float(0.5 - r_ * np.sin(t)), float(0.5 - r_ * np.cos(t))


for p_ in pins:
    if p_["lat"] <= -80:
        p_["lu"], p_["lv"] = [round(q, 4) for q in loupe(p_["lat"], p_["lon"])]
pole = screen(-90, 0)
out = {"view": {"lat": LAT0, "lon": LON0}, "sun": {"lat": SUN_LAT, "lon": SUN_LON},
       "pole": {"u": round(pole[0], 4), "v": round(pole[1], 4)}, "pins": pins,
       "texture_credit": "NASA's Scientific Visualization Studio; NASA/GSFC/ASU (LROC)"}
json.dump(out, open(os.path.join(ROOT, "data", "processed", "hero_pins.json"), "w"), indent=1)
print(json.dumps(out, indent=1)[:1500])

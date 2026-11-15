#!/usr/bin/env python3
"""
NEURON Lunar Navigator - texture preprocessing (visual layer only)
==================================================================

Input : NASA SVS CGI Moon Kit, lroc_color_poles_8k.tif (8192 x 4096,
        equirectangular, centred on 0 deg E; polar gaps filled with LROC
        polar mosaics). https://svs.gsfc.nasa.gov/4720/
        Credit: NASA's Scientific Visualization Studio; NASA/GSFC/ASU.

Output: www/assets/moon_global_4k.jpg   4096 x 2048 greyscale, equirectangular
        www/assets/moon_south_cap.jpg   4096 x 4096 greyscale, azimuthal-
                                        equidistant south-polar projection,
                                        75 S - 90 S (centre = pole,
                                        0 deg E towards image top)
        data/processed/texture_provenance.json

The textures are used for orientation only and never enter a calculation.
Run:  python3 data-raw/build_textures.py /path/to/lroc_color_poles_8k.tif
"""
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter, ImageOps
from scipy.ndimage import map_coordinates

ROOT = os.path.join(os.path.dirname(__file__), "..")
CAP_DEG = 15.0
CAP_PX = 4096

src_path = sys.argv[1]
Image.MAX_IMAGE_PIXELS = None
sha = hashlib.sha256(open(src_path, "rb").read()).hexdigest()
src = Image.open(src_path).convert("L")
W, H = src.size
arr = np.asarray(src, dtype=np.float32)

# --- global 4k ---------------------------------------------------------------
glob = src.resize((4096, 2048), Image.LANCZOS)
glob = ImageOps.autocontrast(glob, cutoff=0.3)
glob.save(os.path.join(ROOT, "www", "assets", "moon_global_4k.jpg"), quality=86, optimize=True)

# --- south polar cap ---------------------------------------------------------
# Pixel (row i, col j): u = (j+.5)/N, v = 1-(i+.5)/N (three.js UV, flipY).
# dx = u-.5 (towards 0 deg E... see below), r = hypot -> colatitude.
# In the viewer, u-axis points to lon 0 and v-axis to lon 90 E, matching
# lon = atan2(v-.5, u-.5).  The app rotates the camera so 0 deg E is at top.
n = CAP_PX
jj, ii = np.meshgrid(np.arange(n), np.arange(n))
u = (jj + 0.5) / n - 0.5
v = 0.5 - (ii + 0.5) / n
r = np.hypot(u, v)
colat = r / 0.5 * CAP_DEG
lat = -90.0 + colat
lon = np.degrees(np.arctan2(v, u))
col = ((lon + 180.0) % 360.0) / 360.0 * W - 0.5
row = (90.0 - lat) / 180.0 * H - 0.5
cap = map_coordinates(arr, [row.ravel(), col.ravel()], order=3, mode="wrap").reshape(n, n)
inside = r <= 0.5
lo, hi = np.percentile(cap[inside], [0.5, 99.7])
x = np.clip((cap - lo) / (hi - lo), 0, 1)
# local-contrast enhancement: subtract part of the large-scale albedo trend
from scipy.ndimage import gaussian_filter
x = gaussian_filter(x, sigma=1.2)
x = np.clip(x - 0.30 * (gaussian_filter(x, sigma=90) - x[inside].mean()), 0, 1)
lo, hi = np.percentile(x[inside], [0.3, 99.9])
x = 0.10 + 0.82 * np.clip((x - lo) / (hi - lo), 0, 1) ** 0.95
x[~inside] = 0
img = Image.fromarray((x * 255).astype(np.uint8), "L")
img = img.filter(ImageFilter.UnsharpMask(radius=1.6, percent=45, threshold=3))
img.save(os.path.join(ROOT, "www", "assets", "moon_south_cap.jpg"), quality=84, optimize=True)

meta = {
    "source_file": os.path.basename(src_path),
    "source_sha256": sha,
    "source_size_px": [W, H],
    "source_page": "https://svs.gsfc.nasa.gov/4720/",
    "credit": "NASA's Scientific Visualization Studio; NASA/GSFC/Arizona State University",
    "outputs": {
        "www/assets/moon_global_4k.jpg": "greyscale, Lanczos downsample, autocontrast 0.3 %",
        "www/assets/moon_south_cap.jpg": "greyscale, azimuthal equidistant 75S-90S, bicubic resampling, percentile stretch, denoise sigma 1.2 px, local-contrast (Gaussian sigma 90 px, 0.30), tone map 0.10-0.92, unsharp mask r=1.6",
    },
    "cap_extent_deg": CAP_DEG,
    "effective_resolution_note": "Source latitude sampling 22.8 px/deg (~1.33 km/px); the cap image is upsampled and cannot show detail finer than the source.",
    "use": "Visual orientation only; not used in any calculation.",
}
with open(os.path.join(ROOT, "data", "processed", "texture_provenance.json"), "w") as f:
    json.dump(meta, f, indent=2)
print(json.dumps(meta, indent=2))

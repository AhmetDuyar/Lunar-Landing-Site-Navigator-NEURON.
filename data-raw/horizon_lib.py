"""
NEURON Lunar Navigator - terrain horizon library
================================================

Exact local horizons from the LOLA south-polar DEM (LDEM_80S_80MPP_ADJ,
Barker et al. 2023, PGDA product 90; 80 m/px, polar stereographic, R = 1737.4 km,
heights relative to that sphere).

horizon(lat, lon) marches along great circles in every azimuth and returns the
largest elevation angle of the terrain as seen from 2 m above the surface,
including the curvature of the Moon:

    theta(d) = atan2( r_t cos(gamma) - r_o , r_t sin(gamma) ),  gamma = d / R,
    r_o = R + z_0 + 2 m,  r_t = R + z(d).

Multi-resolution sampling: 80 m steps to 5 km (80 m DEM), 320 m steps to 30 km
(4x4 block mean), 1280 m steps to 150 km (16x16 block mean). Samples outside the
DEM (beyond 80 deg S) are ignored, so horizons towards the north are truncated
at the DEM edge.
"""
import numpy as np
from scipy.ndimage import map_coordinates

R = 1737400.0
N = 7600
PX = 80.0
X0 = -304000.0
H_OBS = 2.0


def load_dem(path):
    z = np.fromfile(path, dtype=np.float32).reshape(N, N)
    z4 = z.reshape(N // 4, 4, N // 4, 4).mean(axis=(1, 3))
    z16 = z.reshape(N // 16, 16, N // 16, 16).mean(axis=(1, 3))
    return {"z": z, "levels": [(z, PX), (z4, PX * 4), (z16, PX * 16)]}


def ll_to_xy(lat, lon):
    colat = np.radians(90.0 + np.asarray(lat, float))
    rho = 2 * R * np.tan(colat / 2)
    t = np.radians(lon)
    return rho * np.sin(t), rho * np.cos(t)


def sample(arr, px, x, y):
    """Bilinear sample of a grid with pixel size px (pixel-registered, origin X0)."""
    n = arr.shape[0]
    col = (x - X0) / px - 0.5
    row = (-X0 - y) / px - 0.5
    ok = (col >= 0) & (col <= n - 1) & (row >= 0) & (row <= n - 1)
    v = map_coordinates(arr, [row, col], order=1, mode="nearest")
    return np.where(ok, v, np.nan)


def destination(lat, lon, az, d):
    """Great-circle destination; az clockwise from north (deg), d in m. Broadcasts."""
    p1 = np.radians(lat); l1 = np.radians(lon); a = np.radians(az); g = d / R
    sp2 = np.sin(p1) * np.cos(g) + np.cos(p1) * np.sin(g) * np.cos(a)
    p2 = np.arcsin(np.clip(sp2, -1, 1))
    l2 = l1 + np.arctan2(np.sin(a) * np.sin(g) * np.cos(p1), np.cos(g) - np.sin(p1) * sp2)
    return np.degrees(p2), np.degrees(l2)


STEPS = [(np.arange(80.0, 5000.0 + 1, 80.0), 0),
         (np.arange(5320.0, 30000.0 + 1, 320.0), 1),
         (np.arange(31280.0, 150000.0 + 1, 1280.0), 2)]


def horizon(dem, lat, lon, az=None):
    """Horizon elevation (deg) for each azimuth (deg, clockwise from local north)."""
    if az is None:
        az = np.arange(0.0, 360.0, 1.0)
    x0, y0 = ll_to_xy(lat, lon)
    z0 = float(sample(dem["z"], PX, np.array([x0]), np.array([y0]))[0])
    r_o = R + z0 + H_OBS
    best = np.full(az.shape, -90.0)
    for d, lev in STEPS:
        arr, px = dem["levels"][lev]
        la, lo = destination(lat, lon, az[:, None], d[None, :])
        x, y = ll_to_xy(la, lo)
        zt = sample(arr, px, x.ravel(), y.ravel()).reshape(x.shape)
        g = d[None, :] / R
        r_t = R + zt
        th = np.degrees(np.arctan2(r_t * np.cos(g) - r_o, r_t * np.sin(g)))
        th = np.where(np.isnan(th), -90.0, th)
        best = np.maximum(best, th.max(axis=1))
    return best, z0


# --- cheap features for the ML surrogate ---------------------------------------
FEAT_D = np.array([1000.0, 2000.0, 4000.0, 8000.0, 16000.0, 32000.0, 64000.0, 128000.0])


def features(dem, lat, lon, az):
    """Per azimuth: elevation angles of 8 coarse (1280 m) terrain samples, local terms."""
    x0, y0 = ll_to_xy(lat, lon)
    z = dem["z"]
    z0 = float(sample(z, PX, np.array([x0]), np.array([y0]))[0])
    r_o = R + z0 + H_OBS
    arr, px = dem["levels"][2]
    la, lo = destination(lat, lon, az[:, None], FEAT_D[None, :])
    x, y = ll_to_xy(la, lo)
    zt = sample(arr, px, x.ravel(), y.ravel()).reshape(x.shape)
    g = FEAT_D[None, :] / R
    th = np.degrees(np.arctan2((R + zt) * np.cos(g) - r_o, (R + zt) * np.sin(g)))
    th = np.where(np.isnan(th), -5.0, th)
    # local slope along each azimuth from the 80 m DEM (+-160 m)
    la1, lo1 = destination(lat, lon, az, 160.0)
    xa, ya = ll_to_xy(la1, lo1)
    za = sample(z, PX, xa, ya)
    slope_dir = np.degrees(np.arctan2(za - z0, 160.0))
    # local relief within ~1 km (4 x 4 km window of the 320 m level std)
    a4, p4 = dem["levels"][1]
    ring = np.array([sample(a4, p4, np.array([x0 + dx]), np.array([y0 + dy]))[0]
                     for dx in (-960, 0, 960) for dy in (-960, 0, 960)])
    relief = float(np.nanstd(ring))
    colat = 90.0 + lat
    F = np.column_stack([th, th.max(axis=1), slope_dir,
                         np.full(az.shape, z0), np.full(az.shape, relief), np.full(az.shape, colat),
                         np.sin(np.radians(az)), np.cos(np.radians(az))])
    return F


FEATURE_NAMES = [f"theta_{int(d / 1000)}km" for d in FEAT_D] + ["theta_coarse_max", "slope_along_az",
                                                                 "elevation", "relief_2km", "colatitude",
                                                                 "sin_az", "cos_az"]


# --- features for the deployable surrogate: ONLY the 1280 m DEM (475 x 475) --------
def features_coarse(z16, lat, lon, az):
    """Same idea as features(), but every input comes from the 1280 m block-mean DEM,
    so the app can evaluate it from a < 1 MB file. az: array of azimuths (deg)."""
    px = PX * 16
    x0, y0 = ll_to_xy(lat, lon)
    z0 = float(sample(z16, px, np.array([x0]), np.array([y0]))[0])
    r_o = R + z0 + H_OBS
    la, lo = destination(lat, lon, az[:, None], FEAT_D[None, :])
    x, y = ll_to_xy(la, lo)
    zt = sample(z16, px, x.ravel(), y.ravel()).reshape(x.shape)
    g = FEAT_D[None, :] / R
    th = np.degrees(np.arctan2((R + zt) * np.cos(g) - r_o, (R + zt) * np.sin(g)))
    th = np.where(np.isnan(th), -5.0, th)
    ring = sample(z16, px, x0 + np.array([-1, 0, 1, -1, 0, 1, -1, 0, 1]) * px,
                  y0 + np.array([-1, -1, -1, 0, 0, 0, 1, 1, 1]) * px)
    relief = float(np.nanstd(ring))
    colat = 90.0 + lat
    return np.column_stack([th, th.max(axis=1), np.full(az.shape, z0), np.full(az.shape, relief),
                            np.full(az.shape, colat), np.sin(np.radians(az)), np.cos(np.radians(az))])


COARSE_FEATURE_NAMES = [f"theta_{int(d / 1000)}km" for d in FEAT_D] + ["theta_coarse_max", "elevation",
                                                                       "relief_3x3", "colatitude", "sin_az", "cos_az"]

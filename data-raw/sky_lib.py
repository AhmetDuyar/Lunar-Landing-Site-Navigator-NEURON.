"""Local Sun/Earth elevation and azimuth from the hourly DE421 product (same math as the app)."""
import numpy as np
import pandas as pd

R_KM = 1737.4
SUN_RADIUS_DEG = 0.2666     # mean apparent radius of the solar disc
_EPH = None


def eph(path="data/processed/ephemeris_moon_me_1h.csv.gz"):
    global _EPH
    if _EPH is None:
        e = pd.read_csv(path)
        _EPH = {"utc": e["utc"].to_numpy(),
                "sun": e[["sun_x", "sun_y", "sun_z"]].to_numpy(float),
                "earth": e[["earth_x_km", "earth_y_km", "earth_z_km"]].to_numpy(float)}
    return _EPH


def local_frame(lat, lon):
    la, lo = np.radians(lat), np.radians(lon)
    up = np.array([np.cos(la) * np.cos(lo), np.cos(la) * np.sin(lo), np.sin(la)])
    east = np.array([-np.sin(lo), np.cos(lo), 0.0])
    north = np.array([-np.sin(la) * np.cos(lo), -np.sin(la) * np.sin(lo), np.cos(la)])
    return up, east, north


def sky(lat, lon, idx=slice(None)):
    E = eph()
    up, east, north = local_frame(lat, lon)
    s = E["sun"][idx]
    e = E["earth"][idx] - R_KM * up
    e = e / np.linalg.norm(e, axis=1, keepdims=True)
    out = {}
    for k, u in (("sun", s), ("earth", e)):
        out[k + "_el"] = np.degrees(np.arcsin(np.clip(u @ up, -1, 1)))
        out[k + "_az"] = np.degrees(np.arctan2(u @ east, u @ north)) % 360.0
    return out


def horizon_at(hz, az):
    """Linear interpolation of a 360-value horizon (1 deg steps) at azimuths az."""
    a = np.asarray(az) % 360.0
    i0 = np.floor(a).astype(int) % 360
    f = a - np.floor(a)
    return hz[i0] * (1 - f) + hz[(i0 + 1) % 360] * f

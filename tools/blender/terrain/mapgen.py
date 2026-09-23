"""Heightfield, masks and placements for an Aether Crown map.

Pure numpy so it can run inside Blender or with a plain Python + numpy.
World convention (same as Godot): x = east, y = up, z = south. Arrays are
indexed [iz, ix].
"""
import json
import math
import struct
import zlib

import numpy as np

SQRT2 = math.sqrt(2.0)


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------
def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def terrace(y, step, rise=0.55):
    k = np.floor(y / step)
    f = y / step - k
    return step * (k + smoothstep(0.05, rise, f))


def box_blur(a, r):
    """Separable box blur with edge clamping (radius r cells)."""
    if r < 1:
        return a.copy()
    out = a
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]
        pad[axis] = (r + 1, r)
        p = np.pad(out, pad, mode="edge")
        c = np.cumsum(p, axis=axis, dtype=np.float64)
        n = out.shape[axis]
        if axis == 0:
            out = (c[2 * r + 1:2 * r + 1 + n, :] - c[0:n, :]) / (2 * r + 1)
        else:
            out = (c[:, 2 * r + 1:2 * r + 1 + n] - c[:, 0:n]) / (2 * r + 1)
    return out


def blur(a, r):
    for _ in range(3):
        a = box_blur(a, r)
    return a


def bilinear(field, S, x, z):
    """Sample an [N,N] field spanning [-S/2,S/2]^2 at world coords."""
    n = field.shape[0]
    fx = np.clip((np.asarray(x) + S / 2) / S * (n - 1), 0, n - 1.000001)
    fz = np.clip((np.asarray(z) + S / 2) / S * (n - 1), 0, n - 1.000001)
    x0 = np.floor(fx).astype(np.int64)
    z0 = np.floor(fz).astype(np.int64)
    tx = fx - x0
    tz = fz - z0
    a = field[z0, x0] * (1 - tx) + field[z0, x0 + 1] * tx
    b = field[z0 + 1, x0] * (1 - tx) + field[z0 + 1, x0 + 1] * tx
    return a * (1 - tz) + b * tz


def write_png(path, arr):
    arr = np.ascontiguousarray(arr)
    if arr.ndim == 2:
        color_type = 0
    elif arr.shape[2] == 3:
        color_type = 2
    else:
        color_type = 6
    depth = 16 if arr.dtype == np.uint16 else 8
    data = arr.astype(">u2") if depth == 16 else arr.astype(np.uint8)
    h, w = arr.shape[:2]
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(tag, payload):
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, depth, color_type, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 6))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


# --------------------------------------------------------------------------
# noise
# --------------------------------------------------------------------------
class Perlin:
    def __init__(self, seed):
        rng = np.random.default_rng(seed)
        perm = rng.permutation(256).astype(np.int64)
        self.perm = np.concatenate([perm, perm])
        ang = rng.random(256) * 2.0 * np.pi
        self.gx = np.cos(ang)
        self.gy = np.sin(ang)

    def noise(self, x, y):
        x = np.asarray(x, dtype=np.float64)
        y = np.asarray(y, dtype=np.float64)
        x0 = np.floor(x)
        y0 = np.floor(y)
        fx = x - x0
        fy = y - y0
        ix = x0.astype(np.int64) & 255
        iy = y0.astype(np.int64) & 255
        ix1 = (ix + 1) & 255
        iy1 = (iy + 1) & 255
        p = self.perm

        def dot(hx, hy, dx, dy):
            h = p[p[hx] + hy]
            return self.gx[h] * dx + self.gy[h] * dy

        n00 = dot(ix, iy, fx, fy)
        n10 = dot(ix1, iy, fx - 1.0, fy)
        n01 = dot(ix, iy1, fx, fy - 1.0)
        n11 = dot(ix1, iy1, fx - 1.0, fy - 1.0)
        u = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
        v = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
        a = n00 + u * (n10 - n00)
        b = n01 + u * (n11 - n01)
        return (a + v * (b - a)) * 1.414

    def fbm(self, x, y, octaves=4, lac=2.0, gain=0.5):
        total = 0.0
        amp = 1.0
        norm = 0.0
        f = 1.0
        for i in range(octaves):
            total = total + amp * self.noise(x * f + i * 17.31, y * f + i * 9.17)
            norm += amp
            amp *= gain
            f *= lac
        return total / norm

    def ridged(self, x, y, octaves=4):
        total = 0.0
        amp = 1.0
        norm = 0.0
        f = 1.0
        for i in range(octaves):
            n = 1.0 - np.abs(self.noise(x * f + i * 31.7, y * f - i * 11.3))
            total = total + amp * n * n
            norm += amp
            amp *= 0.5
            f *= 2.0
        return total / norm


# --------------------------------------------------------------------------
# polylines
# --------------------------------------------------------------------------
def catmull_rom(points, step=2.0):
    pts = np.asarray(points, dtype=np.float64)
    if len(pts) < 3:
        return pts
    P = np.vstack([pts[0] * 2 - pts[1], pts, pts[-1] * 2 - pts[-2]])
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        n = max(2, int(np.linalg.norm(p2 - p1) / step))
        t = np.linspace(0.0, 1.0, n, endpoint=False)[:, None]
        t2 = t * t
        t3 = t2 * t
        c = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                   + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
        out.append(c)
    out.append(pts[-1][None])
    return np.vstack(out)


def densify(points, step=2.0):
    pts = np.asarray(points, dtype=np.float64)
    out = []
    for a, b in zip(pts[:-1], pts[1:]):
        n = max(1, int(np.linalg.norm(b - a) / step))
        t = np.linspace(0.0, 1.0, n, endpoint=False)[:, None]
        out.append(a + (b - a) * t)
    out.append(pts[-1][None])
    return np.vstack(out)


def polyline_query(px, pz, poly, attr=None):
    """Nearest point on a polyline for every (px, pz).

    Returns dist, attr (interpolated along the line), tangent x/z and side
    (+1 left of travel direction when looking down -y, i.e. cross > 0).
    """
    shape = np.shape(px)
    X = np.ravel(px).astype(np.float64)
    Z = np.ravel(pz).astype(np.float64)
    best = np.full(X.shape, np.inf)
    at = np.zeros_like(X)
    tx = np.zeros_like(X)
    tz = np.zeros_like(X)
    side = np.zeros_like(X)
    if attr is None:
        attr = np.zeros(len(poly))
    for i in range(len(poly) - 1):
        a = poly[i]
        d = poly[i + 1] - a
        L2 = float(d @ d)
        if L2 < 1e-9:
            continue
        t = np.clip(((X - a[0]) * d[0] + (Z - a[1]) * d[1]) / L2, 0.0, 1.0)
        qx = a[0] + t * d[0]
        qz = a[1] + t * d[1]
        dist2 = (X - qx) ** 2 + (Z - qz) ** 2
        m = dist2 < best
        if not m.any():
            continue
        L = math.sqrt(L2)
        best[m] = dist2[m]
        at[m] = attr[i] + t[m] * (attr[i + 1] - attr[i])
        tx[m] = d[0] / L
        tz[m] = d[1] / L
        side[m] = np.sign(d[0] * (Z[m] - a[1]) - d[1] * (X[m] - a[0]))
    return (np.sqrt(best).reshape(shape), at.reshape(shape), tx.reshape(shape),
            tz.reshape(shape), side.reshape(shape))


def point_at_sdiag(poly, sdiag_poly, s):
    """Point and unit tangent on the polyline where the diagonal coord == s."""
    i = int(np.clip(np.searchsorted(sdiag_poly, s) - 1, 0, len(poly) - 2))
    s0, s1 = sdiag_poly[i], sdiag_poly[i + 1]
    t = 0.0 if s1 == s0 else (s - s0) / (s1 - s0)
    p = poly[i] + (poly[i + 1] - poly[i]) * t
    d = poly[i + 1] - poly[i]
    d = d / np.linalg.norm(d)
    return p, d


# --------------------------------------------------------------------------
# map generator
# --------------------------------------------------------------------------
class MapGen:
    def __init__(self, layout):
        self.L = layout
        self.S = float(layout["size"])
        self.N = int(layout["height_grid"])
        self.cell = self.S / (self.N - 1)
        self.noise = Perlin(layout["seed"])
        self.noise2 = Perlin(layout["seed"] + 101)
        c = layout["canyon"]
        self.canyon_poly = catmull_rom(c["points"], 2.0)
        self.canyon_sdiag = (self.canyon_poly[:, 0] + self.canyon_poly[:, 1]) / SQRT2
        self.lv = layout["levels"]
        self.roads = [catmull_rom(r, 6.0) for r in layout["roads"]]

    # ---- grids -------------------------------------------------------
    def grid(self, n):
        v = np.linspace(-self.S / 2, self.S / 2, n)
        return np.meshgrid(v, v)

    def pixel_grid(self, n):
        """Pixel-centred grid for textures (n x n covering the map)."""
        v = -self.S / 2 + (np.arange(n) + 0.5) * self.S / n
        return np.meshgrid(v, v)

    # ---- canyon --------------------------------------------------------
    def water_level(self, s, sharp=True):
        steps = self.L["canyon"]["water_steps"]
        s = np.asarray(s, dtype=np.float64)
        if sharp:
            out = np.full(s.shape, steps[-1]["level"])
            for st in reversed(steps):
                out = np.where(s < st["until"], st["level"], out)
            return out
        out = np.full(s.shape, steps[0]["level"], dtype=np.float64)
        for a, b in zip(steps[:-1], steps[1:]):
            out = out + (b["level"] - a["level"]) * smoothstep(a["until"] - 1.6, a["until"] + 1.6, s)
        return out

    def canyon_fields(self, X, Z):
        c = self.L["canyon"]
        dist, sd, tx, tz, side = polyline_query(X, Z, self.canyon_poly, self.canyon_sdiag)
        r = dist + self.noise.fbm(X / 22.0, Z / 22.0, 3) * 3.2
        bulge = np.exp(-(sd / c["bulge_sigma"]) ** 2)
        hwf = c["half_width_floor"] + c["bulge_floor"] * bulge
        hwt = c["half_width_top"] + c["bulge_top"] * bulge
        floor = self.water_level(sd, sharp=False) - c["water_depth"]
        return dict(dist=dist, r=r, sd=sd, tx=tx, tz=tz, side=side, hwf=hwf, hwt=hwt, floor=floor)

    def canyon_carve(self, X, Z, cf):
        depth = self.lv["plains"] - cf["floor"]
        y = np.maximum(cf["r"] - cf["hwf"], 0.0) / np.maximum(cf["hwt"] - cf["hwf"], 1e-3) * depth
        y = y + self.noise2.fbm(X / 9.0, Z / 9.0, 2) * 0.9
        return cf["floor"] + terrace(np.maximum(y, 0.0), 4.6)

    # ---- height --------------------------------------------------------
    def build_height(self):
        X, Z = self.grid(self.N)
        nz = self.noise
        H = (self.lv["plains"] + 1.9 * nz.fbm(X / 85.0, Z / 85.0, 4)
             + 0.55 * nz.fbm(X / 21.0, Z / 21.0, 3))

        # rocky hills that split the lanes
        for h in self.L["hills"]:
            cx, cz = h["center"]
            d = np.hypot(X - cx, Z - cz) / h["radius"] + nz.fbm(X / 18.0, Z / 18.0, 3) * 0.22
            shape = smoothstep(1.0, 0.25, d)
            rid = 0.7 + 0.45 * nz.ridged(X / 26.0, Z / 26.0, 4)
            H = H + terrace(h["height"] * shape * rid, 3.2, 0.7)

        # mountain ring
        rho = (np.abs(X) ** 6 + np.abs(Z) ** 6) ** (1.0 / 6.0)
        m = smoothstep(164.0, 206.0, rho + 8.0 * nz.fbm(X / 40.0, Z / 40.0, 3))
        H = H + self.lv["mountain"] * m ** 1.25 * (0.5 + 0.55 * nz.ridged(X / 48.0, Z / 48.0, 5))

        # plateaus (high-ground bases) and their ramps
        ph = self.lv["plateau"]
        for p in self.L["plateaus"]:
            cx, cz = p["center"]
            d = np.hypot(X - cx, Z - cz) - (p["radius"] + 5.0 * nz.fbm(X / 30.0, Z / 30.0, 3))
            cliff = 1.0 - smoothstep(-2.8, 2.8, d)
            H = np.maximum(H, H * (1.0 - cliff) + ph * cliff)
            for rp in p["ramps"]:
                ax, az = rp["top"]
                bx, bz = rp["bottom"]
                ux, uz = bx - ax, bz - az
                L = math.hypot(ux, uz)
                ux /= L
                uz /= L
                t = ((X - ax) * ux + (Z - az) * uz) / L
                lat = np.abs((X - ax) * -uz + (Z - az) * ux)
                rh = ph * (1.0 - np.clip(t, 0.0, 1.0))
                w = rp["width"]
                mk = (1.0 - smoothstep(w / 2, w / 2 + 9.0, lat)) \
                    * smoothstep(-0.4, -0.12, t) * (1.0 - smoothstep(1.08, 1.4, t))
                H = H * (1.0 - mk) + rh * mk

        # canyon
        cf = self.canyon_fields(X, Z)
        H = np.minimum(H, self.canyon_carve(X, Z, cf))

        # central mesa
        me = self.L["mesa"]
        md = (np.hypot(X - me["center"][0], Z - me["center"][1]) + nz.fbm(X / 24.0, Z / 24.0, 3) * 5.5
              + nz.fbm(X / 7.0, Z / 7.0, 2) * 1.2)
        fall = np.maximum(md - me["radius"], 0.0) * 2.6
        H = np.maximum(H, self.lv["mesa"] - terrace(fall + nz.fbm(X / 11.0, Z / 11.0, 2) * 1.5, 3.6, 0.72))

        # soften roads
        road_d = self.road_distance(X, Z)
        above = smoothstep(-2.5, -1.0, H)
        rmask = (1.0 - smoothstep(3.0, 7.5, road_d)) * above
        Hs = blur(H, 2)
        H = H * (1 - rmask * 0.7) + Hs * rmask * 0.7

        # flatten site pads
        for s in self.L["sites"]:
            sx, sz = s["pos"]
            h0 = float(bilinear(H, self.S, sx, sz))
            d = np.hypot(X - sx, Z - sz)
            mk = (1.0 - smoothstep(s["radius"] * 0.75, s["radius"] * 1.15, d)) * above
            H = H * (1 - mk) + h0 * mk
        for g in self.L["gates"]:
            gx, gz = g["pos"]
            h0 = float(bilinear(H, self.S, gx, gz))
            d = np.hypot(X - gx, Z - gz)
            mk = (1.0 - smoothstep(9.0, 14.0, d)) * above
            H = H * (1 - mk) + h0 * mk

        # bridge approaches
        deck = self.lv["bridge_deck"]
        for b in self.L["bridges"]:
            for end in (b["a"], b["b"]):
                d = np.hypot(X - end[0], Z - end[1])
                mk = (1.0 - smoothstep(6.0, 12.0, d)) * smoothstep(-3.0, -1.0, H)
                H = H * (1 - mk) + (deck - 0.08) * mk

        self.X, self.Z, self.H = X, Z, H
        self.cf = cf
        self.rho = rho
        self.mount = m
        self.road_d = road_d
        return H

    def road_distance(self, X, Z):
        d = np.full(np.shape(X), np.inf)
        for r in self.roads:
            dd = polyline_query(X, Z, r)[0]
            d = np.minimum(d, dd)
        return d

    # ---- derived fields -----------------------------------------------
    def normals(self, H=None):
        H = self.H if H is None else H
        gz, gx = np.gradient(H, self.cell)
        n = np.stack([-gx, np.ones_like(H), -gz], axis=-1)
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        return n

    def ambient_occlusion(self):
        H = self.H
        n = H.shape[0]
        occl = np.zeros_like(H)
        dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]
        steps = [1, 2, 3, 5, 8, 12, 18, 26]
        pad = steps[-1] + 1
        P = np.pad(H, pad, mode="edge")
        for dx, dz in dirs:
            L = math.hypot(dx, dz)
            best = np.zeros_like(H)
            for s in steps:
                sh = P[pad + dz * s:pad + dz * s + n, pad + dx * s:pad + dx * s + n]
                ang = (sh - H) / (s * L * self.cell)
                best = np.maximum(best, ang)
            occl += np.sin(np.arctan(best))
        ao = 1.0 - occl / len(dirs)
        return np.clip(ao, 0.0, 1.0) ** 1.35

    # ---- navigation ----------------------------------------------------
    def bridge_frames(self):
        out = []
        deck = self.lv["bridge_deck"] + 0.3
        for b in self.L["bridges"]:
            a = np.array(b["a"], dtype=np.float64)
            c = np.array(b["b"], dtype=np.float64)
            u = c - a
            L = float(np.linalg.norm(u))
            u /= L
            out.append(dict(id=b["id"], a=a, b=c, u=u, length=L, width=b["width"], deck=deck))
        return out

    def build_nav(self):
        cell = self.L["nav_cell"]
        n = int(round(self.S / cell))
        v = -self.S / 2 + (np.arange(n) + 0.5) * cell
        X, Z = np.meshgrid(v, v)
        normals = self.normals()
        slope = np.degrees(np.arccos(np.clip(normals[..., 1], -1, 1)))
        smax = np.zeros_like(X)
        for ox in (-0.45, 0.45):
            for oz in (-0.45, 0.45):
                smax = np.maximum(smax, bilinear(slope, self.S, X + ox * cell, Z + oz * cell))
        h = bilinear(self.H, self.S, X, Z)
        rho = (np.abs(X) ** 6 + np.abs(Z) ** 6) ** (1.0 / 6.0)
        walk = (smax < 30.0) & (h > -3.0) & (rho < self.L["playable_radius"])
        for b in self.bridge_frames():
            rel_x = X - b["a"][0]
            rel_z = Z - b["a"][1]
            along = rel_x * b["u"][0] + rel_z * b["u"][1]
            lat = np.abs(rel_x * -b["u"][1] + rel_z * b["u"][0])
            on = (along > -3.0) & (along < b["length"] + 3.0) & (lat < b["width"] / 2 - 1.4)
            walk |= on
        # keep the component reachable from the first base
        bx, bz = self.L["bases"][0]["pos"]
        si = int((bz + self.S / 2) / cell)
        sj = int((bx + self.S / 2) / cell)
        keep = np.zeros_like(walk)
        stack = [(si, sj)]
        while stack:
            i, j = stack.pop()
            if i < 0 or j < 0 or i >= n or j >= n or keep[i, j] or not walk[i, j]:
                continue
            keep[i, j] = True
            stack.extend(((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)))
        self.nav = keep
        return keep

    # ---- splat ---------------------------------------------------------
    def build_splat(self, size):
        X, Z = self.pixel_grid(size)
        nz = self.noise
        H = bilinear(self.H, self.S, X, Z)
        nrm = self.normals()
        slope_y = bilinear(nrm[..., 1], self.S, X, Z)
        road_d = self.road_distance(X, Z)
        jitter = nz.fbm(X / 5.0, Z / 5.0, 2)
        road = 1.0 - smoothstep(1.9, 3.6, road_d + jitter * 0.9)
        dirt = road * 0.95
        ash = np.zeros_like(H)
        for s in self.L["sites"]:
            d = np.hypot(X - s["pos"][0], Z - s["pos"][1])
            pad = 1.0 - smoothstep(s["radius"] * 0.6, s["radius"] * 1.25, d + nz.fbm(X / 9, Z / 9, 3) * 6)
            dirt = np.maximum(dirt, pad * 0.5)
            if s["kind"] == "industry":
                zone = 1.0 - smoothstep(s["radius"] * 0.9, s["radius"] * 1.9, d + nz.fbm(X / 14, Z / 14, 3) * 10)
                ash = np.maximum(ash, zone * 0.55)
        for b in self.L["bases"]:
            d = np.hypot(X - b["pos"][0], Z - b["pos"][1])
            pad = 1.0 - smoothstep(26.0, 48.0, d + nz.fbm(X / 11, Z / 11, 3) * 9)
            dirt = np.maximum(dirt, pad * 0.4)
            ash = np.maximum(ash, pad * 0.3)
        for g in self.L["gates"]:
            d = np.hypot(X - g["pos"][0], Z - g["pos"][1])
            dirt = np.maximum(dirt, (1.0 - smoothstep(6.0, 13.0, d)) * 0.8)
        rho = (np.abs(X) ** 6 + np.abs(Z) ** 6) ** (1.0 / 6.0)
        mount = smoothstep(166.0, 196.0, rho + 8.0 * nz.fbm(X / 40.0, Z / 40.0, 3))
        rock = mount * smoothstep(-0.2, 0.4, nz.fbm(X / 16.0, Z / 16.0, 3) + mount * 0.6)
        rock = np.maximum(rock, (1.0 - smoothstep(-4.5, -2.0, H)) * 0.85)
        for h in self.L["hills"]:
            d = np.hypot(X - h["center"][0], Z - h["center"][1]) / h["radius"]
            rock = np.maximum(rock, smoothstep(1.05, 0.55, d + nz.fbm(X / 8, Z / 8, 2) * 0.2) * 0.9)
        patches = smoothstep(0.42, 0.62, nz.fbm(X / 26.0 + 40, Z / 26.0, 4))
        rock = np.maximum(rock, patches * 0.6 * (1 - road))
        rock *= (1 - road * 0.9)
        forest = self.forest_density(X, Z) * (1 - road)
        # steep ground is handled by the shader (triplanar cliff)
        dirt = np.clip(dirt, 0, 1)
        total = dirt + rock + ash
        scale = np.where(total > 1.0, 1.0 / np.maximum(total, 1e-6), 1.0)
        rgba = np.stack([dirt * scale, rock * scale, ash * scale, forest], axis=-1)
        self.splat_fields = dict(H=H, road=road, rock=rock, forest=forest, slope_y=slope_y)
        return (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)

    def forest_density(self, X, Z):
        nz = self.noise
        f = smoothstep(-0.12, 0.2, nz.fbm(X / 58.0 + 13.0, Z / 58.0 - 7.0, 4))
        rho = (np.abs(X) ** 6 + np.abs(Z) ** 6) ** (1.0 / 6.0)
        ring = smoothstep(150.0, 172.0, rho) * (1.0 - smoothstep(186.0, 202.0, rho))
        f = np.maximum(f, ring * smoothstep(-0.35, 0.1, nz.fbm(X / 20.0, Z / 20.0, 3)))
        return np.clip(f, 0, 1)

    # ---- placements ----------------------------------------------------
    def height_at(self, x, z):
        return bilinear(self.H, self.S, x, z)

    def road_at(self, x, z):
        return bilinear(self.road_d, self.S, x, z)

    def excl_mask(self, X, Z, site_pad=6.0, base_r=58.0):
        ok = np.ones(np.shape(X), dtype=bool)
        for s in self.L["sites"]:
            ok &= np.hypot(X - s["pos"][0], Z - s["pos"][1]) > s["radius"] + site_pad
        for b in self.L["bases"]:
            ok &= np.hypot(X - b["pos"][0], Z - b["pos"][1]) > base_r
        for g in self.L["gates"]:
            ok &= np.hypot(X - g["pos"][0], Z - g["pos"][1]) > 16.0
        for b in self.bridge_frames():
            for e in (b["a"], b["b"]):
                ok &= np.hypot(X - e[0], Z - e[1]) > 14.0
        for p in self.L["plateaus"]:
            for rp in p["ramps"]:
                ax, az = rp["top"]
                bx, bz = rp["bottom"]
                ux, uz = bx - ax, bz - az
                L = math.hypot(ux, uz)
                ux /= L
                uz /= L
                t = ((X - ax) * ux + (Z - az) * uz) / L
                lat = np.abs((X - ax) * -uz + (Z - az) * ux)
                ok &= ~((lat < rp["width"] / 2 + 4.0) & (t > -0.3) & (t < 1.35))
        return ok

    def scatter(self, spacing, density_fn, rng, slope_max, hmin=-1.2, hmax=60.0, road_min=6.5):
        n = int(self.S / spacing)
        v = -self.S / 2 + (np.arange(n) + 0.5) * spacing
        X, Z = np.meshgrid(v, v)
        X = (X + (rng.random(X.shape) - 0.5) * spacing * 0.9).ravel()
        Z = (Z + (rng.random(Z.shape) - 0.5) * spacing * 0.9).ravel()
        keep = rng.random(X.shape) < density_fn(X, Z)
        X = X[keep]
        Z = Z[keep]
        h = self.height_at(X, Z)
        nrm = self.normals()
        ny = bilinear(nrm[..., 1], self.S, X, Z)
        slope = np.degrees(np.arccos(np.clip(ny, -1, 1)))
        rho = (np.abs(X) ** 6 + np.abs(Z) ** 6) ** (1.0 / 6.0)
        ok = (slope < slope_max) & (h > hmin) & (h < hmax) & (rho < 199.0)
        ok &= self.road_at(X, Z) > road_min
        ok &= self.excl_mask(X, Z)
        return [(float(x), float(hh), float(z)) for x, z, hh in zip(X[ok], Z[ok], h[ok])]

    def build_placements(self):
        rng = np.random.default_rng(self.L["seed"] + 5)
        placements = {"trees": [], "rocks": [], "props": [], "mist": [], "bridges": []}

        def tree_density(X, Z):
            return self.forest_density(X, Z) * 0.92

        for (x, y, z) in self.scatter(3.3, tree_density, rng, 34.0):
            placements["trees"].append([round(x, 2), round(y - 0.15, 2), round(z, 2),
                                        round(float(rng.uniform(0.75, 1.35)), 2),
                                        round(float(rng.uniform(0, math.tau)), 3),
                                        int(rng.integers(0, 3))])

        def rock_density(X, Z):
            rho = (np.abs(X) ** 6 + np.abs(Z) ** 6) ** (1.0 / 6.0)
            mount = smoothstep(160.0, 190.0, rho)
            hill = np.zeros_like(X)
            for h in self.L["hills"]:
                d = np.hypot(X - h["center"][0], Z - h["center"][1]) / h["radius"]
                hill = np.maximum(hill, smoothstep(1.3, 0.6, d))
            return np.clip(0.05 + mount * 0.35 + hill * 0.45, 0, 1)

        for (x, y, z) in self.scatter(9.0, rock_density, rng, 55.0, hmin=-30.0):
            placements["rocks"].append([round(x, 2), round(y - 0.3, 2), round(z, 2),
                                        round(float(rng.uniform(0.6, 2.4)), 2),
                                        round(float(rng.uniform(0, math.tau)), 3),
                                        int(rng.integers(0, 3))])

        # canyon floor boulders
        cf_pts = []
        for _ in range(900):
            x = rng.uniform(-200, 200)
            z = rng.uniform(-200, 200)
            h = float(self.height_at(x, z))
            if h < -6.0:
                cf_pts.append((x, h, z))
        for (x, h, z) in cf_pts[:260]:
            placements["rocks"].append([round(x, 2), round(h - 0.4, 2), round(z, 2),
                                        round(float(rng.uniform(0.8, 2.8)), 2),
                                        round(float(rng.uniform(0, math.tau)), 3),
                                        int(rng.integers(0, 3))])

        self._place_sites(placements, rng)
        self._place_walls(placements, rng)
        self._place_lamps(placements, rng)
        for b in self.bridge_frames():
            placements["bridges"].append({
                "id": b["id"], "a": [round(float(b["a"][0]), 3), round(float(b["a"][1]), 3)],
                "b": [round(float(b["b"][0]), 3), round(float(b["b"][1]), 3)],
                "width": b["width"], "deck": round(b["deck"], 3)})
        return placements

    def _add_prop(self, placements, model, x, z, rot, scale=1.0, sink=0.25, footprint=3.0, team=-1):
        hs = [float(self.height_at(x + ox, z + oz)) for ox in (-footprint, 0, footprint)
              for oz in (-footprint, 0, footprint)]
        placements["props"].append({"model": model,
                                    "pos": [round(x, 2), round(min(hs) - sink, 2), round(z, 2)],
                                    "rot": round(rot, 3), "scale": round(scale, 2), "team": team})

    def _place_sites(self, placements, rng):
        for s in self.L["sites"]:
            sx, sz = s["pos"]
            R = s["radius"]
            if s["kind"] == "industry":
                kinds = ["workshop", "house_a", "smokestack", "warehouse", "house_b", "workshop", "house_a", "warehouse", "house_b", "smokestack"]
            else:
                kinds = ["house_a", "aether_pylon", "house_b", "crystal_cluster", "workshop", "house_a", "aether_pylon", "house_b", "crystal_cluster", "house_a"]
            placed = []
            attempts = 0
            k = 0
            while k < len(kinds) and attempts < 400:
                attempts += 1
                ang = rng.uniform(0, math.tau)
                rad = rng.uniform(R * 0.5, R * 1.05)
                x = sx + math.cos(ang) * rad
                z = sz + math.sin(ang) * rad
                if self.road_at(x, z) < 6.0:
                    continue
                if any(math.hypot(x - px, z - pz) < 8.0 for px, pz in placed):
                    continue
                h = [float(self.height_at(x + ox, z + oz)) for ox in (-3, 3) for oz in (-3, 3)]
                if max(h) - min(h) > 1.6 or min(h) < -1.5:
                    continue
                rot = math.atan2(sx - x, sz - z) + rng.uniform(-0.25, 0.25)
                self._add_prop(placements, kinds[k], x, z, rot, float(rng.uniform(0.9, 1.1)))
                placed.append((x, z))
                k += 1

    def _place_walls(self, placements, rng):
        for p in self.L["plateaus"]:
            cx, cz = p["center"]
            R = p["radius"] - 5.5
            ramp_angles = []
            for rp in p["ramps"]:
                ramp_angles.append(math.atan2(rp["top"][1] - cz, rp["top"][0] - cx))
            seg = 6.0
            n = int(math.tau * R / seg)
            for i in range(n):
                a = i / n * math.tau
                x = cx + math.cos(a) * R
                z = cz + math.sin(a) * R
                rho = (abs(x) ** 6 + abs(z) ** 6) ** (1.0 / 6.0)
                if rho > 168.0:
                    continue
                near_ramp = any(abs(math.atan2(math.sin(a - ra), math.cos(a - ra))) < 0.2 for ra in ramp_angles)
                if near_ramp:
                    continue
                if float(self.height_at(x, z)) < self.lv["plateau"] - 0.6:
                    continue
                outward = math.atan2(math.cos(a), math.sin(a))
                model = "wall_tower" if i % 5 == 0 else "wall_segment"
                self._add_prop(placements, model, x, z, outward, 1.0, sink=0.3, footprint=1.5, team=p["team"])

    def _place_lamps(self, placements, rng):
        centers = [s["pos"] for s in self.L["sites"]] + [b["pos"] for b in self.L["bases"]]
        for r in self.roads:
            pts = densify(r, 14.0)
            for i in range(1, len(pts) - 1):
                x, z = pts[i]
                if min(math.hypot(x - c[0], z - c[1]) for c in centers) > 48.0:
                    continue
                d = pts[i + 1] - pts[i - 1]
                d = d / (np.linalg.norm(d) + 1e-9)
                side = 1 if i % 2 == 0 else -1
                ox, oz = -d[1] * 5.2 * side, d[0] * 5.2 * side
                px, pz = x + ox, z + oz
                if float(self.height_at(px, pz)) < -1.0:
                    continue
                self._add_prop(placements, "lamp_post", px, pz, math.atan2(-ox, -oz), 1.0, sink=0.05, footprint=0.4)

    # ---- water ---------------------------------------------------------
    def water_regions(self):
        """Per water step: boolean cell mask on the height grid + level."""
        cf = self.cf
        steps = self.L["canyon"]["water_steps"]
        regions = []
        lo = -1e9
        for st in steps:
            hi = st["until"]
            level = st["level"]
            inside = (cf["sd"] > lo - 3.0) & (cf["sd"] < hi) & (cf["dist"] < cf["hwt"] + 6)
            wet = inside & (self.H < level + 0.6)
            regions.append(dict(level=level, lo=lo, hi=hi, mask=wet, lake=bool(st.get("lake", False))))
            lo = hi
        return regions

    def waterfalls(self):
        """Main river steps: crest line across the canyon floor."""
        steps = self.L["canyon"]["water_steps"]
        c = self.L["canyon"]
        out = []
        for a, b in zip(steps[:-1], steps[1:]):
            s = a["until"]
            p, d = point_at_sdiag(self.canyon_poly, self.canyon_sdiag, s)
            bulge = math.exp(-(s / c["bulge_sigma"]) ** 2)
            hwf = c["half_width_floor"] + c["bulge_floor"] * bulge
            out.append(dict(center=p, dir=d, half_width=hwf * 0.95, top=a["level"], bottom=b["level"]))
        return out

    def cliff_falls(self):
        c = self.L["canyon"]
        out = []
        for f in self.L.get("cliff_falls", []):
            p, d = point_at_sdiag(self.canyon_poly, self.canyon_sdiag, f["s"])
            perp = np.array([-d[1], d[0]]) * f["side"]
            bulge = math.exp(-(f["s"] / c["bulge_sigma"]) ** 2)
            hwf = c["half_width_floor"] + c["bulge_floor"] * bulge
            hwt = c["half_width_top"] + c["bulge_top"] * bulge
            water = float(self.water_level(np.array([f["s"]]))[0])
            prof = []
            for t in np.linspace(0.0, 1.0, 26):
                r = (hwt + 4.0) - t * (hwt + 4.0 - hwf + 1.0)
                q = p + perp * r
                y = float(self.height_at(q[0], q[1]))
                prof.append((q, max(y, water)))
            # start where the ground first dips below the plains lip
            out.append(dict(profile=prof, dir=d, perp=perp, width=f["width"], water=water))
        return out

    # ---- previews ------------------------------------------------------
    def hillshade(self, H, cell):
        gz, gx = np.gradient(H, cell)
        n = np.stack([-gx, np.ones_like(H), -gz], axis=-1)
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        sun = np.array([-0.55, 0.62, -0.56])
        sun /= np.linalg.norm(sun)
        return np.clip(n @ sun, 0, 1)

    def minimap(self, size=512):
        X, Z = self.pixel_grid(size)
        H = bilinear(self.H, self.S, X, Z)
        shade = self.hillshade(H, self.S / size)
        f = self.splat_small(size)
        grass = np.array([0.23, 0.28, 0.20])
        forest = np.array([0.13, 0.18, 0.13])
        dirt = np.array([0.46, 0.40, 0.30])
        rock = np.array([0.38, 0.38, 0.40])
        ash = np.array([0.24, 0.23, 0.24])
        water = np.array([0.10, 0.22, 0.32])
        col = grass[None, None, :] * np.ones_like(H)[..., None]
        col = col * (1 - f["forest"][..., None]) + forest * f["forest"][..., None]
        col = col * (1 - f["rock"][..., None]) + rock * f["rock"][..., None]
        col = col * (1 - f["ash"][..., None]) + ash * f["ash"][..., None]
        col = col * (1 - f["dirt"][..., None]) + dirt * f["dirt"][..., None]
        lit = col * (0.35 + 0.85 * shade[..., None])
        height_tint = np.clip((H + 25) / 70.0, 0, 1)[..., None]
        lit = lit * (0.75 + 0.35 * height_tint)
        wl = self.water_level(bilinear(self.cf["sd"], self.S, X, Z))
        wet = (H < wl + 0.1) & (bilinear(self.cf["dist"], self.S, X, Z) < 80)
        lit[wet] = water * (0.8 + 0.2 * shade[wet][..., None])
        for b in self.bridge_frames():
            rel_x = X - b["a"][0]
            rel_z = Z - b["a"][1]
            along = rel_x * b["u"][0] + rel_z * b["u"][1]
            lat = np.abs(rel_x * -b["u"][1] + rel_z * b["u"][0])
            on = (along > -2) & (along < b["length"] + 2) & (lat < b["width"] / 2)
            lit[on] = np.array([0.55, 0.52, 0.48])
        return (np.clip(lit, 0, 1) * 255).astype(np.uint8)

    def splat_small(self, size):
        X, Z = self.pixel_grid(size)
        splat = self.splat_rgba.astype(np.float64) / 255.0
        out = {}
        for i, k in enumerate(["dirt", "rock", "ash", "forest"]):
            out[k] = bilinear(splat[..., i], self.S, X, Z)
        return out


def load_layout(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

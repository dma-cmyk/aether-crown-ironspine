# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pillow"]
# ///
"""Tileable creature surfaces: hide, scales, fur and feathers (albedo, normal, ORM).

The albedo stays pale and nearly grey: creature colours come from vertex paint, so one
texture set serves every creature and both teams.

Run: uv run tools/textures/creature_textures.py
Output: game/assets/textures/creature_<name>_{albedo,normal,orm}.png (512 px)
"""
import pathlib

import numpy as np
from PIL import Image

N = 512
OUT = pathlib.Path(__file__).resolve().parents[2] / "game" / "assets" / "textures"
rng = np.random.default_rng(7)
U, V = np.meshgrid(np.arange(N) / N, np.arange(N) / N)


def value_noise(cells, seed):
    """Periodic smooth noise in [0, 1] with `cells` lattice cells across the tile."""
    g = np.random.default_rng(seed).random((cells, cells))
    x = U * cells
    y = V * cells
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = x - x0
    fy = y - y0
    sx = fx * fx * (3 - 2 * fx)
    sy = fy * fy * (3 - 2 * fy)
    x0 %= cells
    y0 %= cells
    x1 = (x0 + 1) % cells
    y1 = (y0 + 1) % cells
    a = g[y0, x0] * (1 - sx) + g[y0, x1] * sx
    b = g[y1, x0] * (1 - sx) + g[y1, x1] * sx
    return a * (1 - sy) + b * sy


def fbm(cells, octaves, seed, gain=0.5):
    out = np.zeros((N, N))
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        out += value_noise(cells * 2 ** o, seed + o * 17) * amp
        total += amp
        amp *= gain
    return out / total


def blur(h, r):
    """Cheap periodic box blur (three passes ~ gaussian)."""
    out = h
    for _ in range(3):
        acc = np.zeros_like(out)
        for d in range(-r, r + 1):
            acc += np.roll(out, d, axis=1)
        out = acc / (2 * r + 1)
        acc = np.zeros_like(out)
        for d in range(-r, r + 1):
            acc += np.roll(out, d, axis=0)
        out = acc / (2 * r + 1)
    return out


def normal_map(h, strength):
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * N / 64.0
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * N / 64.0
    n = np.stack([-dx * strength, dy * strength, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def cavity(h, r=6, k=4.0):
    return np.clip(1.0 + (h - blur(h, r)) * k, 0.0, 1.0)


def value_noise2(cx, cy, seed):
    """Periodic smooth noise with separate lattice counts across (cx) and down (cy)."""
    g = np.random.default_rng(seed).random((cy, cx))
    x = U * cx
    y = V * cy
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = x - x0
    fy = y - y0
    sx = fx * fx * (3 - 2 * fx)
    sy = fy * fy * (3 - 2 * fy)
    x0 %= cx
    y0 %= cy
    x1 = (x0 + 1) % cx
    y1 = (y0 + 1) % cy
    a = g[y0, x0] * (1 - sx) + g[y0, x1] * sx
    b = g[y1, x0] * (1 - sx) + g[y1, x1] * sx
    return a * (1 - sy) + b * sy


def shingles(cols, rows, rx, ry, seed, lift=1.4):
    """Overlapping rounded scales on a staggered grid; each row covers the top of the next.

    Returns (height 0..1 rising toward each free edge, per-scale random id, local x, local y)."""
    r = np.random.default_rng(seed).random((rows, cols))
    x = U * cols
    y = V * rows
    h = np.zeros((N, N))
    ident = np.zeros((N, N))
    lxo = np.zeros((N, N))
    lyo = np.zeros((N, N))
    done = np.zeros((N, N), dtype=bool)
    base = np.floor(y).astype(int)
    # top-most row first: it lies over the rows below it
    for dr in (-1, 0, 1, 2):
        row = base + dr - 1
        off = np.where(row % 2 == 0, 0.0, 0.5)
        col0 = np.floor(x - off + 0.5).astype(int)
        for dc in (-1, 0, 1):
            c = col0 + dc
            lx = (x - (c + off)) / rx
            ly = (y - (row + 0.5)) / ry
            d2 = lx * lx + ly * ly
            inside = (d2 < 1.0) & ~done
            t = np.clip((ly + 1.0) * 0.5, 0.0, 1.0) ** lift
            rim = np.clip((1.0 - np.sqrt(np.clip(d2, 0, 1))) / 0.12, 0.0, 1.0)
            val = t * (0.35 + 0.65 * rim) + 0.25 * np.sqrt(np.clip(1.0 - lx * lx, 0, 1))
            h = np.where(inside, val, h)
            ident = np.where(inside, r[row % rows, c % cols], ident)
            lxo = np.where(inside, lx, lxo)
            lyo = np.where(inside, ly, lyo)
            done |= inside
    return h / h.max(), ident, lxo, lyo


def save(name, albedo, normal, orm):
    OUT.mkdir(parents=True, exist_ok=True)
    for kind, img in (("albedo", albedo), ("normal", normal), ("orm", orm)):
        a = np.clip(img, 0.0, 1.0)
        Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGB").save(OUT / ("creature_%s_%s.png" % (name, kind)))
    print("creature_%s" % name)


def rgb(gray, tint=(1.0, 1.0, 1.0)):
    return np.stack([gray * tint[0], gray * tint[1], gray * tint[2]], axis=-1)


def orm(ao, rough, metal=0.0):
    return np.stack([ao, rough, np.full_like(ao, metal)], axis=-1)


def hide():
    folds = 1.0 - np.abs(fbm(12, 3, 11) * 2.0 - 1.0)
    folds = folds ** 3.0
    pores = fbm(96, 2, 23)
    h = folds * 0.55 + pores * 0.45
    cav = cavity(h, 4, 2.5)
    blotch = fbm(4, 3, 31)
    albedo = rgb(0.74 + 0.18 * blotch + 0.08 * (cav - 0.5))
    save("hide", albedo, normal_map(h, 1.6), orm(0.65 + 0.35 * cav, 0.7 + 0.2 * (1 - cav)))


def scales():
    h, ident, _lx, _ly = shingles(9, 11, 0.62, 0.78, 5)
    grain = fbm(48, 2, 41)
    hh = h + grain * 0.05
    cav = cavity(hh, 4, 4.0)
    albedo = rgb(0.62 + 0.2 * ident + 0.25 * h - 0.08 * (1 - cav))
    save("scales", albedo, normal_map(hh, 4.0), orm(0.4 + 0.6 * cav, 0.38 + 0.3 * (1 - h)))


def fur():
    strands = np.zeros((N, N))
    amp = 1.0
    for k, (cx, cy) in enumerate(((48, 4), (96, 6), (192, 8), (384, 12))):
        strands += value_noise2(cx, cy, 50 + k) * amp
        amp *= 0.7
    strands /= 1.0 + 0.7 + 0.49 + 0.343
    clumps = value_noise2(12, 3, 61)
    h = strands * 0.75 + clumps * 0.25
    cav = cavity(h, 3, 3.5)
    albedo = rgb(0.6 + 0.35 * strands + 0.1 * clumps)
    save("fur", albedo, normal_map(h, 2.4), orm(0.5 + 0.5 * cav, 0.85 + 0.1 * (1 - cav)))


def feather():
    h, ident, lx, ly = shingles(8, 4, 0.5, 1.2, 9, lift=0.8)
    shaft = np.clip(1.0 - np.abs(lx) / 0.07, 0.0, 1.0)
    barbs = 0.5 + 0.5 * np.sin((np.abs(lx) * 9.0 - ly * 5.0) * np.pi * 2)
    hh = h * 0.75 + shaft * 0.12 + barbs * 0.06 * (1.0 - shaft)
    cav = cavity(hh, 4, 4.0)
    albedo = rgb(0.7 + 0.18 * ident + 0.12 * h - 0.06 * barbs + 0.1 * shaft)
    save("feather", albedo, normal_map(hh, 3.2), orm(0.45 + 0.55 * cav, 0.72 + 0.15 * (1 - h)))


if __name__ == "__main__":
    hide()
    scales()
    fur()
    feather()

"""Reusable architectural / mechanical parts built on mk.Builder (Godot space)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mk  # noqa: E402


def ring_points(r, n, phase=0.0):
    return [(math.cos(phase + i / n * math.tau) * r, math.sin(phase + i / n * math.tau) * r) for i in range(n)]


def round_tower(b, P, x, z, r, h, roof_h=0.0, seg=10, y0=0.0, crenel=True, roof="cone", wall="stone"):
    """Tower with optional crenellated parapet and a conical roof."""
    b.lathe([(r * 1.12, y0), (r, y0 + 1.0), (r, y0 + h)], seg, (x, 0, z), P[wall], smooth=False)
    b.cylinder(r * 1.12, 0.5, seg, (x, y0 + h * 0.62, z), P["stone_trim"])
    top = y0 + h
    if crenel:
        b.lathe([(r * 1.16, top), (r * 1.16, top + 0.7)], seg, (x, 0, z), P["stone_trim"], smooth=False)
        for (cx, cz) in ring_points(r * 1.1, seg, 0.3):
            b.box((0.7, 0.8, 0.7), (x + cx, top + 1.1, z + cz), P["stone_trim"])
    if roof == "cone" and roof_h > 0:
        b.cylinder(r * 1.05, roof_h, seg, (x, top + (0.7 if crenel else 0.0), z), P["roof"], r2=0.0)
        b.cylinder(0.08, 1.6, 4, (x, top + roof_h + 0.5, z), P["brass"])
    elif roof == "spire" and roof_h > 0:
        b.cylinder(r * 0.8, roof_h, seg, (x, top + 0.7, z), P["roof"], r2=0.0)
        b.cylinder(r * 0.35, roof_h * 0.35, seg, (x, top + 0.7 + roof_h * 0.6, z), P["brass"], r2=0.0)
    # arrow slits / windows
    for i in range(3):
        a = (i / 3) * math.tau + 0.4
        wy = y0 + h * (0.35 + 0.2 * i)
        b.box((0.35, 1.1, 0.2), (x + math.cos(a) * r * 1.0, wy, z + math.sin(a) * r * 1.0), P["window_glow"],
              rot=(0, -math.degrees(a) + 90, 0))
    return top


def square_tower(b, P, x, z, w, h, roof_h=0.0, rot=0.0, wall="stone", roof="roof"):
    b.box((w + 0.5, 1.0, w + 0.5), (x, 0.5, z), P["stone_dark"], rot=(0, rot, 0))
    b.box((w, h, w), (x, h / 2, z), P[wall], rot=(0, rot, 0), bevel=0.06)
    b.box((w + 0.35, 0.45, w + 0.35), (x, h - 0.2, z), P["stone_trim"], rot=(0, rot, 0))
    if roof_h > 0:
        b.cylinder(w * 0.78, roof_h, 4, (x, h, z), P[roof], rot=(0, 45 + rot, 0), r2=0.0)
    return h


def crenel_wall(b, P, length, thick, h, loc=(0, 0, 0), rot=0.0, m="stone", merlon_step=1.8):
    """Straight wall centred on loc, running along local X."""
    x0, y0, z0 = loc
    ca = math.cos(math.radians(rot))
    sa = math.sin(math.radians(rot))

    def tr(lx, lz):
        return (x0 + lx * ca + lz * sa, z0 - lx * sa + lz * ca)

    b.box((length, h, thick), (x0, y0 + h / 2, z0), P[m], rot=(0, rot, 0), taper=(1.0, 0.9))
    b.box((length + 0.2, 0.35, thick + 0.25), (x0, y0 + h - 0.1, z0), P["stone_trim"], rot=(0, rot, 0))
    n = max(1, int(length / merlon_step))
    for i in range(n):
        lx = -length / 2 + (i + 0.5) * length / n
        for side in (-1, 1):
            px, pz = tr(lx, side * (thick / 2 - 0.2))
            b.box((0.8, 0.8, 0.35), (px, y0 + h + 0.35, pz), P["stone_trim"], rot=(0, rot, 0))


def banner(b, P, x, y, z, w=1.2, h=3.2, rot=0.0, pole=True):
    """Hanging team banner facing +Z (after rot)."""
    if pole:
        b.box((w + 0.4, 0.12, 0.12), (x, y + 0.1, z), P["brass"], rot=(0, rot, 0))
    pts = [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, -h + 0.5), (0.0, -h), (-w / 2, -h + 0.5)]
    b.side_profile(pts, 0.06, (x, y, z), P["team_cloth"], rot=(0, rot, 0))
    b.box((w * 0.45, w * 0.45, 0.08), (x, y - h * 0.42, z), P["brass"], rot=(0, rot, 45))


def gable_house(b, P, x, z, w, d, h, roof_h, rot=0.0, wall="plaster", roof="roof", chimney=True, windows=True):
    """House footprint w (x) by d (z), walls h, roof ridge along z."""
    ca = math.cos(math.radians(rot))
    sa = math.sin(math.radians(rot))

    def tr(lx, lz):
        return (x + lx * ca + lz * sa, z - lx * sa + lz * ca)

    b.box((w + 0.4, 0.8, d + 0.4), (x, 0.3, z), P["stone_dark"], rot=(0, rot, 0))
    b.box((w, h, d), (x, h / 2 + 0.6, z), P[wall], rot=(0, rot, 0))
    # timber corner posts
    for sx in (-1, 1):
        for sz in (-1, 1):
            px, pz = tr(sx * (w / 2 + 0.02), sz * (d / 2 + 0.02))
            b.box((0.28, h, 0.28), (px, h / 2 + 0.6, pz), P["wood"], rot=(0, rot, 0))
    px, pz = tr(0, 0)
    b.box((w + 0.1, 0.25, d + 0.1), (px, h * 0.55 + 0.6, pz), P["wood"], rot=(0, rot, 0))
    # gable ends
    b.side_profile([(-w / 2, 0.0), (w / 2, 0.0), (0.0, roof_h)], d, (x, h + 0.6, z), P[wall], rot=(0, rot, 0))
    b.gable_roof(w, d, roof_h + 0.15, (x, h + 0.55, z), P[roof], rot=(0, rot, 0), overhang=0.45)
    if chimney:
        cx, cz = tr(w * 0.25, -d * 0.2)
        b.box((0.8, roof_h + 1.4, 0.8), (cx, h + 0.6 + (roof_h + 1.4) / 2, cz), P["stone"], rot=(0, rot, 0))
    if windows:
        for i in range(max(1, int(d / 2.6))):
            lz = -d / 2 + (i + 0.5) * d / max(1, int(d / 2.6))
            for sx in (-1, 1):
                for fy in (0.35, 0.72):
                    wx, wz = tr(sx * (w / 2 + 0.03), lz)
                    b.box((0.12, 0.9, 0.6), (wx, 0.6 + h * fy, wz), P["window_glow"], rot=(0, rot, 0))
        for sz in (-1, 1):
            wx, wz = tr(0, sz * (d / 2 + 0.03))
            b.box((0.7, 0.9, 0.12), (wx, 0.6 + h * 0.72, wz), P["window_glow"], rot=(0, rot, 0))
        dx, dz = tr(0, d / 2 + 0.05)
        b.box((1.1, 1.9, 0.14), (dx, 1.55, dz), P["wood"], rot=(0, rot, 0))


def pipe_run(b, P, pts, r=0.25, m="copper", seg=6):
    """Pipe through a list of (x, y, z) points with joint rings."""
    for a, c in zip(pts[:-1], pts[1:]):
        dx, dy, dz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
        L = math.sqrt(dx * dx + dy * dy + dz * dz)
        if L < 1e-4:
            continue
        # orient a Y-up cylinder along (dx, dy, dz)
        yaw = math.degrees(math.atan2(dx, dz))
        pitch = math.degrees(math.acos(max(-1.0, min(1.0, dy / L))))
        b.cylinder(r, L, seg, a, P[m], rot=(pitch, yaw, 0))
        b.cylinder(r * 1.35, 0.25, seg, (a[0], a[1], a[2]), P["brass"], rot=(pitch, yaw, 0))


def chimney_stack(b, P, x, z, r, h, y0=0.0, m="plaster"):
    b.lathe([(r * 1.3, y0), (r * 1.3, y0 + 2.0), (r, y0 + 2.4), (r * 0.82, y0 + h), (r * 1.0, y0 + h + 0.2), (r, y0 + h + 0.9), (r * 0.7, y0 + h + 0.9)],
            10, (x, 0, z), P[m], smooth=False)
    for k in range(3):
        yy = y0 + 3.0 + (h - 4.0) * (k + 1) / 4
        rr = r * (1.0 - 0.18 * (yy - y0) / h) + 0.12
        b.cylinder(rr, 0.35, 10, (x, yy, z), P["iron"])
    b.cylinder(r * 0.66, 0.3, 10, (x, y0 + h + 0.7, z), P["fire_glow"])


def gear_wheel(b, P, x, y, z, r, thick=0.4, teeth=14, rot=(90, 0, 0), m="brass"):
    b.gear(r, thick, teeth, (x, y, z), P[m], rot=rot)
    b.cylinder(r * 0.28, thick * 1.6, 8, (x, y, z), P["iron_dark"], rot=rot)


def jitter_verts(faces, amount, seed=1):
    rnd = random.Random(seed)
    seen = set()
    for f in faces:
        for v in f.verts:
            if v in seen:
                continue
            seen.add(v)
            v.co.x += rnd.uniform(-amount, amount)
            v.co.y += rnd.uniform(-amount, amount) * 0.6
            v.co.z += rnd.uniform(-amount, amount)

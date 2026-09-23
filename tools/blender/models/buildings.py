"""Gameplay buildings. Models face +Z (Godot), origin at ground centre.

Run: blender --background --factory-startup --python tools/blender/models/buildings.py [-- name ...]
Separate child objects named turret* rotate in game; beacon uses team_glow.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import mk  # noqa: E402
import parts  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models")
BLEND = os.path.join(ROOT, "art", "blend", "buildings")


def plinth(b, P, w, d, h=1.2):
    b.box((w, h, d), (0, h / 2 - 0.4, 0), P["stone_dark"], bevel=0.12)
    b.box((w - 1.0, 0.3, d - 1.0), (0, h - 0.3, 0), P["paving"])
    return h - 0.2


def window_rows(b, P, x0, x1, y, z, n, face_x=False, h=1.6, w=0.55):
    for i in range(n):
        t = (i + 0.5) / n
        if face_x:
            b.box((0.14, h, w), (x0, y, x1 + (z - x1) * t), P["window_glow"])
        else:
            b.box((w, h, 0.14), (x0 + (x1 - x0) * t, y, z), P["window_glow"])


def cannon_turret(name, P, parent, pivot, barrel=4.6, r=2.2, double=False):
    t = mk.Builder(name)
    t.cylinder(r, 1.0, 10, (0, 0, 0), P["iron"])
    t.cylinder(r * 1.05, 0.25, 10, (0, 0.9, 0), P["brass"])
    t.box((r * 1.3, 1.5, r * 0.9), (0, 1.6, -0.3), P["iron_dark"], bevel=0.08)
    xs = (-0.55, 0.55) if double else (0.0,)
    for x in xs:
        t.cylinder(0.34, barrel, 8, (x, 1.7, 0.2), P["iron"], rot=(90, 0, 0), r2=0.28)
        t.cylinder(0.42, 0.5, 8, (x, 1.7, 0.2 + barrel - 0.4), P["brass"], rot=(90, 0, 0))
    t.box((r * 1.5, 0.9, 0.25), (0, 1.3, r * 0.55), P["team_trim"])
    return _place(t.to_object(parent=parent), pivot)


def _place(ob, pivot):
    ob.location = mk.gpos(*pivot)
    return ob


# ---------------------------------------------------------------------------
def citadel(name):
    P = mk.palette()
    b = mk.Builder(name)
    y0 = plinth(b, P, 27, 27, 1.8)
    # keep
    b.box((15, 12, 15), (0, y0 + 6, 0), P["stone"], bevel=0.12)
    b.box((15.8, 0.7, 15.8), (0, y0 + 12.1, 0), P["stone_trim"])
    for side in range(4):
        rot = side * 90
        for k in (-4.2, 0.0, 4.2):
            ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
            lx, lz = k, 7.9
            x, z = lx * ca + lz * sa, -lx * sa + lz * ca
            b.box((1.3, 10.5, 1.4), (x, y0 + 5.2, z), P["stone"], rot=(0, rot, 0), taper=(0.85, 0.55))
    for (sx, sz) in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        for i in range(5):
            t = -6 + i * 3
            if sx == 0:
                b.box((0.7, 2.0, 0.15), (t, y0 + 8.4, sz * 7.56), P["window_glow"])
            else:
                b.box((0.15, 2.0, 0.7), (sx * 7.56, y0 + 8.4, t), P["window_glow"])
    parts.crenel_wall(b, P, 15.4, 1.0, 0.1, (0, y0 + 12.4, 7.2))
    parts.crenel_wall(b, P, 15.4, 1.0, 0.1, (0, y0 + 12.4, -7.2))
    parts.crenel_wall(b, P, 15.4, 1.0, 0.1, (7.2, y0 + 12.4, 0), rot=90)
    parts.crenel_wall(b, P, 15.4, 1.0, 0.1, (-7.2, y0 + 12.4, 0), rot=90)
    # great tower
    ty = y0 + 12.4
    b.lathe([(5.0, ty), (4.3, ty + 1.2), (4.0, ty + 11.0), (4.6, ty + 11.6), (4.6, ty + 12.4), (3.2, ty + 12.4)], 12,
            (0, 0, 0), P["stone"], smooth=False)
    b.cylinder(4.2, 0.6, 12, (0, ty + 5.5, 0), P["stone_trim"])
    for i in range(6):
        a = i / 6 * math.tau
        b.box((0.6, 2.4, 0.2), (math.cos(a) * 4.05, ty + 8.0, math.sin(a) * 4.05), P["window_glow"],
              rot=(0, 90 - math.degrees(a), 0))
    # aether core cage
    cy = ty + 12.4
    for i in range(6):
        a = i / 6 * math.tau + 0.26
        b.box((0.35, 6.2, 0.35), (math.cos(a) * 2.9, cy + 3.0, math.sin(a) * 2.9), P["brass"])
    b.torus(3.0, 0.22, 16, 5, (0, cy + 0.4, 0), P["brass"])
    b.torus(3.0, 0.22, 16, 5, (0, cy + 6.0, 0), P["brass"])
    b.lathe([(0.0, cy + 0.6), (1.7, cy + 2.4), (1.4, cy + 4.3), (0.0, cy + 6.0)], 8, (0, 0, 0), P["team_glow"], smooth=False)
    b.cylinder(3.6, 9.5, 12, (0, cy + 6.2, 0), P["roof"], r2=0.0)
    b.cylinder(0.12, 3.0, 5, (0, cy + 15.3, 0), P["brass"])
    b.sphere(0.45, 8, 5, (0, cy + 18.4, 0), P["brass"])
    # corner towers
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.round_tower(b, P, sx * 8.4, sz * 8.4, 2.9, 17.5 - y0, roof_h=7.0, seg=10, y0=y0)
    # front gate
    b.box((6.0, 8.0, 1.4), (0, y0 + 4.0, 7.9), P["stone_trim"])
    b.box((3.8, 5.6, 0.3), (0, y0 + 2.8, 8.65), P["iron_dark"])
    b.box((4.2, 0.5, 0.5), (0, y0 + 5.8, 8.7), P["brass"])
    parts.banner(b, P, -4.2, y0 + 10.5, 8.75, 1.8, 7.0)
    parts.banner(b, P, 4.2, y0 + 10.5, 8.75, 1.8, 7.0)
    parts.banner(b, P, -9.2, y0 + 12.5, 11.2, 1.3, 4.5)
    parts.banner(b, P, 9.2, y0 + 12.5, 11.2, 1.3, 4.5)
    # industry at the back
    parts.chimney_stack(b, P, -4.5, -11.0, 1.2, 17.0, y0=y0, m="stone")
    parts.chimney_stack(b, P, 4.5, -11.0, 1.2, 15.0, y0=y0, m="stone")
    parts.pipe_run(b, P, [(-4.5, y0 + 3.0, -9.5), (-4.5, y0 + 3.0, -7.6)], 0.4)
    parts.pipe_run(b, P, [(4.5, y0 + 3.0, -9.5), (4.5, y0 + 3.0, -7.6)], 0.4)
    # steps
    for i in range(3):
        b.box((7.0 - i, 0.4, 1.2), (0, 0.2 + i * 0.4, 13.2 - i * 1.0), P["stone_trim"])
    ob = b.to_object()
    cannon_turret("turret", P, ob, (0, y0 + 12.5, 5.0), barrel=3.4, r=1.6)
    return ob


def barracks(name):
    P = mk.palette()
    b = mk.Builder(name)
    y0 = plinth(b, P, 14, 19, 1.0)
    w, d, h = 10.0, 15.0, 7.0
    b.box((w, h, d), (0, y0 + h / 2, -1.0), P["stone"], bevel=0.1)
    for i in range(5):
        z = -1.0 - d / 2 + 1.5 + i * (d - 3.0) / 4
        for sx in (-1, 1):
            b.box((1.0, h - 0.8, 1.1), (sx * (w / 2 + 0.5), y0 + (h - 0.8) / 2, z), P["stone"], taper=(0.6, 0.8))
            if i < 4:
                b.box((0.14, 2.6, 0.9), (sx * (w / 2 + 0.03), y0 + 4.2, z + (d - 3.0) / 8), P["window_glow"])
    b.side_profile([(-w / 2, 0.0), (w / 2, 0.0), (0.0, 5.5)], d, (0, y0 + h, -1.0), P["stone"])
    b.gable_roof(w, d, 5.7, (0, y0 + h - 0.05, -1.0), P["roof"], overhang=0.6)
    # bell tower at the front
    tz = 7.4
    b.box((4.6, 15.0, 4.6), (0, y0 + 7.5, tz), P["stone"], bevel=0.1)
    b.box((5.2, 0.6, 5.2), (0, y0 + 11.0, tz), P["stone_trim"])
    b.box((5.2, 0.6, 5.2), (0, y0 + 15.0, tz), P["stone_trim"])
    for (x, z) in ((0, tz + 2.33), (0, tz - 2.33), (2.33, tz), (-2.33, tz)):
        b.box((1.2 if x == 0 else 0.12, 2.2, 0.12 if x == 0 else 1.2), (x, y0 + 13.0, z), P["window_glow"])
    b.cylinder(3.6, 8.0, 4, (0, y0 + 15.3, tz), P["roof"], rot=(0, 45, 0), r2=0.0)
    b.cylinder(0.1, 2.4, 5, (0, y0 + 23.0, tz), P["brass"])
    b.box((2.8, 4.0, 0.4), (0, y0 + 2.0, tz + 2.35), P["wood"])
    b.box((3.2, 0.4, 0.5), (0, y0 + 4.2, tz + 2.4), P["brass"])
    parts.banner(b, P, -3.4, y0 + 9.0, tz + 1.2, 1.4, 5.0)
    parts.banner(b, P, 3.4, y0 + 9.0, tz + 1.2, 1.4, 5.0)
    # weapon racks
    for x in (-5.8, 5.8):
        b.box((0.3, 1.8, 3.0), (x, y0 + 0.9, 6.5), P["wood"])
        for k in range(4):
            b.cylinder(0.05, 2.0, 4, (x, y0 + 0.2, 5.3 + k * 0.8), P["iron"], rot=(0, 0, 8))
    return b.to_object()


def foundry(name):
    P = mk.palette()
    b = mk.Builder(name)
    y0 = plinth(b, P, 21, 21, 1.0)
    w, d, h = 16.0, 13.0, 9.0
    b.box((w, h, d), (0, y0 + h / 2, -1.5), P["plaster"], bevel=0.1)
    b.box((w + 0.5, 0.6, d + 0.5), (0, y0 + h, -1.5), P["stone_trim"])
    for i in range(3):
        z = -1.5 - d / 2 + (i + 0.5) * d / 3
        b.side_profile([(-w / 2 - 0.3, 0), (w / 2 + 0.3, 0), (w / 2 + 0.3, 0.3), (-w / 2 - 0.3, 3.4)], d / 3 - 0.15,
                       (0, y0 + h + 0.2, z), P["roof"], rot=(0, 90, 0))
        b.box((w - 0.6, 2.2, 0.15), (0, y0 + h + 1.6, z - d / 6 + 0.2), P["window_glow"])
    # furnace mouth
    b.box((6.5, 6.5, 0.6), (0, y0 + 3.25, 5.2), P["stone_dark"])
    b.box((5.0, 5.0, 0.3), (0, y0 + 2.6, 5.4), P["fire_glow"])
    b.box((7.0, 0.7, 0.9), (0, y0 + 6.6, 5.4), P["brass"])
    parts.gear_wheel(b, P, 0, y0 + 10.4, 5.2, 2.6, thick=0.5, teeth=16, rot=(90, 0, 0))
    parts.gear_wheel(b, P, 3.6, y0 + 8.9, 5.3, 1.3, thick=0.4, teeth=10, rot=(90, 0, 0), m="copper")
    for sx in (-1, 1):
        for z in (-5.0, -1.0, 3.0):
            b.box((0.14, 2.4, 1.6), (sx * (w / 2 + 0.03), y0 + 4.6, z), P["window_glow"])
    parts.chimney_stack(b, P, -5.5, -9.8, 1.6, 22.0, y0=y0, m="stone")
    parts.chimney_stack(b, P, 5.5, -9.8, 1.6, 19.0, y0=y0, m="stone")
    # crane
    b.box((0.8, 12.0, 0.8), (9.2, y0 + 6.0, 5.8), P["iron"])
    b.box((0.6, 0.6, 9.0), (9.2, y0 + 12.0, 2.0), P["iron"], rot=(0, -20, 0))
    b.box((0.08, 5.0, 0.08), (7.8, y0 + 9.5, -1.2), P["iron_dark"])
    b.box((1.2, 1.2, 1.2), (7.8, y0 + 6.8, -1.2), P["brass"])
    parts.pipe_run(b, P, [(-w / 2 - 0.5, y0 + 1.0, 4.0), (-w / 2 - 0.5, y0 + 7.0, 4.0), (-w / 2 - 0.5, y0 + 7.0, -6.0),
                          (-5.5, y0 + 7.0, -8.2)], 0.45)
    parts.banner(b, P, -5.0, y0 + 8.2, 5.25, 1.4, 4.6)
    parts.banner(b, P, 5.0, y0 + 8.2, 5.25, 1.4, 4.6)
    return b.to_object()


def skyport(name):
    P = mk.palette()
    b = mk.Builder(name)
    y0 = plinth(b, P, 18, 18, 1.0)
    # hangar
    w, d, h = 10.0, 11.0, 5.0
    b.box((w, h, d), (0, y0 + h / 2, 2.0), P["stone"])
    prof = [(math.cos(t) * (w / 2 + 0.3), math.sin(t) * 3.4) for t in [i / 12 * math.pi for i in range(13)]]
    b.side_profile(prof, d + 0.4, (0, y0 + h, 2.0), P["roof_copper"])
    b.box((6.0, 4.4, 0.3), (0, y0 + 2.2, 7.6), P["iron_dark"])
    # lattice mast
    mz = -5.0
    top = y0 + 25.0
    for (sx, sz) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        parts.pipe_run(b, P, [(sx * 2.6, y0, mz + sz * 2.6), (sx * 1.0, top, mz + sz * 1.0)], 0.28, m="brass")
    for k in range(6):
        yy = y0 + 3.0 + k * 3.8
        rr = 2.6 - (2.6 - 1.0) * (yy - y0) / 25.0
        b.box((rr * 2 + 0.3, 0.3, 0.3), (0, yy, mz + rr), P["iron"])
        b.box((rr * 2 + 0.3, 0.3, 0.3), (0, yy, mz - rr), P["iron"])
        b.box((0.3, 0.3, rr * 2 + 0.3), (rr, yy, mz), P["iron"])
        b.box((0.3, 0.3, rr * 2 + 0.3), (-rr, yy, mz), P["iron"])
    b.cylinder(4.0, 0.6, 14, (0, top, mz), P["iron"])
    b.torus(4.0, 0.25, 16, 5, (0, top + 0.6, mz), P["brass"])
    b.cylinder(1.0, 3.0, 8, (0, top + 0.6, mz), P["stone_trim"], r2=0.4)
    b.lathe([(0.0, top + 3.4), (0.8, top + 4.4), (0.0, top + 6.2)], 6, (0, 0, mz), P["team_glow"], smooth=False)
    # docking arm
    b.box((0.6, 0.6, 9.0), (0, top - 1.0, mz + 5.5), P["iron"])
    b.box((1.4, 1.4, 1.4), (0, top - 1.8, mz + 10.0), P["brass"])
    parts.banner(b, P, -3.2, y0 + 12.0, mz + 2.2, 1.2, 4.0)
    return b.to_object()


def refinery(name):
    P = mk.palette()
    b = mk.Builder(name)
    y0 = plinth(b, P, 13, 13, 1.0)
    b.lathe([(5.0, y0), (5.0, y0 + 1.6), (4.2, y0 + 2.2), (3.2, y0 + 2.2)], 12, (0, 0, 0), P["stone"], smooth=False)
    b.lathe([(0.0, y0 + 2.2), (2.1, y0 + 2.6), (2.1, y0 + 8.4), (0.0, y0 + 9.0)], 10, (0, 0, 0), P["aether"], smooth=True)
    for i in range(6):
        a = i / 6 * math.tau
        b.box((0.3, 7.6, 0.3), (math.cos(a) * 2.5, y0 + 5.8, math.sin(a) * 2.5), P["brass"])
    for yy in (y0 + 2.6, y0 + 5.6, y0 + 8.6):
        b.torus(2.5, 0.18, 14, 4, (0, yy, 0), P["brass"])
    b.lathe([(2.8, y0 + 9.0), (2.6, y0 + 10.0), (1.4, y0 + 11.6), (0.0, y0 + 12.0)], 12, (0, 0, 0), P["roof_copper"])
    b.cylinder(0.12, 2.0, 5, (0, y0 + 11.8, 0), P["brass"])
    for (x, z) in ((-4.0, -2.5), (4.0, -2.5)):
        b.lathe([(1.2, y0), (1.2, y0 + 3.8), (0.8, y0 + 4.4), (0.0, y0 + 4.6)], 10, (x, 0, z), P["copper"])
        parts.pipe_run(b, P, [(x, y0 + 3.0, z), (x * 0.5, y0 + 3.0, z * 0.5), (x * 0.3, y0 + 4.5, z * 0.3)], 0.22)
    parts.banner(b, P, 0, y0 + 7.0, 3.1, 1.0, 3.2, pole=True)
    return b.to_object()


def habitat(name):
    P = mk.palette()
    b = mk.Builder(name)
    y0 = plinth(b, P, 13, 13, 0.8)
    parts.gable_house(b, P, -3.2, -1.5, 5.0, 8.0, 7.5, 3.4, rot=0)
    parts.gable_house(b, P, 3.2, -2.5, 5.0, 6.5, 6.0, 3.0, rot=0)
    parts.round_tower(b, P, 3.6, 3.3, 1.6, 10.0, roof_h=4.0, seg=8, crenel=False)
    parts.banner(b, P, -3.2, 6.8, 2.6, 1.0, 2.8)
    return b.to_object()


def bastion(name):
    P = mk.palette()
    b = mk.Builder(name)
    b.lathe([(4.4, -0.4), (4.4, 0.6), (3.6, 1.2), (3.4, 8.0), (3.9, 8.4), (3.9, 9.0), (3.0, 9.0)], 10, (0, 0, 0),
            P["stone"], smooth=False)
    for (cx, cz) in parts.ring_points(3.7, 10, 0.3):
        b.box((0.9, 1.1, 0.7), (cx, 9.5, cz), P["stone_trim"])
    b.cylinder(3.5, 0.5, 10, (0, 4.2, 0), P["stone_trim"])
    for i in range(3):
        a = i / 3 * math.tau + 0.5
        b.box((0.5, 1.6, 0.2), (math.cos(a) * 3.45, 6.0, math.sin(a) * 3.45), P["window_glow"], rot=(0, 90 - math.degrees(a), 0))
    parts.banner(b, P, 0, 7.6, 3.55, 1.2, 3.6)
    ob = b.to_object()
    cannon_turret("turret", P, ob, (0, 9.0, 0), barrel=4.8, r=2.2, double=True)
    return ob


def gate(name):
    P = mk.palette()
    b = mk.Builder(name)
    # arch block spanning the road (road runs along Z)
    arch = [(-5.0, 16.0), (-5.0, -1.0), (-4.2, -1.0), (-4.2, 6.5)]
    for i in range(1, 16):
        t = math.pi - i / 16 * math.pi
        arch.append((math.cos(t) * 4.2, 6.5 + math.sin(t) * 4.2))
    arch += [(4.2, 6.5), (4.2, -1.0), (5.0, -1.0), (5.0, 16.0)]
    b.side_profile(arch, 7.0, (0, 0, 0), P["stone"])
    b.box((10.6, 0.6, 7.6), (0, 16.1, 0), P["stone_trim"])
    parts.crenel_wall(b, P, 10.0, 7.0, 0.1, (0, 16.3, 0))
    # portcullis
    for i in range(7):
        b.box((0.18, 3.2, 0.18), (-3.0 + i, 9.4, 2.6), P["iron_dark"])
    b.box((7.0, 0.25, 0.2), (0, 8.4, 2.6), P["iron_dark"])
    # flanking towers
    for sx in (-1, 1):
        x = sx * 9.0
        b.box((9.5, 1.2, 9.5), (x, -0.2, 0), P["stone_dark"])
        b.box((8.6, 20.0, 8.6), (x, 9.5, 0), P["stone"], bevel=0.12, taper=(0.93, 0.93))
        b.box((9.4, 0.8, 9.4), (x, 19.8, 0), P["stone_trim"])
        parts.crenel_wall(b, P, 9.0, 9.0, 0.1, (x, 20.2, 0))
        for yy in (6.0, 11.0, 15.5):
            b.box((0.8, 2.2, 0.15), (x, yy, 4.35), P["window_glow"])
            b.box((0.15, 2.2, 0.8), (x + sx * 4.35, yy, 0), P["window_glow"])
        parts.banner(b, P, x, 18.6, 4.45, 3.0, 11.0)
        # wall stubs
        b.box((9.0, 11.0, 3.0), (sx * 17.0, 4.5, -1.0), P["stone"], taper=(1.0, 0.85))
        parts.crenel_wall(b, P, 9.0, 3.0, 0.1, (sx * 17.0, 10.0, -1.0))
        b.box((1.1, 1.4, 1.1), (sx * 5.6, 17.4, 3.6), P["fire_glow"])
    # crest over the arch
    b.box((3.4, 3.4, 0.5), (0, 13.0, 3.6), P["brass"], rot=(0, 0, 45))
    b.box((2.2, 2.2, 0.6), (0, 13.0, 3.8), P["team_glow"], rot=(0, 0, 45))
    ob = b.to_object()
    cannon_turret("turret_l", P, ob, (-9.0, 20.6, 0.5), barrel=4.4, r=2.0)
    cannon_turret("turret_r", P, ob, (9.0, 20.6, 0.5), barrel=4.4, r=2.0)
    return ob


def relay(name):
    P = mk.palette()
    b = mk.Builder(name)
    b.lathe([(5.2, -0.5), (5.2, 0.7), (4.6, 1.2), (1.9, 1.2)], 6, (0, 0, 0), P["stone"], smooth=False)
    b.lathe([(1.9, 1.2), (1.6, 4.2), (2.0, 4.6), (2.0, 5.0), (1.2, 5.0)], 8, (0, 0, 0), P["stone_trim"], smooth=False)
    for (sx, sz) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        parts.pipe_run(b, P, [(sx * 1.3, 5.0, sz * 1.3), (sx * 0.45, 15.0, sz * 0.45)], 0.16, m="brass")
    for yy in (7.5, 10.5, 13.5):
        rr = 1.3 - 0.85 * (yy - 5.0) / 10.0
        b.torus(rr * 1.35, 0.1, 10, 4, (0, yy, 0), P["brass"])
    b.torus(1.6, 0.14, 14, 4, (0, 16.4, 0), P["brass"])
    b.lathe([(0.0, 15.0), (1.0, 16.4), (0.0, 18.8)], 6, (0, 0, 0), P["team_glow"], smooth=False)
    for i in range(6):
        a = i / 6 * math.tau
        b.box((0.9, 0.5, 0.5), (math.cos(a) * 4.2, 1.35, math.sin(a) * 4.2), P["team_glow"],
              rot=(0, 90 - math.degrees(a), 0))
    return b.to_object()


def sanctum(name):
    """Beast sanctum: a henge of runed standing stones around a floating aether crystal, a crag
    for the fliers at the back and a skull-crowned gate for the giants at the front (+Z)."""
    P = mk.palette()
    b = mk.Builder(name)
    b.lathe([(9.2, -0.5), (9.2, 0.4), (8.5, 0.5), (8.5, 0.9), (7.7, 1.0), (0.0, 1.05)], 16, (0, 0, 0), P["stone_dark"], smooth=False)
    b.cylinder(5.4, 0.1, 16, (0, 1.0, 0), P["paving"])
    b.torus(5.4, 0.14, 24, 4, (0, 1.12, 0), P["brass"])
    y0 = 1.05
    tops = {}
    for i, deg in enumerate((36, 72, 108, 144, -36, -72, -108, -144)):
        a = math.radians(deg)
        r = 6.7
        x, z = math.sin(a) * r, math.cos(a) * r
        h = 7.4 if abs(deg) in (108, 144) else 6.0
        stone = b.box((1.5, h, 1.0), (x, y0 + h / 2 - 0.2, z), P["rock"], rot=(-4, deg, 0), taper=(0.72, 0.8), bevel=0.1)
        parts.jitter_verts(stone, 0.12, seed=30 + i)
        b.box((1.42, 0.32, 1.02), (x, y0 + h * 0.66, z), P["brass"], rot=(-4, deg, 0))
        ix, iz = math.sin(a) * (r - 0.52), math.cos(a) * (r - 0.52)
        b.box((0.5, 0.5, 0.1), (ix, y0 + h * 0.46, iz), P["team_glow"], rot=(0, deg, 45))
        b.box((0.16, 0.9, 0.1), (ix, y0 + h * 0.46 - 0.75, iz), P["team_glow"], rot=(0, deg, 0))
        tops[deg] = (x, y0 + h, z)
    for d1, d2 in ((108, 144), (-108, -144)):
        (x1, y1, z1), (x2, y2, z2) = tops[d1], tops[d2]
        ln = math.hypot(x2 - x1, z2 - z1) + 1.8
        yaw = math.degrees(math.atan2(x2 - x1, z2 - z1)) + 90
        lintel = b.box((ln, 0.9, 1.1), ((x1 + x2) / 2, min(y1, y2) + 0.1, (z1 + z2) / 2), P["rock"], rot=(0, yaw, 0), bevel=0.08)
        parts.jitter_verts(lintel, 0.08, seed=50 + int(d1))
    # altar and the floating crystal
    b.lathe([(2.4, y0), (2.4, y0 + 0.4), (1.7, y0 + 0.6), (1.5, y0 + 1.4), (2.0, y0 + 1.6), (2.0, y0 + 1.9), (0.0, y0 + 1.9)], 8,
            (0, 0, 0), P["stone_trim"], smooth=False)
    b.torus(1.95, 0.12, 12, 4, (0, y0 + 1.75, 0), P["brass"])
    b.lathe([(0.0, y0 + 3.2), (1.6, y0 + 6.4), (0.0, y0 + 11.0)], 6, (0, 0, 0), P["team_glow"], smooth=False)
    for k in range(3):
        a = k / 3 * math.tau + 0.4
        b.lathe([(0.0, -1.0), (0.45, 0.0), (0.0, 1.3)], 5, (math.cos(a) * 2.8, y0 + 4.6 + k * 0.8, math.sin(a) * 2.8),
                P["team_glow"], rot=(18, math.degrees(a), 0), smooth=False)
    b.torus(3.2, 0.12, 20, 4, (0, y0 + 6.0, 0), P["brass"], rot=(14, 0, 0))
    b.torus(2.6, 0.1, 20, 4, (0, y0 + 7.4, 0), P["brass"], rot=(-10, 30, 0))
    # crag at the back where the fliers perch
    crag = b.lathe([(3.2, -0.3), (2.9, 3.0), (2.5, 6.0), (2.0, 9.0), (1.4, 11.4), (0.8, 12.8), (0.0, 13.6)], 7,
                   (0.3, 0, -7.4), P["rock"], smooth=False)
    parts.jitter_verts(crag, 0.45, seed=11)
    b.torus(1.2, 0.16, 12, 4, (0.3, 11.9, -7.4), P["brass"])
    parts.banner(b, P, 0.3, 11.0, -5.95, 1.2, 3.6)
    # front gate: two pillars, a beam and a horned skull
    for sx in (-1, 1):
        pil = b.box((1.5, 7.0, 1.5), (sx * 3.7, y0 + 3.5, 7.6), P["rock"], bevel=0.08, taper=(0.88, 0.88))
        parts.jitter_verts(pil, 0.08, seed=70 + sx)
        b.box((1.9, 0.5, 1.9), (sx * 3.7, y0 + 0.25, 7.6), P["stone_trim"])
        b.box((1.62, 0.3, 1.62), (sx * 3.7, y0 + 5.0, 7.6), P["brass"])
        parts.banner(b, P, sx * 3.7, y0 + 4.6, 8.42, 1.0, 3.0, pole=False)
    beam = b.box((9.6, 1.0, 1.4), (0, y0 + 7.4, 7.6), P["rock"], bevel=0.1)
    parts.jitter_verts(beam, 0.06, seed=77)
    b.sphere(0.95, 12, 8, (0, y0 + 8.3, 8.3), P["horn"], scale=(1.0, 0.85, 1.15))
    b.sphere(0.5, 10, 6, (0, y0 + 7.75, 8.95), P["horn"], scale=(0.9, 0.6, 1.0))
    for sx in (-1, 1):
        b.sphere(0.2, 8, 6, (sx * 0.38, y0 + 8.45, 9.25), P["team_glow"])
        b.cylinder(0.32, 2.4, 8, (sx * 0.75, y0 + 8.7, 8.1), P["horn"], rot=(-25, 0, -sx * 55), r2=0.0)
        for k in range(4):
            b.torus(0.2, 0.05, 8, 4, (sx * 2.2, y0 + 6.6 - k * 0.32, 8.35), P["iron_dark"], rot=(0, 90 * (k % 2), 90))
    return b.to_object()


ASSETS = {
    "citadel": citadel,
    "barracks": barracks,
    "foundry": foundry,
    "skyport": skyport,
    "refinery": refinery,
    "habitat": habitat,
    "bastion": bastion,
    "gate": gate,
    "relay": relay,
    "sanctum": sanctum,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name in (argv or list(ASSETS.keys())):
        mk.reset()
        ob = ASSETS[name](name)
        tris = 0
        for o in [ob] + list(ob.children_recursive):
            if o.type == "MESH":
                tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
        mk.save_blend(os.path.join(BLEND, name + ".blend"))
        mk.export_glb(os.path.join(OUT, name + ".glb"))
        print("[buildings] %-10s tris=%d" % (name, tris), flush=True)


if __name__ == "__main__":
    main()

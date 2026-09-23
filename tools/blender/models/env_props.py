"""Environment props: trees, rocks, walls, lamps and city buildings.

Run: blender --background --factory-startup --python tools/blender/models/env_props.py [-- name ...]
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import bmesh  # noqa: E402
import mk  # noqa: E402
import parts  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models")
BLEND = os.path.join(ROOT, "art", "blend", "props")


def pine(name, height, width, layers, seed):
    rnd = random.Random(seed)
    P = mk.palette()
    b = mk.Builder(name)
    b.cylinder(0.28 * width, height * 0.35, 6, (0, -0.3, 0), P["bark"], r2=0.18 * width)
    y = height * 0.16
    for i in range(layers):
        t = i / max(1, layers - 1)
        r = width * (1.0 - 0.72 * t) * rnd.uniform(0.92, 1.08)
        h = height * (0.36 - 0.12 * t)
        faces = b.cylinder(r, h, 8, (rnd.uniform(-0.1, 0.1), y, rnd.uniform(-0.1, 0.1)), P["foliage"], r2=0.0,
                           rot=(0, rnd.uniform(0, 45), 0))
        # droop the rim a little and roughen
        for f in faces:
            for v in f.verts:
                if v.co.y < y + 0.05:
                    v.co.y -= r * 0.18
        parts.jitter_verts(faces, 0.12 * width, seed + i)
        y += height * (0.8 / layers)
    return b.to_object()


def rock(name, seed, scale=(1.6, 1.0, 1.4)):
    rnd = random.Random(seed)
    P = mk.palette()
    b = mk.Builder(name)
    bm = b.bm
    before = set(bm.faces)
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    faces = [f for f in bm.faces if f not in before]
    idx = b.slot(P["rock"])
    seen = set()
    for f in faces:
        f.material_index = idx
        f.smooth = False
        for v in f.verts:
            if v in seen:
                continue
            seen.add(v)
            n = v.co.normalized()
            bump = 1.0 + 0.22 * math.sin(n.x * 5.1 + seed) * math.cos(n.z * 4.3 - seed) + rnd.uniform(-0.12, 0.12)
            v.co = n * bump
            v.co.x *= scale[0]
            v.co.y = v.co.y * scale[1] + 0.3
            v.co.z *= scale[2]
            if v.co.y < 0:
                v.co.y *= 0.3
    return b.to_object()


def wall_segment(name):
    P = mk.palette()
    b = mk.Builder(name)
    parts.crenel_wall(b, P, 6.2, 2.0, 6.0, (0, -1.0, 0))
    # outer buttresses
    for x in (-2.2, 2.2):
        b.box((0.9, 5.0, 1.0), (x, 1.5, 1.2), P["stone"], taper=(0.8, 0.5))
    return b.to_object()


def wall_tower(name):
    P = mk.palette()
    b = mk.Builder(name)
    parts.round_tower(b, P, 0, 0, 2.8, 9.0, roof_h=4.6, seg=10, y0=-1.0)
    parts.banner(b, P, 0, 6.5, 3.05, 1.3, 3.4)
    return b.to_object()


def lamp_post(name):
    P = mk.palette()
    b = mk.Builder(name)
    b.cylinder(0.32, 0.5, 6, (0, 0, 0), P["stone_dark"])
    b.cylinder(0.1, 4.2, 6, (0, 0.5, 0), P["iron"])
    b.box((1.2, 0.08, 0.08), (0.45, 4.6, 0), P["iron"])
    b.box((0.45, 0.6, 0.45), (0.95, 4.2, 0), P["lamp_glow"])
    b.cylinder(0.36, 0.3, 4, (0.95, 4.5, 0), P["iron"], r2=0.05, rot=(0, 45, 0))
    return b.to_object()


def house_a(name):
    P = mk.palette()
    b = mk.Builder(name)
    parts.gable_house(b, P, 0, 0, 5.6, 7.0, 5.2, 3.6)
    return b.to_object()


def house_b(name):
    P = mk.palette()
    b = mk.Builder(name)
    parts.gable_house(b, P, -0.8, 0, 5.0, 6.0, 7.0, 3.2, wall="plaster", roof="roof")
    parts.round_tower(b, P, 2.6, 2.2, 1.5, 9.5, roof_h=3.8, seg=8, crenel=False, wall="stone")
    return b.to_object()


def workshop(name):
    P = mk.palette()
    b = mk.Builder(name)
    w, d, h = 8.0, 12.0, 6.0
    b.box((w + 0.5, 0.8, d + 0.5), (0, 0.3, 0), P["stone_dark"])
    b.box((w, h, d), (0, h / 2 + 0.6, 0), P["plaster"])
    # saw-tooth roof
    for i in range(3):
        z = -d / 2 + (i + 0.5) * d / 3
        b.side_profile([(-w / 2 - 0.3, 0), (w / 2 + 0.3, 0), (w / 2 + 0.3, 0.3), (-w / 2 - 0.3, 2.4)], d / 3 - 0.1,
                       (0, h + 0.6, z), P["roof"], rot=(0, 90, 0))
        b.box((w - 0.4, 1.4, 0.15), (0, h + 1.9, z - d / 6 + 0.15), P["window_glow"])
    b.box((3.0, 3.6, 0.3), (0, 2.4, d / 2 + 0.1), P["iron"])
    b.box((3.3, 0.4, 0.4), (0, 4.4, d / 2 + 0.15), P["brass"])
    for z in (-3.5, 0.0, 3.5):
        for sx in (-1, 1):
            b.box((0.12, 1.6, 1.4), (sx * (w / 2 + 0.03), 3.5, z), P["window_glow"])
    parts.chimney_stack(b, P, 2.2, -4.0, 0.8, 11.0, y0=0.6, m="stone")
    parts.pipe_run(b, P, [(-w / 2 - 0.4, 1.0, 3.0), (-w / 2 - 0.4, 5.0, 3.0), (-w / 2 - 0.4, 5.0, -3.0)], 0.3)
    parts.gear_wheel(b, P, -w / 2 - 0.3, 4.2, -1.0, 1.1, rot=(0, 0, 90))
    return b.to_object()


def warehouse(name):
    P = mk.palette()
    b = mk.Builder(name)
    w, d, h = 8.5, 10.0, 4.5
    b.box((w + 0.4, 0.8, d + 0.4), (0, 0.3, 0), P["stone_dark"])
    b.box((w, h, d), (0, h / 2 + 0.6, 0), P["stone"])
    prof = [(math.cos(t) * (w / 2 + 0.3), math.sin(t) * 2.6) for t in [i / 10 * math.pi for i in range(11)]]
    b.side_profile(prof, d + 0.6, (0, h + 0.6, 0), P["roof_copper"])
    for z in (-3.0, 0.0, 3.0):
        b.box((w + 0.3, 0.25, 0.3), (0, h + 0.7, z), P["iron"])
    b.box((3.2, 3.2, 0.25), (0, 2.2, d / 2 + 0.1), P["wood"])
    for (x, z, s) in [(5.6, 3.0, 1.1), (5.9, 1.6, 0.9), (5.4, 0.2, 1.0), (6.8, 2.4, 0.8)]:
        b.box((s, s, s), (x, s / 2, z), P["wood"], rot=(0, x * 20, 0))
    b.cylinder(0.45, 1.2, 8, (-5.6, 0, 2.0), P["iron"])
    b.cylinder(0.45, 1.2, 8, (-5.7, 0, 3.1), P["iron"])
    return b.to_object()


def smokestack(name):
    P = mk.palette()
    b = mk.Builder(name)
    b.box((6.0, 3.2, 6.0), (0, 1.4, 0), P["stone"], bevel=0.1)
    b.box((6.3, 0.4, 6.3), (0, 3.1, 0), P["stone_trim"])
    parts.chimney_stack(b, P, 0, 0, 1.5, 20.0, y0=3.2, m="plaster")
    b.box((1.6, 2.2, 0.2), (0, 1.6, 3.05), P["fire_glow"])
    parts.pipe_run(b, P, [(2.8, 2.0, 2.8), (4.2, 2.0, 2.8), (4.2, 0.0, 2.8)], 0.35)
    return b.to_object()


def aether_pylon(name):
    P = mk.palette()
    b = mk.Builder(name)
    b.lathe([(2.2, 0), (2.2, 0.8), (1.6, 1.2), (1.2, 3.5), (1.5, 3.8), (1.5, 4.2)], 8, (0, 0, 0), P["stone"], smooth=False)
    for i in range(4):
        a = i / 4 * math.tau + math.pi / 4
        x, z = math.cos(a) * 1.3, math.sin(a) * 1.3
        b.box((0.25, 4.4, 0.25), (x * 0.8, 6.0, z * 0.8), P["brass"], rot=(math.degrees(math.sin(a)) * 0.1, 0, 0))
    b.torus(1.25, 0.12, 12, 4, (0, 5.2, 0), P["brass"])
    b.torus(1.0, 0.1, 12, 4, (0, 7.6, 0), P["brass"])
    b.lathe([(0.0, 4.9), (0.75, 6.1), (0.6, 7.4), (0.0, 8.9)], 6, (0, 0, 0), P["aether"], smooth=False)
    return b.to_object()


def crystal_cluster(name):
    rnd = random.Random(7)
    P = mk.palette()
    b = mk.Builder(name)
    b.lathe([(1.8, 0), (1.4, 0.5), (0.4, 0.8)], 7, (0, 0, 0), P["rock"], smooth=False)
    for i in range(7):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0.0, 1.0)
        h = rnd.uniform(1.4, 3.6)
        r = rnd.uniform(0.2, 0.42)
        b.lathe([(r, 0.0), (r, h * 0.75), (0.0, h)], 6, (math.cos(a) * rr, 0.2, math.sin(a) * rr), P["crystal"],
                rot=(rnd.uniform(-28, 28), rnd.uniform(0, 360), rnd.uniform(-28, 28)), smooth=False)
    return b.to_object()


ASSETS = {
    "tree_pine_a": lambda n: pine(n, 12.0, 3.4, 5, 11),
    "tree_pine_b": lambda n: pine(n, 9.5, 3.6, 4, 23),
    "tree_pine_c": lambda n: pine(n, 14.0, 3.1, 6, 37),
    "rock_a": lambda n: rock(n, 3, (1.7, 1.0, 1.3)),
    "rock_b": lambda n: rock(n, 5, (1.2, 1.4, 1.1)),
    "rock_c": lambda n: rock(n, 9, (2.2, 0.8, 1.6)),
    "wall_segment": wall_segment,
    "wall_tower": wall_tower,
    "lamp_post": lamp_post,
    "house_a": house_a,
    "house_b": house_b,
    "workshop": workshop,
    "warehouse": warehouse,
    "smokestack": smokestack,
    "aether_pylon": aether_pylon,
    "crystal_cluster": crystal_cluster,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv or list(ASSETS.keys())
    for name in names:
        mk.reset()
        ob = ASSETS[name](name)
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        mk.save_blend(os.path.join(BLEND, name + ".blend"))
        mk.export_glb(os.path.join(OUT, name + ".glb"))
        print("[props] %-16s tris=%d" % (name, tris), flush=True)


if __name__ == "__main__":
    main()

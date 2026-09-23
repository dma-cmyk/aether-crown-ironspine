"""Unit models. Face +Z (Godot), origin at the feet (air units: hull centre).

Infantry are exported as a single baked mesh for MultiMesh rendering:
  COLOR.rgb = albedo, COLOR.a = part id (0 body, .25 left leg, .5 right leg, .75 arms)
  UV  = (metallic, roughness)      UV2 = (team mask, emission mask)
Vehicles keep material slots and use child objects as animation joints.

Run: blender --background --factory-startup --python tools/blender/models/units.py [-- name ...]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import bmesh  # noqa: E402
import mk  # noqa: E402
import parts  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models")
BLEND = os.path.join(ROOT, "art", "blend", "units")

BODY, LLEG, RLEG, ARMS = 0.0, 0.25, 0.5, 0.75

# material -> (albedo, metallic, roughness, team mask, emission mask)
BAKE = {
    "iron": ((0.30, 0.31, 0.34), 0.75, 0.42, 0.0, 0.0),
    "iron_dark": ((0.09, 0.095, 0.11), 0.6, 0.55, 0.0, 0.0),
    "brass": ((0.78, 0.56, 0.27), 0.9, 0.32, 0.0, 0.0),
    "copper": ((0.66, 0.36, 0.22), 0.9, 0.38, 0.0, 0.0),
    "leather": ((0.23, 0.16, 0.11), 0.0, 0.72, 0.0, 0.0),
    "wood": ((0.30, 0.20, 0.13), 0.0, 0.7, 0.0, 0.0),
    "skin": ((0.62, 0.46, 0.37), 0.0, 0.6, 0.0, 0.0),
    "canvas": ((0.45, 0.42, 0.36), 0.0, 0.85, 0.0, 0.0),
    "team_cloth": ((0.5, 0.5, 0.5), 0.0, 0.8, 1.0, 0.0),
    "team_trim": ((0.6, 0.6, 0.6), 0.55, 0.38, 1.0, 0.0),
    "team_glow": ((1.0, 1.0, 1.0), 0.0, 0.3, 1.0, 1.0),
    "fire_glow": ((1.0, 0.5, 0.2), 0.0, 0.4, 0.0, 1.0),
}


class Tags:
    def __init__(self):
        self.part = {}

    def __call__(self, faces, part):
        for f in faces:
            self.part[f] = part
        return faces


def bake_infantry(b, tags):
    bm = b.bm
    col = bm.loops.layers.float_color.get("Col") or bm.loops.layers.float_color.new("Col")
    uv1 = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("UV2")
    names = [s.name for s in b.slots]
    for f in bm.faces:
        rgb, metal, rough, team, emit = BAKE[names[f.material_index]]
        part = tags.part.get(f, BODY)
        for l in f.loops:
            l[col] = (rgb[0], rgb[1], rgb[2], part)
            l[uv1].uv = (metal, 1.0 - rough)  # glTF export flips V
            l[uv2].uv = (team, 1.0 - emit)
        f.material_index = 0
    b.color_layer = col
    b.slots = [mk.mat("infantry", (0.5, 0.5, 0.5))]


def legs(b, P, T, armor="iron_dark"):
    for side, part in ((-1, LLEG), (1, RLEG)):
        x = side * 0.13
        T(b.box((0.22, 0.5, 0.26), (x, 0.76, 0.0), P[armor]), part)
        T(b.box((0.2, 0.46, 0.24), (x, 0.32, 0.02), P["leather"]), part)
        T(b.box((0.25, 0.15, 0.38), (x, 0.075, 0.06), P["iron_dark"]), part)
        T(b.box((0.21, 0.17, 0.08), (x, 0.58, 0.13), P["iron"]), part)


def aetherguard(name):
    P = mk.palette()
    b = mk.Builder(name)
    T = Tags()
    legs(b, P, T)
    T(b.box((0.46, 0.18, 0.3), (0, 1.03, 0), P["leather"]), BODY)
    T(b.box((0.36, 0.6, 0.05), (0, 0.8, 0.165), P["team_cloth"]), BODY)
    T(b.box((0.36, 0.5, 0.05), (0, 0.84, -0.165), P["team_cloth"]), BODY)
    T(b.box((0.5, 0.56, 0.33), (0, 1.38, 0), P["iron"], taper=(1.14, 1.0), bevel=0.02), BODY)
    T(b.box((0.26, 0.28, 0.05), (0, 1.4, 0.175), P["team_trim"]), BODY)
    T(b.box((0.38, 0.44, 0.2), (0, 1.36, -0.26), P["iron_dark"]), BODY)
    T(b.cylinder(0.075, 0.36, 6, (0.12, 1.2, -0.38), P["team_glow"]), BODY)
    T(b.cylinder(0.075, 0.36, 6, (-0.12, 1.2, -0.38), P["brass"]), BODY)
    T(b.sphere(0.165, 8, 6, (0, 1.82, -0.01), P["iron"], scale=(1.0, 1.08, 1.12)), BODY)
    T(b.box((0.36, 0.05, 0.36), (0, 1.72, 0.0), P["iron_dark"]), BODY)
    T(b.box((0.24, 0.05, 0.05), (0, 1.8, 0.165), P["team_glow"]), BODY)
    T(b.box((0.05, 0.14, 0.34), (0, 2.0, -0.02), P["team_cloth"]), BODY)
    for side in (-1, 1):
        T(b.sphere(0.15, 8, 5, (side * 0.31, 1.6, 0), P["brass"], scale=(1.1, 0.8, 1.15)), BODY)
    T(b.box((0.12, 0.34, 0.13), (-0.3, 1.4, 0.07), P["iron"], rot=(-38, 0, 12)), ARMS)
    T(b.box((0.12, 0.34, 0.13), (0.3, 1.4, 0.07), P["iron"], rot=(-38, 0, -12)), ARMS)
    T(b.box((0.1, 0.1, 0.34), (-0.17, 1.25, 0.3), P["leather"], rot=(0, 25, 0)), ARMS)
    T(b.box((0.1, 0.1, 0.34), (0.2, 1.25, 0.22), P["leather"], rot=(0, -10, 0)), ARMS)
    T(b.box((0.08, 0.12, 0.8), (0.06, 1.32, 0.34), P["wood"]), ARMS)
    T(b.cylinder(0.04, 0.78, 6, (0.06, 1.36, 0.62), P["iron_dark"], rot=(90, 0, 0)), ARMS)
    T(b.box((0.1, 0.1, 0.12), (0.06, 1.36, 0.95), P["brass"]), ARMS)
    T(b.box((0.06, 0.07, 0.3), (0.06, 1.47, 0.52), P["team_glow"]), ARMS)
    bake_infantry(b, T)
    return b.to_object()


def artificer(name):
    P = mk.palette()
    b = mk.Builder(name)
    T = Tags()
    legs(b, P, T, armor="leather")
    T(b.box((0.46, 0.2, 0.3), (0, 1.03, 0), P["leather"]), BODY)
    T(b.box((0.5, 0.75, 0.34), (0, 1.15, 0), P["leather"], taper=(1.0, 1.0)), BODY)
    T(b.box((0.4, 0.5, 0.05), (0, 0.78, 0.17), P["team_cloth"]), BODY)
    T(b.box((0.46, 0.5, 0.32), (0, 1.4, 0), P["canvas"], taper=(1.1, 1.0)), BODY)
    T(b.box((0.28, 0.2, 0.05), (0, 1.45, 0.17), P["team_trim"]), BODY)
    # tool pack with gear
    T(b.box((0.44, 0.56, 0.26), (0, 1.38, -0.28), P["iron_dark"]), BODY)
    T(b.gear(0.2, 0.06, 8, (0, 1.46, -0.43), P["brass"], rot=(90, 0, 0)), BODY)
    T(b.cylinder(0.05, 0.6, 5, (0.18, 1.6, -0.3), P["copper"]), BODY)
    T(b.box((0.1, 0.1, 0.1), (0.18, 2.22, -0.3), P["team_glow"]), BODY)
    # hood + goggles
    T(b.sphere(0.17, 8, 6, (0, 1.8, -0.02), P["leather"], scale=(1.0, 1.05, 1.15)), BODY)
    T(b.box((0.26, 0.07, 0.06), (0, 1.82, 0.15), P["brass"]), BODY)
    T(b.box((0.1, 0.06, 0.06), (-0.06, 1.82, 0.18), P["team_glow"]), BODY)
    T(b.box((0.1, 0.06, 0.06), (0.06, 1.82, 0.18), P["team_glow"]), BODY)
    for side in (-1, 1):
        T(b.sphere(0.13, 8, 5, (side * 0.29, 1.58, 0), P["leather"], scale=(1.1, 0.8, 1.1)), BODY)
    # arms + big wrench
    T(b.box((0.12, 0.36, 0.13), (-0.29, 1.38, 0.05), P["canvas"], rot=(-30, 0, 10)), ARMS)
    T(b.box((0.12, 0.36, 0.13), (0.29, 1.38, 0.05), P["canvas"], rot=(-30, 0, -10)), ARMS)
    T(b.box((0.08, 0.08, 1.0), (0.12, 1.25, 0.45), P["iron"], rot=(-20, 0, 0)), ARMS)
    T(b.box((0.26, 0.1, 0.12), (0.12, 1.45, 0.92), P["iron"], rot=(-20, 0, 0)), ARMS)
    T(b.box((0.12, 0.12, 0.12), (-0.14, 1.22, 0.3), P["fire_glow"]), ARMS)
    bake_infantry(b, T)
    return b.to_object()


# ---------------------------------------------------------------------------
def walker(name):
    P = mk.palette()
    root = mk.empty(name)
    H = (0.0, 5.0, 0.0)
    hips = mk.Builder("hips")
    hips.box((2.8, 1.1, 1.9), H, P["iron_dark"], bevel=0.08)
    hips.box((1.6, 0.6, 2.1), (0, 4.55, 0), P["iron"])
    for sx in (-1, 1):
        hips.cylinder(0.62, 0.6, 10, (sx * 1.45, 5.0, 0), P["brass"], rot=(0, 0, 90))
    ob_hips = hips.to_object(parent=root, origin=H)

    TP = (0.0, 5.6, 0.0)
    t = mk.Builder("torso")
    t.box((4.6, 3.0, 3.6), (0, 7.3, 0), P["iron"], bevel=0.2)
    t.box((4.9, 0.5, 3.9), (0, 5.95, 0), P["iron_dark"])
    t.box((3.6, 1.8, 0.4), (0, 7.4, 1.85), P["team_trim"], rot=(-18, 0, 0), bevel=0.06)
    t.box((1.8, 0.36, 0.14), (0, 8.35, 1.92), P["team_glow"])
    t.lathe([(1.3, 8.8), (1.2, 9.4), (0.8, 9.9), (0.0, 10.1)], 10, (0, 0, 0.3), P["iron_dark"])
    t.cylinder(0.1, 1.2, 5, (0.5, 9.8, 0.2), P["brass"])
    t.box((0.5, 0.3, 0.5), (0, 9.55, 1.2), P["team_glow"])
    # shoulder cannon (right)
    t.box((1.4, 1.3, 2.4), (2.95, 8.5, 0.2), P["iron_dark"], bevel=0.08)
    t.box((1.5, 0.5, 2.6), (2.95, 9.2, 0.2), P["team_trim"])
    for x in (2.7, 3.2):
        t.cylinder(0.24, 3.2, 8, (x, 8.45, 1.2), P["iron"], rot=(90, 0, 0), r2=0.2)
        t.cylinder(0.3, 0.4, 8, (x, 8.45, 4.1), P["brass"], rot=(90, 0, 0))
    # left arm gatling
    t.box((1.2, 1.2, 1.4), (-2.8, 7.9, 0.0), P["brass"], bevel=0.08)
    t.box((0.9, 2.2, 0.9), (-2.9, 6.6, 0.4), P["iron"], rot=(20, 0, 0))
    t.cylinder(0.5, 1.4, 10, (-2.9, 5.7, 0.9), P["iron_dark"], rot=(90, 0, 0))
    for i in range(6):
        a = i / 6 * math.tau
        t.cylinder(0.09, 2.3, 5, (-2.9 + math.cos(a) * 0.28, 5.7 + math.sin(a) * 0.28, 2.2), P["iron"], rot=(90, 0, 0))
    t.torus(0.42, 0.08, 10, 4, (-2.9, 5.7, 3.6), P["brass"], rot=(90, 0, 0))
    # back: boiler + stacks + banner
    t.lathe([(1.1, 6.2), (1.2, 8.6), (0.8, 9.2), (0.0, 9.4)], 10, (0, 0, -2.0), P["copper"])
    for sx in (-1, 1):
        t.cylinder(0.3, 2.8, 8, (sx * 1.1, 8.0, -2.1), P["iron_dark"])
        t.cylinder(0.36, 0.3, 8, (sx * 1.1, 10.6, -2.1), P["brass"])
        t.cylinder(0.2, 0.12, 8, (sx * 1.1, 10.75, -2.1), P["fire_glow"])
    parts.banner(t, P, 0, 8.6, -2.9, 1.6, 4.2, rot=180)
    ob_torso = t.to_object(parent=ob_hips, origin=TP, parent_origin=H)

    for side, sx in (("l", -1), ("r", 1)):
        hip = (sx * 1.55, 5.0, 0.0)
        knee = (sx * 1.6, 2.7, 0.55)
        ankle = (sx * 1.6, 0.6, 0.15)
        th = mk.Builder("leg_" + side)
        th.box((1.0, 2.6, 1.1), (sx * 1.6, 3.85, 0.3), P["iron"], rot=(-12, 0, 0), bevel=0.08)
        th.box((0.8, 1.6, 0.25), (sx * 1.6, 3.9, 0.95), P["team_trim"], rot=(-12, 0, 0))
        th.sphere(0.55, 10, 6, (sx * 1.6, 2.75, 0.55), P["brass"])
        ob_leg = th.to_object(parent=ob_hips, origin=hip, parent_origin=H)
        sh = mk.Builder("shin_" + side)
        sh.box((0.9, 2.3, 1.0), (sx * 1.6, 1.65, 0.35), P["iron_dark"], rot=(10, 0, 0), bevel=0.08)
        sh.box((0.7, 1.5, 0.25), (sx * 1.6, 1.8, 0.95), P["iron"], rot=(10, 0, 0))
        sh.cylinder(0.14, 2.0, 6, (sx * 1.6, 0.8, -0.4), P["brass"], rot=(10, 0, 0))
        ob_shin = sh.to_object(parent=ob_leg, origin=knee, parent_origin=hip)
        ft = mk.Builder("foot_" + side)
        ft.box((1.4, 0.55, 2.4), (sx * 1.6, 0.28, 0.45), P["iron"], bevel=0.08, taper=(0.9, 0.85))
        for dx in (-0.45, 0.0, 0.45):
            ft.box((0.36, 0.36, 0.7), (sx * 1.6 + dx, 0.2, 1.75), P["iron_dark"], taper=(0.8, 0.6))
        ft.box((0.5, 0.4, 0.8), (sx * 1.6, 0.25, -0.95), P["iron_dark"])
        ft.to_object(parent=ob_shin, origin=ankle, parent_origin=knee)
    return root


def mortar(name):
    P = mk.palette()
    root = mk.empty(name)
    c = mk.Builder("chassis")
    for sx in (-1, 1):
        x = sx * 1.35
        c.box((0.75, 0.8, 3.7), (x, 0.55, 0), P["rubber"])
        for k in (-1.85, 1.85):
            c.cylinder(0.4, 0.75, 10, (x - 0.375, 0.55, k), P["rubber"], rot=(0, 0, -90))
        for k in range(5):
            c.cylinder(0.3, 0.8, 8, (x - 0.4, 0.5, -1.6 + k * 0.8), P["iron_dark"], rot=(0, 0, -90))
        c.box((0.95, 0.12, 4.6), (x, 1.02, 0), P["iron"])
    c.box((2.1, 1.1, 3.9), (0, 1.45, 0), P["iron"], bevel=0.08)
    c.box((2.0, 0.9, 0.8), (0, 1.35, 2.2), P["team_trim"], rot=(-30, 0, 0))
    c.lathe([(0.8, 1.9), (0.85, 2.7), (0.5, 3.1), (0.0, 3.2)], 10, (0, 0, -1.3), P["brass"])
    c.cylinder(0.2, 1.8, 6, (0.6, 2.0, -1.8), P["iron_dark"])
    c.cylinder(0.14, 0.1, 6, (0.6, 3.8, -1.8), P["fire_glow"])
    c.box((2.2, 0.2, 0.4), (0, 2.05, -2.0), P["team_cloth"])
    ob_c = c.to_object(parent=root)
    TP = (0.0, 2.0, 0.6)
    tu = mk.Builder("turret")
    tu.cylinder(0.95, 0.4, 10, TP, P["iron_dark"])
    for sx in (-1, 1):
        tu.box((0.18, 1.1, 1.3), (sx * 0.65, 2.8, 0.6), P["iron"])
    ob_t = tu.to_object(parent=ob_c, origin=TP)
    BP = (0.0, 2.95, 0.6)
    br = mk.Builder("barrel")
    br.lathe([(0.52, -0.9), (0.5, 0.0), (0.44, 1.8), (0.5, 2.0), (0.5, 2.2), (0.38, 2.2)], 10, (0, 2.95, 0.6),
             P["iron"], rot=(90, 0, 0))
    for zz in (0.2, 1.0):
        br.cylinder(0.56, 0.2, 10, (0, 2.95, 0.6 + zz), P["brass"], rot=(90, 0, 0))
    br.cylinder(0.14, 1.9, 8, (-0.95, 2.95, 0.6), P["brass"], rot=(0, 0, -90))
    br.to_object(parent=ob_t, origin=BP, parent_origin=TP)
    for (nm, sx, sz) in (("leg_fl", -1, 1), ("leg_fr", 1, 1), ("leg_bl", -1, -1), ("leg_br", 1, -1)):
        pv = (sx * 1.15, 1.1, sz * 1.7)
        lg = mk.Builder(nm)
        lg.box((0.22, 1.5, 0.22), (sx * 1.55, 0.55, sz * 1.95), P["iron"], rot=(-sz * 20, 0, sx * 25))
        lg.box((0.5, 0.12, 0.5), (sx * 1.85, -0.12, sz * 2.15), P["iron_dark"])
        lg.to_object(parent=ob_c, origin=pv)
    return root


def airship(name):
    P = mk.palette()
    root = mk.empty(name)
    hb = mk.Builder("hull")
    prof = [(0.0, -12.5), (1.1, -11.4), (2.3, -9.0), (3.3, -5.0), (3.7, -1.0), (3.6, 3.0), (3.2, 6.5), (2.4, 9.0),
            (1.2, 10.8), (0.0, 11.5)]
    hb.lathe(prof, 16, (0, 0, 0), P["canvas"], rot=(90, 0, 0))
    for z, r in ((-7.0, 2.9), (-3.0, 3.55), (1.0, 3.72), (5.0, 3.42), (8.5, 2.6)):
        hb.torus(r + 0.04, 0.09, 18, 4, (0, 0, z), P["brass"], rot=(90, 0, 0))
    for z, r in ((-1.8, 3.72), (2.4, 3.66)):
        hb.torus(r + 0.03, 0.34, 18, 4, (0, 0, z), P["team_cloth"], rot=(90, 0, 0))
    # tail fins
    fin = [(0.0, 0.0), (3.2, 0.0), (1.2, 3.4), (0.0, 3.0)]
    for rz in (0, 90, 180, 270):
        hb.side_profile([(x - 12.0, y + 1.9) for (x, y) in fin], 0.16, (0, 0, 0), P["team_cloth"],
                        rot=(rz, -90, 0))
    hb.torus(1.25, 0.18, 12, 5, (0, 0, -11.2), P["team_glow"], rot=(90, 0, 0))
    # gondola
    g = [(-6.0, -4.3), (6.6, -4.3), (5.2, -5.5), (3.0, -6.3), (-4.6, -6.1), (-6.2, -5.1)]
    hb.side_profile(g, 3.4, (0, 0, 0), P["wood"], rot=(0, -90, 0))
    hb.box((3.5, 0.25, 12.4), (0, -4.2, 0.2), P["iron"])
    hb.box((2.6, 1.5, 5.4), (0, -3.4, -0.6), P["wood"])
    hb.box((2.7, 0.3, 4.4), (0, -3.2, -0.6), P["window_glow"])
    hb.box((2.9, 0.3, 5.8), (0, -2.55, -0.6), P["roof"])
    for zz in (-4.0, 3.5):
        for sx in (-1, 1):
            hb.box((0.18, 3.0, 0.18), (sx * 1.2, -2.8, zz), P["brass"], rot=(0, 0, -sx * 15))
    for k in range(3):
        for sx in (-1, 1):
            hb.cylinder(0.2, 1.1, 8, (sx * 1.6, -5.1, -2.5 + k * 2.4), P["iron_dark"], rot=(0, 0, -sx * 90))
    # engine pods
    for sx in (-1, 1):
        hb.box((3.0, 0.25, 0.25), (sx * 3.4, -1.6, -6.0), P["iron"])
        hb.lathe([(0.0, -2.2), (0.6, -1.6), (0.7, 1.2), (0.3, 2.0)], 8, (sx * 4.9, -1.6, -6.0), P["iron_dark"], rot=(90, 0, 0))
    ob_h = hb.to_object(parent=root)
    for side, sx in (("l", -1), ("r", 1)):
        pv = (sx * 4.9, -1.6, -8.4)
        pr = mk.Builder("prop_" + side)
        pr.cylinder(0.25, 0.6, 8, pv, P["brass"], rot=(90, 0, 0))
        for k in range(4):
            pr.box((0.35, 2.4, 0.08), (pv[0], pv[1], pv[2] - 0.1), P["wood"], rot=(0, 0, k * 90 + 10))
        pr.to_object(parent=ob_h, origin=pv)
    return root


ASSETS = {
    "aetherguard": (aetherguard, True),
    "artificer": (artificer, True),
    "walker": (walker, False),
    "mortar": (mortar, False),
    "airship": (airship, False),
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name in (argv or list(ASSETS.keys())):
        mk.reset()
        fn, vcol = ASSETS[name]
        ob = fn(name)
        tris = 0
        for o in [ob] + list(ob.children_recursive):
            if o.type == "MESH":
                tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
        mk.save_blend(os.path.join(BLEND, name + ".blend"))
        mk.export_glb(os.path.join(OUT, name + ".glb"), vertex_colors=vcol)
        print("[units] %-12s tris=%d" % (name, tris), flush=True)


if __name__ == "__main__":
    main()

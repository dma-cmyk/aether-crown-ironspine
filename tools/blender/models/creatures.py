"""Creature units: skinned meshes on a bone rig, animated procedurally in Godot.

Face +Z (Godot), origin at the feet (flyers: body centre), +x is the creature's left.
Skin colour comes from vertex paint over the shared creature textures; harness, armour and
glow use the palette names, so team colours swap exactly as on the other models.

Run: blender --background --factory-startup --python tools/blender/models/creatures.py [-- name ...]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import creature as cr  # noqa: E402
import mk  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models")
BLEND = os.path.join(ROOT, "art", "blend", "units")


# ---------------------------------------------------------------------------
def lin(c):
    """sRGB triple -> linear (vertex colours are linear)."""
    return tuple(((v + 0.055) / 1.055) ** 2.4 for v in c)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def basis(d):
    """Unit vector d plus two perpendicular unit vectors."""
    d = Vector(d).normalized()
    up = Vector((0, 1, 0)) if abs(d.y) < 0.95 else Vector((1, 0, 0))
    e1 = d.cross(up).normalized()
    return d, e1, d.cross(e1).normalized()


def aim(d):
    """mk rotation (degrees) that turns +Y onto direction d."""
    d = Vector(d).normalized()
    return (math.degrees(math.acos(max(-1.0, min(1.0, d.y)))), math.degrees(math.atan2(d.x, d.z)), 0.0)


def tube(b, a, c, r, m, seg=8, r2=None):
    """Cylinder (or cone with r2) from point a to point c."""
    a, c = Vector(a), Vector(c)
    return b.cylinder(r, (c - a).length, seg, tuple(a), m, rot=aim(c - a), r2=r2)


def strap(c, pts, width, thick, m, lift=0.015, n=32, closed=False, name="strap", axis=None):
    """Ribbon laid on the skin along a polyline (Godot points).

    Points drop onto the nearest skin, or with `axis` (two Godot points) they are cast
    straight toward that line, so a band around a limb cannot jump onto the body."""
    dg = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(c.body, dg)
    path = [Vector(p) for p in pts] + ([Vector(pts[0])] if closed else [])
    seg = [(path[i + 1] - path[i]).length for i in range(len(path) - 1)]
    total = sum(seg)
    samples = []
    count = n if closed else n + 1
    for k in range(count):
        s = total * k / n
        i = 0
        while i < len(seg) - 1 and s > seg[i]:
            s -= seg[i]
            i += 1
        samples.append(path[i].lerp(path[i + 1], min(1.0, s / max(seg[i], 1e-6))))
    b = mk.Builder(name)
    bm = b.bm
    idx = b.slot(m)
    rows = []
    for i, p in enumerate(samples):
        loc = None
        if axis is not None:
            a, z = Vector(axis[0]), Vector(axis[1])
            t = max(0.0, min(1.0, (p - a).dot(z - a) / (z - a).length_squared))
            to = a.lerp(z, t) - p
            loc, nrm, _f, _d = bvh.ray_cast(cr.gvec(tuple(p)), cr.gvec(tuple(to)).normalized(), to.length)
        if loc is None:
            loc, nrm, _f, _d = bvh.find_nearest(cr.gvec(tuple(p)))
        q = Vector(cr.to_godot(loc))
        nn = Vector(cr.to_godot(nrm)).normalized()
        if closed:
            tangent = samples[(i + 1) % len(samples)] - samples[i - 1]
        else:
            tangent = samples[min(i + 1, len(samples) - 1)] - samples[max(i - 1, 0)]
        side = tangent.cross(nn).normalized() * width * 0.5
        top = q + nn * (lift + thick)
        bot = q + nn * lift
        rows.append([bm.verts.new(v) for v in (top - side, top + side, bot + side, bot - side)])
    pairs = [(i, (i + 1) % len(rows)) for i in range(len(rows) if closed else len(rows) - 1)]
    for i, j in pairs:
        for k in range(4):
            f = bm.faces.new((rows[i][k], rows[i][(k + 1) % 4], rows[j][(k + 1) % 4], rows[j][k]))
            f.material_index = idx
    if not closed:
        bm.faces.new(list(reversed(rows[0]))).material_index = idx
        bm.faces.new(rows[-1]).material_index = idx
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return b


def ring_verts(faces):
    return list({v for f in faces for v in f.verts})


# ---------------------------------------------------------------------------
def cyclops_paint(p, n):
    x, y, z = p
    c = lin((0.42, 0.43, 0.36))
    c = mix(c, lin((0.29, 0.31, 0.28)), smooth(0.1, -0.7, n[2]) * 0.85)
    c = mix(c, lin((0.53, 0.51, 0.42)), smooth(0.3, 0.9, n[2]) * smooth(3.3, 3.8, y) * (1.0 - smooth(5.6, 6.0, y)))
    dark = max(smooth(0.9, 0.15, y), smooth(3.0, 2.1, y) * smooth(2.0, 2.45, abs(x)))
    c = mix(c, lin((0.22, 0.22, 0.2)), dark)
    c = mix(c, lin((0.52, 0.38, 0.33)), smooth(6.5, 6.8, y) * smooth(0.1, 0.8, n[2]) * 0.5)
    return c


def cyclops(name):
    """Hill giant: one glowing eye, a spiked club in the right fist, iron plates on the left shoulder."""
    P = mk.palette()
    rig = cr.Rig(name)
    rig.bone("hips", (0, 3.5, 0), (0, 4.6, 0.08))
    rig.bone("spine", (0, 4.6, 0.08), (0, 5.55, 0.1), "hips")
    rig.bone("chest", (0, 5.55, 0.1), (0, 6.1, 0.25), "spine")
    rig.bone("neck", (0, 6.1, 0.25), (0, 6.62, 0.62), "chest")
    rig.bone("head", (0, 6.62, 0.62), (0, 7.75, 0.9), "neck")
    rig.bone("jaw", (0, 6.75, 0.78), (0, 6.45, 1.3), "head")
    rig.mirror("clav_l", (0.3, 5.9, 0.1), (1.55, 5.9, 0.0), "chest")
    rig.mirror("uparm_l", (1.55, 5.9, 0.0), (2.25, 4.2, 0.2), "clav_l")
    rig.mirror("forearm_l", (2.25, 4.2, 0.2), (2.5, 2.7, 0.7), "uparm_l")
    rig.mirror("hand_l", (2.5, 2.7, 0.7), (2.56, 2.0, 0.95), "forearm_l")
    rig.mirror("thigh_l", (0.75, 3.45, 0.0), (0.9, 1.9, 0.25), "hips")
    rig.mirror("shin_l", (0.9, 1.9, 0.25), (0.9, 0.45, -0.05), "thigh_l")
    rig.mirror("foot_l", (0.9, 0.45, -0.05), (0.9, 0.12, 0.9), "shin_l")

    skin = cr.Body(name + "_skin", P["hide"], res=0.055)
    skin.ellipsoid((0, 3.55, 0.0), (0.9, 0.55, 0.7))
    skin.ellipsoid((0, 4.15, 0.16), (0.9, 0.7, 0.74))
    skin.ellipsoid((0, 5.08, 0.1), (1.18, 0.9, 0.84))
    skin.mirror_ellipsoid((0.55, 5.45, 0.52), (0.56, 0.4, 0.36), rot=(0, 0, -12))
    skin.ellipsoid((0, 5.85, -0.2), (1.1, 0.48, 0.6))
    skin.mirror_ball((0.62, 6.02, -0.02), 0.46)
    skin.mirror_ellipsoid((0.95, 4.98, -0.24), (0.45, 0.85, 0.5))
    skin.mirror_ball((1.55, 5.86, 0.04), 0.62)
    skin.capsule((0, 5.9, 0.25), (0, 6.65, 0.62), 0.5)
    skin.ellipsoid((0, 7.08, 0.8), (0.66, 0.7, 0.64))
    skin.ball((0, 7.36, 0.6), 0.55)
    skin.ellipsoid((0, 7.52, 1.24), (0.55, 0.13, 0.22))
    skin.mirror_ball((0.37, 6.72, 1.08), 0.28)
    skin.ellipsoid((0, 6.6, 1.04), (0.52, 0.28, 0.48))
    skin.ball((0, 6.45, 1.25), 0.21)
    skin.ball((0, 6.82, 1.42), 0.13)
    skin.mirror_ellipsoid((0.66, 7.12, 0.66), (0.09, 0.22, 0.14))
    skin.mirror_limb([(1.55, 5.9, 0.0), (1.9, 5.05, 0.1), (2.25, 4.2, 0.2)], [0.55, 0.5, 0.4])
    skin.mirror_ellipsoid((1.95, 5.05, 0.33), (0.4, 0.55, 0.38), rot=(0, 0, 20))
    skin.mirror_ball((1.95, 5.0, -0.15), 0.36)
    skin.mirror_limb([(2.25, 4.2, 0.2), (2.4, 3.45, 0.45), (2.5, 2.7, 0.7)], [0.42, 0.48, 0.36])
    skin.mirror_ellipsoid((2.33, 3.75, 0.35), (0.46, 0.6, 0.44), rot=(-15, 0, 10))
    skin.mirror_ellipsoid((2.53, 2.35, 0.82), (0.38, 0.44, 0.4))
    for k in range(4):
        skin.mirror_ball((2.36 + k * 0.11, 2.12 + k * 0.02, 1.08 - k * 0.04), 0.13)
    skin.mirror_ball((2.34, 2.5, 1.1), 0.14)
    skin.mirror_limb([(0.75, 3.45, 0.0), (0.85, 2.7, 0.12), (0.9, 1.9, 0.25)], [0.68, 0.62, 0.46])
    skin.mirror_ball((0.9, 1.9, 0.34), 0.38)
    skin.mirror_limb([(0.9, 1.9, 0.25), (0.9, 1.1, 0.0), (0.9, 0.45, -0.05)], [0.44, 0.42, 0.32])
    skin.mirror_ball((0.9, 1.45, -0.18), 0.4)
    skin.mirror_ellipsoid((0.9, 0.25, 0.38), (0.42, 0.26, 0.7))
    skin.mirror_ball((0.9, 0.22, 0.95), 0.26)

    c = cr.Creature(rig)
    c.skin(skin, faces=5200, paint_fn=cyclops_paint, uv_scale=0.8)

    eye = mk.Builder("eye")
    eye.sphere(0.3, 16, 10, (0, 7.17, 1.2), P["eye_white"])
    eye.sphere(0.165, 14, 8, (0, 7.17, 1.45), P["team_glow"], scale=(1, 1, 0.45))
    eye.sphere(0.065, 10, 6, (0, 7.17, 1.52), P["mouth"], scale=(0.8, 1.5, 0.4))
    c.attach(eye, bone="head")
    horns = mk.Builder("horns")
    for s in (-1, 1):
        horns.cylinder(0.14, 0.8, 8, (s * 0.46, 7.68, 0.55), P["horn"], rot=(-30, 0, -s * 25), r2=0.0)
    c.attach(horns, bone="head", uv_scale=1.0)
    tusks = mk.Builder("tusks")
    for s in (-1, 1):
        tusks.cylinder(0.08, 0.38, 6, (s * 0.26, 6.52, 1.32), P["horn"], rot=(-12, 0, -s * 16), r2=0.0)
    c.attach(tusks, bone="jaw", uv_scale=1.0)

    # belt, loincloth and a bandolier holding the team's aether crystal
    waist = [(math.sin(a) * 1.05, 3.78, 0.1 + math.cos(a) * 0.9) for a in (i / 16 * math.tau for i in range(16))]
    c.attach(strap(c, waist, 0.28, 0.07, P["leather"], closed=True, name="belt"), uv_scale=1.0)
    band = [(1.1, 6.15, 0.1), (0.6, 5.75, 0.9), (0.0, 5.2, 1.0), (-0.55, 4.6, 0.9), (-0.95, 3.95, 0.5)]
    back = [(1.1, 6.15, 0.1), (0.5, 5.6, -0.65), (-0.3, 4.8, -0.7), (-0.95, 3.95, -0.45)]
    c.attach(strap(c, band, 0.3, 0.06, P["leather"], name="band_front"), uv_scale=1.0)
    c.attach(strap(c, back, 0.3, 0.06, P["leather"], name="band_back"), uv_scale=1.0)
    gem = mk.Builder("gem")
    gem.cylinder(0.3, 0.14, 12, (0.02, 5.2, 0.96), P["brass"], rot=(80, 0, 0))
    gem.sphere(0.19, 6, 4, (0.02, 5.22, 1.08), P["team_glow"], scale=(0.8, 1.35, 0.6))
    gem.box((0.34, 0.12, 0.1), (0, 3.78, 1.0), P["brass"], bevel=0.02)
    c.attach(gem, uv_scale=1.0)
    cloth = mk.Builder("loincloth")
    cloth.box((0.74, 1.25, 0.06), (0, 3.18, 0.83), P["team_cloth"], rot=(10, 0, 0))
    cloth.box((1.05, 1.1, 0.06), (0, 3.22, -0.78), P["team_cloth"], rot=(10, 0, 0))
    cloth.box((0.78, 0.1, 0.08), (0, 2.56, 0.72), P["team_trim"])
    c.attach(cloth, bone="hips", uv_scale=1.0)

    # iron shoulder plates (left) and bracers
    top = mk.Builder("pauldron_top")
    top.box((1.2, 0.14, 1.2), (1.62, 6.42, 0.02), P["iron"], rot=(0, 0, -22), bevel=0.04)
    top.box((1.25, 0.06, 1.25), (1.62, 6.36, 0.02), P["brass"], rot=(0, 0, -22))
    c.attach(top, bone="clav_l", uv_scale=1.0)
    low = mk.Builder("pauldron_low")
    low.box((1.05, 0.13, 1.1), (1.98, 6.06, 0.04), P["iron"], rot=(0, 0, -45), bevel=0.04)
    low.box((0.95, 0.12, 1.0), (2.2, 5.66, 0.06), P["iron"], rot=(0, 0, -62), bevel=0.04)
    for k in range(4):
        low.sphere(0.05, 6, 4, (1.82 + k * 0.12, 6.22 - k * 0.12, 0.52), P["brass"])
    c.attach(low, bone="uparm_l", uv_scale=1.0)
    for s, side in ((1, "l"), (-1, "r")):
        elbow = Vector((s * 2.25, 4.2, 0.2))
        wrist = Vector((s * 2.5, 2.7, 0.7))
        for t, w, m in ((0.55, 0.62, "iron"), (0.3, 0.1, "brass"), (0.8, 0.1, "brass")):
            d, e1, e2 = basis(wrist - elbow)
            o = elbow.lerp(wrist, t)
            loop = [tuple(o + (e1 * math.cos(a) + e2 * math.sin(a)) * 0.9) for a in (k / 16 * math.tau for k in range(16))]
            c.attach(strap(c, loop, w, 0.07 if m == "iron" else 0.09, P[m], closed=True, n=20, name="bracer",
                           axis=(tuple(elbow), tuple(wrist))), bone="forearm_" + side, uv_scale=1.0)

    # the club: a banded log with iron spikes, gripped in the right fist
    club = mk.Builder("club")
    grip = Vector((-2.53, 2.35, 0.82))
    d, e1, e2 = basis((-0.05, -0.2, 1.0))
    base = grip - d * 0.55
    prof = [(0.18, 0.0), (0.16, 0.3), (0.16, 1.3), (0.24, 1.9), (0.38, 2.9), (0.5, 3.9), (0.52, 4.5), (0.42, 4.95), (0.0, 5.1)]
    club.lathe(prof, 12, tuple(base), P["wood"], rot=aim(d))
    for at, r in ((3.2, 0.46), (4.35, 0.54)):
        club.torus(r, 0.06, 14, 4, tuple(base + d * at), P["iron"], rot=aim(d))
    club.sphere(0.21, 8, 6, tuple(base), P["brass"])
    for k in range(10):
        a = k / 10 * math.tau + (0.3 if k % 2 else 0.0)
        out = e1 * math.cos(a) + e2 * math.sin(a)
        at = base + d * (3.55 + 0.45 * (k % 2)) + out * 0.48
        tube(club, at, at + out * 0.36, 0.07, P["iron_dark"], 6, r2=0.0)
    c.attach(club, bone="hand_r", uv_scale=1.0)
    return c


def sheet(b, outline, m, cuts=3, thick=0.07):
    """Thin closed sheet from a (roughly planar) outline of Godot points: triangulated,
    subdivided so it can bend with the bones, then given thickness."""
    bm = b.bm
    idx = b.slot(m)
    before = set(bm.faces)
    f = bm.faces.new([bm.verts.new(p) for p in outline])
    tris = bmesh.ops.triangulate(bm, faces=[f], quad_method="BEAUTY", ngon_method="BEAUTY")["faces"]
    bmesh.ops.subdivide_edges(bm, edges=list({e for t in tris for e in t.edges}), cuts=cuts, use_grid_fill=True)
    faces = [x for x in bm.faces if x not in before]
    bmesh.ops.triangulate(bm, faces=faces)
    faces = [x for x in bm.faces if x not in before]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    res = bmesh.ops.solidify(bm, geom=faces, thickness=thick)
    new = [x for x in bm.faces if x not in before]
    for x in new:
        x.material_index = idx
        x.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=new)
    del res
    return new


def mirror_pts(pts):
    return [(-x, y, z) for (x, y, z) in pts]


def near_bones(c, names, k=3, power=3.0):
    """Custom weights: inverse distance to the named bones (for membranes)."""
    def fn(p):
        return cr.weights_near(c.segs, cr.gvec(p), names, k, power)
    return fn


def dragon_paint(p, n):
    x, y, z = p
    c = mix(lin((0.33, 0.31, 0.29)), lin((0.68, 0.6, 0.45)), smooth(-0.15, -0.65, n[1]))
    c = mix(c, lin((0.2, 0.19, 0.18)), smooth(-7.5, -10.2, z) + smooth(6.6, 7.2, z) * 0.5)
    return c


def dragon(name):
    """Winged dragon: long neck and tail, bat wings with team-coloured membranes, glowing eyes."""
    P = mk.palette()
    rig = cr.Rig(name)
    rig.bone("pelvis", (0, 0.0, -1.6), (0, 0.1, 0.0))
    rig.bone("chest", (0, 0.1, 0.0), (0, 0.3, 1.8), "pelvis")
    neck = rig.chain("neck", [(0, 0.3, 1.8), (0, 0.75, 3.0), (0, 1.2, 4.1), (0, 1.55, 5.1)], "chest")
    rig.bone("head", (0, 1.55, 5.1), (0, 1.45, 6.9), neck[-1])
    rig.bone("jaw", (0, 1.3, 5.4), (0, 1.02, 6.8), "head")
    tail_pts = [(0, 0.0, -1.6), (0, -0.1, -3.2), (0, -0.2, -4.8), (0, -0.3, -6.3), (0, -0.4, -7.7), (0, -0.45, -9.0), (0, -0.5, -10.4)]
    rig.chain("tail", tail_pts, "pelvis")
    W = {"shoulder": (0.7, 0.55, 1.3), "elbow": (3.4, 1.1, 0.9), "wrist": (6.8, 1.2, 1.5),
         "f1": (10.8, 0.95, 0.0), "f2": (9.4, 0.85, -2.7), "f3": (7.0, 0.72, -4.1)}
    rig.mirror("humerus_l", W["shoulder"], W["elbow"], "chest")
    rig.mirror("forearm_l", W["elbow"], W["wrist"], "humerus_l")
    for f in ("f1", "f2", "f3"):
        rig.mirror(f + "_l", W["wrist"], W[f], "forearm_l")
    rig.mirror("thigh_l", (0.8, -0.3, -1.2), (1.2, -1.3, -0.7), "pelvis")
    rig.mirror("shin_l", (1.2, -1.3, -0.7), (1.2, -1.9, -1.8), "thigh_l")
    rig.mirror("foot_l", (1.2, -1.9, -1.8), (1.2, -2.25, -1.1), "shin_l")
    rig.mirror("arm_l", (0.7, -0.3, 1.3), (1.0, -1.1, 1.7), "chest")
    rig.mirror("paw_l", (1.0, -1.1, 1.7), (1.0, -1.55, 1.05), "arm_l")

    skin = cr.Body(name + "_skin", P["scales"], res=0.06)
    skin.ellipsoid((0, 0.15, 0.9), (1.2, 1.05, 1.6))
    skin.ellipsoid((0, 0.0, -1.0), (1.0, 0.92, 1.4))
    skin.mirror_ball((0.85, 0.55, 1.2), 0.55)
    skin.limb([(0, 0.35, 1.7), (0, 0.75, 3.0), (0, 1.2, 4.1), (0, 1.55, 5.1)], [0.82, 0.6, 0.48, 0.44])
    skin.ellipsoid((0, 1.6, 5.5), (0.5, 0.46, 0.68))
    skin.ellipsoid((0, 1.45, 6.35), (0.34, 0.28, 0.75))
    skin.ellipsoid((0, 1.15, 6.05), (0.31, 0.17, 0.75))
    skin.mirror_ellipsoid((0.24, 1.84, 5.85), (0.13, 0.1, 0.36))
    skin.limb(tail_pts, [0.82, 0.64, 0.5, 0.38, 0.27, 0.18, 0.07])
    skin.mirror_limb([W["shoulder"], W["elbow"]], [0.4, 0.25])
    skin.mirror_limb([W["elbow"], W["wrist"]], [0.24, 0.16])
    skin.mirror_ball(W["elbow"], 0.27)
    skin.mirror_ball(W["wrist"], 0.2)
    skin.mirror_ellipsoid((1.0, -0.55, -1.0), (0.48, 0.62, 0.6))
    skin.mirror_limb([(1.2, -1.3, -0.7), (1.2, -1.9, -1.8)], [0.3, 0.2])
    skin.mirror_ellipsoid((1.2, -2.12, -1.4), (0.22, 0.14, 0.45))
    skin.mirror_limb([(0.7, -0.3, 1.3), (1.0, -1.1, 1.7), (1.0, -1.5, 1.1)], [0.3, 0.22, 0.16])
    skin.mirror_ball((1.0, -1.56, 1.12), 0.18)

    c = cr.Creature(rig)
    fingers = ["f1_l", "f2_l", "f3_l", "f1_r", "f2_r", "f3_r"]
    c.skin(skin, faces=6000, paint_fn=dragon_paint, uv_scale=0.55, exclude=fingers)

    # finger spars and thumb claws
    for sx, side in ((1, "l"), (-1, "r")):
        wr = Vector((sx * W["wrist"][0], W["wrist"][1], W["wrist"][2]))
        for f in ("f1", "f2", "f3"):
            tip = Vector((sx * W[f][0], W[f][1], W[f][2]))
            sp = mk.Builder("spar")
            tube(sp, wr, tip, 0.12, P["scales"], 6, r2=0.035)
            c.attach(sp, bone=f + "_" + side, uv_scale=0.55, paint_fn=lambda p, n: lin((0.28, 0.27, 0.25)))
        cl = mk.Builder("thumb")
        tube(cl, wr, wr + Vector((sx * 0.2, 0.25, 0.55)), 0.09, P["claw"], 6, r2=0.0)
        c.attach(cl, bone="forearm_" + side)

    # membranes (team-coloured), bending with the arm, fingers and body
    def scallop(a, b, depth, n=4):
        a, b = Vector(a), Vector(b)
        mid_in = Vector(W["wrist"])
        out = []
        for k in range(1, n):
            t = k / n
            p = a.lerp(b, t)
            p = p.lerp(mid_in, depth * math.sin(t * math.pi))
            out.append(tuple(p))
        return out

    lead = [(0.8, 0.5, 1.45), (2.2, 0.85, 1.1), W["elbow"], (5.1, 1.15, 1.2), W["wrist"]]
    outline = (lead + [(8.8, 1.1, 0.75), W["f1"]] + scallop(W["f1"], W["f2"], 0.16) + [W["f2"]]
               + scallop(W["f2"], W["f3"], 0.18) + [W["f3"]]
               + [(5.4, 0.62, -3.4), (3.6, 0.5, -3.0), (2.1, 0.35, -2.55), (1.0, 0.2, -2.1), (0.95, 0.3, -0.6)])
    segs_l = [(Vector(W["wrist"]), Vector(W[f])) for f in ("f1", "f2", "f3")] + [(Vector(W["shoulder"]), Vector(W["elbow"])),
                                                                              (Vector(W["elbow"]), Vector(W["wrist"]))]

    def membrane_paint(p, n):
        q = Vector((abs(p[0]), p[1], p[2]))
        d = min(cr.seg_dist(q, a, b) for (a, b) in segs_l)
        return mix(lin((0.45, 0.42, 0.42)), lin((0.95, 0.92, 0.9)), smooth(0.1, 1.1, d))

    for sx, side, pts in ((1, "l", outline), (-1, "r", mirror_pts(outline))):
        mb = mk.Builder("membrane_" + side)
        sheet(mb, pts, P["membrane"], cuts=3, thick=0.07)
        bones = ["humerus_" + side, "forearm_" + side, "f1_" + side, "f2_" + side, "f3_" + side, "chest", "pelvis"]
        c.attach(mb, weights=near_bones(c, bones), uv_scale=1.3, paint_fn=membrane_paint)

    # head: eyes, horns, teeth; spines down the back
    head = mk.Builder("head_parts")
    for sx in (-1, 1):
        head.sphere(0.12, 10, 6, (sx * 0.34, 1.76, 5.95), P["team_glow"], scale=(0.55, 0.6, 1.0))
        tube(head, (sx * 0.28, 1.9, 5.25), (sx * 0.62, 2.35, 4.0), 0.17, P["horn"], 8, r2=0.0)
        tube(head, (sx * 0.4, 1.55, 5.6), (sx * 0.78, 1.72, 4.9), 0.09, P["horn"], 6, r2=0.0)
        for k in range(4):
            head.cylinder(0.05, 0.2, 5, (sx * 0.24, 1.2, 6.2 + k * 0.22), P["horn"], rot=(180, 0, 0), r2=0.0)
    c.attach(head, bone="head", uv_scale=1.0)
    jaw = mk.Builder("jaw_parts")
    for sx in (-1, 1):
        for k in range(3):
            jaw.cylinder(0.045, 0.16, 5, (sx * 0.22, 1.22, 6.1 + k * 0.24), P["horn"], r2=0.0)
    jaw.box((0.36, 0.06, 0.9), (0, 1.25, 6.2), P["mouth"])
    c.attach(jaw, bone="jaw", uv_scale=1.0)
    spines = mk.Builder("spines")
    spine_path = [(0, 1.02, 3.6), (0, 0.78, 2.6), (0, 1.12, 1.2), (0, 1.0, 0.0), (0, 0.9, -1.2), (0, 0.62, -2.6),
                  (0, 0.42, -3.9), (0, 0.28, -5.2), (0, 0.13, -6.5)]
    for i, (x, y, z) in enumerate(spine_path):
        size = 1.25 - i / len(spine_path) * 0.7
        tube(spines, (x, y - 0.15, z + 0.2), (x, y + 0.7 * size, z - 0.45 * size), 0.2 * size, P["claw"], 6, r2=0.0)
    for sx in (-1, 1):
        spines.lathe([(0.0, -0.3), (0.16, 0.0), (0.0, 0.5)], 5, (sx * 0.5, 1.0, 1.4), P["team_glow"], rot=(-20, 0, -sx * 25), smooth=False)
    c.attach(spines, uv_scale=1.0)
    claws = mk.Builder("claws")
    for sx in (-1, 1):
        for k in (-1, 0, 1):
            tube(claws, (sx * 1.2 + k * 0.1, -2.25, -1.1), (sx * 1.2 + k * 0.14, -2.4, -0.8), 0.05, P["claw"], 5, r2=0.0)
    c.attach(claws, weights=lambda p: {"foot_l" if p[0] > 0 else "foot_r": 1.0})
    return c


def griffin_front(p, n):
    x, y, z = p
    c = mix(lin((0.86, 0.8, 0.64)), lin((0.95, 0.93, 0.88)), smooth(0.9, 1.3, y))
    return mix(c, lin((0.62, 0.52, 0.36)), smooth(-0.1, -0.7, n[1]) * 0.5)


def griffin_back(p, n):
    x, y, z = p
    c = mix(lin((0.74, 0.54, 0.31)), lin((0.86, 0.72, 0.52)), smooth(-0.1, -0.7, n[1]))
    return mix(c, lin((0.35, 0.25, 0.16)), smooth(-3.1, -3.6, z))


def griffin(name):
    """Griffin: an eagle's head, wings and talons on a lion's body; team caparison and helm."""
    P = mk.palette()
    rig = cr.Rig(name)
    rig.bone("pelvis", (0, 0.0, -1.0), (0, 0.1, 0.2))
    rig.bone("chest", (0, 0.1, 0.2), (0, 0.35, 1.2), "pelvis")
    rig.bone("neck1", (0, 0.35, 1.2), (0, 0.9, 1.75), "chest")
    rig.bone("neck2", (0, 0.9, 1.75), (0, 1.35, 2.1), "neck1")
    rig.bone("head", (0, 1.35, 2.1), (0, 1.35, 2.9), "neck2")
    rig.bone("jaw", (0, 1.28, 2.45), (0, 1.12, 2.95), "head")
    rig.chain("tail", [(0, 0.05, -1.0), (0, -0.1, -1.9), (0, -0.3, -2.8), (0, -0.45, -3.6)], "pelvis")
    rig.mirror("wing_l", (0.45, 0.6, 0.9), (2.3, 0.85, 0.7), "chest")
    rig.mirror("wingfore_l", (2.3, 0.85, 0.7), (4.3, 0.95, 0.9), "wing_l")
    rig.mirror("winghand_l", (4.3, 0.95, 0.9), (6.0, 0.9, 0.15), "wingfore_l")
    rig.mirror("fleg_l", (0.4, -0.3, 0.9), (0.5, -1.0, 1.2), "chest")
    rig.mirror("fshin_l", (0.5, -1.0, 1.2), (0.5, -1.5, 1.0), "fleg_l")
    rig.mirror("talon_l", (0.5, -1.5, 1.0), (0.5, -1.62, 1.4), "fshin_l")
    rig.mirror("thigh_l", (0.42, -0.2, -0.8), (0.55, -0.9, -0.5), "pelvis")
    rig.mirror("shin_l", (0.55, -0.9, -0.5), (0.55, -1.4, -1.0), "thigh_l")
    rig.mirror("foot_l", (0.55, -1.4, -1.0), (0.55, -1.6, -0.7), "shin_l")

    front = cr.Body(name + "_front", P["feather"], res=0.035)
    front.ellipsoid((0, 0.2, 0.55), (0.6, 0.62, 0.8))
    front.ball((0, 0.75, 1.3), 0.46)
    front.limb([(0, 0.4, 1.1), (0, 0.9, 1.75), (0, 1.35, 2.1)], [0.46, 0.33, 0.29])
    front.ellipsoid((0, 1.42, 2.36), (0.3, 0.3, 0.42))
    front.mirror_ball((0.42, 0.62, 0.9), 0.3)
    front.mirror_limb([(0.4, -0.2, 0.85), (0.5, -1.0, 1.2)], [0.26, 0.16])
    back = cr.Body(name + "_back", P["fur"], res=0.035)
    back.ellipsoid((0, 0.05, -0.35), (0.53, 0.53, 0.9))
    back.ellipsoid((0, 0.05, -0.95), (0.5, 0.5, 0.45))
    back.mirror_ellipsoid((0.33, -0.1, -0.95), (0.28, 0.5, 0.42))
    back.mirror_limb([(0.55, -0.9, -0.5), (0.55, -1.4, -1.0), (0.55, -1.58, -0.72)], [0.2, 0.13, 0.1])
    back.limb([(0, 0.05, -1.3), (0, -0.1, -1.9), (0, -0.3, -2.8), (0, -0.45, -3.4)], [0.13, 0.09, 0.07, 0.06])
    back.ellipsoid((0, -0.5, -3.55), (0.16, 0.16, 0.3))

    c = cr.Creature(rig)
    c.skin(front, faces=3000, paint_fn=griffin_front, uv_scale=1.4)
    c.skin(back, faces=2200, paint_fn=griffin_back, uv_scale=1.4)

    # feathered wings with long primaries; team-dyed tips
    lead = [(0.45, 0.62, 1.0), (1.4, 0.75, 0.85), (2.3, 0.87, 0.78), (3.3, 0.93, 0.85), (4.3, 0.97, 0.95), (5.2, 0.95, 0.65), (6.0, 0.9, 0.15)]
    trail = [(5.75, 0.88, -0.35), (5.45, 0.88, -0.25), (5.3, 0.86, -0.85), (4.95, 0.85, -0.7), (4.75, 0.84, -1.3),
             (4.35, 0.83, -1.1), (4.1, 0.82, -1.6), (3.6, 0.8, -1.35), (3.3, 0.78, -1.75), (2.6, 0.72, -1.45),
             (1.8, 0.64, -1.45), (1.0, 0.5, -1.15), (0.5, 0.4, -0.6)]
    outline = lead + trail

    def wing_paint(p, n):
        return mix(lin((0.9, 0.84, 0.7)), lin((0.55, 0.42, 0.28)), smooth(3.8, 5.6, abs(p[0])))

    for sx, side, pts in ((1, "l", outline), (-1, "r", mirror_pts(outline))):
        wb = mk.Builder("wing_" + side)
        sheet(wb, pts, P["feather"], cuts=2, thick=0.08)
        bones = ["wing_" + side, "wingfore_" + side, "winghand_" + side, "chest"]
        c.attach(wb, weights=near_bones(c, bones), uv_scale=1.1, paint_fn=wing_paint)
        tips = mk.Builder("tips_" + side)
        for (x, y, z) in trail[:6:2]:
            tube(tips, (sx * (x - 0.35), y, z + 0.35), (sx * x, y, z), 0.09, P["team_cloth"], 5, r2=0.02)
        c.attach(tips, bone="winghand_" + side, uv_scale=1.0)

    head = mk.Builder("head_parts")
    tube(head, (0, 1.44, 2.6), (0, 1.3, 3.15), 0.16, P["brass"], 8, r2=0.05)
    tube(head, (0, 1.32, 3.12), (0, 1.12, 3.2), 0.06, P["brass"], 6, r2=0.0)
    for sx in (-1, 1):
        head.sphere(0.07, 8, 6, (sx * 0.2, 1.5, 2.55), P["team_glow"], scale=(0.6, 0.8, 1.0))
        tube(head, (sx * 0.16, 1.62, 2.2), (sx * 0.3, 1.9, 1.75), 0.08, P["feather"], 5, r2=0.0)
    for k, (dx, h) in enumerate(((0.0, 0.55), (-0.1, 0.42), (0.1, 0.42))):
        tube(head, (dx, 1.68, 2.3 - k * 0.04), (dx * 2.2, 1.68 + h, 1.95 - k * 0.05), 0.06, P["team_cloth"], 5, r2=0.0)
    c.attach(head, bone="head", uv_scale=1.0)
    jaw = mk.Builder("jaw_parts")
    tube(jaw, (0, 1.24, 2.62), (0, 1.16, 2.98), 0.1, P["brass"], 6, r2=0.03)
    c.attach(jaw, bone="jaw", uv_scale=1.0)
    for sx, side in ((1, "l"), (-1, "r")):
        leg = mk.Builder("talons_" + side)
        tube(leg, (sx * 0.5, -0.95, 1.18), (sx * 0.5, -1.5, 1.0), 0.09, P["horn"], 6)
        for k in (-1, 0, 1):
            tube(leg, (sx * 0.5 + k * 0.07, -1.52, 1.0), (sx * 0.5 + k * 0.12, -1.66, 1.38), 0.05, P["claw"], 5, r2=0.0)
        tube(leg, (sx * 0.5, -1.5, 1.0), (sx * 0.5, -1.62, 0.78), 0.045, P["claw"], 5, r2=0.0)
        c.attach(leg, weights=lambda p, s=side: {("talon_" if p[1] < -1.45 else "fshin_") + s: 1.0}, uv_scale=1.0)
    # saddle, caparison and a brass collar
    c.attach(strap(c, [(0.62, 0.35, 0.05), (0.3, 0.62, 0.0), (0.0, 0.66, 0.0), (-0.3, 0.62, 0.0), (-0.62, 0.35, 0.05)],
                   1.0, 0.05, P["team_cloth"], name="caparison"), uv_scale=1.0)
    saddle = mk.Builder("saddle")
    saddle.box((0.55, 0.16, 0.7), (0, 0.66, 0.1), P["leather"], bevel=0.04)
    saddle.box((0.6, 0.28, 0.1), (0, 0.78, 0.44), P["brass"], bevel=0.03)
    c.attach(saddle, uv_scale=1.0)
    collar = [(math.sin(a) * 0.55, 0.62 + math.cos(a) * 0.1, 1.38 + math.cos(a) * 0.42) for a in (k / 12 * math.tau for k in range(12))]
    c.attach(strap(c, collar, 0.14, 0.05, P["brass"], closed=True, n=16, name="collar",
                   axis=((0, 0.35, 1.2), (0, 0.9, 1.75))), uv_scale=1.0)
    return c


def cerberus_paint(p, n):
    x, y, z = p
    c = mix(lin((0.24, 0.22, 0.21)), lin((0.36, 0.33, 0.3)), smooth(-0.1, -0.7, n[1]))
    return mix(c, lin((0.13, 0.12, 0.12)), smooth(0.5, 0.15, y))


def cerberus(name):
    """Three-headed hound: glowing eyes and ember throats, spiked team collars, an iron back plate."""
    P = mk.palette()
    rig = cr.Rig(name)
    rig.bone("pelvis", (0, 2.0, -1.1), (0, 2.1, 0.0))
    rig.bone("chest", (0, 2.1, 0.0), (0, 2.3, 1.1), "pelvis")
    heads = {"c": ((0, 2.3, 1.1), (0, 2.95, 1.8), (0, 2.85, 2.75)),
             "l": ((0.36, 2.25, 1.02), (0.85, 2.72, 1.55), (1.12, 2.58, 2.42))}
    heads["r"] = tuple((-a, b, c_) for (a, b, c_) in heads["l"])
    for k, (base, top, nose) in heads.items():
        rig.bone("neck_" + k, base, top, "chest")
        rig.bone("head_" + k, top, nose, "neck_" + k)
        mid = Vector(top).lerp(Vector(nose), 0.25) + Vector((0, -0.15, 0))
        rig.bone("jaw_" + k, tuple(mid), tuple(Vector(nose) + Vector((0, -0.3, -0.05))), "head_" + k)
    rig.mirror("upper_l", (0.5, 1.8, 0.9), (0.55, 0.9, 1.0), "chest")
    rig.mirror("lower_l", (0.55, 0.9, 1.0), (0.55, 0.2, 0.9), "upper_l")
    rig.mirror("paw_l", (0.55, 0.2, 0.9), (0.55, 0.05, 1.25), "lower_l")
    rig.mirror("thigh_l", (0.5, 1.9, -1.1), (0.55, 1.1, -0.7), "pelvis")
    rig.mirror("shin_l", (0.55, 1.1, -0.7), (0.55, 0.5, -1.2), "thigh_l")
    rig.mirror("foot_l", (0.55, 0.5, -1.2), (0.55, 0.05, -0.95), "shin_l")
    rig.chain("tail", [(0, 2.1, -1.2), (0, 2.3, -1.9), (0, 2.2, -2.6), (0, 1.9, -3.2)], "pelvis")

    skin = cr.Body(name + "_skin", P["fur"], res=0.045)
    skin.ellipsoid((0, 2.05, 0.55), (0.62, 0.72, 0.85))
    skin.ellipsoid((0, 2.12, -0.4), (0.48, 0.48, 0.75))
    skin.ellipsoid((0, 2.05, -1.0), (0.55, 0.55, 0.55))
    for k, (base, top, nose) in heads.items():
        skin.limb([base, top], [0.42, 0.3])
        tv, nv = Vector(top), Vector(nose)
        d = (nv - tv).normalized()
        skin.ellipsoid(tuple(tv + d * 0.2), (0.28, 0.27, 0.34))
        skin.ellipsoid(tuple(tv + d * 0.65 + Vector((0, -0.06, 0))), (0.17, 0.15, 0.3))
        skin.ellipsoid(tuple(tv + d * 0.55 + Vector((0, -0.24, 0))), (0.15, 0.08, 0.3))
    skin.mirror_ball((0.5, 1.9, 0.8), 0.38)
    skin.mirror_limb([(0.5, 1.8, 0.9), (0.55, 0.9, 1.0), (0.55, 0.2, 0.9)], [0.28, 0.19, 0.14])
    skin.mirror_ellipsoid((0.55, 0.12, 1.06), (0.17, 0.12, 0.25))
    skin.mirror_ellipsoid((0.45, 1.62, -1.0), (0.3, 0.5, 0.42))
    skin.mirror_limb([(0.55, 1.1, -0.7), (0.55, 0.5, -1.2), (0.55, 0.1, -0.95)], [0.2, 0.15, 0.13])
    skin.mirror_ellipsoid((0.55, 0.1, -0.85), (0.16, 0.11, 0.24))
    skin.limb([(0, 2.1, -1.2), (0, 2.3, -1.9), (0, 2.2, -2.6), (0, 1.9, -3.2)], [0.15, 0.11, 0.08, 0.05])

    c = cr.Creature(rig)
    c.skin(skin, faces=5200, paint_fn=cerberus_paint, uv_scale=1.2)
    for k, (base, top, nose) in heads.items():
        tv, nv = Vector(top), Vector(nose)
        d, e1, e2 = basis(nv - tv)
        side = e1 if e1.x >= 0 else -e1
        hp = mk.Builder("head_" + k)
        for sx in (-1, 1):
            eye = tv + d * 0.42 + side * sx * 0.17 + Vector((0, 0.1, 0))
            hp.sphere(0.055, 8, 6, tuple(eye), P["team_glow"])
            ear = tv + d * 0.05 + side * sx * 0.17 + Vector((0, 0.2, 0))
            tube(hp, ear, ear + Vector((sx * side.x * 0.12, 0.34, -0.12)), 0.1, P["fur"], 5, r2=0.0)
            for t in (0.62, 0.78):
                tooth = tv + d * t + side * sx * 0.1 + Vector((0, -0.14, 0))
                tube(hp, tooth, tooth + Vector((0, -0.12, 0)), 0.03, P["horn"], 5, r2=0.0)
        hp.sphere(0.12, 8, 6, tuple(tv + d * 0.55 + Vector((0, -0.14, 0))), P["team_glow"], scale=(1.0, 0.6, 1.6))
        c.attach(hp, bone="head_" + k, uv_scale=1.2, paint_fn=cerberus_paint)
        # spiked collar
        loop = [tuple(Vector(base).lerp(tv, 0.35) + (e1 * math.cos(a) + e2 * math.sin(a)) * 0.7) for a in (i / 12 * math.tau for i in range(12))]
        c.attach(strap(c, loop, 0.2, 0.06, P["team_trim"], closed=True, n=16, name="collar", axis=(base, top)),
                 bone="neck_" + k, uv_scale=1.0)
        sp = mk.Builder("spikes_" + k)
        for i in range(6):
            a = i / 6 * math.tau
            out = (e1 * math.cos(a) + e2 * math.sin(a))
            at = Vector(base).lerp(tv, 0.35) + out * 0.42
            tube(sp, at, at + out * 0.16, 0.035, P["iron"], 5, r2=0.0)
        c.attach(sp, bone="neck_" + k, uv_scale=1.0)
    plate = mk.Builder("plate")
    plate.box((0.8, 0.12, 1.0), (0, 2.66, -0.2), P["iron"], rot=(4, 0, 0), bevel=0.04)
    plate.box((0.84, 0.05, 1.04), (0, 2.6, -0.2), P["brass"], rot=(4, 0, 0))
    for z in (-0.55, 0.15):
        tube(plate, (0, 2.7, z), (0, 2.95, z - 0.2), 0.08, P["iron_dark"], 5, r2=0.0)
    c.attach(plate, uv_scale=1.0)
    cloth = [(0.55, 2.2, -0.9), (0.3, 2.55, -0.9), (0.0, 2.6, -0.9), (-0.3, 2.55, -0.9), (-0.55, 2.2, -0.9)]
    c.attach(strap(c, cloth, 0.7, 0.04, P["team_cloth"], name="blanket"), uv_scale=1.0)
    claws = mk.Builder("claws")
    for sx in (-1, 1):
        for (z0, bone) in ((1.25, "paw"), (-0.62, "foot")):
            for k in (-1, 0, 1):
                tube(claws, (sx * 0.55 + k * 0.08, 0.08, z0 - 0.05), (sx * 0.55 + k * 0.1, 0.02, z0 + 0.1), 0.035, P["claw"], 4, r2=0.0)
    c.attach(claws, weights=lambda p: {("paw_" if p[2] > 0 else "foot_") + ("l" if p[0] > 0 else "r"): 1.0})
    return c


def taper(b, pts, r0, r1, m, seg=8):
    """Tapered tube through a polyline (horns): radius r0 at the root down to r1 at the tip."""
    n = len(pts) - 1
    for i in range(n):
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        tube(b, pts[i], pts[i + 1], ra, m, seg, r2=rb)


def demon_paint(p, n):
    x, y, z = p
    c = mix(lin((0.30, 0.09, 0.08)), lin((0.46, 0.17, 0.12)), smooth(0.0, 0.8, n[2]) * smooth(2.6, 3.4, y))
    c = mix(c, lin((0.12, 0.05, 0.05)), max(smooth(1.2, 0.3, y), smooth(2.9, 2.3, y) * smooth(1.5, 1.8, abs(x))))
    return mix(c, lin((0.2, 0.06, 0.06)), smooth(-0.3, -1.2, z) * 0.6)


def demon(name):
    """Demon: ram horns, bat wings with team-coloured membranes, a barbed tail, burning claws
    and ember veins; hooved legs that bend backward."""
    P = mk.palette()
    rig = cr.Rig(name)
    rig.bone("hips", (0, 3.0, 0), (0, 3.9, 0.05))
    rig.bone("spine", (0, 3.9, 0.05), (0, 4.7, 0.1), "hips")
    rig.bone("chest", (0, 4.7, 0.1), (0, 5.3, 0.15), "spine")
    rig.bone("neck", (0, 5.3, 0.15), (0, 5.7, 0.35), "chest")
    rig.bone("head", (0, 5.7, 0.35), (0, 6.5, 0.55), "neck")
    rig.bone("jaw", (0, 5.8, 0.55), (0, 5.55, 0.95), "head")
    rig.mirror("clav_l", (0.25, 5.1, 0.05), (1.15, 5.15, 0.0), "chest")
    rig.mirror("uparm_l", (1.15, 5.15, 0.0), (1.6, 3.9, 0.1), "clav_l")
    rig.mirror("forearm_l", (1.6, 3.9, 0.1), (1.8, 2.75, 0.5), "uparm_l")
    rig.mirror("hand_l", (1.8, 2.75, 0.5), (1.85, 2.2, 0.75), "forearm_l")
    rig.mirror("thigh_l", (0.5, 2.95, 0.0), (0.6, 1.7, 0.4), "hips")
    rig.mirror("shin_l", (0.6, 1.7, 0.4), (0.6, 0.5, -0.2), "thigh_l")
    rig.mirror("foot_l", (0.6, 0.5, -0.2), (0.6, 0.12, 0.35), "shin_l")
    tail_pts = [(0, 3.0, -0.35), (0, 2.6, -1.2), (0, 2.0, -2.0), (0, 1.55, -2.8), (0, 1.35, -3.5)]
    rig.chain("tail", tail_pts, "hips")
    W = {"root": (0.35, 5.0, -0.4), "elbow": (1.3, 5.9, -0.85), "wrist": (2.5, 6.55, -1.15),
         "f1": (3.6, 5.7, -1.45), "f2": (3.1, 4.55, -1.4), "f3": (2.05, 3.85, -1.2)}
    rig.mirror("wing_l", W["root"], W["elbow"], "chest")
    rig.mirror("wingfore_l", W["elbow"], W["wrist"], "wing_l")
    for f in ("f1", "f2", "f3"):
        rig.mirror(f + "_l", W["wrist"], W[f], "wingfore_l")

    skin = cr.Body(name + "_skin", P["hide"], res=0.05)
    skin.ellipsoid((0, 3.05, 0.0), (0.62, 0.45, 0.48))
    skin.ellipsoid((0, 3.62, 0.08), (0.55, 0.55, 0.45))
    skin.ellipsoid((0, 4.5, 0.1), (0.85, 0.68, 0.58))
    skin.mirror_ellipsoid((0.38, 4.72, 0.42), (0.4, 0.3, 0.25), rot=(0, 0, -10))
    skin.ellipsoid((0, 4.95, -0.12), (0.92, 0.42, 0.5))
    skin.mirror_ball((1.1, 5.1, 0.0), 0.42)
    skin.capsule((0, 5.2, 0.15), (0, 5.75, 0.38), 0.3)
    skin.ellipsoid((0, 6.0, 0.5), (0.38, 0.45, 0.42))
    skin.ellipsoid((0, 6.2, 0.8), (0.36, 0.1, 0.13))
    skin.ellipsoid((0, 5.72, 0.72), (0.3, 0.18, 0.3))
    skin.mirror_limb([(1.15, 5.15, 0.0), (1.38, 4.5, 0.05), (1.6, 3.9, 0.1)], [0.38, 0.32, 0.26])
    skin.mirror_limb([(1.6, 3.9, 0.1), (1.7, 3.3, 0.3), (1.8, 2.75, 0.5)], [0.27, 0.31, 0.2])
    skin.mirror_ellipsoid((1.84, 2.42, 0.64), (0.22, 0.28, 0.22))
    skin.mirror_limb([(0.5, 2.95, 0.0), (0.55, 2.3, 0.22), (0.6, 1.7, 0.4)], [0.45, 0.4, 0.28])
    skin.mirror_limb([(0.6, 1.7, 0.4), (0.6, 1.1, 0.1), (0.6, 0.5, -0.2)], [0.26, 0.22, 0.16])
    skin.mirror_ellipsoid((0.6, 0.28, 0.1), (0.2, 0.22, 0.34))
    skin.limb(tail_pts, [0.2, 0.15, 0.1, 0.07, 0.04])

    c = cr.Creature(rig)
    fingers = ["f1_l", "f2_l", "f3_l", "f1_r", "f2_r", "f3_r", "wing_l", "wing_r", "wingfore_l", "wingfore_r"]
    c.skin(skin, faces=5200, paint_fn=demon_paint, uv_scale=0.9, exclude=fingers)

    # ram horns, glowing eyes, an ember throat
    head = mk.Builder("head_parts")
    for sx in (-1, 1):
        taper(head, [(sx * 0.24, 6.3, 0.55), (sx * 0.55, 6.62, 0.42), (sx * 0.8, 6.95, 0.1), (sx * 0.82, 7.3, -0.25), (sx * 0.62, 7.55, -0.42)],
              0.17, 0.02, P["claw"])
        head.sphere(0.075, 8, 6, (sx * 0.15, 6.05, 0.87), P["team_glow"], scale=(1.3, 0.7, 0.6))
        for k in range(2):
            tube(head, (sx * (0.1 + k * 0.1), 5.66, 0.95 - k * 0.05), (sx * (0.1 + k * 0.1), 5.52, 0.97 - k * 0.05), 0.035, P["horn"], 5, r2=0.0)
    c.attach(head, bone="head", uv_scale=1.0)
    jaw = mk.Builder("jaw_parts")
    jaw.sphere(0.13, 8, 6, (0, 5.66, 0.86), P["fire_glow"], scale=(1.3, 0.45, 0.8))
    c.attach(jaw, bone="jaw", uv_scale=1.0)

    # wings: spars along the arm and fingers, team-coloured membranes between them
    for sx, side in ((1, "l"), (-1, "r")):
        m = lambda q: (sx * q[0], q[1], q[2])
        for a, b, bone in (("root", "elbow", "wing_"), ("elbow", "wrist", "wingfore_")):
            sp = mk.Builder("wing_arm")
            tube(sp, m(W[a]), m(W[b]), 0.13 if a == "root" else 0.1, P["hide"], 6, r2=0.08)
            c.attach(sp, bone=bone + side, uv_scale=0.9, paint_fn=lambda p, n: lin((0.22, 0.07, 0.06)))
        for f in ("f1", "f2", "f3"):
            sp = mk.Builder("spar")
            tube(sp, m(W["wrist"]), m(W[f]), 0.07, P["claw"], 6, r2=0.02)
            c.attach(sp, bone=f + "_" + side, uv_scale=0.9)
        cl = mk.Builder("wing_claw")
        tube(cl, m(W["wrist"]), m((W["wrist"][0] + 0.15, W["wrist"][1] + 0.45, W["wrist"][2] + 0.1)), 0.07, P["claw"], 5, r2=0.0)
        c.attach(cl, bone="wingfore_" + side)

    def scallop(a, b, depth, n=4):
        a, b = Vector(a), Vector(b)
        inner = Vector(W["wrist"])
        return [tuple(a.lerp(b, k / n).lerp(inner, depth * math.sin(k / n * math.pi))) for k in range(1, n)]

    outline = ([W["root"], (0.8, 5.5, -0.62), W["elbow"], (1.9, 6.25, -1.0), W["wrist"], (3.1, 6.2, -1.35), W["f1"]]
               + scallop(W["f1"], W["f2"], 0.2) + [W["f2"]] + scallop(W["f2"], W["f3"], 0.22) + [W["f3"]]
               + [(1.3, 3.95, -0.95), (0.6, 4.25, -0.62)])
    for sx, side, pts in ((1, "l", outline), (-1, "r", mirror_pts(outline))):
        mb = mk.Builder("membrane_" + side)
        sheet(mb, pts, P["membrane"], cuts=2, thick=0.06)
        bones = ["wing_" + side, "wingfore_" + side, "f1_" + side, "f2_" + side, "f3_" + side, "chest"]
        c.attach(mb, weights=near_bones(c, bones), uv_scale=1.2,
                 paint_fn=lambda p, n: mix(lin((0.5, 0.42, 0.42)), lin((0.95, 0.9, 0.88)), smooth(0.6, 2.2, abs(p[0]))))

    # claws, barbed tail tip, hooves
    for sx, side in ((1, "l"), (-1, "r")):
        cl = mk.Builder("claws_" + side)
        for k in range(4):
            root = Vector((sx * (1.72 + k * 0.07), 2.22, 0.78 - k * 0.1))
            tube(cl, tuple(root), tuple(root + Vector((sx * 0.04, -0.34, 0.2))), 0.05, P["claw"], 5, r2=0.0)
        c.attach(cl, bone="hand_" + side, uv_scale=1.0)
    tip = mk.Builder("tail_tip")
    tip.sphere(0.24, 8, 6, (0, 1.32, -3.62), P["claw"], scale=(1.0, 0.25, 1.4))
    tube(tip, (0, 1.32, -3.5), (0, 1.3, -4.05), 0.1, P["claw"], 6, r2=0.0)
    c.attach(tip, bone="tail4", uv_scale=1.0)
    hooves = mk.Builder("hooves")
    for sx in (-1, 1):
        hooves.cylinder(0.2, 0.16, 10, (sx * 0.6, 0.08, 0.18), P["claw"], r2=0.17)
    c.attach(hooves, weights=lambda p: {"foot_l" if p[0] > 0 else "foot_r": 1.0})

    # ember veins on chest and forearms
    for sx in (-1, 1):
        for pts in ([(sx * 0.55, 4.95, 0.55), (sx * 0.32, 4.5, 0.66), (sx * 0.12, 4.05, 0.58), (sx * 0.05, 3.62, 0.55)],
                    [(sx * 1.68, 3.75, 0.32), (sx * 1.8, 3.3, 0.5), (sx * 1.9, 2.9, 0.66)]):
            c.attach(strap(c, pts, 0.07, 0.02, P["fire_glow"], lift=0.01, n=10, name="vein"), uv_scale=1.0)
    rune = mk.Builder("rune")
    rune.sphere(0.13, 6, 4, (0, 4.72, 0.7), P["team_glow"], scale=(1.0, 1.4, 0.35))
    c.attach(rune, uv_scale=1.0)

    # belt, loincloth
    waist = [(math.sin(a) * 0.66, 3.3, 0.04 + math.cos(a) * 0.54) for a in (i / 16 * math.tau for i in range(16))]
    c.attach(strap(c, waist, 0.22, 0.06, P["leather"], closed=True, name="belt"), uv_scale=1.0)
    cloth = mk.Builder("loincloth")
    cloth.box((0.52, 0.95, 0.05), (0, 2.82, 0.58), P["team_cloth"], rot=(8, 0, 0))
    cloth.box((0.7, 0.85, 0.05), (0, 2.86, -0.52), P["team_cloth"], rot=(-8, 0, 0))
    cloth.box((0.56, 0.08, 0.07), (0, 2.38, 0.52), P["team_trim"])
    buckle = mk.Builder("buckle")
    buckle.cylinder(0.16, 0.08, 10, (0, 3.3, 0.62), P["brass"], rot=(80, 0, 0))
    buckle.sphere(0.08, 6, 4, (0, 3.3, 0.68), P["team_glow"])
    c.attach(cloth, bone="hips", uv_scale=1.0)
    c.attach(buckle, bone="hips", uv_scale=1.0)
    return c


def angel_paint(p, n):
    x, y, z = p
    return mix(lin((0.93, 0.82, 0.72)), lin((0.78, 0.64, 0.56)), smooth(0.2, -0.8, n[1]) * 0.6)


def angel(name):
    """Angel: feathered wings with team-dyed primaries, a halo, a robe in team colours over
    brass armour, and a lance with a glowing head. Origin at the body centre (a flyer)."""
    P = mk.palette()
    rig = cr.Rig(name)
    rig.bone("pelvis", (0, -0.6, 0), (0, 0.0, 0.0))
    rig.bone("spine", (0, 0.0, 0.0), (0, 0.7, 0.02), "pelvis")
    rig.bone("chest", (0, 0.7, 0.02), (0, 1.2, 0.05), "spine")
    rig.bone("neck", (0, 1.2, 0.05), (0, 1.55, 0.1), "chest")
    rig.bone("head", (0, 1.55, 0.1), (0, 2.15, 0.12), "neck")
    rig.mirror("clav_l", (0.15, 1.1, 0.0), (0.5, 1.12, 0.0), "chest")
    rig.mirror("uparm_l", (0.5, 1.12, 0.0), (0.62, 0.35, 0.05), "clav_l")
    rig.mirror("forearm_l", (0.62, 0.35, 0.05), (0.66, -0.35, 0.25), "uparm_l")
    rig.mirror("hand_l", (0.66, -0.35, 0.25), (0.66, -0.6, 0.35), "forearm_l")
    rig.mirror("thigh_l", (0.2, -0.6, 0.0), (0.24, -1.45, 0.1), "pelvis")
    rig.mirror("shin_l", (0.24, -1.45, 0.1), (0.24, -2.25, -0.05), "thigh_l")
    rig.mirror("foot_l", (0.24, -2.25, -0.05), (0.24, -2.4, 0.25), "shin_l")
    lead = [(0.2, 1.0, -0.25), (0.9, 1.2, -0.3), (1.6, 1.38, -0.35), (2.4, 1.55, -0.35), (3.2, 1.7, -0.3), (3.9, 1.75, -0.45), (4.5, 1.7, -0.9)]
    trail = [(4.3, 1.62, -1.35), (3.95, 1.6, -1.2), (3.8, 1.52, -1.75), (3.4, 1.5, -1.55), (3.2, 1.42, -2.05), (2.8, 1.38, -1.8),
             (2.5, 1.3, -2.15), (2.0, 1.22, -1.85), (1.7, 1.12, -2.0), (1.2, 1.02, -1.6), (0.7, 0.92, -1.3), (0.25, 0.85, -0.7)]
    rig.mirror("wing_l", lead[0], lead[2], "chest")
    rig.mirror("wingfore_l", lead[2], lead[4], "wing_l")
    rig.mirror("winghand_l", lead[4], lead[6], "wingfore_l")

    skin = cr.Body(name + "_skin", P["hide"], res=0.03)
    skin.ellipsoid((0, 1.85, 0.15), (0.2, 0.26, 0.22))
    skin.capsule((0, 1.35, 0.06), (0, 1.62, 0.1), 0.1)
    skin.ellipsoid((0, 0.9, 0.03), (0.36, 0.32, 0.22))
    skin.ellipsoid((0, 0.4, 0.02), (0.3, 0.35, 0.2))
    skin.ellipsoid((0, -0.3, 0.0), (0.3, 0.28, 0.2))
    skin.mirror_ball((0.48, 1.1, 0.0), 0.15)
    skin.mirror_limb([(0.5, 1.12, 0.0), (0.56, 0.74, 0.02), (0.62, 0.35, 0.05)], [0.13, 0.11, 0.09])
    skin.mirror_limb([(0.62, 0.35, 0.05), (0.64, 0.0, 0.15), (0.66, -0.35, 0.25)], [0.09, 0.09, 0.07])
    skin.mirror_ellipsoid((0.66, -0.45, 0.3), (0.07, 0.11, 0.08))
    skin.mirror_limb([(0.2, -0.6, 0.0), (0.22, -1.0, 0.05), (0.24, -1.45, 0.1)], [0.16, 0.14, 0.11])
    skin.mirror_limb([(0.24, -1.45, 0.1), (0.24, -1.85, 0.03), (0.24, -2.25, -0.05)], [0.1, 0.09, 0.07])
    skin.mirror_ellipsoid((0.24, -2.33, 0.1), (0.07, 0.06, 0.16))

    c = cr.Creature(rig)
    c.skin(skin, faces=3200, paint_fn=angel_paint, uv_scale=1.6, exclude=["wing_l", "wing_r", "wingfore_l", "wingfore_r", "winghand_l", "winghand_r"])

    # wings
    outline = lead + trail

    def wing_paint(p, n):
        return mix(lin((0.97, 0.95, 0.9)), lin((0.84, 0.8, 0.72)), smooth(-0.8, -2.0, p[2]) * 0.6)

    for sx, side, pts in ((1, "l", outline), (-1, "r", mirror_pts(outline))):
        wb = mk.Builder("wing_" + side)
        sheet(wb, pts, P["feather"], cuts=2, thick=0.07)
        c.attach(wb, weights=near_bones(c, ["wing_" + side, "wingfore_" + side, "winghand_" + side, "chest"]), uv_scale=1.4, paint_fn=wing_paint)
        tips = mk.Builder("tips_" + side)
        for (x, y, z) in trail[:8:2]:
            tube(tips, (sx * x, y, z + 0.4), (sx * x, y - 0.02, z - 0.05), 0.08, P["team_cloth"], 5, r2=0.02)
        c.attach(tips, bone="winghand_" + side, uv_scale=1.0)

    # head: golden hair, glowing eyes, halo
    head = mk.Builder("head_parts")
    head.sphere(0.24, 12, 8, (0, 1.97, -0.04), P["hide"], scale=(1.05, 0.85, 0.95))
    head.sphere(0.2, 10, 6, (0, 1.72, -0.16), P["hide"], scale=(1.1, 1.2, 0.7))
    c.attach(head, bone="head", uv_scale=1.8, paint_fn=lambda p, n: lin((0.86, 0.68, 0.32)))
    glow = mk.Builder("head_glow")
    for sx in (-1, 1):
        glow.sphere(0.035, 6, 4, (sx * 0.08, 1.88, 0.35), P["team_glow"])
    glow.torus(0.3, 0.035, 20, 6, (0, 2.32, -0.08), P["team_glow"], rot=(-18, 0, 0))
    c.attach(glow, bone="head", uv_scale=1.0)

    # brass cuirass and pauldrons, robe in team colours
    armour = mk.Builder("cuirass")
    armour.sphere(0.36, 16, 10, (0, 0.85, 0.05), P["brass"], scale=(1.12, 1.0, 0.78))
    armour.torus(0.33, 0.05, 16, 4, (0, -0.02, 0.0), P["brass"])
    armour.sphere(0.07, 6, 4, (0, 0.88, 0.33), P["team_glow"], scale=(1.0, 1.3, 0.5))
    c.attach(armour, bone="chest", uv_scale=1.0)
    for sx, side in ((1, "l"), (-1, "r")):
        pd = mk.Builder("pauldron_" + side)
        pd.sphere(0.17, 10, 6, (sx * 0.52, 1.14, 0.0), P["brass"], scale=(1.25, 0.7, 1.1))
        c.attach(pd, bone="clav_" + side, uv_scale=1.0)
        br = mk.Builder("bracer_" + side)
        tube(br, (sx * 0.64, -0.02, 0.15), (sx * 0.66, -0.3, 0.24), 0.1, P["brass"], 8)
        c.attach(br, bone="forearm_" + side, uv_scale=1.0)
    robe = mk.Builder("robe")
    robe.lathe([(0.31, 0.0), (0.36, 0.35), (0.44, 0.9), (0.52, 1.45), (0.58, 1.9), (0.54, 1.95)], 16, (0, -0.05, 0.0), P["team_cloth"], rot=(180, 0, 0))
    robe.torus(0.575, 0.04, 16, 4, (0, -1.93, 0.0), P["team_trim"])
    c.attach(robe, bone="pelvis", uv_scale=1.0)

    # lance through the right fist
    lance = mk.Builder("lance")
    grip = Vector((-0.66, -0.5, 0.33))
    d = Vector((0, -0.12, 1.0)).normalized()
    base, tip = grip - d * 1.2, grip + d * 2.2
    tube(lance, tuple(base), tuple(tip), 0.045, P["brass"], 8)
    tube(lance, tuple(tip), tuple(tip + d * 0.5), 0.1, P["team_glow"], 6, r2=0.0)
    lance.sphere(0.07, 6, 4, tuple(base), P["brass"])
    tube(lance, tuple(tip - d * 0.05 + Vector((0.16, 0, 0))), tuple(tip - d * 0.05 - Vector((0.16, 0, 0))), 0.035, P["brass"], 6)
    c.attach(lance, bone="hand_r", uv_scale=1.0)
    return c


ASSETS = {
    "cerberus": cerberus,
    "cyclops": cyclops,
    "griffin": griffin,
    "dragon": dragon,
    "demon": demon,
    "angel": angel,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name in (argv or list(ASSETS.keys())):
        mk.reset()
        c = ASSETS[name](name)
        tris = c.finish()
        mk.save_blend(os.path.join(BLEND, name + ".blend"))
        cr.export_skinned(os.path.join(OUT, name + ".glb"))
        print("[creatures] %-10s tris=%d bones=%d" % (name, tris, len(c.rig.bones)), flush=True)


if __name__ == "__main__":
    main()

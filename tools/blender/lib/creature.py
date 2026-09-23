"""Skinned creatures: metaball bodies, bone rigs, automatic weights and attachments.

Authored in Godot space like mk.Builder (x = model left, y up, +z = model front) and
converted when objects are created, so the exported glTF lands in Godot as written.

    rig = Rig("cyclops")
    rig.bone("hips", (0, 4, 0), (0, 5, 0))
    skin = Body("cyclops_skin", P["hide"])
    skin.limb([(0, 4, 0), (0, 2, 0)], [0.7, 0.5])
    c = Creature(rig)
    c.skin(skin, faces=5000, paint=fn, uv_scale=0.5)   # weights from bone heat
    c.attach(builder, bone="hand_r")                    # rigid to one bone
    c.attach(builder)                                   # follows the nearest skin
    c.attach(builder, weights=fn)                       # fn(p) -> {bone: weight}
    c.finish(); export_skinned(path)

Animation is procedural in Godot, so only the rest pose and the skin are exported.
"""
import math

import bmesh
import bpy
from mathutils import Vector, kdtree

import mk

# Metaball field: s * (1 - d^2 / r^2)^3 against threshold t. With the defaults below an
# isolated element shows at 1/K of its radius, so radii here are the visible sizes.
STIFF = 2.0
THRESH = 0.6
K = 1.0 / math.sqrt(1.0 - (THRESH / STIFF) ** (1.0 / 3.0))


def kfactor(stiff):
    return 1.0 / math.sqrt(1.0 - (THRESH / stiff) ** (1.0 / 3.0))


def gvec(p):
    return Vector(mk.gpos(*p))


def to_godot(v):
    """Blender vector -> Godot tuple."""
    return (v.x, v.z, -v.y)


def seg_dist(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared < 1e-9 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


# --------------------------------------------------------------------------
class Rig:
    def __init__(self, name):
        self.name = name
        self.bones = []

    def bone(self, name, head, tail, parent=None):
        self.bones.append((name, head, tail, parent))
        return name

    def chain(self, prefix, pts, parent=None):
        """Bones prefix1..n through the points; returns the names."""
        names = []
        for i in range(len(pts) - 1):
            parent = self.bone("%s%d" % (prefix, i + 1), pts[i], pts[i + 1], parent)
            names.append(parent)
        return names

    def mirror(self, name_l, head, tail, parent=None):
        """Add name_l at +x and name_r at -x (parents mirrored the same way)."""
        self.bone(name_l, head, tail, parent)
        pr = parent[:-2] + "_r" if parent and parent.endswith("_l") else parent
        self.bone(name_l[:-2] + "_r", (-head[0], head[1], head[2]), (-tail[0], tail[1], tail[2]), pr)

    def segments(self):
        return {n: (gvec(h), gvec(t)) for (n, h, t, _p) in self.bones}

    def build(self):
        arm = bpy.data.armatures.new(self.name + "_rig")
        ob = bpy.data.objects.new(self.name, arm)
        bpy.context.scene.collection.objects.link(ob)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT")
        for (n, h, t, p) in self.bones:
            eb = arm.edit_bones.new(n)
            eb.head = gvec(h)
            eb.tail = gvec(t)
            if p:
                eb.parent = arm.edit_bones[p]
        bpy.ops.object.mode_set(mode="OBJECT")
        return ob


# --------------------------------------------------------------------------
class Body:
    """Metaball skin: balls, ellipsoids and capsules blended into one surface."""

    def __init__(self, name, m, res=0.07):
        self.name = name
        self.m = m
        self.mb = bpy.data.metaballs.new(name)
        self.mb.resolution = res
        self.mb.render_resolution = res
        self.mb.threshold = THRESH
        self.ob = bpy.data.objects.new(name, self.mb)
        bpy.context.scene.collection.objects.link(self.ob)

    def _el(self, kind, p, r, stiff):
        e = self.mb.elements.new()
        e.type = kind
        e.co = gvec(p)
        e.radius = r * kfactor(stiff)
        e.stiffness = stiff
        return e

    def ball(self, p, r, stiff=STIFF):
        return self._el("BALL", p, r, stiff)

    def ellipsoid(self, p, size, rot=None, stiff=STIFF):
        """Semi-axes (x, y, z) in Godot space, optional Godot-space rotation (degrees)."""
        e = self._el("ELLIPSOID", p, 1.0, stiff)
        e.size_x, e.size_y, e.size_z = size[0], size[2], size[1]
        if rot is not None:
            R = mk.G2B @ mk.xform((0, 0, 0), rot) @ mk.G2B.inverted()
            e.rotation = R.to_quaternion()
        return e

    def capsule(self, a, b, r, stiff=STIFF):
        a, b = gvec(a), gvec(b)
        d = b - a
        e = self.mb.elements.new()
        e.type = "CAPSULE"
        e.co = (a + b) * 0.5
        e.radius = r * kfactor(stiff)
        e.stiffness = stiff
        e.size_x = max(d.length * 0.5, 1e-3)
        e.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())
        return e

    def limb(self, pts, radii, stiff=STIFF):
        """Tapered tube through the points: short capsules with interpolated radii."""
        for i in range(len(pts) - 1):
            a, b = Vector(pts[i]), Vector(pts[i + 1])
            ra, rb = radii[i], radii[i + 1]
            n = max(1, math.ceil(abs(ra - rb) / 0.05), math.ceil((b - a).length / (3.0 * max(ra, rb))))
            for k in range(n):
                t0, t1 = k / n, (k + 1) / n
                self.capsule(tuple(a.lerp(b, t0)), tuple(a.lerp(b, t1)), ra + (rb - ra) * (t0 + t1) * 0.5, stiff)

    def mirror_ball(self, p, r, stiff=STIFF):
        self.ball(p, r, stiff)
        self.ball((-p[0], p[1], p[2]), r, stiff)

    def mirror_ellipsoid(self, p, size, rot=None, stiff=STIFF):
        self.ellipsoid(p, size, rot, stiff)
        r2 = None if rot is None else (rot[0], -rot[1], -rot[2])
        self.ellipsoid((-p[0], p[1], p[2]), size, r2, stiff)

    def mirror_limb(self, pts, radii, stiff=STIFF):
        self.limb(pts, radii, stiff)
        self.limb([(-x, y, z) for (x, y, z) in pts], radii, stiff)

    def to_object(self, faces):
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(self.ob.evaluated_get(dg))
        bpy.data.objects.remove(self.ob)
        bpy.data.metaballs.remove(self.mb)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        if len(me.polygons) > faces:
            mod = ob.modifiers.new("decimate", "DECIMATE")
            mod.ratio = faces / len(me.polygons)
            dg = bpy.context.evaluated_depsgraph_get()
            low = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
            ob.modifiers.clear()
            ob.data = low
            bpy.data.meshes.remove(me)
        ob.data.materials.append(self.m)
        for p in ob.data.polygons:
            p.use_smooth = True
        return ob


# --------------------------------------------------------------------------
def uv_box(me, scale, faces=None):
    """Per-face box projection in the rest pose (textures stay put when the skin bends)."""
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    for poly in (faces if faces is not None else me.polygons):
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                u, w = v.y * (1 if n.x > 0 else -1), v.z
            elif ax == 1:
                u, w = v.x * (-1 if n.y > 0 else 1), v.z
            else:
                u, w = v.x, v.y * (1 if n.z > 0 else -1)
            uv.data[li].uv = (u * scale, w * scale)


def cavity(me, passes=2):
    """Per-vertex concavity 0..1 (creases between metaball lumps), blurred over neighbours."""
    nb = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nb[a].append(b)
        nb[b].append(a)
    raw = []
    for v in me.vertices:
        acc = 0.0
        for j in nb[v.index]:
            d = me.vertices[j].co - v.co
            if d.length > 1e-6:
                acc += v.normal.dot(d.normalized())
        raw.append(acc / max(1, len(nb[v.index])))
    for _ in range(passes):
        raw = [(raw[i] + sum(raw[j] for j in nb[i])) / (1 + len(nb[i])) for i in range(len(raw))]
    return [max(0.0, min(1.0, r * 4.0)) for r in raw]


def paint(me, fn=None, polys=None, dirt=0.0):
    """Vertex colours from fn(p, n) -> (r, g, b) in Godot space (white where fn is None).
    `dirt` darkens creases by up to that fraction."""
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    cav = cavity(me) if dirt > 0.0 else None
    for poly in (polys if polys is not None else me.polygons):
        for li in poly.loop_indices:
            if fn is None:
                attr.data[li].color = (1.0, 1.0, 1.0, 1.0)
                continue
            vi = me.loops[li].vertex_index
            vtx = me.vertices[vi]
            c = fn(to_godot(vtx.co), to_godot(vtx.normal))
            k = 1.0 - dirt * cav[vi] if cav else 1.0
            attr.data[li].color = (c[0] * k, c[1] * k, c[2] * k, 1.0)
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = me.color_attributes.find("Col")


def weights_near(rig_segments, p, bones=None, k=3, power=4.0):
    """Inverse-distance weights to the nearest bone segments (Blender-space point)."""
    names = bones or list(rig_segments.keys())
    d = sorted((seg_dist(p, *rig_segments[n]), n) for n in names)[:k]
    if d[0][0] < 1e-4:
        return {d[0][1]: 1.0}
    w = {n: 1.0 / (dd ** power) for (dd, n) in d}
    s = sum(w.values())
    return {n: v / s for (n, v) in w.items()}


class Creature:
    def __init__(self, rig):
        self.rig = rig
        self.arm = rig.build()
        self.segs = rig.segments()
        self.body = None
        self._parts = []

    def skin(self, body, faces=5000, paint_fn=None, uv_scale=0.5, heat=True, exclude=(), dirt=0.45):
        """Mesh the metaball body and weight it with bone heat (or distances)."""
        ob = body.to_object(faces)
        uv_box(ob.data, uv_scale)
        paint(ob.data, paint_fn, dirt=dirt)
        if self.body is None:
            self.body = ob
            self._bind(ob, heat, exclude)
        else:
            self._bind(ob, heat, exclude)
            self._parts.append(ob)
        return ob

    def _bind(self, ob, heat, exclude):
        if heat:
            saved = {}
            for b in self.arm.data.bones:
                saved[b.name] = b.use_deform
                b.use_deform = b.name not in exclude
            bpy.ops.object.select_all(action="DESELECT")
            ob.select_set(True)
            self.arm.select_set(True)
            bpy.context.view_layer.objects.active = self.arm
            bpy.ops.object.parent_set(type="ARMATURE_AUTO")
            for b in self.arm.data.bones:
                b.use_deform = saved[b.name]
        allowed = [n for n in self.segs if n not in exclude]
        self._fill_missing(ob, allowed)

    def _fill_missing(self, ob, allowed):
        """Vertices bone heat left without weights take the nearest bones."""
        groups = {g.index: g.name for g in ob.vertex_groups}
        for v in ob.data.vertices:
            if any(g.weight > 1e-4 for g in v.groups if g.group in groups):
                continue
            for n, w in weights_near(self.segs, v.co, allowed).items():
                vg = ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n)
                vg.add([v.index], w, "REPLACE")

    def attach(self, builder, bone=None, weights=None, uv_scale=None, paint_fn=None):
        """Add an mk.Builder mesh: rigid to `bone`, custom `weights(p)`, or following the skin."""
        ob = builder.to_object()
        me = ob.data
        if uv_scale is not None:
            uv_box(me, uv_scale)
        paint(me, paint_fn)
        if bone is not None:
            vg = ob.vertex_groups.new(name=bone)
            vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
        elif weights is not None:
            for v in me.vertices:
                for n, w in weights(to_godot(v.co)).items():
                    vg = ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n)
                    vg.add([v.index], w, "REPLACE")
        else:
            self._copy_weights(ob)
        self._parts.append(ob)
        return ob

    def _copy_weights(self, ob):
        src = self.body.data
        names = {g.index: g.name for g in self.body.vertex_groups}
        tree = kdtree.KDTree(len(src.vertices))
        for v in src.vertices:
            tree.insert(v.co, v.index)
        tree.balance()
        for v in ob.data.vertices:
            acc = {}
            total = 0.0
            for (_co, idx, dist) in tree.find_n(v.co, 4):
                k = 1.0 / max(dist, 1e-3) ** 2
                total += k
                for g in src.vertices[idx].groups:
                    acc[names[g.group]] = acc.get(names[g.group], 0.0) + g.weight * k
            for n, w in acc.items():
                vg = ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n)
                vg.add([v.index], w / total, "REPLACE")

    def finish(self):
        """Join everything into the skin and keep at most four normalised influences."""
        bpy.ops.object.select_all(action="DESELECT")
        for o in self._parts:
            o.select_set(True)
        self.body.select_set(True)
        bpy.context.view_layer.objects.active = self.body
        if self._parts:
            bpy.ops.object.join()
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
        self.body.name = "body"
        self.body.data.validate()
        self.body.parent = self.arm
        if not any(m.type == "ARMATURE" for m in self.body.modifiers):
            mod = self.body.modifiers.new("Armature", "ARMATURE")
            mod.object = self.arm
        tris = sum(len(p.vertices) - 2 for p in self.body.data.polygons)
        return tris


def membrane(b, outline, m, rows=6, thick=0.06, sag=0.0):
    """Thin closed sheet: rows of points between a leading edge and a trailing edge.

    outline = (lead, trail): two lists of Godot points with the same length. The sheet is
    lofted between them (rows subdivisions) and given thickness along the average normal.
    """
    lead, trail = outline
    grid = []
    for i in range(len(lead)):
        a, c = Vector(lead[i]), Vector(trail[i])
        col = []
        for r in range(rows + 1):
            t = r / rows
            p = a.lerp(c, t)
            p.y -= sag * math.sin(t * math.pi)
            col.append(p)
        grid.append(col)
    bm = b.bm
    idx = b.slot(m)
    top = [[bm.verts.new(p) for p in col] for col in grid]
    faces = []
    for i in range(len(top) - 1):
        for r in range(rows):
            f = bm.faces.new((top[i][r], top[i + 1][r], top[i + 1][r + 1], top[i][r + 1]))
            f.material_index = idx
            f.smooth = True
            faces.append(f)
    res = bmesh.ops.solidify(bm, geom=faces, thickness=thick)
    for f in res["geom"]:
        if isinstance(f, bmesh.types.BMFace):
            f.material_index = idx
            f.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces])
    return faces


def export_skinned(path):
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=False,
        export_yup=True,
        export_apply=False,
        export_normals=True,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_skins=True,
        export_image_format="NONE",
    )

"""Small procedural modelling kit for Blender (bmesh based).

Geometry is authored in *Godot space* (x right, y up, +z = model front) and
converted to Blender space (x, -z, y) when an object is finalised, so the
exported glTF lands in Godot exactly as written here.
"""
import math
import os
import warnings

import bmesh
import bpy
from mathutils import Matrix, Vector

# Godot -> Blender: rotate +90 deg about X  (x, y, z) -> (x, -z, y)
G2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


def gpos(x, y, z):
    """Godot position -> Blender Vector."""
    return Vector((x, -z, y))


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------
def mat(name, color=(0.8, 0.8, 0.8), metallic=0.0, roughness=0.6, emission=None, strength=0.0, alpha=1.0):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = roughness
    if emission is not None:
        p.inputs["Emission Color"].default_value = (emission[0], emission[1], emission[2], 1.0)
        p.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
    m.diffuse_color = (color[0], color[1], color[2], alpha)
    return m


# Shared palette. Names matter: Godot swaps these for its own material library.
def palette():
    return {
        "stone": mat("stone", (0.42, 0.43, 0.46), 0.0, 0.85),
        "stone_dark": mat("stone_dark", (0.20, 0.21, 0.24), 0.0, 0.85),
        "stone_trim": mat("stone_trim", (0.55, 0.53, 0.50), 0.0, 0.8),
        "paving": mat("paving", (0.45, 0.43, 0.40), 0.0, 0.9),
        "roof": mat("roof", (0.16, 0.19, 0.26), 0.2, 0.55),
        "roof_copper": mat("roof_copper", (0.25, 0.45, 0.42), 0.6, 0.45),
        "iron": mat("iron", (0.13, 0.14, 0.16), 0.85, 0.42),
        "iron_dark": mat("iron_dark", (0.06, 0.065, 0.075), 0.8, 0.5),
        "brass": mat("brass", (0.72, 0.53, 0.26), 0.95, 0.32),
        "copper": mat("copper", (0.62, 0.34, 0.20), 0.95, 0.38),
        "wood": mat("wood", (0.33, 0.22, 0.14), 0.0, 0.8),
        "plaster": mat("plaster", (0.62, 0.58, 0.50), 0.0, 0.9),
        "team_cloth": mat("team_cloth", (0.12, 0.22, 0.52), 0.0, 0.75),
        "team_trim": mat("team_trim", (0.14, 0.26, 0.58), 0.5, 0.4),
        "team_glow": mat("team_glow", (0.3, 0.8, 1.0), 0.0, 0.3, (0.3, 0.8, 1.0), 6.0),
        "aether": mat("aether", (0.35, 0.85, 1.0), 0.0, 0.2, (0.35, 0.85, 1.0), 8.0),
        "window_glow": mat("window_glow", (1.0, 0.72, 0.38), 0.0, 0.5, (1.0, 0.62, 0.3), 3.0),
        "lamp_glow": mat("lamp_glow", (1.0, 0.8, 0.5), 0.0, 0.4, (1.0, 0.7, 0.4), 6.0),
        "fire_glow": mat("fire_glow", (1.0, 0.45, 0.15), 0.0, 0.4, (1.0, 0.4, 0.1), 8.0),
        "glass": mat("glass", (0.15, 0.2, 0.25), 0.3, 0.1),
        "skin": mat("skin", (0.72, 0.55, 0.45), 0.0, 0.7),
        "leather": mat("leather", (0.22, 0.15, 0.10), 0.0, 0.7),
        "rubber": mat("rubber", (0.04, 0.04, 0.045), 0.0, 0.9),
        "foliage": mat("foliage", (0.12, 0.2, 0.12), 0.0, 0.9),
        "bark": mat("bark", (0.22, 0.16, 0.11), 0.0, 0.95),
        "rock": mat("rock", (0.40, 0.39, 0.38), 0.0, 0.9),
        "crystal": mat("crystal", (0.4, 0.9, 1.0), 0.1, 0.15, (0.35, 0.85, 1.0), 4.0),
        "canvas": mat("canvas", (0.62, 0.58, 0.50), 0.0, 0.85),
        # creatures (colour comes from vertex paint)
        "hide": mat("hide", (0.55, 0.50, 0.42), 0.0, 0.8),
        "scales": mat("scales", (0.30, 0.30, 0.32), 0.1, 0.45),
        "fur": mat("fur", (0.22, 0.20, 0.19), 0.0, 0.9),
        "feather": mat("feather", (0.70, 0.60, 0.45), 0.0, 0.75),
        "membrane": mat("membrane", (0.35, 0.12, 0.10), 0.0, 0.6),
        "horn": mat("horn", (0.75, 0.68, 0.55), 0.0, 0.45),
        "claw": mat("claw", (0.10, 0.09, 0.08), 0.0, 0.4),
        "eye_white": mat("eye_white", (0.85, 0.80, 0.70), 0.0, 0.25),
        "mouth": mat("mouth", (0.35, 0.08, 0.07), 0.0, 0.6),
    }


# --------------------------------------------------------------------------
# bmesh primitive builders (all in Godot space)
# --------------------------------------------------------------------------
class Builder:
    """Accumulates geometry for one object, one material slot per name."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.slots = []
        self.color_layer = None

    def slot(self, m):
        if m.name not in [s.name for s in self.slots]:
            self.slots.append(m)
        return [s.name for s in self.slots].index(m.name)

    def _finish(self, geom_verts, geom_faces, m, xf, color=None):
        idx = self.slot(m)
        for f in geom_faces:
            f.material_index = idx
        if xf is not None:
            bmesh.ops.transform(self.bm, matrix=xf, verts=geom_verts)
        if color is not None:
            self.paint(geom_faces, color)
        return geom_faces

    def paint(self, faces, color):
        if self.color_layer is None:
            self.color_layer = self.bm.loops.layers.float_color.new("Col")
            for f in self.bm.faces:
                for l in f.loops:
                    l[self.color_layer] = (1.0, 1.0, 1.0, 1.0)
        for f in faces:
            for l in f.loops:
                l[self.color_layer] = color

    def _new_geom(self, fn):
        before_v = set(self.bm.verts)
        before_f = set(self.bm.faces)
        fn()
        verts = [v for v in self.bm.verts if v not in before_v]
        faces = [f for f in self.bm.faces if f not in before_f]
        if self.color_layer is not None:
            for f in faces:
                for l in f.loops:
                    l[self.color_layer] = (1.0, 1.0, 1.0, 1.0)
        return verts, faces

    # -- primitives ------------------------------------------------------
    def box(self, size, loc=(0, 0, 0), m=None, rot=None, bevel=0.0, color=None, taper=None):
        sx, sy, sz = size

        def mk():
            r = bmesh.ops.create_cube(self.bm, size=1.0)
            bmesh.ops.scale(self.bm, vec=(sx, sy, sz), verts=r["verts"])
            if taper is not None:
                # taper = (top_scale_x, top_scale_z)
                for v in r["verts"]:
                    if v.co.y > 0:
                        v.co.x *= taper[0]
                        v.co.z *= taper[1]
            if bevel > 0:
                bmesh.ops.bevel(self.bm, geom=list(set(e for v in r["verts"] for e in v.link_edges)),
                                offset=bevel, segments=1, affect="EDGES", profile=0.5)
        verts, faces = self._new_geom(mk)
        return self._finish(verts, faces, m, xform(loc, rot), color)

    def cylinder(self, r, h, seg=12, loc=(0, 0, 0), m=None, rot=None, r2=None, caps=True, color=None, smooth=False):
        """Vertical cylinder/cone with base at y=0 (before transform)."""
        r2 = r if r2 is None else r2

        def mk():
            ring0 = []
            ring1 = []
            for i in range(seg):
                a = i / seg * math.tau
                ring0.append(self.bm.verts.new((math.cos(a) * r, 0.0, math.sin(a) * r)))
                ring1.append(self.bm.verts.new((math.cos(a) * r2, h, math.sin(a) * r2)))
            for i in range(seg):
                j = (i + 1) % seg
                f = self.bm.faces.new((ring0[i], ring1[i], ring1[j], ring0[j]))
                f.smooth = smooth
            if caps:
                self.bm.faces.new(list(reversed(ring0)))
                if r2 > 1e-4:
                    self.bm.faces.new(ring1)
        verts, faces = self._new_geom(mk)
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        return self._finish(verts, faces, m, xform(loc, rot), color)

    def lathe(self, profile, seg=16, loc=(0, 0, 0), m=None, rot=None, color=None, smooth=True, cap_bottom=True):
        """Revolve [(radius, y), ...] around the Y axis."""

        def mk():
            rings = []
            for (rad, y) in profile:
                ring = []
                for i in range(seg):
                    a = i / seg * math.tau
                    ring.append(self.bm.verts.new((math.cos(a) * rad, y, math.sin(a) * rad)))
                rings.append(ring)
            for k in range(len(rings) - 1):
                for i in range(seg):
                    j = (i + 1) % seg
                    f = self.bm.faces.new((rings[k][i], rings[k + 1][i], rings[k + 1][j], rings[k][j]))
                    f.smooth = smooth
            if cap_bottom and profile[0][0] > 1e-4:
                self.bm.faces.new(list(reversed(rings[0])))
            if profile[-1][0] > 1e-4:
                self.bm.faces.new(rings[-1])
        verts, faces = self._new_geom(mk)
        bmesh.ops.remove_doubles(self.bm, verts=verts, dist=1e-5)
        faces = [f for f in faces if f.is_valid]
        verts = [v for v in verts if v.is_valid]
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        return self._finish(verts, faces, m, xform(loc, rot), color)

    def sphere(self, r, seg=12, rings=8, loc=(0, 0, 0), m=None, scale=(1, 1, 1), rot=None, color=None, smooth=True):
        prof = []
        for k in range(rings + 1):
            t = k / rings * math.pi
            prof.append((math.sin(t) * r, -math.cos(t) * r))
        faces = self.lathe(prof, seg, (0, 0, 0), m, None, None, smooth, cap_bottom=False)
        verts = list({v for f in faces for v in f.verts})
        bmesh.ops.scale(self.bm, vec=scale, verts=verts)
        bmesh.ops.transform(self.bm, matrix=xform(loc, rot), verts=verts)
        if color is not None:
            self.paint(faces, color)
        return faces

    def prism(self, pts, y0, y1, loc=(0, 0, 0), m=None, rot=None, color=None):
        """Extrude a 2D polygon [(x, z), ...] (CCW seen from above) between y0 and y1."""

        def mk():
            bot = [self.bm.verts.new((x, y0, z)) for (x, z) in pts]
            top = [self.bm.verts.new((x, y1, z)) for (x, z) in pts]
            self.bm.faces.new(list(reversed(bot)))
            self.bm.faces.new(top)
            n = len(pts)
            for i in range(n):
                j = (i + 1) % n
                self.bm.faces.new((bot[i], bot[j], top[j], top[i]))
        verts, faces = self._new_geom(mk)
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        return self._finish(verts, faces, m, xform(loc, rot), color)

    def side_profile(self, pts, width, loc=(0, 0, 0), m=None, rot=None, color=None, top_m=None, top_edge=None):
        """Extrude a 2D profile [(x, y), ...] along Z (width centred)."""

        def mk():
            a = [self.bm.verts.new((x, y, -width / 2)) for (x, y) in pts]
            b = [self.bm.verts.new((x, y, width / 2)) for (x, y) in pts]
            self.bm.faces.new(a)
            self.bm.faces.new(list(reversed(b)))
            n = len(pts)
            for i in range(n):
                j = (i + 1) % n
                self.bm.faces.new((a[i], a[j], b[j], b[i]))
        verts, faces = self._new_geom(mk)
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        out = self._finish(verts, faces, m, xform(loc, rot), color)
        if top_m is not None and top_edge is not None:
            idx = self.slot(top_m)
            # faces 2 + top_edge is the extruded quad for edge (top_edge, top_edge+1)
            faces[2 + top_edge].material_index = idx
        return out

    def gable_roof(self, w, d, h, loc=(0, 0, 0), m=None, rot=None, overhang=0.3, thick=0.15, color=None):
        """Roof ridge along Z. Base at y=0, width w (x), depth d (z)."""
        hw = w / 2 + overhang
        pts = [(-hw, 0.0), (hw, 0.0), (0.0, h)]
        pts2 = [(-hw, -thick), (hw, -thick), (hw, 0.0), (0.0, h), (-hw, 0.0)]
        return self.side_profile(pts2, d + overhang * 2, loc, m, rot, color)

    def hip_cone(self, r, h, seg=4, loc=(0, 0, 0), m=None, rot=None, color=None):
        return self.cylinder(r, h, seg, loc, m, rot, r2=0.0, color=color)

    def torus(self, R, r, seg=16, seg2=6, loc=(0, 0, 0), m=None, rot=None, color=None):
        def mk():
            rings = []
            for i in range(seg):
                a = i / seg * math.tau
                ring = []
                for k in range(seg2):
                    b = k / seg2 * math.tau
                    rr = R + math.cos(b) * r
                    ring.append(self.bm.verts.new((math.cos(a) * rr, math.sin(b) * r, math.sin(a) * rr)))
                rings.append(ring)
            for i in range(seg):
                i2 = (i + 1) % seg
                for k in range(seg2):
                    k2 = (k + 1) % seg2
                    f = self.bm.faces.new((rings[i][k], rings[i2][k], rings[i2][k2], rings[i][k2]))
                    f.smooth = True
        verts, faces = self._new_geom(mk)
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        return self._finish(verts, faces, m, xform(loc, rot), color)

    def gear(self, r, thick, teeth=12, loc=(0, 0, 0), m=None, rot=None, color=None, hole=0.35):
        """Flat gear in the XZ plane (extruded along Y)."""
        pts = []
        n = teeth * 4
        for i in range(n):
            a = i / n * math.tau
            rr = r if (i % 4) in (0, 1) else r * 0.82
            pts.append((math.cos(a) * rr, math.sin(a) * rr))
        faces = self.prism(pts, -thick / 2, thick / 2, loc, m, rot, color)
        return faces

    def join_to(self, other):
        pass

    # -- finalize -----------------------------------------------------------
    def to_object(self, collection=None, parent=None, origin=(0, 0, 0), parent_origin=(0, 0, 0)):
        """Create the Blender object. `origin` is the pivot in model (Godot) space;
        `parent_origin` is the parent's pivot in the same space."""
        ox, oy, oz = origin
        bmesh.ops.translate(self.bm, vec=(-ox, -oy, -oz), verts=self.bm.verts)
        bmesh.ops.transform(self.bm, matrix=G2B, verts=self.bm.verts)
        me = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for s in self.slots:
            me.materials.append(s)
        ob = bpy.data.objects.new(self.name, me)
        (collection or bpy.context.scene.collection).objects.link(ob)
        if parent is not None:
            ob.parent = parent
        ob.location = gpos(ox - parent_origin[0], oy - parent_origin[1], oz - parent_origin[2])
        if me.color_attributes:
            me.color_attributes.active_color = me.color_attributes[0]
            me.color_attributes.render_color_index = 0
        return ob


def xform(loc=(0, 0, 0), rot=None, scale=None):
    """Transform in Godot space. rot = (rx, ry, rz) degrees, applied Y*X*Z."""
    M = Matrix.Translation(Vector(loc))
    if rot is not None:
        rx, ry, rz = (math.radians(a) for a in rot)
        R = Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(rz, 4, "Z")
        M = M @ R
    if scale is not None:
        M = M @ Matrix.Diagonal(Vector((scale[0], scale[1], scale[2], 1.0)))
    return M


def empty(name, loc=(0, 0, 0), parent=None):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    ob.location = gpos(*loc)
    return ob


# --------------------------------------------------------------------------
# export
# --------------------------------------------------------------------------
def export_glb(path, vertex_colors=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=False,
        export_yup=True,
        export_apply=True,
        export_normals=True,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE" if vertex_colors else "NONE",
        export_all_vertex_colors=False,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_image_format="NONE",
    )


def save_blend(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)

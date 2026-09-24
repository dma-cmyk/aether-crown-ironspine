"""Gearforge Building Kit (Phase 2.6A).

Shared modular parts for the production building set. Geometry helpers are
reused from make_gearforge_titan.py (no duplication); this module only adds
building-level assembly functions so no building is authored from zero.

Conventions: metric 1unit=1m, Blender Y depth / Z up, front -Y, origin at
ground centre, snake_case names, shared material_lib palette (Principled
BSDF only, no textures). Parts take caller-owned materials so each building
script controls its own material->mesh join.

Run: imported by make_gearforge_*.py scripts, not run directly.
"""

import math
import os
import sys

KIT_DIR = os.path.abspath(os.path.dirname(__file__))
SCRIPT_DIR = os.path.abspath(os.path.join(KIT_DIR, ".."))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import make_gearforge_titan as T  # noqa: E402


def base_pad(prefix, w, d, mat, h=0.30):
    """Ground contact slab. Top at h, centred on origin."""
    return T.box(f"{prefix}_pad", (w, d, h), (0.0, 0.0, h * 0.5), mat, bevel=0.03)


def hall(prefix, w, d, h, mat, y0=0.0, bevel=0.05):
    """Main mass block sitting on y0 (usually pad top)."""
    return T.box(f"{prefix}_hall", (w, d, h), (0.0, 0.0, y0 + h * 0.5), mat, bevel=bevel)


def upper_block(prefix, part, w, d, h, loc, mat, bevel=0.04):
    return T.box(f"{prefix}_{part}", (w, d, h), loc, mat, bevel=bevel)


def gable_roof(prefix, w, d, h, z, mat):
    """Low trapezoid cap. w/d are bottom extents."""
    return T.trapezoid(f"{prefix}_roof", (w, d), (w * 0.55, d * 0.55), h,
                       (0.0, 0.0, z + h * 0.5), mat, bevel=0.03)


def parapet(prefix, w, d, h, z, mat):
    """Fortified rim: 4 thin walls + 4 corner posts (barracks language)."""
    t = 0.22
    T.box(f"{prefix}_parapet_f", (w, t, h), (0.0, -d * 0.5, z + h * 0.5), mat, bevel=0.0)
    T.box(f"{prefix}_parapet_b", (w, t, h), (0.0, d * 0.5, z + h * 0.5), mat, bevel=0.0)
    T.box(f"{prefix}_parapet_l", (t, d, h), (-w * 0.5, 0.0, z + h * 0.5), mat, bevel=0.0)
    T.box(f"{prefix}_parapet_r", (t, d, h), (w * 0.5, 0.0, z + h * 0.5), mat, bevel=0.0)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            T.box(f"{prefix}_post_{int(sx)}_{int(sy)}", (0.4, 0.4, h + 0.5),
                  (sx * w * 0.5, sy * d * 0.5, z + (h + 0.5) * 0.5), mat, bevel=0.0)


def chimney(prefix, r, h, loc, mats, iron=None, glow=None, vertices=10):
    """Straight stack with brass collar + lip. Top at loc[2]+h."""
    x, y, z0 = loc
    mat_iron = iron or mats["dark_iron"]
    _cyl = T.cylinder
    _cyl(f"{prefix}_stack", r, h, (x, y, z0 + h * 0.5),
         mat_iron, vertices=vertices, bevel=0.0)
    _cyl(f"{prefix}_stack_collar", r * 1.12, h * 0.07, (x, y, z0 + h * 0.22),
         mats["brass"], vertices=vertices, bevel=0.0)
    _cyl(f"{prefix}_stack_lip", r * 1.18, h * 0.08, (x, y, z0 + h * 0.90),
         mats["brass"], vertices=vertices, bevel=0.0)
    if glow is not None:
        _cyl(f"{prefix}_stack_heat", r * 0.78, 0.08, (x, y, z0 + h * 0.97),
             glow, vertices=vertices, bevel=0.0)


def boiler_horizontal(prefix, r, length, loc, mats, vertices=12):
    x, y, z = loc
    T.cylinder(f"{prefix}_boiler", r, length, (x, y, z), mats["copper"],
               vertices=vertices, rot=(0.0, math.radians(90.0), 0.0), bevel=0.0)
    for dx in (-length * 0.32, length * 0.32):
        T.torus(f"{prefix}_boiler_band_{int((dx + 9) * 10)}", r * 1.02, r * 0.12,
                (x + dx, y, z), mats["brass"],
                rot=(0.0, math.radians(90.0), 0.0), major=12, minor=5)


def tank_vertical(prefix, r, h, loc, mats, vertices=12, capped=True):
    x, y, z0 = loc
    T.cylinder(f"{prefix}_tank", r, h, (x, y, z0 + h * 0.5), mats["copper"],
               vertices=vertices, bevel=0.0)
    T.torus(f"{prefix}_tank_band", r * 1.02, r * 0.10, (x, y, z0 + h * 0.55),
            mats["brass"], major=12, minor=5)
    if capped:
        T.cylinder(f"{prefix}_tank_cap", r * 1.06, h * 0.08, (x, y, z0 + h * 0.97),
                   mats["brass"], vertices=vertices, bevel=0.0)


def pipe_run(a, b, r, mat, name, vertices=8):
    return T.cylinder_between(name, a, b, r, mat, vertices=vertices, bevel=0.0)


def pipe_elbow(prefix, corner, r, mat, arm=0.8, vertices=8):
    """Simple 90-degree corner: two stubs + joint sphere (8-seg)."""
    x, y, z = corner
    T.cylinder(f"{prefix}_elbow_a", r, arm, (x - arm * 0.5, y, z), mat,
               vertices=vertices, rot=(0.0, math.radians(90.0), 0.0), bevel=0.0)
    T.cylinder(f"{prefix}_elbow_b", r, arm, (x, y, z + arm * 0.5), mat,
               vertices=vertices, bevel=0.0)
    import bpy
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r * 1.05, location=(x, y, z),
                                         segments=vertices, ring_count=max(3, vertices // 2))
    obj = bpy.context.active_object
    obj.name = f"{prefix}_elbow_joint"
    obj.data.materials.append(mat)
    return obj


def door_large(prefix, w, h, loc, mats, frame=None):
    """Recessed industrial door + frame on a front (-Y) face."""
    x, y, z0 = loc
    fmat = frame or mats["brass"]
    T.box(f"{prefix}_door_frame", (w + 0.5, 0.24, h + 0.4), (x, y, z0 + h * 0.5), fmat, bevel=0.0)
    T.box(f"{prefix}_door", (w, 0.18, h), (x, y - 0.06, z0 + h * 0.5), mats["dark_iron"], bevel=0.0)
    T.box(f"{prefix}_door_lintel", (w + 0.9, 0.30, 0.30), (x, y, z0 + h + 0.25), fmat, bevel=0.0)


def gate_arch(prefix, w, h, loc, mats):
    """Factory gate: two posts + lintel + recessed dark opening."""
    x, y, z0 = loc
    T.box(f"{prefix}_gate_post_l", (0.6, 0.8, h), (x - w * 0.5, y, z0 + h * 0.5),
          mats["steel"], bevel=0.03)
    T.box(f"{prefix}_gate_post_r", (0.6, 0.8, h), (x + w * 0.5, y, z0 + h * 0.5),
          mats["steel"], bevel=0.03)
    T.box(f"{prefix}_gate_lintel", (w + 1.2, 0.8, 0.9), (x, y, z0 + h + 0.3),
          mats["brass"], bevel=0.03)
    T.box(f"{prefix}_gate_dark", (w - 0.4, 0.3, h - 0.3), (x, y + 0.1, z0 + (h - 0.3) * 0.5),
          mats["dark_iron"], bevel=0.0)


def wall_segment(prefix, w, h, loc, mats, buttress=True):
    x, y, z0 = loc
    T.box(f"{prefix}_wall", (w, 0.5, h), (x, y, z0 + h * 0.5), mats["dark_iron"], bevel=0.03)
    T.box(f"{prefix}_wall_cap", (w + 0.2, 0.7, 0.25), (x, y, z0 + h + 0.1), mats["steel"], bevel=0.0)
    if buttress:
        for dx in (-w * 0.32, w * 0.32):
            T.box(f"{prefix}_buttress_{int((dx + 9) * 10)}", (0.5, 0.9, h * 0.7),
                  (x + dx, y, z0 + h * 0.35), mats["steel"], bevel=0.0)


def roof_machine(prefix, w, d, h, loc, mats):
    x, y, z0 = loc
    T.box(f"{prefix}_roofunit", (w, d, h), (x, y, z0 + h * 0.5), mats["steel"], bevel=0.02)
    T.cylinder(f"{prefix}_roofvent", min(w, d) * 0.22, h * 0.7, (x, y, z0 + h * 1.2),
               mats["brass"], vertices=8, bevel=0.0)


def vent_stack(prefix, w, h, loc, mat, glow=None):
    x, y, z0 = loc
    T.box(f"{prefix}_vent", (w, w * 0.7, h), (x, y, z0 + h * 0.5), mat, bevel=0.0)
    if glow is not None:
        T.box(f"{prefix}_vent_glow", (w * 0.7, w * 0.5, 0.08), (x, y, z0 + h * 0.85), glow, bevel=0.0)


def aether_node(prefix, r, loc, mats, ring_r=None):
    """Vertical cyan core + brass housing + containment ring."""
    x, y, z0 = loc
    T.cylinder(f"{prefix}_node_housing", r * 1.5, r * 0.9, (x, y, z0 + r * 0.45),
               mats["brass"], vertices=10, bevel=0.0)
    T.cylinder(f"{prefix}_node_core", r, r * 2.6, (x, y, z0 + r * 1.9),
               mats["aether_glow"], vertices=10, bevel=0.0)
    T.torus(f"{prefix}_node_ring", (ring_r or r * 1.9), r * 0.22, (x, y, z0 + r * 1.9),
            mats["brass"], major=14, minor=6)


def aether_conduit(a, b, mat, name, r=0.10, vertices=6):
    return T.cylinder_between(name, a, b, r, mat, vertices=vertices, bevel=0.0)


def furnace_mouth(prefix, w, h, loc, mats):
    x, y, z0 = loc
    T.box(f"{prefix}_furnace_frame", (w + 0.4, 0.3, h + 0.3), (x, y, z0 + h * 0.5),
          mats["brass"], bevel=0.0)
    T.box(f"{prefix}_furnace_mouth", (w, 0.24, h), (x, y - 0.04, z0 + h * 0.5),
          mats["furnace_glow"], bevel=0.0)


def support_frame(prefix, w, d, h, loc, mat):
    """4-post open frame + top rim (crane / platform skeleton)."""
    x, y, z0 = loc
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            T.box(f"{prefix}_frame_post_{int(sx)}_{int(sy)}", (0.28, 0.28, h),
                  (x + sx * w * 0.5, y + sy * d * 0.5, z0 + h * 0.5), mat, bevel=0.0)
    T.box(f"{prefix}_frame_rim", (w + 0.3, d + 0.3, 0.24), (x, y, z0 + h), mat, bevel=0.0)


def catwalk(prefix, w, d, loc, mats):
    x, y, z0 = loc
    T.box(f"{prefix}_catwalk", (w, d, 0.14), (x, y, z0), mats["steel"], bevel=0.0)
    for sy in (-1.0, 1.0):
        T.box(f"{prefix}_rail_{int(sy)}",
              (w, 0.08, 0.5), (x, y + sy * d * 0.5, z0 + 0.3), mats["brass"], bevel=0.0)


def crane_bridge(prefix, span, loc, mats, rail_len=8.0):
    """Loading gantry over an exit axis: 2 rails running north-south,
    legs at the rail ends, bridge spanning X, hook block under it."""
    x, y, z0 = loc
    h = 5.2
    for sx in (-1.0, 1.0):
        T.box(f"{prefix}_crane_rail_{int(sx)}", (0.3, rail_len, 0.24),
              (x + sx * span * 0.5, y, z0 + 0.12), mats["steel"], bevel=0.0)
        for dy in (-rail_len * 0.38, rail_len * 0.38):
            T.box(f"{prefix}_crane_leg_{int(sx)}_{int((dy + 9) * 10)}", (0.34, 0.34, h),
                  (x + sx * span * 0.5, y + dy, z0 + h * 0.5), mats["dark_iron"], bevel=0.0)
    T.box(f"{prefix}_crane_bridge", (span + 1.2, 0.5, 0.6), (x, y, z0 + h),
          mats["brass"], bevel=0.0)
    T.box(f"{prefix}_crane_hook", (0.5, 0.5, 0.7), (x + 0.8, y, z0 + h - 0.8),
          mats["dark_iron"], bevel=0.0)


def join_by_material(mats, asset, lod="lod0"):
    for key, mat in mats.items():
        objects = [
            obj for obj in T.bpy.context.scene.objects
            if obj.type == "MESH" and len(obj.data.materials) > 0 and obj.data.materials[0] == mat
        ]
        if not objects:
            continue
        T.bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        T.bpy.context.view_layer.objects.active = objects[0]
        T.bpy.ops.object.join()
        joined = T.bpy.context.active_object
        joined.name = f"{asset}_{key}_{lod}"
        joined.data.name = f"{asset}_{key}_{lod}_mesh"
        joined.select_set(False)

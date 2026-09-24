"""Build the Gearforge Crownpiercer production Titan.

Outputs:
  blender/source/gearforge_titan.blend
  blender/exports/gearforge_titan.glb

Design intent: a readable 11.5 m Aether siege engine with a deliberately
asymmetric Crownspike cannon, compact sensor head, load-bearing piston legs,
twin boiler stacks, and a protected rear Aether reactor. The polish pass adds
layered armor and visible load/recoil/pressure paths without changing the
established Crownpiercer silhouette, footprint, origin, or runtime anchors.
Geometry is authored from modular low-poly parts, bevelled only where
highlights help the RTS silhouette, then joined by shared material for a low
draw-call GLB. No textures or transparency.

Coordinates use Blender X right / Y depth / Z up, with front at -Y. glTF
exports Y-up; Blender -Y becomes Godot +Z, matching VisualTitan's facing and
firing code. The origin is the ground contact centre. `muzzle` remains the
runtime FX anchor expected by visual_titan.gd.

Run:
  blender --background --python blender/scripts/make_gearforge_titan.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector


ASSET = "gearforge_titan"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPT_DIR = os.path.join(ROOT, "blender", "scripts")
SOURCE_BLEND = os.path.join(ROOT, "blender", "source", ASSET + ".blend")
EXPORT_GLB = os.path.join(ROOT, "blender", "exports", ASSET + ".glb")

if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from material_lib import palette  # noqa: E402


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.actions,
    ):
        for item in list(collection):
            try:
                collection.remove(item)
            except Exception:
                pass


def apply_transform(obj, rotation=True, scale=True):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=rotation, scale=scale)
    obj.select_set(False)


def add_bevel(obj, width=0.08):
    if width <= 0.0:
        return
    bevel = obj.modifiers.new(name="production_bevel", type="BEVEL")
    bevel.width = width
    bevel.segments = 1
    bevel.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.select_set(False)


def box(name, size, loc, mat, rot=(0.0, 0.0, 0.0), bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    apply_transform(obj)
    add_bevel(obj, min(bevel, min(size) * 0.18))
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, loc, mat, vertices=12, rot=(0.0, 0.0, 0.0), bevel=0.035):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=loc,
        rotation=rot,
    )
    obj = bpy.context.active_object
    obj.name = name
    apply_transform(obj)
    add_bevel(obj, min(bevel, radius * 0.16, depth * 0.08))
    obj.data.materials.append(mat)
    return obj


def cylinder_between(name, start, end, radius, mat, vertices=10, bevel=0.025):
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    midpoint = (start_v + end_v) * 0.5
    obj = cylinder(
        name,
        radius,
        direction.length,
        midpoint,
        mat,
        vertices=vertices,
        bevel=bevel,
    )
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    apply_transform(obj)
    return obj


def torus(name, major_radius, minor_radius, loc, mat, rot=(0.0, 0.0, 0.0), major=16, minor=6):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=major,
        minor_segments=minor,
        location=loc,
        rotation=rot,
    )
    obj = bpy.context.active_object
    obj.name = name
    apply_transform(obj)
    obj.data.materials.append(mat)
    return obj


def trapezoid(name, bottom_xy, top_xy, height, loc, mat, bevel=0.04):
    bx, by = bottom_xy[0] * 0.5, bottom_xy[1] * 0.5
    tx, ty = top_xy[0] * 0.5, top_xy[1] * 0.5
    hz = height * 0.5
    verts = [
        (-bx, -by, -hz), (bx, -by, -hz), (bx, by, -hz), (-bx, by, -hz),
        (-tx, -ty, hz), (tx, -ty, hz), (tx, ty, hz), (-tx, ty, hz),
    ]
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5),
        (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (4, 0, 3, 7),
    ]
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    add_bevel(obj, bevel)
    obj.data.materials.append(mat)
    return obj


def anchor(name, loc):
    bpy.ops.object.empty_add(type="PLAIN_AXES", location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.empty_display_size = 0.35
    return obj


def build_foot(sx, mats):
    side = "l" if sx < 0 else "r"
    x = 1.58 * sx
    # Wide heel-to-toe footprint establishes mass and keeps ground contact clear.
    box(f"{ASSET}_sole_{side}", (1.74, 2.55, 0.30), (x, 0.05, 0.18), mats["dark_iron"], bevel=0.08)
    # A raised foot deck and front ram lip stop the sole reading as one flat box.
    box(f"{ASSET}_foot_deck_{side}", (1.56, 2.16, 0.18), (x, 0.02, 0.40),
        mats["steel"], bevel=0.055)
    trapezoid(f"{ASSET}_toe_{side}", (1.70, 1.45), (1.34, 1.15), 0.48,
              (x, -0.70, 0.55), mats["steel"], bevel=0.06)
    box(f"{ASSET}_toe_ram_{side}", (1.42, 0.20, 0.27), (x, -1.20, 0.48),
        mats["brass"], bevel=0.035)
    box(f"{ASSET}_heel_{side}", (1.42, 0.72, 0.62), (x, 0.92, 0.53), mats["dark_iron"], bevel=0.08)
    box(f"{ASSET}_heel_cap_{side}", (1.22, 0.18, 0.48), (x, 1.29, 0.56),
        mats["steel"], bevel=0.045)
    cylinder(f"{ASSET}_ankle_{side}", 0.56, 0.72, (x, 0.10, 0.92), mats["brass"], vertices=12)
    cylinder(f"{ASSET}_ankle_axle_{side}", 0.34, 1.48, (x, 0.02, 1.02), mats["dark_iron"],
             vertices=12, rot=(0.0, math.radians(90.0), 0.0))
    # Fork and ram make the transfer from ankle axle into the sole explicit.
    for ox in (-0.54, 0.54):
        cylinder_between(
            f"{ASSET}_ankle_fork_{side}_{int((ox + 0.6) * 10)}",
            (x + ox, 0.38, 0.55), (x + ox, 0.20, 1.34),
            0.11, mats["dark_iron"], vertices=8)
    cylinder_between(f"{ASSET}_ankle_ram_{side}", (x, -0.52, 0.62),
                     (x, -0.42, 1.46), 0.14, mats["copper"], vertices=10)

    # Reversed-knee industrial leg: large armor masses plus exposed piston pairs.
    box(f"{ASSET}_shin_{side}", (1.10, 1.08, 2.05), (x, 0.20, 2.02), mats["dark_iron"],
        rot=(math.radians(-5.0), 0.0, 0.0), bevel=0.10)
    trapezoid(f"{ASSET}_shin_armor_{side}", (1.44, 0.54), (1.15, 0.42), 1.75,
              (x, -0.57, 2.13), mats["steel"], bevel=0.07)
    cylinder(f"{ASSET}_knee_{side}", 0.58, 1.42, (x, -0.16, 3.08), mats["brass"],
             vertices=14, rot=(0.0, math.radians(90.0), 0.0))
    cylinder(f"{ASSET}_knee_cap_{side}", 0.37, 1.58, (x, -0.16, 3.08), mats["dark_iron"],
             vertices=12, rot=(0.0, math.radians(90.0), 0.0))
    trapezoid(f"{ASSET}_knee_guard_{side}", (1.18, 0.36), (0.88, 0.26), 0.76,
              (x, -0.73, 3.10), mats["steel"], bevel=0.055)
    cylinder(f"{ASSET}_knee_outer_cap_{side}", 0.28, 0.16,
             (x + sx * 0.78, -0.16, 3.08), mats["brass"], vertices=12,
             rot=(0.0, math.radians(90.0), 0.0), bevel=0.02)
    box(f"{ASSET}_thigh_{side}", (1.26, 1.26, 1.58), (x, 0.26, 3.88), mats["dark_iron"],
        rot=(math.radians(7.0), 0.0, 0.0), bevel=0.11)
    box(f"{ASSET}_thigh_plate_{side}", (1.40, 0.36, 1.18), (x, -0.53, 3.92), mats["steel"], bevel=0.06)
    box(f"{ASSET}_thigh_crown_{side}", (1.48, 1.12, 0.24), (x, 0.18, 4.58),
        mats["bronze"], bevel=0.05)

    for offset in (-0.38, 0.38):
        cylinder_between(
            f"{ASSET}_shin_piston_{side}_{int((offset + 0.5) * 10)}",
            (x + offset, 0.72, 1.15),
            (x + offset, 0.68, 2.88),
            0.105,
            mats["copper"],
            vertices=8,
        )
        cylinder_between(
            f"{ASSET}_thigh_piston_{side}_{int((offset + 0.5) * 10)}",
            (x + offset, 0.66, 3.02),
            (x + offset, 0.78, 4.58),
            0.095,
            mats["brass"],
            vertices=8,
        )
    # Front diagonal actuators remain visible from the normal quarter camera.
    cylinder_between(f"{ASSET}_front_leg_ram_{side}", (x - sx * 0.38, -0.50, 1.18),
                     (x - sx * 0.48, -0.52, 2.78), 0.095,
                     mats["copper"], vertices=8)
    # One readable rivet row per shin; enough for close-up scale without noise.
    for rx in (-0.38, 0.38):
        for rz in (1.66, 2.56):
            cylinder(f"{ASSET}_shin_rivet_{side}_{int((rx + 0.5) * 10)}_{int(rz * 10)}",
                     0.09, 0.10, (x + rx, -0.80, rz), mats["brass"], vertices=8,
                     rot=(math.radians(90.0), 0.0, 0.0), bevel=0.01)


def build_body(mats):
    # Five large forms read first: two legs, hip deck, armored torso, cannon.
    cylinder(f"{ASSET}_hip_turntable", 2.14, 0.72, (0.0, 0.08, 4.72), mats["dark_iron"], vertices=16)
    box(f"{ASSET}_hip_beam", (4.45, 2.55, 0.70), (0.0, 0.08, 4.86), mats["steel"], bevel=0.11)
    trapezoid(f"{ASSET}_torso", (4.60, 3.38), (3.88, 2.86), 2.52,
              (0.0, 0.12, 6.35), mats["dark_iron"], bevel=0.12)
    box(f"{ASSET}_torso_front_plate", (3.58, 0.34, 1.82), (0.0, -1.62, 6.48),
        mats["steel"], rot=(math.radians(-4.0), 0.0, 0.0), bevel=0.09)
    # Layered glacis panels break the large front plane while preserving its
    # broad, low read. The centre keel visually carries the governor's mass.
    for sx in (-1.0, 1.0):
        side = "l" if sx < 0 else "r"
        box(f"{ASSET}_glacis_{side}", (1.06, 0.20, 0.72),
            (sx * 1.35, -1.86, 7.02), mats["dark_iron"],
            rot=(0.0, 0.0, math.radians(-sx * 7.0)), bevel=0.06)
        box(f"{ASSET}_torso_side_rib_{side}", (0.24, 2.18, 1.62),
            (sx * 2.22, 0.02, 6.44), mats["steel"], bevel=0.055)
    trapezoid(f"{ASSET}_governor_keel", (1.32, 0.24), (0.92, 0.18), 0.88,
              (0.0, -1.93, 5.76), mats["dark_iron"], bevel=0.055)
    box(f"{ASSET}_torso_belt", (4.42, 3.12, 0.27), (0.0, 0.04, 5.53), mats["brass"], bevel=0.035)
    box(f"{ASSET}_top_deck", (3.85, 2.82, 0.30), (0.0, 0.18, 7.67), mats["bronze"], bevel=0.06)
    box(f"{ASSET}_top_deck_front_lip", (3.42, 0.22, 0.22), (0.0, -1.35, 7.76),
        mats["brass"], bevel=0.035)

    # Chest Aether governor: a small, meaningful energy focal point.
    cylinder(f"{ASSET}_chest_core_housing", 0.78, 0.42, (0.0, -1.87, 6.62), mats["brass"],
             vertices=16, rot=(math.radians(90.0), 0.0, 0.0))
    cylinder(f"{ASSET}_chest_core", 0.52, 0.48, (0.0, -2.02, 6.62), mats["aether_glow"],
             vertices=16, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.02)
    torus(f"{ASSET}_chest_core_ring", 0.70, 0.10, (0.0, -2.13, 6.62), mats["brass"],
          rot=(math.radians(90.0), 0.0, 0.0), major=16, minor=6)
    for sx in (-1.0, 1.0):
        cylinder_between(f"{ASSET}_governor_lock_{'l' if sx < 0 else 'r'}",
                         (sx * 0.78, -2.00, 6.12), (sx * 0.78, -2.00, 7.10),
                         0.085, mats["copper"], vertices=8)
    for x in (-1.46, 1.46):
        box(f"{ASSET}_chest_vent_{int(x * 10)}", (0.72, 0.16, 0.95), (x, -1.86, 6.42),
            mats["rust"], bevel=0.025)
        for z in (6.13, 6.42, 6.71):
            box(f"{ASSET}_vent_slit_{int(x * 10)}_{int(z * 100)}", (0.52, 0.12, 0.07),
                (x, -1.98, z), mats["dark_iron"], bevel=0.01)

    # Compact sensor head stays subordinate to the machine and main weapon.
    cylinder(f"{ASSET}_neck", 0.46, 0.48, (0.0, -0.42, 7.98), mats["brass"], vertices=12)
    trapezoid(f"{ASSET}_sensor_head", (1.40, 1.24), (1.05, 0.92), 0.88,
              (0.0, -0.74, 8.52), mats["dark_iron"], bevel=0.09)
    box(f"{ASSET}_sensor_brow", (1.18, 0.22, 0.20), (0.0, -1.32, 8.62), mats["brass"], bevel=0.025)
    box(f"{ASSET}_sensor_visor", (0.86, 0.12, 0.22), (0.0, -1.45, 8.48), mats["aether_glow"], bevel=0.025)
    for sx in (-1.0, 1.0):
        box(f"{ASSET}_sensor_cheek_{'l' if sx < 0 else 'r'}", (0.22, 0.72, 0.46),
            (sx * 0.62, -0.74, 8.40), mats["steel"],
            rot=(0.0, 0.0, math.radians(sx * 6.0)), bevel=0.045)
    cylinder(f"{ASSET}_rangefinder", 0.20, 0.52, (0.70, -0.72, 8.66), mats["copper"],
             vertices=10, rot=(0.0, math.radians(90.0), 0.0))


def build_cannon(mats):
    # The Crownspike is an arm-mounted siege lance, not a torso tube.
    x = -2.72
    cylinder(f"{ASSET}_cannon_shoulder_axle", 0.74, 1.28, (-2.22, 0.0, 7.30), mats["brass"],
             vertices=16, rot=(0.0, math.radians(90.0), 0.0))
    box(f"{ASSET}_cannon_shoulder", (1.66, 2.12, 1.58), (x, -0.02, 7.30), mats["steel"], bevel=0.13)
    box(f"{ASSET}_cannon_breech", (1.72, 2.20, 1.36), (x, -1.48, 7.26), mats["dark_iron"], bevel=0.12)
    box(f"{ASSET}_cannon_top_armor", (1.92, 1.58, 0.30), (x, -1.42, 8.02), mats["bronze"], bevel=0.05)
    # Rear counterweight, trunnion collars, and a lower recoil cradle explain
    # how the torso carries the long barrel instead of treating it as a tube.
    box(f"{ASSET}_cannon_counterweight", (1.44, 0.70, 1.12), (x, 0.86, 7.22),
        mats["dark_iron"], bevel=0.10)
    box(f"{ASSET}_cannon_counterweight_cap", (1.58, 0.18, 0.82), (x, 1.22, 7.22),
        mats["steel"], bevel=0.045)
    torus(f"{ASSET}_cannon_outer_trunnion", 0.71, 0.105, (-3.60, 0.0, 7.30),
          mats["brass"], rot=(0.0, math.radians(90.0), 0.0), major=16, minor=6)
    for rx in (-0.56, 0.56):
        box(f"{ASSET}_recoil_cradle_{int((rx + 0.6) * 10)}", (0.18, 3.52, 0.22),
            (x + rx, -2.48, 6.68), mats["steel"], bevel=0.025)
        cylinder_between(f"{ASSET}_recoil_ram_{int((rx + 0.6) * 10)}",
                         (x + rx, -0.72, 6.86), (x + rx, -3.92, 6.86),
                         0.105, mats["copper"], vertices=8)
    for y in (-1.05, -2.42, -3.80):
        box(f"{ASSET}_cradle_crossbar_{int(abs(y) * 100)}", (1.42, 0.16, 0.18),
            (x, y, 6.68), mats["brass"], bevel=0.025)
    cylinder_between(f"{ASSET}_cannon_mount_strut_front", (-1.82, -0.72, 6.18),
                     (-2.40, -0.22, 6.72), 0.14, mats["brass"], vertices=10)
    cylinder_between(f"{ASSET}_cannon_mount_strut_rear", (-1.82, 0.72, 6.18),
                     (-2.40, 0.36, 6.72), 0.14, mats["dark_iron"], vertices=10)

    cylinder(f"{ASSET}_cannon_shroud", 0.66, 2.55, (x, -3.34, 7.26), mats["steel"],
             vertices=16, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.05)
    for y in (-2.45, -3.56, -4.42):
        torus(f"{ASSET}_cannon_band_{int(abs(y) * 100)}", 0.70, 0.11, (x, y, 7.26), mats["brass"],
              rot=(math.radians(90.0), 0.0, 0.0), major=16, minor=6)
    cylinder(f"{ASSET}_cannon_barrel", 0.38, 2.72, (x, -5.05, 7.26), mats["dark_iron"],
             vertices=16, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.035)
    cylinder(f"{ASSET}_cannon_muzzle", 0.78, 0.78, (x, -6.34, 7.26), mats["bronze"],
             vertices=16, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.06)
    cylinder(f"{ASSET}_cannon_bore", 0.48, 0.12, (x, -6.76, 7.26), mats["dark_iron"],
             vertices=16, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.01)
    cylinder(f"{ASSET}_cannon_aether_lens", 0.25, 0.13, (x, -6.84, 7.26), mats["aether_glow"],
             vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.01)

    # Cooling rails make the gun's length legible at mid and strategic zoom.
    for rail_x in (-0.73, 0.73):
        box(f"{ASSET}_cannon_rail_{int(rail_x * 100)}", (0.16, 3.10, 0.20),
            (x + rail_x, -3.82, 7.62), mats["copper"], bevel=0.025)
    for y in (-2.72, -3.45, -4.18):
        box(f"{ASSET}_cannon_fin_{int(abs(y) * 100)}", (1.76, 0.12, 1.02),
            (x, y, 7.28), mats["dark_iron"], bevel=0.025)
    cylinder(f"{ASSET}_breech_lock", 0.82, 0.24, (x, -2.20, 7.26), mats["brass"],
             vertices=16, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.025)

    # Deliberate energy route: rear reactor -> chest governor -> breech -> muzzle.
    cylinder_between(f"{ASSET}_weapon_feed_a", (-0.42, -1.82, 6.72), (-1.38, -1.76, 7.30),
                     0.12, mats["aether_glow"], vertices=8)
    cylinder_between(f"{ASSET}_weapon_feed_b", (-1.38, -1.76, 7.30), (x + 0.65, -1.72, 7.30),
                     0.12, mats["aether_glow"], vertices=8)
    anchor("muzzle", (x, -6.92, 7.26))


def build_brace_arm(mats):
    # Opposite arm is a compact siege brace: broad, low, and visually distinct
    # from the long cannon so the silhouette has a clear front-side asymmetry.
    x = 2.75
    cylinder(f"{ASSET}_brace_shoulder_axle", 0.76, 1.28, (2.20, 0.02, 7.28), mats["brass"],
             vertices=16, rot=(0.0, math.radians(90.0), 0.0))
    box(f"{ASSET}_brace_shoulder", (1.72, 2.04, 1.68), (x, 0.02, 7.25), mats["steel"], bevel=0.14)
    box(f"{ASSET}_brace_shoulder_crown", (1.54, 1.62, 0.28), (x, -0.02, 8.10),
        mats["bronze"], bevel=0.055)
    box(f"{ASSET}_brace_upper", (1.22, 1.34, 1.48), (3.15, 0.14, 6.12), mats["dark_iron"],
        rot=(0.0, math.radians(-4.0), math.radians(-8.0)), bevel=0.11)
    cylinder(f"{ASSET}_brace_elbow", 0.48, 1.35, (3.28, -0.02, 5.31), mats["brass"],
             vertices=12, rot=(0.0, math.radians(90.0), 0.0))
    trapezoid(f"{ASSET}_brace_gauntlet", (1.46, 1.70), (1.18, 1.40), 1.78,
              (3.36, -0.05, 4.53), mats["dark_iron"], bevel=0.11)
    box(f"{ASSET}_brace_face", (1.24, 0.28, 1.26), (3.36, -0.90, 4.52), mats["steel"], bevel=0.06)
    box(f"{ASSET}_brace_press_plate", (0.78, 0.16, 0.82), (3.36, -1.08, 4.52),
        mats["bronze"], bevel=0.04)
    for dx in (-0.40, 0.0, 0.40):
        box(f"{ASSET}_brace_tooth_{int((dx + 0.5) * 100)}", (0.28, 0.72, 0.35),
            (3.36 + dx, -0.50, 3.53), mats["bronze"], bevel=0.04)
    cylinder_between(f"{ASSET}_brace_piston_outer", (3.56, 0.72, 6.88), (3.70, 0.68, 5.12),
                     0.13, mats["copper"], vertices=8)
    cylinder_between(f"{ASSET}_brace_piston_inner", (2.78, 0.70, 6.75), (2.92, 0.66, 5.22),
                     0.11, mats["brass"], vertices=8)
    cylinder_between(f"{ASSET}_brace_shock", (3.52, -0.56, 6.72), (3.58, -0.48, 5.26),
                     0.14, mats["copper"], vertices=10)
    for sx in (-1.0, 1.0):
        box(f"{ASSET}_brace_side_rail_{'l' if sx < 0 else 'r'}", (0.16, 1.24, 0.20),
            (3.36 + sx * 0.60, -0.08, 4.62), mats["brass"], bevel=0.025)
    box(f"{ASSET}_brace_rear_block", (1.14, 0.52, 0.82), (3.28, 0.78, 5.62),
        mats["dark_iron"], bevel=0.075)


def build_reactor_and_exhaust(mats):
    # Twin pressure drums and stacks create the back-view 'industrial crown'.
    for sx in (-1.18, 1.18):
        side = "l" if sx < 0 else "r"
        cylinder(f"{ASSET}_rear_boiler_{side}", 0.66, 2.45, (sx, 1.38, 7.54), mats["copper"], vertices=14)
        cylinder(f"{ASSET}_boiler_lower_cap_{side}", 0.74, 0.22, (sx, 1.38, 6.31),
                 mats["dark_iron"], vertices=14, bevel=0.025)
        cylinder(f"{ASSET}_boiler_upper_cap_{side}", 0.74, 0.22, (sx, 1.38, 8.77),
                 mats["bronze"], vertices=14, bevel=0.025)
        for z in (6.55, 7.55, 8.54):
            torus(f"{ASSET}_boiler_band_{side}_{int(z * 100)}", 0.68, 0.085, (sx, 1.38, z),
                  mats["brass"], major=14, minor=6)
        cylinder(f"{ASSET}_stack_{side}", 0.37, 2.28, (sx, 1.40, 10.02), mats["dark_iron"], vertices=12)
        cylinder(f"{ASSET}_stack_collar_{side}", 0.47, 0.25, (sx, 1.40, 9.18), mats["brass"], vertices=12)
        cylinder(f"{ASSET}_stack_lip_{side}", 0.53, 0.30, (sx, 1.40, 11.20), mats["brass"], vertices=12)
        cylinder(f"{ASSET}_stack_heat_{side}", 0.34, 0.08, (sx, 1.40, 11.38), mats["furnace_glow"], vertices=12,
                 bevel=0.01)
        anchor(f"exhaust_{side}", (sx, 1.40, 11.45))
        cylinder_between(f"{ASSET}_stack_stay_{side}", (sx, 1.38, 9.18),
                         (sx * 1.72, 0.78, 8.20), 0.09,
                         mats["brass"], vertices=8)

    # Rear reactor is visible only from the back, preventing a front glow overload.
    cylinder(f"{ASSET}_reactor_housing", 1.05, 0.74, (0.0, 2.03, 7.12), mats["dark_iron"],
             vertices=16, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.05)
    cylinder(f"{ASSET}_reactor_core", 0.69, 0.80, (0.0, 2.34, 7.12), mats["aether_glow"],
             vertices=16, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.03)
    torus(f"{ASSET}_reactor_ring", 0.94, 0.13, (0.0, 2.47, 7.12), mats["brass"],
          rot=(math.radians(90.0), 0.0, 0.0), major=18, minor=6)
    # Four bolted cage rails protect the exposed core and create a readable
    # rear depth stack: armor frame -> containment ring -> luminous core.
    for sx in (-1.0, 1.0):
        side = "l" if sx < 0 else "r"
        box(f"{ASSET}_reactor_cage_vertical_{side}", (0.18, 0.18, 1.86),
            (sx * 1.16, 2.30, 7.12), mats["steel"], bevel=0.035)
        cylinder_between(f"{ASSET}_lower_pressure_pipe_{side}",
                         (sx * 1.18, 1.78, 6.42), (sx * 1.70, 1.04, 5.32),
                         0.12, mats["copper"], vertices=8)
    for z in (6.16, 8.08):
        box(f"{ASSET}_reactor_cage_cross_{int(z * 100)}", (2.42, 0.18, 0.18),
            (0.0, 2.30, z), mats["brass"], bevel=0.035)
    box(f"{ASSET}_rear_manifold", (2.18, 0.42, 0.46), (0.0, 1.73, 5.48),
        mats["dark_iron"], bevel=0.07)
    for sx in (-0.72, 0.72):
        cylinder(f"{ASSET}_manifold_valve_{int(sx * 100)}", 0.20, 0.18,
                 (sx, 1.96, 5.48), mats["brass"], vertices=10,
                 rot=(math.radians(90.0), 0.0, 0.0), bevel=0.015)
    anchor("reactor_anchor", (0.0, 2.52, 7.12))

    # Copper service pipes and a back armor chevron make the rear intentional.
    for sx in (-1.0, 1.0):
        side = "l" if sx < 0 else "r"
        cylinder_between(f"{ASSET}_reactor_pipe_a_{side}", (sx * 0.60, 2.12, 7.18),
                         (sx * 1.18, 1.90, 8.04), 0.115, mats["copper"], vertices=8)
        cylinder_between(f"{ASSET}_reactor_pipe_b_{side}", (sx * 1.18, 1.90, 8.04),
                         (sx * 1.18, 1.62, 8.78), 0.115, mats["copper"], vertices=8)
        box(f"{ASSET}_back_chevron_{side}", (0.20, 0.14, 1.22),
            (sx * 0.72, 2.31, 5.95), mats["aether_glow"],
            rot=(0.0, 0.0, math.radians(-sx * 30.0)), bevel=0.025)

    # Small upper-deck pressure gauges, readable as brass punctuation only close-up.
    for x in (-0.48, 0.48):
        cylinder(f"{ASSET}_deck_valve_{int(x * 100)}", 0.19, 0.28, (x, 0.80, 8.06), mats["brass"], vertices=10)
        torus(f"{ASSET}_deck_wheel_{int(x * 100)}", 0.28, 0.055, (x, 0.80, 8.30), mats["copper"], major=12, minor=5)


def join_by_material(mats):
    """Collapse modular construction pieces into one mesh per material."""
    for key, mat in mats.items():
        objects = [
            obj for obj in bpy.context.scene.objects
            if obj.type == "MESH" and len(obj.data.materials) > 0 and obj.data.materials[0] == mat
        ]
        if not objects:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        joined = bpy.context.active_object
        joined.name = f"{ASSET}_{key}_lod0"
        joined.data.name = f"{ASSET}_{key}_lod0_mesh"
        joined.select_set(False)


def mesh_stats():
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    verts = sum(len(obj.data.vertices) for obj in meshes)
    polygons = sum(len(obj.data.polygons) for obj in meshes)
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    materials = {slot.material.name for obj in meshes for slot in obj.material_slots if slot.material}
    print(
        "TITAN_STATS meshes=%d verts=%d polygons=%d triangles=%d materials=%d"
        % (len(meshes), verts, polygons, triangles, len(materials))
    )
    return len(meshes), verts, polygons, triangles, len(materials)


def main():
    clear_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["asset_name"] = ASSET
    scene["design_variant"] = "B_aether_siege_engine"
    scene["production_name"] = "Crownpiercer"
    scene["forward_axis"] = "-Y"
    scene["up_axis"] = "+Z"
    scene["texture_count"] = 0
    scene["visual_pass"] = "reference_informed_polish"

    mats = palette("gearforge")
    build_foot(-1.0, mats)
    build_foot(1.0, mats)
    build_body(mats)
    build_cannon(mats)
    build_brace_arm(mats)
    build_reactor_and_exhaust(mats)
    join_by_material(mats)
    stats = mesh_stats()
    scene["mesh_count"] = stats[0]
    scene["vertex_count"] = stats[1]
    scene["polygon_count"] = stats[2]
    scene["triangle_count"] = stats[3]
    scene["material_count"] = stats[4]

    bpy.ops.object.select_all(action="SELECT")
    os.makedirs(os.path.dirname(SOURCE_BLEND), exist_ok=True)
    os.makedirs(os.path.dirname(EXPORT_GLB), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE_BLEND)
    print("SAVE_BLEND_OK", SOURCE_BLEND)
    bpy.ops.export_scene.gltf(
        filepath=EXPORT_GLB,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_materials="EXPORT",
        export_animations=False,
    )
    print("EXPORT_GLB_OK", EXPORT_GLB, os.path.getsize(EXPORT_GLB), "bytes")


if __name__ == "__main__":
    main()

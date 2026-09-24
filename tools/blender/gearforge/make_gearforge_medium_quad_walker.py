"""Build the Gearforge Ironbastion medium quad-walker (Phase 2 Prototype).

Asset:
  blender/source/gearforge_medium_quad_walker.blend
  game/assets/models/gearforge_medium_quad_walker.glb

Design Intent:
  Gearforge Ironbastion - A mass-produced medium quadruped military support walker.
  Sits between the 1.8m infantry and the 11.4m Crownpiercer Titan, slightly larger
  and much more stable/heavily armored than the 4.54m bipedal Ironstride.
  Features a wide, low-slung 4-legged stance, heavy cast-iron chassis, rear copper
  boiler with twin angled exhaust stacks, brass traverse ring, and an armored
  turret housing twin heavy recoil cannons with copper recoil cylinders.

Visual reference standard:
  High industrial steampunk density, exposed hydraulic pistons and steam conduits,
  brass/iron/steel hierarchy, clear RTS silhouette, and authentic Gearforge motifs.

Units: Metric (1 BU = 1 meter)
Coordinates: Blender X right, Y depth (front = -Y), Z up
glTF export: Y-up (Blender -Y -> Godot +Z)
"""

import math
import os
import sys

import bpy
from mathutils import Vector, Quaternion

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from material_lib import palette  # noqa: E402

ASSET = "gearforge_medium_quad_walker"
PRODUCTION_NAME = "Ironbastion"
UNIT_CLASS = "medium_quad_support_walker"
ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
SOURCE_BLEND = os.path.join(ROOT, "blender", "source", ASSET + ".blend")
EXPORT_GLB = os.path.join(ROOT, "game", "assets", "models", ASSET + ".glb")
INTERMEDIATE_GLB = os.path.join(ROOT, "blender", "exports", ASSET + ".glb")

# ------------------------------------------------------------ Geometry Helpers

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for col in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.actions):
        for item in list(col):
            try:
                col.remove(item)
            except Exception:
                pass


def apply_transform(obj, location=False, rotation=True, scale=True):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=location, rotation=rotation, scale=scale)
    obj.select_set(False)


def add_bevel(obj, width=0.04):
    if width <= 0.0:
        return
    bevel = obj.modifiers.new(name="bevel", type="BEVEL")
    bevel.width = width
    bevel.segments = 1
    bevel.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.select_set(False)


def box(name, size, loc, mat, rot=(0.0, 0.0, 0.0), bevel=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    apply_transform(obj)
    if bevel > 0.0:
        add_bevel(obj, min(bevel, min(size) * 0.2))
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, loc, mat, vertices=12, rot=(0.0, 0.0, 0.0), bevel=0.0):
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
    if bevel > 0.0:
        add_bevel(obj, min(bevel, radius * 0.2))
    obj.data.materials.append(mat)
    return obj


def torus(name, major_r, minor_r, loc, mat, rot=(0.0, 0.0, 0.0), major_seg=14, minor_seg=6):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_r,
        minor_radius=minor_r,
        location=loc,
        rotation=rot,
        major_segments=major_seg,
        minor_segments=minor_seg,
    )
    obj = bpy.context.active_object
    obj.name = name
    apply_transform(obj)
    obj.data.materials.append(mat)
    return obj


def cylinder_between(name, p1, p2, radius, mat, vertices=10, bevel=0.0):
    a, b = Vector(p1), Vector(p2)
    delta = b - a
    length = delta.length
    if length < 1e-6:
        return None
    mid = (a + b) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length, location=mid)
    obj = bpy.context.active_object
    obj.name = name
    up = Vector((0.0, 0.0, 1.0))
    rot_diff = up.rotation_difference(delta.normalized())
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = rot_diff
    apply_transform(obj)
    if bevel > 0.0:
        add_bevel(obj, min(bevel, radius * 0.2))
    obj.data.materials.append(mat)
    return obj


def box_between(name, p1, p2, width, depth, mat, bevel=0.03):
    a, b = Vector(p1), Vector(p2)
    delta = b - a
    length = delta.length
    if length < 1e-6:
        return None
    mid = (a + b) * 0.5
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=mid)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (width, depth, length)
    apply_transform(obj)
    up = Vector((0.0, 0.0, 1.0))
    rot_diff = up.rotation_difference(delta.normalized())
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = rot_diff
    apply_transform(obj)
    if bevel > 0.0:
        add_bevel(obj, min(bevel, min(width, depth) * 0.2))
    obj.data.materials.append(mat)
    return obj


def anchor(name, loc):
    bpy.ops.object.empty_add(type="PLAIN_AXES", location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.empty_display_size = 0.40
    return obj


# ------------------------------------------------------------ Walker Stations
# Height hierarchy:
# Infantry: 1.8m, Ironstride: 4.54m, Ironbastion: ~5.6m, Titan: 11.4m
# Ground contact at Z=0.0
# Stance: 4 legs splayed diagonally outward for heavy gun recoil stabilization.
# Front is -Y, Back is +Y.
HULL_Z = 2.65       # Central chassis center
HULL_TOP_Z = 3.35   # Chassis top surface (traverse ring mount)
TURRET_Z = 3.85     # Turret pivot center
CANNON_Z = 4.12     # Twin cannon axis
STACK_TOP_Z = 5.60  # Exhaust stack top

# 4 Hip sockets located at chassis corners
HIP_OFFSETS = {
    "fl": (-1.35, -1.15, 2.50),  # Front-Left
    "fr": ( 1.35, -1.15, 2.50),  # Front-Right
    "rl": (-1.35,  1.25, 2.50),  # Rear-Left
    "rr": ( 1.35,  1.25, 2.50),  # Rear-Right
}

# Knee stations flare outward and slightly forward/back
KNEE_OFFSETS = {
    "fl": (-2.35, -1.75, 1.80),
    "fr": ( 2.35, -1.75, 1.80),
    "rl": (-2.35,  1.85, 1.80),
    "rr": ( 2.35,  1.85, 1.80),
}

# Ankle stations reach down and out to the massive ram feet
ANKLE_OFFSETS = {
    "fl": (-2.55, -2.25, 0.55),
    "fr": ( 2.55, -2.25, 0.55),
    "rl": (-2.55,  2.35, 0.55),
    "rr": ( 2.55,  2.35, 0.55),
}

FOOT_OFFSETS = {
    "fl": (-2.55, -2.25, 0.12),
    "fr": ( 2.55, -2.25, 0.12),
    "rl": (-2.55,  2.35, 0.12),
    "rr": ( 2.55,  2.35, 0.12),
}

GROUPS = ("leg_fl", "leg_fr", "leg_rl", "leg_rr", "turret", "hull")


# ------------------------------------------------------------ Sub-assemblies

def build_quad_leg(leg_id, mats):
    """Build one of the 4 heavy hydraulic legs with rich industrial density."""
    prefix = f"{ASSET}_{leg_id}"
    H = mats["dark_iron"]
    S = mats["steel"]
    B = mats["brass"]
    C = mats["copper"]

    tag = leg_id.replace("leg_", "")
    hip = HIP_OFFSETS[tag]
    knee = KNEE_OFFSETS[tag]
    ankle = ANKLE_OFFSETS[tag]
    foot = FOOT_OFFSETS[tag]
    sx = -1.0 if "l" in tag else 1.0
    is_front = "f" in tag

    # 1. Hip joint & mounting hub on hull
    cylinder(f"{prefix}_hip_hub", 0.42, 0.52, hip, H, vertices=12,
             rot=(0.0, math.radians(90.0), 0.0), bevel=0.03)
    torus(f"{prefix}_hip_ring", 0.44, 0.06, hip, B,
          rot=(0.0, math.radians(90.0), 0.0))
    cylinder(f"{prefix}_hip_pin", 0.22, 0.58, hip, S, vertices=10,
             rot=(0.0, math.radians(90.0), 0.0))
    # Hip reinforcement gusset
    box(f"{prefix}_hip_gusset", (0.32, 0.38, 0.44),
        (hip[0] - sx * 0.15, hip[1], hip[2] + 0.18), H, bevel=0.02)

    # 2. Thigh (Upper Leg) - Heavy Armored Truss & Hydraulic Cylinders
    box_between(f"{prefix}_thigh_beam", hip, knee, 0.44, 0.50, H, bevel=0.04)
    # Steel armor plate over thigh
    thigh_mid = Vector(hip).lerp(Vector(knee), 0.5)
    box_between(f"{prefix}_thigh_plate",
                Vector(hip) + Vector((sx * 0.12, 0.0, 0.10)),
                Vector(knee) + Vector((sx * 0.12, 0.0, 0.10)),
                0.26, 0.54, S, bevel=0.03)

    # Dual copper hydraulic rams along thigh (industrial density)
    for p_idx, y_mult in ((0, 0.18), (1, -0.18)):
        ram_offset = Vector((0.0, y_mult, -0.12))
        p_start = Vector(hip) + ram_offset
        p_mid = Vector(thigh_mid) + ram_offset
        p_end = Vector(knee) + ram_offset
        cylinder_between(f"{prefix}_thigh_piston_cyl_{p_idx}", p_start, p_mid, 0.075, C, vertices=8)
        cylinder_between(f"{prefix}_thigh_piston_rod_{p_idx}", p_mid, p_end, 0.045, S, vertices=8)
        torus(f"{prefix}_thigh_piston_collar_{p_idx}", 0.085, 0.02, p_mid, B)

    # 3. Knee joint - Heavy Brass Pivot with Cap & Armored Guard
    cylinder(f"{prefix}_knee_hub", 0.40, 0.48, knee, B, vertices=12,
             rot=(0.0, math.radians(90.0), 0.0), bevel=0.03)
    cylinder(f"{prefix}_knee_core", 0.22, 0.54, knee, H, vertices=10,
             rot=(0.0, math.radians(90.0), 0.0))
    torus(f"{prefix}_knee_ring", 0.42, 0.045, knee, B,
          rot=(0.0, math.radians(90.0), 0.0))

    # Knee armor guard (heavy knee cap)
    cap_y_off = -0.24 if is_front else 0.24
    box(f"{prefix}_knee_guard", (0.38, 0.20, 0.46),
        (knee[0] + sx * 0.04, knee[1] + cap_y_off, knee[2]), S, bevel=0.03)
    # Knee bolt accents
    for b_z in (-0.14, 0.14):
        cylinder(f"{prefix}_knee_bolt_{int(b_z * 100)}", 0.045, 0.24,
                 (knee[0] + sx * 0.04, knee[1] + cap_y_off * 1.15, knee[2] + b_z),
                 B, vertices=6, rot=(math.radians(90.0), 0.0, 0.0))

    # 4. Shin (Lower Leg) - Dual reinforced struts angled to foot
    box_between(f"{prefix}_shin_beam", knee, ankle, 0.40, 0.46, H, bevel=0.03)
    # Front/rear shin shield plate
    shin_plate_y = -0.12 if is_front else 0.12
    box_between(f"{prefix}_shin_shield",
                Vector(knee) + Vector((0.0, shin_plate_y, -0.08)),
                Vector(ankle) + Vector((0.0, shin_plate_y, 0.15)),
                0.32, 0.16, S, bevel=0.03)

    # Lateral heavy secondary damper
    strut_mid_a = Vector(knee).lerp(Vector(ankle), 0.15) + Vector((sx * 0.14, 0.0, -0.05))
    strut_mid_b = Vector(knee).lerp(Vector(ankle), 0.85) + Vector((sx * 0.14, 0.0, -0.05))
    strut_center = strut_mid_a.lerp(strut_mid_b, 0.52)
    cylinder_between(f"{prefix}_shin_damper_cyl", strut_mid_a, strut_center, 0.085, C, vertices=8)
    cylinder_between(f"{prefix}_shin_damper_rod", strut_center, strut_mid_b, 0.05, S, vertices=8)
    torus(f"{prefix}_shin_damper_ring", 0.095, 0.02, strut_center, B)

    # 5. Ankle joint
    cylinder(f"{prefix}_ankle_pin", 0.28, 0.44, ankle, B, vertices=10,
             rot=(0.0, math.radians(90.0), 0.0), bevel=0.02)
    box(f"{prefix}_ankle_bracket", (0.34, 0.36, 0.30), ankle, H, bevel=0.02)

    # 6. Heavy Foot Assembly (Wide stabilized ram pad with claws & shock absorbers)
    fx, fy, fz = foot
    # Main cast-iron ground ram pad
    box(f"{prefix}_foot_pad", (1.25, 1.45, 0.22), (fx, fy, fz), H, bevel=0.03)
    # Steel reinforced upper deck on foot
    box(f"{prefix}_foot_deck", (1.00, 1.15, 0.18), (fx, fy, fz + 0.18), S, bevel=0.02)

    # Ground grip claws / cleats
    claw_dir_y = -1.0 if is_front else 1.0
    # Front claws (2 forward teeth with brass tips)
    for c_dx in (-0.36, 0.36):
        box(f"{prefix}_claw_{int(c_dx * 100)}", (0.24, 0.40, 0.18),
            (fx + c_dx, fy + claw_dir_y * 0.72, fz - 0.02), B, bevel=0.02)
    # Rear heel claw / spur
    box(f"{prefix}_heel_spur", (0.55, 0.36, 0.20),
        (fx, fy - claw_dir_y * 0.70, fz + 0.02), S, bevel=0.02)
    # Lateral anti-slip cleats
    for s_dy in (-0.35, 0.35):
        box(f"{prefix}_side_cleat_{int(s_dy * 100)}", (0.16, 0.30, 0.14),
            (fx + sx * 0.62, fy + s_dy, fz - 0.02), B, bevel=0.02)

    # Vertical heavy shock cylinder connecting ankle to deck
    cylinder_between(f"{prefix}_ankle_shock_cyl",
                     (fx, fy, fz + 0.24),
                     (fx, fy, fz + 0.44),
                     0.15, C, vertices=8)
    cylinder_between(f"{prefix}_ankle_shock_rod",
                     (fx, fy, fz + 0.40),
                     Vector(ankle) + Vector((0.0, 0.0, -0.06)),
                     0.09, S, vertices=8)
    torus(f"{prefix}_foot_ring", 0.17, 0.035, (fx, fy, fz + 0.26), B)


def build_hull(mats):
    """Build the central chassis/hull: heavy octagonal armored tub, rear boiler, twin stacks, Aether conduit."""
    H = mats["dark_iron"]
    S = mats["steel"]
    B = mats["brass"]
    C = mats["copper"]
    G_AETHER = mats["aether_glow"]
    G_FURNACE = mats["furnace_glow"]

    # 1. Main armored chassis (central lower tub & armored belly)
    # Lower core block (cast iron tub)
    box(f"{ASSET}_hull_lower_tub", (2.85, 3.30, 1.15), (0.0, 0.05, 2.30), H, bevel=0.06)
    # Heavy belly armor plate (skid plate)
    box(f"{ASSET}_hull_belly_skid", (2.40, 2.80, 0.18), (0.0, 0.05, 1.65), S, bevel=0.03)
    # Upper armored superstructure (wider, sloped)
    box(f"{ASSET}_hull_upper_deck", (3.25, 3.45, 0.72), (0.0, 0.05, 3.02), H, bevel=0.05)

    # 2. Front Glacis Plate & Sloped Nose
    # Forward sloped frontal armor wedge
    box(f"{ASSET}_hull_glacis", (2.45, 0.95, 0.68), (0.0, -1.68, 2.62), S,
        rot=(math.radians(28.0), 0.0, 0.0), bevel=0.04)
    # Heavy chin plate below glacis
    box(f"{ASSET}_hull_chin", (2.05, 0.62, 0.52), (0.0, -1.58, 2.12), H, bevel=0.04)
    # Towing shackles / cleats on lower front
    for sx in (-0.80, 0.80):
        torus(f"{ASSET}_towing_shackle_{int(sx * 100)}", 0.14, 0.035,
              (sx, -1.92, 1.95), B, rot=(math.radians(90.0), 0.0, 0.0))
        cylinder(f"{ASSET}_towing_bracket_{int(sx * 100)}", 0.08, 0.12,
                 (sx, -1.86, 1.95), S, vertices=8, rot=(math.radians(90.0), 0.0, 0.0))

    # 3. Aether Sensor Array (Horizontal visor slit on glacis)
    box(f"{ASSET}_sensor_visor_housing", (1.55, 0.24, 0.24), (0.0, -1.98, 2.78), B, bevel=0.02)
    box(f"{ASSET}_sensor_visor_slit", (1.35, 0.08, 0.11), (0.0, -2.08, 2.78), G_AETHER, bevel=0.0)

    # Auxiliary lateral sensor lenses (cyan optics with brass bezels)
    for sx in (-0.98, 0.98):
        side_tag = "l" if sx < 0 else "r"
        cylinder(f"{ASSET}_sensor_lens_{side_tag}", 0.095, 0.12, (sx, -1.88, 2.68), G_AETHER, vertices=8,
                 rot=(math.radians(90.0), 0.0, 0.0))
        cylinder(f"{ASSET}_sensor_bezel_{side_tag}", 0.135, 0.06, (sx, -1.91, 2.68), B, vertices=10,
                 rot=(math.radians(90.0), 0.0, 0.0))

    # 4. Side armor sponsons protecting the hip pivots & Faction Plates
    for sx in (-1.0, 1.0):
        side_tag = "l" if sx < 0 else "r"
        # Front hip sponson
        box(f"{ASSET}_sponson_f_{side_tag}", (0.52, 0.92, 0.72),
            (sx * 1.58, -1.15, 2.72), S, bevel=0.04)
        # Rear hip sponson
        box(f"{ASSET}_sponson_r_{side_tag}", (0.52, 0.92, 0.72),
            (sx * 1.58,  1.25, 2.72), S, bevel=0.04)
        # Structural bridge between sponsons
        box(f"{ASSET}_sponson_bridge_{side_tag}", (0.36, 1.45, 0.42),
            (sx * 1.55,  0.05, 2.82), H, bevel=0.03)

        # Faction plate (steel panel for team color display, e.g. blue/red in showcase)
        box(f"{ASSET}_faction_plate_{side_tag}", (0.06, 0.85, 0.35),
            (sx * 1.76, 0.05, 2.85), S, bevel=0.01)

        # Access maintenance ladder / catwalk rungs
        for r_i, r_z in enumerate((2.15, 2.35, 2.55)):
            cylinder(f"{ASSET}_ladder_rung_{side_tag}_{r_i}", 0.025, 0.40,
                     (sx * 1.65, 0.05, r_z), B, vertices=6,
                     rot=(0.0, 0.0, 0.0))

    # 5. Rear Boiler & Steam Generation Plant
    # Horizontal cylindrical copper boiler tank across the rear
    cylinder(f"{ASSET}_rear_boiler", 0.60, 2.25, (0.0, 1.38, 2.72), C, vertices=14,
             rot=(0.0, math.radians(90.0), 0.0), bevel=0.03)
    # Brass reinforcing containment bands on boiler
    for b_x in (-0.78, 0.0, 0.78):
        torus(f"{ASSET}_boiler_band_{int((b_x + 2) * 100)}", 0.62, 0.075,
              (b_x, 1.38, 2.72), B, rot=(0.0, math.radians(90.0), 0.0),
              major_seg=14, minor_seg=6)

    # Boiler pressure gauge on rear right
    cylinder(f"{ASSET}_boiler_gauge_base", 0.12, 0.08, (0.95, 1.82, 2.95), B, vertices=10,
             rot=(math.radians(90.0), 0.0, 0.0))
    cylinder(f"{ASSET}_boiler_gauge_face", 0.09, 0.04, (0.95, 1.86, 2.95), S, vertices=10,
             rot=(math.radians(90.0), 0.0, 0.0))

    # Rear boiler protective armored cradle
    box(f"{ASSET}_boiler_cradle", (2.50, 0.78, 0.42), (0.0, 1.42, 2.18), H, bevel=0.03)

    # 6. Twin Angled Heavy Exhaust Stacks
    # Angled rearward 16 degrees, Gearforge signature twin stacks
    stack_rot = (math.radians(-16.0), 0.0, 0.0)
    for sx in (-0.70, 0.70):
        side_tag = "l" if sx < 0 else "r"
        # Stack base socket
        cylinder(f"{ASSET}_stack_base_{side_tag}", 0.34, 0.36,
                 (sx, 1.48, 3.42), H, vertices=12, bevel=0.02)
        # Main stack pipe
        cylinder(f"{ASSET}_stack_tube_{side_tag}", 0.25, 1.85,
                 (sx, 1.68, 4.28), H, vertices=12, rot=stack_rot)
        # Brass lip and collar
        torus(f"{ASSET}_stack_collar_{side_tag}", 0.28, 0.05,
              (sx, 1.60, 3.88), B, rot=stack_rot)
        cylinder(f"{ASSET}_stack_lip_{side_tag}", 0.31, 0.18,
                 (sx, 1.86, 5.06), B, vertices=12, rot=stack_rot)
        # Furnace interior glow inside stack opening
        cylinder(f"{ASSET}_stack_furnace_{side_tag}", 0.21, 0.10,
                 (sx, 1.88, 5.10), G_FURNACE, vertices=10, rot=stack_rot)

    # 7. Rear Aether Regulator & High-Pressure Conduit
    # Centered glowing Aether regulator core at rear chassis
    box(f"{ASSET}_aether_regulator_housing", (0.80, 0.42, 0.68), (0.0, 1.74, 2.48), H, bevel=0.03)
    cylinder(f"{ASSET}_aether_core_cell", 0.26, 0.34, (0.0, 1.88, 2.48), G_AETHER, vertices=12,
             rot=(math.radians(90.0), 0.0, 0.0))
    torus(f"{ASSET}_aether_core_ring", 0.28, 0.055, (0.0, 1.90, 2.48), B,
          rot=(math.radians(90.0), 0.0, 0.0))

    # Copper high-pressure steam pipes routing from boiler into hull chassis
    for sx in (-1.0, 1.0):
        side_tag = "l" if sx < 0 else "r"
        p_start = (sx * 0.88, 1.25, 3.18)
        p_mid = (sx * 1.28, 0.85, 3.12)
        p_end = (sx * 1.30, 0.35, 3.05)
        cylinder_between(f"{ASSET}_copper_pipe_a_{side_tag}", p_start, p_mid, 0.065, C, vertices=8)
        cylinder_between(f"{ASSET}_copper_pipe_b_{side_tag}", p_mid, p_end, 0.065, C, vertices=8)
        torus(f"{ASSET}_pipe_joint_{side_tag}", 0.075, 0.02, p_mid, B)

    # 8. Chassis Top Traverse Ring (heavy brass mount for Turret)
    cylinder(f"{ASSET}_turret_traverse_ring", 1.48, 0.20, (0.0, -0.10, 3.44), B, vertices=18, bevel=0.02)
    cylinder(f"{ASSET}_turret_traverse_core", 1.38, 0.24, (0.0, -0.10, 3.45), H, vertices=18)
    # Gear teeth ring around traverse base (steampunk detail)
    torus(f"{ASSET}_traverse_gear_rim", 1.50, 0.04, (0.0, -0.10, 3.42), S)


def build_turret(mats):
    """Build the armored rotating turret housing twin heavy recoil cannons with high visual density."""
    H = mats["dark_iron"]
    S = mats["steel"]
    B = mats["brass"]
    C = mats["copper"]
    G_AETHER = mats["aether_glow"]

    # 1. Turret Body (Low profile, sloped heavy armored block)
    # Turret base plate
    box(f"{ASSET}_turret_base", (2.35, 2.55, 0.42), (0.0, -0.15, 3.62), H, bevel=0.04)
    # Main turret armor block (beveled, chamfered front)
    box(f"{ASSET}_turret_cab", (2.15, 2.25, 0.82), (0.0, -0.10, 4.12), H, bevel=0.06)
    # Sloped front mantlet plate (heavy steel glacis)
    box(f"{ASSET}_turret_glacis", (1.95, 0.68, 0.72), (0.0, -1.18, 4.02), S,
        rot=(math.radians(24.0), 0.0, 0.0), bevel=0.04)

    # 2. Turret Roof Detailing (Commander Cupola & Vent & Periscope)
    # Offset brass commander cupola
    cylinder(f"{ASSET}_turret_cupola", 0.42, 0.20, (0.58, 0.35, 4.58), B, vertices=14, bevel=0.02)
    cylinder(f"{ASSET}_turret_hatch", 0.34, 0.06, (0.58, 0.35, 4.69), H, vertices=12)
    # Cupola vision slits
    for a_deg in (0, 72, 144, 216, 288):
        rad = math.radians(a_deg)
        sx = 0.58 + math.cos(rad) * 0.40
        sy = 0.35 + math.sin(rad) * 0.40
        cylinder(f"{ASSET}_cupola_slit_{a_deg}", 0.035, 0.08, (sx, sy, 4.58), G_AETHER, vertices=6)

    # Left side ventilation cowl / armored air intake
    box(f"{ASSET}_turret_vent_cowl", (0.52, 0.62, 0.22), (-0.58, 0.45, 4.58), S, bevel=0.02)
    for v_x in (-0.72, -0.58, -0.44):
        box(f"{ASSET}_vent_louver_{int((v_x + 1) * 100)}", (0.04, 0.50, 0.06),
            (v_x, 0.45, 4.68), H, bevel=0.0)

    # 3. Turret Rear Counterweight & Ammunition Casing (Bustle)
    box(f"{ASSET}_turret_bustle", (1.85, 0.95, 0.78), (0.0, 1.28, 4.02), H, bevel=0.04)
    # Heavy ammo access doors with brass latches
    for bx in (-0.46, 0.46):
        box(f"{ASSET}_ammo_door_{int(bx * 100)}", (0.36, 0.12, 0.48),
            (bx, 1.76, 4.02), S, bevel=0.02)
        cylinder(f"{ASSET}_ammo_latch_{int(bx * 100)}", 0.055, 0.18,
                 (bx, 1.78, 4.22), B, vertices=8, rot=(0.0, math.radians(90.0), 0.0))
    # Bustle lifting eye-lugs on top
    for lx in (-0.75, 0.75):
        torus(f"{ASSET}_lifting_lug_{int((lx + 1) * 100)}", 0.10, 0.03,
              (lx, 1.25, 4.50), B, rot=(0.0, math.radians(90.0), 0.0))

    # 4. Twin Heavy Recoil Cannons (Side by side)
    CANNON_SPACING = 0.60
    GUN_Y_MOUNT = -1.15
    GUN_LENGTH = 3.65
    MUZZLE_Y = GUN_Y_MOUNT - GUN_LENGTH

    # Armored mantlet surround
    box(f"{ASSET}_gun_mantlet", (1.85, 0.52, 0.68), (0.0, -1.28, CANNON_Z), S, bevel=0.03)

    for side, sx in (("l", -1.0), ("r", 1.0)):
        gx = sx * CANNON_SPACING
        gun_tag = f"{ASSET}_gun_{side}"

        # Trunnion pivot socket
        cylinder(f"{gun_tag}_trunnion", 0.25, 0.30, (gx, GUN_Y_MOUNT, CANNON_Z), B,
                 vertices=12, rot=(0.0, math.radians(90.0), 0.0), bevel=0.02)

        # Recoil housing box (heavy square breech sleeve)
        box(f"{gun_tag}_breech_sleeve", (0.44, 1.15, 0.44),
            (gx, GUN_Y_MOUNT - 0.48, CANNON_Z), H, bevel=0.03)

        # Dual copper recoil cylinders (mounted above and below the sleeve)
        cylinder(f"{gun_tag}_recoil_cyl_top", 0.075, 0.95,
                 (gx, GUN_Y_MOUNT - 0.48, CANNON_Z + 0.27), C,
                 vertices=8, rot=(math.radians(90.0), 0.0, 0.0))
        cylinder(f"{gun_tag}_recoil_cyl_bot", 0.075, 0.95,
                 (gx, GUN_Y_MOUNT - 0.48, CANNON_Z - 0.27), C,
                 vertices=8, rot=(math.radians(90.0), 0.0, 0.0))
        torus(f"{gun_tag}_recoil_ring_top", 0.085, 0.02,
              (gx, GUN_Y_MOUNT - 0.85, CANNON_Z + 0.27), B, rot=(math.radians(90.0), 0.0, 0.0))
        torus(f"{gun_tag}_recoil_ring_bot", 0.085, 0.02,
              (gx, GUN_Y_MOUNT - 0.85, CANNON_Z - 0.27), B, rot=(math.radians(90.0), 0.0, 0.0))

        # Stepped Gun Barrel
        # Heavy breech collar
        cylinder(f"{gun_tag}_barrel_base", 0.20, 0.95,
                 (gx, GUN_Y_MOUNT - 1.45, CANNON_Z), S,
                 vertices=12, rot=(math.radians(90.0), 0.0, 0.0))
        # Long barrel sleeve (Dark iron main tube)
        cylinder(f"{gun_tag}_barrel_mid", 0.16, 1.85,
                 (gx, GUN_Y_MOUNT - 2.55, CANNON_Z), H,
                 vertices=12, rot=(math.radians(90.0), 0.0, 0.0))
        # Brass reinforcement ring at mid-barrel
        torus(f"{gun_tag}_barrel_mid_ring", 0.18, 0.035,
              (gx, GUN_Y_MOUNT - 2.30, CANNON_Z), B, rot=(math.radians(90.0), 0.0, 0.0))
        # Front barrel section
        cylinder(f"{gun_tag}_barrel_tip", 0.135, 0.85,
                 (gx, GUN_Y_MOUNT - 3.45, CANNON_Z), S,
                 vertices=12, rot=(math.radians(90.0), 0.0, 0.0))

        # Brass Muzzle Brake with dual recoil vent slots
        cylinder(f"{gun_tag}_muzzle_brake", 0.21, 0.48,
                 (gx, MUZZLE_Y + 0.15, CANNON_Z), B,
                 vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.02)
        # Inner dark iron bore
        cylinder(f"{gun_tag}_muzzle_bore", 0.105, 0.52,
                 (gx, MUZZLE_Y + 0.15, CANNON_Z), H,
                 vertices=10, rot=(math.radians(90.0), 0.0, 0.0))
        # Side recoil vent slot accents
        for v_z in (-0.08, 0.08):
            box(f"{gun_tag}_brake_vent_{int((v_z + 1) * 100)}", (0.34, 0.16, 0.05),
                (gx, MUZZLE_Y + 0.15, CANNON_Z + v_z), H, bevel=0.0)

    # Cross-brace connecting the twin barrels near the muzzle (RTS visual reinforcement)
    box(f"{ASSET}_cannon_cross_brace", (CANNON_SPACING + 0.10, 0.22, 0.18),
        (0.0, GUN_Y_MOUNT - 3.20, CANNON_Z), S, bevel=0.02)
    cylinder(f"{ASSET}_brace_center_bolt", 0.06, 0.24,
             (0.0, GUN_Y_MOUNT - 3.20, CANNON_Z), B, vertices=8)

    # 5. Turret Auxiliary Systems
    # Right-side Aether targeting optic pod (Twin optical lenses)
    box(f"{ASSET}_turret_targeting_box", (0.38, 0.48, 0.36), (1.20, -0.65, 4.35), H, bevel=0.02)
    # Upper optic (Cyan Aether lens)
    cylinder(f"{ASSET}_targeting_lens_upper", 0.11, 0.10, (1.20, -0.90, 4.42), G_AETHER,
             vertices=10, rot=(math.radians(90.0), 0.0, 0.0))
    torus(f"{ASSET}_targeting_bezel_upper", 0.13, 0.025, (1.20, -0.89, 4.42), B,
          rot=(math.radians(90.0), 0.0, 0.0))
    # Lower optic (Secondary rangefinder)
    cylinder(f"{ASSET}_targeting_lens_lower", 0.08, 0.10, (1.20, -0.90, 4.26), G_AETHER,
             vertices=8, rot=(math.radians(90.0), 0.0, 0.0))
    torus(f"{ASSET}_targeting_bezel_lower", 0.10, 0.02, (1.20, -0.89, 4.26), B,
          rot=(math.radians(90.0), 0.0, 0.0))

    # Left-side boxed smoke / flare launcher cluster (4-tube rack)
    box(f"{ASSET}_smoke_rack", (0.24, 0.50, 0.38), (-1.20, -0.45, 4.30), S,
        rot=(0.0, math.radians(18.0), 0.0), bevel=0.02)
    for t_i, t_dy in enumerate((-0.14, 0.14)):
        for t_j, t_dz in enumerate((-0.09, 0.09)):
            cylinder(f"{ASSET}_smoke_tube_{t_i}_{t_j}", 0.055, 0.35,
                     (-1.30, -0.45 + t_dy, 4.30 + t_dz), H, vertices=8,
                     rot=(math.radians(25.0), math.radians(-20.0), 0.0))
            torus(f"{ASSET}_smoke_ring_{t_i}_{t_j}", 0.065, 0.015,
                  (-1.36, -0.45 + t_dy - 0.06, 4.30 + t_dz + 0.10), B,
                  rot=(math.radians(25.0), math.radians(-20.0), 0.0))


# ------------------------------------------------------------ Group Hierarchy & Pivot Setup

def group_of(name):
    """Determine which functional group an object belongs to."""
    for leg_id in ("leg_fl", "leg_fr", "leg_rl", "leg_rr"):
        if leg_id in name:
            return leg_id
    if "turret" in name or "gun" in name or "smoke" in name or "ammo" in name or "cannon" in name or "targeting" in name or "cupola" in name:
        return "turret"
    return "hull"


def join_and_pivot_groups():
    """Join parts into 6 clean functional groups with realistic pivot empties."""
    pivots = {
        "leg_fl": HIP_OFFSETS["fl"],
        "leg_fr": HIP_OFFSETS["fr"],
        "leg_rl": HIP_OFFSETS["rl"],
        "leg_rr": HIP_OFFSETS["rr"],
        "turret": (0.0, -0.10, HULL_TOP_Z + 0.10),
        "hull": (0.0, 0.0, 0.0),  # Ground centre origin
    }

    members = {g: [] for g in GROUPS}
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            members[group_of(obj.name)].append(obj)

    result = {}
    for group in GROUPS:
        objects = members[group]
        if not objects:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        joined = bpy.context.active_object
        joined.name = f"{ASSET}_{group}_lod0"
        joined.data.name = f"{ASSET}_{group}_lod0_mesh"
        joined.select_set(False)

        bpy.context.view_layer.update()
        pivot = anchor(f"{group}_pivot", pivots[group])
        bpy.context.view_layer.update()
        joined.parent = pivot
        joined.matrix_parent_inverse = pivot.matrix_world.inverted()
        bpy.context.view_layer.update()
        result[group] = joined
    return result


def build_runtime_anchors():
    """Create runtime attachment empties for Godot/gameplay integration."""
    GUN_Y_MOUNT = -1.15
    GUN_LENGTH = 3.65
    MUZZLE_Y = GUN_Y_MOUNT - GUN_LENGTH
    CANNON_SPACING = 0.60

    anchor("muzzle_l", (-CANNON_SPACING, MUZZLE_Y, CANNON_Z))
    anchor("muzzle_r", ( CANNON_SPACING, MUZZLE_Y, CANNON_Z))
    anchor("center_anchor", (0.0, 0.0, HULL_Z))
    anchor("turret_mount", (0.0, -0.10, HULL_TOP_Z))
    anchor("exhaust_l", (-0.70, 1.88, 5.10))
    anchor("exhaust_r", ( 0.70, 1.88, 5.10))
    anchor("sensor_anchor", (0.0, -2.08, 2.78))
    for leg_id, foot in FOOT_OFFSETS.items():
        anchor(f"foot_{leg_id}", foot)


def report_stats():
    """Print polygon, vertex, triangle and bounding box metrics."""
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    verts = sum(len(obj.data.vertices) for obj in meshes)
    polygons = sum(len(obj.data.polygons) for obj in meshes)
    triangles = 0
    surfaces = 0
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        surfaces += max(1, len([s for s in obj.material_slots if s.material]))
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            for axis in range(3):
                lo[axis] = min(lo[axis], world[axis])
                hi[axis] = max(hi[axis], world[axis])

    materials = {s.material.name for obj in meshes for s in obj.material_slots if s.material}
    print(f"QUAD_WALKER_STATS meshes={len(meshes)} surfaces={surfaces} verts={verts} "
          f"polygons={polygons} triangles={triangles} materials={len(materials)}")
    print(f"QUAD_WALKER_BOUNDS width={hi.x - lo.x:.3f} depth={hi.y - lo.y:.3f} height={hi.z - lo.z:.3f} "
          f"x=[{lo.x:.2f},{hi.x:.2f}] y=[{lo.y:.2f},{hi.y:.2f}] z=[{lo.z:.2f},{hi.z:.2f}]")
    return len(meshes), verts, polygons, triangles, len(materials), surfaces


def main():
    clear_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["asset_name"] = ASSET
    scene["production_name"] = PRODUCTION_NAME
    scene["unit_class"] = UNIT_CLASS
    scene["forward_axis"] = "-Y"
    scene["up_axis"] = "+Z"
    scene["origin_mode"] = "ground_centre"
    scene["texture_count"] = 0

    full = palette("gearforge")
    mats = {
        "dark_iron": full["dark_iron"],
        "steel": full["steel"],
        "brass": full["brass"],
        "copper": full["copper"],
        "aether_glow": full["aether_glow"],
        "furnace_glow": full["furnace_glow"],
    }

    # Build 4 quadruped legs
    for leg_id in ("leg_fl", "leg_fr", "leg_rl", "leg_rr"):
        build_quad_leg(leg_id, mats)

    # Build hull and turret
    build_hull(mats)
    build_turret(mats)

    # Group into functional assemblies and create empties
    join_and_pivot_groups()
    build_runtime_anchors()

    stats = report_stats()
    for key, val in zip(("mesh_count", "vertex_count", "polygon_count",
                         "triangle_count", "material_count", "surface_count"), stats):
        scene[key] = val

    # Save .blend file
    os.makedirs(os.path.dirname(SOURCE_BLEND), exist_ok=True)
    os.makedirs(os.path.dirname(EXPORT_GLB), exist_ok=True)
    os.makedirs(os.path.dirname(INTERMEDIATE_GLB), exist_ok=True)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE_BLEND)
    print("SAVE_BLEND_OK", SOURCE_BLEND)

    # Export intermediate GLB (blender/exports)
    bpy.ops.export_scene.gltf(
        filepath=INTERMEDIATE_GLB,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_materials="EXPORT",
        export_animations=False,
    )
    print("EXPORT_INTERMEDIATE_GLB_OK", INTERMEDIATE_GLB, os.path.getsize(INTERMEDIATE_GLB), "bytes")

    # Export production GLB (game/assets/models)
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
    print("EXPORT_PRODUCTION_GLB_OK", EXPORT_GLB, os.path.getsize(EXPORT_GLB), "bytes")


if __name__ == "__main__":
    main()

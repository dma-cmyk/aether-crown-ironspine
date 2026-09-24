"""Build the Gearforge Ironstride production Walker.

Outputs:
  blender/source/gearforge_walker.blend
  blender/exports/gearforge_walker.glb

Design intent (docs/phase25d.md, Phase 2.5D):
a 4.5 m line walker - the mass-produced middle of the scale hierarchy between
1.8 m infantry and the 11.4 m Crownpiercer Titan. It is deliberately NOT a
small Titan: no sensor head, no asymmetric arm cannon, no tall torso. The
Ironstride is a squat A-frame gun carriage - wide splayed ram feet, legs that
lean outward on their way down, a low armoured hull wider than it is tall, and
one centred recoil cannon on a shallow top mount.

Geometry is authored from modular low-poly parts and joined into four
functional groups (leg_l, leg_r, turret, hull), each parented to a pivot empty
at its real rotation axis, so a later walk / recoil / traverse rig has
something to key. No textures, no transparency.

Coordinates use Blender X right / Y depth / Z up, with front at -Y. glTF
exports Y-up, so Blender -Y becomes Godot +Z. The origin is the ground contact
centre, matching every other Gearforge ground asset.

Run:
  blender --background --python blender/scripts/make_gearforge_walker.py
"""

import math
import os
import sys

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from building_kit import kit  # noqa: E402
from material_lib import palette  # noqa: E402

ASSET = "gearforge_walker"
ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
SOURCE_BLEND = os.path.join(ROOT, "blender", "source", ASSET + ".blend")
EXPORT_GLB = os.path.join(ROOT, "blender", "exports", ASSET + ".glb")

T = kit.T

# ------------------------------------------------------------ key stations
# Digitigrade stations, per side. The knee kicks rearward and the ankle rakes
# forward, so the side profile is an unmistakable Z rather than a straight post.
FOOT_X, FOOT_Y = 1.24, -0.26
ANKLE = (1.24, -0.22, 0.60)
KNEE = (0.90, 0.72, 1.48)
HIP = (0.70, 0.26, 2.42)
HULL_Z = 3.02          # armoured hull centre
ROOF_Z = 3.46
GUN_Z = 3.80           # cannon axis
GROUPS = ("leg_l", "leg_r", "turret", "hull")


def mirror(station, sx, dx=0.0, dy=0.0, dz=0.0):
    return (sx * (station[0] + dx), station[1] + dy, station[2] + dz)


def box_between(name, start, end, width, depth, mat, bevel=0.04, extend=0.0):
    """Armour box whose long axis runs from start to end (leg segments)."""
    a, b = Vector(start), Vector(end)
    direction = b - a
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(a + b) * 0.5)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (width, depth, direction.length + extend)
    T.apply_transform(obj)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    T.apply_transform(obj)
    T.add_bevel(obj, bevel)
    obj.data.materials.append(mat)
    return obj


def along(start, end, t, lateral=0.0, sx=1.0):
    """Point a fraction t along a leg segment, pushed sideways in X."""
    a, b = Vector(start), Vector(end)
    point = a.lerp(b, t)
    return (point.x + sx * lateral, point.y, point.z)


# ------------------------------------------------------------------- legs
def build_leg(sx, mats):
    tag = "legl" if sx < 0 else "legr"
    H, S, B, C = mats["dark_iron"], mats["steel"], mats["brass"], mats["copper"]
    fx, fy = sx * FOOT_X, FOOT_Y
    ankle = mirror(ANKLE, sx)
    knee = mirror(KNEE, sx)
    hip = mirror(HIP, sx)

    # Ground contact is a broad ram pad, not a foot: widest point of the machine.
    T.box(f"{ASSET}_{tag}_pad", (1.00, 1.64, 0.22), (fx, fy, 0.11), H, bevel=0.03)
    T.box(f"{ASSET}_{tag}_deck", (0.92, 1.26, 0.18), (fx, fy - 0.04, 0.30), S, bevel=0.03)
    T.trapezoid(f"{ASSET}_{tag}_toe", (0.90, 0.50), (0.66, 0.36), 0.32,
                (fx, fy - 0.84, 0.26), S, bevel=0.025)
    T.box(f"{ASSET}_{tag}_claw", (0.70, 0.32, 0.16), (fx, fy - 1.06, 0.09), B, bevel=0.0)
    T.box(f"{ASSET}_{tag}_heel", (0.78, 0.40, 0.42), (fx, fy + 0.76, 0.32), H, bevel=0.03)
    T.box(f"{ASSET}_{tag}_spur", (0.46, 0.26, 0.22), (fx, fy + 0.98, 0.13), B, bevel=0.0)
    for gy in (-0.50, 0.16):
        T.box(f"{ASSET}_{tag}_cleat_{int((gy + 1) * 100)}", (1.06, 0.16, 0.14),
              (fx, fy + gy, 0.10), B, bevel=0.0)

    # Ankle joint: a real axle plus a raked forward strut the foot pivots on.
    for bx in (-0.34, 0.34):
        for by in (-0.46, 0.34):
            T.cylinder(f"{ASSET}_{tag}_bolt_{int((bx + 1) * 100)}_{int((by + 1) * 100)}",
                       0.055, 0.08, (fx + bx, fy + by, 0.40), B, vertices=6, bevel=0.0)
    T.box(f"{ASSET}_{tag}_ankle_block", (0.52, 0.64, 0.46), (fx, fy + 0.06, 0.52), H, bevel=0.03)
    T.cylinder(f"{ASSET}_{tag}_ankle_axle", 0.23, 0.90, ankle, B,
               vertices=10, rot=(0.0, math.radians(90.0), 0.0), bevel=0.0)

    # Shin rakes forward from the rear knee. This is the walking-machine read.
    box_between(f"{ASSET}_{tag}_shin", knee, ankle, 0.56, 0.62, H, bevel=0.04, extend=0.18)
    box_between(f"{ASSET}_{tag}_shin_plate",
                along(knee, ankle, 0.18, -0.03, sx), along(knee, ankle, 0.92, -0.03, sx),
                0.64, 0.20, S, bevel=0.025)
    T.box(f"{ASSET}_{tag}_shin_rib", (0.70, 0.18, 0.18), along(knee, ankle, 0.34), B, bevel=0.0)

    # Exposed hydraulics: one long fore ram, one short aft ram per segment.
    T.cylinder_between(f"{ASSET}_{tag}_shin_ram",
                       along(knee, ankle, 0.08, -0.34, sx), along(knee, ankle, 0.94, -0.30, sx),
                       0.08, C, vertices=8, bevel=0.0)
    T.cylinder_between(f"{ASSET}_{tag}_ankle_ram",
                       (fx + sx * 0.30, fy + 0.62, 0.44), along(knee, ankle, 0.30, 0.30, sx),
                       0.065, C, vertices=8, bevel=0.0)

    # Knee: the biggest brass note on the leg, and the pivot of the Z profile.
    T.cylinder(f"{ASSET}_{tag}_knee", 0.33, 0.78, knee, B,
               vertices=12, rot=(0.0, math.radians(90.0), 0.0), bevel=0.0)
    T.cylinder(f"{ASSET}_{tag}_knee_cap", 0.21, 0.92, knee, H,
               vertices=10, rot=(0.0, math.radians(90.0), 0.0), bevel=0.0)
    T.box(f"{ASSET}_{tag}_knee_guard", (0.56, 0.30, 0.54), mirror(KNEE, sx, 0.0, -0.34, 0.04),
          S, bevel=0.03)

    # Thigh leans back and inboard up to the hip yoke.
    box_between(f"{ASSET}_{tag}_thigh", hip, knee, 0.62, 0.74, H, bevel=0.04, extend=0.16)
    box_between(f"{ASSET}_{tag}_thigh_plate",
                along(hip, knee, 0.14, -0.03, sx), along(hip, knee, 0.90, -0.03, sx),
                0.70, 0.22, S, bevel=0.025)
    T.cylinder_between(f"{ASSET}_{tag}_thigh_ram",
                       along(hip, knee, 0.10, 0.30, sx), along(hip, knee, 0.92, 0.26, sx),
                       0.075, C, vertices=8, bevel=0.0)
    T.box(f"{ASSET}_{tag}_hip_housing", (0.66, 0.80, 0.52), mirror(HIP, sx, 0.0, 0.02, -0.04),
          H, bevel=0.04)
    T.cylinder(f"{ASSET}_{tag}_hip_axle", 0.28, 0.76, hip, B,
               vertices=12, rot=(0.0, math.radians(90.0), 0.0), bevel=0.0)


# ------------------------------------------------------------------- hull
def build_hull(mats):
    H, S, B, C, A = (mats["dark_iron"], mats["steel"], mats["brass"],
                     mats["copper"], mats["aether_glow"])

    # Hip yoke spans the two hip axles; the traverse collar sits on top of it.
    T.box(f"{ASSET}_hull_yoke", (2.24, 1.02, 0.50), (0.0, 0.20, HIP[2] + 0.10), S, bevel=0.04)
    T.cylinder(f"{ASSET}_hull_collar", 0.66, 0.30, (0.0, 0.10, HIP[2] + 0.40), B,
               vertices=14, bevel=0.0)

    # Armoured hull: deeper than it is tall, and wider than it is deep. The
    # opposite of the Titan torso, which is a tall block on a narrow waist.
    T.trapezoid(f"{ASSET}_hull_body", (2.10, 2.16), (1.86, 1.88), 0.88,
                (0.0, 0.06, HULL_Z), H, bevel=0.06)
    T.box(f"{ASSET}_hull_belt", (2.16, 2.20, 0.18), (0.0, 0.06, HULL_Z - 0.40), B, bevel=0.0)
    T.box(f"{ASSET}_hull_roof", (1.90, 1.94, 0.16), (0.0, 0.06, ROOF_Z), S, bevel=0.03)

    # Sloped glacis with one horizontal Aether sensor slit. Deliberately no head.
    T.trapezoid(f"{ASSET}_hull_glacis", (1.78, 0.30), (1.50, 0.22), 0.84,
                (0.0, -1.02, HULL_Z + 0.02), H, bevel=0.03)
    T.box(f"{ASSET}_hull_brow", (1.58, 0.26, 0.18), (0.0, -1.06, HULL_Z + 0.42), B, bevel=0.0)
    T.box(f"{ASSET}_hull_sensor", (1.16, 0.12, 0.13), (0.0, -1.12, HULL_Z + 0.20), A, bevel=0.0)
    T.box(f"{ASSET}_hull_glacis_rib", (0.26, 0.20, 0.72), (0.0, -1.08, HULL_Z - 0.06), S, bevel=0.02)
    # Chest regulator: the only Aether element on the front besides the slit.
    T.cylinder(f"{ASSET}_hull_regulator_ring", 0.25, 0.20, (0.0, -1.02, HULL_Z - 0.30), B,
               vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    T.cylinder(f"{ASSET}_hull_regulator", 0.15, 0.14, (0.0, -1.10, HULL_Z - 0.30), A,
               vertices=10, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)

    for sx in (-1.0, 1.0):
        side = "l" if sx < 0 else "r"
        # Shoulder blocks give a horizontal read from the front and carry the
        # faction plate the Godot pass will recolour.
        T.box(f"{ASSET}_hull_shoulder_{side}", (0.40, 1.60, 0.86), (sx * 1.06, 0.02, HULL_Z + 0.16),
              H, rot=(0.0, math.radians(sx * 12.0), 0.0), bevel=0.04)
        T.box(f"{ASSET}_hull_shoulder_cap_{side}", (0.48, 1.64, 0.14), (sx * 1.08, 0.02, HULL_Z + 0.64),
              B, bevel=0.0)
        for sz in (-0.24, 0.20):
            T.box(f"{ASSET}_hull_strake_{side}_{int((sz + 1) * 100)}", (0.10, 1.44, 0.09),
                  (sx * 1.26, 0.06, HULL_Z + sz), B, bevel=0.0)
        # Flat neutral panel reserved for Blue/Red marking (see docs/phase25d.md).
        T.box(f"{ASSET}_hull_faction_plate_{side}", (0.10, 0.72, 0.46),
              (sx * 1.28, -0.24, HULL_Z + 0.16), S, bevel=0.0)
        # Smoke launcher cluster: small, and the only extra weapon fitting.
        for dy in (-0.12, 0.12):
            T.cylinder(f"{ASSET}_hull_smoke_{side}_{int((dy + 1) * 100)}", 0.075, 0.26,
                       (sx * 1.02, 0.62 + dy, HULL_Z + 0.80), B, vertices=8,
                       rot=(math.radians(-24.0), 0.0, 0.0), bevel=0.0)
        T.box(f"{ASSET}_hull_step_{side}", (0.32, 0.36, 0.12), (sx * 1.04, 0.62, HIP[2] + 0.36),
              B, bevel=0.0)
        T.cylinder(f"{ASSET}_hull_tank_{side}", 0.19, 0.66, (sx * 0.86, 0.86, HULL_Z - 0.34), C,
                   vertices=10, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)

    # Rear machinery block: transverse boiler, ammunition housing, twin swept
    # exhausts and a small Aether capacitor. The rear must not be a blank plate.
    T.box(f"{ASSET}_hull_rear_plate", (1.84, 0.24, 0.92), (0.0, 1.14, HULL_Z - 0.04), S, bevel=0.03)
    for rx in (-0.62, 0.62):
        T.box(f"{ASSET}_hull_rear_rib_{int((rx + 1) * 100)}", (0.16, 0.20, 0.86),
              (rx, 1.24, HULL_Z - 0.04), H, bevel=0.0)
    T.cylinder(f"{ASSET}_hull_boiler", 0.40, 1.44, (0.0, 1.06, HULL_Z + 0.02), C,
               vertices=12, rot=(0.0, math.radians(90.0), 0.0), bevel=0.0)
    for bx in (-0.46, 0.46):
        T.torus(f"{ASSET}_hull_boiler_band_{int((bx + 1) * 100)}", 0.44, 0.06,
                (bx, 1.06, HULL_Z + 0.02), B, rot=(0.0, math.radians(90.0), 0.0),
                major=12, minor=5)
    T.box(f"{ASSET}_hull_ammo_housing", (1.34, 0.56, 0.60), (0.0, 1.06, HULL_Z + 0.56), H, bevel=0.04)
    T.box(f"{ASSET}_hull_ammo_hatch", (0.62, 0.16, 0.38), (0.0, 1.36, HULL_Z + 0.56), B, bevel=0.0)
    T.cylinder(f"{ASSET}_hull_capacitor", 0.21, 0.34, (0.0, 0.70, HULL_Z + 0.72), B,
               vertices=12, bevel=0.0)
    T.cylinder(f"{ASSET}_hull_capacitor_core", 0.13, 0.16, (0.0, 0.70, HULL_Z + 0.90), A,
               vertices=10, bevel=0.0)
    for sx in (-1.0, 1.0):
        side = "l" if sx < 0 else "r"
        T.cylinder(f"{ASSET}_hull_exhaust_{side}", 0.135, 0.94, (sx * 0.66, 1.18, HULL_Z + 0.96),
                   H, vertices=10, rot=(math.radians(-18.0), 0.0, 0.0), bevel=0.0)
        T.cylinder(f"{ASSET}_hull_exhaust_lip_{side}", 0.175, 0.13, (sx * 0.66, 1.32, HULL_Z + 1.40),
                   B, vertices=10, rot=(math.radians(-18.0), 0.0, 0.0), bevel=0.0)
        T.cylinder_between(f"{ASSET}_hull_feed_{side}", (sx * 0.46, 1.06, HULL_Z + 0.02),
                           (sx * 0.66, 1.14, HULL_Z + 0.62), 0.075, C, vertices=8, bevel=0.0)


# ----------------------------------------------------------------- turret
def build_turret(mats):
    H, S, B, C = mats["dark_iron"], mats["steel"], mats["brass"], mats["copper"]

    # Shallow top mount, not a tower: the gun sits on the hull roof.
    T.cylinder(f"{ASSET}_turret_ring", 0.66, 0.20, (0.0, -0.04, ROOF_Z + 0.10), B,
               vertices=14, bevel=0.0)
    T.trapezoid(f"{ASSET}_turret_body", (1.30, 1.28), (1.10, 1.08), 0.54,
                (0.0, -0.08, GUN_Z), H, bevel=0.05)
    T.box(f"{ASSET}_turret_trim", (1.34, 1.32, 0.10), (0.0, -0.08, GUN_Z - 0.24), B, bevel=0.0)
    T.box(f"{ASSET}_turret_hatch", (0.52, 0.56, 0.12), (0.0, 0.10, GUN_Z + 0.30), S, bevel=0.02)
    T.box(f"{ASSET}_turret_mantlet", (1.10, 0.50, 0.68), (0.0, -0.76, GUN_Z), H, bevel=0.04)
    T.box(f"{ASSET}_turret_mantlet_face", (0.86, 0.16, 0.54), (0.0, -1.00, GUN_Z), S, bevel=0.03)
    for sx in (-1.0, 1.0):
        side = "l" if sx < 0 else "r"
        T.cylinder(f"{ASSET}_turret_trunnion_{side}", 0.18, 0.28, (sx * 0.60, -0.70, GUN_Z), B,
                   vertices=10, rot=(0.0, math.radians(90.0), 0.0), bevel=0.0)
        # Recoil rails over the barrel and recoil cylinders under it: the gun
        # has to look like it absorbs its own shot.
        T.box(f"{ASSET}_turret_rail_{side}", (0.12, 1.26, 0.12), (sx * 0.44, -0.62, GUN_Z + 0.38),
              C, bevel=0.0)
        T.cylinder(f"{ASSET}_turret_recoil_{side}", 0.12, 1.06, (sx * 0.42, -0.84, GUN_Z - 0.32),
                   C, vertices=8, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
        T.box(f"{ASSET}_turret_brake_slot_{side}", (0.08, 0.20, 0.36), (sx * 0.22, -2.44, GUN_Z),
              H, bevel=0.0)
    T.box(f"{ASSET}_turret_rail_cross", (1.06, 0.15, 0.15), (0.0, -1.22, GUN_Z + 0.38), B, bevel=0.0)

    # Barrel: sleeve, tube, brass muzzle brake. Short enough to stay a medium gun.
    T.cylinder(f"{ASSET}_turret_sleeve", 0.235, 0.68, (0.0, -1.30, GUN_Z), S,
               vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    T.cylinder(f"{ASSET}_turret_barrel", 0.15, 1.12, (0.0, -1.98, GUN_Z), H,
               vertices=10, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    T.cylinder(f"{ASSET}_turret_brake", 0.245, 0.36, (0.0, -2.46, GUN_Z), B,
               vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)

    # Breech and counterweight balance the barrel and fill the rear silhouette.
    T.box(f"{ASSET}_turret_breech", (0.86, 0.56, 0.62), (0.0, 0.40, GUN_Z), H, bevel=0.04)
    T.cylinder(f"{ASSET}_turret_breech_ring", 0.28, 0.22, (0.0, 0.68, GUN_Z), B,
               vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    T.box(f"{ASSET}_turret_counterweight", (0.96, 0.28, 0.46), (0.0, 0.76, GUN_Z - 0.14), S, bevel=0.03)
    # Secondary: one compact coaxial support gun, nothing more.
    T.box(f"{ASSET}_turret_coax_box", (0.32, 0.48, 0.30), (0.64, -0.82, GUN_Z - 0.32), H, bevel=0.02)
    T.cylinder(f"{ASSET}_turret_coax", 0.07, 0.74, (0.64, -1.34, GUN_Z - 0.32), S,
               vertices=8, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)


# ------------------------------------------------------- assembly / export
def group_of(name):
    for group in GROUPS:
        token = group.replace("_", "")
        if f"_{token}_" in name:
            return group
    return "hull"


def join_groups():
    """One mesh object per functional group, each parented to its pivot empty.

    Materials stay as separate slots inside the object, so the shared palette
    is untouched while walk / recoil / traverse animation still has four
    independently transformable parts to key.
    """
    pivots = {
        "leg_l": mirror(HIP, -1.0),
        "leg_r": mirror(HIP, 1.0),
        "turret": (0.0, -0.04, ROOF_Z + 0.10),
        "hull": (0.0, 0.10, HIP[2] + 0.40),
    }
    # Classify every part first: joining renames objects, and a renamed
    # group mesh must never be re-collected by a later group.
    members = {group: [] for group in GROUPS}
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

        pivot = T.anchor(f"{group}_pivot", pivots[group])
        joined.parent = pivot
        joined.matrix_parent_inverse = pivot.matrix_world.inverted()
        result[group] = joined
    return result


def build_anchors():
    T.anchor("muzzle", (0.0, -2.68, GUN_Z))
    T.anchor("center_anchor", (0.0, 0.06, HULL_Z))
    T.anchor("reactor_anchor", (0.0, -1.10, HULL_Z - 0.30))
    T.anchor("exhaust_l", (-0.66, 1.46, HULL_Z + 1.46))
    T.anchor("exhaust_r", (0.66, 1.46, HULL_Z + 1.46))
    T.anchor("weapon_secondary", (0.64, -1.72, GUN_Z - 0.32))
    T.anchor("piston_l", (-FOOT_X, FOOT_Y - 0.40, ANKLE[2]))
    T.anchor("piston_r", (FOOT_X, FOOT_Y - 0.40, ANKLE[2]))


def report_stats():
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
    print("WALKER_STATS meshes=%d surfaces=%d verts=%d polygons=%d triangles=%d materials=%d"
          % (len(meshes), surfaces, verts, polygons, triangles, len(materials)))
    print("WALKER_BOUNDS width=%.3f depth=%.3f height=%.3f x=[%.2f,%.2f] y=[%.2f,%.2f] z=[%.2f,%.2f]"
          % (hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    return len(meshes), verts, polygons, triangles, len(materials), surfaces


def main():
    T.clear_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["asset_name"] = ASSET
    scene["production_name"] = "Ironstride"
    scene["unit_class"] = "frontline_support_walker"
    scene["forward_axis"] = "-Y"
    scene["up_axis"] = "+Z"
    scene["origin_mode"] = "ground_centre"
    scene["texture_count"] = 0

    full = palette("gearforge")
    mats = {k: full[k] for k in ("dark_iron", "steel", "brass", "copper", "aether_glow")}
    build_leg(-1.0, mats)
    build_leg(1.0, mats)
    build_hull(mats)
    build_turret(mats)
    join_groups()
    build_anchors()

    stats = report_stats()
    for key, val in zip(("mesh_count", "vertex_count", "polygon_count",
                         "triangle_count", "material_count", "surface_count"), stats):
        scene[key] = val

    bpy.ops.object.select_all(action="SELECT")
    os.makedirs(os.path.dirname(SOURCE_BLEND), exist_ok=True)
    os.makedirs(os.path.dirname(EXPORT_GLB), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE_BLEND)
    print("SAVE_BLEND_OK", SOURCE_BLEND)
    bpy.ops.export_scene.gltf(
        filepath=EXPORT_GLB, export_format="GLB", use_selection=False,
        export_apply=True, export_yup=True, export_normals=True,
        export_materials="EXPORT", export_animations=False)
    print("EXPORT_GLB_OK", EXPORT_GLB, os.path.getsize(EXPORT_GLB), "bytes")


if __name__ == "__main__":
    main()

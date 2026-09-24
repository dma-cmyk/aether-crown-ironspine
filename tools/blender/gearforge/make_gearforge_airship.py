"""Build the Gearforge Crownhammer production Airship.

Outputs:
  blender/source/gearforge_airship.blend
  blender/exports/gearforge_airship.glb

Design intent (docs/art/airship_design.md, Phase 2.5C Variant C):
a 34 m twin-cell Aether dreadnought. Two slatted lift cells cradle a central
armoured keel hull; an armoured ram prow and an H-tail bridge the two cells so
the ship always reads as one body. Aether runs from the dorsal reactor into the
cell injectors (lift), forward to the belly siege mortar (firepower) and aft to
the tail thrusters (thrust). Weapon logic is deliberately unlike the Titan:
the airship shoots down and sideways instead of carrying one long arm cannon.

Geometry is authored from modular low-poly parts, bevelled only where the RTS
light needs a face break, then joined by shared material for a low draw-call
GLB. No textures, no transparency.

Coordinates use Blender X right / Y depth / Z up, with front at -Y. glTF
exports Y-up, so Blender -Y becomes Godot +Z and matches VisualAirship facing.
The origin is the keel hull centre line: this is a flying vehicle, so the
ground-contact origin rule in docs/model_rules.md does not apply. Z = 0 is the
keel centre, the spine reaches +6.55 m and the mortar muzzle -4.52 m.

Run:
  blender --background --python blender/scripts/make_gearforge_airship.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector


ASSET = "gearforge_airship"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPT_DIR = os.path.join(ROOT, "blender", "scripts")
SOURCE_BLEND = os.path.join(ROOT, "blender", "source", ASSET + ".blend")
EXPORT_GLB = os.path.join(ROOT, "blender", "exports", ASSET + ".glb")

if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from material_lib import palette  # noqa: E402


# ---------------------------------------------------------------- key dimensions
CELL_X = 4.00          # lift cell centre offset from the ship centre line
CELL_Z = 3.30          # lift cell centre height above the keel centre
CELL_R = 2.55          # lift cell radius (slender enough to read as a ship)
CELL_Y0 = -9.60        # lift cell straight section, front end
CELL_Y1 = 10.00        # lift cell straight section, rear end
KEEL_HALF_W = 2.20     # keel hull half width at the widest station
KEEL_TOP = 1.70
KEEL_BOTTOM = -1.70
KEEL_FRONT = -12.60
KEEL_REAR = 11.60
PROW_TIP = -17.00
TAIL_TIP = 16.20
GIRDER_Z = -1.98       # continuous underside girder that ties the belly together
RING_STATIONS = (-8.10, -4.70, -1.30, 2.10, 5.50, 8.90)


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
        vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot
    )
    obj = bpy.context.active_object
    obj.name = name
    apply_transform(obj)
    add_bevel(obj, min(bevel, radius * 0.16, depth * 0.08))
    obj.data.materials.append(mat)
    return obj


def cone(name, radius_bottom, radius_top, depth, loc, mat, vertices=12, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        location=loc,
        rotation=rot,
    )
    obj = bpy.context.active_object
    obj.name = name
    apply_transform(obj)
    obj.data.materials.append(mat)
    return obj


def cylinder_between(name, start, end, radius, mat, vertices=8, bevel=0.0):
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    obj = cylinder(
        name, radius, direction.length, (start_v + end_v) * 0.5, mat,
        vertices=vertices, bevel=bevel,
    )
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    apply_transform(obj)
    return obj


def torus(name, major_radius, minor_radius, loc, mat, rot=(0.0, 0.0, 0.0), major=16, minor=6):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius, minor_radius=minor_radius,
        major_segments=major, minor_segments=minor, location=loc, rotation=rot,
    )
    obj = bpy.context.active_object
    obj.name = name
    apply_transform(obj)
    obj.data.materials.append(mat)
    return obj


def prism(name, back_xz, front_xz, y_back, y_front, loc, mat, bevel=0.07):
    """Box tapered along Y. Front face sits at -Y, matching the ship's facing."""
    bx, bz = back_xz[0] * 0.5, back_xz[1] * 0.5
    fx, fz = front_xz[0] * 0.5, front_xz[1] * 0.5
    verts = [
        (-bx, y_back, -bz), (bx, y_back, -bz), (bx, y_back, bz), (-bx, y_back, bz),
        (-fx, y_front, -fz), (fx, y_front, -fz), (fx, y_front, fz), (-fx, y_front, fz),
    ]
    faces = [
        (0, 3, 2, 1), (4, 5, 6, 7),
        (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
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
    obj.empty_display_size = 0.5
    return obj


def cell_surface(side, angle_deg, radius=None):
    """Point on a lift cell hull. angle 0 = top, positive = outboard."""
    r = CELL_R if radius is None else radius
    a = math.radians(angle_deg)
    return (side * (CELL_X + math.sin(a) * r), CELL_Z + math.cos(a) * r)


# ------------------------------------------------------------------- lift cells
def build_lift_cell(side, mats):
    tag = "l" if side < 0 else "r"
    x = side * CELL_X
    length = CELL_Y1 - CELL_Y0
    mid_y = (CELL_Y0 + CELL_Y1) * 0.5

    # Primary: the pressurised Aether cell. Slatted iron armour, not fabric.
    cylinder(f"{ASSET}_cell_{tag}", CELL_R, length, (x, mid_y, CELL_Z),
             mats["dark_iron"], vertices=20, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    cone(f"{ASSET}_cell_nose_{tag}", CELL_R, 0.62, 4.70, (x, CELL_Y0 - 2.35, CELL_Z),
         mats["dark_iron"], vertices=20, rot=(math.radians(-90.0), 0.0, 0.0))
    cone(f"{ASSET}_cell_tail_{tag}", CELL_R, 0.90, 3.60, (x, CELL_Y1 + 1.80, CELL_Z),
         mats["dark_iron"], vertices=20, rot=(math.radians(90.0), 0.0, 0.0))

    # Secondary: brass ring frames. Flat discs read as bands for a fraction of
    # the cost of a torus, and 0.17 m of proud rim survives the strategic zoom.
    for index, y in enumerate(RING_STATIONS):
        cylinder(f"{ASSET}_cell_ring_{tag}_{index}", CELL_R + 0.17, 0.26, (x, y, CELL_Z),
                 mats["brass"], vertices=20, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    cylinder(f"{ASSET}_cell_nose_ring_{tag}", CELL_R + 0.10, 0.34, (x, CELL_Y0 - 0.10, CELL_Z),
             mats["brass"], vertices=20, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    cylinder(f"{ASSET}_cell_tail_ring_{tag}", CELL_R + 0.10, 0.30, (x, CELL_Y1 + 0.08, CELL_Z),
             mats["brass"], vertices=20, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    cylinder(f"{ASSET}_cell_vent_ring_{tag}", CELL_R * 0.66, 0.26, (x, CELL_Y1 + 2.05, CELL_Z),
             mats["brass"], vertices=16, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    cylinder(f"{ASSET}_cell_tail_cap_{tag}", 0.98, 0.44, (x, CELL_Y1 + 3.70, CELL_Z),
             mats["bronze"], vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.05)
    cylinder(f"{ASSET}_cell_vent_{tag}", 0.62, 0.20, (x, CELL_Y1 + 3.94, CELL_Z),
             mats["furnace_glow"], vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    cylinder(f"{ASSET}_cell_nose_cap_{tag}", 0.72, 0.52, (x, CELL_Y0 - 4.62, CELL_Z),
             mats["bronze"], vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.05)
    # Mid-cone ring keeps the long bow taper from going blank.
    cylinder(f"{ASSET}_cell_bow_ring_{tag}", CELL_R * 0.62, 0.24, (x, CELL_Y0 - 2.20, CELL_Z),
             mats["brass"], vertices=16, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)

    # Longitudinal stringers cross the rings into a cage. Top and outboard only:
    # the inboard face is buried in the keel trench and would never be seen.
    for angle in (-34.0, 0.0, 38.0, 72.0):
        sx, sz = cell_surface(side, angle, CELL_R - 0.05)
        box(f"{ASSET}_cell_stringer_{tag}_{int(angle)}", (0.34, length + 1.9, 0.20),
            (sx, mid_y - 0.35, sz), mats["steel"],
            rot=(0.0, math.radians(side * angle), 0.0), bevel=0.04)

    # Upper armour panel: a steel back so the cell is not one flat iron value.
    top_x, top_z = cell_surface(side, 0.0, CELL_R - 0.04)
    box(f"{ASSET}_cell_deck_{tag}", (2.30, length - 1.2, 0.22), (top_x, mid_y, top_z - 0.04),
        mats["steel"], bevel=0.05)

    # Aether lift: injector slits along the cell belly. This is the only large
    # emissive run on the ship and it explains why the hull floats.
    for index, y in enumerate((-7.4, -4.0, -0.6, 2.8, 6.2, 9.2)):
        box(f"{ASSET}_cell_injector_{tag}_{index}", (0.80, 1.90, 0.22),
            (x + side * 0.55, y, CELL_Z - CELL_R + 0.16), mats["aether_glow"], bevel=0.0)
        box(f"{ASSET}_cell_injector_shroud_{tag}_{index}", (1.24, 2.16, 0.30),
            (x + side * 0.55, y, CELL_Z - CELL_R + 0.02), mats["brass"], bevel=0.05)


# -------------------------------------------------------------------- keel hull
def build_keel(mats):
    # Primary: the armoured spine that makes two cells into one ship.
    prism(f"{ASSET}_keel_hull", (2 * KEEL_HALF_W, KEEL_TOP - KEEL_BOTTOM), (3.40, 2.80),
          KEEL_REAR, KEEL_FRONT, (0.0, 0.0, 0.0), mats["dark_iron"], bevel=0.12)
    box(f"{ASSET}_keel_belt", (2 * KEEL_HALF_W + 0.22, 20.40, 0.34), (0.0, -0.70, 0.30),
        mats["brass"], bevel=0.06)
    box(f"{ASSET}_keel_shoulder", (4.90, 19.20, 0.42), (0.0, -0.70, KEEL_TOP - 0.10),
        mats["steel"], bevel=0.08)

    # Saddles: the visible reason the cells sit where they sit.
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        for index, y in enumerate((-7.4, 0.0, 7.4)):
            box(f"{ASSET}_saddle_{tag}_{index}", (2.60, 0.90, 1.30),
                (side * 2.55, y, 1.05), mats["steel"], rot=(0.0, math.radians(side * 22.0), 0.0),
                bevel=0.07)
            cylinder_between(
                f"{ASSET}_brace_{tag}_{index}",
                (side * 1.70, y, KEEL_TOP - 0.2), (side * 3.55, y, CELL_Z - CELL_R + 0.5),
                0.16, mats["brass"], vertices=8,
            )

    # Dorsal spine deck between the cells: keeps the trench from reading empty.
    box(f"{ASSET}_spine_deck", (2.60, 21.00, 0.46), (0.0, -0.40, KEEL_TOP + 0.44),
        mats["bronze"], bevel=0.07)
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        box(f"{ASSET}_spine_rail_{tag}", (0.16, 20.20, 0.44), (side * 1.24, -0.40, KEEL_TOP + 0.90),
            mats["dark_iron"], bevel=0.03)

    # Side armour ribs: armour-over-machine rhythm along a very long flank.
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        for index, y in enumerate((-9.0, -5.0, -1.0, 3.0)):
            box(f"{ASSET}_keel_rib_{tag}_{index}", (0.44, 0.76, 2.80),
                (side * (KEEL_HALF_W + 0.05), y, -0.05), mats["steel"], bevel=0.06)
        # Exposed boiler bank feeding the propellers.
        for index, y in enumerate((-4.6, -1.2, 2.2)):
            cylinder(f"{ASSET}_keel_boiler_{tag}_{index}", 0.52, 2.40,
                     (side * (KEEL_HALF_W + 0.26), y, -0.85), mats["copper"],
                     vertices=10, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.05)


def build_keel_girder(mats):
    """One unbroken understructure: the RTS camera spends its time under here."""
    box(f"{ASSET}_girder", (2.55, 21.20, 0.62), (0.0, -0.80, GIRDER_Z), mats["dark_iron"],
        bevel=0.07)
    box(f"{ASSET}_girder_rail", (3.30, 20.40, 0.26), (0.0, -0.80, GIRDER_Z - 0.42),
        mats["brass"], bevel=0.05)
    for index, y in enumerate((-10.0, -6.6, -3.2, 0.2, 3.6, 7.6)):
        box(f"{ASSET}_girder_rib_{index}", (3.55, 0.40, 0.90), (0.0, y, GIRDER_Z + 0.10),
            mats["steel"], bevel=0.05)
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        cylinder_between(
            f"{ASSET}_girder_truss_fwd_{tag}", (side * 1.30, -11.00, GIRDER_Z),
            (side * 1.90, -5.40, KEEL_BOTTOM), 0.15, mats["dark_iron"], vertices=8,
        )
        cylinder_between(
            f"{ASSET}_girder_truss_aft_{tag}", (side * 1.30, 9.60, GIRDER_Z),
            (side * 1.90, 4.20, KEEL_BOTTOM), 0.15, mats["dark_iron"], vertices=8,
        )


def build_prow(mats):
    # Armoured ram: settles the ship's facing from every angle.
    # The prow is a mass, not a spike: it has to out-read two cell noses.
    prism(f"{ASSET}_prow", (3.40, 3.20), (1.30, 1.70), KEEL_FRONT, PROW_TIP,
          (0.0, 0.0, 0.25), mats["dark_iron"], bevel=0.11)
    prism(f"{ASSET}_prow_deck", (3.20, 0.62), (1.20, 0.46), KEEL_FRONT + 0.2, PROW_TIP + 0.4,
          (0.0, 0.0, 1.62), mats["steel"], bevel=0.06)
    prism(f"{ASSET}_prow_ram", (1.70, 2.00), (0.42, 0.70), PROW_TIP + 0.3, PROW_TIP - 1.55,
          (0.0, 0.0, 0.10), mats["bronze"], bevel=0.07)
    box(f"{ASSET}_prow_collar", (3.60, 0.62, 3.40), (0.0, KEEL_FRONT - 0.30, 0.25),
        mats["brass"], bevel=0.08)
    box(f"{ASSET}_prow_band", (2.70, 0.46, 2.50), (0.0, PROW_TIP + 1.60, 0.20),
        mats["brass"], bevel=0.07)
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        box(f"{ASSET}_prow_cheek_{tag}", (0.42, 4.20, 1.70), (side * 1.32, KEEL_FRONT - 2.00, 0.45),
            mats["steel"], rot=(0.0, math.radians(side * 12.0), 0.0), bevel=0.06)
    # Bow lens: the forward end of the Aether run, no barrel.
    cylinder(f"{ASSET}_prow_lens", 0.52, 0.26, (0.0, PROW_TIP + 0.95, 0.85),
             mats["aether_glow"], vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
    torus(f"{ASSET}_prow_lens_ring", 0.66, 0.13, (0.0, PROW_TIP + 0.90, 0.85), mats["brass"],
          rot=(math.radians(90.0), 0.0, 0.0), major=12, minor=5)


# --------------------------------------------------------------- underside mass
def build_gondola(mats):
    # Command gondola, hung forward where the RTS camera looks under the hull.
    prism(f"{ASSET}_gondola", (3.90, 1.95), (3.10, 1.60), -4.30, -10.60, (0.0, 0.0, -2.62),
          mats["steel"], bevel=0.09)
    box(f"{ASSET}_gondola_roof", (4.20, 6.40, 0.34), (0.0, -7.45, -1.72), mats["dark_iron"],
        bevel=0.06)
    box(f"{ASSET}_gondola_keelplate", (3.20, 5.90, 0.30), (0.0, -7.45, -3.58), mats["bronze"],
        bevel=0.05)
    # Bridge glazing: one continuous cyan slit, the crew's place in the machine.
    box(f"{ASSET}_bridge_slit", (3.16, 0.34, 0.52), (0.0, -10.48, -2.30), mats["aether_glow"],
        bevel=0.0)
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        box(f"{ASSET}_bridge_slit_{tag}", (0.30, 3.20, 0.46), (side * 1.86, -8.70, -2.34),
            mats["aether_glow"], bevel=0.0)
        box(f"{ASSET}_gondola_rib_{tag}", (0.26, 0.60, 1.90), (side * 1.96, -5.20, -2.62),
            mats["brass"], bevel=0.05)
        cylinder_between(
            f"{ASSET}_gondola_strut_{tag}", (side * 1.55, -4.10, KEEL_BOTTOM + 0.1),
            (side * 1.70, -5.60, -2.30), 0.15, mats["dark_iron"], vertices=8,
        )


def build_belly_mortar(mats):
    # Primary weapon: a short, heavy mortar aimed down and forward. The whole
    # ship is the carriage, which is why it needs no arm.
    tilt = math.radians(-152.0)  # barrel axis: down and toward -Y
    box(f"{ASSET}_mortar_cradle", (3.30, 3.90, 1.05), (0.0, -1.40, -2.05), mats["dark_iron"],
        bevel=0.10)
    cylinder(f"{ASSET}_mortar_breech", 1.02, 1.30, (0.0, -1.10, -2.42), mats["steel"],
             vertices=14, rot=(tilt, 0.0, 0.0), bevel=0.08)
    cylinder(f"{ASSET}_mortar_core", 0.58, 0.46, (0.0, -0.62, -2.05), mats["aether_glow"],
             vertices=12, rot=(tilt, 0.0, 0.0), bevel=0.0)
    torus(f"{ASSET}_mortar_core_ring", 0.72, 0.13, (0.0, -0.58, -2.02), mats["brass"],
          rot=(tilt, 0.0, 0.0), major=14, minor=5)
    cylinder(f"{ASSET}_mortar_barrel", 0.95, 2.80, (0.0, -2.26, -3.46), mats["bronze"],
             vertices=14, rot=(tilt, 0.0, 0.0), bevel=0.06)
    for index, (by, bz) in enumerate(((-1.72, -2.92), (-2.40, -3.60), (-3.08, -4.28))):
        torus(f"{ASSET}_mortar_band_{index}", 1.08, 0.16, (0.0, by, bz), mats["brass"],
              rot=(tilt, 0.0, 0.0), major=12, minor=4)
    cylinder(f"{ASSET}_mortar_muzzle", 1.04, 0.40, (0.0, -3.28, -4.48), mats["dark_iron"],
             vertices=14, rot=(tilt, 0.0, 0.0), bevel=0.04)
    cylinder(f"{ASSET}_mortar_lens", 0.70, 0.18, (0.0, -3.38, -4.58), mats["aether_glow"],
             vertices=12, rot=(tilt, 0.0, 0.0), bevel=0.0)
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        cylinder_between(
            f"{ASSET}_mortar_recoil_{tag}", (side * 1.15, -0.10, -1.95),
            (side * 0.92, -1.95, -3.05), 0.17, mats["copper"], vertices=8,
        )


def build_sponsons(mats):
    # Broadside batteries. Two per side keeps the flank busy at mid zoom
    # without stealing the mortar's role as the readable main gun.
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        for index, y in enumerate((-6.80, 2.10)):
            x = side * (KEEL_HALF_W + 0.52)
            box(f"{ASSET}_sponson_{tag}_{index}", (1.60, 3.30, 1.55), (x, y, -0.55),
                mats["dark_iron"], rot=(0.0, math.radians(side * -14.0), 0.0), bevel=0.08)
            box(f"{ASSET}_sponson_plate_{tag}_{index}", (0.36, 3.00, 1.30),
                (side * (KEEL_HALF_W + 1.26), y, -0.48), mats["steel"], bevel=0.06)
            cylinder(f"{ASSET}_sponson_ring_{tag}_{index}", 0.86, 0.30,
                     (side * (KEEL_HALF_W + 1.30), y, -0.48), mats["brass"],
                     vertices=12, rot=(0.0, math.radians(90.0), 0.0), bevel=0.04)
            for offset in (-0.44, 0.44):
                cylinder(
                    f"{ASSET}_sponson_barrel_{tag}_{index}_{int((offset + 1) * 10)}",
                    0.21, 2.30, (side * (KEEL_HALF_W + 2.30), y + offset, -0.48),
                    mats["bronze"], vertices=10, rot=(0.0, math.radians(90.0), 0.0), bevel=0.04,
                )
            cylinder(f"{ASSET}_sponson_feed_{tag}_{index}", 0.22, 1.40,
                     (side * (KEEL_HALF_W + 0.30), y + 1.30, -1.20), mats["copper"],
                     vertices=8, bevel=0.03)


def build_machinery_pod(mats):
    # Aft underside: boilers and furnace mouths, the steam half of the ship.
    prism(f"{ASSET}_pod", (3.20, 1.70), (3.60, 1.85), 9.40, 2.90, (0.0, 0.0, -2.45),
          mats["dark_iron"], bevel=0.09)
    box(f"{ASSET}_pod_deck", (3.90, 6.30, 0.32), (0.0, 6.15, -1.68), mats["steel"], bevel=0.06)
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        cylinder(f"{ASSET}_pod_drum_{tag}", 0.74, 4.60, (side * 1.10, 6.20, -2.70),
                 mats["copper"], vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.06)
        for index, y in enumerate((4.60, 7.80)):
            torus(f"{ASSET}_pod_band_{tag}_{index}", 0.82, 0.10, (side * 1.10, y, -2.70),
                  mats["brass"], rot=(math.radians(90.0), 0.0, 0.0), major=12, minor=5)
        box(f"{ASSET}_pod_furnace_{tag}", (0.70, 0.30, 0.62), (side * 1.10, 3.30, -2.70),
            mats["furnace_glow"], bevel=0.0)
        box(f"{ASSET}_pod_rust_{tag}", (0.24, 1.10, 0.90), (side * 1.82, 3.90, -2.35),
            mats["rust"], bevel=0.04)
        cylinder_between(
            f"{ASSET}_pod_steam_{tag}", (side * 1.10, 8.60, -2.70),
            (side * 3.90, 7.60, -0.62), 0.20, mats["copper"], vertices=8,
        )


# -------------------------------------------------------------------- propulsion
def build_engines(mats):
    # Steam ducted propellers: cruise thrust, fed by the keel boiler bank.
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        x = side * 5.20
        cylinder(f"{ASSET}_nacelle_{tag}", 1.12, 3.60, (x, 6.90, -0.62), mats["dark_iron"],
                 vertices=14, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.08)
        cylinder(f"{ASSET}_nacelle_drum_{tag}", 0.96, 1.60, (x, 5.40, -0.62), mats["copper"],
                 vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.06)
        torus(f"{ASSET}_nacelle_band_{tag}", 1.18, 0.12, (x, 7.60, -0.62), mats["brass"],
              rot=(math.radians(90.0), 0.0, 0.0), major=14, minor=5)
        box(f"{ASSET}_nacelle_furnace_{tag}", (0.56, 0.26, 0.50), (x, 4.58, -0.62),
            mats["furnace_glow"], bevel=0.0)
        # Pylon up into the cell belly: the engine hangs from the lift cell.
        box(f"{ASSET}_nacelle_pylon_{tag}", (0.46, 2.10, 1.60), (x, 6.60, 0.42),
            mats["steel"], bevel=0.06)
        # Duct ring + blades. Separate objects survive joining as one mesh but
        # the hub anchor keeps a future rotation rig possible.
        torus(f"{ASSET}_duct_{tag}", 1.62, 0.26, (x, 9.05, -0.62), mats["brass"],
              rot=(math.radians(90.0), 0.0, 0.0), major=16, minor=5)
        cylinder(f"{ASSET}_duct_lip_{tag}", 1.74, 0.22, (x, 9.05, -0.62), mats["dark_iron"],
                 vertices=18, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)
        cylinder(f"{ASSET}_prop_hub_{tag}", 0.40, 0.80, (x, 8.95, -0.62), mats["steel"],
                 vertices=10, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.05)
        for blade in range(4):
            ang = math.radians(blade * 90.0 + 22.0)
            box(f"{ASSET}_prop_blade_{tag}_{blade}", (0.24, 0.16, 2.40),
                (x + math.sin(ang) * 0.82, 8.95, -0.62 + math.cos(ang) * 0.82),
                mats["bronze"], rot=(0.0, math.radians(blade * 90.0 + 22.0), math.radians(14.0)),
                bevel=0.0)


def build_tail(mats):
    # Tail boom carries the H-tail and the Aether thrusters.
    prism(f"{ASSET}_tail_boom", (2.60, 1.80), (3.20, 2.60), TAIL_TIP, KEEL_REAR - 0.4,
          (0.0, 0.0, 0.35), mats["dark_iron"], bevel=0.09)
    box(f"{ASSET}_tail_collar", (3.40, 0.50, 2.80), (0.0, KEEL_REAR + 0.20, 0.35),
        mats["brass"], bevel=0.07)

    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        # Vertical fins sit directly behind the cells, so the H reads as the
        # tail of a twin-cell ship rather than a generic cruciform.
        box(f"{ASSET}_fin_{tag}", (0.40, 5.40, 5.60), (side * CELL_X, 14.20, 3.20),
            mats["steel"], bevel=0.08)
        box(f"{ASSET}_fin_edge_{tag}", (0.52, 0.52, 5.40), (side * CELL_X, 16.55, 3.20),
            mats["dark_iron"], bevel=0.06)
        box(f"{ASSET}_fin_spar_{tag}", (0.54, 0.50, 5.30), (side * CELL_X, 11.90, 3.20),
            mats["brass"], bevel=0.05)
        box(f"{ASSET}_fin_mark_{tag}", (0.46, 2.20, 0.42), (side * CELL_X, 15.20, 4.90),
            mats["aether_glow"], bevel=0.0)
        cylinder_between(
            f"{ASSET}_fin_stay_{tag}", (side * CELL_X, 12.60, 1.10),
            (side * 1.20, KEEL_REAR + 0.4, 0.60), 0.16, mats["dark_iron"], vertices=8,
        )
        cylinder_between(
            f"{ASSET}_fin_stay_top_{tag}", (side * CELL_X, 12.60, 5.30),
            (side * 1.60, KEEL_REAR + 0.6, 3.60), 0.14, mats["dark_iron"], vertices=8,
        )
        # Aether thruster: brass ring nozzle, cyan throat, fed from the reactor.
        cylinder(f"{ASSET}_thruster_{tag}", 0.86, 2.20, (side * 1.20, 14.90, 0.20),
                 mats["steel"], vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.06)
        torus(f"{ASSET}_thruster_ring_{tag}", 0.96, 0.18, (side * 1.20, TAIL_TIP - 0.25, 0.20),
              mats["brass"], rot=(math.radians(90.0), 0.0, 0.0), major=14, minor=5)
        cylinder(f"{ASSET}_thruster_core_{tag}", 0.70, 0.26, (side * 1.20, TAIL_TIP - 0.34, 0.20),
                 mats["aether_glow"], vertices=12, rot=(math.radians(90.0), 0.0, 0.0), bevel=0.0)

    # Tailplane caps the fins at the top so the rear reads as one H, not two plates.
    box(f"{ASSET}_tailplane", (2 * CELL_X + 1.60, 3.60, 0.40), (0.0, 14.60, 5.85),
        mats["dark_iron"], bevel=0.07)
    box(f"{ASSET}_tailplane_spar", (2 * CELL_X + 1.20, 0.54, 0.56), (0.0, 12.90, 5.85),
        mats["brass"], bevel=0.05)
    box(f"{ASSET}_tailplane_edge", (2 * CELL_X + 1.60, 0.44, 0.48), (0.0, 16.30, 5.85),
        mats["bronze"], bevel=0.05)
    box(f"{ASSET}_tailplane_lower", (2 * CELL_X + 0.60, 2.80, 0.34), (0.0, 14.60, 1.10),
        mats["steel"], bevel=0.06)


def build_reactor(mats):
    # Dorsal reactor in the trench between the cells: the single Aether source.
    box(f"{ASSET}_reactor_base", (2.50, 4.20, 0.70), (0.0, 4.20, KEEL_TOP + 0.95),
        mats["dark_iron"], bevel=0.08)
    cylinder(f"{ASSET}_reactor_housing", 1.32, 2.80, (0.0, 4.20, KEEL_TOP + 2.60),
             mats["steel"], vertices=16, bevel=0.08)
    cylinder(f"{ASSET}_reactor_core", 0.94, 1.70, (0.0, 4.20, KEEL_TOP + 2.60),
             mats["aether_glow"], vertices=16, bevel=0.0)
    for z in (KEEL_TOP + 1.55, KEEL_TOP + 3.65):
        torus(f"{ASSET}_reactor_ring_{int(z * 100)}", 1.42, 0.18, (0.0, 4.20, z), mats["brass"],
              major=14, minor=5)
    cylinder(f"{ASSET}_reactor_cap", 1.36, 0.50, (0.0, 4.20, KEEL_TOP + 4.30), mats["bronze"],
             vertices=16, bevel=0.06)
    # Twin uptakes: the Gearforge paired-stack motif, kept short so the cells win.
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        cylinder(f"{ASSET}_reactor_stack_{tag}", 0.44, 2.40, (side * 0.92, 1.70, KEEL_TOP + 1.70),
                 mats["copper"], vertices=12, bevel=0.06)
        torus(f"{ASSET}_reactor_stack_ring_{tag}", 0.52, 0.10, (side * 0.92, 1.70, KEEL_TOP + 2.70),
              mats["brass"], major=12, minor=5)

    # Injector trunks: reactor -> both lift cells. This is the lift circuit.
    for side in (-1.0, 1.0):
        tag = "l" if side < 0 else "r"
        cylinder_between(
            f"{ASSET}_injector_trunk_{tag}", (side * 0.95, 4.20, KEEL_TOP + 2.20),
            (side * 2.90, 4.20, CELL_Z - CELL_R + 0.30), 0.26, mats["copper"], vertices=10,
        )
        # Keel conduits: reactor -> mortar breech, and reactor -> thrusters.
        cylinder_between(
            f"{ASSET}_conduit_fwd_{tag}", (side * 0.72, 3.00, KEEL_TOP + 0.85),
            (side * 0.72, -0.60, -1.55), 0.20, mats["copper"], vertices=8,
        )
        cylinder_between(
            f"{ASSET}_conduit_aft_{tag}", (side * 0.82, 5.60, KEEL_TOP + 0.85),
            (side * 1.15, 14.90, 0.35), 0.20, mats["copper"], vertices=8,
        )
        # Faction chevron on the outer cell flank, readable from the side only.
        cx, cz = cell_surface(side, 62.0, CELL_R + 0.02)
        box(f"{ASSET}_flank_mark_{tag}", (0.24, 2.60, 0.52), (cx, -6.40, cz),
            mats["aether_glow"], rot=(0.0, math.radians(side * 62.0), 0.0), bevel=0.0)


def build_anchors():
    anchor("muzzle", (0.0, -3.46, -4.66))
    anchor("weapon_l", (-4.50, -6.80, -0.48))
    anchor("weapon_r", (4.50, -6.80, -0.48))
    anchor("reactor_anchor", (0.0, 4.20, KEEL_TOP + 2.60))
    anchor("engine_l", (-5.20, 8.95, -0.62))
    anchor("engine_r", (5.20, 8.95, -0.62))
    anchor("exhaust_l", (-5.20, 4.45, -0.62))
    anchor("exhaust_r", (5.20, 4.45, -0.62))
    anchor("thruster_l", (-1.20, TAIL_TIP - 0.45, 0.20))
    anchor("thruster_r", (1.20, TAIL_TIP - 0.45, 0.20))
    anchor("bow_lens", (0.0, PROW_TIP + 0.80, 0.85))
    anchor("bridge_anchor", (0.0, -10.55, -2.30))


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
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            for axis in range(3):
                lo[axis] = min(lo[axis], world[axis])
                hi[axis] = max(hi[axis], world[axis])
    materials = {slot.material.name for obj in meshes for slot in obj.material_slots if slot.material}
    print(
        "AIRSHIP_STATS meshes=%d verts=%d polygons=%d triangles=%d materials=%d"
        % (len(meshes), verts, polygons, triangles, len(materials))
    )
    print(
        "AIRSHIP_BOUNDS width=%.3f length=%.3f height=%.3f x=[%.2f,%.2f] y=[%.2f,%.2f] z=[%.2f,%.2f]"
        % (hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z)
    )
    return len(meshes), verts, polygons, triangles, len(materials), (hi - lo)


def main():
    clear_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["asset_name"] = ASSET
    scene["design_variant"] = "C_twin_cell_aether_dreadnought"
    scene["production_name"] = "Crownhammer"
    scene["forward_axis"] = "-Y"
    scene["up_axis"] = "+Z"
    scene["origin_mode"] = "flight_origin_keel_centre"
    scene["texture_count"] = 0

    mats = palette("gearforge")
    build_keel(mats)
    build_keel_girder(mats)
    build_prow(mats)
    build_lift_cell(-1.0, mats)
    build_lift_cell(1.0, mats)
    build_gondola(mats)
    build_belly_mortar(mats)
    build_sponsons(mats)
    build_machinery_pod(mats)
    build_engines(mats)
    build_tail(mats)
    build_reactor(mats)
    join_by_material(mats)
    build_anchors()

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

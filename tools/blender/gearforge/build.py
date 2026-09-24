"""Gearforge machines from the earlier Aether Crown project, rebuilt as Ironspine units.

The make_gearforge_*.py modules (and material_lib, building_kit) are that project's generators,
kept as they were; run this driver, not them (their main() writes into the old project's layout).
It calls their build functions, then instead of their own joins:
  * joins the pieces into the parts the game animates, each with its pivot as origin,
  * adds anchor empties (muzzles, exhausts) parented to the part that carries them,
  * bakes painted-metal textures (bake.py) into game/assets/textures/units/<name>_*.png,
  * gives every part one material "gf_<name>", which MatLib turns into the machine shader.

Blender space here is the old scripts' (x right, -y front, z up); glTF export turns -y into
Godot's +z front, as the other unit models have it.

Run: blender --background --factory-startup --python tools/blender/gearforge/build.py [-- name ...]
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import bake  # noqa: E402
import mk  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models")
TEX = os.path.join(ROOT, "game", "assets", "textures", "units")
BLEND = os.path.join(ROOT, "art", "blend", "units")


def _leg_groups(side_tag, foot, shin, thigh):
    """Name patterns for one leg split at the knee and ankle."""
    return [(foot, "foot_" + side_tag), (shin, "shin_" + side_tag), (thigh, "leg_" + side_tag)]


def _strider():
    import make_gearforge_walker as M
    from material_lib import palette
    full = palette("gearforge")
    mats = {k: full[k] for k in ("dark_iron", "steel", "brass", "copper", "aether_glow")}
    M.build_leg(-1.0, mats)
    M.build_leg(1.0, mats)
    M.build_hull(mats)
    M.build_turret(mats)


def _quad():
    import make_gearforge_medium_quad_walker as M
    from material_lib import palette
    mats = palette("gearforge")
    for leg in ("leg_fl", "leg_fr", "leg_rl", "leg_rr"):
        M.build_quad_leg(leg, mats)
    M.build_hull(mats)
    M.build_turret(mats)


def _dreadnought():
    import make_gearforge_airship as M
    from material_lib import palette
    mats = palette("gearforge")
    for fn in ("build_keel", "build_keel_girder", "build_prow"):
        getattr(M, fn)(mats)
    M.build_lift_cell(-1.0, mats)
    M.build_lift_cell(1.0, mats)
    for fn in ("build_gondola", "build_belly_mortar", "build_sponsons", "build_machinery_pod", "build_engines",
               "build_tail", "build_reactor"):
        getattr(M, fn)(mats)


def _colossus():
    import make_gearforge_titan as M
    from material_lib import palette
    mats = palette("gearforge")
    M.build_foot(-1.0, mats)
    M.build_foot(1.0, mats)
    M.build_body(mats)
    M.build_cannon(mats)
    M.build_brace_arm(mats)
    M.build_reactor_and_exhaust(mats)


def _titan_leg(s):
    return _leg_groups(
        s,
        rf"^(sole|foot_deck|toe|toe_ram|heel|heel_cap|ankle|ankle_axle|ankle_fork|ankle_ram)_{s}(_\d+)*$",
        rf"^(shin|shin_armor|knee|knee_cap|knee_guard|knee_outer_cap|shin_piston|shin_rivet|front_leg_ram)_{s}(_\d+)*$",
        rf"^(thigh|thigh_plate|thigh_crown|thigh_piston)_{s}(_\d+)*$")


def _quad_leg(leg):
    return [
        (rf"^{leg}_(ankle_pin|ankle_bracket|ankle_shock|foot|claw|heel|side_cleat)", "foot_" + leg[4:]),
        (rf"^{leg}_(knee|shin)", "shin_" + leg[4:]),
        (rf"^{leg}_", "leg_" + leg[4:]),
    ]


# groups: first matching pattern wins (names without the asset prefix); pivot: object whose centre
# is the joint, or a position; parent: the part it hangs from. paint: extra always-painted pieces.
MODELS = {
    "strider": {
        "asset": "gearforge_walker", "build": _strider, "res": 1024, "size": 4.5,
        "groups": [(r"^legl_(pad|deck|toe|claw|heel|spur|cleat|bolt|ankle_block|ankle_axle)", "foot_l"),
                   (r"^legl_(knee|shin|ankle_ram)", "shin_l"),
                   (r"^legl_", "leg_l"),
                   (r"^legr_(pad|deck|toe|claw|heel|spur|cleat|bolt|ankle_block|ankle_axle)", "foot_r"),
                   (r"^legr_(knee|shin|ankle_ram)", "shin_r"),
                   (r"^legr_", "leg_r"),
                   (r"^turret_", "turret"),
                   (r".", "hull")],
        "parts": {"hull": (None, (0.0, 0.1, 2.82)), "turret": ("hull", "turret_ring"),
                  "leg_l": ("hull", "legl_hip_axle"), "shin_l": ("leg_l", "legl_knee"),
                  "foot_l": ("shin_l", "legl_ankle_axle"),
                  "leg_r": ("hull", "legr_hip_axle"), "shin_r": ("leg_r", "legr_knee"),
                  "foot_r": ("shin_r", "legr_ankle_axle")},
        "anchors": {"muzzle": ("turret", "turret_brake", (0, -0.35, 0)),
                    "exhaust_l": ("hull", "hull_exhaust_lip_l", (0, 0, 0.1)),
                    "exhaust_r": ("hull", "hull_exhaust_lip_r", (0, 0, 0.1))},
        "paint": r"(faction_plate|thigh_plate|shin_plate|hull_roof|turret_hatch|hull_shoulder_cap)",
    },
    "quadwalker": {
        "asset": "gearforge_medium_quad_walker", "build": _quad, "res": 1024, "size": 5.5,
        "groups": _quad_leg("leg_fl") + _quad_leg("leg_fr") + _quad_leg("leg_rl") + _quad_leg("leg_rr") + [
            (r"^gun_l_", "gun_l"), (r"^gun_r_", "gun_r"),
            (r"^(turret_(?!traverse)|traverse_gear|cupola|vent_louver|ammo_|lifting_lug|gun_mantlet|cannon_cross"
             r"|brace_center|targeting|smoke_)", "turret"),
            (r".", "hull")],
        "parts": {"hull": (None, (0.0, 0.0, 2.6)), "turret": ("hull", "turret_traverse_core"),
                  "gun_l": ("turret", "gun_l_trunnion"), "gun_r": ("turret", "gun_r_trunnion"),
                  **{f"leg_{k}": ("hull", f"leg_{k}_hip_hub") for k in ("fl", "fr", "rl", "rr")},
                  **{f"shin_{k}": (f"leg_{k}", f"leg_{k}_knee_hub") for k in ("fl", "fr", "rl", "rr")},
                  **{f"foot_{k}": (f"shin_{k}", f"leg_{k}_ankle_pin") for k in ("fl", "fr", "rl", "rr")}},
        "anchors": {"muzzle_l": ("gun_l", "gun_l_muzzle_brake", (0, -0.3, 0)),
                    "muzzle_r": ("gun_r", "gun_r_muzzle_brake", (0, -0.3, 0)),
                    "exhaust_l": ("hull", "stack_lip_l", (0, 0, 0.1)),
                    "exhaust_r": ("hull", "stack_lip_r", (0, 0, 0.1))},
        "paint": r"(faction_plate|thigh_plate|shin_shield|hull_glacis|turret_glacis|sponson_f_|ammo_door)",
    },
    "dreadnought": {
        "asset": "gearforge_airship", "build": _dreadnought, "res": 2048, "size": 14.0,
        "groups": [(r"^prop_(hub|blade)_l", "prop_l"), (r"^prop_(hub|blade)_r", "prop_r"), (r".", "hull")],
        "parts": {"hull": (None, (0.0, 0.0, 0.0)), "prop_l": ("hull", "prop_hub_l"), "prop_r": ("hull", "prop_hub_r")},
        "anchors": {**{f"gun_{s}{i}": ("hull", f"sponson_barrel_{s}_{i}_5", (0, -0.9, 0))
                       for s in ("l", "r") for i in (0, 1)},
                    "mortar": ("hull", "mortar_muzzle", (0, 0, -0.3)),
                    "exhaust_l": ("hull", "reactor_stack_ring_l", (0, 0, 0.2)),
                    "exhaust_r": ("hull", "reactor_stack_ring_r", (0, 0, 0.2))},
        "paint": r"(fin_mark|flank_mark|fin_[lr]$|gondola$|sponson_plate|prow_cheek)",
    },
    "colossus": {
        "asset": "gearforge_titan", "build": _colossus, "res": 2048, "size": 11.5,
        "groups": _titan_leg("l") + _titan_leg("r") + [
            (r"^(cannon_|recoil_|cradle_|breech_lock|weapon_feed)", "cannon"),
            (r"^brace_", "brace"),
            (r"^hip_", "hips"),
            (r".", "torso")],
        "parts": {"hips": (None, "hip_turntable"), "torso": ("hips", "hip_turntable"),
                  "cannon": ("torso", "cannon_shoulder_axle"), "brace": ("torso", "brace_shoulder_axle"),
                  "leg_l": ("hips", "thigh_crown_l"), "shin_l": ("leg_l", "knee_l"), "foot_l": ("shin_l", "ankle_axle_l"),
                  "leg_r": ("hips", "thigh_crown_r"), "shin_r": ("leg_r", "knee_r"), "foot_r": ("shin_r", "ankle_axle_r")},
        "anchors": {"muzzle": ("cannon", "cannon_muzzle", (0, -0.5, 0)),
                    "exhaust_l": ("torso", "stack_lip_l", (0, 0, 0.2)),
                    "exhaust_r": ("torso", "stack_lip_r", (0, 0, 0.2))},
        "paint": r"(back_chevron|shin_armor|thigh_plate|torso_front_plate|glacis|cannon_shroud|brace_face|torso_side_rib)",
    },
}


def centre(o):
    return sum((o.matrix_world @ Vector(c) for c in o.bound_box), Vector()) / 8.0


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.name = name
    ob.data.name = name
    return ob


def build(name):
    spec = MODELS[name]
    mk.reset()
    spec["build"]()
    prefix = spec["asset"] + "_"
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    short = {o: o.name[len(prefix):] if o.name.startswith(prefix) else o.name for o in meshes}
    # joints and anchors are measured on the untouched pieces
    where = {s: centre(o) for o, s in short.items()}

    def pos(ref):
        return Vector(ref) if isinstance(ref, tuple) else where[ref].copy()

    paint = bpy.data.materials.new("gearforge_paint")
    for o, s in short.items():
        if re.search(spec["paint"], s):
            for slot in o.material_slots:
                if slot.material and "glow" not in slot.material.name:
                    slot.material = paint
    members = {}
    for o, s in short.items():
        part = next(p for pat, p in spec["groups"] if re.search(pat, s))
        members.setdefault(part, []).append(o)
    missing = set(members) ^ set(spec["parts"])
    assert not missing, "parts without pieces or pieces without parts: %s" % missing

    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    parts = {}
    for part, (parent, ref) in spec["parts"].items():
        ob = join(members[part], part)
        pv = pos(ref)
        ob.data.transform(Matrix.Translation(-pv))
        ob.location = pv
        ob["pivot"] = pv
        parts[part] = ob
    for part, (parent, _ref) in spec["parts"].items():
        ob = parts[part]
        up = parts[parent] if parent else root
        pv = Vector(ob["pivot"])
        ob.parent = up
        ob.location = pv - (Vector(up["pivot"]) if parent else Vector())
    for anchor, (part, ref, off) in spec["anchors"].items():
        e = bpy.data.objects.new(anchor, None)
        bpy.context.scene.collection.objects.link(e)
        e.parent = parts[part]
        e.location = pos(ref) + Vector(off) - Vector(parts[part]["pivot"])

    objs = list(parts.values())
    bake.bake(objs, name, TEX, spec["res"], spec["size"])
    final = mk.mat("gf_" + name, (0.3, 0.3, 0.32), 0.8, 0.45)
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(final)
        for p in o.data.polygons:
            p.material_index = 0
        del o["pivot"]
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    for img in list(bpy.data.images):
        bpy.data.images.remove(img)
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    mk.save_blend(os.path.join(BLEND, name + ".blend"))
    mk.export_glb(os.path.join(OUT, name + ".glb"))
    print("[gearforge] %-12s parts=%d tris=%d" % (name, len(objs), tris), flush=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name in argv or list(MODELS):
        build(name)


if __name__ == "__main__":
    main()

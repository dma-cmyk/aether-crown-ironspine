"""Shared Gearforge PBR palette (Phase 2.5A art foundation).

Provides the production material library used by all Phase 2.5A asset
scripts: dark iron / steel / brass / bronze / copper / stone / rust /
Aether emissive blue / furnace emissive orange. Principled BSDF only,
no textures (Iris Xe budget, RTS distance). Same parameter values in
every asset so materials stay shared across the building set.

This module is imported by make_*.py scripts, not run directly.
Run: blender --background --python blender/scripts/material_lib.py
(prints the palette, creates nothing).
"""
import bpy

# (base_color_rgb, metallic, roughness, emission_rgb_or_None, emission_strength)
PALETTE = {
    "dark_iron": ((0.23, 0.24, 0.28), 0.70, 0.60, None, 0.0),
    "steel": ((0.45, 0.47, 0.52), 0.85, 0.35, None, 0.0),
    "brass": ((0.60, 0.44, 0.20), 0.85, 0.40, None, 0.0),
    "bronze": ((0.48, 0.32, 0.16), 0.80, 0.50, None, 0.0),
    "copper": ((0.70, 0.36, 0.18), 0.80, 0.45, None, 0.0),
    "stone": ((0.42, 0.40, 0.38), 0.05, 0.90, None, 0.0),
    "rust": ((0.45, 0.25, 0.12), 0.30, 0.80, None, 0.0),
    "aether_glow": ((0.25, 0.70, 1.00), 0.00, 0.40, (0.25, 0.70, 1.00), 2.5),
    "furnace_glow": ((1.00, 0.50, 0.15), 0.00, 0.40, (1.00, 0.50, 0.15), 2.2),
}


def make_pbr(name, base_color, metallic=0.6, roughness=0.5,
             emission_color=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        if "Base Color" in bsdf.inputs:
            bsdf.inputs["Base Color"].default_value = (*base_color, 1.0)
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
        if emission_color is not None:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = (*emission_color, 1.0)
            elif "Emission" in bsdf.inputs:
                try:
                    bsdf.inputs["Emission"].default_value = (*emission_color, 1.0)
                except Exception:
                    pass
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def palette(prefix="gearforge"):
    """Create (or reuse params for) every palette material. Returns dict."""
    mats = {}
    for key, (color, metallic, roughness, emission, strength) in PALETTE.items():
        mats[key] = make_pbr("%s_%s" % (prefix, key), color, metallic,
                             roughness, emission, strength)
    return mats


if __name__ == "__main__":
    for key, spec in PALETTE.items():
        print("PALETTE %s color=%s metallic=%.2f roughness=%.2f emission=%s strength=%.1f"
              % (key, spec[0], spec[1], spec[2], spec[3], spec[4]))

"""Painted-metal texture bake for the Gearforge machines.

Every object keeps its gearforge_<key> material slots while baking; each slot gets a procedural
Cycles material for its metal (edge wear from a bevel probe, cavity grime from AO, vertical
streaks, rust, verdigris, chipped team paint), and four maps are baked into one atlas:

  <name>_albedo.png  sRGB colour. Team-painted areas hold a neutral grey (PAINT_GREY) that the game
                     multiplies by the side's colour.
  <name>_orm.png     R ambient occlusion, G roughness, B metallic
  <name>_mask.png    R team paint, G team glow (Aether), B furnace glow
  <name>_normal.png  tangent-space normal (OpenGL, +Y): rounded bevels and hammered-metal grain
"""
import math
import os

import bpy

PAINT_GREY = 0.5  # sRGB value of bare team paint in the albedo map; the game shader divides by it

# key -> look. base/wear colours are linear. "paint": share of the surface painted in team colour.
LOOKS = {
    "dark_iron": {"base": (0.068, 0.072, 0.082), "metal": 0.75, "rough": 0.55, "wear": (0.42, 0.43, 0.45),
                  "wear_amt": 1.0, "rust": 0.3, "paint": 0.0, "panels": 1.0},
    "steel": {"base": (0.20, 0.21, 0.23), "metal": 0.85, "rough": 0.38, "wear": (0.55, 0.56, 0.58),
              "wear_amt": 1.0, "rust": 0.1, "paint": 0.0, "panels": 1.0},
    "brass": {"base": (0.52, 0.34, 0.12), "metal": 1.0, "rough": 0.34, "wear": (0.85, 0.66, 0.36),
              "wear_amt": 0.8, "tarnish": 0.6, "paint": 0.0},
    "bronze": {"base": (0.34, 0.19, 0.08), "metal": 0.95, "rough": 0.42, "wear": (0.70, 0.46, 0.25),
               "wear_amt": 0.8, "tarnish": 0.5, "paint": 0.0},
    "copper": {"base": (0.50, 0.20, 0.09), "metal": 1.0, "rough": 0.4, "wear": (0.85, 0.46, 0.30),
               "wear_amt": 0.8, "patina": 0.7, "paint": 0.0},
    "rust": {"base": (0.20, 0.075, 0.03), "metal": 0.15, "rough": 0.85, "wear": (0.28, 0.12, 0.05),
             "wear_amt": 0.3, "paint": 0.0},
    "stone": {"base": (0.16, 0.15, 0.14), "metal": 0.0, "rough": 0.9, "wear": (0.3, 0.29, 0.27),
              "wear_amt": 0.4, "paint": 0.0},
    # armour plates and markings in the side's colour (chosen per model by name)
    "paint": {"base": (0.20, 0.21, 0.23), "metal": 0.85, "rough": 0.4, "wear": (0.52, 0.53, 0.55),
              "wear_amt": 0.6, "paint": 1.0, "chips": 1.0, "panels": 1.0},
    "aether_glow": {"glow": "team", "base": (0.75, 0.92, 1.0)},
    "furnace_glow": {"glow": "fire", "base": (1.0, 0.45, 0.14)},
}


class Graph:
    """Tiny helper for wiring shader nodes from Python."""

    def __init__(self, mat):
        mat.use_nodes = True
        self.nt = mat.node_tree
        self.nt.nodes.clear()

    def node(self, kind, **props):
        n = self.nt.nodes.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def put(self, sock, v):
        if isinstance(v, bpy.types.NodeSocket):
            self.nt.links.new(v, sock)
        elif isinstance(v, (tuple, list)) and len(v) == 3 and sock.type == "RGBA":
            sock.default_value = (v[0], v[1], v[2], 1.0)
        else:
            sock.default_value = v

    @staticmethod
    def sock(socks, ident):
        return next(s for s in socks if s.identifier == ident)

    def math(self, op, a, b=None, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.put(n.inputs[0], a)
        if b is not None:
            self.put(n.inputs[1], b)
        return n.outputs[0]

    def add(self, a, b, clamp=False):
        return self.math("ADD", a, b, clamp)

    def mul(self, a, b, clamp=False):
        return self.math("MULTIPLY", a, b, clamp)

    def ramp(self, x, lo, hi):
        """0 below lo, 1 above hi, smooth in between."""
        n = self.node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP", clamp=True)
        self.put(n.inputs["Value"], x)
        n.inputs["From Min"].default_value = lo
        n.inputs["From Max"].default_value = hi
        return n.outputs["Result"]

    def mix(self, a, b, fac, kind="RGBA"):
        n = self.node("ShaderNodeMix", data_type=kind, clamp_factor=True)
        suffix = "Color" if kind == "RGBA" else "Float"
        self.put(self.sock(n.inputs, "Factor_Float"), fac)
        self.put(self.sock(n.inputs, "A_" + suffix), a)
        self.put(self.sock(n.inputs, "B_" + suffix), b)
        return self.sock(n.outputs, "Result_" + suffix)

    def rgb_mul(self, a, b):
        n = self.node("ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY")
        self.put(self.sock(n.inputs, "Factor_Float"), 1.0)
        self.put(self.sock(n.inputs, "A_Color"), a)
        self.put(self.sock(n.inputs, "B_Color"), b)
        return self.sock(n.outputs, "Result_Color")

    def noise(self, vec, scale, detail=3.0, rough=0.55, distortion=0.0):
        n = self.node("ShaderNodeTexNoise")
        self.put(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = distortion
        return n.outputs["Fac"]

    def scaled(self, vec, s):
        n = self.node("ShaderNodeMapping")
        self.put(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = s
        return n.outputs["Vector"]

    def combine(self, r, g, b):
        n = self.node("ShaderNodeCombineColor")
        self.put(n.inputs["Red"], r)
        self.put(n.inputs["Green"], g)
        self.put(n.inputs["Blue"], b)
        return n.outputs["Color"]


def build_bake_material(mat, key, size):
    """Turn `mat` into the procedural look for `key`. `size` (m) scales the noise to the model.
    Returns {pass: output socket} and the image node the bake writes into."""
    look = LOOKS[key]
    g = Graph(mat)
    out = g.node("ShaderNodeOutputMaterial")
    emit = g.node("ShaderNodeEmission")
    g.nt.links.new(emit.outputs[0], out.inputs["Surface"])
    img = g.node("ShaderNodeTexImage")
    g.nt.nodes.active = img
    img.select = True
    geo = g.node("ShaderNodeNewGeometry")
    P = geo.outputs["Position"]
    k = 4.0 / size  # noise frequency relative to a 4 m machine

    if "glow" in look:
        c = look["base"]
        passes = {
            "albedo": g.combine(*c),
            "orm": g.combine(1.0, 0.35, 0.0),
            "mask": g.combine(0.0, 1.0 if look["glow"] == "team" else 0.0, 1.0 if look["glow"] == "fire" else 0.0),
        }
        bsdf = g.node("ShaderNodeBsdfPrincipled")
        passes["normal"] = bsdf
        return passes, img, emit, out

    # probes: bevelled normal vs true normal = convex/concave edges; AO = cavities
    bevel = g.node("ShaderNodeBevel", samples=8)
    bevel.inputs["Radius"].default_value = 0.035 * size / 4.0
    dot = g.node("ShaderNodeVectorMath", operation="DOT_PRODUCT")
    g.put(dot.inputs[0], bevel.outputs["Normal"])
    g.put(dot.inputs[1], geo.outputs["Normal"])
    edge = g.ramp(g.math("SUBTRACT", 1.0, dot.outputs["Value"]), 0.01, 0.12)
    ao_node = g.node("ShaderNodeAmbientOcclusion", samples=16, only_local=False)
    ao_node.inputs["Distance"].default_value = 0.5 * size / 4.0
    ao = ao_node.outputs["AO"]
    cav = g.ramp(g.math("SUBTRACT", 1.0, ao), 0.08, 0.7)

    n_big = g.noise(P, 1.2 * k, 4.0, 0.6)
    n_mid = g.noise(P, 5.0 * k, 3.0, 0.6)
    n_fine = g.noise(P, 26.0 * k, 2.0, 0.5)
    streak = g.noise(g.scaled(P, (7.0 * k, 7.0 * k, 0.5 * k)), 1.0, 2.0, 0.5)

    # plate seams: a world-aligned grid, drawn only across faces it does not run into
    seams = 0.0
    if look.get("panels"):
        spacing = 1.15 * size / 4.0
        width = 0.022 * size / 4.0 / spacing * 2.0
        cell = g.scaled(P, (1.0 / spacing,) * 3)
        off = g.node("ShaderNodeVectorMath", operation="ADD")
        g.put(off.inputs[0], cell)
        off.inputs[1].default_value = (0.37, 0.61, 0.23)
        sep = g.node("ShaderNodeSeparateXYZ")
        g.put(sep.inputs[0], off.outputs[0])
        nabs = g.node("ShaderNodeVectorMath", operation="ABSOLUTE")
        g.put(nabs.inputs[0], geo.outputs["Normal"])
        nsep = g.node("ShaderNodeSeparateXYZ")
        g.put(nsep.inputs[0], nabs.outputs[0])
        for axis in ("X", "Y", "Z"):
            d = g.mul(g.math("ABSOLUTE", g.math("SUBTRACT", g.math("FRACT", sep.outputs[axis]), 0.5)), 2.0)
            line = g.mul(g.ramp(d, 1.0 - width, 1.0 - width * 0.35),
                         g.ramp(g.math("SUBTRACT", 1.0, nsep.outputs[axis]), 0.55, 0.85))
            seams = line if seams == 0.0 else g.math("MAXIMUM", seams, line)
        seams = g.mul(seams, look["panels"])

    # bare-metal wear on edges, broken up so it reads as chips, not an outline
    wear = g.mul(g.ramp(g.add(g.mul(edge, 1.25), g.mul(g.math("SUBTRACT", n_fine, 0.5), 0.9)), 0.42, 0.62),
                 look.get("wear_amt", 1.0))
    grime = g.ramp(g.add(g.mul(cav, 0.9), g.mul(g.math("SUBTRACT", n_big, 0.5), 0.5)), 0.2, 0.85)
    streaks = g.mul(g.ramp(streak, 0.56, 0.72), 0.4)

    base = look["base"]
    varied = g.rgb_mul(g.combine(*base), g.combine(*(g.add(0.8, g.mul(n_mid, 0.4)) for _ in range(3))))
    col = varied
    rough = g.add(look["rough"], g.mul(g.math("SUBTRACT", n_mid, 0.5), 0.2))
    metal = look["metal"]
    if look.get("rust"):
        rust = g.mul(g.ramp(g.add(g.mul(cav, 0.7), g.mul(n_big, 0.8)), 0.72, 0.9), look["rust"])
        rust_col = g.mix(g.combine(0.16, 0.055, 0.02), g.combine(0.30, 0.12, 0.04), n_fine)
        col = g.mix(col, rust_col, rust)
        rough = g.mix(rough, 0.85, rust, "FLOAT")
        metal = g.mix(metal, 0.2, rust, "FLOAT")
    if look.get("tarnish"):
        tar = g.mul(g.ramp(g.add(cav, g.mul(g.math("SUBTRACT", n_big, 0.5), 0.6)), 0.25, 0.8), look["tarnish"])
        col = g.mix(col, g.combine(base[0] * 0.35, base[1] * 0.3, base[2] * 0.25), tar)
        rough = g.mix(rough, 0.6, tar, "FLOAT")
    if look.get("patina"):
        pat = g.mul(g.ramp(g.add(cav, g.mul(g.math("SUBTRACT", n_big, 0.5), 0.7)), 0.4, 0.85), look["patina"])
        col = g.mix(col, g.combine(0.10, 0.24, 0.19), pat)
        rough = g.mix(rough, 0.75, pat, "FLOAT")
        metal = g.mix(metal, 0.3, pat, "FLOAT")

    paint = 0.0
    if look.get("paint"):
        # painted panels with chipped edges and scuffs, showing the metal (and its wear) beneath
        chips = look.get("chips", 1.0)
        scuff = g.ramp(n_fine, 0.66, 0.74)
        lost = g.add(g.ramp(g.add(g.mul(edge, 1.4), g.mul(g.math("SUBTRACT", n_mid, 0.5), 0.9)), 0.3, 0.45),
                     g.mul(scuff, 0.7), clamp=True)
        paint = g.mul(g.math("SUBTRACT", 1.0, g.mul(lost, chips)), look["paint"], clamp=True)
        pg = PAINT_GREY
        pg_lin = ((pg + 0.055) / 1.055) ** 2.4
        # mottled, sun-faded paint
        shade = g.add(g.add(0.72, g.mul(n_mid, 0.35)), g.mul(g.ramp(n_big, 0.5, 0.75), 0.25))
        paint_col = g.combine(*(g.mul(shade, pg_lin) for _ in range(3)))
        col = g.mix(col, paint_col, paint)
        rough = g.mix(rough, g.add(0.5, g.mul(n_fine, 0.15)), paint, "FLOAT")
        metal = g.mix(metal, 0.08, paint, "FLOAT")

    wear_col = g.combine(*look["wear"])
    col = g.mix(col, wear_col, g.mul(wear, g.math("SUBTRACT", 1.0, paint) if paint else 1.0))
    rough = g.mix(rough, 0.25, wear, "FLOAT")
    metal = g.mix(metal, 1.0, g.mul(wear, 0.8), "FLOAT") if look["metal"] > 0.5 else metal
    # soot and oil gather in cavities and run down the plates
    col = g.mix(col, g.rgb_mul(col, g.combine(0.25, 0.23, 0.21)), g.mul(grime, 0.75))
    col = g.mix(col, g.rgb_mul(col, g.combine(0.45, 0.42, 0.38)), streaks)
    rough = g.mix(rough, 0.8, g.mul(grime, 0.6), "FLOAT")
    if seams != 0.0:
        col = g.mix(col, g.rgb_mul(col, g.combine(0.3, 0.3, 0.3)), g.mul(seams, 0.85))
        rough = g.mix(rough, 0.75, seams, "FLOAT")

    passes = {
        "albedo": col,
        "orm": g.combine(g.mul(g.add(0.25, g.mul(ao, 0.75)), g.math("SUBTRACT", 1.0, g.mul(seams, 0.5)) if seams != 0.0 else 1.0),
                         rough, metal),
        "mask": g.combine(paint, 0.0, 0.0),
    }
    # shading normal: rounded bevels plus a faint hammered grain
    bump = g.node("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.12
    bump.inputs["Distance"].default_value = 0.02
    height = g.add(g.mul(n_fine, 0.6), g.mul(n_mid, 0.4))
    if seams != 0.0:
        height = g.math("SUBTRACT", height, g.mul(seams, 1.5))
    g.put(bump.inputs["Height"], height)
    g.put(bump.inputs["Normal"], bevel.outputs["Normal"])
    bsdf = g.node("ShaderNodeBsdfPrincipled")
    g.put(bsdf.inputs["Normal"], bump.outputs["Normal"])
    passes["normal"] = bsdf
    return passes, img, emit, out


def unwrap(objects, margin=0.004):
    """One shared atlas for all parts: smart projection in multi-object edit mode, then a tight pack."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
        if not o.data.uv_layers:
            o.data.uv_layers.new(name="UVMap")
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(55.0), island_margin=margin, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(objects, name, out_dir, res, size):
    """Bake the four maps for `objects` (meshes with gearforge_<key> slots) into out_dir. The colour
    map gets the full `res`; the others need less detail and are kept small for the web build."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.bake.margin = 6
    scene.render.bake.use_clear = True
    unwrap(objects)

    mats = {}
    for o in objects:
        for s in o.material_slots:
            m = s.material
            if m and m.name not in mats:
                key = m.name.split("gearforge_", 1)[-1].split(".")[0]
                mats[m.name] = (m, build_bake_material(m, key, size))

    os.makedirs(out_dir, exist_ok=True)
    paths = {}
    for pas in ("albedo", "orm", "mask", "normal"):
        r = {"albedo": res, "mask": min(res, 512)}.get(pas, min(res, 1024))
        img = bpy.data.images.new(f"{name}_{pas}", r, r, alpha=False, float_buffer=False)
        img.colorspace_settings.name = "sRGB" if pas == "albedo" else "Non-Color"
        if pas == "normal":
            img.generated_color = (0.5, 0.5, 1.0, 1.0)
        for m, (passes, img_node, emit, out) in mats.values():
            img_node.image = img
            nt = m.node_tree
            if pas == "normal":
                nt.links.new(passes["normal"].outputs[0], out.inputs["Surface"])
            else:
                nt.links.new(passes[pas], emit.inputs["Color"])
                nt.links.new(emit.outputs[0], out.inputs["Surface"])
        bpy.ops.object.select_all(action="DESELECT")
        for o in objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if pas == "normal":
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
        else:
            bpy.ops.object.bake(type="EMIT")
        path = os.path.join(out_dir, f"{name}_{pas}.png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        paths[pas] = path
        print("[bake] %s %dpx" % (os.path.basename(path), r), flush=True)
    return paths

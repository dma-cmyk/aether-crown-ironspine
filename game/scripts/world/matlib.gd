class_name MatLib
extends RefCounted
## Material library. Blender exports placeholder materials with semantic names;
## these are swapped for textured / team-coloured Godot materials here.

const TEX_DIR := "res://assets/textures/"

## name -> spec. "tex" refers to <tex>_albedo/_normal/_orm.png in TEX_DIR.
const SPECS := {
	"stone": {"tex": "stone", "tint": Color(0.60, 0.62, 0.68), "scale": 0.42, "rough": 0.9},
	"stone_dark": {"tex": "stone", "tint": Color(0.42, 0.43, 0.48), "scale": 0.42, "rough": 0.9},
	"stone_trim": {"tex": "stone", "tint": Color(0.82, 0.8, 0.78), "scale": 0.55, "rough": 0.85},
	"paving": {"tex": "terrain_rock", "tint": Color(1.35, 1.3, 1.24), "scale": 0.3, "rough": 0.9},
	"roof": {"tex": "roof", "tint": Color(0.42, 0.47, 0.58), "scale": 0.55, "rough": 0.6},
	"roof_copper": {"tex": "roof", "tint": Color(0.40, 0.66, 0.60), "scale": 0.55, "rough": 0.5, "metal": 0.45},
	"iron": {"tex": "metal", "tint": Color(0.36, 0.38, 0.42), "scale": 0.7, "rough": 0.5, "metal": 0.85},
	"iron_dark": {"tex": "metal", "tint": Color(0.17, 0.18, 0.2), "scale": 0.7, "rough": 0.55, "metal": 0.8},
	"brass": {"tex": "metal", "tint": Color(0.95, 0.70, 0.36), "scale": 0.9, "rough": 0.34, "metal": 1.0},
	"copper": {"tex": "metal", "tint": Color(0.86, 0.48, 0.30), "scale": 0.9, "rough": 0.4, "metal": 1.0},
	"wood": {"tex": "wood", "tint": Color(0.75, 0.62, 0.52), "scale": 0.5, "rough": 0.85},
	"plaster": {"tex": "plaster", "tint": Color(0.86, 0.80, 0.70), "scale": 0.45, "rough": 0.92},
	"rock": {"tex": "rock", "tint": Color(0.78, 0.76, 0.74), "scale": 0.3, "rough": 0.92},
	"bark": {"color": Color(0.23, 0.17, 0.12), "rough": 0.95},
	"canvas": {"color": Color(0.58, 0.55, 0.49), "rough": 0.85},
	"foliage": {"color": Color(0.12, 0.2, 0.11), "rough": 0.9, "instance_tint": true},
	"skin": {"color": Color(0.74, 0.56, 0.45), "rough": 0.7},
	"leather": {"color": Color(0.24, 0.16, 0.11), "rough": 0.75},
	"rubber": {"color": Color(0.05, 0.05, 0.055), "rough": 0.9},
	"glass": {"color": Color(0.12, 0.16, 0.2), "rough": 0.08, "metal": 0.4},
	"team_cloth": {"team": "cloth", "rough": 0.8},
	"team_trim": {"team": "trim", "rough": 0.4, "metal": 0.6},
	"team_glow": {"team": "glow", "emit": 5.0},
	"aether": {"emit_color": Color(0.35, 0.85, 1.0), "emit": 6.0},
	"crystal": {"emit_color": Color(0.35, 0.85, 1.0), "emit": 3.0, "rough": 0.1},
	"window_glow": {"emit_color": Color(1.0, 0.63, 0.32), "emit": 2.4},
	"lamp_glow": {"emit_color": Color(1.0, 0.72, 0.42), "emit": 5.0},
	"fire_glow": {"emit_color": Color(1.0, 0.42, 0.12), "emit": 7.0},
}

static var _cache := {}
static var _tex_cache := {}


static func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var path := TEX_DIR + name + ".png"
		_tex_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[name]


static func get_mat(name: String, team: int = -1, world_space: bool = true) -> Material:
	var base := name.get_slice(".", 0)
	if base == "infantry":
		return infantry_material(team)
	if not SPECS.has(base):
		return null
	var key := "%s|%d|%s" % [base, team, world_space]
	if not _cache.has(key):
		_cache[key] = _build(base, team, world_space)
	return _cache[key]


static func _build(name: String, team: int, world_space: bool) -> Material:
	var s: Dictionary = SPECS[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.roughness = s.get("rough", 0.7)
	m.metallic = s.get("metal", 0.0)
	if s.has("tex"):
		var albedo := tex(s["tex"] + "_albedo")
		m.albedo_color = s["tint"]
		if albedo:
			m.albedo_texture = albedo
			var nrm := tex(s["tex"] + "_normal")
			if nrm:
				m.normal_enabled = true
				m.normal_texture = nrm
				m.normal_scale = 0.9
			var orm := tex(s["tex"] + "_orm")
			if orm:
				m.roughness_texture = orm
				m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				m.roughness = s.get("rough", 0.7) + 0.2
				m.ao_enabled = true
				m.ao_texture = orm
				m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				m.ao_light_affect = 0.35
			m.uv1_triplanar = true
			m.uv1_world_triplanar = world_space
			var sc: float = s.get("scale", 0.5)
			m.uv1_scale = Vector3(sc, sc, sc)
			m.uv1_triplanar_sharpness = 4.0
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	elif s.has("team"):
		var f: Dictionary = Defs.FACTIONS.get(team, Defs.FACTIONS[-1])
		match s["team"]:
			"cloth":
				m.albedo_color = f["cloth"]
			"trim":
				m.albedo_color = (f["cloth"] as Color).lerp(Color(0.8, 0.8, 0.85), 0.25)
			"glow":
				m.albedo_color = f["glow"]
				m.emission_enabled = true
				m.emission = f["glow"]
				m.emission_energy_multiplier = s.get("emit", 4.0)
	elif s.has("emit_color"):
		m.albedo_color = s["emit_color"]
		m.emission_enabled = true
		m.emission = s["emit_color"]
		m.emission_energy_multiplier = s.get("emit", 3.0)
	else:
		m.albedo_color = s.get("color", Color(0.7, 0.7, 0.7))
	if s.get("instance_tint", false):
		m.vertex_color_use_as_albedo = true
	return m


## Replace imported placeholder materials under `root`.
static func remap(root: Node, team: int = -1, world_space: bool = true) -> void:
	var nodes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.append(root)
	for mi: MeshInstance3D in nodes:
		var mesh := mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			if src == null:
				continue
			var m := get_mat(src.resource_name, team, world_space)
			if m:
				mi.set_surface_override_material(i, m)


## Bake library materials into a mesh (for MultiMesh use). Returns a copy.
static func remapped_mesh(mesh: Mesh, team: int = -1, world_space: bool = true) -> Mesh:
	var copy: Mesh = mesh.duplicate()
	for i in copy.get_surface_count():
		var src := copy.surface_get_material(i)
		if src == null:
			continue
		var m := get_mat(src.resource_name, team, world_space)
		if m:
			copy.surface_set_material(i, m)
	return copy


static func noise_texture(size: int, freq: float, seed_value: int, normal: bool = false, fractal_octaves: int = 4) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.seed = seed_value
	n.fractal_octaves = fractal_octaves
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	t.generate_mipmaps = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	return t


static func infantry_material(team: int) -> ShaderMaterial:
	var key := "infantry|%d" % team
	if not _cache.has(key):
		var f: Dictionary = Defs.FACTIONS.get(team, Defs.FACTIONS[-1])
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/infantry.gdshader")
		m.set_shader_parameter("team_color", f["cloth"])
		m.set_shader_parameter("glow_color", f["glow"])
		_cache[key] = m
	return _cache[key]

class_name Terrain
extends Node3D
## Battlefield terrain: Blender-built meshes + heightfield queries + scatter.

const MAP_JSON := "res://data/map_ironspine.json"
const DIR := "res://assets/terrain/"
const MODEL_DIR := "res://assets/models/"

var layout: Dictionary
var placements: Dictionary
var size := 400.0
var grid := 321
var heights := PackedFloat32Array()
var bridges: Array[Dictionary] = []
var terrain_material: ShaderMaterial
var water_material: ShaderMaterial
var fall_material: ShaderMaterial
var fog_texture: ImageTexture
var scatter_root: Node3D


func build(with_scatter: bool = true) -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(MAP_JSON))
	placements = JSON.parse_string(FileAccess.get_file_as_string(DIR + "placements.json"))
	size = float(layout["size"])
	grid = int(layout["height_grid"])
	heights = FileAccess.get_file_as_bytes(DIR + "height.bin").to_float32_array()
	for b in placements["bridges"]:
		var a := Vector2(b["a"][0], b["a"][1])
		var c := Vector2(b["b"][0], b["b"][1])
		var u := (c - a).normalized()
		bridges.append({"id": b["id"], "a": a, "b": c, "u": u, "n": Vector2(-u.y, u.x),
				"length": a.distance_to(c), "width": float(b["width"]), "deck": float(b["deck"])})
	_build_materials()
	var scene: PackedScene = load(DIR + "terrain.glb")
	var root := scene.instantiate()
	root.name = "TerrainMesh"
	add_child(root)
	_apply_materials(root)
	scatter_root = Node3D.new()
	scatter_root.name = "Scatter"
	add_child(scatter_root)
	if with_scatter:
		_spawn_scatter()
		_spawn_mist()


# ------------------------------------------------------------------ queries
func height_at(x: float, z: float) -> float:
	var fx := clampf((x + size * 0.5) / size * (grid - 1), 0.0, grid - 1.001)
	var fz := clampf((z + size * 0.5) / size * (grid - 1), 0.0, grid - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * grid + ix
	var a := lerpf(heights[i], heights[i + 1], tx)
	var b := lerpf(heights[i + grid], heights[i + grid + 1], tx)
	return lerpf(a, b, tz)


## Walkable ground height (bridge decks included).
func ground_at(x: float, z: float) -> float:
	var h := height_at(x, z)
	for b in bridges:
		var rel := Vector2(x, z) - (b["a"] as Vector2)
		var along := rel.dot(b["u"])
		if along > -5.0 and along < float(b["length"]) + 5.0 and absf(rel.dot(b["n"])) < float(b["width"]) * 0.5 + 0.5:
			h = maxf(h, b["deck"])
	return h


func ground_pos(p: Vector3) -> Vector3:
	return Vector3(p.x, ground_at(p.x, p.z), p.z)


func normal_at(x: float, z: float) -> Vector3:
	var e := 1.2
	var hx := height_at(x + e, z) - height_at(x - e, z)
	var hz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


func in_bounds(x: float, z: float, margin: float = 0.0) -> bool:
	var h := size * 0.5 - margin
	return absf(x) < h and absf(z) < h


## Ray vs terrain (and bridge decks). Returns Vector3.INF on miss.
func raycast(origin: Vector3, dir: Vector3, max_dist: float = 3000.0) -> Vector3:
	var t := 0.0
	var prev_t := 0.0
	dir = dir.normalized()
	while t < max_dist:
		var p := origin + dir * t
		var g := ground_at(p.x, p.z)
		if p.y <= g:
			var lo := prev_t
			var hi := t
			for i in 12:
				var mid := (lo + hi) * 0.5
				var q := origin + dir * mid
				if q.y <= ground_at(q.x, q.z):
					hi = mid
				else:
					lo = mid
			var hit := origin + dir * hi
			return Vector3(hit.x, ground_at(hit.x, hit.z), hit.z)
		prev_t = t
		t += clampf((p.y - g) * 0.5, 0.4, 25.0)
	return Vector3.INF


# ------------------------------------------------------------------ materials
func _tex(name: String) -> Texture2D:
	return MatLib.tex(name)


func _build_materials() -> void:
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = load("res://shaders/terrain.gdshader")
	terrain_material.set_shader_parameter("splat_map", load(DIR + "splat.png"))
	terrain_material.set_shader_parameter("macro_noise", MatLib.noise_texture(256, 0.02, 11))
	terrain_material.set_shader_parameter("map_size", size)
	for layer in ["grass", "dirt", "rock", "cliff"]:
		var al := _tex("terrain_%s_albedo" % layer)
		var nm := _tex("terrain_%s_normal" % layer)
		if al:
			terrain_material.set_shader_parameter(layer + "_albedo", al)
		if nm:
			terrain_material.set_shader_parameter(layer + "_normal", nm)
	fog_texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_L8))
	var white := Image.create(4, 4, false, Image.FORMAT_L8)
	white.fill(Color.WHITE)
	fog_texture.update(white)
	terrain_material.set_shader_parameter("fog_map", fog_texture)

	var foam := MatLib.noise_texture(256, 0.03, 5)
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://shaders/water.gdshader")
	water_material.set_shader_parameter("wave_a", MatLib.noise_texture(256, 0.035, 21, true, 3))
	water_material.set_shader_parameter("wave_b", MatLib.noise_texture(256, 0.02, 33, true, 4))
	water_material.set_shader_parameter("foam_noise", foam)

	fall_material = ShaderMaterial.new()
	fall_material.shader = load("res://shaders/waterfall.gdshader")
	fall_material.set_shader_parameter("foam_noise", MatLib.noise_texture(256, 0.045, 8, false, 3))


func _apply_materials(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if n.begins_with("terrain_"):
			mi.material_override = terrain_material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		elif n.begins_with("water_"):
			mi.material_override = water_material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n.begins_with("waterfall_") or n.begins_with("cliff_fall_"):
			mi.material_override = fall_material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			MatLib.remap(mi, -1, true)


# ------------------------------------------------------------------ scatter
func _load_mesh(model: String, team: int = -1) -> Mesh:
	var path := MODEL_DIR + model + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate()
	var found: Array = inst.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = null
	if found.size() > 0:
		mesh = MatLib.remapped_mesh((found[0] as MeshInstance3D).mesh, team, true)
	inst.free()
	return mesh


func _spawn_scatter() -> void:
	# trees + rocks: [x, y, z, scale, rot, variant]
	_multimesh_group("trees", ["tree_pine_a", "tree_pine_b", "tree_pine_c"], placements["trees"], true)
	_multimesh_group("rocks", ["rock_a", "rock_b", "rock_c"], placements["rocks"], false)
	# props: group by model
	var by_model := {}
	for p in placements["props"]:
		var key := "%s|%d" % [p["model"], int(p.get("team", -1))]
		if not by_model.has(key):
			by_model[key] = []
		by_model[key].append([p["pos"][0], p["pos"][1], p["pos"][2], p["scale"], p["rot"], 0])
	for key: String in by_model:
		_multimesh_group("props_" + key.replace("|", "_"), [key.get_slice("|", 0)], by_model[key], false, int(key.get_slice("|", 1)))


## Smoke sources on scattered industrial props (local chimney tops rotated by the prop yaw).
const CHIMNEY_TOPS := {"smokestack": [Vector3(0, 24.4, 0)], "workshop": [Vector3(2.2, 13.2, -4.0)]}
const CHIMNEY_SIZE := {"smokestack": 3.6, "workshop": 2.4}


func register_chimneys(fx: FX) -> void:
	for p in placements["props"]:
		var tops: Array = CHIMNEY_TOPS.get(p["model"], [])
		for local: Vector3 in tops:
			var b := Basis(Vector3.UP, float(p["rot"]))
			var pos := Vector3(p["pos"][0], p["pos"][1], p["pos"][2]) + b * (local * float(p["scale"]))
			var big: float = CHIMNEY_SIZE.get(p["model"], 2.4)
			fx.add_chimney(pos, 1.2 + big * 0.6, big, 0.24)


func _multimesh_group(group_name: String, models: Array, items: Array, tint: bool, team: int = -1) -> void:
	var meshes: Array[Mesh] = []
	for m in models:
		meshes.append(_load_mesh(m, team))
	# bucket by variant and by map quadrant (cheap frustum culling)
	var buckets := {}
	for it in items:
		var v := int(it[5]) % models.size()
		if meshes[v] == null:
			continue
		var q := (1 if float(it[0]) > 0.0 else 0) + (2 if float(it[2]) > 0.0 else 0)
		var key := v * 4 + q
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(it)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(group_name)
	for key in buckets:
		var v: int = key / 4
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = tint
		mm.mesh = meshes[v]
		mm.instance_count = list.size()
		for i in list.size():
			var it: Array = list[i]
			var s := float(it[3])
			var b := Basis(Vector3.UP, float(it[4])).scaled(Vector3(s, s * (rng.randf_range(0.9, 1.15) if tint else 1.0), s))
			mm.set_instance_transform(i, Transform3D(b, Vector3(it[0], it[1], it[2])))
			if tint:
				var c := Color(rng.randf_range(0.8, 1.15), rng.randf_range(0.85, 1.15), rng.randf_range(0.75, 1.05))
				mm.set_instance_color(i, c)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d" % [group_name, key]
		mmi.multimesh = mm
		scatter_root.add_child(mmi)


func _spawn_mist() -> void:
	var tex := _soft_particle_texture()
	for m in placements["mist"]:
		var p := GPUParticles3D.new()
		p.amount = 14
		p.lifetime = 6.0
		p.preprocess = 6.0
		p.visibility_aabb = AABB(Vector3(-25, -5, -25), Vector3(50, 25, 50))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		var r := float(m[3])
		pm.emission_box_extents = Vector3(r, 0.5, r * 0.4)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 25.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.4
		pm.gravity = Vector3(0, 0.15, 0)
		pm.scale_min = 3.5
		pm.scale_max = 6.5
		var curve := CurveTexture.new()
		var c := Curve.new()
		c.add_point(Vector2(0, 0.0))
		c.add_point(Vector2(0.25, 1.0))
		c.add_point(Vector2(1, 0.0))
		curve.curve = c
		pm.alpha_curve = curve
		pm.color = Color(0.9, 0.95, 1.0, 0.28)
		p.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = tex
		mat.proximity_fade_enabled = true
		mat.proximity_fade_distance = 2.0
		quad.material = mat
		p.draw_pass_1 = quad
		p.position = Vector3(m[0], m[1], m[2])
		scatter_root.add_child(p)


static func _soft_particle_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t

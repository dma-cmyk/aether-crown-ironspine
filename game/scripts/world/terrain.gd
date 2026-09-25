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
## Tree index (placements["trees"]) -> [MultiMesh, instance, rest transform, colour], for felling.
var tree_slots := {}
var build_map: ImageTexture


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
	var trees: Array = []
	for i in placements["trees"].size():
		trees.append(placements["trees"][i] + [i])
	_multimesh_group("trees", ["tree_pine_a", "tree_pine_b", "tree_pine_c"], trees, true)
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
	for m in placements["mist"]:
		fx.add_mist(Vector3(m[0], m[1], m[2]), float(m[3]))
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
			var xf := Transform3D(b, Vector3(it[0], it[1], it[2]))
			mm.set_instance_transform(i, xf)
			var c := Color.WHITE
			if tint:
				c = Color(rng.randf_range(0.8, 1.15), rng.randf_range(0.85, 1.15), rng.randf_range(0.75, 1.05))
				mm.set_instance_color(i, c)
			if it.size() > 6:
				tree_slots[int(it[6])] = [mm, i, xf, c]
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d" % [group_name, key]
		mmi.multimesh = mm
		scatter_root.add_child(mmi)


# ------------------------------------------------------------------ felling and building ground
## Tint a tree while a building is placed: 0 its own colour, 1 may be cleared, 2 will be felled.
func mark_tree(i: int, level: int) -> void:
	var slot: Array = tree_slots.get(i, [])
	if slot.is_empty():
		return
	var c: Color = [slot[3], Color(2.1, 1.8, 0.5), Color(5.5, 2.2, 0.3)][level]
	(slot[0] as MultiMesh).set_instance_color(slot[1], c)


## Topple tree `i` toward `away` and sink it into the ground, or hide it at once.
func fell_tree(i: int, away: Vector3, animate: bool) -> void:
	var slot: Array = tree_slots.get(i, [])
	if slot.is_empty():
		return
	var mm: MultiMesh = slot[0]
	var idx: int = slot[1]
	var rest: Transform3D = slot[2]
	mm.set_instance_color(idx, slot[3])
	var gone := Transform3D(Basis().scaled(Vector3.ZERO), rest.origin)
	if not animate or away == Vector3.ZERO:
		mm.set_instance_transform(idx, gone)
		return
	var axis := Vector3.UP.cross(away).normalized()
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		mm.set_instance_transform(idx, Transform3D(Basis(axis, k * k * deg_to_rad(84.0)) * rest.basis, rest.origin)), 0.0, 1.0, 1.4)
	tw.tween_method(func(k: float) -> void:
		var b := Basis(axis, deg_to_rad(84.0)) * rest.basis
		mm.set_instance_transform(idx, Transform3D(b.scaled(Vector3.ONE * (1.0 - k)), rest.origin - Vector3(0, k * 1.5, 0))), 0.0, 1.0, 1.6).set_delay(0.8)
	tw.tween_callback(func() -> void: mm.set_instance_transform(idx, gone))


## Show (or hide with null) the building-ground map drawn over the terrain while placing:
## one pixel per nav cell, alpha 0 outside the ground the player may build on.
func show_build_map(img: Image) -> void:
	if img == null:
		terrain_material.set_shader_parameter("build_strength", 0.0)
		return
	if build_map == null or build_map.get_size() != Vector2(img.get_size()):
		build_map = ImageTexture.create_from_image(img)
		terrain_material.set_shader_parameter("build_map", build_map)
		terrain_material.set_shader_parameter("build_cells", float(img.get_width()))
	else:
		build_map.update(img)
	terrain_material.set_shader_parameter("build_strength", 1.0)


class_name FogOfWar
extends Node3D
## Player visibility grid, enemy concealment and a screen-space fog overlay.

const CELLS := 100
const CELL := 4.0

var world: World
var vis := PackedByteArray()
var explored := PackedByteArray()
var img: Image
var tex: ImageTexture
var overlay: MeshInstance3D
var enabled := true
var _t := 0.0
var _circles := {}
var _pixels := PackedByteArray()


func setup(w: World) -> void:
	world = w
	vis.resize(CELLS * CELLS)
	explored.resize(CELLS * CELLS)
	_pixels.resize(CELLS * CELLS)
	img = Image.create_from_data(CELLS, CELLS, false, Image.FORMAT_L8, _pixels)
	tex = ImageTexture.create_from_image(img)
	overlay = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	overlay.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/fog_overlay.gdshader")
	m.set_shader_parameter("fog_tex", tex)
	m.set_shader_parameter("map_size", 400.0)
	m.render_priority = 100
	overlay.material_override = m
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.extra_cull_margin = 16384.0
	overlay.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(overlay)
	if Game.args.has("nofog"):
		enabled = false


func is_visible_at(p: Vector3) -> bool:
	if not enabled:
		return true
	var c := _cell(p)
	return vis[c.y * CELLS + c.x] != 0


func is_explored_at(p: Vector3) -> bool:
	if not enabled:
		return true
	var c := _cell(p)
	return explored[c.y * CELLS + c.x] != 0


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int((p.x + 200.0) / CELL), 0, CELLS - 1), clampi(int((p.z + 200.0) / CELL), 0, CELLS - 1))


func _circle(r: int) -> PackedInt32Array:
	if not _circles.has(r):
		var out := PackedInt32Array()
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dz * dz <= r * r:
					out.append(dx)
					out.append(dz)
		_circles[r] = out
	return _circles[r]


func _stamp(p: Vector3, radius: float) -> void:
	var c := _cell(p)
	var offs := _circle(int(radius / CELL))
	var i := 0
	while i < offs.size():
		var x := c.x + offs[i]
		var z := c.y + offs[i + 1]
		i += 2
		if x < 0 or z < 0 or x >= CELLS or z >= CELLS:
			continue
		vis[z * CELLS + x] = 1


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.2
	recompute()


func recompute() -> void:
	vis.fill(0)
	for u in world.units:
		if u.team == Defs.TEAM_PLAYER and u.alive:
			_stamp(u.global_position, u.vision)
	for b in world.buildings:
		if b.team == Defs.TEAM_PLAYER and b.alive:
			_stamp(b.global_position, b.vision)
	for s in world.sites:
		if s.owner_team == Defs.TEAM_PLAYER:
			_stamp(s.global_position, s.vision)
	for i in vis.size():
		if vis[i]:
			explored[i] = 1
	for u in world.units:
		if u.team != Defs.TEAM_PLAYER:
			u.seen_by_player = not enabled or is_visible_at(u.global_position)
	for b in world.buildings:
		if b.team != Defs.TEAM_PLAYER and not b.seen_by_player:
			b.seen_by_player = not enabled or is_visible_at(b.global_position)
		elif b.team != Defs.TEAM_PLAYER and b.seen_by_player == false:
			pass
	for i in _pixels.size():
		_pixels[i] = 255 if vis[i] else (150 if explored[i] else 60)
	img.set_data(CELLS, CELLS, false, Image.FORMAT_L8, _pixels)
	tex.update(img)
	overlay.visible = enabled


## Buildings start hidden until spotted.
func hide_enemy_buildings() -> void:
	for b in world.buildings:
		if b.team != Defs.TEAM_PLAYER:
			b.seen_by_player = not enabled

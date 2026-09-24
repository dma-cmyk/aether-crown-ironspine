class_name Minimap
extends Control
## Tactical map rotated to match the camera. Left click/drag pans, right click orders a move.

var world: World
var commander: Commander
var camera: CameraRig
var tex: Texture2D
var fog_tex: ImageTexture
var fog_img: Image
var _fog_t := 0.0
var _pings: Array[Dictionary] = []
var _drag := false
const MAP := 400.0


func setup(w: World, c: Commander, cam: CameraRig) -> void:
	world = w
	commander = c
	camera = cam
	tex = load("res://assets/terrain/minimap.png")
	fog_img = Image.create(FogOfWar.CELLS, FogOfWar.CELLS, false, Image.FORMAT_RGBA8)
	fog_tex = ImageTexture.create_from_image(fog_img)
	mouse_filter = Control.MOUSE_FILTER_STOP
	world.alert.connect(func(p: Vector3, _t: String, team: int): if team == Defs.TEAM_PLAYER and p != Vector3.ZERO: ping(p, UITheme.GOLD))
	world.entity_died.connect(func(e: Entity): if e.team == Defs.TEAM_PLAYER and e.is_building: ping(e.global_position, UITheme.RED))


func ping(p: Vector3, c: Color) -> void:
	_pings.append({"p": p, "t": 0.0, "c": c})


func _scale() -> float:
	return minf(size.x, size.y) / (MAP * 1.414) * 0.98


func world_to_map(p: Vector3) -> Vector2:
	var yaw := camera.yaw
	var sx := p.x * cos(yaw) - p.z * sin(yaw)
	var sy := p.x * sin(yaw) + p.z * cos(yaw)
	return size * 0.5 + Vector2(sx, sy) * _scale()


func map_to_world(m: Vector2) -> Vector3:
	var v := (m - size * 0.5) / _scale()
	var yaw := camera.yaw
	var x := v.x * cos(yaw) + v.y * sin(yaw)
	var z := -v.x * sin(yaw) + v.y * cos(yaw)
	return Vector3(x, 0, z)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and commander.mode == Commander.Mode.STRIKE:
			# the Tower of Judgement can be aimed anywhere on the map
			if commander.strike_at(map_to_world(mb.position)):
				world.sfx.play_ui("confirm")
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if mb.pressed:
				camera.look_at_point(map_to_world(mb.position))
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var p := map_to_world(mb.position)
			var units := commander.own_units()
			if not units.is_empty():
				commander.move_group(units, world.nav.nearest_walkable_pos(p), mb.shift_pressed, false)
				world.sfx.play_ui("confirm")
				ping(p, UITheme.GREEN)
			accept_event()
	elif event is InputEventMouseMotion and _drag:
		camera.look_at_point(map_to_world((event as InputEventMouseMotion).position))
		accept_event()


func _process(delta: float) -> void:
	_fog_t -= delta
	if _fog_t <= 0.0:
		_fog_t = 0.4
		_update_fog()
	for p in _pings:
		p["t"] += delta
	_pings = _pings.filter(func(p): return p["t"] < 2.5)
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 0.066
		queue_redraw()


var _redraw_t := 0.0


func _update_fog() -> void:
	var fog := world.fog
	if not fog.enabled:
		fog_img.fill(Color(0, 0, 0, 0))
	else:
		var data := PackedByteArray()
		data.resize(FogOfWar.CELLS * FogOfWar.CELLS * 4)
		for i in FogOfWar.CELLS * FogOfWar.CELLS:
			var a := 0 if fog.vis[i] else (95 if fog.explored[i] else 200)
			data[i * 4] = 6
			data[i * 4 + 1] = 9
			data[i * 4 + 2] = 14
			data[i * 4 + 3] = a
		fog_img.set_data(FogOfWar.CELLS, FogOfWar.CELLS, false, Image.FORMAT_RGBA8, data)
	fog_tex.update(fog_img)


func _draw() -> void:
	var s := _scale()
	draw_set_transform(size * 0.5, camera.yaw, Vector2(s, s))
	draw_texture_rect(tex, Rect2(-MAP * 0.5, -MAP * 0.5, MAP, MAP), false, Color(0.82, 0.86, 0.92))
	draw_texture_rect(fog_tex, Rect2(-MAP * 0.5, -MAP * 0.5, MAP, MAP), false)
	draw_rect(Rect2(-MAP * 0.5, -MAP * 0.5, MAP, MAP), UITheme.GOLD_DIM, false, 2.0 / s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# sites
	for site in world.sites:
		var p := world_to_map(site.global_position)
		var c := Defs.team_color(site.owner_team) if site.owner_team >= 0 else Color(0.9, 0.85, 0.7)
		var r := 6.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), Color(c, 0.9))
		draw_polyline(PackedVector2Array([p + Vector2(0, -r - 2), p + Vector2(r + 2, 0), p + Vector2(0, r + 2), p + Vector2(-r - 2, 0), p + Vector2(0, -r - 2)]), Color(0, 0, 0, 0.7), 1.5)
		if site.capturing_team >= 0:
			draw_arc(p, r + 5, 0, TAU * site.capture, 20, Defs.team_color(site.capturing_team), 2.0)
	for b in world.buildings:
		if not b.alive or (b.team != Defs.TEAM_PLAYER and not b.seen_by_player):
			continue
		var p2 := world_to_map(b.global_position)
		var sz := clampf(b.radius * s * 1.3, 4.0, 11.0)
		var col := Defs.team_color(b.team)
		draw_rect(Rect2(p2 - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
		draw_rect(Rect2(p2 - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(0, 0, 0, 0.8), false, 1.0)
	for u in world.units:
		if not u.alive or (u.team != Defs.TEAM_PLAYER and not u.seen_by_player):
			continue
		var p3 := world_to_map(u.global_position)
		var col2 := Defs.team_color(u.team).lightened(0.25)
		if u.selected:
			col2 = Color(0.6, 1.0, 0.6)
		var rr := 2.6 if u.type == "squad" else 3.6
		draw_circle(p3, rr + 1.0, Color(0, 0, 0, 0.7))
		draw_circle(p3, rr, col2)
	# camera frustum
	var vp := get_viewport().get_visible_rect().size
	var corners: Array[Vector2] = []
	for c in [Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, vp.y * 0.78), Vector2(0, vp.y * 0.78)]:
		var g := camera.screen_to_ground(c)
		if g == Vector3.INF:
			var cam := camera.cam
			var o := cam.project_ray_origin(c)
			var d := cam.project_ray_normal(c)
			g = o + d * 260.0
		corners.append(world_to_map(g))
	corners.append(corners[0])
	draw_polyline(PackedVector2Array(corners), Color(1, 1, 1, 0.75), 1.5, true)
	for p in _pings:
		var k: float = p["t"] / 2.5
		var pos := world_to_map(p["p"])
		var c3: Color = p["c"]
		draw_arc(pos, 4.0 + 18.0 * fmod(k * 2.0, 1.0), 0, TAU, 24, Color(c3, 1.0 - k), 2.0)
	# compass (north = -Z)
	var n_dir := world_to_map(Vector3(0, 0, -150)) - size * 0.5
	var np := size * 0.5 + n_dir.normalized() * (minf(size.x, size.y) * 0.5 - 12.0)
	draw_circle(np, 11, Color(0.05, 0.06, 0.08, 0.9))
	draw_arc(np, 11, 0, TAU, 20, UITheme.GOLD, 1.5)
	draw_string(UITheme.title_font(), np + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.IVORY)



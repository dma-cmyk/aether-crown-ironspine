class_name Commander
extends Node
## Player input: selection, orders, hotkeys, control groups, targeting and building placement.

signal selection_changed
signal mode_changed(mode: String)
signal order_issued(kind: String, pos: Vector3)

enum Mode { NONE, MOVE, ATTACK, PATROL, REPAIR, SPECIAL, PLACE, RALLY, STRIKE }

var world: World
var camera: CameraRig
var selection: Array[Entity] = []
var groups := {}
var mode := Mode.NONE
var place_id := ""
var ghost: Node3D
var ghost_valid := false
var drag_start := Vector2.ZERO
var dragging := false
var drag_rect := Rect2()
var hover: Entity
var enabled := true
var _last_click_time := 0.0
var _last_click_entity: Entity
var _last_group_key := -1
var _last_group_time := 0.0
var hud: Control
## The Tower of Judgement waiting for a target (Mode.STRIKE).
var strike_from: Building


func setup(w: World, cam: CameraRig) -> void:
	world = w
	camera = cam
	world.entity_died.connect(_on_entity_died)


func _on_entity_died(e: Entity) -> void:
	if e in selection:
		selection.erase(e)
		selection_changed.emit()
	for k in groups:
		(groups[k] as Array).erase(e)


# ---------------------------------------------------------------- helpers
func own_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for e in selection:
		if e is Unit and e.team == Defs.TEAM_PLAYER and e.alive:
			out.append(e)
	return out


func selected_building() -> Building:
	if selection.size() == 1 and selection[0] is Building and selection[0].team == Defs.TEAM_PLAYER:
		return selection[0]
	return null


func set_selection(list: Array, add: bool = false) -> void:
	if not add:
		for e in selection:
			if is_instance_valid(e):
				e.set_selected(false)
		selection.clear()
	for e in list:
		if is_instance_valid(e) and e.alive and not e in selection:
			selection.append(e)
			e.set_selected(true)
	selection_changed.emit()


func pick(screen: Vector2) -> Entity:
	var cam := camera.cam
	var best: Entity = null
	var best_d := INF
	for list in [world.units, world.buildings]:
		for e: Entity in list:
			if not e.alive or (e.team != Defs.TEAM_PLAYER and not e.seen_by_player):
				continue
			var p := e.aim_point()
			if cam.is_position_behind(p):
				continue
			var sp := cam.unproject_position(p)
			var depth := cam.global_position.distance_to(p)
			var r_px := e.radius * 1.1 / maxf(depth, 1.0) * get_viewport().get_visible_rect().size.y / (2.0 * tan(deg_to_rad(cam.fov * 0.5)))
			r_px = maxf(r_px, 14.0)
			var d := sp.distance_to(screen)
			if d < r_px:
				var score := d / r_px + (0.5 if e.is_building else 0.0)
				if score < best_d:
					best_d = score
					best = e
	return best


func ground_at_mouse(screen: Vector2) -> Vector3:
	return camera.screen_to_ground(screen)


func _ui_hovered() -> bool:
	var c := get_viewport().gui_get_hovered_control()
	return c != null and c.mouse_filter != Control.MOUSE_FILTER_IGNORE


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if not enabled or world.game_over:
		return
	# fingers are read by TouchControls; the mouse clicks Godot makes from them only work the HUD
	if Game.from_touch(event):
		return
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion:
		if dragging:
			var cur := (event as InputEventMouseMotion).position
			drag_rect = Rect2(drag_start, cur - drag_start).abs()
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if mode != Mode.NONE:
				_confirm_mode(mb.position, mb.shift_pressed)
				get_viewport().set_input_as_handled()
				return
			dragging = true
			drag_start = mb.position
			drag_rect = Rect2(mb.position, Vector2.ZERO)
		elif dragging:
			dragging = false
			if drag_rect.size.length() > 8.0:
				_box_select(drag_rect, mb.shift_pressed)
			else:
				_click_select(mb.position, mb.shift_pressed, mb.double_click)
			drag_rect = Rect2()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if mode != Mode.NONE:
			cancel_mode()
			return
		_smart_order(mb.position, mb.shift_pressed)


# ---------------------------------------------------------------- touch (TouchControls)
## A tap selects our units and buildings. With units (or a producing building) of ours selected,
## it gives the order a right click would; otherwise it selects what is there or clears.
func touch_tap(pos: Vector2) -> void:
	if mode == Mode.PLACE:
		_touch_place(pos)
		return
	if mode != Mode.NONE:
		_confirm_mode(pos, false)
		return
	var e := pick(pos)
	var b := selected_building()
	var commandable := not own_units().is_empty() or (b != null and not b.produces().is_empty())
	if e and e.team == Defs.TEAM_PLAYER and not (commandable and _wants_repair(e)):
		_click_select(pos, false, false)
	elif commandable:
		_smart_order(pos, false)
	else:
		_click_select(pos, false, false)


## Hold, then lift without moving: select whatever is there (enemies too), or clear the selection.
func touch_pick(pos: Vector2) -> void:
	_click_select(pos, false, false)


func touch_box(rect: Rect2) -> void:
	_box_select(rect, false)


func _wants_repair(e: Entity) -> bool:
	return e.is_building and e.hp < e.max_hp and not e in selection \
			and own_units().any(func(u: Unit) -> bool: return u.def.get("repair_rate", 0.0) > 0.0)


## The first tap sets the ghost down, a tap on the ghost builds it, a tap elsewhere moves it.
func _touch_place(pos: Vector2) -> void:
	var g := ground_at_mouse(pos)
	if g == Vector3.INF:
		return
	if ghost and ghost.visible and Vector2(g.x - ghost.global_position.x, g.z - ghost.global_position.z).length() < float(Defs.BUILDINGS[place_id]["radius"]) + 2.0:
		if ghost_valid:
			_place_building(ghost.global_position)
			world.sfx.play_ui("confirm")
			set_mode(Mode.NONE)
		else:
			world.sfx.play_ui("error")
		return
	place_at(g)
	world.sfx.play_ui("click")


func place_at(g: Vector3) -> void:
	if ghost == null:
		return
	ghost.visible = true
	ghost.global_position = g
	var to_cam := camera.cam.global_position - g
	ghost.rotation.y = snappedf(atan2(to_cam.x, to_cam.z), PI / 4.0)
	var v := placement_valid(place_id, g)
	if v != ghost_valid:
		ghost_valid = v
		_ghost_material(ghost, v)


func _click_select(pos: Vector2, add: bool, dbl: bool) -> void:
	var e := pick(pos)
	var now := Time.get_ticks_msec() * 0.001
	if e == null:
		if not add:
			set_selection([])
		return
	if (dbl or (now - _last_click_time < 0.35 and _last_click_entity == e)) and e is Unit and e.team == Defs.TEAM_PLAYER:
		var same := []
		for u in world.units:
			if u.team == Defs.TEAM_PLAYER and u.alive and u.def_id == e.def_id and _on_screen(u.global_position):
				same.append(u)
		set_selection(same, add)
	elif add and e in selection:
		e.set_selected(false)
		selection.erase(e)
		selection_changed.emit()
	elif add and e.team == Defs.TEAM_PLAYER and e is Unit:
		set_selection([e], true)
	else:
		set_selection([e])
	_last_click_time = now
	_last_click_entity = e
	world.sfx.play_ui("click")


func _on_screen(p: Vector3) -> bool:
	var cam := camera.cam
	if cam.is_position_behind(p):
		return false
	return get_viewport().get_visible_rect().has_point(cam.unproject_position(p))


func _box_select(rect: Rect2, add: bool) -> void:
	var cam := camera.cam
	var picked := []
	for u in world.units:
		if u.team != Defs.TEAM_PLAYER or not u.alive:
			continue
		var p := u.global_position + Vector3(0, 1.0, 0)
		if cam.is_position_behind(p):
			continue
		if rect.has_point(cam.unproject_position(p)):
			picked.append(u)
	if picked.is_empty():
		for b in world.buildings:
			if b.team == Defs.TEAM_PLAYER and b.alive and not cam.is_position_behind(b.global_position) and rect.has_point(cam.unproject_position(b.global_position)):
				picked.append(b)
				break
	set_selection(picked, add)
	if not picked.is_empty():
		world.sfx.play_ui("click")


func _smart_order(pos: Vector2, queued: bool) -> void:
	var b := selected_building()
	var units := own_units()
	var ground := ground_at_mouse(pos)
	if b and units.is_empty():
		if ground != Vector3.INF and not b.produces().is_empty():
			b.rally = ground
			world.fx.ring_burst(ground + Vector3(0, 0.4, 0), 3.0, Color(0.5, 1.0, 0.6))
			world.sfx.play_ui("confirm")
		return
	if units.is_empty():
		return
	var e := pick(pos)
	if e and e.team != Defs.TEAM_PLAYER and e.team != Defs.TEAM_NEUTRAL:
		for u in units:
			u.order_attack(e)
		world.fx.ring_burst(e.global_position + Vector3(0, 0.4, 0), e.radius + 1.0, Color(1.0, 0.35, 0.3))
		world.sfx.play_ui("confirm")
		order_issued.emit("attack", e.global_position)
		return
	if e and e.team == Defs.TEAM_PLAYER and (e.is_building or e.is_mechanical) and e.hp < e.max_hp:
		var any := false
		for u in units:
			if u.def.get("repair_rate", 0.0) > 0.0:
				u.order_repair(e)
				any = true
		if any:
			world.sfx.play_ui("confirm")
			return
	if ground == Vector3.INF:
		return
	move_group(units, ground, queued, false)
	world.fx.ring_burst(ground + Vector3(0, 0.4, 0), 2.5, Color(0.5, 1.0, 0.6))
	world.sfx.play_ui("confirm")
	order_issued.emit("move", ground)


func move_group(units: Array, target: Vector3, queued: bool, attack: bool, patrol: bool = false) -> void:
	if units.is_empty():
		return
	var centroid := Vector3.ZERO
	var max_r := 1.0
	for u: Unit in units:
		centroid += u.global_position
		max_r = maxf(max_r, u.radius)
	centroid /= units.size()
	var fwd := Vector3(target.x - centroid.x, 0, target.z - centroid.z)
	if fwd.length() < 0.5:
		fwd = camera.forward_dir()
	fwd = fwd.normalized()
	var right := Vector3(fwd.z, 0, -fwd.x)
	var n := units.size()
	var cols := int(ceil(sqrt(n * 1.8)))
	var spacing := max_r * 2.2 + 1.5
	var slots: Array[Vector3] = []
	for i in n:
		var row := i / cols
		var col := i % cols
		var in_row := mini(cols, n - row * cols)
		var x := (col - (in_row - 1) * 0.5) * spacing
		slots.append(target + right * x - fwd * row * spacing)
	var sorted := units.duplicate()
	sorted.sort_custom(func(a, b): return (a.global_position - centroid).dot(right) < (b.global_position - centroid).dot(right))
	var by_row := []
	for i in n:
		by_row.append(sorted[i])
	# assign front row to units nearest the target
	var order_list := by_row.duplicate()
	order_list.sort_custom(func(a, b): return a.global_position.distance_to(target) < b.global_position.distance_to(target))
	var assigned := {}
	for r in range(0, n, cols):
		var chunk := order_list.slice(r, mini(r + cols, n))
		chunk.sort_custom(func(a, b): return (a.global_position - centroid).dot(right) < (b.global_position - centroid).dot(right))
		for k in chunk.size():
			assigned[chunk[k]] = slots[r + k]
	for u: Unit in units:
		var p: Vector3 = assigned[u]
		if not u.is_air:
			p = world.nav.nearest_walkable_pos(p)
		if patrol:
			u.order_patrol(p)
		elif attack:
			u.order_attack_move(p)
		else:
			u.order_move(p, queued)


func _key(ev: InputEventKey) -> void:
	var k := ev.physical_keycode
	if k >= KEY_0 and k <= KEY_9:
		var idx := k - KEY_0
		if ev.ctrl_pressed:
			groups[idx] = selection.duplicate()
			world.sfx.play_ui("confirm")
		else:
			var list: Array = groups.get(idx, [])
			var alive := list.filter(func(e): return is_instance_valid(e) and e.alive)
			if alive.is_empty():
				return
			var now := Time.get_ticks_msec() * 0.001
			if _last_group_key == idx and now - _last_group_time < 0.4:
				camera.look_at_point(alive[0].global_position)
			set_selection(alive, ev.shift_pressed)
			_last_group_key = idx
			_last_group_time = now
		return
	if k == KEY_ESCAPE and mode != Mode.NONE:
		cancel_mode()
		get_viewport().set_input_as_handled()
		return
	var b := selected_building()
	if b and own_units().is_empty():
		_building_key(b, ev)
		return
	match k:
		KEY_M:
			command("move")
		KEY_H:
			command("hold")
		KEY_A:
			command("attack")
		KEY_P:
			command("patrol")
		KEY_F:
			command("fortify")
		KEY_R:
			command("repair")
		KEY_D:
			command("deploy")
		KEY_S:
			command("special")
		KEY_TAB:
			pass


func _building_key(b: Building, ev: InputEventKey) -> void:
	var keys := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U]
	var i := keys.find(ev.physical_keycode)
	if i < 0:
		return
	if b.def_id == "citadel" and ev.shift_pressed == false and hud and hud.has_method("citadel_build_mode") and hud.citadel_build_mode():
		hud.build_key(i)
		return
	if b.def.has("superweapon"):
		if i == 0:
			begin_strike(b)
		return
	var prods: Array = b.produces()
	if i < prods.size():
		queue(b, prods[i])


func queue(b: Building, uid: String) -> void:
	var why := b.can_queue(uid)
	if why == "":
		b.queue_unit(uid)
		world.sfx.play_ui("click")
	else:
		world.sfx.play_ui("error")
		world.raise_alert(b.global_position, why, Defs.TEAM_PLAYER, "q_err", 1.0)


## Command card entry point (buttons and hotkeys).
func command(cmd: String) -> void:
	var units := own_units()
	if units.is_empty():
		return
	match cmd:
		"move":
			set_mode(Mode.MOVE)
		"attack":
			set_mode(Mode.ATTACK)
		"patrol":
			set_mode(Mode.PATROL)
		"hold":
			for u in units:
				u.order_hold()
			world.sfx.play_ui("confirm")
		"fortify":
			for u in units:
				u.toggle_fortify()
			world.sfx.play_ui("confirm")
		"deploy":
			for u in units:
				u.toggle_deploy()
			world.sfx.play_ui("confirm")
		"repair":
			if units.any(func(u): return u.def.get("repair_rate", 0.0) > 0.0):
				set_mode(Mode.REPAIR)
		"special":
			var targeted := false
			for u in units:
				var sid: String = u.def.get("special", "")
				if sid != "" and Defs.SPECIALS[sid].get("targeted", false) and u.special_ready():
					targeted = true
			if targeted:
				set_mode(Mode.SPECIAL)
			else:
				var used := false
				for u in units:
					if u.special_ready():
						used = u.use_special() or used
				world.sfx.play_ui("confirm" if used else "error")


func command_available(cmd: String) -> bool:
	for u in own_units():
		if cmd in u.def["commands"]:
			if cmd == "special":
				return u.def.get("special", "") != ""
			return true
	return false


func set_mode(m: Mode) -> void:
	mode = m
	mode_changed.emit(Mode.keys()[m])
	if m != Mode.PLACE and ghost:
		ghost.queue_free()
		ghost = null
	if m != Mode.PLACE:
		_hide_territory()


func cancel_mode() -> void:
	set_mode(Mode.NONE)


func _confirm_mode(pos: Vector2, shift: bool) -> void:
	var ground := ground_at_mouse(pos)
	var units := own_units()
	match mode:
		Mode.MOVE:
			if ground != Vector3.INF:
				move_group(units, ground, shift, false)
		Mode.ATTACK:
			var e := pick(pos)
			if e and e.team != Defs.TEAM_PLAYER and e.team >= 0:
				for u in units:
					u.order_attack(e)
			elif ground != Vector3.INF:
				move_group(units, ground, false, true)
				world.fx.ring_burst(ground + Vector3(0, 0.4, 0), 3.0, Color(1.0, 0.4, 0.3))
		Mode.PATROL:
			if ground != Vector3.INF:
				move_group(units, ground, false, false, true)
		Mode.REPAIR:
			var e2 := pick(pos)
			if e2 and e2.team == Defs.TEAM_PLAYER:
				for u in units:
					u.order_repair(e2)
		Mode.SPECIAL:
			if ground != Vector3.INF:
				for u in units:
					var sid: String = u.def.get("special", "")
					if sid != "" and Defs.SPECIALS[sid].get("targeted", false):
						u.use_special(ground)
		Mode.STRIKE:
			if ground == Vector3.INF or not strike_at(ground):
				world.sfx.play_ui("error")
				return
		Mode.PLACE:
			if ghost_valid and ground != Vector3.INF:
				_place_building(ground)
				if shift and world.player(0).can_afford(Defs.BUILDINGS[place_id]["cost"]):
					return
			else:
				world.sfx.play_ui("error")
				return
	world.sfx.play_ui("confirm")
	set_mode(Mode.NONE)


# ---------------------------------------------------------------- superweapon
func begin_strike(b: Building) -> void:
	if not b.strike_ready():
		world.sfx.play_ui("error")
		world.raise_alert(Vector3.ZERO, "充填中（%d%%）" % int(b.charge_ratio() * 100.0), Defs.TEAM_PLAYER, "strike_err", 1.0)
		return
	strike_from = b
	set_mode(Mode.STRIKE)


## Fire the waiting tower at a point (the battlefield or the minimap).
func strike_at(p: Vector3) -> bool:
	if mode != Mode.STRIKE or strike_from == null or not is_instance_valid(strike_from):
		return false
	var ok := strike_from.fire_superweapon(p)
	if ok:
		set_mode(Mode.NONE)
	return ok


func at_limit(id: String) -> bool:
	var lim := int(Defs.BUILDINGS[id].get("limit", 0))
	return lim > 0 and world.count_buildings(Defs.TEAM_PLAYER, id) >= lim


# ---------------------------------------------------------------- building placement
func begin_place(id: String) -> void:
	if at_limit(id):
		world.sfx.play_ui("error")
		world.raise_alert(Vector3.ZERO, "%sは%d基までしか建てられない" % [Defs.building_name(id, 0), int(Defs.BUILDINGS[id]["limit"])],
				Defs.TEAM_PLAYER, "place_err", 1.0)
		return
	var cost: Dictionary = Defs.BUILDINGS[id]["cost"]
	if not world.player(0).can_afford(cost):
		world.sfx.play_ui("error")
		world.raise_alert(Vector3.ZERO, "資源不足", Defs.TEAM_PLAYER, "place_err", 1.0)
		return
	place_id = id
	set_mode(Mode.PLACE)
	ghost = UnitVisual.load_model(Defs.BUILDINGS[id]["model"], 0, true)
	world.add_child(ghost)
	_add_footprint(ghost, float(Defs.BUILDINGS[id]["radius"]))
	ghost_valid = true
	_ghost_material(ghost, true)
	_show_territory()
	if Game.touch_input:
		# no cursor to follow: start in the middle of the screen and wait for a tap
		ghost.visible = false
		var g := camera.screen_to_ground(get_viewport().get_visible_rect().size * Vector2(0.5, 0.45))
		if g != Vector3.INF:
			place_at(g)


const GHOST_OK := Color(0.35, 1.0, 0.55)
const GHOST_BAD := Color(1.0, 0.3, 0.22)
var _ghost_mats := {}
## Where the player may build while placing: rings on the ground around the citadel, gates and cities.
var _territory: Node3D


func _ghost_material(root: Node, valid: bool) -> void:
	if not _ghost_mats.has(valid):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/ghost.gdshader")
		var c := GHOST_OK if valid else GHOST_BAD
		m.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
		_ghost_mats[valid] = m
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "Footprint":
			mi.set_instance_shader_parameter("ring_color", Color(GHOST_OK if valid else GHOST_BAD, 0.85))
			continue
		mi.material_override = _ghost_mats[valid]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A ring on the ground under the ghost, the size of the building's footprint.
func _add_footprint(root: Node3D, radius: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "Footprint"
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(radius * 2.0, radius * 2.0)
	ring.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ring.gdshader")
	ring.material_override = m
	ring.position.y = 0.5
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	ring.set_instance_shader_parameter("ring_width", 0.06)
	ring.set_instance_shader_parameter("ring_pulse", 1.0)
	ring.set_instance_shader_parameter("ring_fill", 1.0)


func _show_territory() -> void:
	_hide_territory()
	_territory = Node3D.new()
	world.add_child(_territory)
	for b in world.buildings:
		if b.team == Defs.TEAM_PLAYER and b.alive and b.def_id in ["citadel", "gate"]:
			_territory.add_child(_ground_circle(b.global_position, 62.0 if b.def_id == "citadel" else 26.0))
	for st in world.sites:
		if st.owner_team == Defs.TEAM_PLAYER:
			_territory.add_child(_ground_circle(st.global_position, st.radius + 20.0))


func _hide_territory() -> void:
	if _territory:
		_territory.queue_free()
		_territory = null


## A thin band that follows the ground around a circle (a flat quad would sink into hills).
func _ground_circle(c: Vector3, r: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := clampi(int(r * 1.6), 32, 128)
	var col := Color(0.55, 0.9, 1.0, 0.5)
	var inner := Color(0.55, 0.9, 1.0, 0.0)
	var pts: Array[Vector3] = []
	for i in n + 1:
		var a := TAU * i / n
		var d := Vector3(cos(a), 0.0, sin(a))
		for k: float in [r - 2.2, r]:
			var q := c + d * k
			pts.append(Vector3(q.x, world.terrain.ground_at(q.x, q.z) + 0.35, q.z))
	for i in n:
		var a0 := pts[i * 2]
		var b0 := pts[i * 2 + 1]
		var a1 := pts[i * 2 + 2]
		var b1 := pts[i * 2 + 3]
		for v: Array in [[a0, inner], [b0, col], [b1, col], [a0, inner], [b1, col], [a1, inner]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func placement_valid(id: String, p: Vector3) -> bool:
	var d: Dictionary = Defs.BUILDINGS[id]
	var fp: float = d["footprint"]
	if not world.terrain.in_bounds(p.x, p.z, 20.0):
		return false
	if not world.nav.area_free(p, fp + 1.0):
		return false
	var h0 := world.terrain.height_at(p.x, p.z)
	for a in 8:
		var ang := a * TAU / 8.0
		var q := p + Vector3(cos(ang), 0, sin(ang)) * fp
		if absf(world.terrain.height_at(q.x, q.z) - h0) > 1.6:
			return false
	for b in world.buildings:
		if b.alive and Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length() < b.radius + d["radius"] + 1.0:
			return false
	for u in world.units:
		if u.alive and not u.is_air and Vector2(u.global_position.x - p.x, u.global_position.z - p.z).length() < fp + u.radius:
			return false
	return in_territory(p)


func in_territory(p: Vector3) -> bool:
	for b in world.buildings:
		if b.team == Defs.TEAM_PLAYER and b.alive and b.def_id in ["citadel", "gate"]:
			if Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length() < (62.0 if b.def_id == "citadel" else 26.0):
				return true
	for s in world.sites:
		if s.owner_team == Defs.TEAM_PLAYER and Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length() < s.radius + 20.0:
			return true
	return false


func _place_building(p: Vector3) -> void:
	var d: Dictionary = Defs.BUILDINGS[place_id]
	if not world.player(0).spend(d["cost"]):
		world.sfx.play_ui("error")
		return
	var to_cam := camera.cam.global_position - p
	var yaw := snappedf(atan2(to_cam.x, to_cam.z), PI / 4.0)
	world.spawn_building(place_id, Defs.TEAM_PLAYER, p, yaw, false)
	world.fx.ring_burst(p + Vector3(0, 0.5, 0), d["radius"], Color(0.5, 1.0, 0.6))
	world.sfx.play_at("build_done", p, -6.0)


func _process(_delta: float) -> void:
	if mode == Mode.PLACE and ghost and not Game.touch_input:
		var g := ground_at_mouse(get_viewport().get_mouse_position())
		if g != Vector3.INF:
			place_at(g)
		else:
			ghost.visible = false
	hover = null
	if not dragging and not Game.touch_input and not _ui_hovered():
		hover = pick(get_viewport().get_mouse_position())



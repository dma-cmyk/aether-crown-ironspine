extends Node
## Dev: --scenario=touch_test plays a match with synthetic touches and prints PASS / FAIL per step,
## then quits (exit code 1 on a failure). Run it at a phone size:
## godot --path game --resolution 844x390 -- --capture=x --frames=100000 --touch --scenario=touch_test [--shots=<dir>]

var world: World
var commander: Commander
var camera: CameraRig
var hud: HUD
var fails := 0
var orders := 0


func setup(w: World, c: Commander, cam: CameraRig, h: HUD) -> void:
	world = w
	commander = c
	camera = cam
	hud = h
	process_mode = Node.PROCESS_MODE_ALWAYS
	commander.order_issued.connect(func(_k: String, _p: Vector3) -> void: orders += 1)
	_run.call_deferred()


func _run() -> void:
	world.fog.enabled = false
	world.player(0).material = 5000.0
	world.player(0).aether = 5000.0
	await _wait(1.0)
	var walker: Unit
	for u in world.units:
		if u.team == 0 and u.def_id == "walker":
			walker = u
	camera.set_view(walker.global_position, -45.0, 60.0)
	await _wait(0.5)

	await _tap(_screen(walker.aim_point()))
	_check("tap selects our walker", commander.selection == [walker])

	await _tap(_empty_spot())
	_check("tap on the ground moves it", walker.order == Unit.Order.MOVE, str(walker.order))

	var mid := Vector2(520, 240)
	var before := camera.screen_to_ground(mid)
	var orders0 := orders
	await _drag([mid], [mid + Vector2(220, -60)])
	var after := camera.screen_to_ground(mid + Vector2(220, -60))
	_check("one-finger drag keeps the ground under the finger", Vector2(before.x - after.x, before.z - after.z).length() < 1.5,
			"%.2f m off" % Vector2(before.x - after.x, before.z - after.z).length())
	_check("a drag gives no order and keeps the selection", commander.selection == [walker] and orders == orders0)

	var d0 := camera.target_distance
	await _drag([mid - Vector2(80, 0), mid + Vector2(80, 0)], [mid - Vector2(160, 0), mid + Vector2(160, 0)])
	_check("pinching out zooms in", absf(camera.target_distance - maxf(d0 * 0.5, CameraRig.MIN_DIST)) < 2.0,
			"%.1f -> %.1f" % [d0, camera.target_distance])
	var yaw0 := camera.yaw
	await _drag([mid - Vector2(100, 0), mid + Vector2(100, 0)], [mid + Vector2(-100, 60), mid + Vector2(100, -60)])
	_check("twisting two fingers turns the camera", absf(angle_difference(yaw0, camera.yaw)) > 0.4, "%.2f rad" % angle_difference(yaw0, camera.yaw))

	await _tap(_center(hud.cmd_buttons[1]))
	_check("the HOLD button works and the tap stays on the HUD", walker.order == Unit.Order.HOLD and commander.selection == [walker], str(walker.order))
	_check("pressing a button shows what it does", hud.tooltip.visible)
	await _shot("hold_tip")

	await _tap(_center(hud.deselect_button))
	_check("the clear button empties the selection", commander.selection.is_empty())

	var squad: Unit = world.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.def_id == "aetherguard")[0]
	camera.set_view(squad.global_position, -45.0, 70.0)
	await _wait(0.5)
	var a := Vector2(380, 140)
	var b := Vector2(660, 320)
	await _hold_drag(a, b)
	var rect := Rect2(a, b - a)
	var n_in := world.units.filter(func(u: Unit) -> bool: return u.team == 0 and rect.has_point(_screen(u.global_position + Vector3(0, 1, 0)))).size()
	print("[touch_test] %d of our units inside the box" % n_in)
	var inside := commander.selection.all(func(e: Entity) -> bool: return e is Unit and e.team == 0 and rect.has_point(_screen(e.global_position + Vector3(0, 1, 0))))
	_check("hold and drag box-selects our units", not commander.selection.is_empty() and inside, "%d selected" % commander.selection.size())

	var empty := _empty_spot()
	await _hold_drag(empty, empty)
	_check("hold and lift on open ground clears the selection", commander.selection.is_empty(), "%d selected" % commander.selection.size())

	var cit := world.citadel(0)
	commander.set_selection([cit])
	camera.set_view(cit.global_position, -45.0, 90.0)
	await _wait(0.6)
	await _tap(_center(hud.cmd_buttons[7]))
	_check("the 建設 button opens the build menu", hud.build_mode)
	await _tap(_center(hud.cmd_buttons[0]))
	_check("a building button starts placing", commander.mode == Commander.Mode.PLACE and commander.ghost != null)
	var site := _valid_spot(commander.place_id) if commander.mode == Commander.Mode.PLACE else Vector2.INF
	_check("found a free spot to build", site != Vector2.INF)
	var n := world.buildings.size()
	await _tap(site)
	var g := camera.screen_to_ground(site)
	_check("the first tap sets the ghost down there", commander.ghost and Vector2(commander.ghost.global_position.x - g.x, commander.ghost.global_position.z - g.z).length() < 0.5)
	_check("... without building yet", world.buildings.size() == n)
	await _shot("place")
	await _tap(site)
	_check("a second tap on the ghost builds it", world.buildings.size() == n + 1 and commander.mode == Commander.Mode.NONE,
			"%d -> %d" % [n, world.buildings.size()])

	var gear: Button = hud.find_children("*", "Button", true, false).filter(
			func(x: Button) -> bool: return x.tooltip_text.begins_with("メニュー"))[0]
	await _tap(_center(gear))
	_check("the gear pauses the game", get_tree().paused and hud.menus.pause_box.visible)
	await _shot("pause")
	await _tap(_center(hud.menus.pause_box.get_child(0).get_child(1)))
	_check("再開 resumes", not get_tree().paused)

	print("[touch_test] %s (%d failed)" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("[touch_test] %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		fails += 1


func _screen(p: Vector3) -> Vector2:
	return camera.cam.unproject_position(p)


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## A screen point clear of the HUD with nothing to pick under it.
func _empty_spot() -> Vector2:
	for y in range(130, 330, 20):
		for x in range(300, 760, 20):
			if commander.pick(Vector2(x, y)) == null:
				return Vector2(x, y)
	return Vector2(520, 240)


## A screen point on the battlefield where the building fits.
func _valid_spot(id: String) -> Vector2:
	for y in range(140, 320, 20):
		for x in range(300, 760, 20):
			var g := camera.screen_to_ground(Vector2(x, y))
			if g != Vector3.INF and commander.placement_valid(id, g):
				return Vector2(x, y)
	return Vector2.INF


# ---------------------------------------------------------------- synthetic touches
func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev.xformed_by(get_tree().root.get_final_transform()))


func _touch(i: int, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = pressed
	_send(e)


func _move(i: int, from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = to
	e.relative = to - from
	_send(e)


func _tap(p: Vector2) -> void:
	_touch(0, p, true)
	await _frames(3)
	_touch(0, p, false)
	await _frames(4)


## Fingers go down at `from`, slide to `to` in 12 steps and lift.
func _drag(from: Array, to: Array) -> void:
	for i in from.size():
		_touch(i, from[i], true)
		await _frames(2)
	for k in 12:
		for i in from.size():
			_move(i, (from[i] as Vector2).lerp(to[i], k / 12.0), (from[i] as Vector2).lerp(to[i], (k + 1) / 12.0))
		await _frames(1)
	for i in range(from.size() - 1, -1, -1):
		_touch(i, to[i], false)
		await _frames(2)
	await _frames(2)


func _hold_drag(from: Vector2, to: Vector2) -> void:
	_touch(0, from, true)
	await _wait(TouchControls.HOLD + 0.2)
	for k in 8:
		_move(0, from.lerp(to, k / 8.0), from.lerp(to, (k + 1) / 8.0))
		await _frames(1)
	_touch(0, to, false)
	await _frames(4)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	var dir := Game.arg("shots")
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("touch_%s.png" % name))

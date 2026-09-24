class_name TouchControls
extends Node
## Touch play on phones and tablets. One finger: tap a unit or building of ours to select it; with
## units selected, tap the ground to move and an enemy to attack; tap twice for every unit of that
## kind on screen; drag to pan; hold still, then drag, to box-select. Two fingers: pinch to zoom,
## twist to turn, move together to pan. Hold still and lift to select anything (enemies too) or
## clear the selection. Touches that land on the HUD are left to it.
## Building: drag a building button out onto the field, or drag the placed ghost, and the
## building follows the finger (held a little above it); lifting the finger builds it there.

const TAP_SLOP := 16.0
const HOLD := 0.45
## The ghost rides this far above a dragging finger, so the finger does not hide it.
const LIFT := Vector2(0, -70)

var commander: Commander
var camera: CameraRig
var _touches := {}
var _start := Vector2.ZERO
var _start_t := 0.0
## "" until the finger moves or holds, then "pan", "box" or "two".
var _gesture := ""
var _grab := Vector3.INF
var _two_d := 1.0
var _two_a := 0.0
var _two_zoom := 0.0
## Where and when a mouse click made from a finger got past the HUD.
var _free_press := Vector2.INF
var _free_frame := -1
## The finger went down on the ghost being placed.
var _on_ghost := false
## A building button was pressed: the next finger that drags off it carries the building.
var _card_pending := false


func setup(c: Commander, cam: CameraRig) -> void:
	commander = c
	camera = cam


## A finger that lands on the HUD belongs to the HUD. One that lands on the battlefield is
## followed until it lifts, even across the HUD.
func _unhandled_input(event: InputEvent) -> void:
	# Godot turns the first finger into a mouse click just before passing on the touch itself.
	# Controls stop the click but not the touch, so a touch counts only if its click got through.
	var mb := event as InputEventMouseButton
	if mb and mb.device == InputEvent.DEVICE_ID_EMULATION and mb.pressed:
		_free_press = mb.position
		_free_frame = Engine.get_process_frames()
		return
	var st := event as InputEventScreenTouch
	if st == null or not st.pressed or not commander.enabled or commander.world.game_over:
		return
	var clicked := _free_frame == Engine.get_process_frames() and _free_press.distance_to(st.position) < 1.0
	if _touches.is_empty() and not clicked and _on_hud(st.position):
		return
	_touches[st.index] = st.position
	if _touches.size() == 1:
		_start = st.position
		_start_t = _now()
		_gesture = ""
		_on_ghost = _near_ghost(st.position)
	elif _touches.size() == 2:
		_begin_two()
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	var st := event as InputEventScreenTouch
	if st and not st.pressed and _touches.has(st.index):
		_touches.erase(st.index)
		if st.canceled:
			_reset()
		elif _gesture in ["ghost", "card"]:
			_drop(st.position)
		elif _touches.is_empty():
			_finish(st.position)
		elif _touches.size() == 1:
			_gesture = "pan"
			_grab = camera.screen_to_ground(_touches.values()[0])
		get_viewport().set_input_as_handled()
		return
	var sd := event as InputEventScreenDrag
	if sd and _card_pending and _touches.is_empty():
		if commander.mode != Commander.Mode.PLACE:
			_card_pending = false
		elif not _on_card(sd.position):
			# the finger has left the button: from here on it carries the building
			_card_pending = false
			_touches[sd.index] = sd.position
			_gesture = "card"
	if sd and _touches.has(sd.index):
		_touches[sd.index] = sd.position
		if _touches.size() == 2:
			_move_two()
		elif _gesture == "" and sd.position.distance_to(_start) > TAP_SLOP:
			_gesture = "ghost" if _on_ghost and commander.mode == Commander.Mode.PLACE else "pan"
			_grab = camera.screen_to_ground(_start)
		if _gesture in ["ghost", "card"]:
			_carry(sd.position)
		elif _gesture == "pan":
			_pan_to(sd.position)
		elif _gesture == "box":
			commander.drag_rect = Rect2(_start, sd.position - _start).abs()
		get_viewport().set_input_as_handled()


## Fallback for a finger that made no click (another finger was already down): a visible control
## that takes clicks under it.
func _on_hud(p: Vector2) -> bool:
	var hud: Control = commander.hud
	if hud == null:
		return false
	for c: Control in hud.find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(p):
			return true
	return false


func _process(_delta: float) -> void:
	if not commander.enabled or commander.world.game_over:
		if not _touches.is_empty():
			_reset()
		return
	if _touches.size() == 1 and _gesture == "" and commander.mode == Commander.Mode.NONE and _now() - _start_t > HOLD:
		_gesture = "box"
		commander.dragging = true
		commander.drag_start = _start
		commander.drag_rect = Rect2(_start, Vector2.ZERO)
		Input.vibrate_handheld(25)


func _finish(pos: Vector2) -> void:
	match _gesture:
		"":
			commander.touch_tap(pos)
		"box":
			commander.dragging = false
			if commander.drag_rect.size.length() > TAP_SLOP:
				commander.touch_box(commander.drag_rect)
			else:
				commander.touch_pick(pos)
			commander.drag_rect = Rect2()
	_reset()


## HUD: a building button went down under a finger.
func card_pressed() -> void:
	_card_pending = true


func _on_card(p: Vector2) -> bool:
	var hud: HUD = commander.hud as HUD
	if hud == null:
		return false
	var card := hud.cmd_grid.get_parent() as Control
	return card.get_global_rect().has_point(p)


func _near_ghost(p: Vector2) -> bool:
	if commander.mode != Commander.Mode.PLACE or commander.ghost == null or not commander.ghost.visible:
		return false
	var g := camera.screen_to_ground(p)
	var gp := commander.ghost.global_position
	return g != Vector3.INF and Vector2(g.x - gp.x, g.z - gp.z).length() < float(Defs.BUILDINGS[commander.place_id]["radius"]) + 3.0


func _carry(p: Vector2) -> void:
	if _on_hud(p):
		return
	var g := camera.screen_to_ground(p + LIFT)
	if g != Vector3.INF:
		commander.place_at(g)


## Lifting the finger builds where the ghost stands; back on the HUD it gives up instead.
func _drop(p: Vector2) -> void:
	if _gesture == "card" and _on_hud(p):
		commander.cancel_mode()
	elif commander.mode == Commander.Mode.PLACE:
		commander.confirm_ghost()
	_reset()


func _reset() -> void:
	if _gesture == "box":
		commander.dragging = false
		commander.drag_rect = Rect2()
	_touches.clear()
	_gesture = ""
	_grab = Vector3.INF
	_on_ghost = false
	_card_pending = false


## Keep the ground point first touched under the finger.
func _pan_to(p: Vector2) -> void:
	if _grab == Vector3.INF:
		_grab = camera.screen_to_ground(p)
		return
	var now := camera.screen_to_plane(p, _grab.y)
	if now != Vector3.INF:
		camera.pan_by(Vector3(_grab.x - now.x, 0.0, _grab.z - now.z))


func _begin_two() -> void:
	if _gesture == "box":
		commander.dragging = false
		commander.drag_rect = Rect2()
	_gesture = "two"
	var p: Array = _touches.values()
	_two_d = maxf((p[0] as Vector2).distance_to(p[1]), 1.0)
	_two_a = (p[1] - p[0]).angle()
	_two_zoom = camera.target_distance
	_grab = camera.screen_to_ground((p[0] + p[1]) * 0.5)


func _move_two() -> void:
	var p: Array = _touches.values()
	var a: float = (p[1] - p[0]).angle()
	camera.zoom_to(_two_zoom * _two_d / maxf((p[0] as Vector2).distance_to(p[1]), 1.0))
	camera.turn_by(-angle_difference(_two_a, a))
	_two_a = a
	_pan_to((p[0] + p[1]) * 0.5)


func _now() -> float:
	return Time.get_ticks_msec() * 0.001

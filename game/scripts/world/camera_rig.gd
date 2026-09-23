class_name CameraRig
extends Node3D
## RTS camera: pan (arrows / screen edge / middle drag with Shift), zoom (wheel),
## rotate (middle drag / , .), follows terrain height.

signal moved

const MIN_DIST := 22.0
const MAX_DIST := 150.0

var terrain: Terrain
var cam: Camera3D
var focus := Vector3.ZERO
var yaw := deg_to_rad(-45.0)
var pitch := deg_to_rad(52.0)
var distance := 72.0
var target_distance := 72.0
var target_focus := Vector3.ZERO
var input_enabled := true
var bounds := 185.0
var _dragging := false
var _last_mouse := Vector2.ZERO
var _shake := 0.0


func setup(t: Terrain) -> void:
	terrain = t
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.fov = 42.0
	cam.near = 0.5
	cam.far = 2200.0
	add_child(cam)
	cam.make_current()


func look_at_point(p: Vector3, instant: bool = false) -> void:
	target_focus = Vector3(p.x, 0.0, p.z)
	if instant:
		focus = target_focus
		focus.y = terrain.ground_at(focus.x, focus.z) if terrain else 0.0
		_update_transform()


func set_view(p: Vector3, yaw_deg: float, dist: float, pitch_deg: float = -1.0) -> void:
	yaw = deg_to_rad(yaw_deg)
	distance = dist
	target_distance = dist
	if pitch_deg > 0.0:
		pitch = deg_to_rad(pitch_deg)
	look_at_point(p, true)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func forward_dir() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func right_dir() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_distance = maxf(MIN_DIST, target_distance * 0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_distance = minf(MAX_DIST, target_distance * 1.13)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			_last_mouse = mb.position
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var d := mm.position - _last_mouse
		_last_mouse = mm.position
		if Input.is_key_pressed(KEY_SHIFT):
			var k := distance * 0.0022
			target_focus += (-right_dir() * d.x + forward_dir() * d.y) * k
		else:
			yaw -= d.x * 0.006
			_pitch_offset = clampf(_pitch_offset + d.y * 0.004, -0.35, 0.3)


var _pitch_offset := 0.0


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	if input_enabled:
		var pan := Vector2.ZERO
		if Input.is_action_pressed("cam_left"):
			pan.x -= 1
		if Input.is_action_pressed("cam_right"):
			pan.x += 1
		if Input.is_action_pressed("cam_up"):
			pan.y += 1
		if Input.is_action_pressed("cam_down"):
			pan.y -= 1
		if Game.edge_scroll and not _dragging and DisplayServer.window_is_focused():
			var vp := get_viewport()
			var mp := vp.get_mouse_position()
			var sz := vp.get_visible_rect().size
			var m := 6.0
			if mp.x >= 0 and mp.y >= 0 and mp.x <= sz.x and mp.y <= sz.y:
				if mp.x < m:
					pan.x -= 1
				elif mp.x > sz.x - m:
					pan.x += 1
				if mp.y < m:
					pan.y += 1
				elif mp.y > sz.y - m:
					pan.y -= 1
		if pan != Vector2.ZERO:
			var speed := 24.0 + distance * 0.9
			target_focus += (right_dir() * pan.x + forward_dir() * pan.y).normalized() * speed * delta
		if Input.is_action_pressed("cam_rot_left"):
			yaw += 1.6 * delta
		if Input.is_action_pressed("cam_rot_right"):
			yaw -= 1.6 * delta
	target_focus.x = clampf(target_focus.x, -bounds, bounds)
	target_focus.z = clampf(target_focus.z, -bounds, bounds)
	focus.x = lerpf(focus.x, target_focus.x, 1.0 - exp(-12.0 * delta))
	focus.z = lerpf(focus.z, target_focus.z, 1.0 - exp(-12.0 * delta))
	var gy := terrain.ground_at(focus.x, focus.z) if terrain else 0.0
	focus.y = lerpf(focus.y, maxf(gy, -6.0), 1.0 - exp(-5.0 * delta))
	distance = lerpf(distance, target_distance, 1.0 - exp(-9.0 * delta))
	_shake = maxf(0.0, _shake - delta * 2.5)
	_update_transform()


func _update_transform() -> void:
	var t := inverse_lerp(MIN_DIST, MAX_DIST, distance)
	var p := lerpf(deg_to_rad(38.0), deg_to_rad(60.0), sqrt(clampf(t, 0.0, 1.0))) + _pitch_offset
	pitch = clampf(p, deg_to_rad(18.0), deg_to_rad(80.0))
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	var pos := focus + off
	if terrain:
		var g := terrain.height_at(pos.x, pos.z) + 3.0
		if pos.y < g:
			pos.y = g
	if cam:
		var jitter := Vector3.ZERO
		if _shake > 0.0:
			jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.35
		cam.global_transform = Transform3D(Basis(), pos + jitter).looking_at(focus + jitter * 0.5, Vector3.UP)
	moved.emit()


## Screen point -> ground point (Vector3.INF when the ray misses).
func screen_to_ground(screen_pos: Vector2) -> Vector3:
	if cam == null or terrain == null:
		return Vector3.INF
	var o := cam.project_ray_origin(screen_pos)
	var d := cam.project_ray_normal(screen_pos)
	return terrain.raycast(o, d)

class_name FlyerVisual
extends CreatureVisual
## Winged creature: wingbeats that ripple out along the wing, glides when cruising straight,
## banking into turns, a blob shadow on the ground and a fall to earth on death.
## Subclasses fill `wing` (bones from shoulder to tip per side) and pose the body in _body().

const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

## Bone names per side, shoulder first. Tips may share a parent (fingers).
var wing := {"l": [], "r": []}
## Per-bone phase lag (radians) and share of the stroke.
var lags: Array[float] = [0.0, 0.7, 1.2, 1.35, 1.5]
var amps: Array[float] = [1.0, 0.55, 0.45, 0.42, 0.38]
## Wing held in a glide: per-bone lift (radians).
var glide_pose: Array[float] = [0.12, -0.05, -0.05, -0.05, -0.05]
var beat_rate := 0.75
var hover_rate := 1.05
var beat_amp := 0.55
var fold := 0.3
var bob := 0.35
var beat := 0.0
var glide := 0.0
var bank := 0.0
var last_facing := 0.0
var shadow: MeshInstance3D
var _fall_v := 0.0
var _landed := false


func setup(u: Unit) -> void:
	super.setup(u)
	last_facing = u.facing
	beat = randf() * 10.0
	shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(u.radius * 2.2, u.radius * 2.6)
	q.orientation = PlaneMesh.FACE_Y
	shadow.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/blob_shadow.gdshader")
	shadow.material_override = m
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.top_level = true
	add_child(shadow)


func _process(delta: float) -> void:
	if unit == null or skel == null:
		return
	delta = minf(delta, 0.05)
	visible = unit.seen_by_player or unit.team == Defs.TEAM_PLAYER
	if death_t >= 0.0:
		_fall(delta)
		return
	stride(delta)
	_tick(delta)
	var turn_rate := angle_difference(last_facing, unit.facing) / maxf(delta, 0.001)
	last_facing = unit.facing
	bank = lerpf(bank, clampf(-turn_rate * 0.4, -0.45, 0.45), clampf(delta * 2.0, 0.0, 1.0))
	var cruising := walk > 0.8 and absf(turn_rate) < 0.25 and fmod(beat * 0.11, 1.0) > 0.6
	glide = move_toward(glide, 1.0 if cruising and not attacking() else 0.0, delta * 1.5)
	beat += delta * lerpf(hover_rate, beat_rate, walk) * (1.0 - glide * 0.9)
	var ph := beat * TAU
	model.position.y = -sin(ph - 0.5) * bob * (1.0 - glide)
	model.rotation.z = bank
	var g := World.inst.terrain.ground_at(unit.global_position.x, unit.global_position.z)
	shadow.global_position = Vector3(unit.global_position.x, g + 0.3, unit.global_position.z)
	shadow.global_rotation = Vector3(0, unit.facing, 0)
	shadow.visible = visible
	if not visible:
		return
	_flap(ph)
	_body(ph, delta)
	apply_pose()
	_after_pose(delta)


func attacking() -> bool:
	return false


func _flap(ph: float) -> void:
	for s: String in ["l", "r"]:
		var sg := 1.0 if s == "l" else -1.0
		var bones: Array = wing[s]
		for i in bones.size():
			var a := sin(ph - lags[i]) * beat_amp * amps[i] * (1.0 - glide) + glide_pose[i] * glide
			turn(bones[i], Z, sg * a)
			if i >= 2:
				turn(bones[i], Y, sg * fold * maxf(0.0, cos(ph - lags[i])) * (1.0 - glide))


## Attack timers; runs every frame, seen or not.
func _tick(_delta: float) -> void:
	pass


## Neck, tail, legs and attacks; called after the wings, before the pose is applied.
func _body(_ph: float, _delta: float) -> void:
	pass


## Effects that need this frame's bone positions (breath, sparks).
func _after_pose(_delta: float) -> void:
	pass


func _fall(delta: float) -> void:
	death_t += delta
	shadow.visible = false
	if not _landed:
		_fall_v += 16.0 * delta
		model.position.y -= _fall_v * delta
		model.rotation.z = lerpf(model.rotation.z, 1.0, delta * 1.2)
		model.rotation.x = lerpf(model.rotation.x, 0.35, delta)
		for s: String in ["l", "r"]:
			var sg := 1.0 if s == "l" else -1.0
			var bones: Array = wing[s]
			for i in bones.size():
				turn(bones[i], Z, sg * (0.9 - i * 0.25) * minf(death_t * 2.0, 1.0))
		apply_pose()
		var ground := World.inst.terrain.ground_at(unit.global_position.x, unit.global_position.z)
		if model.global_position.y <= ground + 1.2:
			_landed = true
			var p := Vector3(model.global_position.x, ground, model.global_position.z)
			for k in 8:
				var a := k / 8.0 * TAU
				World.inst.fx.dust(p + Vector3(cos(a) * unit.radius, 0.4, sin(a) * unit.radius), 3.5)
			World.inst.fx.debris(p, 8, true)
			World.inst.sfx.play_at("thud_big", p)
			var cam := World.inst.camera
			if cam.focus.distance_to(p) < 80.0:
				cam.shake(0.5)
	elif death_t > 5.0:
		model.position.y -= delta * 0.5

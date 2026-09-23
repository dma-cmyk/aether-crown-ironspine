class_name CyclopsVisual
extends CreatureVisual
## Hill giant: heavy stride with footfall dust, overhead club smash, boulder throw and a
## toppling death. Attack timings match the weapon "delay" and the special's release time.

const STRIDE := 7.5
const SWING := 1.0
const HURL := 1.4
## From the right wrist to the club head, and from the left wrist into the palm (model axes at rest).
const CLUB_HEAD := Vector3(-0.21, -1.07, 3.69)
const PALM := Vector3(0.05, -0.5, 0.4)
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

var phase := 0.0
var swing_t := -1.0
var hurl_t := -1.0
var look_yaw := 0.0
var idle_t := 0.0
var boulder: Node3D
var _wander := 0.0
var _wander_t := 0.0
var _landed := false


func setup(u: Unit) -> void:
	super.setup(u)
	idle_t = randf() * 10.0
	phase = randf()
	boulder = make_boulder()
	boulder.visible = false
	add_child(boulder)
	boulder.top_level = true


static func make_boulder() -> Node3D:
	var b: Node3D = (load("res://assets/models/rock_a.glb") as PackedScene).instantiate()
	MatLib.remap(b, -1, false)
	b.scale = Vector3.ONE * 0.36
	return b


func muzzle_points(w: Dictionary, _target: Entity) -> Array[Vector3]:
	if w["id"] == "cyclops_club":
		return [bone_point("hand_r", CLUB_HEAD)]
	return [bone_point("hand_l", PALM)]


func on_fire(w: Dictionary, _target: Entity) -> void:
	if w["id"] == "cyclops_club":
		swing_t = 0.0


func on_special(sid: String) -> void:
	if sid == "boulder_hurl":
		hurl_t = 0.0
		swing_t = -1.0


func special_point() -> Vector3:
	return bone_point("hand_l", PALM)


func _process(delta: float) -> void:
	if unit == null or skel == null:
		return
	delta = minf(delta, 0.05)
	visible = unit.seen_by_player or unit.team == Defs.TEAM_PLAYER
	if death_t >= 0.0:
		_die(delta)
		return
	var moved := stride(delta)
	var prev := phase
	phase = fmod(phase + moved / STRIDE, 1.0)
	idle_t += delta
	if swing_t >= 0.0:
		swing_t += delta
		if swing_t > SWING:
			swing_t = -1.0
	if hurl_t >= 0.0:
		hurl_t += delta
		if hurl_t > HURL:
			hurl_t = -1.0
	if not visible:
		return
	_gait(prev)
	_idle(delta)
	if swing_t >= 0.0:
		_swing(swing_t / SWING)
	if hurl_t >= 0.0:
		_hurl(hurl_t / HURL)
	boulder.visible = hurl_t >= 0.0 and hurl_t / HURL > 0.2 and hurl_t / HURL < 0.72
	apply_pose()
	if boulder.visible:
		boulder.global_position = bone_point("hand_l", PALM)


func _gait(prev: float) -> void:
	var t := phase * TAU
	var w := walk
	for s: String in ["l", "r"]:
		var sg := 1.0 if s == "l" else -1.0
		var sw := sin(t) * 0.5 * w * sg
		var lift := maxf(0.0, cos(t) * sg) * w
		turn("thigh_" + s, X, -sw - lift * 0.25)
		turn("shin_" + s, X, lift * 1.0)
		turn("foot_" + s, X, sw * 0.5 - lift * 0.35)
	shift("hips", Vector3(sin(t) * 0.1 * w, -absf(sin(t)) * 0.22 * w, 0))
	turn("hips", Z, -sin(t) * 0.05 * w)
	turn("hips", Y, sin(t) * 0.1 * w)
	turn("spine", Y, -sin(t) * 0.14 * w)
	turn("spine", X, 0.1 * w)
	if swing_t < 0.0:
		turn("uparm_r", X, -sin(t) * 0.2 * w - 0.15 * w)
	if hurl_t < 0.0:
		turn("uparm_l", X, sin(t) * 0.35 * w)
		turn("forearm_l", X, -0.25 * w)
	# footfalls
	if w > 0.35 and visible:
		for k: float in [0.25, 0.75]:
			if prev < k and phase >= k or (prev > phase and k > prev):
				var side := "l" if k < 0.5 else "r"
				World.inst.fx.dust(bone_point("foot_" + side), 2.2)


func _idle(delta: float) -> void:
	var breath := sin(idle_t * 1.3)
	turn("chest", X, breath * 0.025)
	turn("clav_l", Z, breath * 0.03)
	turn("clav_r", Z, -breath * 0.03)
	var want := target_yaw(1.0)
	if unit.target == null or not is_instance_valid(unit.target):
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(2.0, 5.0)
			_wander = randf_range(-0.6, 0.6)
		want = _wander * (1.0 - walk)
	look_yaw = lerpf(look_yaw, want, delta * 2.0)
	turn("neck", Y, look_yaw * 0.4)
	turn("head", Y, look_yaw * 0.6)


func _crouch(c: float) -> void:
	for s: String in ["l", "r"]:
		turn("thigh_" + s, X, -c * 0.5)
		turn("shin_" + s, X, c * 1.0)
		turn("foot_" + s, X, -c * 0.5)
	shift("hips", Vector3(0, -c * 0.55, 0))


## Club: wind up overhead, smash down at 60 %, recover.
func _swing(s: float) -> void:
	var arm := 0.0
	var elbow := 0.0
	var wrist := 0.0
	var lean := 0.0
	var twist := 0.0
	var crouch := 0.0
	if s < 0.45:
		var k := ease_out(s / 0.45)
		arm = -2.7 * k
		elbow = -0.9 * k
		wrist = -0.4 * k
		lean = -0.14 * k
		twist = -0.25 * k
	elif s < 0.6:
		var k := ease_in((s - 0.45) / 0.15)
		arm = lerpf(-2.7, -0.75, k)
		elbow = lerpf(-0.9, 0.0, k)
		wrist = lerpf(-0.4, 1.2, k)
		lean = lerpf(-0.14, 0.3, k)
		twist = lerpf(-0.25, 0.15, k)
		crouch = k
	else:
		var k := smoothstep(0.0, 1.0, (s - 0.6) / 0.4)
		arm = lerpf(-0.75, 0.0, k)
		wrist = lerpf(1.2, 0.0, k)
		lean = lerpf(0.3, 0.0, k)
		twist = lerpf(0.15, 0.0, k)
		crouch = 1.0 - k
	turn("uparm_r", X, arm)
	turn("uparm_r", Z, -0.3 * absf(arm) / 2.7)
	turn("forearm_r", X, elbow)
	turn("hand_r", X, wrist)
	turn("spine", X, lean * 0.6)
	turn("chest", X, lean * 0.4)
	turn("spine", Y, twist)
	turn("jaw", X, 0.3 * bump(s, 0.3, 0.75))
	_crouch(crouch * 0.4)


## Boulder: crouch and grab, heave it overhead, throw at ~71 %, recover.
func _hurl(s: float) -> void:
	var arm := 0.0
	var elbow := 0.0
	var lean := 0.0
	var twist := 0.0
	var crouch := 0.0
	if s < 0.28:
		var k := ease_out(s / 0.28)
		crouch = k
		lean = 0.55 * k
		arm = -0.8 * k
	elif s < 0.66:
		var k := ease_out((s - 0.28) / 0.38)
		crouch = 1.0 - k
		lean = lerpf(0.55, -0.2, k)
		arm = lerpf(-0.8, -2.9, k)
		elbow = -1.2 * k
		twist = 0.3 * k
	elif s < 0.78:
		var k := ease_in((s - 0.66) / 0.12)
		lean = lerpf(-0.2, 0.25, k)
		arm = lerpf(-2.9, -1.2, k)
		elbow = lerpf(-1.2, 0.0, k)
		twist = lerpf(0.3, -0.2, k)
	else:
		var k := smoothstep(0.0, 1.0, (s - 0.78) / 0.22)
		lean = lerpf(0.25, 0.0, k)
		arm = lerpf(-1.2, 0.0, k)
		twist = lerpf(-0.2, 0.0, k)
	turn("uparm_l", X, arm)
	turn("uparm_l", Z, 0.25 * absf(arm) / 2.9)
	turn("forearm_l", X, elbow)
	turn("spine", X, lean * 0.6)
	turn("chest", X, lean * 0.4)
	turn("spine", Y, twist)
	turn("jaw", X, 0.35 * bump(s, 0.5, 0.85))
	_crouch(crouch * 0.8)


func _die(delta: float) -> void:
	death_t += delta
	boulder.visible = false
	var k := clampf(death_t / 1.25, 0.0, 1.0)
	model.rotation.x = -1.45 * k * k
	turn("uparm_l", Z, 0.9 * k)
	turn("uparm_r", Z, -0.9 * k)
	turn("head", X, -0.4 * k)
	turn("thigh_l", X, -0.35 * k)
	turn("thigh_r", X, -0.2 * k)
	turn("jaw", X, 0.4 * k)
	apply_pose()
	if k >= 1.0 and not _landed:
		_landed = true
		var back := Basis(Vector3.UP, unit.facing) * Vector3(0, 0, -1)
		for i in 7:
			World.inst.fx.dust(unit.global_position + back * (1.0 + i * 1.1) + Vector3(randf_range(-1.5, 1.5), 0.3, randf_range(-1.5, 1.5)), 4.5)
		World.inst.fx.debris(unit.global_position + back * 4.0, 8, true)
		World.inst.sfx.play_at("thud_big", unit.global_position)
		var cam := World.inst.camera
		if cam.focus.distance_to(unit.global_position) < 80.0:
			cam.shake(0.6)
	if death_t > 4.5:
		model.position.y = -(death_t - 4.5) * 0.6

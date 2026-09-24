class_name TitanVisual
extends CreatureVisual
## Titan: a slow, ground-shaking stride, the head thrust forward as the beam leaves the mask,
## a long gathering of light before Titan's Light sweeps the ground, flakes and dark smoke
## falling from a body that is coming apart, and a collapse into dust.

const STRIDE := 12.0
const BEAM := 1.0
## Unit.RAY_CHARGE + Unit.RAY_SWEEP.
const RAY := 3.7
## From the head bone to the mouth slit of the mask (model axes at rest).
const MOUTH := Vector3(0.0, -0.1, 1.6)
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

var phase := 0.0
var beam_t := -1.0
var ray_t := -1.0
var look_yaw := 0.0
var idle_t := 0.0
var _crumble_t := 0.0
var _landed := false


func setup(u: Unit) -> void:
	super.setup(u)
	idle_t = randf() * 10.0
	phase = randf()


func muzzle_points(_w: Dictionary, _target: Entity) -> Array[Vector3]:
	return [bone_point("head", MOUTH)]


func special_point() -> Vector3:
	return bone_point("head", MOUTH)


func on_fire(_w: Dictionary, _target: Entity) -> void:
	beam_t = 0.0


func on_special(sid: String) -> void:
	if sid == "titan_ray":
		ray_t = 0.0
		beam_t = -1.0
		World.inst.sfx.play_at("roar", unit.global_position)


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
	if beam_t >= 0.0:
		beam_t += delta
		if beam_t > BEAM:
			beam_t = -1.0
	if ray_t >= 0.0:
		ray_t += delta
		if ray_t > RAY:
			ray_t = -1.0
	if not visible:
		return
	_gait(prev)
	_idle(delta)
	if beam_t >= 0.0:
		_beam_pose(beam_t / BEAM)
	if ray_t >= 0.0:
		_ray_pose(ray_t)
	apply_pose()
	_crumble(delta)


func _gait(prev: float) -> void:
	var t := phase * TAU
	var w := walk
	for s: String in ["l", "r"]:
		var sg := 1.0 if s == "l" else -1.0
		var sw := sin(t) * 0.42 * w * sg
		var lift := maxf(0.0, cos(t) * sg) * w
		turn("thigh_" + s, X, -sw - lift * 0.25)
		turn("shin_" + s, X, lift * 0.9)
		turn("foot_" + s, X, sw * 0.4 - lift * 0.3)
		# the long arms swing heavily against the stride
		turn("uparm_" + s, X, sin(t) * 0.22 * w * sg)
		turn("forearm_" + s, X, -0.15 * w)
	shift("hips", Vector3(sin(t) * 0.18 * w, -absf(sin(t)) * 0.35 * w, 0))
	turn("hips", Z, -sin(t) * 0.05 * w)
	turn("spine", Y, -sin(t) * 0.1 * w)
	if w > 0.3:
		for k: float in [0.25, 0.75]:
			if prev < k and phase >= k or (prev > phase and k > prev):
				var p := bone_point("foot_" + ("l" if k < 0.5 else "r"))
				World.inst.fx.dust(p, 3.5)
				World.inst.sfx.play_at("thud", p, -6.0)
				var cam := World.inst.camera
				if cam.focus.distance_to(p) < 60.0:
					cam.shake(0.18)


func _idle(delta: float) -> void:
	var breath := sin(idle_t * 0.9)
	turn("chest", X, breath * 0.03)
	turn("clav_l", Z, breath * 0.02)
	turn("clav_r", Z, -breath * 0.02)
	var want := target_yaw(0.8)
	if unit.target == null or not is_instance_valid(unit.target):
		want = sin(idle_t * 0.23) * 0.4 * (1.0 - walk)
	look_yaw = lerpf(look_yaw, want, delta * 1.5)
	turn("neck", Y, look_yaw * 0.45)
	turn("head", Y, look_yaw * 0.55)


## Beam: the head drives forward and the jaw drops as the light leaves the mask.
func _beam_pose(s: float) -> void:
	var k := bump(s, 0.0, 1.0)
	turn("neck", X, 0.25 * k)
	turn("head", X, -0.15 * k)
	turn("jaw", X, 0.45 * k)
	turn("chest", X, 0.08 * k)


## Titan's Light: rear back and gather (0 .. 2.5 s), then bow the head along the sweep.
func _ray_pose(t: float) -> void:
	var charge := smoothstep(0.0, 2.5, t)
	var sweep := clampf((t - 2.5) / 1.2, 0.0, 1.0)
	var gather := charge * (1.0 - smoothstep(0.0, 0.3, sweep))
	for s: String in ["l", "r"]:
		var sg := 1.0 if s == "l" else -1.0
		turn("uparm_" + s, Z, sg * 0.9 * gather)
		turn("uparm_" + s, X, -0.5 * gather)
		turn("forearm_" + s, X, -0.7 * gather)
	turn("spine", X, -0.28 * gather + 0.2 * sweep)
	turn("chest", X, -0.15 * gather)
	turn("neck", X, -0.3 * gather + lerpf(0.5, 0.15, sweep) * float(t > 2.5))
	turn("jaw", X, 0.55 * maxf(gather * 0.4, float(t > 2.5) * (1.0 - sweep * 0.5)))
	if t < 2.5 and randf() < 0.6:
		# light gathers at the mouth and the core
		var mouth := bone_point("head", MOUTH)
		var c := Defs.team_glow(unit.team)
		var from := mouth + Vector3(randf_range(-6, 6), randf_range(-4, 6), randf_range(-6, 6))
		World.inst.fx.fire_l.emit(from, (mouth - from) * 1.6, 0.6, 0.6, 0.1, Color(c.r, c.g, c.b, 0.7), 0.0)
		if randf() < 0.2:
			World.inst.fx.flash(mouth, c, 2.0 + charge * 3.0)


## The body comes apart: flakes and dark smoke, more of it the lower its health.
func _crumble(delta: float) -> void:
	_crumble_t -= delta
	if _crumble_t > 0.0:
		return
	_crumble_t = lerpf(0.15, 0.8, unit.hp_ratio())
	var bones := ["uparm_l", "uparm_r", "chest", "spine", "forearm_l", "forearm_r", "thigh_l", "thigh_r"]
	var p := bone_point(bones[randi() % bones.size()], Vector3(randf_range(-0.6, 0.6), randf_range(-1.0, 0.0), randf_range(-0.6, 0.6)))
	World.inst.fx.smoke_puff(p, 1.6, 0.35, 0.8)
	if randf() < 0.4:
		World.inst.fx.debris(p, 2, false)


func _die(delta: float) -> void:
	death_t += delta
	var k := clampf(death_t / 1.8, 0.0, 1.0)
	model.rotation.x = 1.3 * k * k
	for s: String in ["l", "r"]:
		turn("uparm_" + s, X, -1.0 * k)
		turn("thigh_" + s, X, -0.5 * k)
		turn("shin_" + s, X, 0.8 * k)
	turn("head", X, 0.35 * k)
	turn("jaw", X, 0.5 * k)
	apply_pose()
	if k >= 1.0 and not _landed:
		_landed = true
		var fwd := Basis(Vector3.UP, unit.facing) * Vector3(0, 0, 1)
		for i in 12:
			World.inst.fx.dust(unit.global_position + fwd * (1.0 + i * 1.2) + Vector3(randf_range(-2.5, 2.5), 0.4, randf_range(-2.5, 2.5)), 6.0)
		World.inst.fx.debris(unit.global_position + fwd * 7.0, 16, true)
		World.inst.sfx.play_at("thud_big", unit.global_position)
		var cam := World.inst.camera
		if cam.focus.distance_to(unit.global_position) < 100.0:
			cam.shake(1.0)
	if death_t > 2.0 and death_t < 8.0 and randf() < delta * 10.0:
		# it crumbles to dust where it fell
		var fwd2 := Basis(Vector3.UP, unit.facing) * Vector3(0, 0, 1)
		World.inst.fx.dust(unit.global_position + fwd2 * randf_range(0.0, 13.0) + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2)), 4.0)
	if death_t > 3.0:
		model.position.y = -(death_t - 3.0) * 0.8

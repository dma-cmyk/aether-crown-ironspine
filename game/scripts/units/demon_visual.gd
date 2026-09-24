class_name DemonVisual
extends CreatureVisual
## Demon: a prowling stride on backward-bent legs, half-spread wings that breathe, a lashing
## tail, alternating raking swipes with the burning claws, a roar with the wings flung open
## for Hellfire, and a collapse on death. The blow lands at the weapon's "delay".

const STRIDE := 5.5
const SWIPE := 0.8
const ROAR := 1.3
## From the wrist to the claw tips (model axes at rest).
const CLAWS := Vector3(0.0, -0.87, 0.4)
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

var phase := 0.0
var swipe_t := -1.0
var swipe_side := "r"
var roar_t := -1.0
var look_yaw := 0.0
var idle_t := 0.0
var _landed := false


func setup(u: Unit) -> void:
	super.setup(u)
	idle_t = randf() * 10.0
	phase = randf()


func muzzle_points(_w: Dictionary, _target: Entity) -> Array[Vector3]:
	return [bone_point("hand_" + swipe_side, CLAWS)]


func on_fire(_w: Dictionary, _target: Entity) -> void:
	swipe_side = "l" if swipe_side == "r" else "r"
	swipe_t = 0.0


func on_special(sid: String) -> void:
	if sid == "hellfire":
		roar_t = 0.0
		swipe_t = -1.0
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
	if swipe_t >= 0.0:
		swipe_t += delta
		if swipe_t > SWIPE:
			swipe_t = -1.0
	if roar_t >= 0.0:
		roar_t += delta
		if roar_t > ROAR:
			roar_t = -1.0
	if not visible:
		return
	_gait(prev)
	_idle(delta)
	if swipe_t >= 0.0:
		_swipe(swipe_t / SWIPE)
	if roar_t >= 0.0:
		_roar(roar_t / ROAR)
	apply_pose()
	_embers(delta)


func _gait(prev: float) -> void:
	var t := phase * TAU
	var w := walk
	for s: String in ["l", "r"]:
		var sg := 1.0 if s == "l" else -1.0
		var sw := sin(t) * 0.55 * w * sg
		var lift := maxf(0.0, cos(t) * sg) * w
		turn("thigh_" + s, X, -sw - lift * 0.45)
		turn("shin_" + s, X, -lift * 0.7)
		turn("foot_" + s, X, sw * 0.4 + lift * 0.3)
	shift("hips", Vector3(sin(t) * 0.08 * w, -absf(sin(t)) * 0.16 * w, 0))
	turn("hips", Y, sin(t) * 0.12 * w)
	turn("spine", Y, -sin(t) * 0.16 * w)
	turn("spine", X, 0.18 * w)
	if swipe_t < 0.0 and roar_t < 0.0:
		turn("uparm_l", X, sin(t) * 0.3 * w)
		turn("uparm_r", X, -sin(t) * 0.3 * w)
		turn("forearm_l", X, -0.35 * w)
		turn("forearm_r", X, -0.35 * w)
	if w > 0.4:
		for k: float in [0.25, 0.75]:
			if prev < k and phase >= k or (prev > phase and k > prev):
				World.inst.fx.dust(bone_point("foot_" + ("l" if k < 0.5 else "r")), 1.4)


func _idle(delta: float) -> void:
	var breath := sin(idle_t * 1.5)
	turn("chest", X, breath * 0.03)
	for s: String in ["l", "r"]:
		var sg := 1.0 if s == "l" else -1.0
		# wings rise and settle with the breath, and fold back a little at a run
		turn("wing_" + s, Z, sg * (breath * 0.06 - walk * 0.1))
		turn("wing_" + s, Y, sg * walk * 0.25)
		turn("f1_" + s, Z, sg * breath * 0.05)
	for i in 4:
		turn("tail%d" % (i + 1), Y, sin(idle_t * 1.7 - i * 0.7) * (0.18 + walk * 0.1))
		turn("tail%d" % (i + 1), X, sin(idle_t * 1.1 - i * 0.5) * 0.06)
	var want := target_yaw(1.0)
	if unit.target == null or not is_instance_valid(unit.target):
		want = sin(idle_t * 0.37) * 0.5 * (1.0 - walk)
	look_yaw = lerpf(look_yaw, want, delta * 3.0)
	turn("neck", Y, look_yaw * 0.4)
	turn("head", Y, look_yaw * 0.6)


## Rake: the arm cocks up and out, then tears across the body; the blow lands at 40 %.
func _swipe(s: float) -> void:
	var sg := 1.0 if swipe_side == "l" else -1.0
	var up := 0.0
	var out := 0.0
	var across := 0.0
	var twist := 0.0
	if s < 0.3:
		var k := ease_out(s / 0.3)
		up = -2.0 * k
		out = 0.7 * k
		twist = 0.35 * k
	elif s < 0.45:
		var k := ease_in((s - 0.3) / 0.15)
		up = lerpf(-2.0, -0.9, k)
		out = lerpf(0.7, -0.3, k)
		across = 0.9 * k
		twist = lerpf(0.35, -0.4, k)
	else:
		var k := smoothstep(0.0, 1.0, (s - 0.45) / 0.55)
		up = lerpf(-0.9, 0.0, k)
		out = lerpf(-0.3, 0.0, k)
		across = lerpf(0.9, 0.0, k)
		twist = lerpf(-0.4, 0.0, k)
	turn("uparm_" + swipe_side, X, up)
	turn("uparm_" + swipe_side, Z, sg * out)
	turn("uparm_" + swipe_side, Y, -sg * across)
	turn("forearm_" + swipe_side, X, -0.5 * absf(up) / 2.0)
	turn("spine", Y, sg * twist)
	turn("chest", X, 0.12 * bump(s, 0.3, 0.7))
	turn("jaw", X, 0.35 * bump(s, 0.25, 0.7))


## Hellfire: rear back, fling the wings and arms wide and roar.
func _roar(s: float) -> void:
	var k := bump(s, 0.0, 1.0)
	var open := ease_out(minf(s / 0.3, 1.0)) * (1.0 - smoothstep(0.7, 1.0, s))
	for side: String in ["l", "r"]:
		var sg := 1.0 if side == "l" else -1.0
		turn("wing_" + side, Z, sg * 0.45 * open)
		turn("wing_" + side, Y, -sg * 0.55 * open)
		turn("wingfore_" + side, Z, sg * 0.3 * open)
		turn("uparm_" + side, Z, sg * 1.1 * open)
		turn("uparm_" + side, X, -0.6 * open)
		turn("forearm_" + side, X, -0.8 * open)
	turn("spine", X, -0.3 * k)
	turn("chest", X, -0.2 * k)
	turn("neck", X, -0.3 * k)
	turn("head", X, -0.25 * k)
	turn("jaw", X, 0.6 * k)


## Glowing sparks drift off the claws and throat now and then.
func _embers(delta: float) -> void:
	if randf() > delta * (6.0 if roar_t >= 0.0 else 1.5):
		return
	var c := DragonVisual.fire_of(unit.team)
	var p := bone_point("hand_" + ("l" if randf() < 0.5 else "r"), CLAWS * 0.6)
	World.inst.fx.fire_l.emit(p, Vector3(randf_range(-0.4, 0.4), randf_range(1.0, 2.2), randf_range(-0.4, 0.4)), 0.7, 0.15, 0.5,
			Color(c.r, c.g, c.b, 0.6), randf_range(-2, 2))


func _die(delta: float) -> void:
	death_t += delta
	var k := clampf(death_t / 1.1, 0.0, 1.0)
	model.rotation.x = 1.35 * k * k
	for s: String in ["l", "r"]:
		var sg := 1.0 if s == "l" else -1.0
		turn("uparm_" + s, X, -1.2 * k)
		turn("wing_" + s, Z, -sg * 0.6 * k)
		turn("wing_" + s, Y, sg * 0.4 * k)
		turn("thigh_" + s, X, -0.6 * k)
		turn("shin_" + s, X, 0.9 * k)
	turn("head", X, 0.4 * k)
	turn("jaw", X, 0.5 * k)
	apply_pose()
	if k >= 1.0 and not _landed:
		_landed = true
		var fwd := Basis(Vector3.UP, unit.facing) * Vector3(0, 0, 1)
		for i in 6:
			World.inst.fx.dust(unit.global_position + fwd * (1.0 + i * 0.9) + Vector3(randf_range(-1.2, 1.2), 0.3, randf_range(-1.2, 1.2)), 3.5)
		World.inst.fx.burn(unit.global_position + fwd * 3.0, 2.5, 3.0, DragonVisual.fire_of(unit.team))
		World.inst.sfx.play_at("thud_big", unit.global_position)
	if death_t > 4.5:
		model.position.y = -(death_t - 4.5) * 0.6

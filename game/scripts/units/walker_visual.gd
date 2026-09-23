class_name WalkerVisual
extends UnitVisual
## Bipedal walker: procedural gait, torso aiming, recoil, crouch and collapse.

var model: Node3D
var hips: Node3D
var torso: Node3D
var legs := {}
var shins := {}
var feet := {}
var rest := {}
var phase := 0.0
var torso_yaw := 0.0
var recoil := 0.0
var crouch := 0.0
var death_t := -1.0
var smoke_t := 0.0
var _last_pos := Vector3.ZERO

const CANNON_MUZZLES := [Vector3(2.7, 2.85, 4.4), Vector3(3.2, 2.85, 4.4)]
const GATLING_MUZZLE := Vector3(-2.9, 0.1, 4.6)


func setup(u: Unit) -> void:
	super.setup(u)
	model = load_model("walker", u.team)
	add_child(model)
	hips = find_node3d(model, "hips")
	torso = find_node3d(model, "torso")
	for s in ["l", "r"]:
		legs[s] = find_node3d(model, "leg_" + s)
		shins[s] = find_node3d(model, "shin_" + s)
		feet[s] = find_node3d(model, "foot_" + s)
	for n in [hips, torso, legs["l"], legs["r"], shins["l"], shins["r"], feet["l"], feet["r"]]:
		rest[n] = n.transform
	_last_pos = u.global_position


func muzzle_points(w: Dictionary, _target: Entity) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if w["id"] == "walker_cannon":
		for p in CANNON_MUZZLES:
			out.append(torso.global_transform * p)
	else:
		out.append(torso.global_transform * GATLING_MUZZLE)
	return out


func on_fire(w: Dictionary, _target: Entity) -> void:
	if w["id"] == "walker_cannon":
		recoil = 1.0


func on_death() -> void:
	death_t = 0.0


func _process(delta: float) -> void:
	if unit == null or hips == null:
		return
	delta = minf(delta, 0.05)
	visible = unit.seen_by_player or unit.team == Defs.TEAM_PLAYER
	if death_t >= 0.0:
		death_t += delta
		var k := clampf(death_t / 1.6, 0.0, 1.0)
		hips.transform = rest[hips].translated(Vector3(0, -2.6 * k * k, 0)).rotated_local(Vector3.RIGHT, 0.5 * k)
		torso.rotation.z = lerpf(torso.rotation.z, 0.35, delta * 2.0)
		if death_t > 1.6:
			model.position.y -= delta * 0.5
		smoke_t -= delta
		if smoke_t <= 0.0 and death_t < 7.0:
			smoke_t = 0.25
			World.inst.fx.smoke(unit.global_position + Vector3(randf_range(-2, 2), 4.0, randf_range(-2, 2)), 2.5, 0.35)
		return
	var gp := unit.get_global_transform_interpolated().origin
	var moved := Vector2(gp.x - _last_pos.x, gp.z - _last_pos.z).length()
	_last_pos = gp
	var spd := moved / maxf(delta, 0.001)
	var walk := clampf(spd / maxf(unit.speed * 0.8, 0.1), 0.0, 1.0)
	phase = fmod(phase + moved / 7.2, 1.0)
	var target_crouch := 1.0 if unit.fortified else 0.0
	crouch = move_toward(crouch, target_crouch, delta * 1.2)
	var t := phase * TAU
	for s in ["l", "r"]:
		var sgn := 1.0 if s == "l" else -1.0
		var swing := sin(t) * 0.42 * walk * sgn
		var lift := maxf(0.0, cos(t) * sgn) * walk
		legs[s].transform = (rest[legs[s]] as Transform3D).rotated_local(Vector3.RIGHT, -swing - crouch * 0.35)
		shins[s].transform = (rest[shins[s]] as Transform3D).rotated_local(Vector3.RIGHT, lift * 0.75 + crouch * 0.7)
		feet[s].transform = (rest[feet[s]] as Transform3D).rotated_local(Vector3.RIGHT, swing - lift * 0.75 - crouch * 0.35)
	var bob := absf(sin(t)) * 0.22 * walk - crouch * 0.9
	hips.transform = (rest[hips] as Transform3D).translated(Vector3(0, bob, 0)).rotated_local(Vector3.FORWARD, sin(t) * 0.035 * walk)
	# torso aims at the current target
	var want := 0.0
	if unit.target and is_instance_valid(unit.target) and unit.target.alive:
		var to := unit.target.global_position - unit.global_position
		want = wrapf(atan2(to.x, to.z) - unit.facing, -PI, PI)
		want = clampf(want, -1.4, 1.4)
	torso_yaw = rotate_toward(torso_yaw, want, delta * 1.8)
	recoil = maxf(0.0, recoil - delta * 3.0)
	torso.transform = (rest[torso] as Transform3D).rotated_local(Vector3.UP, torso_yaw).translated_local(Vector3(0, 0, -recoil * 0.25))
	# damage smoke
	if unit.hp_ratio() < 0.5:
		smoke_t -= delta
		if smoke_t <= 0.0:
			smoke_t = 0.35 if unit.hp_ratio() > 0.25 else 0.15
			World.inst.fx.smoke(torso.global_position + Vector3(0, 3.5, -1.5), 1.6, 0.28)
	if unit.special_time > 0.0 and randf() < delta * 8.0:
		World.inst.fx.flash(torso.global_position + Vector3(randf_range(-2, 2), randf_range(1, 4), randf_range(-2, 2)), Defs.team_glow(unit.team), 1.2)



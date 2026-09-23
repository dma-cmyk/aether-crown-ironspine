class_name CerberusVisual
extends CreatureVisual
## Cerberus: a trot that breaks into a gallop, three heads that look about and bite in turn,
## a howl for Frenzy and a collapse onto its side.

const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK
const HEADS := ["c", "l", "r"]
## From each head bone to the tip of its nose (model axes at rest).
const NOSE := {"c": Vector3(0, -0.1, 0.95), "l": Vector3(0.27, -0.14, 0.87), "r": Vector3(-0.27, -0.14, 0.87)}
const REST_YAW := {"c": 0.0, "l": 0.3, "r": -0.3}
const BITE := 0.35
## Leg phase offsets: trot pairs the diagonals, the gallop runs front then back.
const TROT := {"fl": 0.0, "hr": 0.0, "fr": 0.5, "hl": 0.5}
const GALLOP := {"fl": 0.0, "fr": 0.12, "hr": 0.5, "hl": 0.62}

var phase := 0.0
var bite_t := {"c": -1.0, "l": -1.0, "r": -1.0}
var next_head := 0
var look := {"c": 0.0, "l": 0.0, "r": 0.0}
var wander := {"c": 0.0, "l": 0.0, "r": 0.0}
var wander_t := {"c": 0.0, "l": 0.0, "r": 0.0}
var howl_t := -1.0
var idle_t := 0.0
var _landed := false


func setup(u: Unit) -> void:
	super.setup(u)
	phase = randf()
	idle_t = randf() * 10.0


func muzzle_points(_w: Dictionary, _target: Entity) -> Array[Vector3]:
	var k: String = HEADS[next_head]
	return [bone_point("head_" + k, NOSE[k])]


func on_fire(_w: Dictionary, _target: Entity) -> void:
	bite_t[HEADS[next_head]] = 0.0
	next_head = (next_head + 1) % 3


func on_special(sid: String) -> void:
	if sid == "frenzy":
		howl_t = 0.0
		World.inst.sfx.play_at("howl", unit.global_position)


func _process(delta: float) -> void:
	if unit == null or skel == null:
		return
	delta = minf(delta, 0.05)
	visible = unit.seen_by_player or unit.team == Defs.TEAM_PLAYER
	if death_t >= 0.0:
		_die(delta)
		return
	var moved := stride(delta)
	var gallop := smoothstep(0.5, 0.85, walk)
	phase = fmod(phase + moved / lerpf(3.2, 5.6, gallop), 1.0)
	idle_t += delta
	for k: String in HEADS:
		if bite_t[k] >= 0.0:
			bite_t[k] += delta
			if bite_t[k] > BITE:
				bite_t[k] = -1.0
	if howl_t >= 0.0:
		howl_t += delta
		if howl_t > 1.4:
			howl_t = -1.0
	if not visible:
		return
	_legs(gallop)
	_heads(delta, gallop)
	apply_pose()


func _legs(gallop: float) -> void:
	var w := walk
	for leg: String in ["fl", "fr", "hl", "hr"]:
		var off: float = lerpf(TROT[leg], GALLOP[leg], gallop)
		var t := (phase + off) * TAU
		var swing := sin(t) * w * lerpf(0.45, 0.7, gallop)
		var lift := maxf(0.0, cos(t)) * w
		var s := leg.substr(1, 1)
		if leg.begins_with("f"):
			turn("upper_" + s, X, -swing)
			turn("lower_" + s, X, lift * 1.1)
			turn("paw_" + s, X, lift * 0.6 - swing * 0.3)
		else:
			turn("thigh_" + s, X, -swing)
			turn("shin_" + s, X, -lift * 0.7)
			turn("foot_" + s, X, lift * 0.9 + swing * 0.3)
	var t0 := phase * TAU
	var flex := sin(t0) * 0.12 * gallop * w
	turn("chest", X, flex)
	turn("pelvis", X, -flex * 0.6)
	var bob := -absf(sin(t0 * 2.0)) * 0.08 * w * (1.0 - gallop) + sin(t0) * 0.14 * gallop * w
	shift("pelvis", Vector3(0, bob, 0))
	turn("tail1", X, -0.25 - 0.35 * w)
	turn("tail2", X, 0.15 * w)
	for i in 3:
		turn("tail%d" % (i + 1), Y, sin(idle_t * (2.0 + 4.0 * w) - i * 0.7) * 0.2)


func _heads(delta: float, gallop: float) -> void:
	var frenzy: bool = unit.special_time > 0.0 and unit.def.get("special", "") == "frenzy"
	var howl := bump(howl_t / 1.4, 0.0, 1.0) if howl_t >= 0.0 else 0.0
	var aim := target_yaw(1.1)
	var has_target := unit.target != null and is_instance_valid(unit.target) and unit.target.alive
	var t0 := phase * TAU
	for k: String in HEADS:
		var want: float = aim + REST_YAW[k] * 0.4 if has_target else REST_YAW[k]
		if not has_target:
			wander_t[k] -= delta
			if wander_t[k] <= 0.0:
				wander_t[k] = randf_range(1.0, 3.5)
				wander[k] = randf_range(-0.5, 0.5)
			want += wander[k] * (1.0 - walk)
		look[k] = lerpf(look[k], want, clampf(delta * 5.0, 0.0, 1.0))
		var b := bump(bite_t[k] / BITE, 0.0, 1.0) if bite_t[k] >= 0.0 else 0.0
		var jaw := 0.0
		if bite_t[k] >= 0.0:
			jaw = 0.7 * (1.0 - smoothstep(0.45, 0.7, bite_t[k] / BITE)) * smoothstep(0.0, 0.2, bite_t[k] / BITE)
		if frenzy:
			jaw = maxf(jaw, 0.25 + 0.1 * sin(idle_t * 11.0 + REST_YAW[k] * 9.0))
		jaw = maxf(jaw, 0.45 * howl)
		var nod := sin(t0 * 2.0 + REST_YAW[k] * 3.0) * 0.08 * walk
		turn("neck_" + k, Y, look[k] * 0.5)
		turn("head_" + k, Y, look[k] * 0.5)
		turn("neck_" + k, X, b * 0.4 + nod - howl * 0.6 - 0.1 * gallop * walk)
		turn("head_" + k, X, b * 0.25 - howl * 0.3)
		turn("jaw_" + k, X, jaw)


func _die(delta: float) -> void:
	death_t += delta
	var k := smoothstep(0.0, 1.0, death_t / 0.8)
	model.rotation.z = 1.35 * k
	for s: String in ["l", "r"]:
		turn("upper_" + s, X, -0.3 * k)
		turn("thigh_" + s, X, -0.3 * k)
	for h: String in HEADS:
		turn("neck_" + h, X, 0.5 * k)
		turn("jaw_" + h, X, 0.3 * k)
	apply_pose()
	if k >= 1.0 and not _landed:
		_landed = true
		World.inst.fx.dust(unit.global_position + Vector3(0, 0.5, 0), 3.0)
		World.inst.sfx.play_at("death_small", unit.global_position)
	if death_t > 5.0:
		model.position.y = -(death_t - 5.0) * 0.4

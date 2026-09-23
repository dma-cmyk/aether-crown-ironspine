class_name GriffinVisual
extends FlyerVisual
## Griffin: quick wingbeats, the head locked on its prey, and a stoop that swings the talons
## forward as the strike lands. Keen Sight rears the head for a screech.

const STRIKE := 0.6

var strike_t := -1.0
var screech_t := -1.0
var look := Vector2.ZERO


func setup(u: Unit) -> void:
	super.setup(u)
	wing = {"l": ["wing_l", "wingfore_l", "winghand_l"], "r": ["wing_r", "wingfore_r", "winghand_r"]}
	lags = [0.0, 0.6, 1.1]
	amps = [1.0, 0.5, 0.55]
	glide_pose = [0.1, -0.05, -0.08]
	beat_rate = 1.05
	hover_rate = 1.45
	beat_amp = 0.7
	fold = 0.45
	bob = 0.3


func muzzle_points(_w: Dictionary, _target: Entity) -> Array[Vector3]:
	return [bone_point("talon_l"), bone_point("talon_r")]


func on_fire(_w: Dictionary, _target: Entity) -> void:
	strike_t = 0.0


func on_special(sid: String) -> void:
	if sid == "keen_sight":
		screech_t = 0.0
		World.inst.sfx.play_at("screech", unit.global_position)


func attacking() -> bool:
	return strike_t >= 0.0


func _tick(delta: float) -> void:
	if strike_t >= 0.0:
		strike_t += delta
		if strike_t > STRIKE:
			strike_t = -1.0
	if screech_t >= 0.0:
		screech_t += delta
		if screech_t > 1.2:
			screech_t = -1.0


func _body(ph: float, delta: float) -> void:
	for i in 3:
		turn("tail%d" % (i + 1), Y, sin(ph * 0.5 - i * 0.8) * 0.15)
		turn("tail%d" % (i + 1), X, 0.1 + sin(ph - i * 0.6) * 0.05)
	var reach := bump(strike_t / STRIKE, 0.0, 1.0) if strike_t >= 0.0 else 0.0
	for s: String in ["l", "r"]:
		turn("thigh_" + s, X, 1.0)
		turn("shin_" + s, X, -0.5)
		turn("fleg_" + s, X, lerpf(0.9, -0.7, reach))
		turn("fshin_" + s, X, lerpf(-1.2, 0.2, reach))
		turn("talon_" + s, X, lerpf(0.4, -0.5, reach))
	var want := Vector2.ZERO
	if unit.target and is_instance_valid(unit.target) and unit.target.alive:
		var to := unit.target.global_position - unit.global_position
		want.x = clampf(wrapf(atan2(to.x, to.z) - unit.facing, -PI, PI), -1.0, 1.0)
		want.y = clampf(atan2(-to.y, Vector2(to.x, to.z).length()) * 0.6, -0.3, 0.9)
	look = look.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	var cry := bump(screech_t / 1.2, 0.0, 1.0) if screech_t >= 0.0 else 0.0
	turn("neck1", Y, look.x * 0.35)
	turn("neck2", Y, look.x * 0.35)
	turn("neck1", X, look.y * 0.4 - cry * 0.4)
	turn("neck2", X, look.y * 0.3 - cry * 0.3)
	turn("head", Y, look.x * 0.2)
	turn("head", X, look.y * 0.2 - cry * 0.3)
	turn("jaw", X, 0.55 * cry + 0.25 * reach)
	model.position.y -= 2.4 * reach
	model.rotation.x = 0.35 * reach

class_name AngelVisual
extends FlyerVisual
## Angel: broad slow wingbeats, the robe and legs hanging still below, the lance levelled at
## the target and thrust as the beam leaves its head, and both arms raised for Blessing.

const THRUST := 0.55
const BLESS := 1.4
## From the right wrist to the lance head (model axes at rest).
const LANCE_TIP := Vector3(0.0, -0.47, 2.76)

var thrust_t := -1.0
var bless_t := -1.0
var look := Vector2.ZERO
var sway := 0.0


func setup(u: Unit) -> void:
	super.setup(u)
	wing = {"l": ["wing_l", "wingfore_l", "winghand_l"], "r": ["wing_r", "wingfore_r", "winghand_r"]}
	lags = [0.0, 0.6, 1.1]
	amps = [1.0, 0.5, 0.55]
	glide_pose = [0.15, -0.05, -0.08]
	beat_rate = 0.8
	hover_rate = 1.1
	beat_amp = 0.6
	fold = 0.35
	bob = 0.35
	sway = randf() * 10.0


func muzzle_points(_w: Dictionary, _target: Entity) -> Array[Vector3]:
	return [bone_point("hand_r", LANCE_TIP)]


func on_fire(_w: Dictionary, _target: Entity) -> void:
	thrust_t = 0.0


func on_special(sid: String) -> void:
	if sid == "blessing":
		bless_t = 0.0


func attacking() -> bool:
	return thrust_t >= 0.0 or bless_t >= 0.0


func _tick(delta: float) -> void:
	if thrust_t >= 0.0:
		thrust_t += delta
		if thrust_t > THRUST:
			thrust_t = -1.0
	if bless_t >= 0.0:
		bless_t += delta
		if bless_t > BLESS:
			bless_t = -1.0


func _body(ph: float, delta: float) -> void:
	sway += delta
	# legs hang together inside the robe, trailing a little when flying fast
	for s: String in ["l", "r"]:
		turn("thigh_" + s, X, -0.1 - walk * 0.25 + sin(sway * 1.3) * 0.04)
		turn("shin_" + s, X, 0.2 + walk * 0.2)
		turn("foot_" + s, X, 0.5)
	turn("spine", X, 0.12 * walk + sin(ph - 0.5) * 0.03)
	var want := Vector2.ZERO
	if unit.target and is_instance_valid(unit.target) and unit.target.alive:
		var to := unit.target.global_position - unit.global_position
		want.x = clampf(wrapf(atan2(to.x, to.z) - unit.facing, -PI, PI), -0.9, 0.9)
		want.y = clampf(atan2(-to.y, Vector2(to.x, to.z).length()), -0.3, 1.0)
	look = look.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	turn("neck", Y, look.x * 0.4)
	turn("head", Y, look.x * 0.3)
	turn("head", X, look.y * 0.3)
	# the lance follows the target; a thrust drives it forward
	var jab := bump(thrust_t / THRUST, 0.0, 1.0) if thrust_t >= 0.0 else 0.0
	turn("uparm_r", X, -0.25 - look.y * 0.5 - jab * 0.5)
	turn("uparm_r", Y, -look.x * 0.4)
	turn("forearm_r", X, -0.3 + jab * 0.3)
	turn("spine", Y, look.x * 0.2 - jab * 0.15)
	turn("uparm_l", Z, 0.25 + sin(sway * 0.9) * 0.05)
	turn("forearm_l", X, -0.4)
	if bless_t >= 0.0:
		var k := bump(bless_t / BLESS, 0.0, 1.0)
		for s: String in ["l", "r"]:
			var sg := 1.0 if s == "l" else -1.0
			turn("uparm_" + s, X, -2.4 * k)
			turn("uparm_" + s, Z, sg * 0.5 * k)
		turn("head", X, -0.4 * k)
		turn("chest", X, -0.15 * k)


func _after_pose(delta: float) -> void:
	if bless_t < 0.0 or randf() > delta * 30.0:
		return
	var p := bone_point("head", Vector3(randf_range(-0.6, 0.6), 0.9, randf_range(-0.6, 0.6)))
	World.inst.fx.sparkle(p, Color(1.0, 0.92, 0.65))

class_name DragonVisual
extends FlyerVisual
## Dragon: slow deep wingbeats, sinuous neck and tail, legs tucked in flight, and a breath of
## fire that streams from the jaws to the target (aether-blue for the Crown).

const BREATH := 1.1
## From the head bone to the tip of the jaws (model axes at rest).
const MOUTH := Vector3(0, -0.3, 1.85)

var breath_t := -1.0
var breath_at := Vector3.INF
var look := Vector2.ZERO
var _emit := 0.0


func setup(u: Unit) -> void:
	super.setup(u)
	wing = {"l": ["humerus_l", "forearm_l", "f1_l", "f2_l", "f3_l"], "r": ["humerus_r", "forearm_r", "f1_r", "f2_r", "f3_r"]}
	beat_rate = 0.62
	hover_rate = 0.85
	beat_amp = 0.6
	bob = 0.45


func muzzle_points(_w: Dictionary, _target: Entity) -> Array[Vector3]:
	return [bone_point("head", MOUTH)]


func special_point() -> Vector3:
	return bone_point("head", MOUTH)


func on_fire(_w: Dictionary, target: Entity) -> void:
	breath_t = 0.0
	breath_at = target.global_position


func on_special_at(sid: String, at: Vector3) -> void:
	if sid == "inferno":
		breath_t = 0.0
		breath_at = at


func attacking() -> bool:
	return breath_t >= 0.0


func flame_color() -> Color:
	return DragonVisual.fire_of(unit.team)


## Aether-blue fire for the Crown, ordinary flame for everyone else.
static func fire_of(team: int) -> Color:
	return Color(0.28, 0.58, 1.0) if team == Defs.TEAM_PLAYER else Color(1.0, 0.42, 0.1)


func _tick(delta: float) -> void:
	if breath_t < 0.0:
		return
	breath_t += delta
	if breath_t > BREATH:
		breath_t = -1.0
		breath_at = Vector3.INF
	elif unit.target and is_instance_valid(unit.target) and unit.target.alive and breath_at.distance_to(unit.target.global_position) < 12.0:
		breath_at = unit.target.global_position


func _body(ph: float, delta: float) -> void:
	# tail and neck sway; legs tucked back
	for i in 6:
		turn("tail%d" % (i + 1), Y, sin(ph * 0.5 - i * 0.7) * 0.09)
		turn("tail%d" % (i + 1), X, sin(ph - i * 0.6) * 0.04)
	for s: String in ["l", "r"]:
		turn("thigh_" + s, X, 0.9)
		turn("shin_" + s, X, -0.6)
		turn("foot_" + s, X, 0.5)
		turn("arm_" + s, X, 0.8)
		turn("paw_" + s, X, -0.7)
	var want := Vector2.ZERO
	var target := breath_at
	if breath_t < 0.0 and unit.target and is_instance_valid(unit.target) and unit.target.alive:
		target = unit.target.global_position
	if target != Vector3.INF:
		var to := target - unit.global_position
		want.x = clampf(wrapf(atan2(to.x, to.z) - unit.facing, -PI, PI), -1.0, 1.0)
		want.y = clampf(atan2(-to.y, Vector2(to.x, to.z).length()) * 0.8, -0.2, 1.1)
	look = look.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	var rear := 0.0
	var jaw := 0.0
	if breath_t >= 0.0:
		var s := breath_t / BREATH
		rear = bump(s, 0.0, 0.4) * 0.35
		jaw = 0.55 * bump(s, 0.18, 1.0)
	var neck_pitch := 0.05 + sin(ph) * 0.03
	for n: String in ["neck1", "neck2", "neck3"]:
		turn(n, Y, look.x * 0.28)
		turn(n, X, look.y * 0.3 - rear + neck_pitch)
	turn("head", Y, look.x * 0.16)
	turn("head", X, look.y * 0.15 + rear * 0.8)
	turn("jaw", X, jaw)


func _after_pose(delta: float) -> void:
	if breath_t < 0.25 or breath_t > 0.9 or breath_at == Vector3.INF:
		return
	var mouth := bone_point("head", MOUTH)
	var to := breath_at - mouth
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	var c := flame_color()
	var fx := World.inst.fx
	_emit += delta * 80.0
	while _emit >= 1.0:
		_emit -= 1.0
		var v := dir * 34.0 + Vector3(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5), randf_range(-2.5, 2.5))
		var life := dist / 34.0 * randf_range(0.8, 1.05) + 0.08
		var hot := Color(c.r, c.g, c.b, 0.5).lerp(Color(1.0, 0.9, 0.7, 0.6), randf() * 0.25)
		fx.fire_l.emit(mouth + dir * randf() * 0.8, v, life, 0.4, 2.4, hot, randf_range(-3, 3))
	if randf() < delta * 20.0:
		fx.flash(mouth, c, 1.4)

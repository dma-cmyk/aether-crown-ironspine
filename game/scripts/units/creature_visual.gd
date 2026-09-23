class_name CreatureVisual
extends UnitVisual
## Skinned creature: loads the rig and poses bones by turning them about model-space axes.
## Subclasses build the gait, attacks and death from turn() / shift() calls, then apply_pose().

var model: Node3D
var skel: Skeleton3D
var death_t := -1.0
## 0 standing .. 1 full stride, smoothed from the actual ground speed.
var walk := 0.0
var _bones := {}
var _rest := {}
var _rest_pos := {}
var _to_local := {}
var _pose := {}
var _shift := {}
var _last_pos := Vector3.ZERO


func setup(u: Unit) -> void:
	super.setup(u)
	model = load_model(u.def["model"], u.team)
	add_child(model)
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	for i in skel.get_bone_count():
		_bones[skel.get_bone_name(i)] = i
		var r := skel.get_bone_rest(i)
		_rest[i] = r.basis.get_rotation_quaternion()
		_rest_pos[i] = r.origin
		_to_local[i] = skel.get_bone_global_rest(i).basis.orthonormalized().inverse()
	_last_pos = u.global_position


func on_death() -> void:
	death_t = 0.0


## Rotate a bone about a model-space axis (as the bone sits at rest). Turns add up within a frame.
func turn(bone: String, axis: Vector3, angle: float) -> void:
	var i: int = _bones.get(bone, -1)
	if i < 0 or absf(angle) < 0.0001:
		return
	var local: Vector3 = ((_to_local[i] as Basis) * axis).normalized()
	_pose[i] = (_pose.get(i, Quaternion.IDENTITY) as Quaternion) * Quaternion(local, angle)


## Move a bone by a model-space offset (measured in its parent's rest frame).
func shift(bone: String, offset: Vector3) -> void:
	var i: int = _bones.get(bone, -1)
	if i < 0:
		return
	var p := skel.get_bone_parent(i)
	var local: Vector3 = offset if p < 0 else (_to_local[p] as Basis) * offset
	_shift[i] = (_shift.get(i, Vector3.ZERO) as Vector3) + local


func apply_pose() -> void:
	for i: int in _rest:
		skel.set_bone_pose_rotation(i, (_rest[i] as Quaternion) * (_pose.get(i, Quaternion.IDENTITY) as Quaternion))
		skel.set_bone_pose_position(i, (_rest_pos[i] as Vector3) + (_shift.get(i, Vector3.ZERO) as Vector3))
	_pose.clear()
	_shift.clear()


## World position of a point given in model-space axes relative to the bone's head.
func bone_point(bone: String, offset := Vector3.ZERO) -> Vector3:
	var i: int = _bones.get(bone, -1)
	if i < 0:
		return unit.aim_point()
	var g := skel.get_bone_global_pose(i)
	return skel.global_transform * (g.origin + g.basis * ((_to_local[i] as Basis) * offset))


## Updates `walk` from how far the unit moved and returns the distance covered this frame.
func stride(delta: float) -> float:
	var gp := unit.get_global_transform_interpolated().origin
	var moved := Vector2(gp.x - _last_pos.x, gp.z - _last_pos.z).length()
	_last_pos = gp
	var want := clampf(moved / maxf(delta, 0.001) / maxf(unit.speed * 0.8, 0.1), 0.0, 1.0)
	walk = lerpf(walk, want, clampf(delta * 6.0, 0.0, 1.0))
	return moved


## Yaw (radians, relative to the body) toward the current target, 0 without one.
func target_yaw(limit: float) -> float:
	if unit.target == null or not is_instance_valid(unit.target) or not unit.target.alive:
		return 0.0
	var to := unit.target.global_position - unit.global_position
	return clampf(wrapf(atan2(to.x, to.z) - unit.facing, -PI, PI), -limit, limit)


static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)


static func ease_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t


## 0 -> 1 -> 0 over [a, b] with a smooth rise and fall.
static func bump(t: float, a: float, b: float) -> float:
	if t <= a or t >= b:
		return 0.0
	return sin((t - a) / (b - a) * PI)

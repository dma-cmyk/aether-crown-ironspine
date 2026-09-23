class_name VehicleVisual
extends UnitVisual
## Self-propelled mortar: turret yaw, barrel elevation, stabiliser legs, track wobble.

var model: Node3D
var chassis: Node3D
var turret: Node3D
var barrel: Node3D
var legs: Array[Node3D] = []
var rest := {}
var turret_yaw := 0.0
var elevation := 0.25
var deploy_k := 0.0
var recoil := 0.0
var death_t := -1.0
var smoke_t := 0.0
var bob_t := 0.0


func setup(u: Unit) -> void:
	super.setup(u)
	model = load_model("mortar", u.team)
	add_child(model)
	chassis = find_node3d(model, "chassis")
	turret = find_node3d(model, "turret")
	barrel = find_node3d(model, "barrel")
	for n in ["leg_fl", "leg_fr", "leg_bl", "leg_br"]:
		var l := find_node3d(model, n)
		if l:
			legs.append(l)
			rest[l] = l.transform
	rest[barrel] = barrel.transform
	rest[chassis] = chassis.transform


func muzzle_points(_w: Dictionary, _target: Entity) -> Array[Vector3]:
	return [barrel.global_transform * Vector3(0, 0, 2.3)]


func on_fire(_w: Dictionary, _target: Entity) -> void:
	recoil = 1.0


func on_death() -> void:
	death_t = 0.0


func _process(delta: float) -> void:
	if unit == null or turret == null:
		return
	delta = minf(delta, 0.05)
	visible = unit.seen_by_player or unit.team == Defs.TEAM_PLAYER
	if death_t >= 0.0:
		death_t += delta
		model.rotation.z = lerpf(model.rotation.z, 0.25, delta)
		model.position.y = -minf(death_t * 0.25, 1.2)
		smoke_t -= delta
		if smoke_t <= 0.0 and death_t < 7.0:
			smoke_t = 0.3
			World.inst.fx.smoke(unit.global_position + Vector3(0, 2.5, 0), 1.8, 0.3)
		return
	var want_deploy := 1.0 if (unit.deployed or unit.setup_goal == "deploy") else 0.0
	deploy_k = move_toward(deploy_k, want_deploy, delta * 0.6)
	var fold := (1.0 - deploy_k) * 1.2
	for l in legs:
		var sx := -1.0 if l.name.ends_with("l") else 1.0
		l.transform = (rest[l] as Transform3D).rotated_local(Vector3.FORWARD, fold * sx)
	var want_yaw := 0.0
	var want_elev := 0.25
	if unit.target and is_instance_valid(unit.target) and unit.target.alive:
		var to := unit.target.global_position - unit.global_position
		want_yaw = wrapf(atan2(to.x, to.z) - unit.facing, -PI, PI)
		var d := Vector2(to.x, to.z).length()
		want_elev = clampf(0.95 - d / 120.0, 0.35, 1.05)
	turret_yaw = rotate_toward(turret_yaw, want_yaw, delta * 1.5)
	turret.rotation.y = turret_yaw
	elevation = move_toward(elevation, want_elev, delta * 0.8)
	recoil = maxf(0.0, recoil - delta * 2.5)
	barrel.transform = (rest[barrel] as Transform3D).rotated_local(Vector3.RIGHT, -elevation).translated_local(Vector3(0, 0, -recoil * 0.5))
	bob_t += delta * (8.0 if unit.moving else 0.0)
	chassis.transform = (rest[chassis] as Transform3D).translated(Vector3(0, sin(bob_t) * 0.04, 0)).rotated_local(Vector3.RIGHT, sin(bob_t * 0.5) * 0.01)
	if unit.moving and randf() < delta * 6.0:
		World.inst.fx.dust(unit.global_position + Vector3(randf_range(-1.5, 1.5), 0.3, -1.8).rotated(Vector3.UP, unit.facing), 1.2)
	if unit.hp_ratio() < 0.5:
		smoke_t -= delta
		if smoke_t <= 0.0:
			smoke_t = 0.4
			World.inst.fx.smoke(unit.global_position + Vector3(0, 2.8, 0), 1.2, 0.25)

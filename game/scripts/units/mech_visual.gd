class_name MechVisual
extends UnitVisual
## Flying mech: hovers on its thruster pack, leans into flight and banks through turns, legs
## trailing behind; the rifle arm follows the target and the shoulder pods kick back as the
## missiles leave. Thrusters burn in the team's glow. Falls, burning, when destroyed.

## Missile tubes on each pod, relative to the pod's pivot (model axes).
const TUBES := [Vector3(-0.15, -0.03, 0.7), Vector3(0.25, -0.03, 0.7), Vector3(-0.15, 0.33, 0.7), Vector3(0.25, 0.33, 0.7)]
const NOZZLES := [Vector3(0.5, 0.05, -1.52), Vector3(-0.5, 0.05, -1.52)]

var model: Node3D
var body: Node3D
var parts := {}
var rest := {}
var bob := 0.0
var bank := 0.0
var walk := 0.0
var recoil := 0.0
var aim := Vector2.ZERO
var last_facing := 0.0
var death_t := -1.0
var smoke_t := 0.0
var _salvo := 0
var _last_pos := Vector3.ZERO
var shadow: MeshInstance3D


func setup(u: Unit) -> void:
	super.setup(u)
	model = load_model("mech", u.team)
	model.scale = Vector3.ONE * 1.25
	add_child(model)
	body = find_node3d(model, "body")
	for n in ["pod_l", "pod_r", "arm_l", "arm_r", "leg_l", "leg_r"]:
		parts[n] = find_node3d(model, n)
		rest[n] = (parts[n] as Node3D).transform
	last_facing = u.facing
	bob = randf() * TAU
	_last_pos = u.global_position
	shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4.0, 3.0)
	q.orientation = PlaneMesh.FACE_Y
	shadow.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/blob_shadow.gdshader")
	shadow.material_override = m
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.top_level = true
	add_child(shadow)


## Two missiles per volley, from alternate tubes of each pod.
func muzzle_points(_w: Dictionary, _target: Entity) -> Array[Vector3]:
	_salvo = (_salvo + 1) % 4
	var out: Array[Vector3] = []
	for n in ["pod_l", "pod_r"]:
		var t: Vector3 = TUBES[_salvo]
		out.append((parts[n] as Node3D).global_transform * Vector3(t.x * (1.0 if n == "pod_l" else -1.0), t.y, t.z))
	return out


func special_point() -> Vector3:
	_salvo = (_salvo + 1) % 4
	recoil = 1.0
	var n := "pod_l" if _salvo % 2 == 0 else "pod_r"
	var t: Vector3 = TUBES[_salvo]
	return (parts[n] as Node3D).global_transform * Vector3(t.x * (1.0 if n == "pod_l" else -1.0), t.y, t.z)


func on_fire(_w: Dictionary, _target: Entity) -> void:
	recoil = 1.0


func on_death() -> void:
	death_t = 0.0


func _process(delta: float) -> void:
	if unit == null or body == null:
		return
	delta = minf(delta, 0.05)
	visible = unit.seen_by_player or unit.team == Defs.TEAM_PLAYER
	if death_t >= 0.0:
		_fall(delta)
		return
	var gp := unit.get_global_transform_interpolated().origin
	var moved := Vector2(gp.x - _last_pos.x, gp.z - _last_pos.z).length()
	_last_pos = gp
	walk = lerpf(walk, clampf(moved / maxf(delta, 0.001) / maxf(unit.speed * 0.8, 0.1), 0.0, 1.0), clampf(delta * 4.0, 0.0, 1.0))
	bob += delta * 1.6
	var turn_rate := angle_difference(last_facing, unit.facing) / maxf(delta, 0.001)
	last_facing = unit.facing
	bank = lerpf(bank, clampf(-turn_rate * 0.35, -0.4, 0.4), clampf(delta * 2.5, 0.0, 1.0))
	model.position.y = sin(bob) * 0.25
	model.rotation = Vector3(walk * 0.4 + sin(bob * 0.5) * 0.02, 0.0, bank)
	var g := World.inst.terrain.ground_at(unit.global_position.x, unit.global_position.z)
	shadow.global_position = Vector3(unit.global_position.x, g + 0.3, unit.global_position.z)
	shadow.global_rotation = Vector3(0, unit.facing, 0)
	shadow.visible = visible
	if not visible:
		return
	# legs trail in flight; the rifle arm tracks the target
	var sway := sin(bob * 0.8) * 0.05
	for s: String in ["l", "r"]:
		var leg: Node3D = parts["leg_" + s]
		leg.transform = (rest["leg_" + s] as Transform3D).rotated_local(Vector3.RIGHT, walk * 0.55 + sway * (1.0 if s == "l" else -1.0))
	var want := Vector2.ZERO
	if unit.target and is_instance_valid(unit.target) and unit.target.alive:
		var to := unit.target.aim_point() - unit.global_position
		want.x = clampf(wrapf(atan2(to.x, to.z) - unit.facing, -PI, PI), -0.8, 0.8)
		want.y = clampf(atan2(-to.y, Vector2(to.x, to.z).length()) - walk * 0.4, -0.6, 1.2)
	aim = aim.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	(parts["arm_r"] as Node3D).transform = (rest["arm_r"] as Transform3D).rotated_local(Vector3.UP, aim.x).rotated_local(Vector3.RIGHT, aim.y)
	(parts["arm_l"] as Node3D).transform = (rest["arm_l"] as Transform3D).rotated_local(Vector3.FORWARD, -0.15 - walk * 0.2)
	recoil = maxf(0.0, recoil - delta * 4.0)
	for n in ["pod_l", "pod_r"]:
		(parts[n] as Node3D).transform = (rest[n] as Transform3D).translated_local(Vector3(0, 0, -0.25 * recoil))
	_thrust(delta)
	if unit.hp_ratio() < 0.5:
		smoke_t -= delta
		if smoke_t <= 0.0:
			smoke_t = 0.3 if unit.hp_ratio() > 0.25 else 0.12
			World.inst.fx.smoke(body.global_position + Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1)), 1.4, 0.28)


## Exhaust from the two back nozzles, stronger at speed.
func _thrust(delta: float) -> void:
	var c := Defs.team_glow(unit.team)
	var down := body.global_transform.basis * Vector3(0, -0.94, -0.34)
	for nz: Vector3 in NOZZLES:
		if randf() > delta * lerpf(18.0, 40.0, walk):
			continue
		var p := body.global_transform * nz
		World.inst.fx.fire_l.emit(p, down * randf_range(6.0, 9.0) + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)),
				0.22, 0.35, 0.9, Color(c.r, c.g, c.b, 0.55), randf_range(-3, 3))


func _fall(delta: float) -> void:
	death_t += delta
	shadow.visible = false
	var ground := World.inst.terrain.height_at(unit.global_position.x, unit.global_position.z)
	model.position.y = maxf(ground - unit.global_position.y + 1.5, -death_t * death_t * 5.0)
	model.rotation.x = lerpf(model.rotation.x, 1.2, delta * 1.2)
	model.rotation.z = lerpf(model.rotation.z, 0.6, delta)
	smoke_t -= delta
	if smoke_t <= 0.0 and death_t < 30.0:
		smoke_t = 0.1
		World.inst.fx.smoke(body.global_position + Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)), 1.8, 0.4)
		if randf() < 0.3:
			World.inst.fx.fire(body.global_position, 1.0)
	if model.global_position.y <= ground + 2.0 and death_t < 50.0:
		death_t = 50.0
		World.inst.fx.explosion(model.global_position, 2.6)
		World.inst.fx.debris(model.global_position, 8, true)
		World.inst.sfx.play_at("explosion_big", model.global_position)
		World.inst.camera.shake(0.5)

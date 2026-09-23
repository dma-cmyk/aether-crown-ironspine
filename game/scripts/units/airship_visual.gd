class_name AirshipVisual
extends UnitVisual
## Skyfrigate: bobbing, banking, spinning propellers, crash on death, ground shadow.

var model: Node3D
var props: Array[Node3D] = []
var bob := 0.0
var bank := 0.0
var last_facing := 0.0
var death_t := -1.0
var smoke_t := 0.0
var shadow: MeshInstance3D

const GUNS := [Vector3(1.8, -5.1, -2.5), Vector3(1.8, -5.1, -0.1), Vector3(1.8, -5.1, 2.3)]
const SCALE := 0.62


func setup(u: Unit) -> void:
	super.setup(u)
	model = load_model("airship", u.team)
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	for n in ["prop_l", "prop_r"]:
		var p := find_node3d(model, n)
		if p:
			props.append(p)
	last_facing = u.facing
	bob = randf() * TAU
	shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(6, 16)
	q.orientation = PlaneMesh.FACE_Y
	shadow.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/blob_shadow.gdshader")
	shadow.material_override = m
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.top_level = true
	add_child(shadow)


func muzzle_points(w: Dictionary, target: Entity) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var side := 1.0
	if target and is_instance_valid(target):
		var local := global_transform.affine_inverse() * target.global_position
		side = 1.0 if local.x >= 0.0 else -1.0
	if w["id"] == "flak":
		out.append(global_transform * (Vector3(0, 2.8, 4.0) * SCALE))
		return out
	for g in GUNS:
		out.append(global_transform * (Vector3(g.x * side, g.y, g.z) * SCALE))
	return out


func on_death() -> void:
	death_t = 0.0


func _process(delta: float) -> void:
	if unit == null:
		return
	delta = minf(delta, 0.05)
	visible = unit.seen_by_player or unit.team == Defs.TEAM_PLAYER
	for p in props:
		p.rotate_object_local(Vector3.FORWARD, delta * (14.0 if unit.moving else 6.0))
	if death_t >= 0.0:
		death_t += delta
		var ground := World.inst.terrain.height_at(unit.global_position.x, unit.global_position.z)
		model.position.y = maxf(ground - unit.global_position.y + 1.0, -death_t * death_t * 3.0)
		model.rotation.x = lerpf(model.rotation.x, 0.45, delta * 0.6)
		model.rotation.z = lerpf(model.rotation.z, 0.3, delta * 0.4)
		smoke_t -= delta
		if smoke_t <= 0.0:
			smoke_t = 0.12
			World.inst.fx.smoke(model.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-6, 6)), 3.0, 0.4)
			if randf() < 0.3:
				World.inst.fx.fire(model.global_position + Vector3(randf_range(-2, 2), 1, randf_range(-5, 5)), 1.5)
		if model.global_position.y <= ground + 1.5 and death_t < 50.0:
			death_t = 50.0
			World.inst.fx.explosion(model.global_position, 3.5)
			World.inst.camera.shake(1.0)
			World.inst.sfx.play_at("explosion_big", model.global_position)
		shadow.visible = false
		return
	bob += delta * 0.9
	var turn := angle_difference(last_facing, unit.facing) / maxf(delta, 0.001)
	last_facing = unit.facing
	bank = lerpf(bank, clampf(-turn * 0.35, -0.3, 0.3), delta * 2.0)
	model.position.y = sin(bob) * 0.5
	model.rotation.z = bank
	model.rotation.x = sin(bob * 0.7) * 0.02
	var g := World.inst.terrain.ground_at(unit.global_position.x, unit.global_position.z)
	shadow.global_position = Vector3(unit.global_position.x, g + 0.3, unit.global_position.z)
	shadow.global_rotation = Vector3(0, unit.facing, 0)
	shadow.visible = visible
	if unit.hp_ratio() < 0.5:
		smoke_t -= delta
		if smoke_t <= 0.0:
			smoke_t = 0.3
			World.inst.fx.smoke(model.global_position + Vector3(randf_range(-2, 2), 1.0, randf_range(-5, 5)), 2.0, 0.25)

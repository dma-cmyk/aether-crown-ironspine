class_name GearforgeVisual
extends UnitVisual
## The Gearforge machines (strider, quad walker, colossus, dreadnought). One script reads the
## parts each model has: legs split at knee and ankle (leg_/shin_/foot_ + l, r or fl, fr, rl, rr),
## a turret or torso that turns to the target, guns that recoil, a cannon that elevates,
## propellers, and anchor empties for muzzles and exhausts. Walkers step, stomp and collapse;
## the airship bobs, banks and crashes.

var model: Node3D
var body: Node3D  # hull or hips: bobs with the gait
var aim_part: Node3D  # turret or torso: yaws to the target
var cannon: Node3D
var brace: Node3D
var guns: Array[Node3D] = []
var props: Array[Node3D] = []
var legs := {}  # side -> [thigh, shin, foot]
var rest := {}
var anchors := {}
var phase := 0.0
var stride := 4.0
var aim_yaw := 0.0
var elevation := 0.0
var recoil := {}
var death_t := -1.0
var smoke_t := 0.0
var steam_t := 0.0
var bob := 0.0
var bank := 0.0
var last_facing := 0.0
var shadow: MeshInstance3D
var _last_pos := Vector3.ZERO
var _broadside := 0

const QUAD_PHASE := {"fl": 0.0, "rr": 0.0, "fr": 0.5, "rl": 0.5}


func setup(u: Unit) -> void:
	super.setup(u)
	model = load_model(u.def["model"], u.team)
	model.scale = Vector3.ONE * float(u.def.get("scale", 1.0))
	add_child(model)
	stride = float(u.def.get("stride", 4.0))
	for n in ["hull", "hips"]:
		body = body if body else find_node3d(model, n)
	for n in ["turret", "torso"]:
		aim_part = aim_part if aim_part else find_node3d(model, n)
	cannon = find_node3d(model, "cannon")
	brace = find_node3d(model, "brace")
	for s in ["l", "r", "fl", "fr", "rl", "rr"]:
		var thigh := find_node3d(model, "leg_" + s)
		if thigh:
			legs[s] = [thigh, find_node3d(model, "shin_" + s), find_node3d(model, "foot_" + s)]
	for n in ["gun_l", "gun_r"]:
		var g := find_node3d(model, n)
		if g:
			guns.append(g)
	for n in ["prop_l", "prop_r"]:
		var p := find_node3d(model, n)
		if p:
			props.append(p)
	for n: Node in model.find_children("*", "Node3D", true, false):
		if not n is MeshInstance3D:
			anchors[n.name] = n
	for n: Node3D in [body, aim_part, cannon, brace] + guns:
		if n:
			rest[n] = n.transform
	for s in legs:
		for n: Node3D in legs[s]:
			if n:
				rest[n] = n.transform
	_last_pos = u.global_position
	last_facing = u.facing
	bob = randf() * TAU
	if u.is_air:
		_make_shadow()


func _make_shadow() -> void:
	shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	var box := Unit._model_box(model)
	q.size = Vector2(box.x * 2.2, box.z * 2.2)
	q.orientation = PlaneMesh.FACE_Y
	shadow.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/blob_shadow.gdshader")
	shadow.material_override = m
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.top_level = true
	add_child(shadow)


## Muzzles are the anchors the weapon lists (a prefix like "gun_" takes them all); broadside
## guns fire from the side facing the target.
func muzzle_points(w: Dictionary, target: Entity) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var side := ""
	if w.get("broadside", false) and target and is_instance_valid(target):
		var local := global_transform.affine_inverse() * target.global_position
		side = "r" if local.x > 0.0 else "l"  # "_l" parts sit at -x, as the old scripts built them
	for key: String in w.get("anchors", ["muzzle"]):
		for n: String in anchors:
			if n == key or (key.ends_with("_") and n.begins_with(key) and (side == "" or n.substr(key.length(), 1) == side)):
				out.append((anchors[n] as Node3D).global_position)
	if out.is_empty():
		out.append(unit.aim_point())
	return out


func special_point() -> Vector3:
	return (anchors["muzzle"] as Node3D).global_position if anchors.has("muzzle") else unit.aim_point()


func on_fire(w: Dictionary, _target: Entity) -> void:
	for key: String in w.get("anchors", []):
		if key == "muzzle_l" or key == "muzzle_r":
			recoil[key.substr(7)] = 1.0
		elif key == "muzzle":
			recoil["main"] = 1.0


func on_death() -> void:
	death_t = 0.0


func _process(delta: float) -> void:
	if unit == null or model == null:
		return
	delta = minf(delta, 0.05)
	visible = unit.seen_by_player or unit.team == Defs.TEAM_PLAYER
	for p in props:
		p.rotate_object_local(Vector3.FORWARD, delta * (16.0 if unit.moving else 7.0))
	if unit.is_air:
		_fly(delta)
	else:
		_walk(delta)
	if death_t >= 0.0:
		return
	_aim(delta)
	_exhaust(delta)


func _walk(delta: float) -> void:
	if death_t >= 0.0:
		_collapse(delta)
		return
	var gp := unit.get_global_transform_interpolated().origin
	var moved := Vector2(gp.x - _last_pos.x, gp.z - _last_pos.z).length()
	_last_pos = gp
	var spd := moved / maxf(delta, 0.001)
	var walk := clampf(spd / maxf(unit.speed * 0.8, 0.1), 0.0, 1.0)
	var was := phase
	phase = fmod(phase + moved / stride, 1.0)
	var crouch := 1.0 if unit.fortified else 0.0
	for s: String in legs:
		var off: float = QUAD_PHASE.get(s, 0.0 if s == "l" else 0.5)
		var t := fmod(phase + off, 1.0) * TAU
		var swing := sin(t) * 0.38 * walk
		var lift := maxf(0.0, cos(t)) * walk
		var p: Array = legs[s]
		var front := 1.0 if s.begins_with("f") or s.length() == 1 else -1.0
		(p[0] as Node3D).transform = (rest[p[0]] as Transform3D).rotated_local(Vector3.RIGHT, -swing - crouch * 0.25 * front)
		if p[1]:
			(p[1] as Node3D).transform = (rest[p[1]] as Transform3D).rotated_local(Vector3.RIGHT, lift * 0.6 + crouch * 0.45 * front)
		if p[2]:
			(p[2] as Node3D).transform = (rest[p[2]] as Transform3D).rotated_local(Vector3.RIGHT, swing - lift * 0.6 - crouch * 0.2 * front)
	# A servo click and metal step lands with the procedural gait, including lighter walkers.
	var landed := walk > 0.3 and fmod(was + 0.25, 0.5) > fmod(phase + 0.25, 0.5)
	if landed and visible:
		World.inst.sfx.play_at("robot_step_heavy" if unit.height > 6.0 else "robot_step", unit.global_position, -6.0)
	if landed and unit.height > 6.0:
		World.inst.fx.dust(unit.global_position + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2)), 1.6)
		if unit.team == Defs.TEAM_PLAYER or unit.seen_by_player:
			World.inst.camera.shake(0.08)
	elif walk > 0.3 and randf() < delta * 3.0:
		World.inst.fx.dust(unit.global_position + Vector3(randf_range(-1.5, 1.5), 0.3, randf_range(-1.5, 1.5)), 0.9)
	if body:
		var t := phase * TAU * (2.0 if legs.size() == 2 else 4.0)
		var b := (absf(sin(t * 0.5)) * 0.012 * walk - crouch * 0.05) * unit.height
		body.transform = (rest[body] as Transform3D).translated(Vector3(0, b, 0)).rotated_local(Vector3.FORWARD, sin(phase * TAU) * 0.03 * walk)
	if unit.hp_ratio() < 0.5:
		smoke_t -= delta
		if smoke_t <= 0.0:
			smoke_t = 0.35 if unit.hp_ratio() > 0.25 else 0.15
			World.inst.fx.smoke(unit.global_position + Vector3(0, unit.height * 0.7, 0), unit.height * 0.25, 0.28)


func _collapse(delta: float) -> void:
	death_t += delta
	var k := clampf(death_t / 1.8, 0.0, 1.0)
	if body:
		body.transform = (rest[body] as Transform3D).translated(Vector3(0, -unit.height * 0.3 * k * k, 0)).rotated_local(Vector3.RIGHT, 0.35 * k)
	if aim_part:
		aim_part.rotation.z = lerpf(aim_part.rotation.z, 0.3, delta * 1.5)
	for s: String in legs:
		var p: Array = legs[s]
		if p[1]:
			(p[1] as Node3D).transform = (rest[p[1]] as Transform3D).rotated_local(Vector3.RIGHT, 0.9 * k)
	if death_t > 1.8:
		model.position.y -= delta * 0.4
	smoke_t -= delta
	if smoke_t <= 0.0 and death_t < 7.0:
		smoke_t = 0.25
		World.inst.fx.smoke(unit.global_position + Vector3(randf_range(-2, 2), unit.height * 0.5, randf_range(-2, 2)), unit.height * 0.3, 0.35)


func _fly(delta: float) -> void:
	if death_t >= 0.0:
		death_t += delta
		var ground := World.inst.terrain.height_at(unit.global_position.x, unit.global_position.z)
		model.position.y = maxf(ground - unit.global_position.y + 2.0, -death_t * death_t * 2.5)
		model.rotation.x = lerpf(model.rotation.x, 0.35, delta * 0.5)
		model.rotation.z = lerpf(model.rotation.z, 0.25, delta * 0.35)
		smoke_t -= delta
		if smoke_t <= 0.0:
			smoke_t = 0.1
			World.inst.fx.smoke(model.global_position + Vector3(randf_range(-4, 4), 1, randf_range(-10, 10)), 3.5, 0.4)
			if randf() < 0.35:
				World.inst.fx.fire(model.global_position + Vector3(randf_range(-3, 3), 1, randf_range(-8, 8)), 2.0)
		if model.global_position.y <= ground + 3.0 and death_t < 50.0:
			death_t = 50.0
			World.inst.fx.explosion(model.global_position, 5.0)
			World.inst.camera.shake(1.4)
			World.inst.sfx.play_at("explosion_big", model.global_position)
		shadow.visible = false
		return
	bob += delta * 0.6
	var turn := angle_difference(last_facing, unit.facing) / maxf(delta, 0.001)
	last_facing = unit.facing
	bank = lerpf(bank, clampf(-turn * 0.3, -0.18, 0.18), delta * 1.5)
	model.position.y = sin(bob) * 0.6
	model.rotation.z = bank
	model.rotation.x = sin(bob * 0.7) * 0.015
	var g := World.inst.terrain.ground_at(unit.global_position.x, unit.global_position.z)
	shadow.global_position = Vector3(unit.global_position.x, g + 0.3, unit.global_position.z)
	shadow.global_rotation = Vector3(0, unit.facing, 0)
	shadow.visible = visible
	if unit.hp_ratio() < 0.5:
		smoke_t -= delta
		if smoke_t <= 0.0:
			smoke_t = 0.25
			World.inst.fx.smoke(model.global_position + Vector3(randf_range(-3, 3), 1.0, randf_range(-8, 8)), 2.5, 0.25)


func _aim(delta: float) -> void:
	var want := 0.0
	var want_elev := 0.0
	if unit.target and is_instance_valid(unit.target) and unit.target.alive:
		var to := unit.target.global_position - unit.global_position
		want = wrapf(atan2(to.x, to.z) - unit.facing, -PI, PI)
		want_elev = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.3, 0.5)
	if aim_part and not unit.is_air:
		want = clampf(want, -2.2, 2.2) if aim_part.name == "torso" else want
		aim_yaw = rotate_toward(aim_yaw, want, delta * (1.2 if aim_part.name == "torso" else 2.2))
		aim_part.transform = (rest[aim_part] as Transform3D).rotated_local(Vector3.UP, aim_yaw)
	for k: String in recoil.keys():
		recoil[k] = maxf(0.0, recoil[k] - delta * 2.5)
	for g in guns:
		var side := String(g.name).substr(4)
		g.transform = (rest[g] as Transform3D).translated_local(Vector3(0, 0, -float(recoil.get(side, 0.0)) * 0.5))
	if cannon:
		elevation = move_toward(elevation, want_elev, delta * 0.6)
		var r := float(recoil.get("main", 0.0))
		cannon.transform = (rest[cannon] as Transform3D).rotated_local(Vector3.RIGHT, -elevation - r * 0.12).translated_local(Vector3(0, 0, -r * 0.6))
		if brace:
			brace.transform = (rest[brace] as Transform3D).rotated_local(Vector3.RIGHT, r * 0.25)
	elif aim_part and aim_part.name == "turret" and anchors.has("muzzle"):
		var r := float(recoil.get("main", 0.0))
		aim_part.transform = aim_part.transform.translated_local(Vector3(0, 0, -r * 0.25))
	if unit.special_time > 0.0 and randf() < delta * 8.0:
		World.inst.fx.flash(unit.aim_point() + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * unit.radius * 0.5,
				Defs.team_glow(unit.team), 1.0)


## Steam from the stacks: a faint trail at rest, thicker on the move.
func _exhaust(delta: float) -> void:
	if not visible:
		return
	steam_t -= delta * (1.6 if unit.moving else 0.6)
	if steam_t > 0.0:
		return
	steam_t = 1.0
	for n in ["exhaust_l", "exhaust_r"]:
		if anchors.has(n):
			World.inst.fx.smoke((anchors[n] as Node3D).global_position, unit.height * 0.09, 0.12)

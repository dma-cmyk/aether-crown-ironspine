class_name Building
extends Entity
## Static structure: construction, unit production, turrets, damage fires and collapse.

const MAX_QUEUE := 6
const MUZZLE := {"citadel": Vector3(0, 1.7, 3.8), "gate": Vector3(0, 1.7, 4.8), "bastion": Vector3(0, 1.7, 5.2)}
const STACKS := {"citadel": [Vector3(-4.5, 20.5, -11.0), Vector3(4.5, 18.5, -11.0)], "foundry": [Vector3(-5.5, 25.2, -9.8), Vector3(5.5, 22.2, -9.8)]}

var built := true
var progress := 1.0
var production: Array[String] = []
var prod_t := 0.0
var rally := Vector3.INF
var model: Node3D
var turrets: Array[Node3D] = []
var weapons: Array[Dictionary] = []
var target: Entity
var facing := 0.0
var footprint := 0.0
var model_height := 10.0
var _acquire_t := 0.0
var _rubble_t := -1.0
var _fire_t := 0.0
var _turret_i := 0
var _collapse := 0.0
var _stacks: Array[int] = []


func setup(id: String, t: int, pos: Vector3, face: float, is_built: bool) -> void:
	def_id = id
	def = Defs.BUILDINGS[id]
	team = t
	is_building = true
	armor = "structure"
	max_hp = def["hp"]
	radius = def["radius"]
	footprint = def["footprint"]
	vision = def.get("vision", 30.0)
	facing = face
	var g := World.inst.terrain.ground_at(pos.x, pos.z)
	global_position = Vector3(pos.x, g, pos.z)
	rotation.y = face
	model = UnitVisual.load_model(def["model"], team, true)
	add_child(model)
	for n in model.find_children("turret*", "Node3D", true, false):
		turrets.append(n)
		MatLib.remap(n, team, false)
	for wid in def.get("weapons", []):
		var w: Dictionary = Defs.WEAPONS[wid].duplicate()
		w["id"] = wid
		w["cd"] = randf_range(0.0, w["cooldown"])
		weapons.append(w)
	model_height = _measure_height()
	height = model_height * 0.6
	built = is_built
	progress = 1.0 if built else 0.02
	hp = max_hp if built else max_hp * 0.1
	if footprint > 0.0:
		World.inst.nav.set_blocked_circle(global_position, footprint, true)
	rally = global_position + Basis(Vector3.UP, facing) * Vector3(0, 0, radius + 9.0)
	_update_construction()
	if built:
		_start_stacks()


func _start_stacks() -> void:
	for local: Vector3 in STACKS.get(def_id, []):
		_stacks.append(World.inst.fx.add_chimney(global_position + Basis(Vector3.UP, facing) * local, 3.0, 3.2, 0.22))


func _measure_height() -> float:
	var top := 4.0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var aabb := mi.get_aabb()
		top = maxf(top, (mi.transform * aabb.end).y)
	return top


func display_name() -> String:
	return Defs.building_name(def_id, team)


func description() -> String:
	return Defs.building_desc(def_id, team)


func produces() -> Array:
	return def.get("produces", [])


func queued_pop() -> int:
	var p := 0
	for id in production:
		p += int(Defs.UNITS[id]["pop"])
	return p


func can_queue(uid: String) -> String:
	if not built:
		return "建設中"
	if not uid in produces():
		return "生産不可"
	if production.size() >= MAX_QUEUE:
		return "キューが満杯"
	var p := World.inst.player(team)
	var ud: Dictionary = Defs.UNITS[uid]
	if not p.can_afford(ud["cost"]):
		return "資源不足"
	if p.pop_used + int(ud["pop"]) > p.pop_cap:
		return "人口上限"
	return ""


func queue_unit(uid: String) -> bool:
	if can_queue(uid) != "":
		return false
	var p := World.inst.player(team)
	p.spend(Defs.UNITS[uid]["cost"])
	production.append(uid)
	p.pop_used += int(Defs.UNITS[uid]["pop"])
	return true


func cancel_last() -> void:
	if production.is_empty():
		return
	var uid: String = production.pop_back()
	World.inst.player(team).refund(Defs.UNITS[uid]["cost"])
	if production.is_empty():
		prod_t = 0.0


func production_progress() -> float:
	if production.is_empty():
		return 0.0
	return clampf(prod_t / float(Defs.UNITS[production[0]]["build_time"]), 0.0, 1.0)


func build_speed_mult() -> float:
	var m := 1.0
	for s in World.inst.sites:
		if s.owner_team == team and s.site_id == "brassholm":
			m *= 1.15
	return m


# ---------------------------------------------------------------- simulation
func tick(dt: float) -> void:
	if not alive:
		_rubble_t -= dt
		if _rubble_t <= 0.0:
			World.inst.remove_building(self)
			queue_free()
		return
	if not built:
		var bt: float = def["build_time"]
		progress = minf(1.0, progress + dt / bt)
		hp = minf(max_hp, hp + max_hp * 0.9 * dt / bt)
		_update_construction()
		if randf() < dt * 3.0:
			World.inst.fx.dust(global_position + Vector3(randf_range(-radius, radius), 0.5, randf_range(-radius, radius)) * 0.8, 2.5)
		if progress >= 1.0:
			built = true
			_update_construction()
			_start_stacks()
			World.inst.sfx.play_at("build_done", global_position)
			if team == Defs.TEAM_PLAYER:
				World.inst.raise_alert(global_position, "%s 完成" % display_name(), team)
		return
	if not production.is_empty():
		prod_t += dt * build_speed_mult()
		var uid := production[0]
		if prod_t >= float(Defs.UNITS[uid]["build_time"]):
			prod_t = 0.0
			production.pop_front()
			_spawn(uid)
	for w in weapons:
		w["cd"] = maxf(0.0, w["cd"] - dt)
	if not weapons.is_empty():
		_acquire_t -= dt
		if _acquire_t <= 0.0:
			_acquire_t = 0.4
			var r := 0.0
			var can_air := false
			for w in weapons:
				r = maxf(r, w["range"])
				can_air = can_air or w.get("air", false)
			target = World.inst.find_target(global_position, r, team, can_air, true, target)
		_try_fire()
	if hp_ratio() < 0.5:
		_fire_t -= dt
		if _fire_t <= 0.0:
			_fire_t = 0.5 if hp_ratio() > 0.25 else 0.25
			var p := global_position + Vector3(randf_range(-radius, radius) * 0.6, randf_range(0.3, 0.8) * model_height, randf_range(-radius, radius) * 0.6)
			World.inst.fx.fire(p, 1.4)
			World.inst.fx.smoke(p + Vector3(0, 1.5, 0), 2.6, 0.35)


func _try_fire() -> void:
	if target == null or not is_instance_valid(target) or not target.alive:
		return
	var d := flat_distance_to(target.global_position) - target.radius
	for w in weapons:
		if w["cd"] > 0.0 or d > float(w["range"]):
			continue
		if target.is_air and not w.get("air", false):
			continue
		w["cd"] = float(w["cooldown"]) * randf_range(0.9, 1.1)
		Combat.fire(self, w, target)


func muzzle_points(w: Dictionary, _t: Entity) -> Array[Vector3]:
	if w.get("fx", "") == "beam":
		return [global_position + Vector3(0, model_height * 0.78, 0)]
	if turrets.is_empty():
		return [aim_point()]
	_turret_i = (_turret_i + 1) % turrets.size()
	var tr := turrets[_turret_i]
	return [tr.global_transform * MUZZLE.get(def_id, Vector3(0, 1.7, 4.8))]


func _process(delta: float) -> void:
	if not alive:
		_collapse = minf(1.0, _collapse + delta * 0.35)
		model.position.y = -model_height * 0.55 * _collapse * _collapse
		model.rotation.z = 0.06 * _collapse
		return
	visible = seen_by_player or team == Defs.TEAM_PLAYER
	if target and is_instance_valid(target) and target.alive:
		for tr in turrets:
			var to := target.global_position - tr.global_position
			var local_yaw := wrapf(atan2(to.x, to.z) - global_rotation.y, -PI, PI)
			tr.rotation.y = rotate_toward(tr.rotation.y, local_yaw, delta * 2.2)
	_update_bar_visibility()


func _update_construction() -> void:
	if model == null:
		return
	model.position.y = -model_height * (1.0 - progress) * 0.92
	model.scale = Vector3.ONE * (0.92 + 0.08 * progress) if not built else Vector3.ONE


func _spawn(uid: String) -> void:
	var fwd := Basis(Vector3.UP, facing) * Vector3(0, 0, radius + 3.5)
	var exit := World.inst.nav.nearest_walkable_pos(global_position + fwd)
	var u := World.inst.spawn_unit(uid, team, exit, facing)
	World.inst.player(team).stats["built"] += 1
	if rally != Vector3.INF:
		var spread := Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		u.order_move(rally + spread)
	if team == Defs.TEAM_PLAYER:
		World.inst.sfx.play_at("unit_ready", global_position)
		World.inst.raise_alert(global_position, "%s 出撃準備完了" % u.display_name(), team, "ready_" + uid, 4.0)


func die() -> void:
	if not alive:
		return
	for uid in production:
		World.inst.player(team).refund(Defs.UNITS[uid]["cost"], 0.5)
	production.clear()
	super.die()
	_rubble_t = 12.0
	if footprint > 0.0:
		World.inst.nav.set_blocked_circle(global_position, footprint, false)
	var fx := World.inst.fx
	for h in _stacks:
		fx.remove_ambient(h)
	_stacks.clear()
	for i in 6:
		var p := global_position + Vector3(randf_range(-radius, radius) * 0.7, randf_range(0.2, 0.9) * model_height, randf_range(-radius, radius) * 0.7)
		fx.explosion(p, 2.0 + randf() * 1.5, i * 0.18)
	fx.debris(global_position + Vector3(0, model_height * 0.4, 0), 24)
	fx.smoke_column(global_position, radius)
	World.inst.sfx.play_at("explosion_big", global_position)
	World.inst.camera.shake(1.2)
	if team == Defs.TEAM_PLAYER:
		World.inst.raise_alert(global_position, "%s が破壊された" % display_name(), team)

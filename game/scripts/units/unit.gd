class_name Unit
extends Entity
## Mobile unit: orders, movement, targeting and weapons. Visuals live in a child controller.

enum Order { IDLE, MOVE, ATTACK, ATTACK_MOVE, PATROL, HOLD, REPAIR }

const LEASH := 26.0

var order := Order.IDLE
var move_target := Vector3.ZERO
var patrol_a := Vector3.ZERO
var patrol_b := Vector3.ZERO
var target: Entity
var explicit_target := false
var repair_target: Entity
var path := PackedVector3Array()
var path_i := 0
var velocity := Vector3.ZERO
var facing := 0.0
var speed := 5.0
var weapons: Array[Dictionary] = []
var fortified := false
var deployed := false
var setup_timer := 0.0
var setup_goal := ""
var special_cd := 0.0
var special_time := 0.0
var capture_power := 1.0
var visual: UnitVisual
var guard_pos := Vector3.ZERO
var queue: Array[Vector3] = []
var type := "squad"
var altitude := 0.0
var moving := false
var firing_timer := 0.0
var _acquire_t := 0.0
var _repath_t := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _corpse_t := -1.0
var _bombard_target := Vector3.INF
var _bombard_drops := 0
var _bombard_t := 0.0


func setup(id: String, t: int, pos: Vector3, face: float) -> void:
	def_id = id
	def = Defs.UNITS[id]
	team = t
	type = def["type"]
	armor = def["armor"]
	speed = def["speed"]
	radius = def["radius"]
	vision = def["vision"]
	capture_power = def.get("capture", 1.0)
	is_air = type == "air"
	is_mechanical = type in ["walker", "vehicle", "air"]
	altitude = def.get("altitude", 0.0)
	if type == "squad":
		max_hp = def["members"] * def["member_hp"]
		height = 2.0
	else:
		max_hp = def["hp"]
		height = {"walker": 10.0, "vehicle": 3.5, "air": 5.0}.get(type, 3.0)
	hp = max_hp
	for wid in def["weapons"]:
		var w: Dictionary = Defs.WEAPONS[wid].duplicate()
		w["id"] = wid
		w["cd"] = randf_range(0.0, w["cooldown"])
		weapons.append(w)
	facing = face
	var g := World.inst.terrain.ground_at(pos.x, pos.z)
	global_position = Vector3(pos.x, g + altitude, pos.z)
	rotation.y = facing
	guard_pos = global_position
	_last_pos = global_position
	match type:
		"squad":
			visual = SquadVisual.new()
		"walker":
			visual = WalkerVisual.new()
		"vehicle":
			visual = VehicleVisual.new()
		"air":
			visual = AirshipVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup(self)


func display_name() -> String:
	return Defs.unit_name(def_id, team)


func description() -> String:
	return Defs.unit_desc(def_id, team)


func damage_taken_mult() -> float:
	var m := 1.0
	if fortified:
		m *= 0.5
	if deployed and type == "squad":
		m *= 0.6
	return m


func range_mult() -> float:
	return 1.15 if fortified else 1.0


func rate_mult() -> float:
	var m := 1.0
	if special_time > 0.0 and def.get("special", "") in ["aether_volley", "overcharge"]:
		m *= 2.0 if def["special"] == "aether_volley" else 1.6
	return m


func speed_mult() -> float:
	var m := 1.0
	if special_time > 0.0 and def.get("special", "") == "overcharge":
		m *= 1.4
	if type == "squad" and hp_ratio() < 0.3:
		m *= 0.9
	return m


func max_range() -> float:
	var r := 0.0
	for w in weapons:
		r = maxf(r, weapon_range(w))
	return r


func weapon_range(w: Dictionary) -> float:
	var r: float = w["range"]
	if deployed and w.has("deployed_range"):
		r = w["deployed_range"]
	return r * range_mult()


func members_alive() -> int:
	if type != "squad":
		return 1
	return clampi(int(ceil(hp / float(def["member_hp"]) - 0.001)), 0, int(def["members"]))


func can_move() -> bool:
	return not fortified and not deployed and setup_timer <= 0.0


# ---------------------------------------------------------------- orders
func order_move(p: Vector3, queued: bool = false) -> void:
	if queued and order == Order.MOVE:
		queue.append(p)
		return
	_clear_modes()
	queue.clear()
	order = Order.MOVE
	target = null
	explicit_target = false
	_set_destination(p)


func order_attack(e: Entity) -> void:
	if e == null or not e.alive:
		return
	_clear_modes()
	queue.clear()
	order = Order.ATTACK
	target = e
	explicit_target = true
	_repath_t = 0.0


func order_attack_move(p: Vector3) -> void:
	_clear_modes()
	queue.clear()
	order = Order.ATTACK_MOVE
	target = null
	explicit_target = false
	_set_destination(p)


func order_patrol(p: Vector3) -> void:
	_clear_modes()
	queue.clear()
	order = Order.PATROL
	patrol_a = global_position
	patrol_b = p
	target = null
	explicit_target = false
	_set_destination(p)


func order_hold() -> void:
	order = Order.HOLD
	path.clear()
	target = null
	explicit_target = false
	guard_pos = global_position


func order_stop() -> void:
	order = Order.IDLE
	path.clear()
	queue.clear()
	target = null
	explicit_target = false
	guard_pos = global_position


func order_repair(e: Entity) -> void:
	if def.get("repair_rate", 0.0) <= 0.0 or e == null or e.team != team:
		return
	_clear_modes()
	order = Order.REPAIR
	repair_target = e
	_repath_t = 0.0


func toggle_fortify() -> void:
	if not "fortify" in def["commands"]:
		return
	if fortified:
		fortified = false
		setup_timer = 0.6
		setup_goal = ""
	elif setup_timer <= 0.0:
		path.clear()
		order = Order.HOLD
		setup_timer = 1.4
		setup_goal = "fortify"
	if visual:
		visual.on_mode_changed()


func toggle_deploy() -> void:
	if not "deploy" in def["commands"]:
		return
	if deployed:
		deployed = false
		setup_timer = 2.0
		setup_goal = ""
	elif setup_timer <= 0.0:
		path.clear()
		order = Order.HOLD
		setup_timer = 2.4 if type == "vehicle" else 3.0
		setup_goal = "deploy"
	if visual:
		visual.on_mode_changed()


func _clear_modes() -> void:
	if fortified or deployed:
		fortified = false
		deployed = false
		setup_timer = 1.0
		setup_goal = ""
		if visual:
			visual.on_mode_changed()


func special_ready() -> bool:
	return def.get("special", "") != "" and special_cd <= 0.0


func use_special(at: Vector3 = Vector3.INF) -> bool:
	var sid: String = def.get("special", "")
	if sid == "" or special_cd > 0.0 or not alive:
		return false
	var sp: Dictionary = Defs.SPECIALS[sid]
	match sid:
		"aether_volley", "overcharge":
			special_time = sp["duration"]
		"field_repair":
			for e: Entity in World.inst.query(global_position, 16.0):
				if e.team == team and (e.is_mechanical or e.is_building):
					e.heal(260.0)
					World.inst.fx.sparkle(e.aim_point(), Defs.team_glow(team))
			World.inst.fx.ring_burst(global_position + Vector3(0, 0.5, 0), 16.0, Defs.team_glow(team))
		"aether_bombard":
			if at == Vector3.INF:
				return false
			if flat_distance_to(at) > 60.0:
				order_move(at)
			_bombard_target = at
			_bombard_drops = 7
			_bombard_t = 0.0
	special_cd = sp["cooldown"]
	World.inst.sfx.play_at("special", global_position)
	return true


func _set_destination(p: Vector3) -> void:
	move_target = Vector3(p.x, 0, p.z)
	if is_air:
		path = PackedVector3Array([move_target])
	else:
		path = World.inst.nav.find_path(global_position, move_target)
		if path.is_empty():
			path = PackedVector3Array([World.inst.nav.nearest_walkable_pos(move_target)])
	path_i = 0
	_stuck_t = 0.0


# ---------------------------------------------------------------- simulation
func tick(dt: float) -> void:
	if not alive:
		_corpse_t -= dt
		if _corpse_t <= 0.0:
			World.inst.remove_unit(self)
			queue_free()
		return
	special_cd = maxf(0.0, special_cd - dt)
	special_time = maxf(0.0, special_time - dt)
	firing_timer = maxf(0.0, firing_timer - dt)
	for w in weapons:
		w["cd"] = maxf(0.0, w["cd"] - dt * rate_mult())
	if setup_timer > 0.0:
		setup_timer -= dt
		if setup_timer <= 0.0:
			if setup_goal == "fortify":
				fortified = true
			elif setup_goal == "deploy":
				deployed = true
			setup_goal = ""
			if visual:
				visual.on_mode_changed()
	_acquire_t -= dt
	if _acquire_t <= 0.0:
		_acquire_t = randf_range(0.3, 0.45)
		_acquire()
	if _bombard_drops > 0:
		_tick_bombard(dt)
	moving = false
	match order:
		Order.IDLE, Order.HOLD:
			_tick_idle(dt)
		Order.MOVE:
			if _follow_path(dt):
				if queue.size() > 0:
					_set_destination(queue.pop_front())
				else:
					order = Order.IDLE
					guard_pos = global_position
		Order.ATTACK:
			_tick_attack(dt)
		Order.ATTACK_MOVE, Order.PATROL:
			_tick_attack_move(dt)
		Order.REPAIR:
			_tick_repair(dt)
	_try_fire()
	_auto_repair(dt)
	_integrate(dt)


func _acquire() -> void:
	if explicit_target:
		if target == null or not is_instance_valid(target) or not target.alive:
			target = null
			explicit_target = false
			if order == Order.ATTACK:
				order = Order.IDLE
				guard_pos = global_position
		return
	var can_air := false
	var can_ground := false
	for w in weapons:
		if w.get("air", false):
			can_air = true
		if not w.get("air_only", false):
			can_ground = true
	var r := maxf(vision, max_range())
	if order == Order.HOLD or order == Order.MOVE:
		r = max_range()
	var prev := target
	target = World.inst.find_target(global_position, r, team, can_air, can_ground, prev)


func _tick_idle(dt: float) -> void:
	if target and is_instance_valid(target) and target.alive and order == Order.IDLE and can_move():
		var d := flat_distance_to(target.global_position) - target.radius
		var r := _best_range_vs(target)
		if d > r * 0.92 and guard_pos.distance_to(global_position) < LEASH:
			_steer_towards(target.global_position, dt)
		return
	if order == Order.IDLE and can_move() and flat_distance_to(guard_pos) > 6.0 and not is_air:
		if path.is_empty() or path_i >= path.size():
			_set_destination(guard_pos)
		_follow_path(dt)


func _tick_attack(dt: float) -> void:
	if target == null or not is_instance_valid(target) or not target.alive:
		order = Order.IDLE
		guard_pos = global_position
		return
	var d := flat_distance_to(target.global_position) - target.radius
	var r := _best_range_vs(target)
	if d <= r * 0.95:
		path.clear()
		return
	if not can_move():
		return
	_repath_t -= dt
	if _repath_t <= 0.0 or path_i >= path.size():
		_repath_t = 1.2
		_set_destination(target.global_position)
	_follow_path(dt)


func _tick_attack_move(dt: float) -> void:
	if target and is_instance_valid(target) and target.alive:
		var d := flat_distance_to(target.global_position) - target.radius
		var r := _best_range_vs(target)
		if d > r * 0.95 and can_move():
			_steer_towards(target.global_position, dt)
		return
	if path_i >= path.size() or path.is_empty():
		_set_destination(move_target)
	if _follow_path(dt):
		if order == Order.PATROL:
			var nxt := patrol_a
			patrol_a = patrol_b
			patrol_b = nxt
			_set_destination(nxt)
		else:
			order = Order.IDLE
			guard_pos = global_position


func _tick_repair(dt: float) -> void:
	var e := repair_target
	if e == null or not is_instance_valid(e) or not e.alive or e.hp >= e.max_hp:
		order = Order.IDLE
		guard_pos = global_position
		repair_target = null
		return
	var d := flat_distance_to(e.global_position) - e.radius
	if d > 5.0:
		_repath_t -= dt
		if _repath_t <= 0.0 or path_i >= path.size():
			_repath_t = 1.0
			_set_destination(e.global_position)
		_follow_path(dt)
		return
	path.clear()
	_face_towards(e.global_position, dt)
	e.heal(float(def["repair_rate"]) * members_alive() / float(def["members"]) * dt)
	firing_timer = 0.3
	if randf() < dt * 3.0:
		World.inst.fx.sparks(e.aim_point() + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * e.radius * 0.4, 4)


func _auto_repair(dt: float) -> void:
	if def.get("repair_rate", 0.0) <= 0.0 or order != Order.IDLE or target != null:
		return
	for e: Entity in World.inst.query(global_position, 7.0):
		if e != self and e.team == team and (e.is_mechanical or e.is_building) and e.hp < e.max_hp:
			e.heal(float(def["repair_rate"]) * 0.5 * dt)
			firing_timer = 0.3
			_face_towards(e.global_position, dt)
			if randf() < dt * 2.0:
				World.inst.fx.sparks(e.aim_point(), 3)
			return


func _tick_bombard(dt: float) -> void:
	if flat_distance_to(_bombard_target) > 18.0:
		return
	_bombard_t -= dt
	if _bombard_t <= 0.0:
		_bombard_t = 0.28
		_bombard_drops -= 1
		var p := _bombard_target + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
		World.inst.projectiles.drop_bomb(self, global_position + Vector3(0, -4, 0), p)
		if _bombard_drops <= 0:
			_bombard_target = Vector3.INF


func _best_range_vs(e: Entity) -> float:
	var r := 0.0
	for w in weapons:
		if _weapon_can_hit(w, e):
			r = maxf(r, weapon_range(w))
	return maxf(r, 2.0)


func _weapon_can_hit(w: Dictionary, e: Entity) -> bool:
	if e.is_air:
		return w.get("air", false)
	return not w.get("air_only", false)


func _try_fire() -> void:
	if target == null or not is_instance_valid(target) or not target.alive:
		return
	if setup_timer > 0.0:
		return
	var d := flat_distance_to(target.global_position) - target.radius
	for w in weapons:
		if w["cd"] > 0.0 or not _weapon_can_hit(w, target):
			continue
		if d > weapon_range(w):
			continue
		if d < float(w.get("min_range", 0.0)):
			continue
		if moving and type in ["squad", "vehicle"]:
			continue
		if type == "squad" and not _facing_ok(target.global_position, 0.6):
			continue
		if type == "vehicle" and not deployed and w.has("deployed_range") and d > float(w["range"]) * range_mult():
			continue
		w["cd"] = float(w["cooldown"]) * randf_range(0.88, 1.12)
		firing_timer = 0.6
		Combat.fire(self, w, target)


# ---------------------------------------------------------------- movement
func _follow_path(dt: float) -> bool:
	if not can_move():
		return false
	if path_i >= path.size():
		return true
	var wp := path[path_i]
	var to := Vector3(wp.x - global_position.x, 0, wp.z - global_position.z)
	var last := path_i == path.size() - 1
	var arrive := 1.2 if last else maxf(2.2, radius * 0.8)
	if to.length() < arrive:
		path_i += 1
		return path_i >= path.size()
	_steer_towards(wp, dt)
	_stuck_t += dt
	if _stuck_t > 1.5:
		if global_position.distance_to(_last_pos) < speed * 0.25:
			path_i += 1
			if path_i >= path.size() and not last:
				_set_destination(move_target)
		_stuck_t = 0.0
		_last_pos = global_position
	return false


func _steer_towards(p: Vector3, dt: float) -> void:
	if not can_move():
		return
	var to := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	var dist := to.length()
	if dist < 0.05:
		return
	var dir := to / dist
	var target_yaw := atan2(dir.x, dir.z)
	var turn_rate: float = {"squad": 7.0, "walker": 2.2, "vehicle": 2.6, "air": 1.1}.get(type, 4.0)
	facing = rotate_toward(facing, target_yaw, turn_rate * dt)
	var align := cos(angle_difference(facing, target_yaw))
	var sp := speed * speed_mult()
	if type != "squad":
		sp *= clampf(align, 0.2, 1.0)
	velocity = velocity.lerp(dir * sp, clampf(dt * 6.0, 0.0, 1.0))
	moving = true


func _face_towards(p: Vector3, dt: float) -> void:
	var to := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	if to.length() < 0.1:
		return
	facing = rotate_toward(facing, atan2(to.x, to.z), 5.0 * dt)


func _facing_ok(p: Vector3, tol: float) -> bool:
	var to := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	return absf(angle_difference(facing, atan2(to.x, to.z))) < tol


func _integrate(dt: float) -> void:
	if not moving:
		velocity = velocity.lerp(Vector3.ZERO, clampf(dt * 8.0, 0.0, 1.0))
		if target and is_instance_valid(target) and target.alive and type != "air":
			var turret := type in ["walker", "vehicle"]
			if not turret or type == "vehicle":
				_face_towards(target.global_position, dt)
	# separation from nearby ground units
	if not is_air:
		var push := Vector3.ZERO
		for e: Entity in World.inst.query(global_position, radius + 4.0):
			if e == self or e.is_air:
				continue
			var off := global_position - e.global_position
			off.y = 0
			var dl := off.length()
			var min_d := radius + e.radius
			if e.is_building:
				min_d = e.radius + radius * 0.6
			if dl < min_d and dl > 0.001:
				var strength := (min_d - dl) / min_d
				var k := 6.0 if e.is_building else (3.0 if (e is Unit and (e as Unit).moving) else 4.5)
				push += off / dl * strength * k
		velocity += push * dt * 4.0
	var p := global_position + velocity * dt
	if not is_air:
		var nav := World.inst.nav
		if not nav.walkable_at(p) and nav.walkable_at(global_position):
			# slide along blocked cells
			var px := Vector3(p.x, 0, global_position.z)
			var pz := Vector3(global_position.x, 0, p.z)
			if nav.walkable_at(px):
				p = Vector3(px.x, p.y, px.z)
			elif nav.walkable_at(pz):
				p = Vector3(pz.x, p.y, pz.z)
			else:
				p = global_position
		p.y = World.inst.terrain.ground_at(p.x, p.z)
	else:
		var g := World.inst.terrain.height_at(p.x, p.z)
		var want := maxf(g, 0.0) + altitude
		p.y = lerpf(global_position.y, want, clampf(dt * 0.8, 0.0, 1.0))
	p.x = clampf(p.x, -190.0, 190.0)
	p.z = clampf(p.z, -190.0, 190.0)
	global_position = p
	rotation.y = facing


func die() -> void:
	if not alive:
		return
	super.die()
	_corpse_t = 6.0 if type == "squad" else 9.0
	velocity = Vector3.ZERO
	if visual:
		visual.on_death()
	var fx := World.inst.fx
	match type:
		"squad":
			World.inst.sfx.play_at("death_small", global_position)
		"walker", "vehicle":
			fx.explosion(aim_point(), 2.2)
			fx.debris(aim_point(), 10)
			World.inst.sfx.play_at("explosion_big", global_position)
			World.inst.camera.shake(0.8)
		"air":
			fx.explosion(global_position, 3.0)
			World.inst.sfx.play_at("explosion_big", global_position)

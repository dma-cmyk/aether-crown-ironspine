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
## Flyers: half width, depth below the origin and half length of the model, to clear obstacles.
var _air_box := Vector3.ZERO
var _air_floor := -INF
var _air_t := 0.0
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
var _hurl_target := Vector3.INF
var _hurl_t := -1.0
## Living creatures heal themselves instead of being repaired.
var is_creature := false


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
	is_air = type in ["air", "flyer"]
	is_mechanical = type in ["walker", "vehicle", "air"]
	is_creature = type in ["giant", "beast", "flyer"]
	altitude = def.get("altitude", 0.0)
	if type == "squad":
		max_hp = def["members"] * def["member_hp"]
		height = 2.0
	else:
		max_hp = def["hp"]
		height = def.get("height", {"walker": 10.0, "vehicle": 3.5, "air": 5.0}.get(type, 3.0))
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
	match def.get("visual", type):
		"squad":
			visual = SquadVisual.new()
		"walker":
			visual = WalkerVisual.new()
		"vehicle":
			visual = VehicleVisual.new()
		"air":
			visual = AirshipVisual.new()
		"cyclops":
			visual = CyclopsVisual.new()
		"cerberus":
			visual = CerberusVisual.new()
		"dragon":
			visual = DragonVisual.new()
		"griffin":
			visual = GriffinVisual.new()
		"mech":
			visual = MechVisual.new()
		"demon":
			visual = DemonVisual.new()
		"angel":
			visual = AngelVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup(self)
	if is_air:
		_air_box = _model_box(visual.get("model"))


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
	if special_time > 0.0 and def.get("special", "") in ["aether_volley", "overcharge", "frenzy"]:
		m *= 2.0 if def["special"] == "aether_volley" else 1.6
	return m


func speed_mult() -> float:
	var m := 1.0
	if special_time > 0.0 and def.get("special", "") in ["overcharge", "frenzy"]:
		m *= 1.4 if def["special"] == "overcharge" else 1.5
	if type == "squad" and hp_ratio() < 0.3:
		m *= 0.9
	return m


## Sight radius right now (the griffin's Keen Sight doubles it).
func vision_now() -> float:
	if special_time > 0.0 and def.get("special", "") == "keen_sight":
		return vision * 2.0
	return vision


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


## Save/load: re-enter fortify / deploy without the setup delay.
func restore_modes(fort: bool, dep: bool) -> void:
	fortified = fort
	deployed = dep
	if fort or dep:
		order = Order.HOLD
		path.clear()
		guard_pos = global_position
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
		"aether_volley", "overcharge", "frenzy", "keen_sight":
			special_time = sp["duration"]
		"boulder_hurl":
			if at == Vector3.INF:
				return false
			_hurl_target = at
			_hurl_t = -1.0
			if flat_distance_to(at) > float(sp["range"]):
				order_move(at)
		"inferno":
			if at == Vector3.INF:
				return false
			if flat_distance_to(at) > 12.0:
				order_move(at)
			_bombard_target = at
			_bombard_drops = 6
			_bombard_t = 0.0
		"hellfire":
			# a ring of fire around the demon; it burns ground troops and buildings, not fliers
			var r: float = sp["radius"]
			Combat.splash(global_position, r, float(sp["damage"]), "flame", team, self)
			var c := DragonVisual.fire_of(team)
			var fx := World.inst.fx
			for k in 10:
				var a := k * TAU / 10.0
				var p := global_position + Vector3(cos(a), 0, sin(a)) * r * 0.65
				p.y = World.inst.terrain.ground_at(p.x, p.z)
				fx.burn(p, 2.6, 3.0, c)
			fx.ring_burst(global_position + Vector3(0, 0.5, 0), r, c)
			fx.light_flash(global_position + Vector3(0, 3, 0), c, 9.0)
			World.inst.sfx.play_at("flame", global_position)
			if visual:
				visual.on_special(sid)
		"blessing":
			# heals every friendly unit around, the angel included
			for e: Entity in World.inst.query(global_position, float(sp["radius"])):
				if e.team == team and e is Unit and e.alive:
					var u := e as Unit
					var amount := float(sp["heal"])
					if u.type == "squad":
						# wounds close, but the fallen stay fallen
						amount = minf(amount, u.members_alive() * float(u.def["member_hp"]) - u.hp)
					u.heal(amount)
					World.inst.fx.sparkle(e.aim_point(), Color(1.0, 0.92, 0.65))
			World.inst.fx.ring_burst(Vector3(global_position.x, World.inst.terrain.ground_at(global_position.x, global_position.z) + 0.5, global_position.z),
					float(sp["radius"]), Color(1.0, 0.9, 0.6))
			World.inst.fx.light_flash(global_position, Color(1.0, 0.9, 0.65), 8.0)
			if visual:
				visual.on_special(sid)
		"field_repair":
			for e: Entity in World.inst.query(global_position, 16.0):
				if e.team == team and (e.is_mechanical or e.is_building):
					e.heal(260.0)
					World.inst.fx.sparkle(e.aim_point(), Defs.team_glow(team))
			World.inst.fx.ring_burst(global_position + Vector3(0, 0.5, 0), 16.0, Defs.team_glow(team))
		"missile_salvo":
			if at == Vector3.INF:
				return false
			if flat_distance_to(at) > float(sp["range"]):
				order_move(at)
			_bombard_target = at
			_bombard_drops = 12
			_bombard_t = 0.0
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
	if visual and sp.get("duration", 0.0) > 0.0:
		visual.on_special(sid)
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
	if _hurl_target != Vector3.INF:
		_tick_hurl(dt)
	var regen: float = def.get("regen", 0.0)
	if regen > 0.0 and hp < max_hp and World.inst.match_time - last_damage_time > 6.0:
		heal(regen * dt)
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


## Dragon Inferno, Skyfrigate bombs and the mech's Missile Salvo: close in, then rain on the area.
func _tick_bombard(dt: float) -> void:
	var sid: String = def.get("special", "")
	var dragon := sid == "inferno"
	var salvo := sid == "missile_salvo"
	var reach := 16.0 if dragon else (float(Defs.SPECIALS[sid]["range"]) if salvo else 18.0)
	if flat_distance_to(_bombard_target) > reach:
		return
	_bombard_t -= dt
	if _bombard_t <= 0.0:
		_bombard_t = 0.38 if dragon else (0.12 if salvo else 0.28)
		_bombard_drops -= 1
		var p := _bombard_target + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
		if salvo:
			# the mech stops where it can reach and fires from the shoulder pods
			if order == Order.MOVE:
				order_stop()
			_face_towards(_bombard_target, dt)
			World.inst.projectiles.missile(self, visual.special_point(), p, 45.0, 4.0, "missile")
		elif dragon:
			World.inst.projectiles.firestorm(self, visual.special_point(), p)
			visual.on_special_at("inferno", p)
		else:
			World.inst.projectiles.drop_bomb(self, global_position + Vector3(0, -4, 0), p)
		if _bombard_drops <= 0:
			_bombard_target = Vector3.INF


## Boulder Hurl: walk into range, stop, wind up, and let go when the arm comes over.
func _tick_hurl(dt: float) -> void:
	if _hurl_t < 0.0:
		if flat_distance_to(_hurl_target) > float(Defs.SPECIALS["boulder_hurl"]["range"]):
			return
		order_hold()
		_hurl_t = 0.0
		setup_timer = 1.4
		setup_goal = ""
		visual.on_special("boulder_hurl")
		return
	_face_towards(_hurl_target, dt)
	var before := _hurl_t
	_hurl_t += dt
	if before < 1.0 and _hurl_t >= 1.0:
		World.inst.projectiles.boulder(self, visual.special_point(), _hurl_target)
		_hurl_target = Vector3.INF
		_hurl_t = -1.0


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
		if moving and type in ["squad", "vehicle", "giant"]:
			continue
		if type == "squad" and not _facing_ok(target.global_position, 0.6):
			continue
		if def.has("aim") and not _facing_ok(target.global_position, float(def["aim"])):
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
	var turn_rate: float = def.get("turn", {"squad": 7.0, "walker": 2.2, "vehicle": 2.6, "air": 1.1}.get(type, 4.0))
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
			if e == self or e.is_air or (e.is_building and e.def.has("walls")):
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
	else:
		# fliers keep their own airspace instead of stacking over a target
		var push := Vector3.ZERO
		for e: Entity in World.inst.query(global_position, radius + 6.0):
			if e == self or not e.is_air:
				continue
			var off := global_position - e.global_position
			off.y = 0
			var dl := off.length()
			var min_d := (radius + e.radius) * 0.8
			if dl < min_d:
				push += (off / dl if dl > 0.001 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))) * (min_d - dl) / min_d * 3.0
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
		var want := _air_height(p, dt)
		p.y = lerpf(global_position.y, want, clampf(dt * (2.5 if want > global_position.y else 0.8), 0.0, 1.0))
	p.x = clampf(p.x, -190.0, 190.0)
	p.z = clampf(p.z, -190.0, 190.0)
	global_position = p
	rotation.y = facing


## Cruising height, raised to keep the hull over buildings, walls, trees and rocks under the
## flyer or up to three seconds ahead of it.
func _air_height(p: Vector3, dt: float) -> float:
	var terrain := World.inst.terrain
	_air_t -= dt
	if _air_t <= 0.0:
		_air_t = 0.25
		var nav := World.inst.nav
		var b := Basis(Vector3.UP, facing)
		var ahead := Vector3(velocity.x, 0, velocity.z)
		var top := -INF
		for k in 4:
			for fx: float in [-1.0, 0.0, 1.0]:
				for fz: float in [-1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75, 1.0]:
					var q := p + ahead * k + b.x * (_air_box.x * fx) + b.z * (_air_box.z * fz)
					top = maxf(top, nav.top_at(q, terrain.height_at(q.x, q.z)))
		# sink slowly so a wall that slips between samples does not pull the hull down into it
		_air_floor = maxf(top + _air_box.y + 3.0, _air_floor - 1.0)
	return maxf(maxf(terrain.height_at(p.x, p.z), 0.0) + altitude, _air_floor)


static func _model_box(root: Node3D) -> Vector3:
	var box := AABB()
	var inv := root.global_transform.affine_inverse()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		box = box.merge(inv * mi.global_transform * mi.get_aabb())
	return Vector3(maxf(-box.position.x, box.end.x), maxf(0.0, -box.position.y), maxf(-box.position.z, box.end.z))


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
		"giant", "beast", "flyer":
			World.inst.sfx.play_at("roar_death", global_position)

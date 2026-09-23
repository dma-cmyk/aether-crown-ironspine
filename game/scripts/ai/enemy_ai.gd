class_name EnemyAI
extends Node
## Varkesh commander: economy, construction, expansion, defence and attack waves.

var world: World
var team := 1
var aggression := 1.0
var _think := 0.0
var _build_i := 0
var _next_attack := 240.0
var _attack_group: Array[Unit] = []
var _capture_groups := {}
var rng := RandomNumberGenerator.new()

const BUILD_PLAN := [
	{"id": "refinery", "t": 40.0},
	{"id": "habitat", "t": 75.0},
	{"id": "bastion", "t": 110.0},
	{"id": "refinery", "t": 160.0},
	{"id": "skyport", "t": 230.0},
	{"id": "habitat", "t": 280.0},
	{"id": "barracks", "t": 340.0},
	{"id": "habitat", "t": 420.0},
	{"id": "bastion", "t": 480.0},
]


func setup(w: World, t: int) -> void:
	world = w
	team = t
	rng.seed = 4242


func _physics_process(delta: float) -> void:
	if world == null or world.game_over:
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = 1.0
	_economy()
	_construction()
	_defend()
	_expand()
	_attack()


func _me() -> PlayerState:
	return world.player(team)


func _my_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in world.units:
		if u.team == team and u.alive:
			out.append(u)
	return out


func _economy() -> void:
	var p := _me()
	var diff: float = [0.8, 1.0, 1.25][Game.difficulty]
	for b in world.buildings:
		if b.team != team or not b.alive or not b.built:
			continue
		if b.production.size() >= 2:
			continue
		var choice := ""
		match b.def_id:
			"citadel":
				if world.count_units(team, "artificer") < 3:
					choice = "artificer"
			"barracks":
				choice = "aetherguard" if world.count_units(team, "artificer") >= 2 or rng.randf() < 0.8 else "artificer"
			"foundry":
				choice = "walker" if rng.randf() < 0.55 else "mortar"
			"skyport":
				if rng.randf() < 0.5 * diff:
					choice = "airship"
		if choice != "" and b.can_queue(choice) == "":
			# keep a small reserve for construction
			var cost: Dictionary = Defs.UNITS[choice]["cost"]
			if p.material - float(cost["material"]) > 60.0 or b.def_id == "barracks":
				b.queue_unit(choice)


func _construction() -> void:
	if _build_i >= BUILD_PLAN.size():
		return
	var step: Dictionary = BUILD_PLAN[_build_i]
	if world.match_time < float(step["t"]):
		return
	var id: String = step["id"]
	var d: Dictionary = Defs.BUILDINGS[id]
	if not _me().can_afford(d["cost"]):
		return
	var c := world.citadel(team)
	if c == null:
		return
	for attempt in 30:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(20.0, 46.0)
		var p := c.global_position + Vector3(cos(ang), 0, sin(ang)) * r
		if id == "bastion":
			p = c.global_position.lerp(Vector3(0, 0, 0), rng.randf_range(0.18, 0.3)) + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		if _valid(id, p):
			_me().spend(d["cost"])
			var to_center := -p
			world.spawn_building(id, team, p, atan2(to_center.x, to_center.z), false)
			_build_i += 1
			return


func _valid(id: String, p: Vector3) -> bool:
	var d: Dictionary = Defs.BUILDINGS[id]
	var fp: float = d["footprint"]
	if not world.nav.area_free(p, fp + 1.0):
		return false
	var h0 := world.terrain.height_at(p.x, p.z)
	for a in 8:
		var ang := a * TAU / 8.0
		var q := p + Vector3(cos(ang), 0, sin(ang)) * fp
		if absf(world.terrain.height_at(q.x, q.z) - h0) > 1.6:
			return false
	for b in world.buildings:
		if b.alive and Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length() < b.radius + d["radius"] + 3.0:
			return false
	# keep ramps clear
	for pl in world.terrain.layout["plateaus"]:
		for rp in pl["ramps"]:
			var top := Vector3(rp["top"][0], 0, rp["top"][1])
			if Vector2(top.x - p.x, top.z - p.z).length() < 16.0 + d["radius"]:
				return false
	return true


func _defend() -> void:
	var threat: Entity = null
	for b in world.buildings:
		if b.team == team and b.alive and world.match_time - b.last_damage_time < 4.0 and b.last_attacker and is_instance_valid(b.last_attacker):
			threat = b.last_attacker
			break
	if threat == null:
		return
	for u in _my_units():
		if u.def_id == "artificer" or u in _attack_group:
			continue
		if u.flat_distance_to(threat.global_position) < 90.0 and (u.order == Unit.Order.IDLE or u.order == Unit.Order.MOVE):
			u.order_attack_move(threat.global_position)


func _expand() -> void:
	# artificers / small groups claim neutral sites on our side first
	var targets := world.sites.filter(func(s): return s.owner_team != team)
	if targets.is_empty():
		return
	var c := world.citadel(team)
	if c == null:
		return
	targets.sort_custom(func(a, b): return a.global_position.distance_to(c.global_position) < b.global_position.distance_to(c.global_position))
	for u in _my_units():
		if u.def_id != "artificer" or u.order != Unit.Order.IDLE:
			continue
		for s in targets:
			if s.owner_team == -1 and s.global_position.distance_to(c.global_position) < 230.0 and not _capture_groups.has(s.site_id + str(u.get_instance_id())):
				var busy := false
				for key in _capture_groups:
					if key.begins_with(s.site_id) and is_instance_valid(_capture_groups[key]) and _capture_groups[key].alive:
						busy = true
				if busy:
					continue
				u.order_move(s.global_position + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5)))
				_capture_groups[s.site_id + str(u.get_instance_id())] = u
				break
	# idle infantry escort to the nearest unowned site
	var idle := _my_units().filter(func(u): return u.order == Unit.Order.IDLE and u.def_id == "aetherguard" and not u in _attack_group)
	if idle.size() >= 2 and world.match_time > 60.0:
		var s0: Site = targets[0]
		if s0.owner_team != Defs.TEAM_PLAYER or aggression > 0.5:
			for u in idle.slice(0, 2):
				u.order_attack_move(s0.global_position + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)))


func _attack() -> void:
	if aggression <= 0.0:
		return
	_attack_group = _attack_group.filter(func(u): return is_instance_valid(u) and u.alive)
	if world.match_time < _next_attack:
		return
	var army := _my_units().filter(func(u): return u.def_id != "artificer" and u.order in [Unit.Order.IDLE, Unit.Order.HOLD])
	var power := 0.0
	for u in army:
		power += float(Defs.UNITS[u.def_id]["pop"])
	var need := 18.0 + world.match_time / 60.0 * 3.0
	if power < need:
		return
	var target := _pick_target()
	if target == Vector3.INF:
		return
	_attack_group = army
	var k := 0
	for u in army:
		var off := Vector3((k % 5) * 6.0 - 12.0, 0, (k / 5) * 6.0)
		u.order_attack_move(target + off)
		k += 1
	_next_attack = world.match_time + rng.randf_range(90.0, 140.0) / aggression
	world.raise_alert(target, "ヴァルケシュの大部隊が進軍してくる！", Defs.TEAM_PLAYER, "ai_attack", 30.0)


func _pick_target() -> Vector3:
	var c := world.citadel(team)
	var from := c.global_position if c else Vector3(150, 0, -150)
	var best := Vector3.INF
	var best_d := INF
	for s in world.sites:
		if s.owner_team == Defs.TEAM_PLAYER:
			var d := s.global_position.distance_to(from)
			if d < best_d:
				best_d = d
				best = s.global_position
	if best == Vector3.INF or rng.randf() < 0.3:
		for b in world.buildings:
			if b.team == Defs.TEAM_PLAYER and b.alive:
				var d2 := b.global_position.distance_to(from) + (60.0 if b.def_id == "citadel" else 0.0)
				if d2 < best_d:
					best_d = d2
					best = b.global_position
	return best

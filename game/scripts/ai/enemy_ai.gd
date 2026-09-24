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
	{"id": "sanctum", "t": 310.0},
	{"id": "barracks", "t": 340.0},
	{"id": "habitat", "t": 420.0},
	{"id": "sanctum", "t": 450.0},
	{"id": "bastion", "t": 480.0},
	{"id": "judgement", "t": 600.0},
	{"id": "sanctum_demon", "t": 620.0},
	{"id": "sanctum_angel", "t": 700.0},
]


func setup(w: World, t: int) -> void:
	world = w
	team = t
	rng.seed = 4242


func snapshot() -> Dictionary:
	return {"aggression": aggression, "build_i": _build_i, "next_attack": _next_attack}


func restore(d: Dictionary) -> void:
	aggression = float(d["aggression"])
	_build_i = int(d["build_i"])
	_next_attack = float(d["next_attack"])


func _physics_process(delta: float) -> void:
	if world == null or world.game_over:
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = 1.0
	_economy()
	_construction()
	_superweapon()
	_titan_light()
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
	var picks: Array = []
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
				elif world.match_time > 780.0 and rng.randf() < 0.25 * diff:
					# the titan or the colossus, whichever is not already out
					for c in (["titan", "colossus"] if rng.randf() < 0.5 else ["colossus", "titan"]):
						if b.can_queue(c) in ["", "資源不足"]:
							choice = c
							break
			"barracks":
				choice = "aetherguard" if world.count_units(team, "artificer") >= 2 or rng.randf() < 0.8 else "artificer"
			"foundry":
				var r := rng.randf()
				if p.aether >= 160.0 and r < 0.4:
					choice = "walker" if r < 0.25 or world.match_time < 480.0 else "quadwalker"
				else:
					choice = "strider" if r < 0.7 else "mortar"
			"skyport":
				if rng.randf() < 0.5 * diff:
					var r := rng.randf()
					choice = "mech" if r < 0.45 else ("dreadnought" if r > 0.85 and world.match_time > 720.0 else "airship")
			_:
				if b.def_id.begins_with("sanctum"):
					choice = _beast_choice(b, p, diff)
		if choice != "" and b.can_queue(choice) in ["", "資源不足"]:
			picks.append([b, choice])
	# the dearest units get first call on the treasury and are saved for; infantry spend what
	# is left, unless the army is nearly gone
	picks.sort_custom(func(a: Array, c: Array) -> bool: return _price(a[1]) > _price(c[1]))
	var few_troops := world.count_units(team) - world.count_units(team, "artificer") < 4
	var build := _reserve()
	var held := build
	for pk: Array in picks:
		var b: Building = pk[0]
		var cost: Dictionary = Defs.UNITS[pk[1]]["cost"]
		var need := build if b.def_id in ["citadel", "barracks"] and few_troops else held
		if p.material - float(cost["material"]) >= 60.0 + need.x and p.aether - float(cost["aether"]) >= need.y and b.can_queue(pk[1]) == "":
			b.queue_unit(pk[1])
		elif not b.def_id in ["citadel", "barracks"] and held.x < 400.0:
			held += Vector2(float(cost["material"]), float(cost["aether"]))


static func _price(uid: String) -> float:
	var c: Dictionary = Defs.UNITS[uid]["cost"]
	return float(c["material"]) + float(c["aether"])


## Material and aether held back for the next construction step once its time has come.
func _reserve() -> Vector2:
	if _build_i >= BUILD_PLAN.size() or world.match_time < float(BUILD_PLAN[_build_i]["t"]):
		return Vector2.ZERO
	var cost: Dictionary = Defs.BUILDINGS[BUILD_PLAN[_build_i]["id"]]["cost"]
	return Vector2(float(cost["material"]), float(cost["aether"]))


## A titan turns its Light on the thickest enemy group it can reach.
func _titan_light() -> void:
	for u in world.units:
		if u.team != team or not u.alive or u.def.get("special", "") != "titan_ray" or not u.special_ready():
			continue
		var at := strike_target(u.global_position, float(Defs.SPECIALS["titan_ray"]["range"]) * 0.8)
		if at != Vector3.INF:
			u.use_special(at)


## Fire a charged Tower of Judgement where the most of the enemy stands.
func _superweapon() -> void:
	for b in world.buildings:
		if b.team == team and b.strike_ready():
			var at := strike_target()
			if at != Vector3.INF:
				b.fire_superweapon(at)


## The point where a strike hurts the enemy most: units weighted by cost, buildings by a flat
## share. Scored around every enemy unit and building.
func strike_target(near := Vector3.INF, within := INF) -> Vector3:
	var foes: Array[Entity] = []
	for u in world.units:
		if u.alive and u.team != team and u.team >= 0:
			foes.append(u)
	for b in world.buildings:
		if b.alive and b.team != team and b.team >= 0 and b.def_id != "gate":
			foes.append(b)
	if near != Vector3.INF:
		foes = foes.filter(func(e: Entity) -> bool: return Vector2(e.global_position.x - near.x, e.global_position.z - near.z).length() < within)
	var best := Vector3.INF
	var best_score := 0.0
	for c in foes:
		var score := 0.0
		for e in foes:
			if Vector2(e.global_position.x - c.global_position.x, e.global_position.z - c.global_position.z).length() < 16.0:
				if e is Unit:
					var cost: Dictionary = (e as Unit).def["cost"]
					score += float(cost["material"]) + float(cost["aether"])
				else:
					score += 250.0
		if score > best_score:
			best_score = score
			best = c.global_position
	return best


## A beast from this shrine: griffins mostly to answer enemy fliers, a dragon when aether allows.
func _beast_choice(b: Building, p: PlayerState, diff: float) -> String:
	if rng.randf() > 0.6 * diff:
		return ""
	var fliers := 0
	for u in world.units:
		if u.alive and u.team != team and u.is_air:
			fliers += 1
	var options: Array = b.produces().filter(func(id: String) -> bool:
		match id:
			"griffin":
				return fliers >= 2 or rng.randf() < 0.3
			"dragon":
				return p.aether >= 320.0
		return true)
	return "" if options.is_empty() else options[rng.randi() % options.size()]


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
	var p := _site_for(id, c.global_position)
	_build_i += 1
	if p == Vector3.INF:
		return  # no room anywhere: drop this step so the plan keeps moving
	_me().spend(d["cost"])
	var to_center := -p
	world.spawn_building(id, team, p, atan2(to_center.x, to_center.z), false)


## Towers go out toward the map centre; everything else takes the free spot nearest the citadel,
## then around the gate and the cities we hold, the same ground the player may build on.
## Candidates are scanned on a 4 m grid, so large buildings find the few flat places that fit.
func _site_for(id: String, home: Vector3) -> Vector3:
	if id == "bastion":
		for attempt in 40:
			var q := home.lerp(Vector3.ZERO, rng.randf_range(0.18, 0.3)) + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
			if _valid(id, q):
				return q
	var anchors := [[home, 18.0, 62.0]]
	for b in world.buildings:
		if b.alive and b.team == team and b.def_id == "gate":
			anchors.append([b.global_position, 12.0, 26.0])
	for site in world.sites:
		if site.owner_team == team:
			anchors.append([site.global_position, site.radius + 4.0, site.radius + 20.0])
	for a: Array in anchors:
		var q := _nearest_free(id, a[0], a[1], a[2])
		if q != Vector3.INF:
			return q
	return Vector3.INF


func _nearest_free(id: String, at: Vector3, r0: float, r1: float) -> Vector3:
	var n := int(ceil(r1 / 4.0))
	var spots: Array[Vector3] = []
	for gx in range(-n, n + 1):
		for gz in range(-n, n + 1):
			var r := Vector2(gx, gz).length() * 4.0
			var q := at + Vector3(gx * 4.0, 0, gz * 4.0)
			if r >= r0 and r <= r1 and absf(q.x) < 185.0 and absf(q.z) < 185.0:
				spots.append(q)
	spots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(at) < b.distance_squared_to(at))
	for q in spots:
		if _valid(id, q):
			return q
	return Vector3.INF


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
		if b.alive and Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length() < b.radius + d["radius"] + 2.0:
			return false
	# keep ramps clear
	for pl in world.terrain.layout["plateaus"]:
		for rp in pl["ramps"]:
			var top := Vector3(rp["top"][0], 0, rp["top"][1])
			if Vector2(top.x - p.x, top.z - p.z).length() < 12.0 + d["radius"]:
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

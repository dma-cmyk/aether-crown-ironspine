extends Node
## Dev: plays the Crown side through the Commander/World APIs and logs the match.
## godot --headless --path game -- --match --autoplay [--timescale=8] [--limit=1500]

var world: World
var commander: Commander
var mission: Mission
var _t := 0.0
var _limit := 1500.0
var _stage := "defend"
var _built := {}
var _log_t := 0.0


func setup(w: World, c: Commander, m: Mission) -> void:
	world = w
	commander = c
	mission = m
	_limit = float(Game.arg("limit", "1500"))
	Engine.time_scale = float(Game.arg("timescale", "8"))
	Engine.max_physics_steps_per_frame = 16
	world.alert.connect(func(_p, text, team): if team == 0: _log("alert: " + text))
	world.site_captured.connect(func(s, team): _log("captured %s by %d" % [s.site_name, team]))
	world.game_ended.connect(_on_end)
	world.entity_died.connect(func(e): if e is Building: _log("building destroyed: %s (team %d)" % [e.def_id, e.team]))


func _log(s: String) -> void:
	var t := int(world.match_time)
	print("[%02d:%02d] %s" % [t / 60, t % 60, s])


func _on_end(winner: int) -> void:
	_log("GAME OVER winner=%d  stats0=%s stats1=%s" % [winner, world.player(0).stats, world.player(1).stats])
	get_tree().quit()


func _process(delta: float) -> void:
	if world.game_over:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 2.0
	if world.match_time > _limit:
		_log("TIME LIMIT  units0=%d units1=%d bld0=%d bld1=%d" % [world.count_units(0), world.count_units(1), world.count_buildings(0), world.count_buildings(1)])
		get_tree().quit()
		return
	_economy()
	_army()
	_log_t -= 2.0
	if _log_t <= 0.0:
		_log_t = 60.0
		var p := world.player(0)
		var e := world.player(1)
		_log("status: M=%d A=%d pop=%d/%d units=%d | enemy M=%d units=%d bld=%d | phase=%d stage=%s" % [p.material, p.aether,
				p.pop_used, p.pop_cap, world.count_units(0), e.material, world.count_units(1), world.count_buildings(1), int(mission.get_var("phase")), _stage])


func _economy() -> void:
	var p := world.player(0)
	var cit := world.citadel(0)
	if cit == null:
		return
	# construction plan
	for plan in [["foundry", 60.0], ["refinery", 100.0], ["habitat", 130.0], ["habitat", 240.0], ["skyport", 400.0], ["refinery", 460.0]]:
		var key := "%s@%d" % plan
		if _built.has(key) or world.match_time < float(plan[1]):
			continue
		if not p.can_afford(Defs.BUILDINGS[plan[0]]["cost"]):
			break
		for i in 40:
			var a := randf() * TAU
			var pos := cit.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(22.0, 45.0)
			if commander.placement_valid(plan[0], pos):
				p.spend(Defs.BUILDINGS[plan[0]]["cost"])
				world.spawn_building(plan[0], 0, pos, deg_to_rad(135), false)
				_built[key] = true
				_log("build %s" % plan[0])
				break
		break
	for b in world.buildings:
		if b.team != 0 or not b.built or b.production.size() >= 2:
			continue
		match b.def_id:
			"citadel":
				if world.count_units(0, "artificer") < 3:
					b.queue_unit("artificer")
			"barracks":
				b.queue_unit("aetherguard")
			"foundry":
				b.queue_unit("walker" if randf() < 0.6 else "mortar")
			"skyport":
				b.queue_unit("airship")


func _army() -> void:
	var army: Array = world.units.filter(func(u): return u.team == 0 and u.alive and u.def_id != "artificer")
	var arts: Array = world.units.filter(func(u): return u.team == 0 and u.alive and u.def_id == "artificer")
	# artificers claim neutral cities on our side, then repair near the gate
	var targets := ["west_foundry", "south_works", "central_nexus"]
	for i in arts.size():
		var a: Unit = arts[i]
		if a.order != Unit.Order.IDLE:
			continue
		for s in world.sites:
			if s.site_id == targets[i % targets.size()] and s.owner_team != 0 and (s.site_id != "central_nexus" or int(mission.get_var("phase")) == 1):
				a.order_move(s.global_position)
	var idle: Array = army.filter(func(u): return u.order in [Unit.Order.IDLE, Unit.Order.HOLD])
	match _stage:
		"defend":
			for u: Unit in idle:
				if u.flat_distance_to(Vector3(-60, 0, 60)) > 25.0:
					u.order_attack_move(Vector3(-60, 0, 60) + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)))
			if int(mission.get_var("phase")) == 1 and army.size() >= 12:
				_stage = "nexus"
				_log("army -> Central Nexus (%d units)" % army.size())
				commander.move_group(army, Vector3(0, 0, 0), false, true)
		"nexus":
			var nexus: Site = world.sites.filter(func(s): return s.site_id == "central_nexus")[0]
			var p := world.player(0)
			if nexus.owner_team == 0 and (army.size() >= 14 or p.pop_used + 8 > p.pop_cap):
				_stage = "assault"
				_log("army -> Varkesh Citadel (%d units)" % army.size())
				commander.move_group(army, Vector3(140, 0, -140), false, true)
			elif not idle.is_empty():
				commander.move_group(idle, Vector3(0, 0, 0), false, true)
		"assault":
			if not idle.is_empty():
				var c := world.citadel(1)
				if c:
					for u: Unit in idle:
						u.order_attack(c)
			if army.size() < 6:
				_stage = "nexus"
				_log("assault repelled, regrouping")

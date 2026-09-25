class_name World
extends Node3D
## Owns all gameplay entities, runs the fixed-rate simulation and answers spatial queries.

static var inst: World

signal entity_spawned(e: Entity)
signal entity_died(e: Entity)
signal site_captured(site: Site, team: int)
signal alert(pos: Vector3, text: String, team: int)
signal game_ended(winner: int)

const GRID_CELL := 16.0

var terrain: Terrain
var nav: NavGrid
var fx: FX
var sfx: Sfx
var camera: CameraRig
var fog: FogOfWar
var forest: Forest
var projectiles: Projectiles
var players: Array[PlayerState] = []
var units: Array[Unit] = []
var buildings: Array[Building] = []
var sites: Array[Site] = []
var infantry_renderers := {}
var match_time := 0.0
var game_over := false
var winner := -1
var unit_root: Node3D
var building_root: Node3D

var _grid := {}
var _economy_timer := 0.0
var _alert_cooldowns := {}


func _init() -> void:
	inst = self


func setup(t: Terrain, cam: CameraRig) -> void:
	terrain = t
	camera = cam
	nav = NavGrid.new()
	var meta: Dictionary = t.placements["meta"]
	nav.load_from(Terrain.DIR + "nav.bin", t.size, float(meta["nav_cell"]))
	players = [PlayerState.new(0), PlayerState.new(1)]
	unit_root = Node3D.new()
	unit_root.name = "Units"
	add_child(unit_root)
	building_root = Node3D.new()
	building_root.name = "Buildings"
	add_child(building_root)
	fx = FX.new()
	fx.name = "FX"
	add_child(fx)
	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	projectiles = Projectiles.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	fog = FogOfWar.new()
	fog.name = "Fog"
	add_child(fog)
	fog.setup(self)
	forest = Forest.new()
	forest.setup(self)


## How far from the citadel, a gate or a held city a side may build (the city's own radius is added).
const BUILD_AREA := {"citadel": 85.0, "gate": 32.0, "site": 26.0}


## The circles a side may build in: [[centre, radius], ...].
func build_areas(team: int) -> Array:
	var out := []
	for b in buildings:
		if b.team == team and b.alive and BUILD_AREA.has(b.def_id):
			out.append([b.global_position, BUILD_AREA[b.def_id]])
	for s in sites:
		if s.owner_team == team:
			out.append([s.global_position, s.radius + BUILD_AREA["site"]])
	return out


func in_build_area(team: int, p: Vector3) -> bool:
	if not terrain.in_bounds(p.x, p.z, 20.0):
		return false
	for a: Array in build_areas(team):
		if Vector2(a[0].x - p.x, a[0].z - p.z).length() < a[1]:
			return true
	return false


func player(team: int) -> PlayerState:
	return players[team] if team >= 0 and team < players.size() else null


# ---------------------------------------------------------------- spawning
func spawn_unit(id: String, team: int, pos: Vector3, facing: float = 0.0) -> Unit:
	var u := Unit.new()
	u.name = "%s_%d" % [id, randi() % 100000]
	unit_root.add_child(u)
	u.setup(id, team, pos, facing)
	units.append(u)
	entity_spawned.emit(u)
	return u


func spawn_building(id: String, team: int, pos: Vector3, facing: float, built: bool = true) -> Building:
	if not built:
		# construction starts: fell the trees on the site
		forest.clear_area(pos, float(Defs.BUILDINGS[id]["footprint"]) + 1.0)
	var b := Building.new()
	b.name = "%s_%d" % [id, randi() % 100000]
	building_root.add_child(b)
	b.setup(id, team, pos, facing, built)
	buildings.append(b)
	entity_spawned.emit(b)
	return b


func infantry_renderer(model: String, team: int) -> InfantryRenderer:
	var key := "%s|%d" % [model, team]
	if not infantry_renderers.has(key):
		var r := InfantryRenderer.new()
		r.name = "Infantry_%s_%d" % [model, team]
		add_child(r)
		r.setup(model, team)
		infantry_renderers[key] = r
	return infantry_renderers[key]


func on_entity_died(e: Entity) -> void:
	entity_died.emit(e)
	var p := player(e.team)
	if p:
		if e is Unit:
			p.stats["lost"] += 1
		else:
			p.stats["buildings_lost"] += 1
	if e.last_attacker and is_instance_valid(e.last_attacker):
		var k := player(e.last_attacker.team)
		if k:
			k.stats["kills"] += 1


func remove_unit(u: Unit) -> void:
	units.erase(u)


func remove_building(b: Building) -> void:
	buildings.erase(b)


# ---------------------------------------------------------------- simulation
func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	match_time += delta
	_rebuild_grid()
	for u in units.duplicate():
		if is_instance_valid(u):
			u.tick(delta)
	for b in buildings.duplicate():
		if is_instance_valid(b):
			b.tick(delta)
	for s in sites:
		s.tick(delta)
	projectiles.tick(delta)
	for p in players:
		p.tick(delta)
	_economy_timer -= delta
	if _economy_timer <= 0.0:
		_economy_timer = 0.5
		for p in players:
			p.recompute(self)


func _rebuild_grid() -> void:
	_grid.clear()
	for u in units:
		if u.alive:
			_grid_add(u)
	for b in buildings:
		if b.alive:
			_grid_add(b)


func _grid_add(e: Entity) -> void:
	var p := e.global_position
	var key := Vector2i(floori(p.x / GRID_CELL), floori(p.z / GRID_CELL))
	if not _grid.has(key):
		_grid[key] = []
	_grid[key].append(e)


## Entities whose centre lies within `radius` (+ their own radius) of pos.
func query(pos: Vector3, radius: float) -> Array:
	var out := []
	var r := radius + 14.0
	var x0 := floori((pos.x - r) / GRID_CELL)
	var x1 := floori((pos.x + r) / GRID_CELL)
	var z0 := floori((pos.z - r) / GRID_CELL)
	var z1 := floori((pos.z + r) / GRID_CELL)
	for gx in range(x0, x1 + 1):
		for gz in range(z0, z1 + 1):
			var list: Array = _grid.get(Vector2i(gx, gz), [])
			for e: Entity in list:
				if not e.alive:
					continue
				var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
				if d <= radius + e.radius:
					out.append(e)
	return out


## Best hostile target for `team` near pos.
func find_target(pos: Vector3, radius: float, team: int, can_air: bool, can_ground: bool, prefer: Entity = null) -> Entity:
	var best: Entity = null
	var best_score := INF
	for e: Entity in query(pos, radius):
		if e.team == team or e.team == Defs.TEAM_NEUTRAL:
			continue
		if e.is_air and not can_air:
			continue
		if not e.is_air and not can_ground:
			continue
		if team == Defs.TEAM_PLAYER and not e.seen_by_player:
			continue
		var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length() - e.radius
		var score := d
		if e.is_building:
			score += 18.0 if e.def.get("weapons", []).is_empty() else 4.0
		if e == prefer:
			score -= 10.0
		if score < best_score:
			best_score = score
			best = e
	return best


func friendly_units_near(pos: Vector3, radius: float, team: int) -> Array:
	var out := []
	for e: Entity in query(pos, radius):
		if e is Unit and e.team == team:
			out.append(e)
	return out


func citadel(team: int) -> Building:
	for b in buildings:
		if b.team == team and b.def_id == "citadel" and b.alive:
			return b
	return null


func count_units(team: int, id: String = "") -> int:
	var c := 0
	for u in units:
		if u.team == team and u.alive and (id == "" or u.def_id == id):
			c += 1
	return c


func count_buildings(team: int, id: String = "", only_built: bool = false) -> int:
	var c := 0
	for b in buildings:
		if b.team == team and b.alive and (id == "" or b.def_id == id) and (not only_built or b.built):
			c += 1
	return c


func raise_alert(pos: Vector3, text: String, team: int, key: String = "", cooldown: float = 12.0) -> void:
	if key != "":
		if match_time < float(_alert_cooldowns.get(key, -100.0)):
			return
		_alert_cooldowns[key] = match_time + cooldown
	alert.emit(pos, text, team)


func end_game(win_team: int) -> void:
	if game_over:
		return
	game_over = true
	winner = win_team
	game_ended.emit(win_team)

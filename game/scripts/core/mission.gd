class_name Mission
extends Node
## Plays a Scenario: applies its starting setup, keeps the objective list current and fires
## triggers (condition -> actions) twice a second. Losing a citadel ends the game unless the
## scenario defines its own victory / defeat conditions.

const TICK := 0.5
const WAVE_SCALE := [0.75, 1.0, 1.35]

var world: World
var ai: EnemyAI
var hud: HUD
var scenario: Scenario
## Where Space jumps the camera; scenarios move it with the "focus" action.
var focus_point := Vector3.INF
var vars := {}
## Trigger id -> match time it last fired.
var fired := {}
var objective_title := ""
var objective_sub := ""
var objectives: Array[Dictionary] = []
var _triggers: Array[Dictionary] = []
var _victory := {}
var _defeat := {}
var _tick := 0.0
var _tags := RegEx.create_from_string("\\{(var|countdown|timer|sites|units):([^}]*)\\}")


func setup(w: World, a: EnemyAI, h: HUD, s: Scenario) -> void:
	world = w
	ai = a
	hud = h
	scenario = s
	var d := s.data
	vars = (d.get("vars", {}) as Dictionary).duplicate()
	var teams: Dictionary = d.get("teams", {})
	for key: String in teams:
		var conf: Dictionary = teams[key]
		var p := world.player(int(key))
		p.material = float(conf.get("material", p.material))
		p.aether = float(conf.get("aether", p.aether))
		if int(key) == ai.team:
			ai.aggression = float(conf.get("aggression", ai.aggression))
	var start: Dictionary = d.get("start", {})
	for b: Dictionary in start.get("buildings", []):
		_spawn_building(b)
	for u: Dictionary in start.get("units", []):
		var unit := world.spawn_unit(u["id"], int(u["team"]), _ground(u["at"]), deg_to_rad(float(u.get("facing", 0.0))))
		unit.tag = str(u.get("tag", ""))
	var list: Array = d.get("triggers", [])
	for i in list.size():
		var t: Dictionary = list[i]
		_triggers.append({"id": str(t.get("id", "trigger_%d" % i)), "when": t["when"], "do": t["do"],
				"repeat": bool(t.get("repeat", false)), "cooldown": float(t.get("cooldown", 0.0)), "next": 0.0, "done": false})
	_victory = d.get("victory", _citadel_lost(Defs.TEAM_ENEMY))
	_defeat = d.get("defeat", _citadel_lost(Defs.TEAM_PLAYER))
	if d.has("objectives"):
		_set_objectives(d["objectives"])
	world.entity_died.connect(func(_e: Entity) -> void: _check_end())
	_step()


func get_var(var_name: String) -> float:
	return float(vars.get(var_name, 0.0))


## Default end condition: a side that starts with a citadel loses when it falls.
func _citadel_lost(team: int) -> Dictionary:
	if world.citadel(team) == null:
		return {}
	return {"type": "buildings", "team": team, "id": "citadel", "cmp": "==", "value": 0}


func _process(delta: float) -> void:
	if world.game_over:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_step()


func _step() -> void:
	for t in _triggers:
		if t["done"] or world.match_time < t["next"] or not _eval(t["when"]):
			continue
		fired[t["id"]] = world.match_time
		if t["repeat"]:
			t["next"] = world.match_time + maxf(t["cooldown"], TICK)
		else:
			t["done"] = true
		for a: Dictionary in t["do"]:
			_act(a)
		if world.game_over:
			return
	_check_end()
	_refresh()


func _check_end() -> void:
	if world.game_over:
		return
	if _eval(_defeat):
		world.end_game(Defs.TEAM_ENEMY)
	elif _eval(_victory):
		world.end_game(Defs.TEAM_PLAYER)


# ---------------------------------------------------------------- conditions
func _eval(c: Dictionary) -> bool:
	if c.is_empty():
		return false
	match str(c["type"]):
		"time":
			if c.has("since"):
				return fired.has(c["since"]) and world.match_time - float(fired[c["since"]]) >= float(c["at"])
			return world.match_time >= float(c["at"])
		"var":
			return _cmp(get_var(c["name"]), c)
		"units":
			return _cmp(_units(c).size(), c)
		"buildings":
			return _cmp(world.buildings.filter(func(b: Building) -> bool: return b.alive and _matches(b, c)).size(), c)
		"sites":
			return _cmp(_sites(c), c)
		"resource":
			var p := world.player(int(c["team"]))
			return _cmp(p.material if c["kind"] == "material" else p.aether, c)
		"fired":
			return fired.has(c["trigger"])
		"objective":
			for o in objectives:
				if o["id"] == c["id"]:
					return o["state"] == str(c.get("state", "done"))
			return false
		"all":
			for x: Dictionary in c["of"]:
				if not _eval(x):
					return false
			return true
		"any":
			for x: Dictionary in c["of"]:
				if _eval(x):
					return true
			return false
		"not":
			return not _eval(c["of"])
	return false


static func _cmp(v: float, c: Dictionary) -> bool:
	var target := float(c.get("value", 1))
	match str(c.get("cmp", ">=")):
		">":
			return v > target
		"<=":
			return v <= target
		"<":
			return v < target
		"==":
			return is_equal_approx(v, target)
		"!=":
			return not is_equal_approx(v, target)
	return v >= target


func _sites(f: Dictionary) -> int:
	var n := 0
	for s in world.sites:
		if (not f.has("team") or s.owner_team == int(f["team"])) and (not f.has("id") or s.site_id == str(f["id"])):
			n += 1
	return n


func _units(f: Dictionary) -> Array:
	return world.units.filter(func(u: Unit) -> bool: return u.alive and _matches(u, f))


## Optional filters shared by conditions and the "order" action: team, id, tag, area [x, z, r].
func _matches(e: Entity, f: Dictionary) -> bool:
	if f.has("team") and e.team != int(f["team"]):
		return false
	if f.has("id") and e.def_id != str(f["id"]):
		return false
	if f.has("tag") and e.tag != str(f["tag"]):
		return false
	if f.has("area"):
		var r: Array = f["area"]
		if Vector2(e.global_position.x - float(r[0]), e.global_position.z - float(r[1])).length() > float(r[2]):
			return false
	return true


# ---------------------------------------------------------------- actions
func _act(a: Dictionary) -> void:
	match str(a["type"]):
		"message":
			world.raise_alert(_flat(a.get("at", [0, 0])), _text(a["text"]), Defs.TEAM_PLAYER)
			if a.has("sound"):
				world.sfx.play_ui(str(a["sound"]), -2.0)
		"banner":
			hud.show_banner(_text(a["title"]), _text(str(a.get("text", ""))), float(a.get("seconds", 6.0)))
		"advisor":
			hud.set_advisor(str(a["text"]))
		"spawn":
			_spawn_units(a)
		"spawn_building":
			_spawn_building(a)
		"order":
			for u: Unit in _units(a):
				_order(u, a)
		"resources":
			var p := world.player(int(a["team"]))
			p.material += float(a.get("material", 0.0))
			p.aether += float(a.get("aether", 0.0))
		"ai":
			ai.aggression = float(a["aggression"])
		"objectives":
			_set_objectives(a)
		"objective":
			for o in objectives:
				if o["id"] == a["id"]:
					o["state"] = str(a["state"])
			_refresh()
		"set_var":
			vars[a["name"]] = float(a["value"])
		"add_var":
			vars[a["name"]] = get_var(a["name"]) + float(a["value"])
		"focus":
			focus_point = _flat(a["at"])
		"sound":
			world.sfx.play_ui(str(a["name"]), float(a.get("volume_db", 0.0)))
		"site":
			for s in world.sites:
				if s.site_id == str(a["id"]):
					s.assign(int(a["team"]))
		"victory":
			world.end_game(Defs.TEAM_PLAYER)
		"defeat":
			world.end_game(Defs.TEAM_ENEMY)


## Lays the units out in rows of `columns` (spacing [across, back]) turned by `rotate` degrees.
func _spawn_units(a: Dictionary) -> void:
	var team := int(a["team"])
	var origin := _flat(a["at"])
	var cols := maxi(1, int(a.get("columns", 4)))
	var gap: Array = a.get("spacing", [6.0, 6.0])
	var rot := deg_to_rad(float(a.get("rotate", 0.0)))
	var mult: float = WAVE_SCALE[Game.difficulty] if a.get("difficulty_scale", false) else 1.0
	var k := 0
	for id: String in a["units"]:
		for i in int(ceil(float(a["units"][id]) * mult)):
			var off := Vector3((k % cols - (cols - 1) * 0.5) * float(gap[0]), 0, (k / cols) * float(gap[1]))
			var u := world.spawn_unit(id, team, world.nav.nearest_walkable_pos(origin + off.rotated(Vector3.UP, rot)),
					deg_to_rad(float(a.get("facing", 0.0))))
			u.tag = str(a.get("tag", ""))
			_order(u, a)
			k += 1


func _spawn_building(b: Dictionary) -> void:
	var bld := world.spawn_building(str(b["id"]), int(b["team"]), _flat(b["at"]), deg_to_rad(float(b.get("facing", 0.0))),
			bool(b.get("built", true)))
	bld.tag = str(b.get("tag", ""))


func _order(u: Unit, a: Dictionary) -> void:
	var kind := str(a.get("order", ""))
	if kind == "hold":
		u.order_hold()
	if not kind in ["move", "attack_move", "patrol"]:
		return
	var spread := float(a.get("spread", 0.0))
	var p := _flat(a["target"]) + Vector3(randf_range(-spread, spread), 0, randf_range(-spread, spread))
	match kind:
		"move":
			u.order_move(p)
		"attack_move":
			u.order_attack_move(p)
		"patrol":
			u.order_patrol(p)


# ---------------------------------------------------------------- objectives
func _set_objectives(o: Dictionary) -> void:
	objective_title = str(o.get("title", objective_title))
	objective_sub = str(o.get("subtitle", objective_sub))
	var old := {}
	for x in objectives:
		old[x["id"]] = x["state"]
	objectives.clear()
	for item: Dictionary in o["list"]:
		var id := str(item.get("id", ""))
		objectives.append({"id": id, "text": str(item["text"]), "state": str(item.get("state", old.get(id, "open"))),
				"done_when": item.get("done_when", {}), "failed_when": item.get("failed_when", {})})
	_refresh()


## Objectives with conditions follow them live; the rest keep the state actions gave them.
func _refresh() -> void:
	var items := []
	for o in objectives:
		if not o["failed_when"].is_empty() and _eval(o["failed_when"]):
			o["state"] = "failed"
		elif not o["done_when"].is_empty():
			o["state"] = "done" if _eval(o["done_when"]) else "open"
		elif not o["failed_when"].is_empty() and o["state"] == "failed":
			o["state"] = "open"
		items.append({"text": _text(o["text"]), "state": o["state"]})
	hud.set_objectives(objective_title, objective_sub, items)


## Fills {var:name}, {countdown:seconds}, {timer:trigger:seconds}, {sites:team} and {units:team[:tag]}.
func _text(s: String) -> String:
	var out := s
	for m in _tags.search_all(s):
		var arg := m.get_string(2)
		var v := ""
		match m.get_string(1):
			"var":
				var x := get_var(arg)
				v = str(int(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x
			"countdown":
				v = _clock(float(arg) - world.match_time)
			"timer":
				var since := arg.get_slice(":", 0)
				var length := float(arg.get_slice(":", 1))
				v = _clock(length - (world.match_time - float(fired[since]) if fired.has(since) else 0.0))
			"sites":
				v = str(_sites({"team": arg}))
			"units":
				var f := {"team": arg.get_slice(":", 0)}
				if arg.contains(":"):
					f["tag"] = arg.get_slice(":", 1)
				v = str(_units(f).size())
		out = out.replace(m.get_string(), v)
	return out


static func _clock(seconds: float) -> String:
	var s := int(maxf(0.0, seconds))
	return "%d:%02d" % [s / 60, s % 60]


static func _flat(p: Array) -> Vector3:
	return Vector3(float(p[0]), 0, float(p[1]))


func _ground(p: Array) -> Vector3:
	return world.nav.nearest_walkable_pos(_flat(p))

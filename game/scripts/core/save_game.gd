class_name SaveGame
extends RefCounted
## Mid-mission saves: a JSON snapshot of the battlefield (players, cities, buildings, units,
## explored fog), the scenario's progress and the enemy AI, kept in user://saves/slot<N>.json.
## Shells in flight and visual effects are not saved.

const DIR := "user://saves"
const SLOTS := 3
const FORMAT := 1


static func slot_path(i: int) -> String:
	return DIR.path_join("slot%d.json" % i)


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary and int(v.get("format", 0)) == FORMAT else {}


static func write(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


static func has_any() -> bool:
	for i in range(1, SLOTS + 1):
		if FileAccess.file_exists(slot_path(i)):
			return true
	return false


# ---------------------------------------------------------------- capture
static func capture(m: Node) -> Dictionary:
	var w: World = m.world
	var units: Array = w.units.filter(func(u: Unit) -> bool: return u.alive)
	var blds: Array = w.buildings.filter(func(b: Building) -> bool: return b.alive)
	# units first, then buildings: order targets are saved as indices into this list
	var index := {}
	for e: Entity in units + blds:
		index[e] = index.size()
	var out_units := []
	for u: Unit in units:
		var d := {"id": u.def_id, "team": u.team, "at": _xz(u.global_position), "facing": u.facing, "hp": u.hp, "tag": u.tag,
				"order": int(u.order), "dest": _xz(u.move_target), "patrol": _xz(u.patrol_b),
				"queue": u.queue.map(func(p: Vector3) -> Array: return _xz(p)),
				"fortified": u.fortified, "deployed": u.deployed, "special_cd": u.special_cd}
		var t: Entity = u.repair_target if u.order == Unit.Order.REPAIR else u.target
		if u.order in [Unit.Order.ATTACK, Unit.Order.REPAIR] and t and index.has(t):
			d["target"] = index[t]
		out_units.append(d)
	var out_blds := []
	for b: Building in blds:
		out_blds.append({"id": b.def_id, "team": b.team, "at": _xz(b.global_position), "facing": b.facing, "hp": b.hp,
				"tag": b.tag, "built": b.built, "progress": b.progress, "production": Array(b.production), "prod_t": b.prod_t,
				"rally": _xz(b.rally) if b.rally != Vector3.INF else []})
	var sites := []
	for s in w.sites:
		sites.append({"id": s.site_id, "owner": s.owner_team, "capture": s.capture, "capturing": s.capturing_team})
	var players := []
	for p in w.players:
		players.append({"material": p.material, "aether": p.aether, "income_mult": p.income_mult, "stats": p.stats})
	var cam: CameraRig = m.camera
	return {
		"format": FORMAT,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"scenario": m.scenario.path,
		"title": m.scenario.title(),
		"difficulty": Game.difficulty,
		"match_time": w.match_time,
		"camera": [cam.focus.x, cam.focus.z, rad_to_deg(cam.yaw), cam.distance],
		"players": players,
		"sites": sites,
		"buildings": out_blds,
		"units": out_units,
		"explored": Marshalls.raw_to_base64(w.fog.explored.compress(FileAccess.COMPRESSION_ZSTD)),
		"mission": m.mission.snapshot(),
		"ai": m.ai.snapshot(),
	}


# ---------------------------------------------------------------- restore
## Rebuilds the battlefield from a save. Called by the match before the mission and AI start.
static func restore_world(m: Node, d: Dictionary) -> void:
	var w: World = m.world
	w.match_time = float(d["match_time"])
	for i in mini(w.players.size(), d["players"].size()):
		var pd: Dictionary = d["players"][i]
		var p := w.player(i)
		p.material = float(pd["material"])
		p.aether = float(pd["aether"])
		p.income_mult = float(pd["income_mult"])
		for k: String in pd["stats"]:
			p.stats[k] = int(pd["stats"][k])
	for sd: Dictionary in d["sites"]:
		for s in w.sites:
			if s.site_id == sd["id"]:
				s.restore(int(sd["owner"]), float(sd["capture"]), int(sd["capturing"]))
	var ents: Array[Entity] = []
	for ud: Dictionary in d["units"]:
		var u := w.spawn_unit(ud["id"], int(ud["team"]), _v3(ud["at"]), float(ud["facing"]))
		u.hp = float(ud["hp"])
		u.tag = str(ud["tag"])
		u.special_cd = float(ud["special_cd"])
		if u.visual is SquadVisual:
			(u.visual as SquadVisual).drop_fallen()
		ents.append(u)
	for bd: Dictionary in d["buildings"]:
		var b := w.spawn_building(bd["id"], int(bd["team"]), _v3(bd["at"]), float(bd["facing"]), bool(bd["built"]))
		b.tag = str(bd["tag"])
		b.restore_progress(float(bd["progress"]), float(bd["hp"]))
		b.production.assign(bd["production"])
		b.prod_t = float(bd["prod_t"])
		if not bd["rally"].is_empty():
			b.rally = _v3(bd["rally"])
		ents.append(b)
	# orders last, once every target exists
	for i in d["units"].size():
		var ud: Dictionary = d["units"][i]
		var u: Unit = ents[i]
		var t: Entity = ents[int(ud["target"])] if ud.has("target") else null
		match int(ud["order"]):
			Unit.Order.MOVE:
				u.order_move(_v3(ud["dest"]))
				for q: Array in ud["queue"]:
					u.order_move(_v3(q), true)
			Unit.Order.ATTACK_MOVE:
				u.order_attack_move(_v3(ud["dest"]))
			Unit.Order.PATROL:
				u.order_patrol(_v3(ud["patrol"]))
			Unit.Order.HOLD:
				u.order_hold()
			Unit.Order.ATTACK:
				u.order_attack(t)
			Unit.Order.REPAIR:
				u.order_repair(t)
		u.restore_modes(bool(ud["fortified"]), bool(ud["deployed"]))
	var raw := Marshalls.base64_to_raw(str(d["explored"])).decompress(w.fog.explored.size(), FileAccess.COMPRESSION_ZSTD)
	if raw.size() == w.fog.explored.size():
		w.fog.explored = raw
	var c: Array = d["camera"]
	m.camera.set_view(Vector3(float(c[0]), 0, float(c[1])), float(c[2]), float(c[3]))


static func _xz(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.z, 0.01)]


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), 0, float(a[1]))

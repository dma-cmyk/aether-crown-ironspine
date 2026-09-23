class_name Mission
extends Node
## "Hold the Gate": survive scripted assaults on the Ironspine Gate until reinforcements
## arrive, then take the Central Nexus and break the Varkesh Citadel.

const REINFORCE_AT := 330.0
const WAVES := [
	{"t": 55.0, "units": {"aetherguard": 3}},
	{"t": 130.0, "units": {"aetherguard": 3, "mortar": 1}},
	{"t": 210.0, "units": {"aetherguard": 4, "walker": 1}},
	{"t": 290.0, "units": {"aetherguard": 4, "walker": 2, "mortar": 1}},
]

var world: World
var ai: EnemyAI
var hud: HUD
var phase := 0
var gate: Building
var gate_lost := false
var waves_sent := 0
var wave_units: Array[Unit] = []
var focus_point := Vector3(-51.5, 0, 51.5)
var _tick := 0.0
var _nexus_taken := false
var _warned := false
var _hint_i := 0

const HINTS := [
	[3.0, "ヒント：左ドラッグで部隊を選び、右クリックで移動・攻撃。F で構えると被ダメージが半減する。"],
	[18.0, "ヒント：本拠地（Home キー）を選んで B で建設メニュー。工廠（W）を建てると歩行機と臼砲が作れる。"],
	[36.0, "ヒント：工兵で近くの West Foundry / South Works を占領すると収入と人口上限が増える。"],
	[150.0, "ヒント：臼砲は D で展開すると射程が 72m まで伸びる。橋の手前に並べよう。"],
	[240.0, "ヒント：S で特殊能力。歩兵のエーテル弾は装甲にも効く。"],
]


func setup(w: World, a: EnemyAI, h: HUD) -> void:
	world = w
	ai = a
	hud = h
	for b in world.buildings:
		if b.def_id == "gate" and b.team == Defs.TEAM_PLAYER:
			gate = b
	ai.aggression = 0.0
	world.entity_died.connect(_on_died)
	world.site_captured.connect(_on_captured)
	_refresh()
	hud.show_banner("HOLD THE GATE", "ヴァルケシュ軍がアイアンスパイン門に迫っている。援軍到着まで持ちこたえよ。", 7.0)
	hud.set_advisor("SOME THINGS\nOUTLIVE EMPIRES.")


func _process(delta: float) -> void:
	if world.game_over:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	var t := world.match_time
	_check_end()
	if _hint_i < HINTS.size() and t >= float(HINTS[_hint_i][0]):
		world.raise_alert(Vector3.ZERO, HINTS[_hint_i][1], Defs.TEAM_PLAYER)
		_hint_i += 1
	if phase == 0:
		if waves_sent < WAVES.size() and t >= float(WAVES[waves_sent]["t"]):
			_send_wave(WAVES[waves_sent])
			waves_sent += 1
		if not _warned and waves_sent < WAVES.size() and t >= float(WAVES[waves_sent]["t"]) - 12.0:
			_warned = true
			world.raise_alert(Vector3(40, 0, -40), "敵の攻撃部隊が中央の橋に集結している！", Defs.TEAM_PLAYER)
		elif _warned and waves_sent < WAVES.size() and t < float(WAVES[waves_sent]["t"]) - 12.0:
			_warned = false
		if t >= REINFORCE_AT:
			_reinforce()
		_refresh()
	elif phase == 1:
		_refresh()


func _send_wave(w: Dictionary) -> void:
	var diff: float = [0.75, 1.0, 1.35][Game.difficulty]
	var origin := Vector3(78, 0, -78)
	var target := Vector3(-54, 0, 54)
	var k := 0
	for id in w["units"]:
		var n := int(ceil(float(w["units"][id]) * diff))
		for i in n:
			var off := Vector3((k % 4) * 5.0 - 7.5, 0, (k / 4) * 6.0)
			var p := world.nav.nearest_walkable_pos(origin + off.rotated(Vector3.UP, deg_to_rad(-45)))
			var u := world.spawn_unit(id, Defs.TEAM_ENEMY, p, deg_to_rad(-135))
			u.order_attack_move(target + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
			wave_units.append(u)
			k += 1
	world.raise_alert(Vector3(20, 0, -20), "ヴァルケシュ軍の第%d波が橋を渡ってくる！" % (waves_sent + 1), Defs.TEAM_PLAYER)
	world.sfx.play_ui("alert", -2.0)
	_warned = false


func _reinforce() -> void:
	phase = 1
	var base := Vector3(-120, 0, 128)
	var list := {"walker": 2, "aetherguard": 3, "airship": 1, "mortar": 1}
	var k := 0
	for id in list:
		for i in int(list[id]):
			var p := world.nav.nearest_walkable_pos(base + Vector3((k % 4) * 7.0, 0, -(k / 4) * 7.0))
			var u := world.spawn_unit(id, Defs.TEAM_PLAYER, p, deg_to_rad(135))
			u.order_move(Vector3(-70, 0, 70) + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)))
			k += 1
	world.player(0).material += 400
	world.player(0).aether += 200
	ai.aggression = 1.0
	focus_point = Vector3(0, 0, 0)
	hud.show_banner("REINFORCEMENTS HAVE ARRIVED", "王冠の援軍が到着。中央ネクサスを奪取し、ヴァルケシュの本拠地を破壊せよ。", 7.0)
	hud.set_advisor("DISCIPLINE\nBUILDS WORLDS.")
	world.sfx.play_ui("objective", 0.0)
	world.raise_alert(base, "援軍が到着した（資材+400 / エーテル+200）", Defs.TEAM_PLAYER)


func _on_died(e: Entity) -> void:
	if e == gate and phase == 0:
		gate_lost = true
		world.raise_alert(e.global_position, "アイアンスパイン門が陥落した！", Defs.TEAM_PLAYER)
	if e is Unit:
		wave_units.erase(e)
	_check_end()


func _on_captured(site: Site, team: int) -> void:
	if site.site_id == "central_nexus" and team == Defs.TEAM_PLAYER and not _nexus_taken:
		_nexus_taken = true
		focus_point = Vector3(150, 0, -150)
		hud.show_banner("THE NEXUS IS OURS", "エーテルの流れは王冠のものだ。", 5.0)
		world.sfx.play_ui("objective", 0.0)


func _check_end() -> void:
	if world.game_over:
		return
	if world.citadel(Defs.TEAM_PLAYER) == null:
		world.end_game(Defs.TEAM_ENEMY)
	elif world.citadel(Defs.TEAM_ENEMY) == null:
		world.end_game(Defs.TEAM_PLAYER)


func _refresh() -> void:
	var t := world.match_time
	if phase == 0:
		var remain := int(maxf(0.0, REINFORCE_AT - t))
		var alive_wave := wave_units.filter(func(u): return is_instance_valid(u) and u.alive).size()
		var repel := "done" if waves_sent == WAVES.size() and alive_wave == 0 else "open"
		hud.set_objectives("Hold the Gate", "For a Stronger Tomorrow.", [
			{"text": "アイアンスパイン門を守る", "state": "failed" if gate_lost else "open"},
			{"text": "ヴァルケシュの攻勢を退ける（%d / %d 波）" % [waves_sent, WAVES.size()], "state": repel},
			{"text": "援軍到着まで持ちこたえる  %d:%02d" % [remain / 60, remain % 60], "state": "open"},
		])
	else:
		var owned := world.sites.filter(func(s): return s.owner_team == Defs.TEAM_PLAYER).size()
		hud.set_objectives("Claim the Aether", "Break the Varkesh Citadel.", [
			{"text": "アイアンスパイン門を守る", "state": "failed" if gate_lost else "done"},
			{"text": "中央ネクサスを占領する", "state": "done" if _nexus_taken else "open"},
			{"text": "都市を4つ支配する（%d / 4）" % owned, "state": "done" if owned >= 4 else "open"},
			{"text": "ヴァルケシュ本拠地を破壊する", "state": "open"},
		])

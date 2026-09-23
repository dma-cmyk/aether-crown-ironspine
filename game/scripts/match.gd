extends Node3D
## Match root: builds the battlefield and wires world, input, HUD, AI and mission together.

var terrain: Terrain
var env_rig: EnvRig
var camera: CameraRig
var world: World
var commander: Commander
var hud: Control
var hud_layer: CanvasLayer
var mission: Mission
var scenario: Scenario
var ai: EnemyAI
var music: AudioStreamPlayer
var ambience: Array[AudioStreamPlayer] = []


func _ready() -> void:
	scenario = _load_scenario()
	env_rig = EnvRig.new()
	env_rig.name = "Environment"
	add_child(env_rig)
	env_rig.build()
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(not Game.args.has("noscatter"))
	camera = CameraRig.new()
	camera.name = "CameraRig"
	add_child(camera)
	camera.setup(terrain)
	var listener := AudioListener3D.new()
	camera.add_child(listener)
	listener.make_current()
	camera.moved.connect(func(): listener.global_position = camera.focus + Vector3(0, 18, 0))
	world = World.new()
	world.name = "World"
	add_child(world)
	world.setup(terrain, camera)
	terrain.register_chimneys(world.fx)
	_spawn_start()
	commander = Commander.new()
	commander.name = "Commander"
	add_child(commander)
	commander.setup(world, camera)
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = HUD.new()
	hud.name = "HUD"
	hud_layer.add_child(hud)
	hud.setup(world, commander, camera, self)
	commander.hud = hud
	ai = EnemyAI.new()
	ai.name = "EnemyAI"
	add_child(ai)
	ai.setup(world, Defs.TEAM_ENEMY)
	mission = Mission.new()
	mission.name = "Mission"
	add_child(mission)
	mission.setup(world, ai, hud, scenario)
	var diff: float = [0.85, 1.0, 1.2][Game.difficulty]
	world.player(Defs.TEAM_ENEMY).income_mult = diff
	world.player(Defs.TEAM_ENEMY).material *= diff
	world.fog.hide_enemy_buildings()
	world.fog.recompute()
	camera.set_view(Vector3(-40, 0, 40), -45.0, 104.0)
	_start_audio()
	if Game.is_capture():
		_setup_capture()
	if Game.args.has("autoplay"):
		var bot: Node = load("res://scripts/dev/autoplayer.gd").new()
		add_child(bot)
		bot.setup(world, commander, mission)
	if Game.args.has("nohud"):
		hud_layer.visible = false
		hud.studio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if Game.args.has("nofogwar"):
		world.fog.enabled = false


func _spawn_start() -> void:
	var L := terrain.layout
	for s in L["sites"]:
		var site := Site.new()
		site.name = "Site_" + s["id"]
		world.add_child(site)
		site.setup(s)
		world.sites.append(site)
	for g in L["gates"]:
		var f: Array = g["facing"]
		world.spawn_building("gate", int(g["team"]), Vector3(g["pos"][0], 0, g["pos"][1]), atan2(f[0], f[1]), true)
	if not scenario.data.get("map_start", true):
		return
	for b in L["start_buildings"]:
		world.spawn_building(b["id"], int(b["team"]), Vector3(b["pos"][0], 0, b["pos"][1]), deg_to_rad(float(b["rot"])), true)
	for u in L["start_units"]:
		world.spawn_unit(u["id"], int(u["team"]), Vector3(u["pos"][0], 0, u["pos"][1]), deg_to_rad(float(u["rot"])))


## The scenario chosen on the title screen (or --mission=<path>); falls back to the campaign.
func _load_scenario() -> Scenario:
	var s := Scenario.load_file(Game.arg("mission", Game.scenario_path))
	if s.is_valid():
		return s
	for e in s.errors:
		push_error("%s: %s" % [s.path, e])
	return Scenario.load_file(Scenario.DEFAULT)


func _start_audio() -> void:
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.stream = _looped("res://assets/audio/music_battle.wav")
	music.volume_db = -6.0
	add_child(music)
	music.play()
	for f in ["amb_wind", "amb_battle"]:
		var a := AudioStreamPlayer.new()
		a.bus = "SFX"
		a.stream = _looped("res://assets/audio/%s.wav" % f)
		a.volume_db = -14.0 if f == "amb_wind" else -20.0
		add_child(a)
		a.play()
		ambience.append(a)


static func _looped(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStreamWAV
	if s:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		var frame_bytes := (2 if s.stereo else 1) * 2
		s.loop_end = s.data.size() / frame_bytes
	return s


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") and commander.mode == Commander.Mode.NONE:
		hud.toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cam_home"):
		var c := world.citadel(Defs.TEAM_PLAYER)
		if c:
			camera.look_at_point(c.global_position)


func _setup_capture() -> void:
	var cap := preload("res://scripts/dev/capture.gd").new()
	add_child(cap)
	camera.input_enabled = false
	var v := Game.arg("cam", "")
	if v != "":
		var p := v.split(",")
		camera.set_view(Vector3(float(p[0]), 0, float(p[1])), float(p[2]), float(p[3]), float(p[4]) if p.size() > 4 else -1.0)
	var scenario := Game.arg("scenario", "")
	if scenario != "":
		DevScenarios.run(scenario, world, commander, camera, self)
	if Game.args.has("select"):
		var sel := []
		for u in world.units:
			if u.team == 0:
				sel.append(u)
		commander.set_selection(sel.slice(0, 6))

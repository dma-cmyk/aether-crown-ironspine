extends Node3D
## Title screen: cinematic flyover of the Ironspine with the main menu.

var terrain: Terrain
var world: World
var cam: Camera3D
var t := 0.0
var ui: Control
var diff_button: Button
var overlay: Control
var music: AudioStreamPlayer


func _ready() -> void:
	var env := EnvRig.new()
	add_child(env)
	env.build()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build(true)
	var rig := CameraRig.new()
	rig.input_enabled = false
	add_child(rig)
	rig.setup(terrain)
	rig.set_process(false)
	cam = rig.cam
	world = World.new()
	add_child(world)
	world.setup(terrain, rig)
	world.fog.enabled = false
	terrain.register_chimneys(world.fx)
	_stage_scene()
	_build_ui()
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.stream = preload("res://scripts/match.gd")._looped("res://assets/audio/music_battle.wav")
	music.volume_db = -4.0
	add_child(music)
	music.play()
	if Game.is_capture():
		var cap := preload("res://scripts/dev/capture.gd").new()
		add_child(cap)
		if Game.arg("show") == "scenarios":
			_show_scenarios()
		elif Game.arg("show") == "saves":
			_show_saves()
		elif Game.arg("show") == "help":
			_show_help()
		elif Game.arg("show") == "settings":
			_show_settings()


func _stage_scene() -> void:
	var L := terrain.layout
	for s in L["sites"]:
		var site := Site.new()
		world.add_child(site)
		site.setup(s)
		site.label.visible = false
		world.sites.append(site)
	for g in L["gates"]:
		var f: Array = g["facing"]
		world.spawn_building("gate", int(g["team"]), Vector3(g["pos"][0], 0, g["pos"][1]), atan2(f[0], f[1]), true)
	for b in L["start_buildings"]:
		if int(b["team"]) == 0:
			world.spawn_building(b["id"], 0, Vector3(b["pos"][0], 0, b["pos"][1]), deg_to_rad(float(b["rot"])), true)
	for i in 6:
		var u := world.spawn_unit("aetherguard", 0, Vector3(-60 + i * 4.0, 0, 64 - i * 3.0), deg_to_rad(135))
		u.order_patrol(Vector3(-36 + i * 2.0, 0, 38))
	var w := world.spawn_unit("walker", 0, Vector3(-70, 0, 60), deg_to_rad(135))
	w.order_patrol(Vector3(-40, 0, 40))
	for k in 3:
		var a := world.spawn_unit("airship", 0, Vector3(-120 + k * 30.0, 0, 20 + k * 25.0), deg_to_rad(90))
		a.order_patrol(Vector3(80 - k * 20.0, 0, -60 + k * 30.0))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.theme = UITheme.theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.025, 0.035, 0.92))
	g.set_color(1, Color(0.02, 0.025, 0.035, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.anchor_bottom = 1.0
	shade.offset_right = 640 if Game.compact else 1100
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	var c := Game.compact
	var crest := TextureRect.new()
	crest.texture = UITheme.icon("crest")
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.position = Vector2(30, 16) if c else Vector2(118, 110)
	crest.size = Vector2(60, 60) if c else Vector2(120, 120)
	ui.add_child(crest)
	var title := UITheme.label("AETHER CROWN", 44 if c else 92, UITheme.IVORY, UITheme.title_font(), 4 if c else 6)
	title.position = Vector2(100, 10) if c else Vector2(112, 236)
	ui.add_child(title)
	var tag := UITheme.label("INDUSTRY.   FAITH.   A HIGHER TOMORROW.", 12 if c else 22, UITheme.GOLD, UITheme.title_font(), 3)
	tag.position = Vector2(104, 70) if c else Vector2(122, 352)
	ui.add_child(tag)
	var jp := UITheme.label("世界を繋ぎ、帝国を築け。", 17 if c else 28, UITheme.IVORY, UITheme.serif_font(), 4)
	jp.position = Vector2(32, 94) if c else Vector2(122, 398)
	ui.add_child(jp)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 5 if c else 8)
	menu.position = Vector2(30, 130) if c else Vector2(120, 448)
	menu.size = Vector2(440, 340) if c else Vector2(520, 400)
	ui.add_child(menu)
	_menu_button(menu, "続きから", _show_saves).disabled = not SaveGame.has_any()
	_menu_button(menu, "キャンペーン ― アイアンスパインの門", _start)
	_menu_button(menu, "シナリオ", _show_scenarios)
	diff_button = _menu_button(menu, "", _cycle_difficulty)
	_update_diff()
	_menu_button(menu, "操作説明", _show_help)
	_menu_button(menu, "設定", _show_settings)
	# a browser tab cannot quit itself; it can go fullscreen instead
	if Game.can_fullscreen():
		_menu_button(menu, "全画面の切り替え", Game.toggle_fullscreen)
	elif not Game.is_web():
		_menu_button(menu, "終了", func(): get_tree().quit())
	var foot := UITheme.label("Hold the Gate — For a Stronger Tomorrow.   Built with Godot, Blender, Material Maker, Inkscape and ImageMagick.", 14, UITheme.TEXT_DIM, UITheme.italic_font(), 2)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 122
	foot.offset_top = -44
	foot.offset_right = 1600
	foot.offset_bottom = -20
	foot.visible = not c
	ui.add_child(foot)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)


func _menu_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 42) if Game.compact else Vector2(520, 50)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", UITheme.body_font())
	b.add_theme_font_size_override("font_size", 18 if Game.compact else 22)
	b.pressed.connect(func():
		world.sfx.play_ui("click")
		cb.call())
	parent.add_child(b)
	return b


func _update_diff() -> void:
	diff_button.text = "難易度：%s" % ["Recruit（やさしい）", "Veteran（ふつう）", "Commander（むずかしい）"][Game.difficulty]


func _cycle_difficulty() -> void:
	Game.difficulty = (Game.difficulty + 1) % 3
	Game.save_settings()
	_update_diff()


func _start() -> void:
	Game.start_match(Scenario.DEFAULT)


func _show_modal(p: Control) -> void:
	for c in overlay.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	overlay.add_child(p)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	p.position = (overlay.size - p.size) * 0.5


func _close_modal() -> void:
	for c in overlay.get_children():
		c.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_help() -> void:
	_show_modal(HelpPanel.make(_close_modal))


func _show_saves() -> void:
	_show_modal(SavePanel.make(false, func(slot: int) -> void: Game.load_game(SaveGame.slot_path(slot)), _close_modal))


func _show_scenarios() -> void:
	_show_modal(ScenarioPanel.make(_close_modal))


func _show_settings() -> void:
	_show_modal(Menus.SettingsPanel.make(_close_modal))


func _process(delta: float) -> void:
	t += delta
	var a := t * 0.035 + 2.2
	var center := Vector3(-20, 0, 20)
	var pos := center + Vector3(cos(a) * 125.0, 58.0 + sin(t * 0.07) * 6.0, sin(a) * 125.0)
	cam.global_position = pos
	cam.look_at(center + Vector3(0, -8, 0), Vector3.UP)
	cam.rotate_object_local(Vector3.RIGHT, 0.12)

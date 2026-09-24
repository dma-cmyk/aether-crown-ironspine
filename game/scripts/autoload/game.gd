extends Node
## Global state: settings, match setup, scene flow and dev capture options.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High"]
const DIFFICULTY_NAMES := ["Recruit", "Veteran", "Commander"]

var quality := 1
var master_volume := 0.8
var music_volume := 0.55
var sfx_volume := 0.85
var edge_scroll := true
var difficulty := 1
var scenario_path := "res://scenarios/hold_the_gate.json"
## Set by load_game(); the next match rebuilds itself from it.
var pending_save := {}
var show_fps := false
## Phones and tablets: the compact HUD sized for fingers (--touch or ?touch=1 forces it, touch=0 turns it off).
var compact := false
## The last input came from a finger: no edge scrolling, hover labels or mouse-following ghosts.
var touch_input := false
var _touch_ms := -100000
var _rotate_hint: CanvasLayer

## Command line: godot --path game -- --capture=overview --out=/tmp/a.png --frames=90
var args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if OS.has_feature("web"):
		_read_url_args()
	var t := arg("touch")
	compact = t != "0" and (t != "" or DisplayServer.is_touchscreen_available())
	touch_input = compact
	if compact:
		get_tree().root.size_changed.connect(_fit_screen)
		_fit_screen()
	_register_inputs()
	load_settings()
	if args.has("quality"):
		quality = clampi(int(args["quality"]), 0, 2)
	if args.has("difficulty"):
		difficulty = clampi(int(args["difficulty"]), 0, 2)
	apply_audio()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_input = true
		_touch_ms = Time.get_ticks_msec()
	elif event is InputEventMouse and not from_touch(event) and (event is InputEventMouseButton or (event as InputEventMouseMotion).relative.length() > 2.0):
		touch_input = false


## Mouse events a finger made: Godot's own (DEVICE_ID_EMULATION) and the ones a browser sends
## along with touches, which look like a real mouse (Chrome moves it while a finger drags).
func from_touch(event: InputEvent) -> bool:
	return event is InputEventMouse and (event.device == InputEvent.DEVICE_ID_EMULATION or Time.get_ticks_msec() - _touch_ms < 800)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.physical_keycode == KEY_F11 or (k.physical_keycode == KEY_ENTER and k.alt_pressed)):
		toggle_fullscreen()


func arg(name: String, default: String = "") -> String:
	return str(args.get(name, default))


func is_capture() -> bool:
	return args.has("capture")


func is_web() -> bool:
	return OS.has_feature("web")


## Web: the page's query string works like command line options (?touch=1&quality=0).
func _read_url_args() -> void:
	var q = JavaScriptBridge.eval("window.location.search", true)
	if typeof(q) != TYPE_STRING:
		return
	for pair in (q as String).trim_prefix("?").split("&", false):
		var kv := pair.split("=", true, 1)
		args[kv[0].uri_decode()] = kv[1].uri_decode() if kv.size() > 1 else "1"


# ---------------------------------------------------------------- phones
## Size the UI in CSS pixels, not device pixels: one unit is at most 1.25 px and the screen
## always holds at least 1000 x 480 units, which the compact HUD is laid out for.
func _fit_screen() -> void:
	var root := get_tree().root
	var css := Vector2(root.size) / maxf(DisplayServer.screen_get_scale(), 0.01)
	var k := minf(1.25, minf(css.x / 1000.0, css.y / 480.0))
	if css.y > css.x:
		k = minf(1.25, minf(css.y / 1000.0, css.x / 480.0))
	root.content_scale_size = Vector2i((css / k).round())
	_show_rotate_hint(css.y > css.x)


func _show_rotate_hint(on: bool) -> void:
	if _rotate_hint == null:
		if not on:
			return
		_rotate_hint = CanvasLayer.new()
		_rotate_hint.layer = 100
		add_child(_rotate_hint)
		var bg := ColorRect.new()
		bg.color = Color(0.03, 0.035, 0.05, 0.96)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rotate_hint.add_child(bg)
		var l := UITheme.label("端末を横向きにしてください", 44, UITheme.IVORY, UITheme.serif_font())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.add_child(l)
	_rotate_hint.visible = on


## Web: the browser allows fullscreen only right after a tap or click, so call this from a button.
## Phones also turn to landscape once the page is fullscreen.
func can_fullscreen() -> bool:
	if not is_web():
		return false
	# JS booleans come back as numbers
	var v = JavaScriptBridge.eval("document.fullscreenEnabled ? 1 : 0", true)
	return v != null and int(v) == 1


func toggle_fullscreen() -> void:
	if is_web():
		JavaScriptBridge.eval("""
			if (document.fullscreenElement) { document.exitFullscreen().catch(() => {}); }
			else { document.documentElement.requestFullscreen({ navigationUI: 'hide' })
				.then(() => screen.orientation && screen.orientation.lock && screen.orientation.lock('landscape'))
				.catch(() => {}); }""", true)
		return
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---------------------------------------------------------------- settings
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	quality = int(cf.get_value("video", "quality", quality))
	show_fps = bool(cf.get_value("video", "show_fps", show_fps))
	master_volume = float(cf.get_value("audio", "master", master_volume))
	music_volume = float(cf.get_value("audio", "music", music_volume))
	sfx_volume = float(cf.get_value("audio", "sfx", sfx_volume))
	edge_scroll = bool(cf.get_value("input", "edge_scroll", edge_scroll))
	difficulty = int(cf.get_value("game", "difficulty", difficulty))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "show_fps", show_fps)
	cf.set_value("audio", "master", master_volume)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("input", "edge_scroll", edge_scroll)
	cf.set_value("game", "difficulty", difficulty)
	cf.save(SETTINGS_PATH)
	apply_audio()
	settings_changed.emit()


func apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


# ---------------------------------------------------------------- scenes
func goto_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func load_game(path: String) -> bool:
	var d := SaveGame.read(path)
	if d.is_empty():
		return false
	pending_save = d
	difficulty = int(d["difficulty"])
	start_match(str(d["scenario"]))
	return true


func start_match(path: String = "") -> void:
	if path != "":
		scenario_path = path
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/match.tscn")


# ---------------------------------------------------------------- input
func _register_inputs() -> void:
	var keys := {
		"cam_left": [KEY_LEFT], "cam_right": [KEY_RIGHT], "cam_up": [KEY_UP], "cam_down": [KEY_DOWN],
		"cam_rot_left": [KEY_COMMA], "cam_rot_right": [KEY_PERIOD],
		"cam_home": [KEY_HOME, KEY_BACKSPACE],
		"pause_menu": [KEY_ESCAPE, KEY_F10],
		"select_army": [KEY_F2], "select_idle": [KEY_F1],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in keys[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)

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
var show_fps := false

## Command line: godot --path game -- --capture=overview --out=/tmp/a.png --frames=90
var args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_register_inputs()
	load_settings()
	if args.has("quality"):
		quality = clampi(int(args["quality"]), 0, 2)
	if args.has("difficulty"):
		difficulty = clampi(int(args["difficulty"]), 0, 2)
	apply_audio()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.physical_keycode == KEY_F11 or (k.physical_keycode == KEY_ENTER and k.alt_pressed)):
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func arg(name: String, default: String = "") -> String:
	return str(args.get(name, default))


func is_capture() -> bool:
	return args.has("capture")


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


func start_match() -> void:
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

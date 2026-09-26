class_name Sfx
extends Node3D
## Pooled positional sound effects with per-sound rate limiting.

const SOUNDS := {
	"rifle": ["rifle_1", "rifle_2", "rifle_3"],
	"gatling": ["gatling_1", "gatling_2"],
	"cannon": ["cannon_1", "cannon_2"],
	"mortar": ["mortar_1"],
	"beam": ["beam_1", "beam_2"],
	"explosion": ["explosion_1", "explosion_2"],
	"explosion_small": ["explosion_small_1", "explosion_small_2"],
	"explosion_big": ["explosion_big_1"],
	"death_small": ["thud_1"],
	"capture": ["capture"],
	"build_done": ["build_done"],
	"unit_ready": ["unit_ready"],
	"special": ["special"],
	"click": ["ui_click"],
	"confirm": ["ui_confirm"],
	"error": ["ui_error"],
	"alert": ["ui_alert"],
	"objective": ["objective"],
	"smash": ["smash_1", "smash_2"],
	"bite": ["bite_1", "bite_2"],
	"flame": ["flame_1"],
	"thud_big": ["thud_big_1"],
	"roar": ["roar_1"],
	"roar_death": ["roar_death_1"],
	"screech": ["screech_1"],
	"howl": ["howl_1"],
	"robot_step": ["robot_step_1", "robot_step_2", "robot_step_3"],
	"robot_step_heavy": ["robot_step_heavy_1", "robot_step_heavy_2"],
	"glide_wing": ["glide_wing_1", "glide_wing_2"],
	"glide_machine": ["glide_machine_1", "glide_machine_2"],
}
const LIMIT := {"rifle": 5, "gatling": 3, "explosion_small": 4, "explosion": 4, "cannon": 4, "beam": 3, "bite": 3, "flame": 3, "smash": 3,
	"robot_step": 4, "robot_step_heavy": 2, "glide_wing": 2, "glide_machine": 2}
const VOICE_SETS := {
	"aetherguard": {
		"select": ["guard_select_1", "guard_select_2"],
		"move": ["guard_move_1", "guard_move_2"],
		"attack": ["guard_attack_1", "guard_attack_2"],
	},
	"walker": {
		"select": ["walker_select_1", "walker_select_2"],
		"move": ["walker_move_1", "walker_move_2"],
		"attack": ["walker_attack_1", "walker_attack_2"],
	},
}

var streams := {}
var pool: Array[AudioStreamPlayer3D] = []
var ui_players: Array[AudioStreamPlayer] = []
var voice_streams := {}
var voice_player: AudioStreamPlayer
var _last_voice_ms := -100000
var _last_voice_kind := ""
var _next := 0
var _recent := {}


func _ready() -> void:
	for key in SOUNDS:
		var list: Array[AudioStream] = []
		for f in SOUNDS[key]:
			var path := "res://assets/audio/%s.wav" % f
			if ResourceLoader.exists(path):
				list.append(load(path))
		streams[key] = list
	for i in 28:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Master" if Game.is_web() else "SFX"
		p.unit_size = 16.0
		p.max_distance = 260.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.8
		add_child(p)
		pool.append(p)
	for i in 4:
		var u := AudioStreamPlayer.new()
		u.bus = "Master" if Game.is_web() else "SFX"
		add_child(u)
		ui_players.append(u)
	for unit_id in VOICE_SETS:
		var actions := {}
		for kind in VOICE_SETS[unit_id]:
			var lines: Array[AudioStream] = []
			for name in VOICE_SETS[unit_id][kind]:
				var path := "res://assets/audio/voices/%s.wav" % name
				if ResourceLoader.exists(path):
					lines.append(load(path))
			actions[kind] = lines
		voice_streams[unit_id] = actions
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Master" if Game.is_web() else "SFX"
	add_child(voice_player)


func _allowed(key: String) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	var arr: Array = _recent.get(key, [])
	while arr.size() > 0 and now - float(arr[0]) > 0.16:
		arr.pop_front()
	if arr.size() >= int(LIMIT.get(key, 3)):
		_recent[key] = arr
		return false
	arr.append(now)
	_recent[key] = arr
	return true


func play_at(key: String, pos: Vector3, volume_db: float = 0.0) -> void:
	var list: Array = streams.get(key, [])
	if list.is_empty() or not _allowed(key):
		return
	var p := pool[_next]
	_next = (_next + 1) % pool.size()
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db + (linear_to_db(maxf(Game.sfx_volume, 0.0001)) if Game.is_web() else 0.0)
	p.pitch_scale = randf_range(0.92, 1.08)
	p.global_position = pos
	p.play()


func play_ui(key: String, volume_db: float = -4.0) -> void:
	var list: Array = streams.get(key, [])
	if list.is_empty():
		return
	for u in ui_players:
		if not u.playing:
			u.stream = list[randi() % list.size()]
			u.volume_db = volume_db + (linear_to_db(maxf(Game.sfx_volume, 0.0001)) if Game.is_web() else 0.0)
			u.play()
			return


func has_voice(unit_id: String) -> bool:
	return voice_streams.has(unit_id)


## Command acknowledgements sit in their own channel so UI clicks and combat cannot cut them off.
func play_voice(unit_id: String, kind: String) -> void:
	var actions: Dictionary = voice_streams.get(unit_id, {})
	var lines: Array = actions.get(kind, [])
	if lines.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_voice_ms < (900 if _last_voice_kind == kind else 170):
		return
	if kind == "select" and voice_player.playing:
		return
	_last_voice_ms = now
	_last_voice_kind = kind
	voice_player.stop()
	voice_player.stream = lines[randi() % lines.size()]
	voice_player.volume_db = -4.0 + (linear_to_db(maxf(Game.sfx_volume, 0.0001)) if Game.is_web() else 0.0)
	voice_player.play()

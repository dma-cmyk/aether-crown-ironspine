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

var streams := {}
var pool: Array[AudioStreamPlayer3D] = []
var ui_players: Array[AudioStreamPlayer] = []
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

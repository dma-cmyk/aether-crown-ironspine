class_name PortraitStudio
extends SubViewport
## Small isolated 3D scene that renders the selected unit/building for the HUD portrait.

var cam: Camera3D
var pivot: Node3D
var current_key := ""
var spin := true


func _init() -> void:
	size = Vector2i(256, 256)
	own_world_3d = true
	transparent_bg = false
	msaa_3d = Viewport.MSAA_DISABLED
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.065, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.6)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 1.4
	key.light_color = Color(1.0, 0.92, 0.8)
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 150, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.5, 0.75, 1.0)
	add_child(rim)
	pivot = Node3D.new()
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 30
	add_child(cam)


func show_entity(kind: String, id: String, team: int) -> void:
	var key := "%s|%s|%d" % [kind, id, team]
	if key == current_key:
		return
	current_key = key
	for c in pivot.get_children():
		c.queue_free()
	var model_name: String
	var height := 2.0
	var dist := 4.0
	var look_y := 1.0
	if kind == "unit":
		var d: Dictionary = Defs.UNITS[id]
		model_name = d["model"]
		match d["type"]:
			"squad":
				height = 2.0
				dist = 3.3
				look_y = 1.55
			"walker":
				height = 10.0
				dist = 16.0
				look_y = 7.0
			"vehicle":
				height = 3.4
				dist = 9.5
				look_y = 1.8
			"air":
				height = 8.0
				dist = 30.0
				look_y = -1.0
	else:
		model_name = Defs.BUILDINGS[id]["model"]
		dist = 58.0 if id == "citadel" else (46.0 if id == "gate" else 34.0)
		look_y = 12.0 if id == "citadel" else 8.0
	var inst := UnitVisual.load_model(model_name, team, false)
	pivot.add_child(inst)
	if model_name in ["aetherguard", "artificer"]:
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = MatLib.infantry_material(team)
	pivot.rotation.y = deg_to_rad(-25)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	cam.position = Vector3(0, look_y + dist * 0.18, dist)
	cam.look_at(Vector3(0, look_y, 0))


var _redraw_t := 0.0


func _process(delta: float) -> void:
	if spin and pivot:
		pivot.rotation.y += delta * 0.35
		_redraw_t -= delta
		if _redraw_t <= 0.0:
			_redraw_t = 0.08
			render_target_update_mode = SubViewport.UPDATE_ONCE

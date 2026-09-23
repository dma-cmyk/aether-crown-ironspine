class_name Site
extends Node3D
## Capturable city with an aether relay. Owners gain income and population.

const CAPTURE_TIME := 14.0

var site_id := ""
var site_name := ""
var kind := "industry"
var owner_team := -1
var capture := 0.0
var capturing_team := -1
var contested := false
var income_material := 0.0
var income_aether := 0.0
var pop_bonus := 0
var radius := 22.0
var vision := 34.0
var model: Node3D
var ring: MeshInstance3D
var label: Label3D
var _t := 0.0
var _last_owner := -2


func setup(d: Dictionary) -> void:
	site_id = d["id"]
	site_name = d["name"]
	kind = d["kind"]
	owner_team = int(d["owner"])
	capture = 1.0 if owner_team >= 0 else 0.0
	income_material = float(d["material"])
	income_aether = float(d["aether"])
	pop_bonus = int(d["pop"])
	radius = float(d["radius"])
	var p: Array = d["pos"]
	global_position = Vector3(p[0], World.inst.terrain.ground_at(p[0], p[1]), p[1])
	ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(1, 1)
	ring.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ring.gdshader")
	ring.material_override = m
	ring.scale = Vector3(radius * 2.0, 1, radius * 2.0)
	ring.position.y = 0.35
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.set_instance_shader_parameter("ring_width", 0.025)
	ring.set_instance_shader_parameter("ring_pulse", 1.0)
	label = Label3D.new()
	label.text = site_name.to_upper()
	label.font = UITheme.title_font()
	label.font_size = 40
	label.pixel_size = 0.0005
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position = Vector3(0, 19.0, 0)
	label.modulate = Color(0.95, 0.9, 0.78)
	label.fixed_size = true
	add_child(label)
	_refresh_owner()


func tick(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	var step := 0.25 - _t
	_t = 0.25
	var power := [0.0, 0.0]
	for e: Entity in World.inst.query(global_position, radius):
		if e is Unit and e.alive and not e.is_air and e.team >= 0 and e.team <= 1:
			power[e.team] += (e as Unit).capture_power * (0.5 + 0.5 * e.hp_ratio())
	contested = power[0] > 0.0 and power[1] > 0.0
	if contested:
		return
	var t := -1
	if power[0] > 0.0:
		t = 0
	elif power[1] > 0.0:
		t = 1
	if t < 0:
		return
	var rate := step / CAPTURE_TIME * minf(power[t], 3.0)
	if owner_team == t:
		capture = minf(1.0, capture + rate)
		capturing_team = -1
	elif owner_team == -1:
		if capturing_team != t:
			capturing_team = t
			capture = 0.0
		capture += rate
		if capture >= 1.0:
			capture = 1.0
			_set_owner(t)
	else:
		capture -= rate * 1.2
		capturing_team = t
		if capture <= 0.0:
			capture = 0.0
			var old := owner_team
			_set_owner(-1)
			capturing_team = t
			if old == Defs.TEAM_PLAYER:
				World.inst.raise_alert(global_position, "%s の支配を失った" % site_name, Defs.TEAM_PLAYER)


func _set_owner(t: int) -> void:
	owner_team = t
	if t >= 0:
		capturing_team = -1
		var p := World.inst.player(t)
		p.stats["captured"] += 1
		World.inst.site_captured.emit(self, t)
		World.inst.fx.ring_burst(global_position + Vector3(0, 1, 0), radius, Defs.team_glow(t))
		World.inst.sfx.play_at("capture", global_position)
		if t == Defs.TEAM_PLAYER:
			World.inst.raise_alert(global_position, "%s を占領した" % site_name, t)
		else:
			World.inst.raise_alert(global_position, "敵が %s を占領した" % site_name, Defs.TEAM_PLAYER)
	_refresh_owner()


func _refresh_owner() -> void:
	if _last_owner == owner_team:
		return
	_last_owner = owner_team
	if model:
		model.queue_free()
	model = UnitVisual.load_model("relay", owner_team, true)
	add_child(model)
	var c := Defs.team_color(owner_team) if owner_team >= 0 else Color(0.85, 0.82, 0.7)
	ring.set_instance_shader_parameter("ring_color", Color(c.r, c.g, c.b, 0.55))


func _process(_delta: float) -> void:
	if ring == null:
		return
	var show_fill := capture if (capturing_team >= 0 or owner_team >= 0) else 0.0
	ring.set_instance_shader_parameter("ring_fill", show_fill)
	if capturing_team >= 0 and owner_team < 0:
		var c := Defs.team_color(capturing_team)
		ring.set_instance_shader_parameter("ring_color", Color(c.r, c.g, c.b, 0.45 + 0.3 * sin(Time.get_ticks_msec() * 0.008)))
	elif owner_team >= 0 and capturing_team >= 0:
		var c2 := Defs.team_color(owner_team)
		ring.set_instance_shader_parameter("ring_color", Color(c2.r, c2.g, c2.b, 0.35 + 0.35 * sin(Time.get_ticks_msec() * 0.012)))
	else:
		var c3 := Defs.team_color(owner_team) if owner_team >= 0 else Color(0.85, 0.82, 0.7)
		ring.set_instance_shader_parameter("ring_color", Color(c3.r, c3.g, c3.b, 0.55))



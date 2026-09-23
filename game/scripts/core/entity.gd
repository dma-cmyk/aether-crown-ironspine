class_name Entity
extends Node3D
## Anything that can be selected, damaged and destroyed (units and buildings).

signal died(e: Entity)
signal damaged(e: Entity, amount: float)

var def_id := ""
var def: Dictionary = {}
var team := 0
var hp := 100.0
var max_hp := 100.0
var armor := "light"
var radius := 2.0
var height := 2.0
var vision := 30.0
var alive := true
var selected := false
var is_air := false
var is_building := false
var is_mechanical := false
var last_damage_time := -100.0
var last_attacker: Entity
var seen_by_player := true
var kills := 0

var _ring: MeshInstance3D
var _bar: MeshInstance3D

static var _ring_mesh: QuadMesh
static var _bar_mesh: QuadMesh
static var _ring_mat: ShaderMaterial
static var _bar_mat: ShaderMaterial


func take_damage(amount: float, wclass: String, attacker: Entity) -> void:
	if not alive or amount <= 0.0:
		return
	var dmg := amount * Defs.damage_mult(wclass, armor) * damage_taken_mult()
	if dmg <= 0.0:
		return
	hp -= dmg
	last_damage_time = World.inst.match_time if World.inst else 0.0
	if attacker != null and is_instance_valid(attacker) and attacker.team != team:
		last_attacker = attacker
	damaged.emit(self, dmg)
	if hp <= 0.0:
		hp = 0.0
		if attacker != null and is_instance_valid(attacker):
			attacker.kills += 1
		die()


func heal(amount: float) -> void:
	if alive:
		hp = minf(max_hp, hp + amount)


func damage_taken_mult() -> float:
	return 1.0


func die() -> void:
	if not alive:
		return
	alive = false
	set_selected(false)
	died.emit(self)
	if World.inst:
		World.inst.on_entity_died(self)


func hp_ratio() -> float:
	return clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)


func display_name() -> String:
	return def_id


func description() -> String:
	return ""


func aim_point() -> Vector3:
	return global_position + Vector3(0, height * 0.5, 0)


func flat_distance_to(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()


func is_enemy_of(t: int) -> bool:
	return team != t and team != Defs.TEAM_NEUTRAL


# ---------------------------------------------------------------- selection visuals
func set_selected(v: bool) -> void:
	selected = v
	if v:
		if _ring == null:
			_ring = MeshInstance3D.new()
			_ring.mesh = _shared_ring()
			_ring.material_override = _ring_mat
			_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var s := radius * 2.6
			_ring.scale = Vector3(s, 1, s)
			_ring.position = Vector3(0, 0.25, 0)
			add_child(_ring)
			var c := Color(0.45, 1.0, 0.55) if team == Defs.TEAM_PLAYER else Defs.team_color(team)
			_ring.set_instance_shader_parameter("ring_color", c)
		_ring.visible = true
	elif _ring:
		_ring.visible = false
	_update_bar_visibility()


func _update_bar_visibility() -> void:
	var want := alive and (selected or hp < max_hp * 0.999)
	if want and _bar == null:
		_bar = MeshInstance3D.new()
		_bar.mesh = _shared_bar()
		_bar.material_override = _bar_mat
		_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var w := clampf(radius * 0.9, 1.6, 8.0)
		_bar.scale = Vector3(w, w, w)
		_bar.position = Vector3(0, height + 1.2, 0)
		add_child(_bar)
	if _bar:
		_bar.visible = want and seen_by_player
		if _bar.visible:
			_bar.set_instance_shader_parameter("fill", hp_ratio())
			var c := Color(0.35, 0.95, 0.45) if team == Defs.TEAM_PLAYER else Defs.team_color(team)
			if hp_ratio() < 0.35 and team == Defs.TEAM_PLAYER:
				c = Color(1.0, 0.45, 0.2)
			_bar.set_instance_shader_parameter("bar_color", c)


static func _shared_ring() -> QuadMesh:
	if _ring_mesh == null:
		_ring_mesh = QuadMesh.new()
		_ring_mesh.size = Vector2(1, 1)
		_ring_mesh.orientation = PlaneMesh.FACE_Y
		_ring_mat = ShaderMaterial.new()
		_ring_mat.shader = load("res://shaders/ring.gdshader")
	return _ring_mesh


static func _shared_bar() -> QuadMesh:
	if _bar_mesh == null:
		_bar_mesh = QuadMesh.new()
		_bar_mesh.size = Vector2(1.0, 0.13)
		_bar_mat = ShaderMaterial.new()
		_bar_mat.shader = load("res://shaders/hpbar.gdshader")
	return _bar_mesh

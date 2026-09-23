class_name UnitVisual
extends Node3D
## Base class for unit presentation (models, animation, muzzle points).

var unit: Unit


func setup(u: Unit) -> void:
	unit = u


func on_mode_changed() -> void:
	pass


func on_death() -> void:
	pass


func on_fire(_w: Dictionary, _target: Entity) -> void:
	pass


## World-space points projectiles/tracers start from.
func muzzle_points(_w: Dictionary, _target: Entity) -> Array[Vector3]:
	return [unit.aim_point()]


static func load_model(model: String, team: int, world_space: bool = false) -> Node3D:
	var path := "res://assets/models/%s.glb" % model
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	MatLib.remap(inst, team, world_space)
	return inst


static func find_node3d(root: Node, n: String) -> Node3D:
	return root.find_child(n, true, false) as Node3D

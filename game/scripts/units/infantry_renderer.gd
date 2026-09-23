class_name InfantryRenderer
extends MultiMeshInstance3D
## One MultiMesh per infantry model and team; slots are kept packed for cheap drawing.

var mm: MultiMesh
var owners: Array = []
var count := 0


func setup(model: String, team: int) -> void:
	var inst := (load("res://assets/models/%s.glb" % model) as PackedScene).instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mi.mesh
	mm.instance_count = 128
	mm.visible_instance_count = 0
	inst.free()
	multimesh = mm
	material_override = MatLib.infantry_material(team)
	custom_aabb = AABB(Vector3(-220, -60, -220), Vector3(440, 160, 440))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func alloc(member: Dictionary) -> void:
	if count >= mm.instance_count:
		var keep := count
		mm.instance_count = mm.instance_count * 2
		mm.visible_instance_count = keep
	member["slot"] = count
	owners.resize(maxi(owners.size(), count + 1))
	owners[count] = member
	count += 1
	mm.visible_instance_count = count


func release(member: Dictionary) -> void:
	var slot: int = member.get("slot", -1)
	if slot < 0 or slot >= count:
		return
	var last := count - 1
	if slot != last:
		var moved: Dictionary = owners[last]
		owners[slot] = moved
		moved["slot"] = slot
		mm.set_instance_transform(slot, mm.get_instance_transform(last))
		mm.set_instance_custom_data(slot, mm.get_instance_custom_data(last))
	owners[last] = null
	member["slot"] = -1
	count -= 1
	mm.visible_instance_count = count


func write(member: Dictionary, xf: Transform3D, custom: Color) -> void:
	var slot: int = member.get("slot", -1)
	if slot >= 0 and slot < count:
		mm.set_instance_transform(slot, xf)
		mm.set_instance_custom_data(slot, custom)

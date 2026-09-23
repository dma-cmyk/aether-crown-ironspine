extends Node3D
## Dev: lays out models for inspection and captures a screenshot.
## godot --path game -- --gallery=house_a,house_b --team=0 --out=/tmp/g.png [--spacing=18] [--yaw=-35] [--model_y=3]

var capture: Node


func _ready() -> void:
	var env := EnvRig.new()
	add_child(env)
	env.build()
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = MatLib.tex("terrain_grass_albedo")
	gm.albedo_color = Color(0.62, 0.68, 0.5)
	gm.uv1_scale = Vector3(80, 80, 80)
	ground.material_override = gm
	add_child(ground)

	var names: PackedStringArray
	var g := Game.arg("gallery", "all")
	if g == "all":
		for f in DirAccess.get_files_at("res://assets/models"):
			if f.ends_with(".glb"):
				names.append(f.get_basename())
	else:
		names = g.split(",")
	var team := int(Game.arg("team", "0"))
	var spacing := float(Game.arg("spacing", "16"))
	var cols := int(ceil(sqrt(names.size() * 1.6)))
	var rows := int(ceil(float(names.size()) / cols))
	for i in names.size():
		var path := "res://assets/models/%s.glb" % names[i]
		if not ResourceLoader.exists(path):
			push_warning("missing model " + path)
			continue
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		MatLib.remap(inst, team, true)
		var c := i % cols
		var r := i / cols
		inst.position = Vector3((c - (cols - 1) * 0.5) * spacing, float(Game.arg("model_y", "0")), (r - (rows - 1) * 0.5) * spacing)
		inst.rotation.y = deg_to_rad(float(Game.arg("model_yaw", "0")))
		add_child(inst)
		var lab := Label3D.new()
		lab.text = names[i]
		lab.font_size = 96
		lab.pixel_size = 0.02
		lab.position = inst.position + Vector3(0, 0.3, spacing * 0.42)
		lab.rotation_degrees = Vector3(-60, 0, 0)
		lab.modulate = Color(1, 1, 1)
		lab.outline_size = 12
		add_child(lab)
	var cam := Camera3D.new()
	add_child(cam)
	var extent := maxf(cols, rows) * spacing
	var yaw := deg_to_rad(float(Game.arg("yaw", "-30")))
	var pitch := deg_to_rad(float(Game.arg("pitch", "35")))
	var dist := float(Game.arg("dist", str(extent * 1.1 + 10.0)))
	var focus := Vector3(0, float(Game.arg("focus_y", "3")), 0)
	cam.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.fov = 40
	cam.look_at(focus)
	cam.make_current()
	capture = preload("res://scripts/dev/capture.gd").new()
	add_child(capture)

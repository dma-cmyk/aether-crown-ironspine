class_name SquadVisual
extends UnitVisual
## Infantry squad: members follow formation slots and are drawn through InfantryRenderer.

const SCALE := 1.45

var members: Array[Dictionary] = []
var renderer: InfantryRenderer
var barricade: MeshInstance3D


func setup(u: Unit) -> void:
	super.setup(u)
	renderer = World.inst.infantry_renderer(u.def["model"], u.team)
	var n: int = u.def["members"]
	var cols := 4 if n > 4 else 2
	var spacing := 1.7
	for i in n:
		var row := i / cols
		var col := i % cols
		var off := Vector3((col - (cols - 1) * 0.5) * spacing + (0.35 if row % 2 else 0.0), 0, -row * spacing * 1.1 + 0.8)
		off += Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
		var m := {"off": off, "pos": u.global_position + off, "yaw": u.facing, "phase": randf(), "alive": true,
				"death": 0.0, "recoil": 0.0, "walk": 0.0, "slot": -1}
		renderer.alloc(m)
		members.append(m)


## Save/load: a squad restored below full strength starts without its fallen members.
func drop_fallen() -> void:
	for i in range(members.size() - 1, unit.members_alive() - 1, -1):
		renderer.release(members[i])
		members.remove_at(i)


func _exit_tree() -> void:
	for m in members:
		renderer.release(m)


func on_mode_changed() -> void:
	var want := unit.fortified or unit.deployed
	if want and barricade == null:
		barricade = MeshInstance3D.new()
		barricade.mesh = _barricade_mesh()
		barricade.material_override = MatLib.get_mat("canvas", unit.team)
		add_child(barricade)
		barricade.position = Vector3(0, 0, 2.6)
	if barricade:
		barricade.visible = want


func on_death() -> void:
	if barricade:
		barricade.visible = false


func muzzle_points(_w: Dictionary, _target: Entity) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m in members:
		if m["alive"]:
			var yaw: float = m["yaw"]
			var fwd := Vector3(sin(yaw), 0, cos(yaw))
			out.append((m["pos"] as Vector3) + Vector3(0, 1.62 * SCALE, 0) + fwd * 1.25 * SCALE)
	return out


func on_fire(_w: Dictionary, _target: Entity) -> void:
	for m in members:
		if m["alive"]:
			m["recoil"] = 1.0


func _process(delta: float) -> void:
	if unit == null:
		return
	delta = minf(delta, 0.05)
	var xf := unit.get_global_transform_interpolated()
	var origin := xf.origin
	var yaw := unit.facing
	var basis := Basis(Vector3.UP, yaw)
	var alive_n := unit.members_alive()
	var visible_now := unit.seen_by_player or unit.team == Defs.TEAM_PLAYER
	var crouch := unit.fortified or unit.deployed
	var terrain := World.inst.terrain
	var nav := World.inst.nav
	var aim_yaw := yaw
	if unit.target and is_instance_valid(unit.target) and unit.firing_timer > 0.0:
		var to := unit.target.global_position - origin
		aim_yaw = atan2(to.x, to.z)
	var idx := 0
	for m in members:
		if m["alive"] and idx >= alive_n:
			m["alive"] = false
			m["death"] = 0.001
		idx += 1
		var pos: Vector3 = m["pos"]
		var walk := 0.0
		if m["alive"]:
			var off: Vector3 = m["off"]
			if crouch:
				off = off * 0.8
			var tgt := origin + basis * off
			if not nav.walkable_at(tgt):
				tgt = origin.lerp(tgt, 0.25)
			tgt.y = terrain.ground_at(tgt.x, tgt.z)
			var before := pos
			var k := 1.0 - exp(-5.5 * delta)
			pos = pos.lerp(tgt, k)
			var step := Vector2(pos.x - before.x, pos.z - before.z).length()
			pos.y = terrain.ground_at(pos.x, pos.z)
			var spd := step / maxf(delta, 0.001)
			walk = clampf(spd / 3.0, 0.0, 1.0)
			m["walk"] = lerpf(m["walk"], walk, 1.0 - exp(-10.0 * delta))
			m["phase"] = fmod(float(m["phase"]) + step * 0.34, 1.0)
			var face := aim_yaw if unit.firing_timer > 0.0 else yaw
			if spd > 1.0:
				var mv := pos - before
				face = atan2(mv.x, mv.z) if unit.firing_timer <= 0.0 else aim_yaw
			m["yaw"] = rotate_toward(float(m["yaw"]), face, 8.0 * delta)
			m["recoil"] = maxf(0.0, float(m["recoil"]) - delta * 6.0)
		else:
			m["death"] = minf(1.0, float(m["death"]) + delta / 1.6)
		m["pos"] = pos
		var s := SCALE * (0.86 if crouch and m["alive"] else 1.0)
		var b := Basis(Vector3.UP, float(m["yaw"])).scaled(Vector3(SCALE, s, SCALE))
		var xf_m := Transform3D(b, pos)
		if not visible_now:
			xf_m = Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), pos)
		renderer.write(m, xf_m, Color(float(m["phase"]), float(m["walk"]), float(m["recoil"]), float(m["death"])))


static var _bar_mesh_cache: Mesh


static func _barricade_mesh() -> Mesh:
	if _bar_mesh_cache:
		return _bar_mesh_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bag := BoxMesh.new()
	bag.size = Vector3(1.1, 0.45, 0.6)
	for i in 9:
		var a := -0.9 + i * 0.225
		var r := 6.0
		var p := Vector3(sin(a) * r, 0.22 + (0.42 if i % 2 == 0 else 0.0), cos(a) * r - r)
		for layer in 2:
			var xf := Transform3D(Basis(Vector3.UP, a), p + Vector3(0, layer * 0.42 - (0.42 if i % 2 == 0 else 0.0), 0))
			st.append_from(bag, 0, xf)
	st.generate_normals()
	_bar_mesh_cache = st.commit()
	return _bar_mesh_cache

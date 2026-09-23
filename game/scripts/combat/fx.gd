class_name FX
extends Node3D
## Lightweight effects: CPU-simulated billboard particles drawn through MultiMesh
## (one draw call per layer), tracers/beams, debris, scorch decals and light flashes.


class Layer:
	var mmi: MultiMeshInstance3D
	var mm: MultiMesh
	var cap := 0
	var n := 0
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var age := PackedFloat32Array()
	var life := PackedFloat32Array()
	var s0 := PackedFloat32Array()
	var s1 := PackedFloat32Array()
	var rot := PackedFloat32Array()
	var rotv := PackedFloat32Array()
	var col := PackedColorArray()
	var buf := PackedFloat32Array()
	var drag := 0.8
	var gravity := 0.0

	func _init(parent: Node3D, capacity: int, shader: Shader, tex: Texture2D, mesh: Mesh = null) -> void:
		cap = capacity
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		if mesh == null:
			var q := QuadMesh.new()
			q.size = Vector2(1, 1)
			mesh = q
		mm.mesh = mesh
		mm.instance_count = cap
		mm.visible_instance_count = 0
		mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 400, 800))
		if shader:
			var m := ShaderMaterial.new()
			m.shader = shader
			if tex:
				m.set_shader_parameter("tex", tex)
			mmi.material_override = m
		parent.add_child(mmi)
		for arr in [pos, vel]:
			arr.resize(cap)
		for arr in [age, life, s0, s1, rot, rotv]:
			arr.resize(cap)
		col.resize(cap)
		buf.resize(cap * 20)

	func emit(p: Vector3, v: Vector3, lifetime: float, size_a: float, size_b: float, c: Color, spin: float = 0.0) -> void:
		if n >= cap:
			return
		pos[n] = p
		vel[n] = v
		age[n] = 0.0
		life[n] = lifetime
		s0[n] = size_a
		s1[n] = size_b
		rot[n] = randf() * TAU
		rotv[n] = spin
		col[n] = c
		n += 1

	func update(dt: float) -> void:
		var i := 0
		var damp := 1.0 - clampf(drag * dt, 0.0, 1.0)
		while i < n:
			age[i] += dt
			if age[i] >= life[i]:
				n -= 1
				if i < n:
					pos[i] = pos[n]
					vel[i] = vel[n]
					age[i] = age[n]
					life[i] = life[n]
					s0[i] = s0[n]
					s1[i] = s1[n]
					rot[i] = rot[n]
					rotv[i] = rotv[n]
					col[i] = col[n]
				continue
			var v := vel[i] * damp
			v.y += gravity * dt
			vel[i] = v
			pos[i] += v * dt
			rot[i] += rotv[i] * dt
			i += 1
		for j in n:
			var t := age[j] / life[j]
			var s := lerpf(s0[j], s1[j], sqrt(t))
			var b := j * 20
			var p := pos[j]
			buf[b] = s
			buf[b + 1] = 0.0
			buf[b + 2] = 0.0
			buf[b + 3] = p.x
			buf[b + 4] = 0.0
			buf[b + 5] = s
			buf[b + 6] = 0.0
			buf[b + 7] = p.y
			buf[b + 8] = 0.0
			buf[b + 9] = 0.0
			buf[b + 10] = s
			buf[b + 11] = p.z
			var c := col[j]
			buf[b + 12] = c.r
			buf[b + 13] = c.g
			buf[b + 14] = c.b
			buf[b + 15] = c.a
			buf[b + 16] = t
			buf[b + 17] = rot[j]
			buf[b + 18] = 0.0
			buf[b + 19] = 0.0
		mm.buffer = buf
		mm.visible_instance_count = n


var smoke_l: Layer
var fire_l: Layer
var glow: Layer
var dust_l: Layer
var beams: Layer
var debris_l: Layer
var _tracers: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _emitters: Array[Dictionary] = []
var _amb: Layer
var _amb_buf := PackedFloat32Array()
var _amb_n := 0
var _amb_blocks := {}
var _amb_free: Array[Vector2i] = []
var _amb_dirty := false
var _pending: Array[Dictionary] = []
var _lights: Array[OmniLight3D] = []
var _light_t := PackedFloat32Array()
var _light_e := PackedFloat32Array()
var _decals: Array[Decal] = []
var _decal_i := 0
var _rings: Array[Dictionary] = []
var quality := 1


func _ready() -> void:
	var mix := load("res://shaders/fx_particle.gdshader") as Shader
	var add := load("res://shaders/fx_particle_add.gdshader") as Shader
	smoke_l = Layer.new(self, 900, mix, load("res://assets/fx/fx_smoke.png"))
	smoke_l.drag = 0.9
	dust_l = Layer.new(self, 300, mix, load("res://assets/fx/fx_smoke.png"))
	dust_l.drag = 2.2
	fire_l = Layer.new(self, 500, add, load("res://assets/fx/fx_fire.png"))
	fire_l.drag = 1.6
	glow = Layer.new(self, 900, add, load("res://assets/fx/fx_glow.png"))
	glow.drag = 0.4
	glow.gravity = -2.0
	beams = Layer.new(self, 600, load("res://shaders/fx_beam.gdshader"), null)
	_amb = Layer.new(self, 1, load("res://shaders/fx_ambient.gdshader"), load("res://assets/fx/fx_smoke.png"))
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.3, 0.55)
	debris_l = Layer.new(self, 240, null, null, box)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.16, 0.15, 0.15)
	dm.roughness = 0.9
	dm.vertex_color_use_as_albedo = true
	debris_l.mmi.material_override = dm
	debris_l.mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for i in 6:
		var l := OmniLight3D.new()
		l.omni_range = 18.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)
	_light_t.resize(6)
	_light_e.resize(6)
	var scorch := load("res://assets/fx/fx_scorch.png") as Texture2D
	for i in 48:
		var d := Decal.new()
		d.texture_albedo = scorch
		d.size = Vector3(4, 6, 4)
		d.visible = false
		d.cull_mask = 1
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		add_child(d)
		_decals.append(d)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	var i := 0
	while i < _pending.size():
		_pending[i]["t"] -= delta
		if _pending[i]["t"] <= 0.0:
			var p: Dictionary = _pending[i]
			_pending.remove_at(i)
			explosion(p["pos"], p["size"])
			continue
		i += 1
	i = 0
	while i < _emitters.size():
		var e := _emitters[i]
		e["t"] -= delta
		if e["t"] <= 0.0:
			_emitters.remove_at(i)
			continue
		e["acc"] += delta * e["rate"]
		while e["acc"] >= 1.0:
			e["acc"] -= 1.0
			var r: float = e["r"]
			if e.has("fire"):
				var fc: Color = e["fire"]
				var q: Vector3 = e["pos"] + Vector3(randf_range(-r, r), 0.2, randf_range(-r, r))
				fire_l.emit(q, Vector3(randf_range(-0.3, 0.3), randf_range(2.0, 3.5), randf_range(-0.3, 0.3)), randf_range(0.5, 0.9),
						0.8, 1.8, Color(fc.r, fc.g, fc.b, 0.6), randf_range(-1, 1))
				if randf() < 0.25:
					smoke_l.emit(q + Vector3(0, 1.5, 0), Vector3(0, 2.0, 0), randf_range(2.0, 3.0), 1.0, 3.0, Color(0.12, 0.11, 0.1, 0.45), randf_range(-0.3, 0.3))
				continue
			var p2: Vector3 = e["pos"] + Vector3(randf_range(-r, r), randf() * 2.0, randf_range(-r, r)) * 0.6
			smoke_l.emit(p2, Vector3(randf_range(-0.5, 0.5), randf_range(2.5, 4.5), randf_range(-0.5, 0.5)), randf_range(4.0, 7.0),
					r * 0.35, r * 1.2, Color(0.16, 0.15, 0.14, 0.55), randf_range(-0.3, 0.3))
			if randf() < 0.3:
				fire_l.emit(p2, Vector3(0, 2.0, 0), 0.8, 1.2, 2.6, Color(1.0, 0.45, 0.12, 0.9))
		i += 1
	_upload_ambient()
	_update_tracers(delta)
	_update_debris(delta)
	_update_rings(delta)
	smoke_l.update(delta)
	dust_l.update(delta)
	fire_l.update(delta)
	glow.update(delta)
	for k in _lights.size():
		if _light_t[k] > 0.0:
			_light_t[k] -= delta
			var f := maxf(_light_t[k] / 0.18, 0.0)
			_lights[k].light_energy = _light_e[k] * f * f
			if _light_t[k] <= 0.0:
				_lights[k].visible = false


# ---------------------------------------------------------------- effects
func explosion(p: Vector3, size: float = 1.5, delay: float = 0.0) -> void:
	if delay > 0.0:
		_pending.append({"t": delay, "pos": p, "size": size})
		return
	glow.emit(p, Vector3.ZERO, 0.22, size * 3.0, size * 5.5, Color(1.0, 0.8, 0.5, 1.0))
	for i in int(6 + size * 3):
		var v := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)) * size * 3.5
		fire_l.emit(p + v * 0.1, v, randf_range(0.35, 0.7), size * 1.2, size * 2.6, Color(1.0, randf_range(0.35, 0.6), 0.12, 1.0), randf_range(-2, 2))
	for i in int(4 + size * 3):
		var v2 := Vector3(randf_range(-1, 1), randf_range(0.6, 1.6), randf_range(-1, 1)) * size * 1.6
		smoke_l.emit(p + v2 * 0.2, v2, randf_range(2.5, 4.5), size * 1.2, size * 4.2, Color(0.13, 0.12, 0.115, 0.7), randf_range(-0.4, 0.4))
	sparks(p, int(6 + size * 4))
	light_flash(p + Vector3(0, 1.5, 0), Color(1.0, 0.62, 0.3), 4.0 + size * 3.0)
	var cam := World.inst.camera if World.inst else null
	if cam and size >= 1.8:
		var d := cam.focus.distance_to(p)
		if d < 70.0:
			cam.shake(size * 0.15 * (1.0 - d / 70.0))


func smoke_puff(p: Vector3, size: float, alpha: float, dark: float = 0.2) -> void:
	smoke_l.emit(p, Vector3(randf_range(-0.4, 0.4), randf_range(0.8, 1.6), randf_range(-0.4, 0.4)), randf_range(2.0, 3.5),
			size * 0.5, size * 1.6, Color(dark, dark * 0.96, dark * 0.92, alpha), randf_range(-0.4, 0.4))


func smoke(p: Vector3, size: float = 1.5, alpha: float = 0.35) -> void:
	smoke_puff(p, size, alpha, 0.34)


func fire(p: Vector3, size: float = 1.2) -> void:
	fire_l.emit(p, Vector3(randf_range(-0.3, 0.3), randf_range(1.5, 2.8), randf_range(-0.3, 0.3)), randf_range(0.5, 0.9),
			size * 0.8, size * 1.6, Color(1.0, randf_range(0.4, 0.6), 0.15, 0.95), randf_range(-1, 1))


func flash(p: Vector3, c: Color, size: float = 1.5) -> void:
	glow.emit(p, Vector3.ZERO, 0.14, size, size * 1.6, Color(c.r, c.g, c.b, 1.0))


func glow_dot(p: Vector3, c: Color, size: float = 0.6) -> void:
	glow.emit(p, Vector3.ZERO, 0.06, size, size, c)


func muzzle(p: Vector3, c: Color, size: float = 0.6) -> void:
	glow.emit(p, Vector3.ZERO, 0.07, size * 1.4, size * 2.2, Color(c.r, c.g, c.b, 1.0))
	if size > 1.0:
		fire_l.emit(p, Vector3.ZERO, 0.12, size * 0.8, size * 1.6, Color(1.0, 0.6, 0.25, 1.0))


func sparks(p: Vector3, n: int = 8, c: Color = Color(1.0, 0.7, 0.35)) -> void:
	for i in n:
		var v := Vector3(randf_range(-1, 1), randf_range(0.3, 1.5), randf_range(-1, 1)).normalized() * randf_range(5.0, 12.0)
		glow.emit(p, v, randf_range(0.25, 0.55), 0.35, 0.12, Color(c.r, c.g, c.b, 1.0))


func sparkle(p: Vector3, c: Color) -> void:
	for i in 10:
		var v := Vector3(randf_range(-1, 1), randf_range(1.0, 3.0), randf_range(-1, 1))
		glow.emit(p + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), v, randf_range(0.6, 1.2), 0.5, 0.2, Color(c.r, c.g, c.b, 1.0))


func dust(p: Vector3, size: float = 1.5) -> void:
	dust_l.emit(p, Vector3(randf_range(-1, 1), randf_range(0.4, 1.2), randf_range(-1, 1)), randf_range(1.2, 2.2),
			size * 0.6, size * 1.8, Color(0.42, 0.37, 0.3, 0.35), randf_range(-0.5, 0.5))


func impact_dust(p: Vector3, size: float = 0.6) -> void:
	dust_l.emit(p, Vector3(0, 1.0, 0), 0.6, size * 0.5, size * 1.5, Color(0.45, 0.4, 0.33, 0.4))


# ---------------------------------------------------------------- ambient smoke
## Chimney smoke and waterfall spray loop forever at fixed spots. Each source owns a block of
## instances animated entirely by fx_ambient.gdshader, so they cost no CPU per frame.
## Returns a handle for remove_ambient().
func add_ambient(p: Vector3, count: int, vel: Vector3, jitter: Vector3, spread: Vector3, life: Vector2, size: Vector2, c: Color) -> int:
	if Game.quality == 0:
		count = ceili(count * 0.6)
	var start := -1
	for i in _amb_free.size():
		var blk := _amb_free[i]
		if blk.y >= count:
			start = blk.x
			if blk.y > count:
				_amb_free[i] = Vector2i(blk.x + count, blk.y - count)
			else:
				_amb_free.remove_at(i)
			break
	if start < 0:
		start = _amb_n
		_amb_n += count
		if _amb_n * 20 > _amb_buf.size():
			_amb_buf.resize(maxi(_amb_n, _amb_buf.size() / 20 * 2) * 20)
	for k in count:
		var b := (start + k) * 20
		# rows of the 3x4 transform: the basis columns carry velocity, jitter and spread
		_amb_buf[b] = vel.x
		_amb_buf[b + 1] = jitter.x
		_amb_buf[b + 2] = spread.x
		_amb_buf[b + 3] = p.x
		_amb_buf[b + 4] = vel.y
		_amb_buf[b + 5] = jitter.y
		_amb_buf[b + 6] = spread.y
		_amb_buf[b + 7] = p.y
		_amb_buf[b + 8] = vel.z
		_amb_buf[b + 9] = jitter.z
		_amb_buf[b + 10] = spread.z
		_amb_buf[b + 11] = p.z
		_amb_buf[b + 12] = c.r
		_amb_buf[b + 13] = c.g
		_amb_buf[b + 14] = c.b
		_amb_buf[b + 15] = c.a
		_amb_buf[b + 16] = (k + randf() * 0.6) / count
		_amb_buf[b + 17] = randf_range(life.x, life.y)
		_amb_buf[b + 18] = size.x
		_amb_buf[b + 19] = size.y
	_amb_blocks[start] = count
	_amb_dirty = true
	return start


func remove_ambient(handle: int) -> void:
	if not _amb_blocks.has(handle):
		return
	var count: int = _amb_blocks[handle]
	_amb_blocks.erase(handle)
	for k in count:
		_amb_buf[(handle + k) * 20 + 18] = 0.0
		_amb_buf[(handle + k) * 20 + 19] = 0.0
	_amb_free.append(Vector2i(handle, count))
	_amb_dirty = true


## Waterfall spray: wide, pale, slow puffs at the base of a fall.
func add_mist(p: Vector3, r: float) -> int:
	var s := 3.0 + r * 0.2
	return add_ambient(p, roundi((0.8 + r * 0.12) * 4.5), Vector3(0, 0.9, 0), Vector3(0.4, 0.4, 0.4), Vector3(r * 0.8, 0.8, 0.3),
			Vector2(3.5, 5.5), Vector2(s * 0.5, s * 1.6), Color(0.92, 0.95, 1.0, 0.16))


## Chimney smoke drifting downwind; `rate` is puffs per second.
func add_chimney(p: Vector3, rate: float = 2.5, size: float = 2.2, dark: float = 0.3) -> int:
	return add_ambient(p, roundi(rate * 6.25), Vector3(1.0, 2.8, 0), Vector3(0.4, 0.6, 0.3), Vector3(0.4, 0, 1.0),
			Vector2(5.0, 7.5), Vector2(size * 0.6, size * 3.2), Color(dark, dark * 0.97, dark * 0.95, 0.42))


func _upload_ambient() -> void:
	if not _amb_dirty:
		return
	_amb_dirty = false
	if _amb.mm.instance_count * 20 != _amb_buf.size():
		_amb.mm.instance_count = _amb_buf.size() / 20
	_amb.mm.buffer = _amb_buf
	_amb.mm.visible_instance_count = _amb_n


func smoke_column(p: Vector3, r: float) -> void:
	_emitters.append({"pos": p, "r": r, "t": 9.0, "rate": 7.0, "acc": 0.0})


## Burning ground left by dragon fire.
func burn(p: Vector3, r: float, seconds: float, c: Color) -> void:
	_emitters.append({"pos": p, "r": r, "t": seconds, "rate": 14.0, "acc": 0.0, "fire": c})


func ring_burst(p: Vector3, radius: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ring.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = p
	_rings.append({"mi": mi, "t": 0.0, "r": radius, "c": c})


func light_flash(p: Vector3, c: Color, energy: float) -> void:
	if Game.quality == 0:
		return
	var best := 0
	for k in _lights.size():
		if _light_t[k] <= 0.0:
			best = k
			break
		if _light_t[k] < _light_t[best]:
			best = k
	var l := _lights[best]
	l.global_position = p
	l.light_color = c
	l.omni_range = 10.0 + energy * 2.0
	l.visible = true
	_light_t[best] = 0.18
	_light_e[best] = energy


func crater(p: Vector3, size: float) -> void:
	var d := _decals[_decal_i]
	_decal_i = (_decal_i + 1) % _decals.size()
	d.global_position = p
	d.size = Vector3(size * 2.4, 5.0, size * 2.4)
	d.rotation.y = randf() * TAU
	d.modulate = Color(1, 1, 1, 0.85)
	d.visible = true


func tracer(a: Vector3, b: Vector3, c: Color, width: float = 0.08, delay: float = 0.0) -> void:
	_tracers.append({"a": a, "b": b, "c": c, "w": width, "t": -delay, "speed": 240.0, "beam": false, "life": 0.0})


func beam(a: Vector3, b: Vector3, c: Color, life: float = 0.3) -> void:
	_tracers.append({"a": a, "b": b, "c": c, "w": 0.55, "t": 0.0, "speed": 0.0, "beam": true, "life": life})
	var d := a.distance_to(b)
	for i in int(d / 3.0):
		glow.emit(a.lerp(b, randf()), Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)), 0.35, 0.6, 0.2, Color(c.r, c.g, c.b, 1.0))


func debris(p: Vector3, n: int = 8, small: bool = false) -> void:
	for i in n:
		var v := Vector3(randf_range(-1, 1), randf_range(0.8, 2.0), randf_range(-1, 1)) * (6.0 if small else 9.0)
		_debris.append({"p": p + Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)), "v": v, "r": Vector3(randf(), randf(), randf()) * TAU,
				"rv": Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)), "t": 0.0, "life": randf_range(2.0, 3.5),
				"s": randf_range(0.5, 1.0) * (0.6 if small else 1.3)})
		if _debris.size() > 220:
			_debris.remove_at(0)


func _update_tracers(dt: float) -> void:
	var n := 0
	var buf := beams.buf
	var i := 0
	while i < _tracers.size():
		var tr := _tracers[i]
		tr["t"] += dt
		var t: float = tr["t"]
		if t < 0.0:
			i += 1
			continue
		var a: Vector3 = tr["a"]
		var b: Vector3 = tr["b"]
		var head: Vector3
		var tail: Vector3
		var alpha := 1.0
		if tr["beam"]:
			if t > tr["life"]:
				_tracers.remove_at(i)
				continue
			head = b
			tail = a
			alpha = 1.0 - t / tr["life"]
		else:
			var d := a.distance_to(b)
			var travel: float = t * tr["speed"]
			if travel - 5.0 > d:
				_tracers.remove_at(i)
				continue
			head = a.lerp(b, minf(travel / d, 1.0))
			tail = a.lerp(b, clampf((travel - 5.0) / d, 0.0, 1.0))
		if n < beams.cap:
			var seg := head - tail
			var bb := n * 20
			var c: Color = tr["c"]
			buf[bb] = seg.x
			buf[bb + 1] = 0.0
			buf[bb + 2] = 0.001
			buf[bb + 3] = tail.x
			buf[bb + 4] = seg.y
			buf[bb + 5] = 0.001
			buf[bb + 6] = 0.0
			buf[bb + 7] = tail.y
			buf[bb + 8] = seg.z
			buf[bb + 9] = 0.0
			buf[bb + 10] = 0.0
			buf[bb + 11] = tail.z
			buf[bb + 12] = c.r
			buf[bb + 13] = c.g
			buf[bb + 14] = c.b
			buf[bb + 15] = alpha
			buf[bb + 16] = 0.0
			buf[bb + 17] = tr["w"]
			buf[bb + 18] = 1.0 if tr["beam"] else 0.0
			buf[bb + 19] = 0.0
			n += 1
		i += 1
	beams.mm.buffer = buf
	beams.mm.visible_instance_count = n


func _update_debris(dt: float) -> void:
	var buf := debris_l.buf
	var n := 0
	var terrain := World.inst.terrain if World.inst else null
	var i := 0
	while i < _debris.size():
		var d := _debris[i]
		d["t"] += dt
		if d["t"] > d["life"]:
			_debris.remove_at(i)
			continue
		var v: Vector3 = d["v"]
		v.y -= 22.0 * dt
		var p: Vector3 = d["p"] + v * dt
		var g := terrain.ground_at(p.x, p.z) if terrain else 0.0
		if p.y < g + 0.15:
			p.y = g + 0.15
			v = Vector3(v.x * 0.4, absf(v.y) * 0.25, v.z * 0.4)
			d["rv"] = (d["rv"] as Vector3) * 0.5
		d["v"] = v
		d["p"] = p
		d["r"] = (d["r"] as Vector3) + (d["rv"] as Vector3) * dt
		var sink := clampf((d["t"] - (d["life"] - 0.6)) / 0.6, 0.0, 1.0)
		var s: float = d["s"] * (1.0 - sink)
		var basis := Basis.from_euler(d["r"]).scaled(Vector3(s, s, s))
		var bb := n * 20
		buf[bb] = basis.x.x
		buf[bb + 1] = basis.y.x
		buf[bb + 2] = basis.z.x
		buf[bb + 3] = p.x
		buf[bb + 4] = basis.x.y
		buf[bb + 5] = basis.y.y
		buf[bb + 6] = basis.z.y
		buf[bb + 7] = p.y
		buf[bb + 8] = basis.x.z
		buf[bb + 9] = basis.y.z
		buf[bb + 10] = basis.z.z
		buf[bb + 11] = p.z
		for k in 8:
			buf[bb + 12 + k] = 1.0
		n += 1
		if n >= debris_l.cap:
			break
		i += 1
	debris_l.mm.buffer = buf
	debris_l.mm.visible_instance_count = n


func _update_rings(dt: float) -> void:
	var i := 0
	while i < _rings.size():
		var r := _rings[i]
		r["t"] += dt
		var k: float = r["t"] / 0.9
		var mi: MeshInstance3D = r["mi"]
		if k >= 1.0:
			mi.queue_free()
			_rings.remove_at(i)
			continue
		var s: float = r["r"] * 2.0 * (0.2 + 0.8 * sqrt(k))
		mi.scale = Vector3(s, 1, s)
		var c: Color = r["c"]
		mi.set_instance_shader_parameter("ring_color", Color(c.r, c.g, c.b, 1.0 - k))
		mi.set_instance_shader_parameter("ring_width", 0.08)
		i += 1

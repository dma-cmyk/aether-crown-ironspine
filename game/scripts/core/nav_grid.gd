class_name NavGrid
extends RefCounted
## Ground pathfinding on the baked walkability grid (AStarGrid2D + string pulling).

var astar := AStarGrid2D.new()
var n := 200
var cell := 2.0
var half := 200.0
var base_walk := PackedByteArray()
var blockers := PackedInt32Array()
## Cover per cell from the map (trees, props, rocks) and from standing walls: 0 = none, otherwise the
## height in 0.25 m steps (low 7 bits) plus bit 7 for heavy cover.
var cover := PackedByteArray()
var cover_walls := {}
## Absolute height of the tallest standing building per cell, for flyers to clear.
var roofs := {}


func load_from(path: String, size: float, cell_size: float) -> void:
	base_walk = FileAccess.get_file_as_bytes(path)
	cell = cell_size
	half = size * 0.5
	n = int(round(size / cell_size))
	blockers.resize(n * n)
	astar.region = Rect2i(0, 0, n, n)
	astar.cell_size = Vector2(cell, cell)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.jumping_enabled = true
	astar.update()
	for iz in n:
		for ix in n:
			if base_walk[iz * n + ix] == 0:
				astar.set_point_solid(Vector2i(ix, iz), true)
	var cover_path := path.get_base_dir().path_join("cover.bin")
	cover = FileAccess.get_file_as_bytes(cover_path) if FileAccess.file_exists(cover_path) else PackedByteArray()
	if cover.size() != n * n:
		cover = PackedByteArray()
		cover.resize(n * n)


## Cover code at a point (see `cover`), the stronger of the map's and any standing wall's.
func cover_at(p: Vector3) -> int:
	var c := to_cell(p)
	var i := c.y * n + c.x
	return maxi(cover[i], int(cover_walls.get(i, 0)))


## Top of whatever stands at p (map props from `cover`, buildings from `roofs`); `ground` if nothing.
func top_at(p: Vector3, ground: float) -> float:
	var c := to_cell(p)
	var i := c.y * n + c.x
	return maxf(ground + (maxi(cover[i], int(cover_walls.get(i, 0))) & 127) * 0.25, roofs.get(i, -INF))


## Raise (or clear) building tops over a circle or a rotated rectangle.
func set_roof_circle(center: Vector3, r: float, top: float, on: bool) -> void:
	for i in _circle_cells(center, r):
		_roof(i, top, on)


func set_roof_rect(center: Vector3, half_x: float, half_z: float, yaw: float, top: float, on: bool) -> void:
	for i in _rect_cells(center, half_x, half_z, yaw):
		_roof(i, top, on)


func _roof(i: int, top: float, on: bool) -> void:
	if on:
		roofs[i] = maxf(top, roofs.get(i, -INF))
	else:
		roofs.erase(i)


## Add (or remove) a standing wall's cover over a rotated rectangle.
func set_cover_rect(center: Vector3, half_x: float, half_z: float, yaw: float, code: int, on: bool) -> void:
	for i in _rect_cells(center, half_x, half_z, yaw):
		if on:
			cover_walls[i] = code
		else:
			cover_walls.erase(i)


## Block (or release) a rotated rectangle; counts overlaps like set_blocked_circle.
func set_blocked_rect(center: Vector3, half_x: float, half_z: float, yaw: float, on: bool) -> void:
	for i in _rect_cells(center, half_x, half_z, yaw):
		_block(Vector2i(i % n, i / n), on)


## Indices of the cells whose centres fall inside a rotated rectangle.
func _rect_cells(center: Vector3, half_x: float, half_z: float, yaw: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r := sqrt(half_x * half_x + half_z * half_z)
	var c0 := to_cell(center - Vector3(r, 0, r))
	var c1 := to_cell(center + Vector3(r, 0, r))
	var b := Basis(Vector3.UP, yaw).inverse()
	for iz in range(c0.y, c1.y + 1):
		for ix in range(c0.x, c1.x + 1):
			var l := b * (to_world(Vector2i(ix, iz)) - Vector3(center.x, 0, center.z))
			if absf(l.x) <= half_x and absf(l.z) <= half_z:
				out.append(iz * n + ix)
	return out


## Indices of the cells whose centres fall inside a circle.
func _circle_cells(center: Vector3, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c := to_cell(center)
	var rc := int(ceil(r / cell))
	for dz in range(-rc, rc + 1):
		for dx in range(-rc, rc + 1):
			var q := c + Vector2i(dx, dz)
			if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
				continue
			var w := to_world(q)
			if Vector2(w.x - center.x, w.z - center.z).length() <= r:
				out.append(q.y * n + q.x)
	return out


func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int((p.x + half) / cell), 0, n - 1), clampi(int((p.z + half) / cell), 0, n - 1))


func to_world(c: Vector2i) -> Vector3:
	return Vector3(-half + (c.x + 0.5) * cell, 0.0, -half + (c.y + 0.5) * cell)


func walkable(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < n and c.y < n and not astar.is_point_solid(c)


func walkable_at(p: Vector3) -> bool:
	return walkable(to_cell(p))


func statically_walkable(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < n and c.y < n and base_walk[c.y * n + c.x] != 0


func nearest_walkable(c: Vector2i, max_r: int = 40) -> Vector2i:
	if walkable(c):
		return c
	for r in range(1, max_r):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-r, r + 1):
			for dz in [-r, r]:
				var q := c + Vector2i(dx, dz)
				if walkable(q):
					var d := float(dx * dx + dz * dz)
					if d < best_d:
						best_d = d
						best = q
		for dz in range(-r + 1, r):
			for dx in [-r, r]:
				var q := c + Vector2i(dx, dz)
				if walkable(q):
					var d := float(dx * dx + dz * dz)
					if d < best_d:
						best_d = d
						best = q
		if best.x >= 0:
			return best
	return c


func nearest_walkable_pos(p: Vector3) -> Vector3:
	var c := to_cell(p)
	if walkable(c):
		return p
	return to_world(nearest_walkable(c))


## Returns world-space waypoints (y = 0; callers add ground height).
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := nearest_walkable(to_cell(from))
	var goal_cell := to_cell(to)
	var b := nearest_walkable(goal_cell)
	if a == b:
		out.append(to if b == goal_cell else to_world(b))
		return out
	var ids := astar.get_id_path(a, b, true)
	if ids.is_empty():
		return out
	var pts: Array[Vector2i] = []
	var i := 0
	pts.append(ids[0])
	while i < ids.size() - 1:
		var j := mini(ids.size() - 1, i + 1)
		var k := j
		while k < ids.size() and k - i < 40:
			if line_walkable(ids[i], ids[k]):
				j = k
				k += 1
			else:
				break
		pts.append(ids[j])
		i = j
	for q in range(1, pts.size()):
		out.append(to_world(pts[q]))
	if ids[ids.size() - 1] == goal_cell and out.size() > 0:
		out[out.size() - 1] = Vector3(to.x, 0, to.z)
	return out


func line_walkable(a: Vector2i, b: Vector2i) -> bool:
	var dx := absi(b.x - a.x)
	var dz := absi(b.y - a.y)
	var sx := 1 if b.x > a.x else -1
	var sz := 1 if b.y > a.y else -1
	var x := a.x
	var z := a.y
	var err := dx - dz
	var steps := dx + dz
	for s in steps + 1:
		if not walkable(Vector2i(x, z)):
			return false
		var e2 := err * 2
		if e2 > -dz and e2 < dx:
			# diagonal step: require both orthogonal neighbours (no corner cutting)
			if not walkable(Vector2i(x + sx, z)) or not walkable(Vector2i(x, z + sz)):
				return false
		if x == b.x and z == b.y:
			break
		if e2 > -dz:
			err -= dz
			x += sx
		if e2 < dx:
			err += dx
			z += sz
	return true


func set_blocked_circle(center: Vector3, r: float, blocked: bool) -> void:
	for i in _circle_cells(center, r):
		_block(Vector2i(i % n, i / n), blocked)


func _block(q: Vector2i, on: bool) -> void:
	if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
		return
	var idx := q.y * n + q.x
	blockers[idx] = maxi(0, blockers[idx] + (1 if on else -1))
	astar.set_point_solid(q, base_walk[idx] == 0 or blockers[idx] > 0)


func area_free(center: Vector3, r: float) -> bool:
	var c := to_cell(center)
	var rc := int(ceil(r / cell))
	for dz in range(-rc, rc + 1):
		for dx in range(-rc, rc + 1):
			var q := c + Vector2i(dx, dz)
			var w := to_world(q)
			if Vector2(w.x - center.x, w.z - center.z).length() > r:
				continue
			if not walkable(q):
				return false
	return true

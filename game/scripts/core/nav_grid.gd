class_name NavGrid
extends RefCounted
## Ground pathfinding on the baked walkability grid (AStarGrid2D + string pulling).

var astar := AStarGrid2D.new()
var n := 200
var cell := 2.0
var half := 200.0
var base_walk := PackedByteArray()
var blockers := PackedInt32Array()


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
	var c := to_cell(center)
	var rc := int(ceil(r / cell))
	for dz in range(-rc, rc + 1):
		for dx in range(-rc, rc + 1):
			var q := c + Vector2i(dx, dz)
			if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
				continue
			var w := to_world(q)
			if Vector2(w.x - center.x, w.z - center.z).length() > r:
				continue
			var idx := q.y * n + q.x
			blockers[idx] = maxi(0, blockers[idx] + (1 if blocked else -1))
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

class_name Forest
extends RefCounted
## The map's trees as ground that can be cleared. The terrain build bakes every tree into the nav
## grid as an obstacle (light cover); here each tree remembers the cells it blocks, so a building
## may be placed over trees and they are felled when its construction starts. A cell opens up
## once its last tree is gone, unless something heavier (a rock, a house, a wall) also stands there.

const BUCKET := 16.0

var world: World
var nav: NavGrid
var pos: Array[Vector3] = []
var reach := PackedFloat32Array()
var alive := PackedByteArray()
var cells: Array[PackedInt32Array] = []
## Trees standing on each nav cell.
var count := PackedByteArray()
var _buckets := {}


func setup(w: World) -> void:
	world = w
	nav = w.nav
	count.resize(nav.n * nav.n)
	var list: Array = w.terrain.placements["trees"]
	for i in list.size():
		var t: Array = list[i]
		var p := Vector3(t[0], t[1], t[2])
		# the same circle the terrain build blocked: the lowest ring of branches
		var r := minf(3.0, 2.5 * float(t[3]))
		pos.append(p)
		reach.append(r)
		alive.append(1)
		var cs := nav._circle_cells(p, r)
		cells.append(cs)
		for c in cs:
			count[c] = mini(255, count[c] + 1)
		var key := Vector2i(floori(p.x / BUCKET), floori(p.z / BUCKET))
		var bucket: PackedInt32Array = _buckets.get(key, PackedInt32Array())
		bucket.append(i)  # packed arrays are values: store the grown copy back
		_buckets[key] = bucket


## True when felling trees frees nav cell `i`: only trees stand on it, or it is open ground the
## terrain build shut because the trees fenced it off from the bases.
func clearable(i: int) -> bool:
	if nav.blockers[i] > 0 or (nav.cover[i] & 128) != 0 or not _ground_ok(i):
		return false
	if count[i] > 0:
		return true
	return nav.base_walk[i] == 0 and nav.cover[i] == 0 and not trees_in(_centre(i), 4.0).is_empty()


## Ground the terrain build would call walkable: under 30 degrees, above the water, on the map.
func _ground_ok(i: int) -> bool:
	var w := _centre(i)
	var t := world.terrain
	return t.normal_at(w.x, w.z).y > 0.866 and t.height_at(w.x, w.z) > -3.0 and t.in_bounds(w.x, w.z, 12.0)


func _centre(i: int) -> Vector3:
	return nav.to_world(Vector2i(i % nav.n, i / nav.n))


func _open(i: int) -> void:
	nav.base_walk[i] = 1
	nav.cover[i] = 0
	nav.astar.set_point_solid(Vector2i(i % nav.n, i / nav.n), nav.blockers[i] > 0)


## Like NavGrid.area_free, but ground under trees counts as free.
func area_buildable(center: Vector3, r: float) -> bool:
	for i in nav._circle_cells(center, r):
		if not nav.walkable(Vector2i(i % nav.n, i / nav.n)) and not clearable(i):
			return false
	return true


## Standing trees whose branches reach into the circle.
func trees_in(center: Vector3, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var reach_max := r + 3.0
	var k0 := Vector2i(floori((center.x - reach_max) / BUCKET), floori((center.z - reach_max) / BUCKET))
	var k1 := Vector2i(floori((center.x + reach_max) / BUCKET), floori((center.z + reach_max) / BUCKET))
	for kx in range(k0.x, k1.x + 1):
		for kz in range(k0.y, k1.y + 1):
			for i in _buckets.get(Vector2i(kx, kz), PackedInt32Array()):
				if alive[i] and Vector2(pos[i].x - center.x, pos[i].z - center.z).length() < r + reach[i]:
					out.append(i)
	return out


## Fell every tree reaching into the circle (a new building's footprint). Returns how many fell.
func clear_area(center: Vector3, r: float) -> int:
	var felled := trees_in(center, r)
	for i in felled:
		fell(i, center)
	if felled.size() > 0 and world.fog.is_visible_at(center):
		world.sfx.play_at("thud_big", center, -10.0)
	return felled.size()


## Fell tree `i`, away from `from` (INF: no animation, as when a save is loaded).
func fell(i: int, from: Vector3 = Vector3.INF) -> void:
	if not alive[i]:
		return
	alive[i] = 0
	var opened: Array[int] = []
	for c in cells[i]:
		count[c] -= 1
		# ground too steep or wet to walk stays closed, as the terrain build had it
		if count[c] == 0 and (nav.cover[c] & 128) == 0 and nav.base_walk[c] == 0 and _ground_ok(c):
			_open(c)
			opened.append(c)
	# and the pockets of open ground the tree had fenced off
	var budget := 800
	while not opened.is_empty() and budget > 0:
		var c: int = opened.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := Vector2i(c % nav.n, c / nav.n) + d
			if q.x < 0 or q.y < 0 or q.x >= nav.n or q.y >= nav.n:
				continue
			var k := q.y * nav.n + q.x
			if nav.base_walk[k] == 0 and count[k] == 0 and nav.cover[k] == 0 and _ground_ok(k):
				_open(k)
				opened.append(k)
				budget -= 1
	var away := Vector3.ZERO
	if from != Vector3.INF:
		away = Vector3(pos[i].x - from.x, 0, pos[i].z - from.z)
		if away.length() < 0.5:
			away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	world.terrain.fell_tree(i, away.normalized(), from != Vector3.INF)
	if from != Vector3.INF and world.fog.is_visible_at(pos[i]):
		world.fx.dust(pos[i] + away.normalized() * 4.0, 2.0)


func felled() -> Array:
	var out := []
	for i in alive.size():
		if not alive[i]:
			out.append(i)
	return out

class_name PlayerState
extends RefCounted
## Economy and statistics for one team.

const POP_LIMIT := 160

var team := 0
var material := 450.0
var aether := 160.0
var pop_used := 0
var pop_cap := 20
var income_material := 0.0
var income_aether := 0.0
var income_mult := 1.0
var stats := {"built": 0, "lost": 0, "kills": 0, "buildings_lost": 0, "captured": 0}


func _init(t: int) -> void:
	team = t


func can_afford(cost: Dictionary) -> bool:
	return material >= float(cost.get("material", 0)) and aether >= float(cost.get("aether", 0))


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	material -= float(cost.get("material", 0))
	aether -= float(cost.get("aether", 0))
	return true


func refund(cost: Dictionary, ratio: float = 1.0) -> void:
	material += float(cost.get("material", 0)) * ratio
	aether += float(cost.get("aether", 0)) * ratio


func pop_free() -> int:
	return pop_cap - pop_used


func tick(dt: float) -> void:
	material += income_material * income_mult / 60.0 * dt
	aether += income_aether * income_mult / 60.0 * dt


func recompute(world: World) -> void:
	var im := 0.0
	var ia := 0.0
	var cap := 0
	var used := 0
	for b in world.buildings:
		if b.team != team or not b.alive or not b.built:
			continue
		var inc: Dictionary = b.def.get("income", {})
		im += float(inc.get("material", 0))
		ia += float(inc.get("aether", 0))
		cap += int(b.def.get("pop", 0))
	for s in world.sites:
		if s.owner_team == team:
			im += s.income_material
			ia += s.income_aether
			cap += s.pop_bonus
	for u in world.units:
		if u.team == team and u.alive:
			used += int(u.def.get("pop", 0))
	for b in world.buildings:
		if b.team == team and b.alive:
			used += b.queued_pop()
	income_material = im
	income_aether = ia
	pop_cap = mini(cap, POP_LIMIT)
	pop_used = used

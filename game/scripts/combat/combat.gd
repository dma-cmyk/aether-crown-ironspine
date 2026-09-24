class_name Combat
extends RefCounted
## Weapon discharge: damage, projectiles and firing effects.

const TRACER_COLORS := {
	"rifle": Color(1.0, 0.82, 0.45), "pistol": Color(1.0, 0.8, 0.5), "gatling": Color(1.0, 0.75, 0.35),
	"flak": Color(1.0, 0.9, 0.6),
}
## Share of direct shots (bullets, flat shells, beams) that cover stops: none, light (trees),
## heavy (houses, walls, rocks). Arcing shells, bombs, blows and fire ignore cover.
const COVER_BLOCK := [0.0, 0.25, 0.5]


static func fire(shooter: Entity, w: Dictionary, target: Entity) -> void:
	var world := World.inst
	var muzzles: Array[Vector3]
	if shooter is Unit:
		muzzles = (shooter as Unit).visual.muzzle_points(w, target)
		(shooter as Unit).visual.on_fire(w, target)
	else:
		muzzles = (shooter as Building).muzzle_points(w, target)
	if muzzles.is_empty():
		return
	var dmg: float = w["damage"]
	var wclass: String = w["class"]
	var glow := Defs.team_glow(shooter.team)
	var volley := false
	if shooter is Unit:
		var u := shooter as Unit
		if w.get("per_member", false):
			dmg *= u.members_alive()
		if u.special_time > 0.0 and u.def.get("special", "") == "aether_volley":
			wclass = "lance"
			volley = true
	var aim := target.aim_point()
	var cov := {}
	if w["fx"] in ["tracer", "shell_flat", "beam"]:
		cov = cover_against(muzzles[0], target)
	var block: float = COVER_BLOCK[int(cov.get("kind", 0))]
	match w["fx"]:
		"tracer":
			var col: Color = glow if volley else TRACER_COLORS.get(w["class"], Color(1, 0.85, 0.5))
			var hits := 0
			for i in muzzles.size():
				var stopped := randf() < block
				if not stopped:
					hits += 1
				if i >= 8:
					continue
				var m := muzzles[i]
				var jitter := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.8), randf_range(-1, 1)) * target.radius * 0.45
				var end: Vector3 = (cov["at"] as Vector3) + jitter * 0.4 if stopped else aim + jitter
				world.fx.tracer(m, end, col, 0.09 if w["class"] != "gatling" else 0.12, randf() * 0.12)
				world.fx.muzzle(m, col, 0.55 if w["class"] != "gatling" else 0.8)
				if stopped:
					_hit_cover(end, int(cov["kind"]))
				elif randf() < 0.35:
					world.fx.impact_dust(end, 0.5)
			if hits > 0:
				target.take_damage(dmg * hits / muzzles.size(), wclass, shooter)
			var snd := "rifle" if w["class"] in ["rifle", "pistol"] else "gatling"
			world.sfx.play_at(snd, muzzles[0])
		"shell_flat":
			for m in muzzles:
				# a shell that meets cover bursts against it
				var to: Vector3 = cov["at"] if randf() < block else aim
				world.projectiles.shell(shooter, m, to, w, false, dmg / muzzles.size(), wclass)
				world.fx.muzzle(m, Color(1.0, 0.7, 0.35), 1.8)
				world.fx.smoke(m, 1.6, 0.35)
			world.fx.light_flash(muzzles[0], Color(1.0, 0.7, 0.4), 6.0)
			world.sfx.play_at("cannon", muzzles[0])
		"titan_beam":
			# a thick beam from the mask that bursts where it lands, fliers included
			var m0 := muzzles[0]
			var c := glow.lerp(Color.WHITE, 0.3)
			for k in 3:
				world.fx.beam(m0, aim + Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.3), randf_range(-0.6, 0.6)), c, 0.45)
			splash(aim, float(w.get("splash", 5.0)), dmg, wclass, shooter.team, shooter, true)
			var g := Vector3(aim.x, world.terrain.ground_at(aim.x, aim.z), aim.z)
			world.fx.explosion(aim, 2.0)
			if not target.is_air:
				world.fx.burn(g, 3.0, 2.5, glow)
			world.fx.light_flash(aim, glow, 9.0)
			world.sfx.play_at("beam", m0)
		"missile":
			for m in muzzles:
				world.projectiles.missile(shooter, m, aim + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), dmg / muzzles.size(),
						float(w.get("splash", 2.5)), wclass)
				world.fx.muzzle(m, glow, 1.0)
				world.fx.smoke(m, 1.0, 0.3)
			world.sfx.play_at("mortar", muzzles[0], -8.0)
		"shell_arc":
			var lead := Vector3.ZERO
			if target is Unit:
				lead = (target as Unit).velocity * 1.2
			for m in muzzles:
				world.projectiles.shell(shooter, m, target.global_position + lead, w, true, dmg, wclass)
				world.fx.muzzle(m, Color(1.0, 0.65, 0.3), 2.4)
				world.fx.smoke(m, 2.4, 0.45)
			world.fx.light_flash(muzzles[0], Color(1.0, 0.65, 0.35), 8.0)
			world.sfx.play_at("mortar", muzzles[0])
		"beam":
			var hits := 0
			var end := aim
			for m in muzzles:
				if randf() < block:
					world.fx.beam(m, cov["at"], glow, 0.35)
					_hit_cover(cov["at"], int(cov["kind"]))
				else:
					hits += 1
					world.fx.beam(m, aim, glow, 0.35)
			if hits > 0:
				target.take_damage(dmg * hits / muzzles.size(), wclass, shooter)
			else:
				end = cov["at"]
			world.fx.flash(end, glow, 2.5)
			world.fx.sparks(end, 10, glow)
			world.fx.light_flash(end, glow, 7.0)
			world.sfx.play_at("beam", muzzles[0])
		"smash", "talon", "flame", "rend":
			# the blow lands when the animation gets there
			world.projectiles.strike(shooter, target, float(w.get("delay", 0.3)), dmg, float(w.get("splash", 0.0)), wclass, w["fx"])
			if w["fx"] == "flame":
				world.sfx.play_at("flame", muzzles[0])
		"bite":
			target.take_damage(dmg, wclass, shooter)
			world.fx.impact_dust(aim, 0.7)
			if target.is_mechanical or target.is_building:
				world.fx.sparks(aim, 4)
			world.sfx.play_at("bite", muzzles[0])


## Cover between a direct shot from `from` and a ground unit: {"kind": 1 light / 2 heavy, "at": the
## point where the shot meets it}, or {} when there is none. Only cover within 8 m of the target counts,
## and only where it rises above the line of fire, so a low rock shields infantry but not a walker.
static func cover_against(from: Vector3, target: Entity) -> Dictionary:
	if not (target is Unit) or target.is_air:
		return {}
	var to := target.aim_point()
	var flat := Vector2(from.x - to.x, from.z - to.z)
	var d := flat.length()
	var s := target.radius * 0.7 + 1.0
	var limit := minf(8.0, d - 2.0)
	if s > limit:
		return {}
	var dir := flat / d
	var world := World.inst
	while s <= limit:
		var p := Vector3(to.x + dir.x * s, 0.0, to.z + dir.y * s)
		var c := world.nav.cover_at(p)
		if c > 0:
			var y := lerpf(to.y, from.y, s / d)
			if world.terrain.height_at(p.x, p.z) + float(c & 127) * 0.25 > y:
				p.y = y
				return {"kind": 2 if (c & 128) != 0 else 1, "at": p}
		s += 1.0
	return {}


## Strongest cover right beside a ground unit (0 none, 1 light, 2 heavy), whatever the direction.
static func cover_near(u: Unit) -> int:
	if u.is_air:
		return 0
	var world := World.inst
	var best := 0
	var aim_y := u.aim_point().y
	for k in 8:
		var a := k * TAU / 8.0
		var p := u.global_position + Vector3(cos(a), 0.0, sin(a)) * (u.radius * 0.7 + 1.5)
		var c := world.nav.cover_at(p)
		if c > 0 and world.terrain.height_at(p.x, p.z) + float(c & 127) * 0.25 > aim_y:
			best = maxi(best, 2 if (c & 128) != 0 else 1)
	return best


static func _hit_cover(p: Vector3, kind: int) -> void:
	var fx := World.inst.fx
	fx.impact_dust(p, 0.7)
	if kind == 2:
		fx.sparks(p, 3)


## Area damage (friendly fire off). Falloff to 30% at the edge.
static func splash(pos: Vector3, radius: float, dmg: float, wclass: String, team: int, source: Entity, hit_air: bool = false, only_air: bool = false) -> void:
	for e: Entity in World.inst.query(pos, radius):
		if e.team == team or (e.is_air and not hit_air) or (only_air and not e.is_air):
			continue
		var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length() - e.radius * 0.5
		var k := clampf(1.0 - d / radius, 0.3, 1.0)
		e.take_damage(dmg * k, wclass, source if is_instance_valid(source) else null)

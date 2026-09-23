class_name Combat
extends RefCounted
## Weapon discharge: damage, projectiles and firing effects.

const TRACER_COLORS := {
	"rifle": Color(1.0, 0.82, 0.45), "pistol": Color(1.0, 0.8, 0.5), "gatling": Color(1.0, 0.75, 0.35),
	"flak": Color(1.0, 0.9, 0.6),
}


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
	match w["fx"]:
		"tracer":
			target.take_damage(dmg, wclass, shooter)
			var col: Color = glow if volley else TRACER_COLORS.get(w["class"], Color(1, 0.85, 0.5))
			var n := mini(muzzles.size(), 8)
			for i in n:
				var m := muzzles[i]
				var jitter := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.8), randf_range(-1, 1)) * target.radius * 0.45
				world.fx.tracer(m, aim + jitter, col, 0.09 if w["class"] != "gatling" else 0.12, randf() * 0.12)
				world.fx.muzzle(m, col, 0.55 if w["class"] != "gatling" else 0.8)
				if randf() < 0.35:
					world.fx.impact_dust(aim + jitter, 0.5)
			var snd := "rifle" if w["class"] in ["rifle", "pistol"] else "gatling"
			world.sfx.play_at(snd, muzzles[0])
		"shell_flat":
			for m in muzzles:
				world.projectiles.shell(shooter, m, aim, w, false, dmg / muzzles.size(), wclass)
				world.fx.muzzle(m, Color(1.0, 0.7, 0.35), 1.8)
				world.fx.smoke(m, 1.6, 0.35)
			world.fx.light_flash(muzzles[0], Color(1.0, 0.7, 0.4), 6.0)
			world.sfx.play_at("cannon", muzzles[0])
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
			target.take_damage(dmg, wclass, shooter)
			for m in muzzles:
				world.fx.beam(m, aim, glow, 0.35)
			world.fx.flash(aim, glow, 2.5)
			world.fx.sparks(aim, 10, glow)
			world.fx.light_flash(aim, glow, 7.0)
			world.sfx.play_at("beam", muzzles[0])


## Area damage (friendly fire off). Falloff to 30% at the edge.
static func splash(pos: Vector3, radius: float, dmg: float, wclass: String, team: int, source: Entity, hit_air: bool = false) -> void:
	for e: Entity in World.inst.query(pos, radius):
		if e.team == team or (e.is_air and not hit_air):
			continue
		var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length() - e.radius * 0.5
		var k := clampf(1.0 - d / radius, 0.3, 1.0)
		e.take_damage(dmg * k, wclass, source if is_instance_valid(source) else null)

class_name Projectiles
extends Node3D
## Ballistic shells and bombs; visuals are emitted through FX each tick.

var shells: Array[Dictionary] = []


func shell(source: Entity, from: Vector3, to: Vector3, w: Dictionary, arc: bool, dmg: float, wclass: String) -> void:
	var d := from.distance_to(to)
	var flight := d / 95.0
	if arc:
		flight = clampf(1.4 + d / 36.0, 1.8, 3.6)
	var g := World.inst.terrain.ground_at(to.x, to.z)
	var impact := Vector3(to.x, maxf(to.y, g), to.z)
	if arc:
		impact += Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
		impact.y = World.inst.terrain.ground_at(impact.x, impact.z)
	shells.append({"from": from, "to": impact, "t": 0.0, "flight": flight, "arc": arc, "h": d * 0.45 if arc else d * 0.04,
			"dmg": dmg, "class": wclass, "splash": float(w.get("splash", 2.0)), "team": source.team, "src": source,
			"trail": 0.0, "bomb": false, "prev": from})


func drop_bomb(source: Entity, from: Vector3, to: Vector3) -> void:
	shells.append({"from": from, "to": to, "t": 0.0, "flight": 1.1, "arc": false, "h": 0.0, "dmg": 75.0,
			"class": "shell", "splash": 6.5, "team": source.team, "src": source, "trail": 0.0, "bomb": true, "prev": from})


func tick(dt: float) -> void:
	var fx := World.inst.fx
	var i := 0
	while i < shells.size():
		var s := shells[i]
		s["t"] += dt
		var k: float = clampf(s["t"] / s["flight"], 0.0, 1.0)
		var p: Vector3
		if s["bomb"]:
			p = (s["from"] as Vector3).lerp(s["to"], k)
			p.y = lerpf((s["from"] as Vector3).y, (s["to"] as Vector3).y, k * k)
		else:
			p = (s["from"] as Vector3).lerp(s["to"], k)
			p.y += sin(k * PI) * float(s["h"])
		s["prev"] = p
		s["trail"] -= dt
		if s["trail"] <= 0.0:
			s["trail"] = 0.05 if s["arc"] else 0.03
			fx.smoke(p, 0.7 if s["arc"] else 0.45, 0.22)
		fx.glow_dot(p, Color(1.0, 0.75, 0.4) if not s["bomb"] else Color(0.5, 0.9, 1.0), 0.9 if s["arc"] else 0.6)
		if k >= 1.0:
			_impact(s)
			shells.remove_at(i)
			continue
		i += 1


func _impact(s: Dictionary) -> void:
	var p: Vector3 = s["to"]
	var world := World.inst
	var big: bool = s["arc"] or s["bomb"]
	var src: Entity = s["src"] if is_instance_valid(s["src"]) else null
	Combat.splash(p, s["splash"], s["dmg"], s["class"], s["team"], src, s["bomb"])
	world.fx.explosion(p + Vector3(0, 0.6, 0), 1.9 if big else 1.2)
	world.fx.debris(p, 6 if big else 3, true)
	world.fx.crater(p, 2.2 if big else 1.3)
	world.sfx.play_at("explosion" if big else "explosion_small", p)
	if big:
		world.camera.shake(0.25)

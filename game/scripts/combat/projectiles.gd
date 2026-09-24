class_name Projectiles
extends Node3D
## Ballistic shells, bombs and thrown boulders, plus delayed melee blows and dragon fire;
## visuals are emitted through FX each tick.

var shells: Array[Dictionary] = []
var strikes: Array[Dictionary] = []


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


## A missile on a shallow, weaving arc with a smoke trail and a glowing motor.
func missile(source: Entity, from: Vector3, to: Vector3, dmg: float, splash: float, wclass: String) -> void:
	var d := from.distance_to(to)
	var g := World.inst.terrain.ground_at(to.x, to.z)
	var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * minf(d * 0.12, 4.0)
	shells.append({"from": from, "to": Vector3(to.x, maxf(to.y, g), to.z), "t": 0.0, "flight": d / 48.0 + 0.15, "arc": false,
			"h": d * 0.14, "dmg": dmg, "class": wclass, "splash": splash, "team": source.team, "src": source, "trail": 0.0,
			"bomb": false, "prev": from, "wob": side, "glow": Defs.team_glow(source.team)})


func drop_bomb(source: Entity, from: Vector3, to: Vector3) -> void:
	shells.append({"from": from, "to": to, "t": 0.0, "flight": 1.1, "arc": false, "h": 0.0, "dmg": 75.0,
			"class": "shell", "splash": 6.5, "team": source.team, "src": source, "trail": 0.0, "bomb": true, "prev": from})


## Cyclops boulder: a real rock on a high arc, crushing whatever it lands on.
func boulder(source: Entity, from: Vector3, to: Vector3) -> void:
	var rock := CyclopsVisual.make_boulder()
	add_child(rock)
	rock.global_position = from
	var g := World.inst.terrain.ground_at(to.x, to.z)
	var d := from.distance_to(to)
	shells.append({"from": from, "to": Vector3(to.x, g, to.z), "t": 0.0, "flight": clampf(0.9 + d / 38.0, 1.1, 2.3), "arc": true,
			"h": d * 0.28 + 3.0, "dmg": 170.0, "class": "boulder", "splash": 6.5, "team": source.team, "src": source,
			"trail": 0.0, "bomb": false, "prev": from, "rock": rock, "spin": Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))})


## A melee blow, talon strike or breath that lands `delay` seconds after the attack starts.
func strike(source: Entity, target: Entity, delay: float, dmg: float, splash: float, wclass: String, kind: String) -> void:
	strikes.append({"t": delay, "src": source, "target": target, "pos": target.global_position, "dmg": dmg, "splash": splash,
			"class": wclass, "team": source.team, "kind": kind, "air": target.is_air})


## Dragon Inferno: one burst of fire on the ground.
func firestorm(source: Entity, _from: Vector3, to: Vector3) -> void:
	var p := Vector3(to.x, World.inst.terrain.ground_at(to.x, to.z), to.z)
	strikes.append({"t": 0.3, "src": source, "target": null, "pos": p, "dmg": 70.0, "splash": 6.0, "class": "flame", "team": source.team,
			"kind": "flame", "air": false})


func tick(dt: float) -> void:
	var fx := World.inst.fx
	var j := 0
	while j < strikes.size():
		strikes[j]["t"] -= dt
		if strikes[j]["t"] > 0.0:
			j += 1
			continue
		var st: Dictionary = strikes[j]
		strikes.remove_at(j)
		_land(st)
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
			if s.has("wob"):
				p += (s["wob"] as Vector3) * sin(k * PI)
		s["prev"] = p
		s["trail"] -= dt
		if s.has("rock"):
			var rock: Node3D = s["rock"]
			rock.global_position = p
			rock.rotation += (s["spin"] as Vector3) * dt
			if s["trail"] <= 0.0:
				s["trail"] = 0.08
				fx.dust(p, 1.0)
		else:
			if s["trail"] <= 0.0:
				s["trail"] = 0.05 if s["arc"] else 0.03
				fx.smoke(p, 0.7 if s["arc"] else 0.45, 0.22)
			fx.glow_dot(p, s.get("glow", Color(1.0, 0.75, 0.4) if not s["bomb"] else Color(0.5, 0.9, 1.0)), 0.9 if s["arc"] else 0.6)
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
	if s.has("rock"):
		(s["rock"] as Node3D).queue_free()
		_quake(p, 5.0, 0.5)
		return
	world.fx.explosion(p + Vector3(0, 0.6, 0), 1.9 if big else 1.2)
	world.fx.debris(p, 6 if big else 3, true)
	world.fx.crater(p, 2.2 if big else 1.3)
	world.sfx.play_at("explosion" if big else "explosion_small", p)
	if big:
		world.camera.shake(0.25)


func _land(st: Dictionary) -> void:
	var src: Entity = st["src"] if is_instance_valid(st["src"]) and st["src"].alive else null
	var tgt: Entity = st["target"] if st["target"] != null and is_instance_valid(st["target"]) and st["target"].alive else null
	if src == null:
		return
	var p: Vector3 = st["pos"]
	if tgt and tgt.global_position.distance_to(p) < 6.0:
		p = tgt.global_position
	var fx := World.inst.fx
	match st["kind"]:
		"smash":
			Combat.splash(p, st["splash"], st["dmg"], st["class"], st["team"], src)
			p.y = World.inst.terrain.ground_at(p.x, p.z)
			_quake(p, 3.5, 0.3)
		"talon":
			if tgt:
				tgt.take_damage(st["dmg"], st["class"], src)
				fx.impact_dust(tgt.aim_point(), 0.8)
				if tgt.is_mechanical:
					fx.sparks(tgt.aim_point(), 5)
		"rend":
			# burning claws: tear through everything in reach and leave the ground smouldering
			Combat.splash(p, st["splash"], st["dmg"], st["class"], st["team"], src)
			var fc := DragonVisual.fire_of(st["team"])
			p.y = World.inst.terrain.ground_at(p.x, p.z)
			fx.burn(p, st["splash"] * 0.5, 1.5, fc)
			fx.sparks(p + Vector3(0, 1.0, 0), 10, fc)
			fx.flash(p + Vector3(0, 1.0, 0), fc, 2.0)
			fx.impact_dust(p + Vector3(0, 0.4, 0), 1.2)
			World.inst.sfx.play_at("bite", p)
		"flame":
			Combat.splash(p, st["splash"], st["dmg"], st["class"], st["team"], src, st["air"], st["air"])
			var c := DragonVisual.fire_of(st["team"])
			if not st["air"]:
				p.y = World.inst.terrain.ground_at(p.x, p.z)
				fx.burn(p, st["splash"] * 0.6, 2.5, c)
				fx.crater(p, 1.8)
			fx.light_flash(p + Vector3(0, 1.5, 0), c, 5.0)


## Ground shock from a club blow or a boulder: dust ring, stones, scorch and a thud.
func _quake(p: Vector3, r: float, shake: float) -> void:
	var fx := World.inst.fx
	for k in 8:
		var a := k / 8.0 * TAU
		fx.dust(p + Vector3(cos(a) * r * 0.5, 0.4, sin(a) * r * 0.5), 2.5 + r * 0.3)
	fx.debris(p, 6, true)
	fx.crater(p, r * 0.45)
	World.inst.sfx.play_at("smash", p)
	var cam := World.inst.camera
	var d := cam.focus.distance_to(p)
	if d < 70.0:
		cam.shake(shake * (1.0 - d / 70.0))

class_name DevScenarios
extends RefCounted
## Scripted setups for automated screenshots and smoke tests.


static func run(name: String, world: World, commander: Commander, camera: CameraRig, match_node: Node = null) -> void:
	match name:
		"ui_build":
			commander.set_selection([world.citadel(0)])
			match_node.hud.build_mode = true
			match_node.hud.shrine_page = Game.arg("page") == "shrines"
			camera.set_view(Vector3(-128, 0, 128), -45.0, 90.0)
			if not Game.args.has("noplace"):
				commander.begin_place("foundry")
				var m := Game.arg("mouse", "900,480").split(",")
				Input.warp_mouse(Vector2(float(m[0]), float(m[1])))
		"ui_pause":
			match_node.hud.toggle_pause()
		"ui_save":
			match_node.hud.toggle_pause()
			match_node.hud.menus._open_save(true)
		"ui_help":
			match_node.hud.menus.add_child(HelpPanel.make(func(): pass))
		"ui_end":
			world.end_game(0)
		"ui_multi":
			commander.set_selection(world.units.filter(func(u: Unit) -> bool: return u.team == 0))
		"ui_walker":
			for u in world.units:
				if u.team == 0 and u.def_id == "walker":
					commander.set_selection([u])
					camera.set_view(u.global_position, -45.0, 45.0)
		"showcase":
			world.fog.enabled = false
			for i in 10:
				var p := Vector3(-66 + (i % 5) * 7.0, 0, 62 - (i / 5) * 7.0 - (i % 5) * 2.0)
				var u := world.spawn_unit("aetherguard", 0, p, deg_to_rad(135))
				if i % 3 == 0:
					u.toggle_fortify()
				else:
					u.order_hold()
			for i in 3:
				world.spawn_unit("walker", 0, Vector3(-74 + i * 9.0, 0, 76 - i * 4.0), deg_to_rad(135)).order_hold()
			for i in 2:
				world.spawn_unit("mortar", 0, Vector3(-86 + i * 8.0, 0, 88), deg_to_rad(135)).toggle_deploy()
			world.spawn_unit("airship", 0, Vector3(-95, 0, 70), deg_to_rad(135)).order_attack_move(Vector3(-30, 0, 30))
			for i in 12:
				var e := world.spawn_unit("aetherguard", 1, Vector3(-18 + (i % 4) * 5.0, 0, 16 - (i / 4) * 6.0 - (i % 4) * 2.0), deg_to_rad(-45))
				e.order_attack_move(Vector3(-60, 0, 60))
			for i in 3:
				world.spawn_unit("walker", 1, Vector3(-4 + i * 8.0, 0, -4 - i * 6.0), deg_to_rad(-45)).order_attack_move(Vector3(-60, 0, 60))
			world.spawn_unit("airship", 1, Vector3(20, 0, -40), deg_to_rad(-45)).order_attack_move(Vector3(-55, 0, 55))
		"battle":
			for i in 5:
				var u := world.spawn_unit("aetherguard", 0, Vector3(-40 + i * 7, 0, 58), deg_to_rad(135))
				u.order_attack_move(Vector3(20, 0, 20))
			world.spawn_unit("walker", 0, Vector3(-58, 0, 66), deg_to_rad(135)).order_attack_move(Vector3(10, 0, 10))
			world.spawn_unit("mortar", 0, Vector3(-66, 0, 76), deg_to_rad(135)).toggle_deploy()
			world.spawn_unit("airship", 0, Vector3(-80, 0, 80), deg_to_rad(135)).order_attack_move(Vector3(0, 0, 0))
			for i in 6:
				var e := world.spawn_unit("aetherguard", 1, Vector3(4 + i * 6, 0, -12 - i * 3), deg_to_rad(-45))
				e.order_attack_move(Vector3(-50, 0, 50))
			world.spawn_unit("walker", 1, Vector3(20, 0, -30), deg_to_rad(-45)).order_attack_move(Vector3(-50, 0, 50))
			world.spawn_unit("walker", 1, Vector3(32, 0, -24), deg_to_rad(-45)).order_attack_move(Vector3(-50, 0, 50))
			world.fog.enabled = false
		"creatures":
			world.fog.enabled = false
			var crown := [["cyclops", -104, 100], ["cyclops", -94, 98], ["cerberus", -98, 92], ["cerberus", -90, 90],
					["griffin", -108, 92], ["griffin", -100, 108], ["dragon", -112, 112]]
			for c: Array in crown:
				world.spawn_unit(c[0], 0, Vector3(c[1], 0, c[2]), deg_to_rad(135)).order_attack_move(Vector3(-70, 0, 66))
			for i in 6:
				var e := world.spawn_unit("aetherguard", 1, Vector3(-86 + (i % 3) * 6.0, 0, 80 - (i / 3) * 6.0), deg_to_rad(-45))
				e.order_attack_move(Vector3(-110, 0, 105))
			world.spawn_unit("walker", 1, Vector3(-76, 0, 70), deg_to_rad(-45)).order_attack_move(Vector3(-110, 0, 105))
			world.spawn_unit("mortar", 1, Vector3(-68, 0, 64), deg_to_rad(-45)).order_attack_move(Vector3(-110, 0, 105))
			world.spawn_unit("airship", 1, Vector3(-70, 0, 74), deg_to_rad(-45)).order_attack_move(Vector3(-110, 0, 105))
		"bridge":
			# the Crown's beasts storm the north-west bridge
			world.fog.enabled = false
			# a mid-game Crown (three cities, a habitat, no start units) so the HUD's population adds up
			for u in world.units.duplicate():
				if u.team == 0:
					u.die()
			for s in world.sites:
				if s.site_id in ["brassholm", "west_foundry", "south_works"]:
					s.assign(0)
			world.spawn_building("habitat", 0, Vector3(-120, 0, 168), deg_to_rad(135))
			var br: Dictionary = world.terrain.bridges.filter(func(b: Dictionary) -> bool: return b["id"] == "nw_bridge")[0]
			var on := func(t: float, s: float) -> Vector3:
				var p: Vector2 = br["a"] + br["u"] * t + br["n"] * s
				return Vector3(p.x, 0, p.y)
			var face := atan2(br["u"].x, br["u"].y)
			var goal: Vector3 = on.call(80.0, 0.0)
			for c: Array in [["cyclops", 24, 0], ["cerberus", 34, -2.5], ["cerberus", 32, 3], ["griffin", 40, 12], ["griffin", 46, -12], ["dragon", 38, -10]]:
				world.spawn_unit(c[0], 0, on.call(c[1], c[2]), face).order_attack_move(goal)
			for i in 6:
				world.spawn_unit("aetherguard", 0, on.call(6.0 + (i / 2) * 5.0, -2.5 + (i % 2) * 5.0), face).order_attack_move(goal)
			for i in 8:
				world.spawn_unit("aetherguard", 1, on.call(58.0 + (i / 4) * 6.0, -6.0 + (i % 4) * 4.0), face + PI).order_hold()
			world.spawn_unit("walker", 1, on.call(64.0, -9.0), face + PI).order_hold()
			world.spawn_unit("walker", 1, on.call(66.0, 8.0), face + PI).order_hold()
			world.spawn_unit("mortar", 1, on.call(78.0, 0.0), face + PI).toggle_deploy()
			world.spawn_unit("airship", 1, on.call(62.0, 16.0), face + PI).order_hold()
		"lineup":
			# the four beasts before a Beast Sanctum; --lineup=x,z,facing_deg
			world.fog.enabled = false
			var q := Game.arg("lineup", "-135,-70,-5").split(",")
			var at := Vector3(float(q[0]), 0, float(q[1]))
			var face := deg_to_rad(float(q[2]))
			world.spawn_building("foundry" if Game.args.has("gearforge") else "sanctum", 0, at, face)
			var basis := Basis(Vector3.UP, face)
			var cast: Array = [["griffin", -10, 8, 25], ["cerberus", -5, 18.5, 18], ["cyclops", 7, 15, -20], ["dragon", 9, 1, 0]]
			if Game.args.has("new_races"):
				cast = [["demon", -6, 16, 20], ["angel", 7, 13, -20]]
			if Game.args.has("titan"):
				cast = [["titan", -2, 20, 10], ["mech", 10, 12, -20]]
			if Game.args.has("gearforge"):
				cast = [["colossus", -3, 22, 10], ["quadwalker", 10, 13, -25], ["strider", -11, 11, 25], ["dreadnought", 2, 8, 0]]
			for c: Array in cast:
				var u := world.spawn_unit(c[0], 0, at + basis * Vector3(c[1], 0, c[2]), face + deg_to_rad(c[3]))
				u.order_hold()
				if c[0] == "cerberus":
					u.use_special()
		"cover_test":
			# two identical firefights; only the first Crown squad stands behind a rock
			world.fog.enabled = false
			var rock := Vector3(-132.8, 0, -38.5)
			var crown: Array[Unit] = []
			var foes: Array[Unit] = []
			for lane in 2:
				var dz := -16.0 * lane
				crown.append(world.spawn_unit("aetherguard", 0, rock + Vector3(3.4, 0, dz), deg_to_rad(-90)))
				foes.append(world.spawn_unit("aetherguard", 1, rock + Vector3(-22.0, 0, dz), deg_to_rad(90)))
				crown[lane].order_hold()
				foes[lane].order_hold()
			commander.set_selection([crown[0]])
			world.get_tree().create_timer(0.5).timeout.connect(func() -> void:
				for lane in 2:
					print("[cover_test] lane %d: shots at the Crown meet cover %s, shots back meet %s" % [lane,
							Combat.cover_against(foes[lane].aim_point(), crown[lane]).get("kind", 0),
							Combat.cover_against(crown[lane].aim_point(), foes[lane]).get("kind", 0)]))
			world.get_tree().create_timer(12.0).timeout.connect(func() -> void:
				print("[cover_test] after 12 s: behind the rock %.0f hp, in the open %.0f hp (Varkesh %.0f / %.0f)" % [
						crown[0].hp, crown[1].hp, foes[0].hp, foes[1].hp]))
		"touch_test":
			var t: Node = load("res://scripts/dev/touch_test.gd").new()
			match_node.add_child(t)
			t.setup(world, commander, camera, match_node.hud)
		"titan_test":
			# our titan against a Varkesh line; Titan's Light after 4 s, the limit of one checked
			world.fog.enabled = false
			world.player(0).material = 5000.0
			world.player(0).aether = 5000.0
			var at := Vector3(-60, 0, 20)
			var titan := world.spawn_unit("titan", 0, at, 0.0)
			var foes: Array[Unit] = []
			for i in 8:
				foes.append(world.spawn_unit(["aetherguard", "walker", "aetherguard", "mortar"][i % 4], 1, at + Vector3((i % 4) * 6.0 - 9.0, 0, 26.0 + (i / 4) * 12.0), PI))
			for f in foes:
				f.order_hold()
			camera.set_view(at + Vector3(0, 0, 18), -20.0, 80.0)
			var hp0 := titan.hp
			print("[titan_test] citadel says: '%s'" % world.citadel(0).can_queue("titan"))
			world.get_tree().create_timer(4.0).timeout.connect(func() -> void:
				print("[titan_test] light=%s" % titan.use_special(at + Vector3(0, 0, 40))))
			world.get_tree().create_timer(14.0).timeout.connect(func() -> void:
				var alive := foes.filter(func(f) -> bool: return is_instance_valid(f) and f.alive).size()
				print("[titan_test] 14 s: foes alive %d / %d, titan %.0f -> %.0f (decay %.0f/s)" % [alive, foes.size(), hp0, titan.hp, titan.def["decay"]]))
		"judgement_test":
			# our tower strikes a Varkesh column through the HUD path; theirs strikes our citadel
			world.fog.enabled = false
			var ours := world.spawn_building("judgement", 0, Vector3(-120, 0, 150), 0.0, true)
			ours.charge = 999.0
			var theirs := world.spawn_building("judgement", 1, Vector3(140, 0, -150), 0.0, true)
			var at := Vector3(-60, 0, 20)
			var foes: Array[Unit] = []
			for i in 6:
				foes.append(world.spawn_unit(["aetherguard", "walker", "cyclops"][i % 3], 1, at + Vector3((i % 3) * 7.0 - 7.0, 0, (i / 3) * 8.0), PI))
			for f in foes:
				f.order_hold()
			camera.set_view(at, -30.0, 90.0)
			commander.set_selection([ours])
			commander.begin_strike(ours)
			var fired := commander.strike_at(at)
			var cit := world.citadel(0)
			var before := cit.hp
			var enemy_ai: EnemyAI = match_node.ai
			world.get_tree().create_timer(1.0).timeout.connect(func() -> void:
				print("[judgement_test] ours fired=%s charge=%.0f, enemy AI aims at %s, citadel at %s" % [fired, ours.charge,
						enemy_ai.strike_target(), cit.global_position])
				theirs.charge = 999.0
				theirs.fire_superweapon(cit.global_position))
			world.get_tree().create_timer(12.0).timeout.connect(func() -> void:
				var alive := foes.filter(func(f) -> bool: return is_instance_valid(f) and f.alive).size()
				print("[judgement_test] foes alive %d / %d; our citadel %.0f -> %.0f (lost %.0f%%, cap 30%%)" % [alive, foes.size(), before, cit.hp,
						(before - cit.hp) / cit.max_hp * 100.0]))
		"mech_test":
			# two mechs against a Varkesh warcamp and an infantry squad; a salvo after 5 s
			world.fog.enabled = false
			var at := Vector3(-60, 0, 20)
			var camp := world.spawn_building("barracks", 1, at + Vector3(0, 0, 36), PI, true)
			world.spawn_unit("aetherguard", 1, at + Vector3(10, 0, 30), PI)
			var mechs: Array[Unit] = [world.spawn_unit("mech", 0, at, 0.0), world.spawn_unit("mech", 0, at + Vector3(6, 0, 0), 0.0)]
			camera.set_view(at + Vector3(0, 0, 18), -20.0, 60.0)
			for m in mechs:
				m.order_attack(camp)
			world.get_tree().create_timer(5.0).timeout.connect(func() -> void:
				print("[mech_test] 5 s: warcamp %.0f / %.0f, salvo=%s" % [camp.hp, camp.max_hp, mechs[0].use_special(camp.global_position)]))
			world.get_tree().create_timer(15.0).timeout.connect(func() -> void:
				print("[mech_test] 15 s: warcamp %s %.0f, mechs %.0f %.0f" % ["alive" if camp.alive else "destroyed", camp.hp, mechs[0].hp, mechs[1].hp]))
		"gearforge_test":
			# the four Gearforge machines on the meadow by the western foundry site meet a Varkesh
			# party coming from the north; prints how each fared after 25 s
			world.fog.enabled = false
			var at := Vector3(-135, 0, -58)
			var foes: Array[Unit] = [world.spawn_unit("walker", 1, at + Vector3(8, 0, 46), PI),
					world.spawn_unit("aetherguard", 1, at + Vector3(-6, 0, 40), PI), world.spawn_unit("griffin", 1, at + Vector3(-12, 0, 50), PI)]
			var ours: Array[Unit] = []
			for c: Array in [["strider", -10, 2], ["quadwalker", 8, -2], ["colossus", -1, -6], ["dreadnought", 0, -14]]:
				ours.append(world.spawn_unit(c[0], 0, at + Vector3(c[1], 0, c[2]), 0.0))
			if not Game.args.has("cam"):
				camera.set_view(at + Vector3(0, 0, 10), -165.0, 60.0)
			for f in foes:
				f.order_attack_move(at)
			for u in ours:
				u.order_attack_move(at + Vector3(0, 0, 16))
			world.get_tree().create_timer(25.0).timeout.connect(func() -> void:
				for u in ours:
					print("[gearforge_test] %s hp %.0f/%.0f kills %d" % [u.def_id, u.hp, u.max_hp, u.kills])
				print("[gearforge_test] foes alive %d" % foes.filter(func(f) -> bool: return is_instance_valid(f) and f.alive).size()))
		"races_test":
			# a demon and an angel against a Varkesh squad, walker and griffin; specials after 6 s
			world.fog.enabled = false
			var at := Vector3(-60, 0, 20)
			var demon := world.spawn_unit("demon", 0, at, 0.0)
			var angel := world.spawn_unit("angel", 0, at + Vector3(-6, 0, 0), 0.0)
			var foes: Array[Unit] = [world.spawn_unit("aetherguard", 1, at + Vector3(0, 0, 18), PI),
					world.spawn_unit("walker", 1, at + Vector3(8, 0, 22), PI), world.spawn_unit("griffin", 1, at + Vector3(-8, 0, 24), PI)]
			camera.set_view(at + Vector3(0, 0, 10), -30.0, 55.0)
			for f in foes:
				f.order_attack_move(at)
			demon.order_attack_move(at + Vector3(0, 0, 20))
			angel.order_attack_move(at + Vector3(0, 0, 20))
			world.get_tree().create_timer(6.0).timeout.connect(func() -> void:
				demon.hp *= 0.6
				print("[races_test] hellfire=%s blessing=%s (demon hp %.0f before blessing)" % [demon.use_special(), angel.use_special(), demon.hp])
				print("[races_test] demon hp after blessing %.0f" % demon.hp))
			world.get_tree().create_timer(20.0).timeout.connect(func() -> void:
				print("[races_test] after 20 s: demon %.0f/%.0f angel %.0f/%.0f, kills %d / %d; foes alive %d" % [demon.hp, demon.max_hp, angel.hp,
						angel.max_hp, demon.kills, angel.kills, foes.filter(func(f) -> bool: return is_instance_valid(f) and f.alive).size()]))
		"flyover":
			# flyers crossing the Ironspine gate and the Crown citadel; prints how close each hull came
			world.fog.enabled = false
			var along := Vector3(1, 0, 1).normalized()
			var gate := Vector3(-51.5, 0, 51.5)
			var runs := [["airship", gate + Vector3(-30, 0, 30), gate + Vector3(30, 0, -30)],
					["dragon", gate + along * 15.0 + Vector3(-30, 0, 30), gate + along * 15.0 + Vector3(30, 0, -30)],
					["griffin", gate - along * 15.0 + Vector3(-30, 0, 30), gate - along * 15.0 + Vector3(30, 0, -30)],
					["airship", Vector3(-200, 0, 152), Vector3(-100, 0, 152)]]
			for u in world.units.duplicate():
				if u.team == 1:
					u.die()
			var flyers: Array[Unit] = []
			var low := {}
			for r: Array in runs:
				var u := world.spawn_unit(r[0], 0, r[1], 0.0)
				u.order_move(r[2])
				flyers.append(u)
				low[u] = [INF, Vector3.ZERO]
			# from 3 s on, once they have left their spawn height
			var probe := func() -> void:
				for u in flyers:
					if not is_instance_valid(u) or not u.alive or world.match_time < 3.0:
						continue
					var b := Basis(Vector3.UP, u.facing)
					var top := -INF
					for fx: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
						for fz: float in [-1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75, 1.0]:
							var q := u.global_position + b.x * (u._air_box.x * fx) + b.z * (u._air_box.z * fz)
							top = maxf(top, world.nav.top_at(q, world.terrain.height_at(q.x, q.z)))
					var gap := u.global_position.y - u._air_box.y - top
					if gap < low[u][0]:
						low[u] = [gap, u.global_position]
			var t := Timer.new()
			t.wait_time = 0.1
			t.timeout.connect(probe)
			world.add_child(t)
			t.start()
			world.get_tree().create_timer(22.0).timeout.connect(func() -> void:
				for u in flyers:
					if is_instance_valid(u):
						print("[flyover] %s lowest clearance %.1f m at %s" % [u.def_id, low[u][0], low[u][1]]))
		"base":
			world.fog.enabled = false
		"nofog":
			world.fog.enabled = false

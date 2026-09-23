class_name DevScenarios
extends RefCounted
## Scripted setups for automated screenshots and smoke tests.


static func run(name: String, world: World, commander: Commander, camera: CameraRig, match_node: Node = null) -> void:
	match name:
		"ui_build":
			commander.set_selection([world.citadel(0)])
			match_node.hud.build_mode = true
			camera.set_view(Vector3(-128, 0, 128), -45.0, 90.0)
			commander.begin_place("foundry")
			Input.warp_mouse(Vector2(900, 480))
		"ui_pause":
			match_node.hud.toggle_pause()
		"ui_save":
			match_node.hud.toggle_pause()
			match_node.hud.menus._open_save(true)
		"ui_help":
			match_node.hud.menus.add_child(HelpPanel.make(func(): pass))
		"ui_end":
			world.end_game(0)
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
			world.spawn_building("sanctum", 0, at, face)
			var basis := Basis(Vector3.UP, face)
			for c: Array in [["griffin", -10, 8, 25], ["cerberus", -5, 18.5, 18], ["cyclops", 7, 15, -20], ["dragon", 9, 1, 0]]:
				var u := world.spawn_unit(c[0], 0, at + basis * Vector3(c[1], 0, c[2]), face + deg_to_rad(c[3]))
				u.order_hold()
				if c[0] == "cerberus":
					u.use_special()
		"base":
			world.fog.enabled = false
		"nofog":
			world.fog.enabled = false

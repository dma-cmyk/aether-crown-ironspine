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
		"base":
			world.fog.enabled = false
		"nofog":
			world.fog.enabled = false

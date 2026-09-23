class_name DevScenarios
extends RefCounted
## Scripted setups for automated screenshots and smoke tests.


static func run(name: String, world: World, commander: Commander, camera: CameraRig) -> void:
	match name:
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

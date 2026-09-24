extends SceneTree
## Writes the engine license and third-party notices that ship next to the exported game.
## godot --headless --path game --script res://scripts/dev/licenses.gd -- <out.txt>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var t := "Aether Crown: Ironspine is made with the Godot Engine (https://godotengine.org).\n\n"
	t += "== Godot Engine ==\n\n" + Engine.get_license_text() + "\n\n== Third-party components in the engine ==\n"
	for c: Dictionary in Engine.get_copyright_info():
		t += "\n" + str(c["name"]) + "\n"
		for part: Dictionary in c["parts"]:
			t += "  Files: " + ", ".join(part["files"]) + "\n"
			for line: String in part["copyright"]:
				t += "  Copyright: " + line + "\n"
			t += "  License: " + str(part["license"]) + "\n"
	t += "\n== Fonts ==\n\n" + FileAccess.get_file_as_string("res://assets/fonts/OFL.txt") + "\n"
	t += "\n== License texts ==\n"
	var info := Engine.get_license_info()
	for k: String in info:
		t += "\n---- " + k + " ----\n\n" + str(info[k]) + "\n"
	var f := FileAccess.open(args[0] if args.size() > 0 else "user://THIRD-PARTY-NOTICES.txt", FileAccess.WRITE)
	f.store_string(t)
	f.close()
	quit()

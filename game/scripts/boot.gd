extends Node
## Entry point: title screen, or straight into a match for dev captures.


func _ready() -> void:
	await get_tree().process_frame
	if Game.args.has("check-scenarios"):
		_check_scenarios()
	elif Game.args.has("load"):
		if not Game.load_game(Game.arg("load")):
			Game.goto_title()
	elif Game.args.has("gallery"):
		get_tree().change_scene_to_file("res://scenes/gallery.tscn")
	elif Game.args.has("title"):
		Game.goto_title()
	elif Game.is_capture() or Game.args.has("match"):
		Game.start_match()
	else:
		Game.goto_title()


## godot --headless --path game -- --check-scenarios : validate every scenario file and quit.
func _check_scenarios() -> void:
	var bad := 0
	for s in Scenario.list_all():
		print("%s  %s" % ["OK " if s.is_valid() else "NG ", s.path])
		for e in s.errors:
			print("    " + e)
		bad += 0 if s.is_valid() else 1
	get_tree().quit(1 if bad > 0 else 0)

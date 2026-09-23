extends Node
## Entry point: title screen, or straight into a match for dev captures.


func _ready() -> void:
	await get_tree().process_frame
	if Game.args.has("gallery"):
		get_tree().change_scene_to_file("res://scenes/gallery.tscn")
	elif Game.is_capture() or Game.args.has("match"):
		Game.start_match()
	else:
		Game.goto_title()

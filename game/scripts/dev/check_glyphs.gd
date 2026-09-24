extends SceneTree
## Fails when the game's text uses a character the shipped Japanese fonts lack: the Web build has
## no system fonts to fall back on. Fix by rerunning tools/fonts/subset_fonts.py.
## godot --headless --path game --script res://scripts/dev/check_glyphs.gd

const FACES := ["NotoSansCJKjp-Medium", "NotoSansCJKjp-Bold", "NotoSerifCJKjp-Medium"]


func _init() -> void:
	var chars := {}
	_scan("res://", chars)
	var missing := 0
	for face: String in FACES:
		var font: FontFile = load("res://assets/fonts/%s.woff2" % face)
		for c: int in chars:
			if not font.has_char(c):
				printerr("%s lacks U+%04X %s" % [face, c, String.chr(c)])
				missing += 1
	print("%d characters in the game's text, %d missing from the fonts" % [chars.size(), missing])
	quit(1 if missing > 0 else 0)


func _scan(dir: String, chars: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["gd", "json", "tscn", "tres", "cfg"]:
			var s := FileAccess.get_file_as_string(dir.path_join(f))
			for i in s.length():
				if s.unicode_at(i) >= 0x20:
					chars[s.unicode_at(i)] = true
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_scan(dir.path_join(d), chars)

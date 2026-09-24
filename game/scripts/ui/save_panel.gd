class_name SavePanel
extends RefCounted
## The save slots, shared by the pause menu (save / load) and the title screen (load).


static func make(saving: bool, on_pick: Callable, on_close: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.04, 0.05, 0.065, 0.97), UITheme.GOLD, 2))
	p.custom_minimum_size = Vector2(620, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8 if Game.compact else 12)
	p.add_child(v)
	var t := UITheme.label("セーブ" if saving else "ロード", 30, UITheme.IVORY, UITheme.title_font(), 2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for i in range(1, SaveGame.SLOTS + 1):
		var d := SaveGame.read(SaveGame.slot_path(i))
		var b := Button.new()
		b.custom_minimum_size = Vector2(580, 56 if Game.compact else 64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UITheme.body_font())
		b.add_theme_font_size_override("font_size", 18)
		if d.is_empty():
			b.text = "スロット %d　（空き）" % i
			b.disabled = not saving
		else:
			var sec := int(d["match_time"])
			b.text = "スロット %d　%s　%d:%02d\n　　　　　%s に保存" % [i, d["title"], sec / 60, sec % 60, str(d["saved_at"]).replace("T", " ")]
		b.pressed.connect(func() -> void: on_pick.call(i))
		v.add_child(b)
	var close := Button.new()
	close.text = "戻る"
	close.custom_minimum_size = Vector2(0, 46)
	close.add_theme_font_override("font", UITheme.body_font())
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(on_close)
	v.add_child(close)
	UITheme.add_corners(p)
	return p

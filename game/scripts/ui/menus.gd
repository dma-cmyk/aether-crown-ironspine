class_name Menus
extends Control
## Pause menu, settings and the end-of-match screen.

var hud: HUD
var dim: ColorRect
var pause_box: PanelContainer
var settings_box: PanelContainer
var end_box: PanelContainer
var end_title: Label
var end_sub: Label
var end_stats: Label


func setup(h: HUD) -> void:
	hud = h
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)
	pause_box = _box("PAUSED", [["再開", _resume], ["設定", _open_settings], ["最初からやり直す", _restart], ["タイトルへ戻る", _title], ["ゲームを終了", _quit]])
	settings_box = SettingsPanel.make(func(): settings_box.visible = false; pause_box.visible = true)
	add_child(settings_box)
	settings_box.visible = false
	end_box = _box("VICTORY", [["もう一度", _restart], ["タイトルへ戻る", _title]])
	var v := end_box.get_child(0) as VBoxContainer
	end_title = v.get_child(0) as Label
	end_sub = UITheme.label("", 18, UITheme.GOLD, UITheme.italic_font())
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_sub)
	v.move_child(end_sub, 1)
	end_stats = UITheme.label("", 16, UITheme.IVORY, UITheme.body_font())
	end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_stats)
	v.move_child(end_stats, 2)


func _box(title: String, buttons: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.04, 0.05, 0.065, 0.97), UITheme.GOLD, 2))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(420, 0)
	p.visible = false
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := UITheme.label(title, 34, UITheme.IVORY, UITheme.title_font(), 2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(380, 46)
		btn.add_theme_font_override("font", UITheme.body_font())
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(b[1])
		v.add_child(btn)
	UITheme.add_corners(p)
	p.resized.connect(func(): p.position = (get_viewport_rect().size - p.size) * 0.5)
	return p


func _center(p: Control) -> void:
	await get_tree().process_frame
	p.position = (size - p.size) * 0.5


func toggle_pause() -> void:
	if end_box.visible:
		return
	var show := not pause_box.visible and not settings_box.visible
	pause_box.visible = show
	settings_box.visible = false
	dim.visible = show
	get_tree().paused = show
	if show:
		_center(pause_box)


func show_end(victory: bool) -> void:
	var w := hud.world
	var p := w.player(0)
	end_title.text = "VICTORY" if victory else "DEFEAT"
	end_title.add_theme_color_override("font_color", UITheme.GOLD if victory else UITheme.RED)
	end_sub.text = "The Crown ascends. Ironspine stands." if victory else "The Ironspine has fallen silent."
	var t := int(w.match_time)
	end_stats.text = "戦闘時間 %02d:%02d\n生産 %d   損失 %d   撃破 %d\n占領した拠点 %d" % [t / 60, t % 60, p.stats["built"], p.stats["lost"], p.stats["kills"], p.stats["captured"]]
	end_box.visible = true
	dim.visible = true
	pause_box.visible = false
	_center(end_box)
	w.sfx.play_ui("objective", 0.0)


func _resume() -> void:
	toggle_pause()


func _open_settings() -> void:
	pause_box.visible = false
	settings_box.visible = true
	_center(settings_box)


func _restart() -> void:
	get_tree().paused = false
	Game.start_match()


func _title() -> void:
	get_tree().paused = false
	Game.goto_title()


func _quit() -> void:
	get_tree().quit()


class SettingsPanel:
	static func make(on_back: Callable) -> PanelContainer:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.04, 0.05, 0.065, 0.97), UITheme.GOLD, 2))
		p.set_anchors_preset(Control.PRESET_CENTER)
		p.custom_minimum_size = Vector2(520, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 12)
		p.add_child(v)
		var t := UITheme.label("SETTINGS", 30, UITheme.IVORY, UITheme.title_font(), 2)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var q := HBoxContainer.new()
		q.add_child(_lab("画質"))
		for i in 3:
			var b := Button.new()
			b.text = ["低", "中", "高"][i]
			b.toggle_mode = true
			b.button_pressed = Game.quality == i
			b.custom_minimum_size = Vector2(90, 38)
			b.add_theme_font_override("font", UITheme.body_font())
			var idx := i
			b.pressed.connect(func():
				Game.quality = idx
				Game.save_settings()
				for c in q.get_children():
					if c is Button:
						c.button_pressed = c == b)
			q.add_child(b)
		v.add_child(q)
		v.add_child(_slider("全体音量", Game.master_volume, func(x): Game.master_volume = x; Game.save_settings()))
		v.add_child(_slider("BGM", Game.music_volume, func(x): Game.music_volume = x; Game.save_settings()))
		v.add_child(_slider("効果音", Game.sfx_volume, func(x): Game.sfx_volume = x; Game.save_settings()))
		v.add_child(_check("画面端スクロール", Game.edge_scroll, func(on): Game.edge_scroll = on; Game.save_settings()))
		v.add_child(_check("FPS表示 (F3)", Game.show_fps, func(on): Game.show_fps = on; Game.save_settings()))
		var diff := HBoxContainer.new()
		diff.add_child(_lab("難易度（次の対戦から）"))
		var ob := OptionButton.new()
		for n in Game.DIFFICULTY_NAMES:
			ob.add_item(n)
		ob.selected = Game.difficulty
		ob.item_selected.connect(func(i): Game.difficulty = i; Game.save_settings())
		diff.add_child(ob)
		v.add_child(diff)
		var back := Button.new()
		back.text = "戻る"
		back.custom_minimum_size = Vector2(0, 44)
		back.add_theme_font_override("font", UITheme.body_font())
		back.pressed.connect(on_back)
		v.add_child(back)
		UITheme.add_corners(p)
		return p

	static func _lab(t: String) -> Label:
		var l := UITheme.label(t, 17, UITheme.IVORY, UITheme.body_font())
		l.custom_minimum_size = Vector2(170, 0)
		return l

	static func _slider(t: String, v0: float, cb: Callable) -> HBoxContainer:
		var h := HBoxContainer.new()
		h.add_child(_lab(t))
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = v0
		s.custom_minimum_size = Vector2(280, 24)
		s.value_changed.connect(cb)
		h.add_child(s)
		return h

	static func _check(t: String, v0: bool, cb: Callable) -> HBoxContainer:
		var h := HBoxContainer.new()
		h.add_child(_lab(t))
		var c := CheckBox.new()
		c.button_pressed = v0
		c.toggled.connect(cb)
		h.add_child(c)
		return h

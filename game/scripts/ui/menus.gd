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
var end_stats: HBoxContainer
var next_button: Button
var save_box: PanelContainer
var help_box: PanelContainer


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
	var items := [["再開", _resume], ["セーブ", _open_save.bind(true)], ["ロード", _open_save.bind(false)], ["設定", _open_settings], ["操作説明", _open_help], ["最初からやり直す", _restart], ["タイトルへ戻る", _title]]
	# a browser tab cannot quit itself; it can go fullscreen instead
	if Game.can_fullscreen():
		items.append(["全画面の切り替え", Game.toggle_fullscreen])
	elif not Game.is_web():
		items.append(["ゲームを終了", _quit])
	pause_box = _box("一時停止", items)
	settings_box = SettingsPanel.make(func(): settings_box.visible = false; pause_box.visible = true)
	add_child(settings_box)
	settings_box.visible = false
	end_box = _end_panel()


func _box(title: String, buttons: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.04, 0.05, 0.065, 0.97), UITheme.GOLD, 2))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(420, 0)
	p.visible = false
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6 if Game.compact else 12)
	p.add_child(v)
	var t := UITheme.label(title, 26 if Game.compact else 34, UITheme.IVORY, UITheme.title_font(), 2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UITheme.divider())
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(380, 40 if Game.compact else 46)
		btn.add_theme_font_override("font", UITheme.body_font())
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(b[1])
		v.add_child(btn)
	UITheme.add_corners(p)
	p.resized.connect(func(): p.position = (get_viewport_rect().size - p.size) * 0.5)
	return p


## The report after a match: the verdict, the scenario's closing line, a row of numbers and
## the ways onward.
func _end_panel() -> PanelContainer:
	var c := Game.compact
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.035, 0.042, 0.058, 0.97), UITheme.GOLD, 2))
	p.custom_minimum_size = Vector2(600 if c else 700, 0)
	p.visible = false
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6 if c else 12)
	p.add_child(v)
	end_title = UITheme.label("", 40 if c else 58, UITheme.GOLD, UITheme.title_font(), 3)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_title)
	end_sub = UITheme.label("", 16 if c else 19, UITheme.IVORY, UITheme.italic_font())
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_sub.custom_minimum_size.x = 540 if c else 640
	v.add_child(end_sub)
	v.add_child(UITheme.divider())
	end_stats = HBoxContainer.new()
	end_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	end_stats.add_theme_constant_override("separation", 8 if c else 10)
	v.add_child(end_stats)
	v.add_child(UITheme.divider())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for b: Array in [["次のミッションへ", _next], ["もう一度", _restart], ["タイトルへ戻る", _title]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(176 if c else 200, 42 if c else 46)
		btn.add_theme_font_override("font", UITheme.body_font())
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(b[1])
		row.add_child(btn)
		if b[1] == _next:
			next_button = btn
	UITheme.add_corners(p)
	p.resized.connect(func(): p.position = (get_viewport_rect().size - p.size) * 0.5)
	return p


func _stat_tile(value: String, caption: String) -> Control:
	var c := Game.compact
	var t := PanelContainer.new()
	t.add_theme_stylebox_override("panel", UITheme.panel(Color(0.02, 0.025, 0.035, 0.9), UITheme.GOLD_DIM, 1))
	t.custom_minimum_size = Vector2(100 if c else 118, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	t.add_child(v)
	var n := UITheme.label(value, 24 if c else 30, UITheme.IVORY, UITheme.title_font())
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var l := UITheme.label(caption, 12 if c else 13, UITheme.TEXT_DIM, UITheme.body_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return t


func _center(p: Control) -> void:
	await get_tree().process_frame
	p.reset_size()
	p.position = (size - p.size) * 0.5


func toggle_pause() -> void:
	if end_box.visible:
		return
	if save_box:
		_close_save()
		return
	if help_box:
		_close_help()
		return
	var show := not pause_box.visible and not settings_box.visible
	pause_box.visible = show
	settings_box.visible = false
	dim.visible = show
	get_tree().paused = show
	Game.web_audio_pause(show)
	if show:
		_center(pause_box)


func show_end(victory: bool) -> void:
	var w := hud.world
	var p := w.player(0)
	end_title.text = "勝利" if victory else "敗北"
	end_title.add_theme_color_override("font_color", UITheme.GOLD if victory else UITheme.RED)
	var scn: Scenario = hud.match_node.scenario
	end_sub.text = str(scn.data.get("victory_text" if victory else "defeat_text",
			"王冠は昇る。アイアンスパインは健在だ。" if victory else "アイアンスパインは沈黙した。"))
	next_button.visible = victory and scn.next_path() != ""
	var t := int(w.match_time)
	for ch in end_stats.get_children():
		ch.queue_free()
	for st: Array in [["%02d:%02d" % [t / 60, t % 60], "戦闘時間"], [str(p.stats["built"]), "生産"], [str(p.stats["kills"]), "撃破"],
			[str(p.stats["lost"]), "損失"], [str(p.stats["captured"]), "占領"]]:
		end_stats.add_child(_stat_tile(st[0], st[1]))
	pause_box.visible = false
	settings_box.visible = false
	# the last blow plays out in slow motion, then the report fades in over the field
	var cinematic := not Game.is_capture() and not Game.args.has("autoplay")
	if cinematic:
		Engine.time_scale = 0.3
		var slow := create_tween().set_ignore_time_scale(true)
		slow.tween_interval(0.9)
		slow.tween_property(Engine, "time_scale", 1.0, 1.2)
	end_box.visible = true
	dim.visible = true
	end_box.modulate.a = 0.0
	dim.modulate.a = 0.0
	var delay := 1.2 if cinematic else 0.0
	var tw := create_tween().set_ignore_time_scale(true).set_parallel()
	tw.tween_property(dim, "modulate:a", 1.0, 0.8).set_delay(delay)
	tw.tween_property(end_box, "modulate:a", 1.0, 0.5).set_delay(delay + 0.3)
	_center(end_box)
	w.sfx.play_ui("objective", 0.0)


func _resume() -> void:
	toggle_pause()


func _open_save(saving: bool) -> void:
	save_box = SavePanel.make(saving, _on_slot.bind(saving), _close_save)
	add_child(save_box)
	pause_box.visible = false
	_center(save_box)


func _on_slot(slot: int, saving: bool) -> void:
	if not saving:
		get_tree().paused = false
		Game.load_game(SaveGame.slot_path(slot))
		return
	var ok: bool = hud.match_node.save_game(slot)
	hud.world.raise_alert(Vector3.ZERO, ("スロット %d にセーブしました" % slot) if ok else "セーブできませんでした", Defs.TEAM_PLAYER)
	hud.world.sfx.play_ui("confirm" if ok else "error")
	_close_save()


func _close_save() -> void:
	if save_box:
		save_box.queue_free()
		save_box = null
	pause_box.visible = true
	_center(pause_box)


func _open_help() -> void:
	pause_box.visible = false
	help_box = HelpPanel.make(_close_help)
	add_child(help_box)
	_center(help_box)


func _close_help() -> void:
	if help_box:
		help_box.queue_free()
		help_box = null
	pause_box.visible = true
	_center(pause_box)


func _open_settings() -> void:
	pause_box.visible = false
	settings_box.visible = true
	_center(settings_box)


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Game.start_match()


func _next() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Game.start_match(hud.match_node.scenario.next_path())


func _title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
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
		v.add_theme_constant_override("separation", 4 if Game.compact else 12)
		p.add_child(v)
		var t := UITheme.label("設定", 24 if Game.compact else 30, UITheme.IVORY, UITheme.title_font(), 2)
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
		if not Game.compact:
			v.add_child(_check("画面端スクロール", Game.edge_scroll, func(on): Game.edge_scroll = on; Game.save_settings()))
		v.add_child(_check("FPS表示" if Game.compact else "FPS表示 (F3)", Game.show_fps, func(on): Game.show_fps = on; Game.save_settings()))
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
		back.custom_minimum_size = Vector2(0, 40 if Game.compact else 44)
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

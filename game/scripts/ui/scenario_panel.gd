class_name ScenarioPanel
extends RefCounted
## Title-screen list of built-in and player-made scenarios. Files that fail validation stay
## in the list with their errors so authors can see what to fix.


static func make(on_close: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.035, 0.045, 0.06, 0.97), UITheme.GOLD, 2))
	p.custom_minimum_size = Vector2(1000, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UITheme.label("シナリオ", 28, UITheme.IVORY, UITheme.title_font(), 2))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_fill(list)
	var note := UITheme.label("自作シナリオは「フォルダを開く」の場所に .json を置くと一覧に出ます。書き方は docs/scenarios.md を参照。",
			15, UITheme.TEXT_DIM, UITheme.body_font())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_button(row, "フォルダを開く", func() -> void: OS.shell_open(Scenario.user_dir()))
	_button(row, "再読み込み", func() -> void: _fill(list))
	_button(row, "閉じる", on_close)
	UITheme.add_corners(p)
	return p


static func _fill(list: VBoxContainer) -> void:
	for c in list.get_children():
		c.queue_free()
	for s in Scenario.list_all():
		list.add_child(_entry(s))


static func _entry(s: Scenario) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := "%s  %s" % [s.title(), "" if s.is_builtin() else "（自作）"]
	if s.data.get("subtitle", "") != "":
		head += "  — " + str(s.data["subtitle"])
	var b := Button.new()
	b.text = head if s.is_valid() else "%s（読み込めません）" % s.path.get_file()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_override("font", UITheme.body_font())
	b.add_theme_font_size_override("font_size", 20)
	b.disabled = not s.is_valid()
	b.pressed.connect(func() -> void: Game.start_match(s.path))
	box.add_child(b)
	var text := str(s.data.get("description", "")) if s.is_valid() else "\n".join(s.errors.slice(0, 6))
	if s.errors.size() > 6:
		text += "\n…ほか %d 件" % (s.errors.size() - 6)
	if text != "":
		var desc := UITheme.label(text, 15, UITheme.TEXT_DIM if s.is_valid() else Color(0.95, 0.5, 0.4), UITheme.body_font())
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(940, 0)
		box.add_child(desc)
	return box


static func _button(row: HBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", UITheme.body_font())
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	row.add_child(b)

class_name HUD
extends Control
## In-match interface modelled on a classic RTS layout. Phones get a compact version of it
## (Game.compact): smaller panels, no title or advisor, and buttons sized for fingers.

const CMD_ORDER := ["move", "hold", "attack", "patrol", "fortify", "repair", "deploy", "special"]
const PROD_KEYS := ["Q", "W", "E", "R", "T", "Y", "U"]

var world: World
var commander: Commander
var camera: CameraRig
var match_node: Node

var res_labels := {}
var rate_labels := {}
var obj_title: Label
var obj_sub: Label
var obj_list: VBoxContainer
var alert_box: VBoxContainer
var banner: Label
var banner_sub: Label
var _banner_t := 0.0
var mode_hint: Label
var fps_label: Label
var clock_label: Label
var minimap: Minimap
var studio: PortraitStudio
var portrait: TextureRect
var sel_name: Label
var sel_desc: Label
var sel_hp: ProgressBar
var sel_hp_text: Label
var sel_status: Label
var sel_members: HBoxContainer
var sel_grid: GridContainer
var sel_queue: HBoxContainer
var sel_prod_bar: ProgressBar
var sel_group: Label
var sel_info_box: VBoxContainer
var cmd_buttons: Array[Button] = []
var cmd_grid: GridContainer
var tooltip: PanelContainer
var tip_title: Label
var tip_cost: Label
var tip_body: Label
var advisor_img: TextureRect
var advisor_text: Label
var menus: Menus
var build_mode := false
## Inside the build menu: the page of beast shrines.
var shrine_page := false
var compact := false
var cancel_button: Button
var deselect_button: Button
var obj_collapsed := false
var _tip_t := 0.0
var _last_alert_pos := Vector3.INF
var _sel_sig := ""
var _card_ids: Array[String] = []


func setup(w: World, c: Commander, cam: CameraRig, m: Node) -> void:
	world = w
	commander = c
	camera = cam
	match_node = m
	theme = UITheme.theme()
	compact = Game.compact
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(SelectionBox.new(commander))
	_build_title()
	if compact:
		_build_resources_compact()
	else:
		_build_resources()
	_build_labels()
	_build_objectives()
	_build_alerts()
	_build_minimap()
	_build_selection()
	_build_commands()
	if not compact:
		_build_advisor()
	_build_tooltip()
	menus = Menus.new()
	menus.name = "Menus"
	add_child(menus)
	menus.setup(self)
	world.alert.connect(_on_alert)
	commander.selection_changed.connect(_refresh_selection)
	commander.mode_changed.connect(_on_mode)
	world.game_ended.connect(_on_game_end)
	_refresh_selection()


# ---------------------------------------------------------------- layout helpers
func _panel(rect_pos: Vector2, rect_size: Vector2, anchor: int, bg: Color = UITheme.PANEL_BG) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UITheme.panel(bg, UITheme.GOLD_DIM, 2))
	p.set_anchors_preset(anchor)
	p.size = rect_size
	p.position = rect_pos
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	return p


func _place(c: Control, anchor: int, off: Vector2, sz: Vector2) -> void:
	c.set_anchors_preset(anchor)
	match anchor:
		PRESET_TOP_LEFT:
			c.offset_left = off.x
			c.offset_top = off.y
			c.offset_right = off.x + sz.x
			c.offset_bottom = off.y + sz.y
		PRESET_TOP_RIGHT:
			c.offset_left = -off.x - sz.x
			c.offset_top = off.y
			c.offset_right = -off.x
			c.offset_bottom = off.y + sz.y
		PRESET_BOTTOM_LEFT:
			c.offset_left = off.x
			c.offset_top = -off.y - sz.y
			c.offset_right = off.x + sz.x
			c.offset_bottom = -off.y
		PRESET_BOTTOM_RIGHT:
			c.offset_left = -off.x - sz.x
			c.offset_top = -off.y - sz.y
			c.offset_right = -off.x
			c.offset_bottom = -off.y
		PRESET_CENTER_TOP:
			c.offset_left = -sz.x * 0.5 + off.x
			c.offset_top = off.y
			c.offset_right = sz.x * 0.5 + off.x
			c.offset_bottom = off.y + sz.y
		PRESET_CENTER_BOTTOM:
			c.offset_left = -sz.x * 0.5 + off.x
			c.offset_top = -off.y - sz.y
			c.offset_right = sz.x * 0.5 + off.x
			c.offset_bottom = -off.y


func _framed(anchor: int, off: Vector2, sz: Vector2, corners: bool = true) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UITheme.panel())
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	_place(p, anchor, off, sz)
	if corners:
		UITheme.add_corners(p)
	return p


# ---------------------------------------------------------------- top
func _build_title() -> void:
	clock_label = UITheme.label("00:00", 14 if compact else 15, UITheme.GOLD, UITheme.title_font(), 3)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(clock_label)
	_place(clock_label, PRESET_CENTER_TOP, Vector2(0, 8 if compact else 70), Vector2(120, 22))
	if compact:
		return
	var p := _framed(PRESET_TOP_LEFT, Vector2(10, 8), Vector2(440, 78))
	var sb := UITheme.panel(Color(0.035, 0.04, 0.055, 0.86), UITheme.GOLD_DIM, 2)
	p.add_theme_stylebox_override("panel", sb)
	var crest := TextureRect.new()
	crest.texture = UITheme.icon("crest")
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.position = Vector2(10, 6)
	crest.size = Vector2(64, 64)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(crest)
	var t := UITheme.label("AETHER CROWN", 32, UITheme.IVORY, UITheme.title_font(), 2)
	t.position = Vector2(84, 6)
	p.add_child(t)
	var s := UITheme.label("INDUSTRY.  FAITH.  A HIGHER TOMORROW.", 12, UITheme.TEXT_DIM, UITheme.title_font())
	s.position = Vector2(88, 48)
	p.add_child(s)


func _build_resources() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	_place(bar, PRESET_CENTER_TOP, Vector2(0, 8), Vector2(720, 60))
	for key in ["material", "aether", "pop"]:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(236, 60)
		p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.035, 0.04, 0.055, 0.88), UITheme.GOLD_DIM, 2))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.add_child(p)
		UITheme.add_corners(p, UITheme.GOLD_DIM, 9.0)
		var ic := TextureRect.new()
		ic.texture = UITheme.icon("res_" + key)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(10, 9)
		ic.size = Vector2(42, 42)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
		var nm := UITheme.label({"material": "資材", "aether": "エーテル", "pop": "人口"}[key], 13, UITheme.TEXT_DIM, UITheme.serif_font())
		nm.position = Vector2(60, 5)
		p.add_child(nm)
		var val := UITheme.label("0", 24, UITheme.IVORY, UITheme.title_font())
		val.position = Vector2(60, 22)
		p.add_child(val)
		res_labels[key] = val
		var rate := UITheme.label("", 15, UITheme.GREEN, UITheme.bold_font())
		rate.position = Vector2(150, 30)
		p.add_child(rate)
		rate_labels[key] = rate
		p.tooltip_text = RES_TIPS[key]


const RES_TIPS := {"material": "資材：生産と建設に使う。本拠地・工業都市から毎分得られる。",
		"aether": "エーテル：高度なユニットと施設に使う。精製所・エーテル都市から得られる。",
		"pop": "人口：ユニットの維持上限。本拠地・居住区・占領した都市で増える。"}


## Phones: one small strip in the top-left corner, numbers only.
func _build_resources_compact() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	add_child(bar)
	_place(bar, PRESET_TOP_LEFT, Vector2(8, 6), Vector2(380, 38))
	for key in ["material", "aether", "pop"]:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(124, 38)
		p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.035, 0.04, 0.055, 0.88), UITheme.GOLD_DIM, 1))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.tooltip_text = RES_TIPS[key]
		bar.add_child(p)
		var ic := TextureRect.new()
		ic.texture = UITheme.icon("res_" + key)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(5, 6)
		ic.size = Vector2(26, 26)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
		var val := UITheme.label("0", 17, UITheme.IVORY, UITheme.title_font())
		val.position = Vector2(37, 0)
		p.add_child(val)
		res_labels[key] = val
		var rate := UITheme.label("", 11, UITheme.GREEN, UITheme.bold_font())
		rate.position = Vector2(38, 21)
		p.add_child(rate)
		rate_labels[key] = rate


func _build_labels() -> void:
	mode_hint = UITheme.label("", 15 if compact else 18, UITheme.GOLD, UITheme.serif_font(), 3)
	mode_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(mode_hint)
	_place(mode_hint, PRESET_CENTER_TOP, Vector2(0, 38 if compact else 96), Vector2(400 if compact else 700, 28))
	if compact:
		cancel_button = Button.new()
		cancel_button.text = "取消"
		cancel_button.focus_mode = Control.FOCUS_NONE
		cancel_button.add_theme_font_override("font", UITheme.body_font())
		cancel_button.visible = false
		cancel_button.pressed.connect(commander.cancel_mode)
		add_child(cancel_button)
		_place(cancel_button, PRESET_CENTER_TOP, Vector2(0, 68), Vector2(120, 40))
	banner = UITheme.label("", 28 if compact else 44, UITheme.IVORY, UITheme.title_font(), 6)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(banner)
	_place(banner, PRESET_CENTER_TOP, Vector2(0, 112 if compact else 170), Vector2(900 if compact else 1200, 60))
	banner_sub = UITheme.label("", 15 if compact else 20, UITheme.GOLD, UITheme.italic_font(), 4)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(banner_sub)
	_place(banner_sub, PRESET_CENTER_TOP, Vector2(0, 150 if compact else 228), Vector2(800 if compact else 1200, 32))
	fps_label = UITheme.label("", 13, UITheme.TEXT_DIM)
	add_child(fps_label)
	_place(fps_label, PRESET_TOP_LEFT, Vector2(10, 48) if compact else Vector2(14, 92), Vector2(200, 20))


func _icon_button(icon_name: String, tip: String, sz: Vector2) -> Button:
	var b := Button.new()
	b.icon = UITheme.icon(icon_name)
	b.expand_icon = true
	b.custom_minimum_size = sz
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	return b


func _build_objectives() -> void:
	var w := 270.0 if compact else 380.0
	var p := _framed(PRESET_TOP_RIGHT, Vector2(52, 6) if compact else Vector2(60, 8), Vector2(w, 150), not compact)
	p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.035, 0.04, 0.055, 0.86), UITheme.GOLD_DIM, 2))
	var v := VBoxContainer.new()
	v.position = Vector2(12, 6) if compact else Vector2(16, 8)
	v.size = Vector2(w - 24, 100) if compact else Vector2(350, 134)
	v.add_theme_constant_override("separation", 2 if compact else 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	obj_title = UITheme.label("", 14 if compact else 21, UITheme.IVORY, UITheme.title_font())
	v.add_child(obj_title)
	obj_sub = UITheme.label("", 11 if compact else 13, UITheme.TEXT_DIM, UITheme.italic_font())
	v.add_child(obj_sub)
	obj_list = VBoxContainer.new()
	obj_list.add_theme_constant_override("separation", 2 if compact else 3)
	v.add_child(obj_list)
	if compact:
		# the list covers a lot of a phone screen: a tap folds it down to the title
		p.tooltip_text = "タップで目標を折りたたむ／広げる"
		p.gui_input.connect(func(ev: InputEvent) -> void:
			var mb := ev as InputEventMouseButton
			if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				obj_collapsed = not obj_collapsed
				obj_sub.visible = not obj_collapsed
				obj_list.visible = not obj_collapsed
				_fit_objectives())
	var gear := _icon_button("gear", "メニュー (Esc)", Vector2(40, 40) if compact else Vector2(44, 44))
	gear.focus_mode = Control.FOCUS_ALL
	add_child(gear)
	_place(gear, PRESET_TOP_RIGHT, Vector2(6, 6) if compact else Vector2(10, 10), gear.custom_minimum_size)
	gear.pressed.connect(toggle_pause)


func set_objectives(title: String, sub: String, items: Array) -> void:
	obj_title.text = title.to_upper()
	obj_sub.text = sub
	for c in obj_list.get_children():
		c.queue_free()
	for it in items:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var ic := TextureRect.new()
		var st: String = it.get("state", "open")
		ic.texture = UITheme.icon({"done": "check_on", "failed": "check_fail"}.get(st, "check_off"))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(17, 17)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(ic)
		var col := UITheme.IVORY if st == "open" else (UITheme.TEXT_DIM if st == "done" else UITheme.RED)
		var l := UITheme.label(str(it["text"]), 12 if compact else 14, col, UITheme.serif_font())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(220 if compact else 318, 0)
		h.add_child(l)
		obj_list.add_child(h)
	_fit_objectives()


func _fit_objectives() -> void:
	var v := obj_list.get_parent() as Control
	var parent := v.get_parent() as Panel
	await get_tree().process_frame
	if is_instance_valid(parent):
		var pad := 12.0 if compact else 16.0
		parent.offset_bottom = parent.offset_top + maxf(v.get_combined_minimum_size().y + pad, 34.0 if compact else 100.0)


func _build_alerts() -> void:
	alert_box = VBoxContainer.new()
	alert_box.add_theme_constant_override("separation", 4)
	alert_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(alert_box)
	_place(alert_box, PRESET_TOP_LEFT, Vector2(10, 50) if compact else Vector2(16, 130), Vector2(290, 150) if compact else Vector2(520, 260))


func _on_alert(pos: Vector3, text: String, team: int) -> void:
	if team != Defs.TEAM_PLAYER:
		return
	var l := UITheme.label(text, 13 if compact else 17, UITheme.IVORY, UITheme.serif_font(), 3)
	if compact:
		# stay clear of the mode hint in the middle of the top edge
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 290
	l.set_meta("t", 6.0)
	alert_box.add_child(l)
	while alert_box.get_child_count() > (4 if compact else 6):
		alert_box.get_child(0).queue_free()
		alert_box.remove_child(alert_box.get_child(0))
	if pos != Vector3.ZERO:
		_last_alert_pos = pos
	world.sfx.play_ui("alert", -10.0)


func show_banner(title: String, sub: String = "", duration: float = 5.0) -> void:
	banner.text = title
	banner_sub.text = sub
	_banner_t = duration


# ---------------------------------------------------------------- bottom
func _build_minimap() -> void:
	var side_len := 170.0 if compact else 270.0
	var frame := _framed(PRESET_BOTTOM_LEFT, Vector2(6, 6) if compact else Vector2(10, 10), Vector2(side_len, side_len), not compact)
	frame.add_theme_stylebox_override("panel", UITheme.panel(Color(0.02, 0.025, 0.035, 0.95), UITheme.GOLD_DIM, 2))
	minimap = Minimap.new()
	minimap.position = Vector2(6, 6) if compact else Vector2(8, 8)
	minimap.size = Vector2(158, 158) if compact else Vector2(254, 254)
	frame.add_child(minimap)
	minimap.setup(world, commander, camera)
	minimap.clip_contents = true
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4 if compact else 8)
	add_child(side)
	_place(side, PRESET_BOTTOM_LEFT, Vector2(182, 6) if compact else Vector2(288, 14), Vector2(40, 172) if compact else Vector2(44, 200))
	var defs := [["idle", "待機中の工兵を選択 (F1)", _select_idle], ["army", "全戦闘部隊を選択 (F2)", _select_army],
			["flag", "目標地点へ移動", _goto_objective], ["alert", "最新の警報地点へ移動 (Space)", _goto_alert]]
	for d in defs:
		var b := _icon_button(d[0], d[1], Vector2(40, 40) if compact else Vector2(44, 44))
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(d[2])
		side.add_child(b)


func _build_selection() -> void:
	var c := compact
	var p := _framed(PRESET_CENTER_BOTTOM, Vector2(0, 6) if c else Vector2(-40, 10), Vector2(390, 130) if c else Vector2(780, 178), not c)
	p.clip_contents = c
	studio = PortraitStudio.new()
	add_child(studio)
	var pf := Panel.new()
	pf.add_theme_stylebox_override("panel", UITheme.panel(Color(0.02, 0.025, 0.03, 1.0), UITheme.GOLD, 2))
	pf.position = Vector2(8, 8) if c else Vector2(12, 12)
	pf.size = Vector2(114, 114) if c else Vector2(154, 154)
	pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(pf)
	portrait = TextureRect.new()
	portrait.texture = studio.get_texture()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.position = Vector2(3, 3)
	portrait.size = pf.size - Vector2(6, 6)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pf.add_child(portrait)
	sel_info_box = VBoxContainer.new()
	sel_info_box.position = Vector2(130, 6) if c else Vector2(180, 10)
	sel_info_box.size = Vector2(250, 118) if c else Vector2(585, 160)
	sel_info_box.add_theme_constant_override("separation", 2 if c else 4)
	sel_info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(sel_info_box)
	var top := HBoxContainer.new()
	sel_info_box.add_child(top)
	sel_name = UITheme.label("", 16 if c else 22, UITheme.IVORY, UITheme.title_font())
	sel_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_name.clip_text = c
	top.add_child(sel_name)
	sel_group = UITheme.label("", 12 if c else 15, UITheme.GOLD, UITheme.title_font())
	top.add_child(sel_group)
	sel_desc = UITheme.label("", 11 if c else 14, UITheme.TEXT_DIM, UITheme.italic_font())
	sel_desc.clip_text = c
	sel_desc.custom_minimum_size.x = 250 if c else 0
	sel_info_box.add_child(sel_desc)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	sel_info_box.add_child(hp_row)
	sel_hp = _bar(Color(0.36, 0.86, 0.42))
	sel_hp.custom_minimum_size = Vector2(150, 10) if c else Vector2(300, 14)
	hp_row.add_child(sel_hp)
	sel_hp_text = UITheme.label("", 12 if c else 14, UITheme.IVORY, UITheme.title_font())
	hp_row.add_child(sel_hp_text)
	sel_members = HBoxContainer.new()
	sel_members.add_theme_constant_override("separation", 3 if c else 6)
	sel_info_box.add_child(sel_members)
	sel_queue = HBoxContainer.new()
	sel_queue.add_theme_constant_override("separation", 4 if c else 6)
	sel_info_box.add_child(sel_queue)
	sel_prod_bar = _bar(UITheme.AETHER)
	sel_prod_bar.custom_minimum_size = Vector2(150, 6) if c else Vector2(300, 8)
	sel_info_box.add_child(sel_prod_bar)
	sel_status = UITheme.label("", 11 if c else 14, UITheme.AETHER, UITheme.body_font())
	sel_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_status.custom_minimum_size = Vector2(250 if c else 560, 0)
	sel_info_box.add_child(sel_status)
	sel_grid = GridContainer.new()
	sel_grid.columns = 8 if c else 15
	sel_grid.position = Vector2(10, 8) if c else Vector2(16, 16)
	sel_grid.add_theme_constant_override("h_separation", 4)
	sel_grid.add_theme_constant_override("v_separation", 4)
	p.add_child(sel_grid)
	if c:
		# no empty ground to tap while units wait for orders: clear the selection here
		deselect_button = _icon_button("cancel", "選択を解除", Vector2(40, 40))
		deselect_button.visible = false
		deselect_button.pressed.connect(func() -> void: commander.set_selection([]))
		add_child(deselect_button)
		_place(deselect_button, PRESET_CENTER_BOTTOM, Vector2(175, 140), Vector2(40, 40))


func _bar(c: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0
	b.max_value = 1
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.08, 0.09)
	bg.border_color = Color(0, 0, 0)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = c
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


const CMD_BUTTON := Vector2(83, 74)
const CMD_BUTTON_COMPACT := Vector2(62, 52)


func _build_commands() -> void:
	var c := compact
	var bs := CMD_BUTTON_COMPACT if c else CMD_BUTTON
	var p := _framed(PRESET_BOTTOM_RIGHT, Vector2(6, 6) if c else Vector2(250, 10), Vector2(283, 130) if c else Vector2(372, 178), not c)
	cmd_grid = GridContainer.new()
	cmd_grid.columns = 4
	cmd_grid.position = Vector2(10, 10) if c else Vector2(12, 12)
	cmd_grid.add_theme_constant_override("h_separation", 5 if c else 6)
	cmd_grid.add_theme_constant_override("v_separation", 5 if c else 6)
	p.add_child(cmd_grid)
	for i in 8:
		var b := Button.new()
		b.custom_minimum_size = bs
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(17, 4) if c else Vector2(21, 6)
		ic.size = Vector2(28, 28) if c else Vector2(40, 40)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.name = "Icon"
		b.add_child(ic)
		var lab := UITheme.label("", 10 if c else 13, UITheme.IVORY, UITheme.bold_font())
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.position = Vector2(0, 33) if c else Vector2(0, 49)
		lab.size = Vector2(bs.x, 15 if c else 20)
		lab.clip_text = true
		lab.name = "Label"
		b.add_child(lab)
		var key := UITheme.label("", 10, UITheme.GOLD, UITheme.bold_font())
		key.position = Vector2(bs.x - 22 if c else 66, 1 if c else 2)
		key.name = "Key"
		b.add_child(key)
		var cd := ColorRect.new()
		cd.color = Color(0, 0, 0, 0.6)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd.name = "Cooldown"
		cd.position = Vector2(2, 2)
		cd.size = Vector2(bs.x - 4, 0)
		b.add_child(cd)
		var idx := i
		b.pressed.connect(func(): _on_cmd(idx))
		b.mouse_entered.connect(func(): if not Game.touch_input: _show_tip(idx))
		b.mouse_exited.connect(func(): if not Game.touch_input: tooltip.visible = false)
		cmd_grid.add_child(b)
		cmd_buttons.append(b)


func _build_advisor() -> void:
	var p := _framed(PRESET_BOTTOM_RIGHT, Vector2(10, 10), Vector2(232, 178))
	var shot := PortraitStudio.new()
	shot.size = Vector2i(224, 150)
	add_child(shot)
	shot.show_entity("building", "citadel", Defs.TEAM_PLAYER)
	shot.spin = false
	advisor_img = TextureRect.new()
	advisor_img.texture = shot.get_texture()
	advisor_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	advisor_img.position = Vector2(4, 4)
	advisor_img.size = Vector2(224, 170)
	advisor_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	advisor_img.modulate = Color(0.85, 0.85, 0.9)
	advisor_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(advisor_img)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.position = Vector2(4, 96)
	shade.size = Vector2(224, 78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(shade)
	advisor_text = UITheme.label("規律が\n世界を築く。", 16, UITheme.IVORY, UITheme.title_font(), 3)
	advisor_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	advisor_text.position = Vector2(10, 110)
	advisor_text.size = Vector2(208, 60)
	p.add_child(advisor_text)
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(shot):
		shot.render_target_update_mode = SubViewport.UPDATE_ONCE


func set_advisor(text: String) -> void:
	if advisor_text:
		advisor_text.text = text


func _build_tooltip() -> void:
	tooltip = PanelContainer.new()
	tooltip.add_theme_stylebox_override("panel", UITheme.panel(Color(0.03, 0.035, 0.05, 0.97), UITheme.GOLD, 1))
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.visible = false
	tooltip.z_index = 50
	add_child(tooltip)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(270 if compact else 330, 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(v)
	tip_title = UITheme.label("", 15 if compact else 18, UITheme.IVORY, UITheme.title_font())
	v.add_child(tip_title)
	tip_cost = UITheme.label("", 12 if compact else 14, UITheme.GOLD, UITheme.bold_font())
	v.add_child(tip_cost)
	tip_body = UITheme.label("", 12 if compact else 14, UITheme.TEXT_DIM, UITheme.body_font())
	tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_body.custom_minimum_size = Vector2(260 if compact else 320, 0)
	v.add_child(tip_body)


# ---------------------------------------------------------------- command card
func citadel_build_mode() -> bool:
	return build_mode


func _card_entries() -> Array[String]:
	## Returns ids for the 8 slots: "cmd:x", "unit:x", "bld:x", "toggle:build", "toggle:back" or "".
	var out: Array[String] = []
	var units := commander.own_units()
	var b := commander.selected_building()
	if not units.is_empty():
		for c in CMD_ORDER:
			out.append("cmd:" + c)
		return out
	if b:
		if b.def_id == "citadel" and build_mode:
			for id in (Defs.SHRINES if shrine_page else Defs.BUILD_ORDER):
				out.append("bld:" + id)
			while out.size() < 6:
				out.append("")
			if out.size() < 7:
				out.append("" if shrine_page else "toggle:shrines")
			out.append("toggle:shrines_back" if shrine_page else "toggle:back")
			return out
		for id in b.produces():
			out.append("unit:" + id)
		while out.size() < 7:
			out.append("")
		out.append("toggle:build" if b.def_id == "citadel" else "")
		return out
	for i in 8:
		out.append("")
	return out


func _on_cmd(i: int) -> void:
	if i >= _card_ids.size():
		return
	if Game.touch_input:
		# no hover on a phone: say what the button does for a moment after it is pressed
		_tip_t = 2.5
		_show_tip(i)
	var id := _card_ids[i]
	if id == "":
		return
	var kind := id.get_slice(":", 0)
	var v := id.get_slice(":", 1)
	match kind:
		"cmd":
			commander.command(v)
		"unit":
			var b := commander.selected_building()
			if b:
				if Input.is_key_pressed(KEY_SHIFT) and not Game.touch_input:
					for k in 5:
						commander.queue(b, v)
				else:
					commander.queue(b, v)
		"bld":
			commander.begin_place(v)
		"toggle":
			match v:
				"build", "shrines_back":
					build_mode = true
					shrine_page = false
				"shrines":
					shrine_page = true
				_:
					build_mode = false
					shrine_page = false
			world.sfx.play_ui("click")
			_sel_sig = ""


## Build menu hotkeys (Q W E R T Y U) while the citadel is selected.
func build_key(i: int) -> void:
	var ids: Array = Defs.SHRINES if shrine_page else Defs.BUILD_ORDER
	if i < ids.size():
		commander.begin_place(ids[i])
	elif not shrine_page and i == 6:
		shrine_page = true
		_sel_sig = ""


func _show_tip(i: int) -> void:
	if i >= _card_ids.size() or _card_ids[i] == "":
		tooltip.visible = false
		return
	var id := _card_ids[i]
	var kind := id.get_slice(":", 0)
	var v := id.get_slice(":", 1)
	var touch := Game.touch_input
	tip_cost.text = ""
	match kind:
		"cmd":
			var c: Dictionary = Defs.COMMANDS[v]
			tip_title.text = c["label"] if touch else "%s  [%s]" % [c["label"], c["key"]]
			tip_body.text = c["jp"]
			if v == "special":
				for u in commander.own_units():
					var sid: String = u.def.get("special", "")
					if sid != "":
						tip_title.text = Defs.special_name(sid) + ("" if touch else "  [S]")
						tip_body.text = Defs.SPECIALS[sid]["jp"] + "\n再使用 %d秒" % int(Defs.SPECIALS[sid]["cooldown"])
						break
		"unit":
			var d: Dictionary = Defs.UNITS[v]
			tip_title.text = Defs.unit_name(v, 0) if touch else "%s  [%s]" % [Defs.unit_name(v, 0), PROD_KEYS[i]]
			tip_cost.text = _cost_text(d["cost"]) + "   人口 %d   %d秒" % [d["pop"], int(d["build_time"])]
			tip_body.text = d["jp"] + ("" if touch else "\nShift+クリックで5体まとめて生産")
		"bld":
			var bd: Dictionary = Defs.BUILDINGS[v]
			tip_title.text = Defs.building_name(v, 0) if touch else "%s  [%s]" % [Defs.building_name(v, 0), PROD_KEYS[i]]
			tip_cost.text = _cost_text(bd["cost"]) + "   建設 %d秒" % int(bd["build_time"])
			tip_body.text = bd["jp"] + "\n本拠地・自軍の都市の近くに建設できる" + ("" if touch else "（Shiftで連続配置）")
		"toggle":
			tip_title.text = {"build": "建設", "shrines": "祠"}.get(v, "戻る")
			tip_body.text = {"build": "建設メニューを開く", "shrines": "神獣の祠を選ぶ（祠ごとに呼べる神獣が違う）",
					"shrines_back": "建設メニューに戻る"}.get(v, "生産メニューに戻る")
	tooltip.visible = true
	tooltip.reset_size()
	await get_tree().process_frame
	var b := cmd_buttons[i]
	var at := b.global_position + Vector2(-tooltip.size.x + 80, -tooltip.size.y - 10)
	if compact:
		# above the whole card, so it never covers the next button a finger goes for
		var card := cmd_grid.get_parent() as Control
		at = Vector2(card.global_position.x + card.size.x - tooltip.size.x, card.global_position.y - tooltip.size.y - 6)
	tooltip.global_position = at.clamp(Vector2(4, 4), get_viewport_rect().size - tooltip.size - Vector2(4, 4))


func _cost_text(c: Dictionary) -> String:
	var s := "資材 %d" % int(c.get("material", 0))
	if int(c.get("aether", 0)) > 0:
		s += "  エーテル %d" % int(c.get("aether", 0))
	return s


func _update_commands() -> void:
	var ids := _card_entries()
	_card_ids = ids
	var units := commander.own_units()
	var b := commander.selected_building()
	var p := world.player(Defs.TEAM_PLAYER)
	for i in 8:
		var btn := cmd_buttons[i]
		var id := ids[i]
		var ic: TextureRect = btn.get_node("Icon")
		var lab: Label = btn.get_node("Label")
		var key: Label = btn.get_node("Key")
		var cd: ColorRect = btn.get_node("Cooldown")
		cd.size.y = 0
		if id == "":
			btn.disabled = true
			ic.texture = null
			lab.text = ""
			key.text = ""
			btn.modulate = Color(1, 1, 1, 0.55)
			continue
		btn.modulate = Color.WHITE
		var kind := id.get_slice(":", 0)
		var v := id.get_slice(":", 1)
		match kind:
			"cmd":
				ic.texture = UITheme.icon("cmd_" + v)
				lab.text = Defs.COMMANDS[v]["label"]
				key.text = "" if compact else Defs.COMMANDS[v]["key"]
				var avail := commander.command_available(v)
				btn.disabled = not avail
				if v == "special" and avail:
					var best := 1.0
					for u in units:
						var sid: String = u.def.get("special", "")
						if sid != "":
							best = minf(best, u.special_cd / float(Defs.SPECIALS[sid]["cooldown"]))
					cd.size.y = (btn.size.y - 4.0) * best
				var active := false
				for u in units:
					if (v == "fortify" and (u.fortified or u.setup_goal == "fortify")) or (v == "deploy" and (u.deployed or u.setup_goal == "deploy")) or (v == "hold" and u.order == Unit.Order.HOLD):
						active = true
				lab.add_theme_color_override("font_color", UITheme.AETHER if active else UITheme.IVORY)
			"unit":
				ic.texture = UITheme.icon("unit_" + v)
				lab.text = Defs.unit_short(v)
				key.text = "" if compact else PROD_KEYS[i]
				btn.disabled = b == null or b.can_queue(v) != ""
				lab.add_theme_color_override("font_color", UITheme.IVORY)
				var n := b.production.count(v) if b else 0
				if n > 0:
					key.text = ("x%d" % n) if compact else "%s x%d" % [PROD_KEYS[i], n]
			"bld":
				ic.texture = UITheme.icon(Defs.building_icon(v))
				lab.text = Defs.building_short(v)
				key.text = "" if compact else PROD_KEYS[i]
				btn.disabled = not p.can_afford(Defs.BUILDINGS[v]["cost"])
				lab.add_theme_color_override("font_color", UITheme.IVORY)
			"toggle":
				ic.texture = UITheme.icon({"build": "construct", "shrines": "bld_sanctum"}.get(v, "cancel"))
				lab.text = {"build": "建設", "shrines": "祠"}.get(v, "戻る")
				key.text = "" if compact else {"build": "B", "shrines": "U"}.get(v, "")
				btn.disabled = false
				lab.add_theme_color_override("font_color", UITheme.GOLD)


# ---------------------------------------------------------------- selection panel
func _refresh_selection() -> void:
	_sel_sig = ""
	build_mode = false
	shrine_page = false


func _selection_signature() -> String:
	var s := str(commander.selection.size())
	for e in commander.selection:
		s += "|" + str(e.get_instance_id())
	return s


func _update_selection() -> void:
	var sel := commander.selection.filter(func(e): return is_instance_valid(e) and e.alive)
	var sig := _selection_signature() + str(build_mode) + str(shrine_page)
	var rebuild := sig != _sel_sig
	_sel_sig = sig
	sel_grid.visible = sel.size() > 1
	sel_info_box.visible = sel.size() <= 1
	portrait.get_parent().visible = sel.size() <= 1
	if sel.is_empty():
		studio.show_entity("building", "citadel", Defs.TEAM_PLAYER)
		sel_name.text = "司令部"
		sel_group.text = ""
		sel_desc.text = "タップで選択・命令、長押しで範囲選択。" if Game.touch_input else "左ドラッグで範囲選択、右クリックで移動・攻撃。"
		sel_hp.visible = false
		sel_hp_text.text = ""
		_clear(sel_members)
		_clear(sel_queue)
		sel_prod_bar.visible = false
		var p := world.player(0)
		sel_status.text = "収入  資材 +%d/分   エーテル +%d/分\n拠点 %d / %d を支配中" % [int(p.income_material), int(p.income_aether),
				world.sites.filter(func(s): return s.owner_team == 0).size(), world.sites.size()]
		return
	if sel.size() > 1:
		if rebuild:
			_clear(sel_grid)
			for e in sel.slice(0, 16 if compact else 24):
				sel_grid.add_child(_unit_card(e))
		var i := 0
		for c in sel_grid.get_children():
			if i < sel.size():
				(c.get_node("HP") as ProgressBar).value = sel[i].hp_ratio()
			i += 1
		return
	var e: Entity = sel[0]
	sel_hp.visible = true
	sel_hp.value = e.hp_ratio()
	sel_hp_text.text = "%d / %d" % [int(ceil(e.hp)), int(e.max_hp)]
	var hp_fill := sel_hp.get_theme_stylebox("fill") as StyleBoxFlat
	hp_fill.bg_color = Color(0.36, 0.86, 0.42) if e.team == Defs.TEAM_PLAYER else Defs.team_color(e.team)
	sel_name.text = e.display_name()
	sel_desc.text = e.description()
	sel_group.text = _group_label(e)
	if e is Unit:
		var u := e as Unit
		studio.show_entity("unit", u.def_id, u.team)
		sel_prod_bar.visible = false
		_clear(sel_queue)
		if u.type == "squad":
			if rebuild or sel_members.get_child_count() != int(u.def["members"]):
				_clear(sel_members)
				for k in int(u.def["members"]):
					sel_members.add_child(_member_cell(u))
			var mh: float = u.def["member_hp"]
			var k2 := 0
			for c in sel_members.get_children():
				var fill := clampf((u.hp - k2 * mh) / mh, 0.0, 1.0)
				(c.get_node("HP") as ProgressBar).value = fill
				c.modulate = Color.WHITE if fill > 0.0 else Color(0.4, 0.4, 0.4, 0.6)
				k2 += 1
		else:
			_clear(sel_members)
		sel_status.text = _unit_status(u)
	else:
		var b := e as Building
		studio.show_entity("building", b.def_id, b.team)
		_clear(sel_members)
		if rebuild or sel_queue.get_child_count() != b.production.size():
			_clear(sel_queue)
			for k in b.production.size():
				var btn := _icon_button("unit_" + b.production[k], "クリックで取消", Vector2(30, 30) if compact else Vector2(40, 40))
				btn.focus_mode = Control.FOCUS_ALL
				btn.pressed.connect(func(): b.cancel_last())
				sel_queue.add_child(btn)
		sel_prod_bar.visible = b.team == Defs.TEAM_PLAYER and (not b.production.is_empty() or not b.built)
		sel_prod_bar.value = b.production_progress() if b.built else b.progress
		var st := ""
		if not b.built:
			st = "建設中 %d%%" % int(b.progress * 100)
		elif b.team == Defs.TEAM_PLAYER and not b.produces().is_empty():
			var rally := "地面をタップで集結地点を指定" if Game.touch_input else "右クリックで集結地点を指定"
			st = rally if b.production.is_empty() else "生産中: %s" % Defs.unit_name(b.production[0], 0)
		var inc: Dictionary = b.def.get("income", {})
		if not inc.is_empty():
			st += "\n収入 資材 +%d/分  エーテル +%d/分" % [int(inc.get("material", 0)), int(inc.get("aether", 0))]
		if int(b.def.get("pop", 0)) > 0:
			st += "\n人口上限 +%d" % int(b.def["pop"])
		sel_status.text = st


func _group_label(e: Entity) -> String:
	for k in commander.groups:
		if e in commander.groups[k]:
			return "第%d部隊" % k
	return ""


func _unit_status(u: Unit) -> String:
	var parts: Array[String] = []
	if u.fortified:
		parts.append("構え中（被ダメージ半減・射程+15%）")
	elif u.setup_goal == "fortify":
		parts.append("構えを取っている…")
	if u.deployed:
		parts.append("展開中（射程延長）")
	elif u.setup_goal == "deploy":
		parts.append("展開中…")
	var sid: String = u.def.get("special", "")
	if sid != "":
		if u.special_time > 0.0:
			parts.append("%s 発動中 %d秒" % [Defs.special_name(sid), int(ceil(u.special_time))])
		elif u.special_cd > 0.0:
			parts.append("%s 再使用まで %d秒" % [Defs.special_name(sid), int(ceil(u.special_cd))])
		else:
			parts.append("%s 使用可能" % Defs.special_name(sid) + ("" if Game.touch_input else " [S]"))
	var order_names := {Unit.Order.IDLE: "待機", Unit.Order.MOVE: "移動中", Unit.Order.ATTACK: "攻撃中", Unit.Order.ATTACK_MOVE: "攻撃移動",
			Unit.Order.PATROL: "巡回中", Unit.Order.HOLD: "陣地保持", Unit.Order.REPAIR: "修理中"}
	if u.team == Defs.TEAM_PLAYER:
		parts.push_front(order_names.get(u.order, ""))
	if u.is_creature and u.hp < u.max_hp and world.match_time - u.last_damage_time > 6.0:
		parts.append("自然回復中")
	var cover := Combat.cover_near(u)
	if cover > 0:
		parts.append("遮蔽物のそば：%s" % ("建物・岩" if cover == 2 else "木"))
	if u.kills > 0:
		parts.append("撃破 %d" % u.kills)
	return "  ・  ".join(parts)


func _member_cell(u: Unit) -> Control:
	var k := 0.6 if compact else 1.0
	var c := Panel.new()
	c.custom_minimum_size = Vector2(48, 56) * k
	c.add_theme_stylebox_override("panel", UITheme.panel(Color(0.06, 0.07, 0.09, 1), UITheme.GOLD_DIM, 1))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = UITheme.icon("unit_" + u.def_id)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(6, 3) * k
	ic.size = Vector2(36, 36) * k
	ic.modulate = Defs.team_glow(u.team).lerp(Color.WHITE, 0.5)
	c.add_child(ic)
	var hp := _bar(Color(0.36, 0.86, 0.42))
	hp.name = "HP"
	hp.position = Vector2(5, 44) * k
	hp.size = Vector2(38 * k, 5 if compact else 7)
	c.add_child(hp)
	return c


func _unit_card(e: Entity) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(42, 50) if compact else Vector2(44, 52)
	b.focus_mode = Control.FOCUS_NONE
	var ic := TextureRect.new()
	ic.texture = UITheme.icon("unit_" + e.def_id if e is Unit else Defs.building_icon(e.def_id))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(4, 3)
	ic.size = Vector2(36, 36)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var hp := _bar(Color(0.36, 0.86, 0.42))
	hp.name = "HP"
	hp.position = Vector2(4, 42)
	hp.size = Vector2(36, 6)
	b.add_child(hp)
	b.tooltip_text = e.display_name()
	b.pressed.connect(func(): commander.set_selection([e]))
	return b


func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


# ---------------------------------------------------------------- buttons
func _select_idle() -> void:
	var list := world.units.filter(func(u): return u.team == 0 and u.alive and u.order == Unit.Order.IDLE and u.def_id == "artificer")
	if list.is_empty():
		list = world.units.filter(func(u): return u.team == 0 and u.alive and u.order == Unit.Order.IDLE)
	if not list.is_empty():
		commander.set_selection([list[0]])
		camera.look_at_point(list[0].global_position)


func _select_army() -> void:
	commander.set_selection(world.units.filter(func(u): return u.team == 0 and u.alive and u.def_id != "artificer"))


func _goto_objective() -> void:
	if match_node.mission and match_node.mission.focus_point != Vector3.INF:
		camera.look_at_point(match_node.mission.focus_point)


func _goto_alert() -> void:
	if _last_alert_pos != Vector3.INF:
		camera.look_at_point(_last_alert_pos)


func _on_mode(m: String) -> void:
	if Game.touch_input:
		mode_hint.text = {"MOVE": "移動先をタップ", "ATTACK": "攻撃目標か攻撃移動先をタップ", "PATROL": "巡回先をタップ",
				"REPAIR": "修理対象をタップ", "SPECIAL": "特殊能力の目標地点をタップ", "PLACE": "建設地点をタップ（もう一度タップで建設）"}.get(m, "")
	else:
		mode_hint.text = {"MOVE": "移動先を選択", "ATTACK": "攻撃目標または攻撃移動先を選択", "PATROL": "巡回先を選択",
				"REPAIR": "修理対象を選択", "SPECIAL": "特殊能力の目標地点を選択", "PLACE": "建設地点を選択（右クリック／Escで取消・Shiftで連続）"}.get(m, "")
	if cancel_button:
		cancel_button.visible = m != "NONE"
	if m == "NONE":
		mode_hint.text = ""
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	else:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_CROSS)


func toggle_pause() -> void:
	menus.toggle_pause()


func _on_game_end(winner: int) -> void:
	menus.show_end(winner == Defs.TEAM_PLAYER)


# ---------------------------------------------------------------- per frame
var _ui_t := 0.0


func _process(delta: float) -> void:
	for c in alert_box.get_children():
		var tt: float = c.get_meta("t", 0.0) - delta
		c.set_meta("t", tt)
		c.modulate.a = clampf(tt, 0.0, 1.0)
		if tt <= 0.0:
			c.queue_free()
	if _banner_t > 0.0:
		_banner_t -= delta
		var a := clampf(_banner_t, 0.0, 1.0)
		banner.modulate.a = a
		banner_sub.modulate.a = a
	elif banner.text != "":
		banner.text = ""
		banner_sub.text = ""
	if _tip_t > 0.0:
		_tip_t -= delta
		if _tip_t <= 0.0:
			tooltip.visible = false
	if deselect_button:
		deselect_button.visible = not commander.selection.is_empty()
	_ui_t -= delta
	if _ui_t > 0.0 and _sel_sig == _selection_signature() + str(build_mode) + str(shrine_page):
		return
	_ui_t = 0.1
	var p := world.player(Defs.TEAM_PLAYER)
	res_labels["material"].text = str(int(p.material))
	res_labels["aether"].text = str(int(p.aether))
	res_labels["pop"].text = "%d / %d" % [p.pop_used, p.pop_cap]
	res_labels["pop"].add_theme_color_override("font_color", UITheme.RED if p.pop_used >= p.pop_cap else UITheme.IVORY)
	rate_labels["material"].text = "+%d/分" % int(p.income_material * p.income_mult)
	rate_labels["aether"].text = "+%d/分" % int(p.income_aether * p.income_mult)
	rate_labels["pop"].text = ""
	var t := int(world.match_time)
	clock_label.text = "%02d:%02d" % [t / 60, t % 60]
	fps_label.text = ("FPS %d" % Engine.get_frames_per_second()) if Game.show_fps else ""
	_update_selection()
	_update_commands()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_B and commander.selected_building() and commander.selected_building().def_id == "citadel":
		build_mode = not build_mode
		shrine_page = false
		_sel_sig = ""
	elif k.physical_keycode == KEY_SPACE:
		_goto_alert()
	elif k.physical_keycode == KEY_F1:
		_select_idle()
	elif k.physical_keycode == KEY_F2:
		_select_army()
	elif k.physical_keycode == KEY_F3:
		Game.show_fps = not Game.show_fps


class SelectionBox:
	extends Control
	var commander: Commander

	func _init(c: Commander) -> void:
		commander = c
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if commander.dragging and commander.drag_rect.size.length() > 8.0:
			var r := commander.drag_rect
			draw_rect(r, Color(0.5, 1.0, 0.6, 0.08))
			draw_rect(r, Color(0.6, 1.0, 0.7, 0.9), false, 1.5)
		if commander.hover and is_instance_valid(commander.hover) and commander.mode == Commander.Mode.NONE:
			var e := commander.hover
			var cam := commander.camera.cam
			if not cam.is_position_behind(e.aim_point()):
				var p := cam.unproject_position(e.global_position + Vector3(0, e.height + 2.5, 0))
				var col := UITheme.IVORY if e.team == Defs.TEAM_PLAYER else Defs.team_color(e.team)
				draw_string(UITheme.serif_font(), p + Vector2(-80, 0), e.display_name(), HORIZONTAL_ALIGNMENT_CENTER, 160, 14, col)

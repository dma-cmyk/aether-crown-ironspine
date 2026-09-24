class_name HelpPanel
extends RefCounted
## "How to play" panel shared by the title screen and the pause menu: tabs for the controls,
## building and production, how to win, and a list of every unit with its cost.

const CONTROLS := """[color=#d0a85c]カメラ[/color]
  矢印キー / 画面端 … 移動　　ホイール … ズーム　　中ボタンドラッグ … 回転（Shift で平行移動）
  , . … 回転　　Home / Backspace … 本拠地へ　　Space … 最新の警報地点へ　　ミニマップ左クリック … 移動

[color=#d0a85c]選択と命令[/color]
  左クリック / 左ドラッグ … 選択（Shift で追加、ダブルクリックで同種を全選択）
  右クリック … 移動・攻撃・修理（建物選択中は集結地点）　Shift+右クリック … 経由地点を追加
  Ctrl+数字 … 部隊登録　数字 … 部隊呼び出し（2回押しでカメラ移動）　F1 … 待機ユニット　F2 … 全戦闘部隊

[color=#d0a85c]コマンド（右下のボタンと同じ）[/color]
  M 移動　H 陣地保持　A 攻撃移動　P 巡回　F 構え（被ダメージ半減・射程+15%）
  R 修理（工兵）　D 展開（臼砲：射程延長／歩兵：土嚢）　S 特殊能力

[color=#d0a85c]そのほか[/color]
  F3 … FPS 表示　　Esc … メニュー"""

const TOUCH_CONTROLS := """[color=#d0a85c]カメラ[/color]
  1本指でドラッグ … 移動　　2本指 … 広げる・つまむでズーム、ひねって回転、そろえて動かすと移動
  ミニマップをタップ … その場所へ　　ミニマップ横のボタン … 待機中の工兵・全戦闘部隊を選択、目標地点・最新の警報地点へ

[color=#d0a85c]選択と命令[/color]
  タップ … 自軍を選択（すばやく2回で画面内の同種を全選択）
  選択中にタップ … 地面なら移動、敵なら攻撃、傷ついた建物なら修理（工兵）。兵舎などを選択中なら集結地点
  長押ししてから指を動かす … 範囲選択　　長押しして離す … 敵も含めて選択（何もない所なら解除）
  選択パネル右上のボタン … 選択を解除

[color=#d0a85c]コマンド（右下のボタン。押すと説明が出る）[/color]
  移動・攻撃移動・巡回・修理・特殊能力は、続けて目標をタップ（上の「取消」でやめる）
  陣地保持・構え（被ダメージ半減・射程+15%）・展開（臼砲：射程延長／歩兵：土嚢）はすぐに切り替わる

[color=#d0a85c]そのほか[/color]
  メニューは右上の歯車"""

const BUILD := """[color=#d0a85c]生産[/color]
  兵舎・工廠・飛行場（飛行艦・機動兵）・祠を選択 → Q W E R … ユニット生産（Shift+クリックで5体）
  生産中のユニットのアイコンを押すと取り消せる。建物を選んで右クリックした所が集結地点になる。

[color=#d0a85c]建設[/color]
  本拠地を選択 → B または「建設」… 建設メニュー（Q〜Y で建物を選び、地面をクリック。U または「祠・塔」で祠と天罰の塔）
  建設できるのは本拠地・城門・自軍の都市の周辺だけ（建てる場所を選んでいる間、地面に範囲の線が出る）。

[color=#d0a85c]特別な部隊と施設[/color]
  神獣・悪魔・天使は種類ごとの祠（建設メニューの「祠・塔」）で呼ぶ。機械ではないので修理はできないが、戦闘から離れると自然に回復する。
  天罰の塔（「祠・塔」、1基まで）は約4分ごとに「発射」でマップのどこへでも光の柱を落とせる。撃つと相手にも着弾地点が知らされる。
  本拠地では巨神も作れる（1体まで）。光線と特殊能力「巨神の光」が強いが、体が崩れていき約11分で倒れる。"""

const TOUCH_BUILD := """[color=#d0a85c]生産[/color]
  兵舎・工廠・飛行場（飛行艦・機動兵）・祠を選択 → 右下のボタンでユニットを生産（数字は順番待ちの数）
  生産中のユニットのアイコンをタップすると取り消せる。建物を選んで地面をタップした所が集結地点になる。

[color=#d0a85c]建設[/color]
  本拠地を選択 →「建設」→ 建物を選ぶ（祠と天罰の塔は「祠・塔」の中） → 地面をタップで仮置き、仮置きした建物をもう一度タップで建設
  建設できるのは本拠地・城門・自軍の都市の周辺だけ（建てる場所を選んでいる間、地面に範囲の線が出る）。

[color=#d0a85c]特別な部隊と施設[/color]
  神獣・悪魔・天使は種類ごとの祠（建設メニューの「祠・塔」）で呼ぶ。機械ではないので修理はできないが、戦闘から離れると自然に回復する。
  天罰の塔（「祠・塔」、1基まで）は約4分ごとに「発射」でマップのどこへでも光の柱を落とせる。撃つと相手にも着弾地点が知らされる。
  本拠地では巨神も作れる（1体まで）。光線と特殊能力「巨神の光」が強いが、体が崩れていき約11分で倒れる。"""

const WINNING := """[color=#d0a85c]都市と資源[/color]
  都市のリレー塔の輪の中に地上部隊を置くと占領できる（工兵は速い）。都市は資材・エーテル・人口上限をくれる。
  資材は本拠地と工業都市、エーテルは精製所とエーテル都市から得られる。人口上限は本拠地・居住区・都市で増える。

[color=#d0a85c]地形と遮蔽[/color]
  木・家・城壁・岩は通れず、陰にいる部隊を銃弾・直射の砲弾・光線から守る（家・城壁・岩は半分、木は4分の1を防ぐ。臼砲・爆発・近接攻撃は防げない）。

[color=#d0a85c]勝敗[/color]
  ミッションの目標は右上に表示される。第1ミッションでは門で4つの攻撃波を耐え、援軍到着後に中央ネクサスを奪い、敵本拠地を破壊する。
  本拠地を失うと敗北（ミッションによって勝敗の条件が加わる）。"""

## Where each unit comes from, in the order the list shows them.
const SOURCES := ["barracks", "foundry", "skyport", "citadel", "sanctum_cerberus", "sanctum_cyclops", "sanctum_griffin",
		"sanctum_dragon", "sanctum_demon", "sanctum_angel"]


## Phones get the touch texts and a height that fits the screen.
static func make(on_close: Callable) -> PanelContainer:
	var screen := (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size
	var c := Game.compact
	var w := minf(1080.0, screen.x - 40.0)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.035, 0.045, 0.06, 0.97), UITheme.GOLD, 2))
	p.custom_minimum_size = Vector2(w, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6 if c else 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var title := UITheme.label("操作説明", 20 if c else 26, UITheme.IVORY, UITheme.title_font(), 2)
	title.custom_minimum_size.x = 150 if c else 190
	head.add_child(title)
	v.add_child(UITheme.divider())
	# every page scrolls inside the same box, so switching tabs never moves the panel
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(560.0, screen.y - (140.0 if c else 230.0)))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var touch := Game.touch_input
	var pages := [["操作", TOUCH_CONTROLS if touch else CONTROLS], ["生産と建設", TOUCH_BUILD if touch else BUILD],
			["勝ち方", WINNING], ["部隊一覧", ""]]
	var tabs: Array[Button] = []
	for i in pages.size():
		var t := Button.new()
		t.text = pages[i][0]
		t.toggle_mode = true
		t.focus_mode = Control.FOCUS_NONE
		t.custom_minimum_size = Vector2(0 if c else 120, 34 if c else 38)
		t.add_theme_font_override("font", UITheme.body_font())
		t.add_theme_font_size_override("font_size", 15 if c else 16)
		head.add_child(t)
		tabs.append(t)
		var page: Array = pages[i]
		t.pressed.connect(func() -> void:
			for other in tabs:
				other.button_pressed = other == t
			for ch in scroll.get_children():
				scroll.remove_child(ch)
				ch.queue_free()
			scroll.scroll_vertical = 0
			scroll.add_child(_units(w - 60.0) if page[1] == "" else _text(page[1], w - 60.0)))
	# dev shots open another tab with --tab=<n>
	tabs[clampi(int(Game.arg("tab", "0")), 0, tabs.size() - 1)].pressed.emit()
	var b := Button.new()
	b.text = "閉じる"
	b.custom_minimum_size = Vector2(0, 40 if c else 46)
	b.add_theme_font_override("font", UITheme.body_font())
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(on_close)
	v.add_child(b)
	UITheme.add_corners(p)
	return p


static func _text(bb: String, width: float) -> Control:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.add_theme_font_override("normal_font", UITheme.body_font())
	rt.add_theme_font_size_override("normal_font_size", 14 if Game.compact else 17)
	rt.add_theme_color_override("default_color", UITheme.IVORY)
	rt.add_theme_constant_override("line_separation", 4 if Game.compact else 7)
	rt.text = bb
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(width, 0)
	# a ScrollContainer, unlike the label's own scrolling, follows a dragging finger
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	return rt


## One row per unit the Crown can field: icon, name, cost and what it is for.
static func _units(width: float) -> Control:
	var c := Game.compact
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6 if c else 8)
	list.custom_minimum_size.x = width
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	# a unit made in more than one place is listed once, with all of them
	var made_at := {}
	for src: String in SOURCES:
		for uid: String in Defs.BUILDINGS[src]["produces"]:
			if not made_at.has(uid):
				made_at[uid] = []
			made_at[uid].append("祠" if src.begins_with("sanctum") else Defs.building_short(src))
	for uid: String in made_at:
		var d: Dictionary = Defs.UNITS[uid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UITheme.panel(Color(0.06, 0.07, 0.09, 1.0), UITheme.GOLD_DIM, 1))
		frame.mouse_filter = Control.MOUSE_FILTER_PASS
		var ic := TextureRect.new()
		ic.texture = UITheme.icon("unit_" + uid)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(34, 34) if c else Vector2(42, 42)
		frame.add_child(ic)
		row.add_child(frame)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 14)
		info.add_child(top)
		top.add_child(UITheme.label(Defs.unit_name(uid, 0), 15 if c else 18, UITheme.IVORY, UITheme.title_font()))
		var cost := "資材 %d" % int(d["cost"]["material"])
		if int(d["cost"].get("aether", 0)) > 0:
			cost += "  エーテル %d" % int(d["cost"]["aether"])
		cost += "  人口 %d   %s" % [int(d["pop"]), "・".join(made_at[uid])]
		top.add_child(UITheme.label(cost, 12 if c else 14, UITheme.GOLD, UITheme.bold_font()))
		var desc := UITheme.label(d["jp"], 12 if c else 14, UITheme.TEXT_DIM, UITheme.body_font())
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = width - 80.0
		info.add_child(desc)
		list.add_child(row)
	return list

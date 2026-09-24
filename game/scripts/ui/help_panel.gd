class_name HelpPanel
extends RefCounted
## "How to play" panel shared by the title screen and the pause menu.

const TEXT := """[font_size=26][color=#efe6d2]操作方法[/color][/font_size]

[color=#d0a85c]カメラ[/color]
  矢印キー / 画面端 … 移動　　ホイール … ズーム　　中ボタンドラッグ … 回転（Shift で平行移動）
  , . … 回転　　Home / Backspace … 本拠地へ　　Space … 最新の警報地点へ　　ミニマップ左クリック … 移動

[color=#d0a85c]選択と命令[/color]
  左クリック / 左ドラッグ … 選択（Shift で追加、ダブルクリックで同種を全選択）
  右クリック … 移動・攻撃・修理（建物選択中は集結地点）　Shift+右クリック … 経由地点を追加
  Ctrl+数字 … 部隊登録　数字 … 部隊呼び出し（2回押しでカメラ移動）　F1 … 待機ユニット　F2 … 全戦闘部隊

[color=#d0a85c]コマンド（右下のボタンと同じ）[/color]
  M 移動　H 陣地保持　A 攻撃移動　P 巡回　F 構え（被ダメージ半減・射程+15%）
  R 修理（工兵）　D 展開（臼砲：射程延長／歩兵：土嚢）　S 特殊能力

[color=#d0a85c]生産と建設[/color]
  兵舎・工廠・飛行場（飛行艦・機動兵）・祠を選択 → Q W E R … ユニット生産（Shift+クリックで5体）
  本拠地を選択 → B または「建設」… 建設メニュー（Q〜Y で建物を選び、地面をクリック。U または「祠・塔」で祠と天罰の塔）
  建設できるのは本拠地・城門・自軍の都市の周辺だけ。
  神獣・悪魔・天使は種類ごとの祠（建設メニューの「祠・塔」）で呼ぶ。機械ではないので修理はできないが、戦闘から離れると自然に回復する。
  天罰の塔（「祠・塔」、1基まで）は約4分ごとに「発射」でマップのどこへでも光の柱を落とせる。撃つと相手にも着弾地点が知らされる。

""" + WINNING + "　F3 で FPS 表示、Esc でメニュー。"

const TOUCH_TEXT := """[font_size=24][color=#efe6d2]操作方法（タッチ）[/color][/font_size]

[color=#d0a85c]カメラ[/color]
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

[color=#d0a85c]生産と建設[/color]
  兵舎・工廠・飛行場（飛行艦・機動兵）・祠を選択 → 右下のボタンでユニットを生産（数字は順番待ちの数）
  本拠地を選択 →「建設」→ 建物を選ぶ（祠と天罰の塔は「祠・塔」の中） → 地面をタップで仮置き、仮置きした建物をもう一度タップで建設
  建設できるのは本拠地・城門・自軍の都市の周辺だけ。
  神獣・悪魔・天使は種類ごとの祠（建設メニューの「祠・塔」）で呼ぶ。機械ではないので修理はできないが、戦闘から離れると自然に回復する。
  天罰の塔（「祠・塔」、1基まで）は約4分ごとに「発射」でマップのどこへでも光の柱を落とせる。撃つと相手にも着弾地点が知らされる。

""" + WINNING + "　メニューは右上の歯車。"

const WINNING := """[color=#d0a85c]勝利のために[/color]
  都市のリレー塔の輪の中に地上部隊を置くと占領できる（工兵は速い）。都市は資材・エーテル・人口上限をくれる。
  木・家・城壁・岩は通れず、陰にいる部隊を銃弾・直射の砲弾・光線から守る（家・城壁・岩は半分、木は4分の1を防ぐ。臼砲・爆発・近接攻撃は防げない）。
  ミッションの目標は右上に表示される。第1ミッションでは門で4つの攻撃波を耐え、援軍到着後に中央ネクサスを奪い、敵本拠地を破壊する。
  本拠地を失うと敗北（ミッションによって勝敗の条件が加わる）。"""


## Phones get the touch text in a scrolling box that fits the screen.
static func make(on_close: Callable) -> PanelContainer:
	var screen := (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size
	var w := minf(1080.0, screen.x - 40.0)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.035, 0.045, 0.06, 0.97), UITheme.GOLD, 2))
	p.custom_minimum_size = Vector2(w, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8 if Game.compact else 14)
	p.add_child(v)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.add_theme_font_override("normal_font", UITheme.body_font())
	rt.add_theme_font_size_override("normal_font_size", 14 if Game.compact else 17)
	rt.add_theme_color_override("default_color", UITheme.IVORY)
	rt.add_theme_constant_override("line_separation", 3 if Game.compact else 5)
	rt.text = TOUCH_TEXT if Game.touch_input else TEXT
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(w - 50.0, 0)
	if Game.compact:
		# a ScrollContainer, unlike the label's own scrolling, follows a dragging finger
		rt.mouse_filter = Control.MOUSE_FILTER_PASS
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, screen.y - 110.0)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_child(rt)
		v.add_child(scroll)
	else:
		v.add_child(rt)
	var b := Button.new()
	b.text = "閉じる"
	b.custom_minimum_size = Vector2(0, 40 if Game.compact else 46)
	b.add_theme_font_override("font", UITheme.body_font())
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(on_close)
	v.add_child(b)
	UITheme.add_corners(p)
	return p

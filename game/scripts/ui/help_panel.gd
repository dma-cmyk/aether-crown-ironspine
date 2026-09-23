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
  兵舎・工廠・飛行場・神獣の祠を選択 → Q W E R … ユニット生産（Shift+クリックで5体）
  本拠地を選択 → B または CONSTRUCT … 建設メニュー（Q〜U で建物を選び、地面をクリック）
  建設できるのは本拠地・城門・自軍の都市の周辺だけ。
  神獣の祠ではケルベロス・サイクロプス・グリフォン・ドラゴンを呼べる。機械ではないので修理はできないが、戦闘から離れると自然に回復する。

[color=#d0a85c]勝利のために[/color]
  都市のリレー塔の輪の中に地上部隊を置くと占領できる（工兵は速い）。都市は資材・エーテル・人口上限をくれる。
  ミッションの目標は右上に表示される。第1ミッションでは門で4つの攻撃波を耐え、援軍到着後に中央ネクサスを奪い、敵本拠地を破壊する。
  本拠地を失うと敗北（ミッションによって勝敗の条件が加わる）。 F3 で FPS 表示、Esc でメニュー。"""


static func make(on_close: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel(Color(0.035, 0.045, 0.06, 0.97), UITheme.GOLD, 2))
	p.custom_minimum_size = Vector2(1080, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(1040, 0)
	rt.add_theme_font_override("normal_font", UITheme.body_font())
	rt.add_theme_font_size_override("normal_font_size", 17)
	rt.add_theme_color_override("default_color", UITheme.IVORY)
	rt.add_theme_constant_override("line_separation", 5)
	rt.text = TEXT
	v.add_child(rt)
	var b := Button.new()
	b.text = "閉じる"
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_override("font", UITheme.body_font())
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(on_close)
	v.add_child(b)
	UITheme.add_corners(p)
	return p

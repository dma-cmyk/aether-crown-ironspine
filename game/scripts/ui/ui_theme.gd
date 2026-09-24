class_name UITheme
extends RefCounted
## Fonts, colours and panel styles shared by all UI.

const GOLD := Color(0.84, 0.68, 0.40)
const GOLD_DIM := Color(0.52, 0.42, 0.26)
const IVORY := Color(0.94, 0.90, 0.81)
const TEXT_DIM := Color(0.68, 0.66, 0.60)
const AETHER := Color(0.46, 0.86, 1.0)
const GREEN := Color(0.52, 0.92, 0.46)
const RED := Color(1.0, 0.44, 0.34)
const PANEL_BG := Color(0.045, 0.055, 0.075, 0.88)
const PANEL_BG_LIGHT := Color(0.08, 0.095, 0.12, 0.9)

static var _fonts := {}
static var _icons := {}
static var _theme: Theme


## Noto subsets shipped in assets/fonts (tools/fonts/subset_fonts.py): the Web build has no
## system fonts. `jp` fills in Japanese for the Latin-only faces.
static func _font(key: String, face: String, jp: String = "", spacing: int = 0) -> Font:
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = load("res://assets/fonts/%s.woff2" % face)
		if jp != "":
			v.fallbacks = [load("res://assets/fonts/%s.woff2" % jp)]
		v.spacing_glyph = spacing
		_fonts[key] = v
	return _fonts[key]


static func title_font() -> Font:
	return _font("title", "NotoSerifDisplay-SemiBold", "NotoSerifCJKjp-Medium", 2)


static func serif_font() -> Font:
	return _font("serif", "NotoSerif-Medium", "NotoSerifCJKjp-Medium")


static func italic_font() -> Font:
	return _font("italic", "NotoSerif-Italic", "NotoSerifCJKjp-Medium")


static func body_font() -> Font:
	return _font("body", "NotoSansCJKjp-Medium")


static func bold_font() -> Font:
	return _font("bold", "NotoSansCJKjp-Bold")


static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var p := "res://assets/ui/icons/%s.svg" % name
		_icons[name] = load(p) if ResourceLoader.exists(p) else null
	return _icons[name]


static func panel(bg: Color = PANEL_BG, border: Color = GOLD_DIM, width: int = 2, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.anti_aliasing = true
	return s


static func label(text: String, size: int = 16, color: Color = IVORY, font: Font = null, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 16
	var normal := panel(Color(0.09, 0.105, 0.135, 0.95), GOLD_DIM, 2)
	var hover := panel(Color(0.14, 0.16, 0.2, 0.97), GOLD, 2)
	var pressed := panel(Color(0.2, 0.18, 0.12, 0.97), GOLD, 2)
	var disabled := panel(Color(0.06, 0.065, 0.075, 0.85), Color(0.25, 0.23, 0.2), 2)
	for s in [normal, hover, pressed, disabled]:
		s.shadow_size = 2
		s.content_margin_left = 6
		s.content_margin_right = 6
		s.content_margin_top = 4
		s.content_margin_bottom = 4
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", IVORY)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.43, 0.4))
	t.set_color("icon_normal_color", "Button", IVORY)
	t.set_color("icon_hover_color", "Button", Color(1, 1, 1))
	t.set_color("icon_disabled_color", "Button", Color(0.4, 0.4, 0.4, 0.6))
	t.set_font("font", "Button", title_font())
	t.set_font_size("font_size", "Button", 15)
	var tip := panel(Color(0.04, 0.05, 0.065, 0.97), GOLD, 1)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", IVORY)
	t.set_stylebox("panel", "PanelContainer", panel())
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.15, 0.16, 0.19)
	slider_bg.set_corner_radius_all(3)
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider_bg)
	var grab := StyleBoxFlat.new()
	grab.bg_color = GOLD_DIM
	grab.set_corner_radius_all(3)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	_theme = t
	return t


## Decorative corner flourishes for a panel.
static func add_corners(c: Control, color: Color = GOLD, size: float = 14.0) -> void:
	var deco := Corners.new()
	deco.color = color
	deco.corner_size = size
	deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(deco)


class Corners:
	extends Control
	var color := GOLD
	var corner_size := 14.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, get_size())
		var s := corner_size
		var w := 2.0
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var p := Vector2(r.size.x * corner.x, r.size.y * corner.y)
			var dx := s if corner.x == 0 else -s
			var dy := s if corner.y == 0 else -s
			draw_line(p + Vector2(0, dy), p, color, w)
			draw_line(p, p + Vector2(dx, 0), color, w)
			var d := p + Vector2(dx * 0.45, dy * 0.45)
			draw_colored_polygon(PackedVector2Array([d + Vector2(0, -3), d + Vector2(3, 0), d + Vector2(0, 3), d + Vector2(-3, 0)]), color)


## A dark band that fades out at both ends, with thin gold edges: sits behind text drawn
## over the battlefield (banners, hints) so it stays readable on bright ground.
class Ribbon:
	extends Control
	var strength := 0.62
	var edges := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var xs := [0.0, w * 0.2, w * 0.8, w]
		var a := [0.0, 1.0, 1.0, 0.0]
		var bg := Color(0.015, 0.02, 0.03)
		for i in 3:
			var c0 := Color(bg, a[i] * strength)
			var c1 := Color(bg, a[i + 1] * strength)
			if strength > 0.0:
				_band(xs[i], xs[i + 1], 0.0, size.y, c0, c1)
			if edges:
				var g0 := Color(GOLD_DIM, a[i] * 0.9)
				var g1 := Color(GOLD_DIM, a[i + 1] * 0.9)
				_band(xs[i], xs[i + 1], 0.0, 1.5, g0, g1)
				_band(xs[i], xs[i + 1], size.y - 1.5, size.y, g0, g1)

	func _band(x0: float, x1: float, y0: float, y1: float, c0: Color, c1: Color) -> void:
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
				PackedColorArray([c0, c1, c1, c0]))


## A thin gold rule that fades out at both ends, for under titles and between sections.
static func divider(width: float = 0.0) -> Control:
	var r := Ribbon.new()
	r.strength = 0.0
	r.custom_minimum_size = Vector2(width, 3)
	return r


## Title-screen menu entries: no box, a dark band fading to the right, and a gold edge on
## the left that thickens (and pushes the text in a little) under the pointer.
static func menu_button_styles(b: Button) -> void:
	var looks := {
		"normal": [Color(0.02, 0.025, 0.035, 0.55), GOLD_DIM, 2, 22],
		"hover": [Color(0.13, 0.1, 0.05, 0.85), GOLD, 5, 30],
		"pressed": [Color(0.2, 0.15, 0.07, 0.9), GOLD, 5, 30],
		"focus": [Color(0.13, 0.1, 0.05, 0.85), GOLD, 5, 30],
		"disabled": [Color(0.02, 0.025, 0.035, 0.35), Color(0.3, 0.28, 0.25), 2, 22],
	}
	for state: String in looks:
		var l: Array = looks[state]
		var g := Gradient.new()
		var bg: Color = l[0]
		var edge: Color = l[1]
		var px: float = l[2] / 520.0
		g.offsets = PackedFloat32Array([0.0, px, px + 0.001, 0.55, 1.0])
		g.colors = PackedColorArray([edge, edge, bg, Color(bg, bg.a * 0.55), Color(bg, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 520
		gt.height = 4
		var sb := StyleBoxTexture.new()
		sb.texture = gt
		sb.content_margin_left = l[3]
		sb.content_margin_right = 12
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.78))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.93, 0.78))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.44))

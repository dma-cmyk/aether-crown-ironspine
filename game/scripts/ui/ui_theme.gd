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


static func _sys(key: String, names: PackedStringArray, weight: int = 400, italic: bool = false, spacing: int = 0) -> Font:
	if not _fonts.has(key):
		var f := SystemFont.new()
		f.font_names = names
		f.font_weight = weight
		f.font_italic = italic
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		if spacing != 0:
			var v := FontVariation.new()
			v.base_font = f
			v.spacing_glyph = spacing
			_fonts[key] = v
		else:
			_fonts[key] = f
	return _fonts[key]


static func title_font() -> Font:
	return _sys("title", PackedStringArray(["Noto Serif Display", "Noto Serif", "DejaVu Serif"]), 600, false, 2)


static func serif_font() -> Font:
	return _sys("serif", PackedStringArray(["Noto Serif", "DejaVu Serif", "Noto Serif CJK JP"]), 500)


static func italic_font() -> Font:
	return _sys("italic", PackedStringArray(["Noto Serif", "DejaVu Serif"]), 400, true)


static func body_font() -> Font:
	return _sys("body", PackedStringArray(["Noto Sans CJK JP", "Noto Sans", "DejaVu Sans"]), 500)


static func bold_font() -> Font:
	return _sys("bold", PackedStringArray(["Noto Sans CJK JP", "Noto Sans", "DejaVu Sans"]), 700)


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

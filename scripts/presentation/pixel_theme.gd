class_name PixelTheme
extends RefCounted

const FONT: FontFile = preload("res://assets/fonts/DotGothic16-Regular.ttf")


static func make(night: bool = false) -> Theme:
	var theme := Theme.new()
	var variation: FontVariation = font_for_size(16)
	theme.default_font = variation
	theme.default_font_size = 16
	var paper: Color = Color.BLACK if night else Color.WHITE
	var ink: Color = Color.WHITE if night else Color.BLACK
	for control: String in ["Button", "Label", "HSlider"]:
		theme.set_font("font", control, variation)
		theme.set_color("font_color", control, ink)
		theme.set_color("font_hover_color", control, ink)
		theme.set_color("font_focus_color", control, ink)
		theme.set_color("font_pressed_color", control, paper)
		theme.set_color("font_disabled_color", control, ink)
	for state: String in ["normal", "hover", "disabled"]:
		theme.set_stylebox(state, "Button", box(paper, ink))
	theme.set_stylebox("pressed", "Button", box(ink, paper))
	theme.set_stylebox("panel", "Panel", box(paper, ink))
	var focus: StyleBoxFlat = box(paper, ink)
	focus.draw_center = false
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("slider", "HSlider", box(paper, ink))
	theme.set_stylebox("grabber_area", "HSlider", box(ink, ink))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(ink, ink))
	theme.set_stylebox("focus", "HSlider", focus)
	var grabber: Texture2D = (
		preload("res://assets/slider_grabber_night.svg")
		if night
		else preload("res://assets/slider_grabber.svg")
	)
	for state: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
		theme.set_icon(state, "HSlider", grabber)
	return theme


static func font_for_size(size: int) -> FontVariation:
	var font: FontFile = FONT
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var variation := FontVariation.new()
	variation.base_font = FONT
	var excess: int = maxi(0, ceili(FONT.get_height(size)) - size)
	variation.spacing_top = -int(excess / 2.0)
	variation.spacing_bottom = -excess - variation.spacing_top
	return variation


static func box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	return style

class_name PixelWidgets
extends RefCounted


static func label(parent: Control, text: String, rect: Rect2, font_size: int = 16) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", PixelTheme.font_for_size(font_size))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = rect.size
	return label


static func button(parent: Control, text: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button


static func panel(parent: Control, rect: Rect2) -> Panel:
	var panel := Panel.new()
	parent.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


static func icon(parent: Control, path: String, at: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	parent.add_child(icon)
	icon.texture = load(path) as Texture2D
	icon.position = at
	icon.size = Vector2(16, 16)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent.get_theme_color("font_color", "Label") == Color.WHITE:
		var inverted := ShaderMaterial.new()
		inverted.shader = preload("res://assets/invert.gdshader")
		icon.material = inverted
	return icon


static func fit(label: Label, width: float) -> void:
	var font_size: int = 16
	while font_size > 12:
		if (
			(
				label
				. get_theme_font("font")
				. get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				. x
			)
			<= width
		):
			break
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", PixelTheme.font_for_size(font_size))
	label.size.x = width

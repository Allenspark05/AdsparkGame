extends RefCounted

# Shared look for the code-built buttons: opaque dark purple with an orange border,
# so the city skyline and billboard in the background never show through the text.
# Use:  const UiStyle = preload("res://scenes/ui_style.gd")  then  UiStyle.style_button(button)

static func style_button(b: Button) -> void:
	var fills = {
		"normal": Color(0.10, 0.04, 0.20),
		"hover": Color(0.20, 0.08, 0.34),
		"pressed": Color(0.30, 0.12, 0.42),
	}
	for state in fills:
		var sb = StyleBoxFlat.new()
		sb.bg_color = fills[state]
		sb.border_color = Color(1.0, 0.6, 0.15)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

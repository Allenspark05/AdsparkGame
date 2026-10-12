extends RefCounted

# Shared look for the code-built buttons: opaque dark purple with an orange border,
# so the city skyline and billboard in the background never show through the text.
# Use:  const UiStyle = preload("res://scenes/ui_style.gd")  then  UiStyle.style_button(button)

const PURPLE_DARK = Color(0.10, 0.04, 0.20)
const ORANGE = Color(1.0, 0.6, 0.15)
const OUTLINE = Color(0.12, 0.03, 0.2)

# Same dark-purple / orange look for a text box; the border brightens while it has focus.
static func style_line_edit(e: LineEdit) -> void:
	for state in ["normal", "focus", "read_only"]:
		var sb = StyleBoxFlat.new()
		sb.bg_color = PURPLE_DARK
		sb.border_color = ORANGE if state == "focus" else Color(0.55, 0.38, 0.7)
		sb.set_border_width_all(4 if state == "focus" else 3)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		if state == "focus":
			sb.shadow_color = Color(1.0, 0.6, 0.15, 0.45)
			sb.shadow_size = 8
		e.add_theme_stylebox_override(state, sb)
	e.add_theme_color_override("font_color", Color(1, 1, 1))
	e.add_theme_color_override("font_placeholder_color", Color(0.7, 0.6, 0.8))
	e.add_theme_color_override("caret_color", ORANGE)
	e.add_theme_color_override("selection_color", Color(1.0, 0.6, 0.15, 0.5))

# Quick scale "pop" around the control's centre (score ticks, banners).
static func pop(c: Control, amount: float = 1.25) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(amount, amount)
	var t = c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

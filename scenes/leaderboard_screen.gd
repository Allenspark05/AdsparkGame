extends Control

const UiStyle = preload("res://scenes/ui_style.gd")
const ROWS : int = 10
const ROW_Y : int = 204
const ROW_H : int = 48
const HERO_ICONS = {
	"boy": "res://assets/portrait_boy.png",
	"girl": "res://assets/portrait_girl.png",
}
const RANK_COLORS = [Color(1.0, 0.84, 0.2), Color(0.82, 0.85, 0.9), Color(0.85, 0.55, 0.3)]

func _ready():
	var bg = Sprite2D.new()
	bg.texture = load("res://assets/bg.png")
	bg.centered = false
	add_child(bg)

	var ground = Sprite2D.new()
	ground.texture = load("res://assets/ground.png")
	ground.centered = false
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, 864, 168)
	ground.position = Vector2(0, 768)
	add_child(ground)

	_label("LEADERBOARD", Vector2(0, 124), 864, HORIZONTAL_ALIGNMENT_CENTER, 46, Color(1.0, 0.6, 0.15))

	var panel = Panel.new()
	panel.position = Vector2(96, 190)
	panel.size = Vector2(672, ROWS * ROW_H + 16)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.03, 0.16, 0.88)
	sb.border_color = Color(1.0, 0.6, 0.15)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var entries = Leaderboard.top(ROWS)
	for i in ROWS:
		var y = ROW_Y + i * ROW_H
		var has_entry = i < entries.size()
		var color = Color(1, 1, 1) if has_entry else Color(0.5, 0.45, 0.6)
		if has_entry and i < RANK_COLORS.size():
			color = RANK_COLORS[i]
		_label("%d." % (i + 1), Vector2(112, y), 60, HORIZONTAL_ALIGNMENT_RIGHT, 28, color)
		if has_entry:
			var e = entries[i]
			var icon = TextureRect.new()
			icon.texture = load(HERO_ICONS.get(e["hero"], HERO_ICONS["boy"]))
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(184, y + 2)
			icon.size = Vector2(36, 36)
			add_child(icon)
			_label(e["name"], Vector2(236, y), 330, HORIZONTAL_ALIGNMENT_LEFT, 28, color)
			_label(str(e["score"]), Vector2(580, y), 160, HORIZONTAL_ALIGNMENT_RIGHT, 28, color)
		else:
			_label("-", Vector2(236, y), 330, HORIZONTAL_ALIGNMENT_LEFT, 28, color)

	var back = Button.new()
	back.text = "BACK  (Esc)"
	back.add_theme_font_size_override("font_size", 24)
	back.position = Vector2(316, 704)
	back.size = Vector2(232, 48)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_back)
	UiStyle.style_button(back)
	add_child(back)

func _label(text: String, pos: Vector2, width: float, align: int, font_size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.2))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	l.size = Vector2(width, 40)
	l.horizontal_alignment = align
	add_child(l)
	return l

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_back()

func _back():
	AudioManager.play("confirm")
	get_tree().change_scene_to_file(GameState.leaderboard_return)

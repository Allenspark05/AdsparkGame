extends Control

# Hero screen. Step 1: type your name (Enter). Step 2: pick a hero (arrows) and play (Enter).
const UiStyle = preload("res://scenes/ui_style.gd")

const HEROES = [
	{"id": "boy", "name": "MEDIA", "tag": "Boy Hero", "portrait": "res://assets/portrait_boy.png", "color": Color(0.35, 0.65, 1.0)},
	{"id": "girl", "name": "CREATIVE", "tag": "Girl Hero", "portrait": "res://assets/portrait_girl.png", "color": Color(1.0, 0.55, 0.75)},
]
const CARD_SIZE = Vector2(300, 320)
const CARD_Y = 322

var index : int = 0
var cards : Array = []
var stage : String = "name"  # "name" while typing the name, "hero" while choosing the hero
var name_edit : LineEdit
var hint : Label
var step_label : Label
var chips : HBoxContainer

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

	var title = Label.new()
	title.text = "CHOOSE YOUR HERO"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.15))
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.2))
	title.add_theme_constant_override("outline_size", 10)
	title.position = Vector2(0, 140)
	title.size = Vector2(864, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var name_label = Label.new()
	name_label.text = "STEP 1 OF 2 - YOUR NAME"
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.2))
	name_label.add_theme_constant_override("outline_size", 8)
	name_label.position = Vector2(0, 214)
	name_label.size = Vector2(864, 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label = name_label
	add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.max_length = 12
	name_edit.placeholder_text = "Type your name"
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_font_size_override("font_size", 28)
	name_edit.position = Vector2(252, 246)
	name_edit.size = Vector2(360, 52)
	UiStyle.style_line_edit(name_edit)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.focus_entered.connect(_on_name_focused)
	add_child(name_edit)

	for i in HEROES.size():
		var card = _make_card(i)
		card.position = Vector2(100 + i * 364, CARD_Y)
		add_child(card)
		cards.append(card)

	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.2))
	hint.add_theme_constant_override("outline_size", 8)
	hint.position = Vector2(0, 654)
	hint.size = Vector2(864, 32)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 14)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.position = Vector2(0, 650)
	chips.size = Vector2(864, 40)
	for pair in [["< >", "CHOOSE"], ["ENTER", "PLAY"], ["TAB", "NAME"], ["L", "BOARD"], ["M", "MUTE"]]:
		chips.add_child(_make_chip(pair[0], pair[1]))
	add_child(chips)

	var lb_button = Button.new()
	lb_button.text = "Leaderboard"
	lb_button.add_theme_font_size_override("font_size", 22)
	lb_button.position = Vector2(314, 700)
	lb_button.size = Vector2(236, 44)
	lb_button.focus_mode = Control.FOCUS_NONE
	lb_button.pressed.connect(_open_leaderboard)
	UiStyle.style_button(lb_button)
	add_child(lb_button)

	AudioManager.start_music()
	if GameState.player_name != "":
		# coming back from a game or the leaderboard: same player, just pick a hero
		name_edit.text = GameState.player_name
		_set_stage("hero")
	else:
		# a fresh start: offer the last player's name, selected so typing replaces it
		name_edit.text = Leaderboard.last_name
		_set_stage("name")
		name_edit.select_all()

func _make_card(i: int) -> Button:
	var hero = HEROES[i]
	var card = Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE  # arrows/enter are handled in _unhandled_input
	card.pressed.connect(_on_card_pressed.bind(i))
	card.mouse_entered.connect(_on_card_hover.bind(i))

	var portrait = TextureRect.new()
	portrait.texture = load(hero.portrait)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(55, 20)
	portrait.size = Vector2(190, 190)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(portrait)
	var bob = portrait.create_tween().set_loops()
	bob.tween_property(portrait, "position:y", 12.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(portrait, "position:y", 20.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var name_label = Label.new()
	name_label.text = hero.name
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.add_theme_color_override("font_color", hero.color)
	name_label.position = Vector2(0, 216)
	name_label.size = Vector2(300, 46)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)

	var tag_label = Label.new()
	tag_label.text = hero.tag
	tag_label.add_theme_font_size_override("font_size", 22)
	tag_label.position = Vector2(0, 268)
	tag_label.size = Vector2(300, 32)
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tag_label)
	return card

func _make_chip(key_text: String, action: String) -> Control:
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var key = Label.new()
	key.text = key_text
	key.add_theme_font_size_override("font_size", 13)
	key.add_theme_color_override("font_color", Color(0.12, 0.03, 0.2))
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.6, 0.15)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	key.add_theme_stylebox_override("normal", sb)
	var act = Label.new()
	act.text = action
	act.add_theme_font_size_override("font_size", 13)
	act.add_theme_color_override("font_outline_color", UiStyle.OUTLINE)
	act.add_theme_constant_override("outline_size", 6)
	box.add_child(key)
	box.add_child(act)
	return box

func _style(color: Color, border: int, fill_alpha: float, glow: bool = false) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	if glow:
		sb.shadow_color = Color(color.r, color.g, color.b, 0.6)
		sb.shadow_size = 22
	sb.bg_color = Color(0.08, 0.03, 0.16, fill_alpha)
	sb.border_color = color
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(18)
	return sb

func _name() -> String:
	return name_edit.text.strip_edges()

func _set_stage(new_stage: String) -> void:
	stage = new_stage
	if stage == "name":
		name_edit.grab_focus()
		name_edit.caret_column = name_edit.text.length()
	else:
		name_edit.release_focus()
	_refresh()

func _refresh():
	var active = (stage == "hero")
	for i in cards.size():
		var selected = (i == index)
		var color = HEROES[i].color if selected else Color(0.45, 0.35, 0.6)
		var border = 2
		if selected:
			border = 8 if active else 4
		var sb = _style(color, border, 0.97, selected and active)
		for state in ["normal", "hover", "pressed"]:
			cards[i].add_theme_stylebox_override(state, sb)
		cards[i].modulate = Color(1, 1, 1) if (selected and active) else Color(0.65, 0.65, 0.65)
		cards[i].pivot_offset = CARD_SIZE / 2.0
		var target = Vector2(1.06, 1.06) if (selected and active) else Vector2.ONE
		var t = cards[i].create_tween()
		t.tween_property(cards[i], "scale", target, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh_hint()

func _refresh_hint():
	hint.add_theme_color_override("font_color", Color(1, 1, 1))
	step_label.text = "STEP 1 OF 2 - YOUR NAME" if stage == "name" else "STEP 2 OF 2 - PICK YOUR HERO"
	chips.visible = (stage == "hero")
	hint.visible = (stage == "name")
	if stage == "name":
		hint.text = "Type your name, then press ENTER"
	else:
		hint.text = "LEFT / RIGHT choose    ENTER play    TAB change name    L board    M mute"

func _nudge():
	hint.visible = true
	hint.text = "Please type your name first!"
	hint.add_theme_color_override("font_color", Color(1.0, 0.6, 0.15))
	AudioManager.play("tick")

func _on_name_submitted(_text: String) -> void:
	if _name() == "":
		_nudge()
		return
	AudioManager.play("confirm")
	_set_stage("hero")

func _on_name_changed(_text: String) -> void:
	_refresh_hint()

func _on_name_focused() -> void:
	if stage != "name":  # the player clicked the name box
		_set_stage("name")

func _on_card_hover(i: int):
	if i != index:
		AudioManager.play("tick")
	index = i
	_refresh()

func _on_card_pressed(i: int):
	index = i
	_start()

func _unhandled_input(event):
	if stage == "name":
		return  # the name box is handling the keyboard
	if event.is_action_pressed("ui_left"):
		index = (index - 1 + HEROES.size()) % HEROES.size()
		AudioManager.play("tick")
		_refresh()
	elif event.is_action_pressed("ui_right"):
		index = (index + 1) % HEROES.size()
		AudioManager.play("tick")
		_refresh()
	elif event.is_action_pressed("ui_accept"):
		_start()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_up"):
		_set_stage("name")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_open_leaderboard()

func _open_leaderboard():
	AudioManager.play("confirm")
	if _name() != "":
		GameState.player_name = _name()  # come back to the same player
	GameState.leaderboard_return = "res://scenes/select.tscn"
	get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")

func _start():
	var player = _name()
	if player == "":
		_set_stage("name")
		_nudge()
		return
	AudioManager.play("confirm")
	GameState.player_name = player
	GameState.hero = HEROES[index].id
	get_tree().change_scene_to_file("res://scenes/main.tscn")

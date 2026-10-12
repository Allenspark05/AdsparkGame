extends CanvasLayer

const UiStyle = preload("res://scenes/ui_style.gd")

signal restart

var score_label : Label
var info_label : Label

func _ready():
	score_label = _make_label(36, Color(1, 1, 1), 266, 50)
	info_label = _make_label(26, Color(1.0, 0.6, 0.15), 312, 36)
	UiStyle.style_button($ChangeHeroButton)
	UiStyle.style_button($LeaderboardButton)

func _make_label(font_size: int, color: Color, y: float, height: float) -> Label:
	var l = Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.2))
	l.add_theme_constant_override("outline_size", 8)
	l.position = Vector2(0, y)
	l.size = Vector2(864, height)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l

# Called by main.gd the moment the round ends. The round is saved under the current
# player's name automatically (only a personal best changes the leaderboard).
func show_result(score: int) -> void:
	var r = Leaderboard.record(GameState.player_name, score, GameState.hero)
	score_label.text = "SCORE: %d     BEST: %d" % [score, r["best"]]
	info_label.text = _info_text(score, r)
	_animate_in(r["is_best"])

# Slide the result in from above; pop the banner when it is a personal best.
func _animate_in(is_best: bool) -> void:
	for l in [score_label, info_label]:
		l.pivot_offset = l.size / 2.0
		l.modulate.a = 0.0
		var home = l.position.y
		l.position.y = home - 40
		var t = create_tween().set_parallel(true)
		t.tween_property(l, "position:y", home, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "modulate:a", 1.0, 0.25)
	if is_best:
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(info_label):
			UiStyle.pop(info_label, 1.3)

func _info_text(score: int, r: Dictionary) -> String:
	if r["rank"] <= 0:
		return "Score a point to join the leaderboard" if score <= 0 else ""
	var rank_text = "You are #%d of %d" % [r["rank"], r["total"]]
	if r["is_best"]:
		return "NEW PERSONAL BEST!   " + rank_text
	return rank_text

func _on_restart_button_pressed():
	restart.emit()

# Goes to the hero screen with the current player's name filled in, to change the
# name (Tab) or the hero.
func _on_change_hero_button_pressed():
	get_tree().change_scene_to_file("res://scenes/select.tscn")

func _on_leaderboard_button_pressed():
	GameState.leaderboard_return = "res://scenes/main.tscn"
	get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")

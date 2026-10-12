extends Node

const UiStyle = preload("res://scenes/ui_style.gd")

@export var pipe_scene : PackedScene

var game_running : bool
var game_over : bool
var scroll
var score
const SCROLL_SPEED : float = 240.0  # pixels per second, so every refresh rate plays the same
const RESTART_GUARD : float = 0.6  # seconds after dying before Space/Enter can restart
var screen_size : Vector2i
var ground_height : int
var pipes : Array
var paused : bool = false
var game_over_at : int = 0
var hint_label : Label
var pause_label : Label
const PIPE_DELAY : int = 100
const PIPE_RANGE : int = 200

# Called when the node enters the scene tree for the first time.
func _ready():
	screen_size = Vector2i(get_viewport().get_visible_rect().size)
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	hint_label = _make_banner("TAP OR PRESS SPACE TO FLY", 26, 560)
	pause_label = _make_banner("PAUSED - TAP OR PRESS SPACE TO RESUME", 28, 400)
	pause_label.hide()
	new_game()
	AudioManager.start_music()

# Big outlined centre text on its own layer, used for the get-ready hint and the pause notice.
func _make_banner(text: String, font_size: int, y: float) -> Label:
	var layer = CanvasLayer.new()
	add_child(layer)
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.2))
	l.add_theme_constant_override("outline_size", 8)
	l.position = Vector2(0, y)
	l.size = Vector2(864, 50)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(l)
	return l

func new_game():
	#reset variables
	game_running = false
	game_over = false
	set_paused(false)
	hint_label.show()
	score = 0
	scroll = 0
	$ScoreLabel.text = "SCORE: " + str(score)
	$GameOver.hide()
	get_tree().call_group("pipes", "queue_free")
	pipes.clear()
	#generate starting pipes
	generate_pipes()
	$Bird.reset()
	
func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if game_over:
			# Space/Enter retries, after a short guard so a late flap can't skip the result
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and can_restart():
				new_game()
			return
		if event.keycode in [KEY_P, KEY_ESCAPE] and game_running:
			set_paused(not paused)
			return
	if paused:
		# any tap or Space resumes, and is not also counted as a flap
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
			set_paused(false)
		return
	if game_over == false:
		var pressed_flap = false
		if event is InputEventMouseButton:
			pressed_flap = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		elif event is InputEventKey:
			# space bar only, ignore key-repeat so holding it doesn't spam flaps
			pressed_flap = event.keycode == KEY_SPACE and event.pressed and not event.echo
		if pressed_flap:
			flap_or_start()

func flap_or_start():
	if game_running == false:
		start_game()
	elif $Bird.flying:
		$Bird.flap()
		AudioManager.play("flap")
		check_top()

func can_restart() -> bool:
	return game_over and Time.get_ticks_msec() - game_over_at >= RESTART_GUARD * 1000.0

func set_paused(value: bool) -> void:
	paused = value
	pause_label.visible = value
	$PipeTimer.paused = value
	$Bird.set_physics_process(not value)

# Pause automatically when the window or browser tab loses focus mid-run.
func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if game_running:
			set_paused(true)

func start_game():
	hint_label.hide()
	game_running = true
	$Bird.flying = true
	$Bird.flap()
	AudioManager.play("flap")
	#start pipe timer
	$PipeTimer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if game_running and not paused:
		var step = SCROLL_SPEED * delta
		scroll += step
		#reset scroll
		if scroll >= screen_size.x:
			scroll = 0
		#move ground node
		$Ground.position.x = -scroll
		#move pipes
		for pipe in pipes:
			pipe.position.x -= step


func _on_pipe_timer_timeout():
	generate_pipes()
	
func generate_pipes():
	var pipe = pipe_scene.instantiate()
	pipe.position.x = screen_size.x + PIPE_DELAY
	pipe.position.y = (screen_size.y - ground_height) / 2  + randi_range(-PIPE_RANGE, PIPE_RANGE)
	pipe.hit.connect(bird_hit)
	pipe.scored.connect(scored)
	add_child(pipe)
	pipes.append(pipe)
	
func scored():
	score += 1
	$ScoreLabel.text = "SCORE: " + str(score)
	AudioManager.play("score")
	UiStyle.pop($ScoreLabel)

func check_top():
	if $Bird.position.y < 0:
		$Bird.falling = true
		stop_game()

func stop_game():
	if game_over:
		return
	$PipeTimer.stop()
	$GameOver.show()
	$GameOver.show_result(score)
	$Bird.flying = false
	game_running = false
	game_over = true
	game_over_at = Time.get_ticks_msec()
	AudioManager.play("hit")
	get_tree().create_timer(0.35).timeout.connect(func(): AudioManager.play("gameover"))
	
func bird_hit():
	$Bird.falling = true
	stop_game()

func _on_ground_hit():
	$Bird.falling = false
	stop_game()

func _on_game_over_restart():
	new_game()

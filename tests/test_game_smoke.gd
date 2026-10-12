extends SceneTree

# Loads the real game scene and plays rounds headlessly.
# Run:  <godot> --headless --path . -s tests/test_game_smoke.gd
const TEST_PATH = "user://test_leaderboard_smoke.json"
var failures : int = 0
# Autoloads are not compile-time globals in a -s script, so fetch them from the tree.
var audio
var board
var state

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		print("FAIL  ", msg)
		failures += 1

func playing_count() -> int:
	var n = 0
	for p in audio.pool:
		if p.playing:
			n += 1
	return n

func play_round(main, points: int) -> void:
	main.new_game()
	main.flap_or_start()
	for i in points:
		main.scored()
	main.stop_game()

func _initialize():
	audio = root.get_node("AudioManager")
	board = root.get_node("Leaderboard")
	state = root.get_node("GameState")
	# never touch the player's real leaderboard
	board.save_path = TEST_PATH
	board.entries = []
	board.last_name = ""
	state.hero = "girl"
	state.player_name = "Tester"

	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	check(not main.game_over, "a new game starts not over")
	check(audio.music_player.playing, "music is playing once the game scene loads")
	var tex = main.get_node("Bird/AnimatedSprite2D").sprite_frames.get_frame_texture("flying", 0)
	check(tex.resource_path == "res://assets/bird_girl1.png", "the bird uses the chosen hero's frames")

	main.flap_or_start()
	check(main.game_running, "flap_or_start starts the game")
	check(playing_count() == 1, "starting plays the flap sound")
	main.flap_or_start()
	check(playing_count() == 2, "flapping again plays another flap sound")
	main.scored()
	check(main.score == 1, "scored() adds a point")
	check(playing_count() == 3, "scoring plays the score sound")

	var before = playing_count()
	main.stop_game()
	check(main.game_over, "stop_game ends the round")
	var after_first = playing_count()
	check(after_first == before + 1, "stop_game plays the hit sound once")
	main.stop_game()
	check(playing_count() == after_first, "a second stop_game (pipe hit, then ground) plays nothing more")

	# round 1 ended with score 1: it is saved automatically under the player's name
	var go = main.get_node("GameOver")
	check(go.score_label.text == "SCORE: 1     BEST: 1", "game over shows score and best: %s" % go.score_label.text)
	check("NEW PERSONAL BEST" in go.info_label.text and "#1 of 1" in go.info_label.text, "first score shows a personal best and the rank: %s" % go.info_label.text)
	var saved = board.top()
	check(saved.size() == 1 and saved[0]["name"] == "Tester" and saved[0]["score"] == 1 and saved[0]["hero"] == "girl",
		"the score is saved automatically with the player's name and hero")

	# round 2: same player, same score -> no banner, no second row
	play_round(main, 1)
	check(not ("NEW PERSONAL BEST" in go.info_label.text) and "#1 of 1" in go.info_label.text, "an equal score shows the rank but no banner: %s" % go.info_label.text)
	check(board.count() == 1, "retrying does not add a second row")

	# round 3: a zero score changes nothing
	play_round(main, 0)
	check(go.score_label.text == "SCORE: 0     BEST: 1", "a zero score still shows the player's best: %s" % go.score_label.text)
	check(board.count() == 1 and board.top()[0]["score"] == 1, "a zero score changes nothing")

	# round 4: a higher score replaces the player's best; Restart asks nothing
	play_round(main, 2)
	check("NEW PERSONAL BEST" in go.info_label.text, "a higher score shows the banner: %s" % go.info_label.text)
	check(board.count() == 1 and board.top()[0]["score"] == 2, "a higher score replaces the player's row")
	go._on_restart_button_pressed()
	check(not main.game_over and board.count() == 1, "Restart starts a new round without any prompt")

	# another player gets their own row and rank
	state.player_name = "Zoe"
	play_round(main, 5)
	check(board.count() == 2 and board.top()[0]["name"] == "Zoe", "a second player gets their own row")
	check("#1 of 2" in go.info_label.text, "the rank is relative to all players: %s" % go.info_label.text)

	# get-ready hint, pause, and keyboard restart
	main.new_game()
	check(main.hint_label.visible, "the get-ready hint shows before the first flap")
	main.flap_or_start()
	check(not main.hint_label.visible, "the hint hides once the game starts")
	main.set_paused(true)
	var px = main.get_node("Bird").position.y
	var sc = main.scroll
	main._process(0.016)
	check(main.scroll == sc and main.pause_label.visible, "pausing freezes the scroll and shows the notice")
	main.set_paused(false)
	main._process(0.5)
	check(is_equal_approx(main.scroll - sc, main.SCROLL_SPEED * 0.5), "scroll distance follows time, not frame count")
	main.stop_game()
	check(not main.can_restart(), "Space cannot restart in the first moments after dying")
	main.game_over_at -= 1000
	check(main.can_restart(), "Space can restart after the guard time")
	var key = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	main._input(key)
	check(not main.game_over, "Space restarts after the guard time")

	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)

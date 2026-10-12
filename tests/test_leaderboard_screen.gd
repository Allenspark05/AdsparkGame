extends SceneTree

# Run:  <godot> --headless --path . -s tests/test_leaderboard_screen.gd
const TEST_PATH = "user://test_leaderboard_screen.json"
const SELECT = "res://scenes/select.tscn"
const BOARD = "res://scenes/leaderboard.tscn"
const MAIN = "res://scenes/main.tscn"
var failures : int = 0
var board
var state

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		print("FAIL  ", msg)
		failures += 1

func labels_with_text(node: Node, text: String) -> int:
	var n = 0
	for c in node.get_children():
		if c is Label and c.text == text:
			n += 1
	return n

func key(code: int) -> InputEventKey:
	var ev = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev

func settle() -> void:
	await process_frame
	await process_frame

func names_of() -> Array:
	var out = []
	for e in board.top():
		out.append(e["name"])
	return out

func _initialize():
	board = root.get_node("Leaderboard")
	state = root.get_node("GameState")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	board.save_path = TEST_PATH  # never touch the player's real leaderboard
	board.entries = []
	board.last_name = ""
	board.record("Zed", 9, "boy")
	board.record("Amy", 5, "girl")

	# the screen lists ranks, names, scores and dashes for empty rows
	var screen = load(BOARD).instantiate()
	root.add_child(screen)
	await settle()
	check(labels_with_text(screen, "Zed") == 1, "the top name is listed")
	check(labels_with_text(screen, "9") == 1, "the top score is listed")
	check(labels_with_text(screen, "Amy") == 1, "the second name is listed")
	check(labels_with_text(screen, "5") == 1, "the second score is listed")
	for r in range(1, 11):
		check(labels_with_text(screen, "%d." % r) == 1, "rank %d has a row" % r)
	check(labels_with_text(screen, "-") == 8, "the eight empty rows show a dash")

	# Esc goes back to wherever the screen was opened from
	state.leaderboard_return = SELECT
	screen._unhandled_input(key(KEY_ESCAPE))
	await settle()
	check(current_scene != null and current_scene.scene_file_path == SELECT, "Esc returns to the opener")

	# L on the hero screen (hero step) opens the leaderboard and remembers the hero screen
	current_scene._set_stage("hero")
	current_scene._unhandled_input(key(KEY_L))
	await settle()
	check(current_scene != null and current_scene.scene_file_path == BOARD, "L on the hero screen opens the leaderboard")
	check(state.leaderboard_return == SELECT, "the hero screen is remembered as the way back")

	# the game over Leaderboard button: the round was already saved automatically
	var go = load("res://scenes/game_over.tscn").instantiate()
	root.add_child(go)
	await settle()
	state.player_name = "Zoe"
	go.show_result(3)
	check(names_of() == ["Zed", "Amy", "Zoe"], "the finished round is saved when the result is shown: %s" % [names_of()])
	go._on_leaderboard_button_pressed()
	await settle()
	check(state.leaderboard_return == MAIN, "the game screen is remembered as the way back")
	check(current_scene != null and current_scene.scene_file_path == BOARD, "the game over button opens the leaderboard")

	# Change Player / Hero goes to the hero screen with the player remembered
	var go2 = load("res://scenes/game_over.tscn").instantiate()
	root.add_child(go2)
	await settle()
	state.player_name = "Switcher"
	go2.show_result(4)
	go2._on_change_hero_button_pressed()
	await settle()
	check(names_of().has("Switcher"), "the round is saved before leaving")
	check(current_scene != null and current_scene.scene_file_path == SELECT, "Change Player / Hero opens the hero screen")
	check(current_scene.name_edit.text == "Switcher" and current_scene.stage == "hero", "the hero screen keeps the current player's name")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)

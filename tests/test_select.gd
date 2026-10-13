extends SceneTree

# The hero screen asks for the player's name first. Run:
#   <godot> --headless --path . -s tests/test_select.gd
const SELECT = "res://scenes/select.tscn"
const MAIN = "res://scenes/main.tscn"
const BOARD = "res://scenes/leaderboard.tscn"
const TEST_PATH = "user://test_select.json"
var failures : int = 0
var state
var board

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		print("FAIL  ", msg)
		failures += 1

func key(code: int) -> InputEventKey:
	var ev = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev

func settle() -> void:
	await process_frame
	await process_frame

func make_select():
	var sel = load(SELECT).instantiate()
	root.add_child(sel)
	await settle()
	return sel

func _initialize():
	await process_frame  # autoloads run _ready() (and _load()) on the first frame in a -s script
	state = root.get_node("GameState")
	board = root.get_node("Leaderboard")
	board.save_path = TEST_PATH  # never touch the player's real leaderboard
	board.entries = []
	board.last_name = "Old"
	state.player_name = ""
	state.hero = "boy"

	# a fresh start asks for the name first, pre-filled with the last player
	var sel = await make_select()
	check(sel.stage == "name", "a fresh start begins at the name step")
	check(sel.name_edit.text == "Old", "the name box is pre-filled with the last player: box='%s' last_name='%s' player='%s' stage=%s" % [sel.name_edit.text, board.last_name, state.player_name, sel.stage])
	check(sel.name_edit.has_focus(), "the name box has keyboard focus")

	# a blank name is refused
	sel.name_edit.text = "   "
	sel.name_edit.text_submitted.emit("   ")
	check(sel.stage == "name", "Enter on a blank name stays on the name step")
	check("name" in sel.hint.text.to_lower(), "a blank name shows a nudge: %s" % sel.hint.text)
	sel._start()
	check(state.player_name == "" and (current_scene == null or current_scene.scene_file_path != MAIN), "a blank name cannot start the game")

	# a real name moves on to choosing the hero
	sel.name_edit.text = "  Kai  "
	sel.name_edit.text_submitted.emit("  Kai  ")
	check(sel.stage == "hero", "Enter on a name moves to choosing the hero")
	check(not sel.name_edit.has_focus(), "the name box gives up focus so the arrow keys choose the hero")

	# arrows choose the hero, but only in the hero step
	check(sel.index == 0, "the first hero is selected")
	sel._unhandled_input(key(KEY_RIGHT))
	check(sel.index == 1, "right selects the second hero")
	sel._unhandled_input(key(KEY_RIGHT))
	check(sel.index == 0, "right wraps around")
	sel._unhandled_input(key(KEY_LEFT))
	check(sel.index == 1, "left goes back")
	sel._set_stage("name")
	sel._unhandled_input(key(KEY_RIGHT))
	check(sel.index == 1, "arrows do nothing while typing the name")

	# Tab returns to the name from the hero step
	sel._set_stage("hero")
	sel._unhandled_input(key(KEY_TAB))
	check(sel.stage == "name", "Tab goes back to editing the name")
	sel._set_stage("hero")

	# leaving for the leaderboard remembers the typed name
	sel._open_leaderboard()
	await settle()
	check(state.player_name == "Kai", "opening the leaderboard keeps the trimmed name: %s" % state.player_name)
	check(current_scene != null and current_scene.scene_file_path == BOARD, "the leaderboard opens from the hero screen")

	# coming back with a known player starts at the hero step with the name filled in
	var back = await make_select()
	check(back.stage == "hero" and back.name_edit.text == "Kai", "returning with a known player starts at the hero step")

	# starting saves the trimmed name and the chosen hero, then plays
	back.index = 1
	back._start()
	await settle()
	check(state.player_name == "Kai" and state.hero == "girl", "starting stores the name and hero: %s / %s" % [state.player_name, state.hero])
	check(current_scene != null and current_scene.scene_file_path == MAIN, "starting opens the game")

	# tapping the name box on a TV / phone asks through the browser prompt; on desktop it does not
	var asked = []
	var tap = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	state.player_name = ""
	var tv = await make_select()
	tv.ask_name = func(current): asked.append(current); return "Rin"
	tv.name_edit.text = ""
	tv.prompt_on_tap = false
	tv._on_name_gui_input(tap)
	check(asked.size() == 0, "on desktop a click on the name box does not open the prompt")
	tv.prompt_on_tap = true
	tv._on_name_gui_input(tap)
	check(asked.size() == 1 and tv.name_edit.text == "Rin" and tv.stage == "hero", "on a TV a tap on the name box opens the prompt and uses the answer: '%s'" % tv.name_edit.text)
	tv.queue_free()

	# the browser name prompt (TV / phone): its answer fills the box, a cancel changes nothing
	state.player_name = ""
	var web = await make_select()
	web.name_edit.text = ""
	web._apply_prompt_result(null)
	check(web.stage == "name" and web.name_edit.text == "", "cancelling the name prompt changes nothing")
	web._apply_prompt_result("   ")
	check(web.stage == "name", "a blank prompt answer stays on the name step")
	web._apply_prompt_result("  Mayumi Santos Reyes  ")
	check(web.name_edit.text == "Mayumi Santo", "the prompt answer is trimmed and capped at the box length: '%s'" % web.name_edit.text)
	check(web.stage == "hero", "a good prompt answer moves on to the hero step")
	web.name_edit.text = ""
	web._set_stage("name")
	web.name_edit.text_submitted.emit("")
	check(web.stage == "name" and "name" in web.hint.text.to_lower(), "off the web, Enter on an empty name still shows the nudge")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)

extends SceneTree

# Run headless:  <godot> --headless --path . -s tests/test_audio.gd
const AM = preload("res://scenes/audio_manager.gd")
const TEST_PATH = "user://test_settings.cfg"
var failures : int = 0
var made : Array = []

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		print("FAIL  ", msg)
		failures += 1

func remove_file() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func make():
	var am = AM.new()
	am.settings_path = TEST_PATH
	made.append(am)
	root.add_child(am)
	await process_frame  # _ready() runs on the next frame when added from a script like this
	return am

func key_event(code: int, echo: bool = false) -> InputEventKey:
	var ev = InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.echo = echo
	return ev

func playing_count(am) -> int:
	var n = 0
	for p in am.pool:
		if p.playing:
			n += 1
	return n

func _initialize():  # not _init(): the scene tree must exist so add_child() runs _ready()
	remove_file()
	var master = AudioServer.get_bus_index("Master")
	var am = await make()
	check(not am.muted, "starts unmuted when there is no settings file")
	check(not AudioServer.is_bus_mute(master), "master bus starts unmuted")

	# effects
	am.play("no_such_sound")
	check(playing_count(am) == 0, "an unknown sound name is ignored without a crash")
	am.play("flap")
	check(playing_count(am) == 1, "play('flap') uses one pool player")
	for i in 10:
		am.play("score")
	check(playing_count(am) == am.POOL_SIZE, "more plays than players reuses the pool without a crash")

	# music
	am.start_music()
	check(am.music_player.playing, "start_music() starts the music player")
	am.start_music()
	check(am.music_player.playing, "calling start_music() again keeps it playing")
	am.stop_music()
	check(not am.music_player.playing, "stop_music() stops it")

	# mute switch and its key
	am._unhandled_input(key_event(KEY_M, true))
	check(not am.muted, "a held (echo) M key does not toggle mute")
	am._unhandled_input(key_event(KEY_X))
	check(not am.muted, "other keys do not toggle mute")
	am._unhandled_input(key_event(KEY_M))
	check(am.muted, "pressing M mutes")
	check(AudioServer.is_bus_mute(master), "muting mutes the master bus")
	var again = await make()
	check(again.muted, "mute persists: a new AudioManager loads muted")
	again._unhandled_input(key_event(KEY_M))
	check(not again.muted and not AudioServer.is_bus_mute(master), "pressing M again unmutes")
	var third = await make()
	check(not third.muted, "unmuted state persists too")

	# a damaged settings file falls back to unmuted
	var f = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("this is not a config file [[[")
	f.close()
	var fourth = await make()
	check(not fourth.muted, "a damaged settings file falls back to unmuted")

	AudioServer.set_bus_mute(master, false)
	remove_file()
	for n in made:
		n.free()
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)

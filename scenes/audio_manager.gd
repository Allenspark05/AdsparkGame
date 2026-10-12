extends Node

# Autoload: sound effects, looping music and a saved mute switch (key M).

const SOUNDS = {
	"flap": "res://assets/sounds/flap.wav",
	"score": "res://assets/sounds/score.wav",
	"hit": "res://assets/sounds/hit.wav",
	"gameover": "res://assets/sounds/gameover.wav",
	"tick": "res://assets/sounds/tick.wav",
	"confirm": "res://assets/sounds/confirm.wav",
	"music": "res://assets/sounds/music.wav",
}
const POOL_SIZE : int = 6

var settings_path : String = "user://settings.cfg"
var pool : Array = []
var music_player : AudioStreamPlayer
var streams : Dictionary = {}
var muted : bool = false

func _ready():
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -8.0
	music_player.finished.connect(music_player.play)  # loop by replaying
	add_child(music_player)
	_load_settings()
	_apply_mute()

func _get_stream(sound_name: String):
	if not streams.has(sound_name):
		var path = SOUNDS.get(sound_name, "")
		if path != "" and ResourceLoader.exists(path):
			streams[sound_name] = load(path)
		else:
			streams[sound_name] = null
	return streams[sound_name]

func play(sound_name: String) -> void:
	var stream = _get_stream(sound_name)
	if stream == null:
		return
	for p in pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	pool[0].stream = stream  # every player is busy: reuse the first
	pool[0].play()

func start_music() -> void:
	if music_player.playing:
		return
	var stream = _get_stream("music")
	if stream == null:
		return
	music_player.stream = stream
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func toggle_mute() -> void:
	muted = not muted
	_apply_mute()
	_save_settings()

func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

func _load_settings() -> void:
	muted = false
	var cfg = ConfigFile.new()
	if cfg.load(settings_path) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.save(settings_path)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_mute()

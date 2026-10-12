# Leaderboard and Sounds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Save each run's score to a ranked top-10 leaderboard with name entry and a leaderboard screen, and add synthesized sound effects plus looping music with an M mute key.

**Architecture:** Two new autoloads: `Leaderboard` (score storage behind `_load()`/`_save()`, so an online backend can replace them later) and `AudioManager` (sound pool, music player, mute). The game over screen gets a code-built name-entry panel; a new code-built leaderboard screen follows the same style as `select.gd`. Sound files are generated once by a Python script and saved as `.wav` assets.

**Tech Stack:** Godot 4.7 / GDScript (tabs for indentation), Python 3 with numpy and the standard `wave` module (sound generation and checks only, not shipped).

**Spec:** `docs/superpowers/specs/2026-10-09-leaderboard-sounds-design.md`

## Global Constraints

- Godot 4.7, GDScript, **tab** indentation, matching the existing scripts in `scenes/`.
- Viewport is 864 x 936. The ground starts at y = 768. Keep all UI above y = 768 or intentionally over the ground sprite.
- Autoload names are exactly `GameState` (exists), `Leaderboard` and `AudioManager`, registered in `project.godot` under `[autoload]` as `Name="*res://scenes/<file>.gd"`.
- Leaderboard: top **10** entries, names capped at **12** characters, empty name becomes `"Player"`, file at `user://leaderboard.json`.
- Entry schema: `{"name": String, "score": int, "hero": "boy"|"girl", "date": ISO string}`; file shape `{"entries": [...], "last_name": String}`.
- Sound files live in `assets/sounds/`, named exactly: `flap.wav`, `score.wav`, `hit.wav`, `gameover.wav`, `tick.wav`, `confirm.wav`, `music.wav`. Format 44.1 kHz, 16-bit, mono.
- M toggles mute from any scene and the setting persists in `user://settings.cfg`.
- No network code. No new third-party dependencies in the project.
- The project is **not a git repository**, so there are no commit steps. Each task ends with a checkpoint copy into the scratchpad instead.
- No Godot binary is installed on the development machine. Steps marked **(user)** need the user to run Godot. Do not claim those steps passed.

## Notes versus the spec

- Ties on score: instead of comparing dates, a new entry is inserted after existing entries with an equal score. This gives the same result (earlier run ranks higher) and is deterministic even within one second.
- Music loops by replaying when the player's `finished` signal fires, instead of editing the WAV import loop flags. It is robust to import settings, at the cost of a possible gap of a few milliseconds at the seam.

## Review Focus

Input classes the spec implies but a casual run would not hit, most likely first:

1. A leaderboard file that is corrupted, empty, hand-edited or the wrong JSON type: expect an empty board, no crash (Task 2 tests).
2. Score 0, or a score equal to the lowest entry on a full board: expect it does not qualify (Task 2 tests).
3. Names that are blank, over 12 characters, or contain quotes and backslashes: expect `"Player"`, truncation, and an exact round trip through the file (Task 2 tests).
4. The game over trigger firing twice (pipe hit, then ground hit): expect sounds and the name panel to happen once (Task 4 guard, checked in Task 7).
5. Typing the letter "m" in the name box: expect it types an "m" and does not toggle mute; muted state survives a restart (user check, Task 7).

---

## File Structure

| File | Responsibility |
|---|---|
| `assets/sounds/*.wav` | Seven synthesized audio files (generated, not hand-edited) |
| `scenes/leaderboard.gd` | Autoload: score storage, ranking, qualification rules |
| `scenes/audio_manager.gd` | Autoload: sound pool, music, mute persistence |
| `scenes/game_over.gd`, `game_over.tscn` | Score text, name-entry panel, Leaderboard button |
| `scenes/leaderboard_screen.gd`, `leaderboard.tscn` | Top-10 screen |
| `scenes/main.gd` | Sound triggers, double-stop guard, passes score to game over |
| `scenes/select.gd` | Menu sounds, Leaderboard button and L key |
| `scenes/game_state.gd` | Adds `leaderboard_return` |
| `tests/test_leaderboard.gd` | Headless GDScript tests for the Leaderboard autoload |
| `project.godot` | Two new autoloads |

Scratchpad (not shipped): `$S = /private/tmp/claude-502/-Users-allenlacoste-Downloads-FlappyBird-main/9acfc61f-1da9-43a7-a1db-a8954982325b/scratchpad`, holding `make_sounds.py` and `verify_sounds.py`. Python needs `sys.path.insert(0, "$S/pylib")` for numpy (already installed there). Run Python as `python3 -I script.py` from `$S`.

---

### Task 1: Synthesized sound assets

**Files:**
- Create: `$S/verify_sounds.py`
- Create: `$S/make_sounds.py`
- Create: `assets/sounds/flap.wav`, `score.wav`, `hit.wav`, `gameover.wav`, `tick.wav`, `confirm.wav`, `music.wav` (generated)

**Interfaces:**
- Consumes: nothing.
- Produces: the seven file names above under `res://assets/sounds/`, used verbatim by `AudioManager` in Task 3.

- [ ] **Step 1: Write the verification script (the failing test)**

Create `$S/verify_sounds.py`:

```python
import sys
sys.path.insert(0, "/private/tmp/claude-502/-Users-allenlacoste-Downloads-FlappyBird-main/9acfc61f-1da9-43a7-a1db-a8954982325b/scratchpad/pylib")
import wave
import numpy as np

OUT = "/Users/allenlacoste/Downloads/FlappyBird-main/assets/sounds/"
# name: (min seconds, max seconds, max start/end sample magnitude)
EXPECT = {
    "flap.wav": (0.10, 0.40, 600),
    "score.wav": (0.15, 0.60, 600),
    "hit.wav": (0.10, 0.50, 600),
    "gameover.wav": (0.60, 2.50, 600),
    "tick.wav": (0.02, 0.15, 600),
    "confirm.wav": (0.10, 0.50, 600),
    "music.wav": (19.5, 20.5, 400),
}
failures = 0
for name, (lo, hi, edge) in EXPECT.items():
    try:
        with wave.open(OUT + name, "rb") as f:
            ch, sw, sr, n = f.getnchannels(), f.getsampwidth(), f.getframerate(), f.getnframes()
            data = np.frombuffer(f.readframes(n), dtype="<i2")
    except FileNotFoundError:
        print("FAIL  %s missing" % name)
        failures += 1
        continue
    dur = n / sr
    peak = np.abs(data).max() / 32767.0
    problems = []
    if (ch, sw, sr) != (1, 2, 44100):
        problems.append("format %s/%s/%s" % (ch, sw, sr))
    if not lo <= dur <= hi:
        problems.append("duration %.2fs outside %.2f-%.2f" % (dur, lo, hi))
    if not 0.25 <= peak <= 0.98:
        problems.append("peak %.2f outside 0.25-0.98" % peak)
    if abs(int(data[0])) > edge or abs(int(data[-1])) > edge:
        problems.append("edges not silent: %d, %d" % (data[0], data[-1]))
    if problems:
        failures += 1
        print("FAIL  %s: %s" % (name, "; ".join(problems)))
    else:
        print("PASS  %s  %.2fs  peak %.2f" % (name, dur, peak))
sys.exit(1 if failures else 0)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd $S && python3 -I verify_sounds.py`
Expected: seven `FAIL ... missing` lines, exit code 1.

- [ ] **Step 3: Write the generator**

Create `$S/make_sounds.py`:

```python
import sys
sys.path.insert(0, "/private/tmp/claude-502/-Users-allenlacoste-Downloads-FlappyBird-main/9acfc61f-1da9-43a7-a1db-a8954982325b/scratchpad/pylib")
import os
import wave
import numpy as np

SR = 44100
OUT = "/Users/allenlacoste/Downloads/FlappyBird-main/assets/sounds/"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def tone(freq, dur, shape="sine", a=0.004, r=0.03, decay=0.0):
    """freq is a number (Hz) or an array with one value per sample (for sweeps)."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    if np.isscalar(freq):
        phase = 2 * np.pi * freq * t
    else:
        phase = 2 * np.pi * np.cumsum(freq) / SR
    if shape == "sine":
        w = np.sin(phase)
    else:  # triangle
        w = 2 / np.pi * np.arcsin(np.sin(phase))
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    if decay > 0:
        e *= np.exp(-decay * t)
    return w * e


def save(name, x, peak=0.8):
    x = x / np.max(np.abs(x)) * peak
    data = (x * 32767).astype("<i2")
    with wave.open(OUT + name, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# flap: a quick downward "whoomp"
n = int(SR * 0.18)
save("flap.wav", tone(np.linspace(520, 200, n), 0.18, "sine", a=0.004, r=0.05, decay=8), 0.7)

# score: a bright two-note ding
ding = np.concatenate([tone(880, 0.07, "sine", r=0.02),
                       tone(1320, 0.20, "sine", r=0.12, decay=6)])
save("score.wav", ding, 0.7)

# hit: noise burst plus a low thump (short fade in and out so the edges are silent)
n = int(SR * 0.25)
t = np.arange(n) / SR
thump = np.sin(2 * np.pi * 90 * t) * np.exp(-14 * t)
noise = rng.standard_normal(n) * np.exp(-30 * t)
hit = thump + 0.6 * noise
fade_in, fade_out = int(0.003 * SR), int(0.02 * SR)
hit[:fade_in] *= np.linspace(0, 1, fade_in)
hit[-fade_out:] *= np.linspace(1, 0, fade_out)
save("hit.wav", hit, 0.85)

# game over: a descending minor motif (A4 F4 D4 A3)
notes = [(440.0, 0.22), (349.2, 0.22), (293.7, 0.22), (220.0, 0.55)]
go = np.concatenate([tone(f, d, "tri", a=0.01, r=0.08, decay=2.5) for f, d in notes])
save("gameover.wav", go, 0.75)

# menu tick and confirm
save("tick.wav", tone(1000, 0.04, "sine", a=0.002, r=0.02), 0.5)
save("confirm.wav", np.concatenate([tone(660, 0.07, "sine", r=0.02),
                                    tone(990, 0.12, "sine", r=0.08, decay=8)]), 0.65)

# music: 20 s loop at 96 BPM, A minor: Am - F - G - Em, 8 beats each
BEAT = 60 / 96
EIGHTH = BEAT / 2
TOTAL = int(round(SR * 64 * EIGHTH))  # 64 eighth notes = 20.0 s
buf = np.zeros(TOTAL)
chords = [(45, [57, 60, 64]), (41, [53, 57, 60]), (43, [55, 59, 62]), (40, [52, 55, 59])]
pattern = [0, 1, 2, 1] * 4  # 16 eighth notes per chord
for ci, (bass, arp) in enumerate(chords):
    for k in range(16):
        start = int(round((ci * 16 + k) * EIGHTH * SR))
        note = arp[pattern[k]] + (12 if k % 8 == 7 else 0)
        w = tone(midi(note), EIGHTH, "tri", a=0.004, r=0.06, decay=4)
        buf[start:start + len(w)] += 0.5 * w[:TOTAL - start]
    for beat in range(8):
        start = int(round((ci * 8 + beat) * BEAT * SR))
        w = tone(midi(bass), BEAT, "sine", a=0.01, r=0.1, decay=1.5)
        buf[start:start + len(w)] += 0.7 * w[:TOTAL - start]
save("music.wav", buf, 0.5)
print("ok")
```

- [ ] **Step 4: Generate and re-run the verification**

Run: `cd $S && python3 -I make_sounds.py && python3 -I verify_sounds.py`
Expected: `ok`, then seven `PASS` lines, exit code 0. If a file fails, adjust that sound's fades in `make_sounds.py` and regenerate. Do not loosen the checks.

- [ ] **Step 5: Checkpoint**

Run: `mkdir -p $S/backup-task1 && cp -R /Users/allenlacoste/Downloads/FlappyBird-main/assets/sounds $S/backup-task1/`

---

### Task 2: Leaderboard autoload with tests

**Files:**
- Create: `tests/test_leaderboard.gd`
- Create: `scenes/leaderboard.gd`
- Modify: `project.godot` (add autoload line)

**Interfaces:**
- Consumes: nothing.
- Produces (used by Tasks 5 and 6): autoload `Leaderboard` with
  - `var save_path : String = "user://leaderboard.json"`
  - `var last_name : String`
  - `func qualifies(score: int) -> bool`
  - `func submit(player_name: String, score: int, hero: String) -> void`
  - `func top(n: int = 10) -> Array` (each element a Dictionary with `name`, `score`, `hero`, `date`)
  - `func best() -> int`
  - `func _load() -> void`, `func _save() -> void` (the storage swap point)

- [ ] **Step 1: Write the failing tests**

Create `tests/test_leaderboard.gd`:

```gdscript
extends SceneTree

# Run headless:  <godot> --headless --path . -s tests/test_leaderboard.gd
const LB = preload("res://scenes/leaderboard.gd")
const TEST_PATH = "user://test_leaderboard.json"
var failures : int = 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		print("FAIL  ", msg)
		failures += 1

func remove_file() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func write_raw(text: String) -> void:
	var f = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func fresh():
	remove_file()
	var lb = LB.new()
	lb.save_path = TEST_PATH
	lb._load()
	return lb

func reload():
	var lb = LB.new()
	lb.save_path = TEST_PATH
	lb._load()
	return lb

func _init():
	# empty board
	var lb = fresh()
	check(lb.top().size() == 0, "empty board has no entries")
	check(lb.best() == 0, "best() is 0 on an empty board")
	check(not lb.qualifies(0), "score 0 never qualifies")
	check(lb.qualifies(1), "score 1 qualifies on an empty board")

	# ranking and ties (earlier run stays ahead)
	lb.submit("A", 5, "boy")
	lb.submit("B", 9, "girl")
	lb.submit("C", 5, "boy")
	var names = []
	for e in lb.top():
		names.append(e["name"])
	check(names == ["B", "A", "C"], "ranked by score, ties keep the earlier run first: %s" % [names])
	check(lb.best() == 9, "best() is the top score")

	# trimming to 10 and the qualify boundary
	lb = fresh()
	for i in range(1, 13):
		lb.submit("P%d" % i, i, "boy")
	check(lb.top().size() == 10, "board is trimmed to 10 entries")
	check(lb.top()[9]["score"] == 3, "lowest kept score is 3 after 12 submissions")
	check(not lb.qualifies(3), "a score equal to the lowest on a full board does not qualify")
	check(lb.qualifies(4), "a score above the lowest on a full board qualifies")
	check(lb.top(3).size() == 3, "top(3) returns three entries")

	# names
	lb = fresh()
	lb.submit("   ", 4, "boy")
	check(lb.top()[0]["name"] == "Player", "blank name becomes Player")
	lb.submit("ABCDEFGHIJKLMNOP", 3, "boy")
	check(lb.top()[1]["name"] == "ABCDEFGHIJKL", "names are capped at 12 characters")
	var tricky = 'Sam "the" \\ \'x\''.substr(0, 12)
	lb.submit('Sam "the" \\ \'x\'', 2, "girl")
	var again = reload()
	check(again.top()[2]["name"] == tricky, "quotes and backslashes round-trip through the file")

	# persistence
	lb = fresh()
	lb.submit("Kai", 7, "girl")
	again = reload()
	check(again.top().size() == 1 and again.top()[0]["score"] == 7, "entries persist across loads")
	check(again.last_name == "Kai", "last_name persists across loads")
	check(again.top()[0]["hero"] == "girl", "hero persists across loads")

	# damaged files never crash and give an empty board
	for bad in ["", "{not json", "[]", "42", '{"entries": "oops"}', '{"entries": [1, 2, {"x": 1}]}']:
		write_raw(bad)
		var broken = reload()
		check(broken.top().size() == 0, "damaged file gives an empty board: %s" % bad)
	write_raw('{"entries": [{"name": "Ok", "score": 3}, {"name": "NoScore"}], "last_name": "Ok"}')
	var partial = reload()
	check(partial.top().size() == 1 and partial.top()[0]["name"] == "Ok", "entries missing fields are skipped, valid ones kept")

	remove_file()
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
```

- [ ] **Step 2: Run to verify it fails**

Run **(user)**: `<path-to-Godot> --headless --path /Users/allenlacoste/Downloads/FlappyBird-main -s tests/test_leaderboard.gd`
Expected: a script error that `res://scenes/leaderboard.gd` cannot be preloaded, and a non-zero exit. (If no Godot is available, record that this step could not run.)

- [ ] **Step 3: Write the implementation**

Create `scenes/leaderboard.gd`:

```gdscript
extends Node

# Autoload: local top-10 leaderboard.
# Only _load() and _save() touch storage, so an online backend can replace them later.

const MAX_ENTRIES : int = 10
const MAX_NAME : int = 12

var save_path : String = "user://leaderboard.json"
var entries : Array = []
var last_name : String = ""

func _ready():
	_load()

func qualifies(score: int) -> bool:
	if score <= 0:
		return false
	if entries.size() < MAX_ENTRIES:
		return true
	return score > entries[entries.size() - 1]["score"]

func submit(player_name: String, score: int, hero: String) -> void:
	var clean = player_name.strip_edges().substr(0, MAX_NAME)
	if clean == "":
		clean = "Player"
	_insert({
		"name": clean,
		"score": score,
		"hero": hero,
		"date": Time.get_datetime_string_from_system(),
	})
	last_name = clean
	_save()

func top(n: int = MAX_ENTRIES) -> Array:
	return entries.slice(0, n)

func best() -> int:
	if entries.is_empty():
		return 0
	return entries[0]["score"]

# Insert after every entry with an equal or higher score, so an earlier run keeps its rank.
func _insert(entry: Dictionary) -> void:
	var idx = entries.size()
	for i in entries.size():
		if entry["score"] > entries[i]["score"]:
			idx = i
			break
	entries.insert(idx, entry)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)

func _load() -> void:
	entries = []
	last_name = ""
	if not FileAccess.file_exists(save_path):
		return
	var f = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw = parsed.get("entries", [])
	if typeof(raw) == TYPE_ARRAY:
		for e in raw:
			if typeof(e) == TYPE_DICTIONARY and e.has("name") and e.has("score"):
				_insert({
					"name": str(e["name"]).substr(0, MAX_NAME),
					"score": int(e["score"]),
					"hero": str(e.get("hero", "boy")),
					"date": str(e.get("date", "")),
				})
	last_name = str(parsed.get("last_name", "")).substr(0, MAX_NAME)

func _save() -> void:
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Leaderboard: could not save scores, keeping them in memory")
		return
	f.store_string(JSON.stringify({"entries": entries, "last_name": last_name}))
```

- [ ] **Step 4: Register the autoload**

In `project.godot`, under `[autoload]`, add a line so the section reads:

```
[autoload]

GameState="*res://scenes/game_state.gd"
Leaderboard="*res://scenes/leaderboard.gd"
```

- [ ] **Step 5: Run the tests to verify they pass**

Run **(user)**: `<path-to-Godot> --headless --path /Users/allenlacoste/Downloads/FlappyBird-main -s tests/test_leaderboard.gd`
Expected: every line `PASS`, final `FAILURES: 0`, exit code 0. If the development machine has no Godot, state plainly that the tests are written but unrun, and ask the user to run this command.

- [ ] **Step 6: Checkpoint**

Run: `mkdir -p $S/backup-task2 && cp -R /Users/allenlacoste/Downloads/FlappyBird-main/scenes /Users/allenlacoste/Downloads/FlappyBird-main/tests /Users/allenlacoste/Downloads/FlappyBird-main/project.godot $S/backup-task2/`

---

### Task 3: AudioManager autoload

**Files:**
- Create: `scenes/audio_manager.gd`
- Modify: `project.godot` (add autoload line)

**Interfaces:**
- Consumes: the seven sound files from Task 1.
- Produces (used by Tasks 4, 5, 6): autoload `AudioManager` with
  - `func play(sound_name: String) -> void` (names: `flap`, `score`, `hit`, `gameover`, `tick`, `confirm`; unknown or missing names are silently ignored)
  - `func start_music() -> void` (does nothing if already playing)
  - `func stop_music() -> void`
  - `func toggle_mute() -> void`
  - `var muted : bool`

- [ ] **Step 1: Write the implementation**

Create `scenes/audio_manager.gd`:

```gdscript
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
const SETTINGS_PATH : String = "user://settings.cfg"

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
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS_PATH)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_mute()
```

- [ ] **Step 2: Register the autoload**

In `project.godot`, add one more line under `[autoload]`:

```
AudioManager="*res://scenes/audio_manager.gd"
```

- [ ] **Step 3: Static check**

Run: `cd /Users/allenlacoste/Downloads/FlappyBird-main && grep -n "^GameState\|^Leaderboard\|^AudioManager" project.godot && for f in flap score hit gameover tick confirm music; do [ -f assets/sounds/$f.wav ] && echo "ok $f" || echo "MISSING $f"; done`
Expected: three autoload lines and seven `ok` lines.

- [ ] **Step 4: Checkpoint**

Run: `mkdir -p $S/backup-task3 && cp -R /Users/allenlacoste/Downloads/FlappyBird-main/scenes /Users/allenlacoste/Downloads/FlappyBird-main/project.godot $S/backup-task3/`

---

### Task 4: Hook sounds into the game and menu

**Files:**
- Modify: `scenes/main.gd` (functions `_ready`, `start_game`, `flap_or_start`, `scored`, `stop_game`)
- Modify: `scenes/select.gd` (functions `_ready`, `_on_card_hover`, `_unhandled_input`, `_start`)

**Interfaces:**
- Consumes: `AudioManager.play(name)`, `AudioManager.start_music()` from Task 3.
- Produces: `stop_game()` in `main.gd` now ignores a second call (used by Task 5, which adds the result call inside it).

- [ ] **Step 1: Edit `scenes/main.gd`**

In `_ready()`, add `AudioManager.start_music()` as the last line:

```gdscript
func _ready():
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	new_game()
	AudioManager.start_music()
```

In `start_game()`, add the flap sound after the first flap:

```gdscript
func start_game():
	game_running = true
	$Bird.flying = true
	$Bird.flap()
	AudioManager.play("flap")
	#start pipe timer
	$PipeTimer.start()
```

In `flap_or_start()`, add the sound to the flap branch:

```gdscript
func flap_or_start():
	if game_running == false:
		start_game()
	elif $Bird.flying:
		$Bird.flap()
		AudioManager.play("flap")
		check_top()
```

In `scored()`:

```gdscript
func scored():
	score += 1
	$ScoreLabel.text = "SCORE: " + str(score)
	AudioManager.play("score")
```

Replace `stop_game()` with a guarded version (a pipe hit followed by a ground hit calls it twice):

```gdscript
func stop_game():
	if game_over:
		return
	$PipeTimer.stop()
	$GameOver.show()
	$Bird.flying = false
	game_running = false
	game_over = true
	AudioManager.play("hit")
	get_tree().create_timer(0.35).timeout.connect(func(): AudioManager.play("gameover"))
```

- [ ] **Step 2: Edit `scenes/select.gd`**

At the end of `_ready()` (after `_refresh()`), add `AudioManager.start_music()`.

Replace `_on_card_hover`:

```gdscript
func _on_card_hover(i: int):
	if i != index:
		AudioManager.play("tick")
	index = i
	_refresh()
```

Replace `_unhandled_input`:

```gdscript
func _unhandled_input(event):
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
```

Replace `_start`:

```gdscript
func _start():
	AudioManager.play("confirm")
	GameState.hero = HEROES[index].id
	get_tree().change_scene_to_file("res://scenes/main.tscn")
```

- [ ] **Step 3: Static check**

Run: `cd /Users/allenlacoste/Downloads/FlappyBird-main && grep -n "AudioManager" scenes/main.gd scenes/select.gd && grep -n -A2 "func stop_game" scenes/main.gd`
Expected: sound calls in `main.gd` (`_ready`, `start_game`, `flap_or_start`, `scored`, `stop_game`) and `select.gd` (`_ready`, hover, left/right, `_start`), and `if game_over:` as the first line of `stop_game`.

- [ ] **Step 4: Checkpoint**

Run: `mkdir -p $S/backup-task4 && cp -R /Users/allenlacoste/Downloads/FlappyBird-main/scenes $S/backup-task4/`

---

### Task 5: Game over: score text, name entry, Leaderboard button

**Files:**
- Modify: `scenes/game_over.gd` (full replacement below)
- Modify: `scenes/game_over.tscn` (add `LeaderboardButton`)
- Modify: `scenes/main.gd` (`stop_game` calls `show_result`)
- Modify: `scenes/game_state.gd` (add `leaderboard_return`)

**Interfaces:**
- Consumes: `Leaderboard.qualifies/submit/best/last_name`, `AudioManager.play`, `GameState.hero`.
- Produces: `GameOver.show_result(score: int) -> void`; `GameState.leaderboard_return : String` (a scene path, set before opening the leaderboard screen in Task 6).

- [ ] **Step 1: Add the return-scene variable**

In `scenes/game_state.gd`, append:

```gdscript

# Scene to return to when the leaderboard screen's Back button is pressed.
var leaderboard_return : String = "res://scenes/select.tscn"
```

- [ ] **Step 2: Replace `scenes/game_over.gd`**

```gdscript
extends CanvasLayer

signal restart

var score_label : Label
var name_panel : Panel
var name_edit : LineEdit
var pending_score : int = 0

func _ready():
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color(1, 1, 1))
	score_label.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.2))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.position = Vector2(0, 270)
	score_label.size = Vector2(864, 50)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(score_label)
	_build_name_panel()

func _build_name_panel():
	name_panel = Panel.new()
	name_panel.position = Vector2(212, 570)
	name_panel.size = Vector2(440, 150)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.03, 0.16, 0.92)
	sb.border_color = Color(1.0, 0.6, 0.15)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	name_panel.add_theme_stylebox_override("panel", sb)
	add_child(name_panel)

	var title = Label.new()
	title.text = "NEW HIGH SCORE! Enter your name"
	title.add_theme_font_size_override("font_size", 22)
	title.position = Vector2(0, 12)
	title.size = Vector2(440, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_panel.add_child(title)

	name_edit = LineEdit.new()
	name_edit.max_length = 12
	name_edit.placeholder_text = "Your name"
	name_edit.position = Vector2(60, 52)
	name_edit.size = Vector2(320, 40)
	name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_panel.add_child(name_edit)

	var submit_button = Button.new()
	submit_button.text = "Submit"
	submit_button.position = Vector2(60, 102)
	submit_button.size = Vector2(150, 36)
	submit_button.focus_mode = Control.FOCUS_NONE
	submit_button.pressed.connect(_submit)
	name_panel.add_child(submit_button)

	var skip_button = Button.new()
	skip_button.text = "Skip"
	skip_button.position = Vector2(230, 102)
	skip_button.size = Vector2(150, 36)
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.pressed.connect(_skip)
	name_panel.add_child(skip_button)

	name_panel.hide()

# Called by main.gd the moment the round ends.
func show_result(score: int) -> void:
	pending_score = score
	_refresh_score_text()
	if Leaderboard.qualifies(score):
		name_edit.text = Leaderboard.last_name
		name_panel.show()
		name_edit.grab_focus()
		name_edit.caret_column = name_edit.text.length()
	else:
		name_panel.hide()

func _refresh_score_text():
	score_label.text = "SCORE: %d     BEST: %d" % [pending_score, maxi(pending_score, Leaderboard.best())]

func _on_name_submitted(_text: String) -> void:
	_submit()

func _submit() -> void:
	Leaderboard.submit(name_edit.text, pending_score, GameState.hero)
	AudioManager.play("confirm")
	name_panel.hide()
	_refresh_score_text()

func _skip() -> void:
	AudioManager.play("tick")
	name_panel.hide()

func _on_restart_button_pressed():
	restart.emit()

func _on_change_hero_button_pressed():
	get_tree().change_scene_to_file("res://scenes/select.tscn")

func _on_leaderboard_button_pressed():
	if name_panel.visible:
		_submit()  # don't lose a score the player was about to enter
	GameState.leaderboard_return = "res://scenes/main.tscn"
	get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")
```

- [ ] **Step 3: Add the button to `scenes/game_over.tscn`**

Insert this node before the `[connection ...]` lines (after `ChangeHeroButton`), and add its connection after the existing ones:

```
[node name="LeaderboardButton" type="Button" parent="."]
offset_left = 342.0
offset_top = 495.0
offset_right = 502.0
offset_bottom = 545.0
theme_override_font_sizes/font_size = 24
text = "Leaderboard"
```

```
[connection signal="pressed" from="LeaderboardButton" to="." method="_on_leaderboard_button_pressed"]
```

- [ ] **Step 4: Pass the score from `main.gd`**

In `stop_game()`, call `show_result` right after `$GameOver.show()`:

```gdscript
func stop_game():
	if game_over:
		return
	$PipeTimer.stop()
	$GameOver.show()
	$GameOver.show_result(score)
	$Bird.flying = false
	game_running = false
	game_over = true
	AudioManager.play("hit")
	get_tree().create_timer(0.35).timeout.connect(func(): AudioManager.play("gameover"))
```

- [ ] **Step 5: Static check**

Run: `cd /Users/allenlacoste/Downloads/FlappyBird-main && grep -n "show_result\|_on_leaderboard_button_pressed\|leaderboard_return" scenes/*.gd scenes/game_over.tscn`
Expected: `show_result` defined in `game_over.gd` and called in `main.gd`; the `_on_leaderboard_button_pressed` method and the connection line both present; `leaderboard_return` in `game_state.gd` and `game_over.gd`.

- [ ] **Step 6: Checkpoint**

Run: `mkdir -p $S/backup-task5 && cp -R /Users/allenlacoste/Downloads/FlappyBird-main/scenes $S/backup-task5/`

---

### Task 6: Leaderboard screen and its entry points

**Files:**
- Create: `scenes/leaderboard_screen.gd`
- Create: `scenes/leaderboard.tscn`
- Modify: `scenes/select.gd` (hint position and text, Leaderboard button, L key)

**Interfaces:**
- Consumes: `Leaderboard.top(n)`, `GameState.leaderboard_return`, `AudioManager.play`, the portrait images `res://assets/portrait_boy.png` and `portrait_girl.png`.
- Produces: scene `res://scenes/leaderboard.tscn`, opened by Task 5's button and by this task's select-screen button.

- [ ] **Step 1: Create `scenes/leaderboard_screen.gd`**

```gdscript
extends Control

const ROWS : int = 10
const ROW_Y : int = 190
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

	_label("LEADERBOARD", Vector2(0, 90), 864, HORIZONTAL_ALIGNMENT_CENTER, 52, Color(1.0, 0.6, 0.15))

	var panel = Panel.new()
	panel.position = Vector2(96, 176)
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
	back.position = Vector2(316, 692)
	back.size = Vector2(232, 48)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_back)
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
```

- [ ] **Step 2: Create `scenes/leaderboard.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/leaderboard_screen.gd" id="1_lbscreen"]

[node name="LeaderboardScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_lbscreen")
```

- [ ] **Step 3: Add the entry points in `scenes/select.gd`**

Move the hint up and update its text. In `_ready()`, change the hint block to:

```gdscript
	var hint = Label.new()
	hint.text = "LEFT / RIGHT choose    ENTER start    L leaderboard    M mute"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(1, 1, 1))
	hint.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.2))
	hint.add_theme_constant_override("outline_size", 8)
	hint.position = Vector2(0, 676)
	hint.size = Vector2(864, 32)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	var lb_button = Button.new()
	lb_button.text = "Leaderboard (L)"
	lb_button.add_theme_font_size_override("font_size", 22)
	lb_button.position = Vector2(314, 716)
	lb_button.size = Vector2(236, 44)
	lb_button.focus_mode = Control.FOCUS_NONE
	lb_button.pressed.connect(_open_leaderboard)
	add_child(lb_button)
```

Add the L key as a new branch in `_unhandled_input` (after the `ui_accept` branch):

```gdscript
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_open_leaderboard()
```

Add the new function at the end of the file:

```gdscript
func _open_leaderboard():
	AudioManager.play("confirm")
	GameState.leaderboard_return = "res://scenes/select.tscn"
	get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")
```

- [ ] **Step 4: Static check**

Run: `cd /Users/allenlacoste/Downloads/FlappyBird-main && grep -n "leaderboard_screen\|leaderboard.tscn" scenes/*.gd scenes/*.tscn && ls scenes/leaderboard_screen.gd scenes/leaderboard.tscn`
Expected: `leaderboard.tscn` loaded from `game_over.gd` and `select.gd`, `leaderboard_screen.gd` referenced from the `.tscn`, and both files listed.

- [ ] **Step 5: Checkpoint**

Run: `mkdir -p $S/backup-task6 && cp -R /Users/allenlacoste/Downloads/FlappyBird-main/scenes $S/backup-task6/`

---

### Task 7: Final verification and handoff

**Files:** none changed unless a check fails.

- [ ] **Step 1: Check every referenced file exists**

Run: `cd /Users/allenlacoste/Downloads/FlappyBird-main && grep -rhoE 'res://[A-Za-z0-9_./-]+' scenes project.godot | sort -u | while read p; do f="${p#res://}"; [ -e "$f" ] || echo "MISSING $p"; done`
Expected: no output, apart from `res://icon.svg` if it was already missing before this work (check with `ls icon.svg`; it is not part of this change).

- [ ] **Step 2: Check the double-stop guard and tab indentation**

Run: `cd /Users/allenlacoste/Downloads/FlappyBird-main && grep -n -A1 "func stop_game" scenes/main.gd && grep -nP '^ +[^ ]' scenes/leaderboard.gd scenes/audio_manager.gd scenes/game_over.gd scenes/leaderboard_screen.gd scenes/select.gd scenes/main.gd scenes/game_state.gd tests/test_leaderboard.gd || echo "no space-indented lines"`
Expected: `if game_over:` right after `func stop_game`, and `no space-indented lines`. Fix any space-indented line to tabs.

- [ ] **Step 3: Re-run the sound checks**

Run: `cd $S && python3 -I verify_sounds.py`
Expected: seven `PASS`, exit code 0.

- [ ] **Step 4: Report honestly, then hand the user this run checklist (user)**

Tell the user which checks passed (sound files, static checks) and which could not run (Godot tests, the game itself). Ask them to open the project in Godot, press F5, and confirm:

1. Music plays on the hero screen; M mutes and unmutes; the mute survives closing and reopening the game.
2. Arrow keys move the highlight with a tick; Enter plays a confirm sound and starts the game.
3. Space flaps with a "whoomp"; passing a pipe plays a ding; hitting a pipe or the ground plays a thud, then the game over motif once (not twice).
4. A score above 0 shows "NEW HIGH SCORE! Enter your name"; typing a name (including the letter "m" and spaces) works and does not mute or flap; Enter or Submit saves it; Skip hides the box.
5. The Leaderboard button on the game over screen and on the hero screen (or key L) opens the top 10, ranked, with hero icons; Back or Esc returns to the correct screen.
6. Closing and reopening the game keeps the leaderboard.
7. Optional: run the unit tests with `<path-to-Godot> --headless --path <project> -s tests/test_leaderboard.gd` and expect `FAILURES: 0`.

If any check fails, ask the user to paste the error or describe the behavior, and fix it task by task.

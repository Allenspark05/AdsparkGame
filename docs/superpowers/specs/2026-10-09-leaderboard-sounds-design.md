# Leaderboard and Sounds: Design

Date: 2026-10-09. Project: AdSpark Halloween Flappy Bird (Godot 4.7, GDScript).

## Goal

Save each run's final score to a ranked leaderboard that players can view, and add sound
effects plus background music to the game. Scores are stored locally now, behind a small
swap point so an online backend can replace it later without touching the game.

## Decisions (agreed with the user)

- Storage: local file now, online later (the interface stays stable, only storage changes).
- Name entry: free text, up to 12 characters (not 3-letter initials).
- Entries kept: top 10.
- Music: on by default, **M** toggles mute for all audio, and the setting is saved.
- Sounds are synthesized by a script and saved as `.wav` files. They are simple retro
  style sounds; the user can swap in their own files with the same names later.

## Revision: one name per player (supersedes the name box after a run)

The first version asked for a name in a box after each qualifying run. It was replaced:

- The hero screen asks for the **name first** (step 1: type it and press Enter; step 2: choose the hero
  with the arrow keys and press Enter; Tab goes back to the name). A blank name is refused. The name is
  kept in `GameState.player_name`, and coming back to the hero screen (Change Player / Hero) keeps it.
- A finished round is **recorded automatically**: `Leaderboard.record(name, score, hero)` replaces the
  `qualifies()`/`submit()` pair. There is one row per player (their best score, matched ignoring case);
  a lower or equal score changes nothing and a zero score is never recorded. Every player is stored
  (so ranks beyond ten work, capped at 500 rows); the screens show the top 10.
- `record()` returns `{rank (0 = not on the board), total, is_best, best}`. The game over screen shows
  `SCORE / BEST`, a "NEW PERSONAL BEST!" banner when `is_best`, and "You are #rank of total".
- The name box on the game over screen is gone, so Restart, Change Player / Hero and Leaderboard simply
  leave. Names are trimmed, cut to 12 characters and trimmed again; blank becomes "Player".
- Loading is tolerant of hand-edited files: bad scores, null names and a null `last_name` are skipped or
  defaulted, and duplicate players in an old file merge to their best.

## Non-goals

- No online or network code, no accounts, no anti-cheat. Local scores are trusted.
- No per-hero separate boards. One board; each entry records which hero was used.
- No settings screen. The only setting is mute (key M).

## Components

### 1. `scenes/leaderboard.gd` (autoload `Leaderboard`)

Public API, the only thing the rest of the game uses:

- `qualifies(score: int) -> bool`: true if `score > 0` and the board has fewer than 10
  entries or `score` beats the lowest entry.
- `submit(player_name: String, score: int, hero: String) -> void`: adds an entry, sorts,
  trims to 10, saves.
- `top(n: int = 10) -> Array`: entries as dictionaries, best first.
- `best() -> int`: highest score on the board, or 0.
- `last_name: String`: the most recently submitted name, used to pre-fill the name box.

Entry schema (JSON in `user://leaderboard.json`):

```json
{"entries": [{"name": "Sam", "score": 12, "hero": "girl", "date": "2026-10-09T14:03:00"}],
 "last_name": "Sam"}
```

Ordering: score descending, then date ascending (the earlier run ranks higher on a tie).
Name is trimmed, empty names become "Player", and the length is capped at 12.

Swap point: only `_load()` and `_save()` touch storage. A missing, empty or corrupted
file yields an empty board and never raises. An online backend later replaces those two
functions (and may make the API calls asynchronous), and nothing else changes.

### 2. Game over flow (`scenes/game_over.gd`, `game_over.tscn`)

- Shows the final score and the current best.
- If `Leaderboard.qualifies(score)`, shows a name panel: a `LineEdit` (max 12 chars,
  pre-filled with `last_name`), a Submit button (Enter also submits) and a Skip button.
- After submit or skip, the existing Restart and Change Hero buttons stay, and a new
  **Leaderboard** button opens the leaderboard screen.
- `main.gd` already ignores input while `game_over` is true, so typing a space in the name
  box cannot flap the bird.
- `main.gd` passes the final score to the game over screen via a new `show_result(score)`
  call at the moment it stops the game.

### 3. Leaderboard screen (`scenes/leaderboard.tscn`, `scenes/leaderboard_screen.gd`)

- Built in code like `select.gd`: Halloween background and ground sprites, a title,
  and ten rows (rank, hero icon, name, score). Empty rows show a dash.
- Back button and Esc return to the scene it was opened from. The opener is remembered in
  `GameState.leaderboard_return` as a scene path.
- Opened from a **Leaderboard** button on the game over screen and on the hero select
  screen (also key **L** on the select screen).

### 4. Audio (`scenes/audio_manager.gd`, autoload `AudioManager`)

- API: `play(sound_name: String)`, `start_music()`, `stop_music()`, `toggle_mute()`.
- Sounds in `assets/sounds/`: `flap.wav`, `score.wav`, `hit.wav`, `gameover.wav`,
  `tick.wav` (menu move), `confirm.wav` (menu choose), `music.wav` (about 20 s loop).
- A small pool of `AudioStreamPlayer` nodes so overlapping effects do not cut each other
  off. Music uses its own player with loop enabled.
- Mute is applied by muting the Master bus and is saved in `user://settings.cfg`. Key **M**
  toggles it from any scene (`_unhandled_input` in the autoload).
- Hooks:
  - `main.gd`: flap (on flap), score (in `scored()`), hit then game over (in `stop_game()`).
  - `select.gd`: tick (on move) and confirm (on start).
  - Leaderboard screen: tick on navigation, confirm on Back.
- Music starts when the select screen loads and keeps playing across scene changes, since
  it lives in the autoload. It is not restarted if already playing.

### 5. Sound generation

A hand-run Python script (kept outside the project, using numpy and the standard `wave`
module) synthesizes the `.wav` files: 44.1 kHz, 16-bit, mono. Effects use short
envelopes (flap: quick downward chirp, score: two-note ding, hit: noise burst with low
thump, game over: descending minor motif). Music is a looped minor-key arpeggio with a
bass line, with start and end samples matched so the loop does not click.

## Data flow

1. Round ends, `stop_game()` plays hit then game over, and calls
   `GameOver.show_result(score)`.
2. If it qualifies, the name panel appears. Submit calls `Leaderboard.submit(...)`, which
   writes `user://leaderboard.json`.
3. The Leaderboard button opens the board, which reads `Leaderboard.top(10)`.

## Error handling

- Unreadable or corrupted leaderboard file: start empty, overwrite on the next save.
- Missing sound file: skip playback quietly (guard with `ResourceLoader.exists`).
- Failed save (read-only disk): keep the in-memory board for the session and continue.

## Testing and verification

There is no Godot on the development machine, so the game cannot be run during
implementation. Verification is limited to:

- Sound files: measured duration, peak level, silence at the ends, and loop-seam match.
- Leaderboard logic: the sort, trim and tie rules are mirrored in a small Python check.
- Static review: every `res://` path referenced exists, signal and method names match
  between `.tscn` and `.gd` files.

The user runs the game (F5) and confirms: sounds on flap, score, hit and game over; music
loops and M mutes it; a qualifying score shows the name box; the leaderboard lists entries
across restarts; Back returns to the right screen.

## Files

New: `scenes/leaderboard.gd`, `scenes/audio_manager.gd`, `scenes/leaderboard.tscn`,
`scenes/leaderboard_screen.gd`, `assets/sounds/*.wav`.
Edited: `project.godot` (two autoloads), `scenes/main.gd`, `scenes/game_over.gd`,
`scenes/game_over.tscn`, `scenes/select.gd`, `scenes/game_state.gd`
(`leaderboard_return`).

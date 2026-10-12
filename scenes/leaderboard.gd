extends Node

# Autoload: local leaderboard with one row per player (their best score).
# Every player is kept so ranks beyond ten still work; the screens show the top 10.
# Only _load() and _save() touch storage, so an online backend can replace them later.

const SHOWN : int = 10
const MAX_STORED : int = 500
const MAX_NAME : int = 12

var save_path : String = "user://leaderboard.json"
var entries : Array = []
var last_name : String = ""

func _ready():
	_load()

# Records a finished round. A score only counts if it beats the player's own best;
# a zero score is never recorded. Players are matched ignoring upper/lower case.
# Returns {rank (0 = not on the board), total, is_best, best}.
func record(player_name: String, score: int, hero: String) -> Dictionary:
	var clean = _clean_name(player_name)
	var key = clean.to_lower()
	var before = _score_of(key)
	if score > 0:
		_merge({
			"name": clean,
			"score": score,
			"hero": hero,
			"date": Time.get_datetime_string_from_system(),
		})
	last_name = clean
	_save()
	var idx = _index_of(key)
	return {
		"rank": idx + 1,
		"total": entries.size(),
		"is_best": score > 0 and score > before,
		"best": _score_of(key),
	}

func top(n: int = SHOWN) -> Array:
	return entries.slice(0, n)

func count() -> int:
	return entries.size()

func best() -> int:
	if entries.is_empty():
		return 0
	return entries[0]["score"]

func _clean_name(player_name: String) -> String:
	# trim again after cutting so the result is stable when cleaned a second time (on load)
	var clean = player_name.strip_edges().substr(0, MAX_NAME).strip_edges()
	if clean == "":
		clean = "Player"
	return clean

func _index_of(key: String) -> int:
	for i in entries.size():
		if entries[i]["name"].to_lower() == key:
			return i
	return -1

func _score_of(key: String) -> int:
	var idx = _index_of(key)
	if idx == -1:
		return 0
	return entries[idx]["score"]

# Adds an entry, or replaces the same player's row if this score is higher.
func _merge(entry: Dictionary) -> void:
	var idx = _index_of(entry["name"].to_lower())
	if idx != -1:
		if entry["score"] <= entries[idx]["score"]:
			return
		entries.remove_at(idx)
	_insert(entry)

# Insert after every entry with an equal or higher score, so an earlier run keeps its rank.
func _insert(entry: Dictionary) -> void:
	var idx = entries.size()
	for i in entries.size():
		if entry["score"] > entries[i]["score"]:
			idx = i
			break
	entries.insert(idx, entry)
	if entries.size() > MAX_STORED:
		entries.resize(MAX_STORED)

func _load() -> void:
	entries = []
	last_name = ""
	if not FileAccess.file_exists(save_path):
		return
	var f = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK:  # unlike JSON.parse_string, this does not log an error
		return
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw = parsed.get("entries", [])
	if typeof(raw) == TYPE_ARRAY:
		for e in raw:
			# skip entries whose score is not a number (null, list, object) instead of aborting the load
			if typeof(e) == TYPE_DICTIONARY and e.has("name") and e.has("score") \
					and typeof(e["score"]) in [TYPE_INT, TYPE_FLOAT]:
				var raw_name = e["name"]
				_merge({
					"name": _clean_name(raw_name if typeof(raw_name) == TYPE_STRING else ""),
					"score": int(e["score"]),
					"hero": str(e.get("hero", "boy")),
					"date": str(e.get("date", "")),
				})
	var saved_last = parsed.get("last_name", "")
	if typeof(saved_last) == TYPE_STRING:
		last_name = saved_last.substr(0, MAX_NAME)

func _save() -> void:
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Leaderboard: could not save scores, keeping them in memory")
		return
	f.store_string(JSON.stringify({"entries": entries, "last_name": last_name}))

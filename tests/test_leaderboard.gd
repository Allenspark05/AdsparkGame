extends SceneTree

# Run headless:  <godot> --headless --path . -s tests/test_leaderboard.gd
const LB = preload("res://scenes/leaderboard.gd")
const TEST_PATH = "user://test_leaderboard.json"
var failures : int = 0
var made : Array = []  # every Leaderboard node the tests create, freed at the end

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
	return reload()

func reload():
	var lb = LB.new()
	made.append(lb)
	lb.save_path = TEST_PATH
	lb._load()
	return lb

func names_of(lb) -> Array:
	var out = []
	for e in lb.top():
		out.append(e["name"])
	return out

func _init():
	# empty board
	var lb = fresh()
	check(lb.top().size() == 0, "empty board has no entries")
	check(lb.best() == 0, "best() is 0 on an empty board")
	check(lb.count() == 0, "count() is 0 on an empty board")

	# a player's first score
	var r = lb.record("Amy", 5, "girl")
	check(r["rank"] == 1 and r["total"] == 1 and r["is_best"] and r["best"] == 5, "first score is recorded as a new best: %s" % [r])

	# a zero score is never recorded
	r = lb.record("Zed", 0, "boy")
	check(lb.top().size() == 1 and r["rank"] == 0 and not r["is_best"], "a zero score is not recorded: %s" % [r])

	# a lower or equal score never replaces a player's best
	r = lb.record("Amy", 3, "girl")
	check(not r["is_best"] and r["best"] == 5 and r["rank"] == 1 and lb.top().size() == 1, "a lower score keeps the old best: %s" % [r])
	r = lb.record("Amy", 5, "girl")
	check(not r["is_best"] and r["best"] == 5, "an equal score is not a new best")

	# a higher score replaces it; the same player is matched ignoring case
	r = lb.record("amy", 9, "boy")
	check(r["is_best"] and r["best"] == 9 and lb.top().size() == 1, "a higher score by the same player replaces the row: %s" % [r])
	check(lb.top()[0]["name"] == "amy" and lb.top()[0]["hero"] == "boy" and lb.top()[0]["score"] == 9, "the row takes the latest spelling, hero and score")

	# ranking and ties (the earlier player stays ahead)
	lb = fresh()
	lb.record("A", 5, "boy")
	lb.record("B", 9, "girl")
	r = lb.record("C", 5, "boy")
	check(names_of(lb) == ["B", "A", "C"], "ranked by score, ties keep the earlier player first: %s" % [names_of(lb)])
	check(r["rank"] == 3 and r["total"] == 3, "rank and total are reported: %s" % [r])
	check(lb.best() == 9, "best() is the top score")

	# every player is stored, top() shows up to 100, and ranks beyond ten are still reported
	lb = fresh()
	for i in range(1, 13):
		lb.record("P%d" % i, i + 10, "boy")
	check(lb.top().size() == 12, "top() lists every player up to the limit")
	check(lb.top(3).size() == 3, "top(3) returns three entries")
	check(lb.count() == 12, "all 12 players are kept")
	r = lb.record("Late", 1, "boy")
	check(r["rank"] == 13 and r["total"] == 13 and r["is_best"], "a player below the top ten still gets a rank: %s" % [r])

	# 100 players: all are kept and ranked, and top() caps at 100
	lb = fresh()
	for i in range(1, 121):
		lb.record("Player%d" % i, i, "boy")
	check(lb.count() == 120, "120 players are all stored")
	check(lb.top().size() == 100, "top() caps at 100 entries")
	check(lb.top()[0]["name"] == "Player120" and lb.top()[99]["name"] == "Player21", "the 100 best are shown in order")

	# names
	lb = fresh()
	r = lb.record("   ", 4, "boy")
	check(lb.top()[0]["name"] == "Player", "a blank name becomes Player")
	lb.record("ABCDEFGHIJKLMNOP", 3, "boy")
	check(lb.top()[1]["name"] == "ABCDEFGHIJKL", "names are capped at 12 characters")
	var tricky = 'Sam "the" \\ \'x\''.substr(0, 12).strip_edges()  # cut to 12, no edge spaces
	lb.record('Sam "the" \\ \'x\'', 2, "girl")
	var again = reload()
	check(again.top()[2]["name"] == tricky, "quotes and backslashes round-trip through the file")
	check(again.last_name == tricky, "last_name is the most recent player")

	# persistence
	lb = fresh()
	lb.record("Kai", 7, "girl")
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

	# a hand-edited bad score must not take the valid entries down with it
	write_raw('{"entries": [{"name": "a", "score": null}, {"name": "b", "score": 5}, {"name": "c", "score": [1]}, {"name": "d", "score": {"x": 1}}, {"name": "e", "score": 3}], "last_name": "b"}')
	var odd = reload()
	check(names_of(odd) == ["b", "e"], "entries with a non-numeric score are skipped, valid ones kept: %s" % [names_of(odd)])
	check(odd.last_name == "b", "last_name is still read when some entries are bad")

	# other hand-edit cases
	write_raw('{"entries": [{"name": "", "score": 4}, {"name": "x", "score": 2}], "last_name": null}')
	var edited = reload()
	check(edited.top()[0]["name"] == "Player", "a blank name in the file becomes Player")
	check(edited.last_name == "", "a null last_name loads as empty, not the text <null>")

	# old files with the same player several times keep only the best
	write_raw('{"entries": [{"name": "Sam", "score": 3}, {"name": "sam", "score": 7}, {"name": "Bo", "score": 4}], "last_name": "Bo"}')
	var merged = reload()
	check(names_of(merged) == ["sam", "Bo"] and merged.top()[0]["score"] == 7, "duplicate players in an old file merge to their best: %s" % [names_of(merged)])

	remove_file()
	for n in made:
		n.free()
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)

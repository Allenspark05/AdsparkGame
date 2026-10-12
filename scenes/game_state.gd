extends Node

# Autoload: remembers which hero the player picked on the select screen.
# "boy" or "girl", used to pick res://assets/bird_<hero><frame>.png
var hero : String = "boy"

# Who is playing. Asked once on the hero screen; every round is saved under this name.
var player_name : String = ""

# Scene to return to when the leaderboard screen's Back button is pressed.
var leaderboard_return : String = "res://scenes/select.tscn"

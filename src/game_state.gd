extends Node
# Global singleton for passing data between scenes.
# Registered as autoload "GameState" in project.godot.

var pending_log: MatchLog       = null  # log ready to display in PlaybackScene
var pending_log_path: String    = ""    # path to a log file to load on arrival

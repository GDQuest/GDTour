var ctrl := "Ctrl"

var context_2d := "Ctrl+F1"
var context_3d := "Ctrl+F2"
var context_script := "Ctrl+F3"

var run_project := "F5"
var run_current := "F6"
var stop := "F8"
var focus := "F"
var select_mode := "Q"
var move_mode := "W"
var rotate_mode := "E"
var top_view := "Kp 7"


func _init() -> void:
	if OS.get_name() != "macOS":
		return

	ctrl = "Cmd"

	context_2d = "Alt+1"
	context_3d = "Alt+2"
	context_script = "Alt+3"

	run_current = "%s+R" % ctrl
	stop = "%s+." % ctrl

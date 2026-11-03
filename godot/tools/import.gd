## Import the original game from a disk image, without a window (for tests and scripted runs).
##
##   godot --headless --path godot -s res://tools/import.gd -- <disk image>
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -s res://tools/import.gd -- <disk image>")
		quit(2)
		return
	var t := Time.get_ticks_msec()
	var err := Import.from_image(args[0])
	if err != "":
		printerr("IMPORT FAILED: " + err)
		quit(1)
		return
	print("IMPORT OK (%d ms) into %s" % [Time.get_ticks_msec() - t, ProjectSettings.globalize_path(Import.DIR)])
	quit(0)

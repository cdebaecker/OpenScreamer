# Parse-checks every script of the port:
#   godot --headless --path godot -s res://tools/check.gd
extends SceneTree


func _initialize() -> void:
	var bad := 0
	for dir in ["res://game", "res://screen", "res://host", "res://tools", "res://"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var s: GDScript = load(dir.path_join(f))
			if s == null or not s.can_instantiate():
				bad += 1
				printerr("FAILED: ", dir.path_join(f))
	print("check: %d failing script(s)" % bad)
	quit(1 if bad else 0)

# Smoke test of the real host (window, shader, keyboard events, real-time pacing):
# runs main.tscn, types a few keys through the input system and saves window screenshots.
#   xvfb-run godot --path godot -s res://tools/smoke.gd -- outdir
extends SceneTree

var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://smoke"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.add_child(load("res://main.tscn").instantiate())
	_run()


func _key(code: Key, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.unicode = unicode
		e.pressed = pressed
		Input.parse_input_event(e)
		await create_timer(0.08).timeout


func _hold(code: Key, seconds: float) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await create_timer(seconds).timeout
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await create_timer(0.1).timeout


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name))
	print("shot ", name, " at ", Time.get_ticks_msec(), " ms")


func _run() -> void:
	await process_frame
	# keep the roster in memory: don't touch the player's user://CHAR
	var chara: Chara = root.get_child(root.get_child_count() - 1).game.chara
	var saved := [chara.data.roster_default]
	chara.save_load = func() -> PackedByteArray: return saved[0]
	chara.save_store = func(d: PackedByteArray) -> void: saved[0] = d
	await create_timer(2.0).timeout
	await _shot("1_splash.png")
	await _key(KEY_SPACE, 0x20)
	await create_timer(3.0).timeout
	await _shot("2_demo.png")
	await _key(KEY_SPACE, 0x20)  # skip the demo
	await create_timer(8.0).timeout  # the gatekeeper's speech (keys typed meanwhile are dropped)
	await _shot("3_registration.png")
	await _key(KEY_SPACE, 0x20)
	await create_timer(3.0).timeout
	for c in "ABE":
		await _key(KEY_A + (c.unicode_at(0) - 0x41) as Key, c.unicode_at(0))
	await _key(KEY_SPACE, 0x20)
	await create_timer(3.0).timeout
	await _shot("4_confirm.png")
	await _key(KEY_SPACE, 0x20)
	await create_timer(6.0).timeout
	await _shot("5_town.png")
	await _key(KEY_SPACE, 0x20)  # 1st item: to the BIAS gate
	await create_timer(4.0).timeout
	await _key(KEY_SPACE, 0x20)  # enter BIAS
	await create_timer(3.0).timeout
	await _key(KEY_SPACE, 0x20)
	await create_timer(5.0).timeout
	await _shot("6_dungeon.png")
	await _hold(KEY_W, 0.4)  # forward (keypad 8 alias)
	await create_timer(1.5).timeout
	await _shot("7_step.png")
	await _key(KEY_F12)
	await _shot("8_help.png")
	quit()

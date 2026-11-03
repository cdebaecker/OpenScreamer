# Smoke test of the port's own interface in a real window: the settings menu (pages, pausing,
# keyboard and gamepad), the modern font and CRT display, the on-screen keyboard typing a name with
# the gamepad, and the roster page deleting a screamer.  Prints "ok"/"FAIL" lines and saves
# screenshots.  Settings go to a temporary file and the roster stays in memory.
#   xvfb-run godot --path godot -s res://tools/ui_smoke.gd -- outdir
extends SceneTree

var out_dir := ""
var main: Node
var failed := 0


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://ui_smoke"
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://main.tscn").instantiate()
	main.settings_path = out_dir.path_join("settings.cfg")
	DirAccess.remove_absolute(main.settings_path)
	root.add_child(main)
	_run()


func check(ok: bool, what: String) -> void:
	print("ok   " if ok else "FAIL ", what)
	if not ok:
		failed += 1


func _send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	await create_timer(0.08).timeout


func _key(code: Key, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.unicode = unicode
		e.pressed = pressed
		await _send(e)


func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = pressed
		await _send(e)


func _touch(p: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = p * Vector2(root.size) / root.get_visible_rect().size  # the window's pixels
	e.index = index
	e.pressed = pressed
	await _send(e)


func _centre(touch: TouchControls, id: String) -> Vector2:
	return (touch._keys[id] as Control).get_global_rect().get_center()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name))


func _run() -> void:
	await process_frame
	var game: Game = main.game
	var saved := [game.data.roster_default]
	game.chara.save_load = func() -> PackedByteArray: return saved[0]
	game.chara.save_store = func(d: PackedByteArray) -> void: saved[0] = d
	var menu: SettingsMenu = main.menu
	await create_timer(1.5).timeout

	# the menu: F10 opens it and the game stops
	await _key(KEY_F10)
	check(menu.visible, "F10 opens the settings")
	var clock := game.sys.clock
	await create_timer(1.0).timeout
	check(game.sys.clock == clock, "the game is paused while the settings are open")
	await _shot("settings_game.png")
	for page in ["display", "sound", "access", "controls", "roster"]:
		await _pad(JOY_BUTTON_RIGHT_SHOULDER)
		await _shot("settings_%s.png" % page)
	await _key(KEY_ESCAPE)
	check(not menu.visible, "Esc closes the settings")
	await create_timer(0.5).timeout
	check(game.sys.clock > clock, "the game goes on after the settings close")
	await _pad(JOY_BUTTON_START)
	check(menu.visible, "gamepad Start opens the settings")
	# the font option with the gamepad: d-pad down to "Font", A
	menu.show_page("Display")  # the first row: the font
	await create_timer(0.1).timeout
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_UP)
	await _pad(JOY_BUTTON_A)
	check(main.settings.modern_font and main.screen.modern_font, "gamepad: d-pad + A switch to the modern font")
	await _pad(JOY_BUTTON_B)
	check(not menu.visible, "gamepad B closes the settings")
	var cfg := ConfigFile.new()
	check(cfg.load(main.settings_path) == OK and cfg.get_value("display", "modern_font") == true, "settings are saved")

	await _key(KEY_SPACE, 0x20)  # past the notice
	await create_timer(3.0).timeout
	await _key(KEY_SPACE, 0x20)  # skip the demo
	await create_timer(8.0).timeout
	await _shot("modern_registration.png")
	main.settings.style = "crt"
	main.apply_settings()
	await _shot("modern_crt_registration.png")
	main.settings.style = "soft"
	main.settings.modern_font = false
	main.apply_settings()
	await _shot("soft_registration.png")
	main.settings.style = "sharp"
	main.settings.scheme = "colour_blind"
	main.settings.modern_font = true
	main.settings.large_text = true
	main.apply_settings()
	await _shot("colour_blind_large_registration.png")
	main.settings.scheme = "original"
	main.settings.large_text = false
	main.settings.modern_font = false
	main.apply_settings()

	# the roster page at the registration screen: delete the first screamer
	await _key(KEY_F10)
	menu.show_page("Roster")
	var before := RosterFile.entries(saved[0]).size()
	check(menu.roster_editable(), "the roster can be changed at registration")
	var first := RosterFile.entries(saved[0])[0].name
	(menu._roster_list.get_child(0) as Button).button_pressed = true
	menu._delete_button.pressed.emit()
	await _shot("settings_roster_delete.png")
	menu._delete_button.pressed.emit()
	var after := RosterFile.entries(saved[0])
	check(after.size() == before - 1 and after.all(func(c: Character) -> bool: return c.name != first),
			"the roster page deletes %s (%d -> %d)" % [first, before, after.size()])
	check(game.town.roster_count == before - 1 and game.chara.roster_count() == before - 1, "the game sees the new roster")
	await _key(KEY_ESCAPE)

	# a new screamer, named with the on-screen keyboard
	await _key(KEY_SPACE, 0x20)  # "new"
	await create_timer(4.0).timeout
	check(game.ui.typing, "the game waits for a name")
	await _pad(JOY_BUTTON_DPAD_RIGHT)  # a gamepad was used: the keyboard comes up (cursor on B)
	await create_timer(0.1).timeout
	check(main.osk.visible, "the on-screen keyboard comes up for typing with a gamepad")
	await _pad(JOY_BUTTON_DPAD_LEFT)
	await _pad(JOY_BUTTON_A)  # A
	await _pad(JOY_BUTTON_X)  # space
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_A)  # B
	await _pad(JOY_BUTTON_A)  # B
	await _pad(JOY_BUTTON_B)  # delete
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)  # abc
	await _pad(JOY_BUTTON_A)  # b
	await create_timer(0.5).timeout
	await _shot("osk_name.png")
	check(game.ui.input == "A Bb", "typed \"A Bb\" with the gamepad (got \"%s\")" % game.ui.input)
	await _pad(JOY_BUTTON_START)  # OK
	await create_timer(0.5).timeout
	check(not game.ui.typing and not main.osk.visible, "Start ends the entry, the keyboard goes away")
	check(game.st.chr.name == "A Bb", "the new screamer is called \"A Bb\" (%s)" % game.st.chr.name)
	await _key(KEY_F10)
	menu.show_page("Roster")
	await create_timer(0.1).timeout
	check(not menu.roster_editable() and menu._delete_button.disabled, "no roster changes once a screamer is chosen")
	await _key(KEY_ESCAPE)

	# into BIAS (as in smoke.gd), a step, the map
	main.automap.path = out_dir.path_join("automap.cfg")
	await create_timer(3.0).timeout
	await _key(KEY_SPACE, 0x20)
	await create_timer(6.0).timeout
	await _key(KEY_SPACE, 0x20)  # 1st item: to the BIAS gate
	await create_timer(4.0).timeout
	await _key(KEY_SPACE, 0x20)  # enter BIAS
	await create_timer(3.0).timeout
	await _key(KEY_SPACE, 0x20)
	await create_timer(5.0).timeout
	check(Ambience.area_of(game.program.current) == "bias", "walked into BIAS (%s)" % game.program.current)
	var start := Vector2i(game.st.pos_x, game.st.pos_y)
	var walk := InputEventKey.new()
	walk.physical_keycode = KEY_W
	walk.keycode = KEY_W
	walk.pressed = true
	Input.parse_input_event(walk)
	await create_timer(0.4).timeout
	walk = walk.duplicate()
	walk.pressed = false
	Input.parse_input_event(walk)
	await create_timer(1.5).timeout
	var moved := Vector2i(game.st.pos_x, game.st.pos_y) != start
	await _key(KEY_F8)
	check(main.automap.visible, "F8 shows the map in BIAS")
	clock = game.sys.clock
	await create_timer(0.5).timeout
	check(game.sys.clock == clock, "the game is paused while the map is shown")
	check(main.automap.visited(game.st.floor, start.x, start.y) and (not moved or main.automap.visited(game.st.floor, game.st.pos_x, game.st.pos_y)),
			"the map has the cells walked (moved: %s)" % moved)
	await _shot("automap.png")
	await _pad(JOY_BUTTON_B)
	check(not main.automap.visible, "B closes the map")

	# the journal
	main.journal.path = out_dir.path_join("journal.cfg")
	DirAccess.remove_absolute(main.journal.path)  # (from an earlier run)
	main.journal._name = ""
	game.sys.journal(&"wall", "", game.data.table("wall_texts")[1])
	game.sys.journal(&"hunter", "8", "")
	await _key(KEY_J, 0x6a)
	check(main.journal.visible and main.journal.entries().size() == 2, "J shows the journal in BIAS")
	var samurai: String = game.data.demo_strings["0x2eb"].trim_prefix("Name      : ").get_slice("_", 0).strip_edges()
	check(not main.journal._text.get_parsed_text().contains(samurai), "the journal in English (%s)" % main.journal._text.get_parsed_text().substr(30, 160))
	clock = game.sys.clock
	await create_timer(0.5).timeout
	check(game.sys.clock == clock, "the game is paused while the journal is shown")
	await _shot("journal.png")
	await _key(KEY_J, 0x6a)
	check(not main.journal.visible, "J closes the journal")

	# quick save standing in BIAS, walk on, quick load
	SaveGame.dir = out_dir.path_join("saves")
	await create_timer(0.5).timeout
	check(game.ui.rest == &"bias", "standing in BIAS is a rest point")
	var saved_at := Vector3i(game.st.pos_x, game.st.pos_y, game.st.facing)
	await _key(KEY_F6)
	check(main._note.visible and main._note.text.begins_with("Saved"), "F6 saves (%s)" % main._note.text)
	await _key(KEY_KP_6)  # turn
	await create_timer(1.5).timeout
	var turned: int = game.st.facing
	var old_sys := game.sys
	var old_state: WeakRef = weakref(game.st)
	await _key(KEY_F7)
	await create_timer(0.3).timeout
	var loaded: Game = main.game
	check(loaded != game and main._note.text.begins_with("Loaded"), "F7 loads into a new game (%s)" % main._note.text)
	var at := Vector3i(loaded.st.pos_x, loaded.st.pos_y, loaded.st.facing)
	check(at == saved_at and turned != saved_at.z, "back where it was saved (%s, saved %s, had turned to %d)" % [at, saved_at, turned])
	check(old_sys.halted, "the old game stopped")
	game = null
	await create_timer(0.3).timeout
	check(old_state.get_ref() == null, "the old game is freed (nothing keeps it in memory)")
	await create_timer(3.0).timeout
	check(loaded.ui.rest == &"bias" and loaded.program.current == &"dungeon", "the loaded game goes on in BIAS (%s)" % loaded.program.current)
	var shown := ""
	for c in 8:
		shown += String.chr(maxi(loaded.screen.text.glyph_at(0x3d + c, 8), 0x20))
	check(shown.strip_edges() == "A Bb", "the name is shown after loading (%s)" % shown)
	await _shot("loaded.png")
	await _key(KEY_F10)
	menu.show_page("Saves")
	await create_timer(0.1).timeout
	await _shot("settings_saves.png")
	check((menu._save_rows["quick"][0] as Label).text.contains("BIAS floor"), "the Saves page lists the quick save")
	await _key(KEY_ESCAPE)
	SaveGame.dir = SaveGame.DIR

	# death: the rewind prompt, and back a step
	await create_timer(1.0).timeout
	var states: int = main.rewind.of(main.game.st.chr.name).size()
	check(states >= 1, "rewind: states recorded in BIAS (%d)" % states)
	var dying: Game = main.game
	var where := Vector2i(dying.st.pos_x, dying.st.pos_y)
	dying.sys.jump(&"game_over")
	await create_timer(1.5).timeout
	check(dying.program.current == &"game_over" and not main.rewind_prompt.visible and main._rewind_button.visible,
			"rewind: on death, the death screen and the bar's Go back")
	await _shot("rewind_death.png")
	await _key(KEY_R)
	check(main.rewind_prompt.visible, "rewind: R opens the prompt")
	await _key(KEY_ESCAPE)
	check(not main.rewind_prompt.visible and main._rewind_button.visible and dying.program.current == &"game_over",
			"rewind: Esc goes back to the death screen")
	await _key(KEY_R)
	clock = dying.sys.clock
	await create_timer(0.5).timeout
	check(dying.sys.clock == clock, "rewind: the game waits for the answer")
	await _shot("rewind_prompt.png")
	await _key(KEY_LEFT)
	await _key(KEY_LEFT)  # 1 step
	await _key(KEY_SPACE, 0x20)
	await create_timer(3.0).timeout
	var back: Game = main.game
	check(back != dying and back.program.current == &"dungeon" and Vector2i(back.st.pos_x, back.st.pos_y) == where,
			"rewind: back in BIAS where it was (%s)" % back.program.current)
	check(back.chara.find_in_roster() >= 0, "rewind: the screamer is in the roster again")
	# the Original difficulty: no saving, no rewind
	check(not main._kana_button.visible and not main.osk.kana_page, "no KANA in English")
	main.settings.difficulty = "original"
	main.apply_settings()
	await _key(KEY_F6)
	check(main._note.text.begins_with("No saving"), "Original difficulty: F6 doesn't save (%s)" % main._note.text)
	await create_timer(1.0).timeout
	check(main.rewind.of(main.game.st.chr.name).is_empty(), "Original difficulty: nothing to go back to")
	await _key(KEY_F10)
	menu.show_page("Saves")
	await create_timer(0.1).timeout
	check((menu._save_rows["quick"][1] as Button).disabled and (menu._save_rows["quick"][2] as Button).disabled,
			"Original difficulty: the Saves page can't save or load")
	await _key(KEY_ESCAPE)
	main.settings.difficulty = "modern"
	main.apply_settings()
	# the interface in Japanese (it follows the text's language)
	main.settings.lang = "ja"
	main.apply_settings()
	await _shot("window_ja.png")
	check(main._kana_button.visible and main.osk.kana_page, "KANA in Japanese")
	await _key(KEY_F10)
	menu.show_page("Game")
	await create_timer(0.2).timeout
	check(main._mute_button.text.begins_with("サウンド") and menu._tabs.get_tab_title(0) == "ゲーム",
			"interface in Japanese (%s, %s)" % [main._mute_button.text, menu._tabs.get_tab_title(0)])
	await _shot("settings_ja.png")
	await _key(KEY_ESCAPE)
	await _key(KEY_F12)
	await _shot("help_ja.png")
	await _key(KEY_F12)
	main.settings.lang = "en"
	main.apply_settings()
	await create_timer(0.1).timeout
	check(main._mute_button.text.begins_with("Sound"), "and back in English (%s)" % main._mute_button.text)

	# touch controls: none until the screen is touched, then over the picture (the window has the
	# game's shape), beside it on a wide window; a held button holds the action, a typed one types
	var touch: TouchControls = main.touch
	check(not touch.visible, "no touch controls before a touch")
	await _touch(Vector2(5, 5), true)
	await _touch(Vector2(5, 5), false)
	check(touch.visible and not touch.beside and not main.automap.visible,
			"a touch shows the touch controls, over the picture (and presses nothing)")
	await _shot("touch_over.png")
	await _key(KEY_KP_5)
	check(not touch.visible, "a key hides them again")
	main.settings.touch = "on"
	main.apply_settings()
	root.size = Vector2i(1800, 880)
	await create_timer(0.5).timeout
	var view := root.get_visible_rect().size
	check(touch.visible and touch.beside and root.canvas_transform.origin.x > 0,
			"on a wide window, beside the picture (%s, offset %s)" % [view, root.canvas_transform.origin])
	await _shot("touch_beside.png")
	var walk_at := _centre(touch, "walk")
	await _touch(walk_at, true)
	check(Input.is_action_pressed(&"forward"), "holding ▲ holds \"forward\"")
	await _touch(walk_at, false)
	check(not Input.is_action_pressed(&"forward"), "letting go lets it go")
	await _touch(_centre(touch, "start"), true)
	await _touch(_centre(touch, "start"), false)
	check(menu.visible, "Menu opens the settings")
	await _touch(_centre(touch, "b"), true)
	await _touch(_centre(touch, "b"), false)
	check(not menu.visible, "B closes them")
	main.settings.touch = "off"
	main.apply_settings()
	check(not touch.visible and root.canvas_transform.origin == Vector2.ZERO, "touch controls off: the picture back in place")
	root.size = Vector2i(1280, 880)
	# a game replaced while its splash runs is freed too (the splash's references are dropped)
	var g1 := Game.create(main.screen)
	g1.sys.host = main
	main._replace_game(g1)
	g1.program.run_program()
	await create_timer(0.5).timeout
	var splash_state: WeakRef = weakref(g1.st)
	g1 = null
	var g2 := Game.create(main.screen)
	g2.sys.host = main
	main._replace_game(g2)
	g2.program.run_program(true, true)
	g2 = null
	await create_timer(0.5).timeout
	check(splash_state.get_ref() == null, "a game stopped during its splash is freed")
	print("%d failed" % failed if failed else "ui smoke: all passed")
	quit(1 if failed else 0)

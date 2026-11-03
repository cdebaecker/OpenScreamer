# Unit tests of the parts no key script reaches: the host (keyboard and gamepad mapping, romaji
# typing, the beeper's waveform, real-time pacing), saving (the roster file, the language setting)
# and small helpers.  The player's own files in user:// are kept and put back.
#
#   godot --headless --path godot -s res://tools/unit_tests.gd [-- --romaji cases.json out.json]
#
# With --romaji it only types the cases and writes the key codes, for comparing with a reference
# keyboard.
extends SceneTree

var failures := 0
var passed := 0


func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
	else:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--romaji" in args:
		var i := args.find("--romaji")
		_romaji(args[i + 1], args[i + 2])
		quit(0)
		return
	_run()


func _run() -> void:
	await process_frame
	# the tests' own settings (the player's language and options don't change them, nor they the player's)
	GameData.settings_file = "user://unit_test_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameData.settings_file))
	UiText.use("en")
	print("LOCALE0 ", OS.get_locale(), " ", TranslationServer.get_locale(), " ", TranslationServer.get_loaded_locales())
	test_text()
	test_parse_number()
	test_character()
	test_keys_matrix()
	await test_input_map()
	test_host_keyboard()
	test_beeper()
	test_roster_file()
	test_settings()
	test_typing_flag()
	test_modern_font()
	test_settings_file()
	test_rebinding()
	test_roster_manager()
	test_osk()
	await test_pacing()
	await test_fast_forward()
	await test_sound_options()
	await test_accessibility()
	await test_automap()
	print("LOCALE ", TranslationServer.get_locale(), " ", TranslationServer.translate("BIAS floor %d"))
	test_save_game()
	test_translations()
	test_fix_bugs()
	test_fix_bugs_items_combat()
	await test_fix_bugs_shops_bias()
	await test_last_doors()
	await test_wall_text_one()
	await test_pendant_fix()
	test_rewind()
	test_ui_translation()
	await test_journal()
	print("unit tests: %d passed, %d failed" % [passed, failures])
	quit(1 if failures else 0)


# ------------------------------------------------------------------ romaji

func _romaji(cases_path: String, out_path: String) -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(cases_path))
	var out := {}
	for c: String in cases:
		var keys := Keys.new()
		var kb := HostKeyboard.new(keys)
		for i in c.length():
			for pressed in [true, false]:
				kb.key_event(_key_event(c[i], pressed))
		var codes := []
		while keys.pending() > 0:
			codes.append(keys.take())
		out[c] = codes
	FileAccess.open(out_path, FileAccess.WRITE).store_string(JSON.stringify(out))


func _key_event(ch: String, pressed: bool) -> InputEventKey:
	var named := {"-": KEY_MINUS, ".": KEY_PERIOD, ",": KEY_COMMA, "[": KEY_BRACKETLEFT, "]": KEY_BRACKETRIGHT,
			"/": KEY_SLASH, "'": KEY_APOSTROPHE, " ": KEY_SPACE, "`": KEY_QUOTELEFT, "\b": KEY_BACKSPACE}
	var e := InputEventKey.new()
	e.pressed = pressed
	if named.has(ch):
		e.physical_keycode = named[ch]
	elif ch.to_upper() >= "A" and ch.to_upper() <= "Z":
		e.physical_keycode = KEY_A + (ch.to_upper().unicode_at(0) - 0x41) as Key
	else:
		e.physical_keycode = KEY_0 + (ch.unicode_at(0) - 0x30) as Key
	e.keycode = e.physical_keycode
	if ch != "\b" and ch != "`":
		e.unicode = ch.unicode_at(0)
	return e


# ------------------------------------------------------------------ text

func test_text() -> void:
	var all := PackedByteArray()
	for c in range(0x20, 0x100):
		all.append(c)
	check(GameText.encode(GameText.decode(all)) == all, "text: bytes -> Unicode -> bytes")
	check(GameText.decode(PackedByteArray([0xb1, 0xdd, 0xa1, 0xdf])) == "ｱﾝ｡ﾟ", "text: half-width katakana")
	check(GameText.encode("ｶﾅ ABC") == PackedByteArray([0xb6, 0xc5, 0x20, 0x41, 0x42, 0x43]), "text: encode")


func test_parse_number() -> void:
	# spaces around a number are fine, anything else (or more than 65535) is not
	var cases := {"0": 0, "12": 12, "  12  ": 12, "": 0, "   ": 0, "65535": 65535, "65536": -1, "1 2": -1,
			"12a": -1, "-1": -1, "abc": -1, "007": 7}
	for s: String in cases:
		check(Ui.parse_number(s) == cases[s], "parse_number(%s) = %d, not %d" % [s, Ui.parse_number(s), cases[s]])


func test_character() -> void:
	var c := Character.new()
	c.name = "ｱｲｳｴ"
	c.hp = 0x1234
	c.poison = 0x1ff
	c.bp_total = 0x10000 + 5
	check(c.name == "ｱｲｳｴ" and c.record[0] == 0xb1, "character: name in the record")
	check(c.record.decode_u16(0x16) == 0x1234 and c.hp == 0x1234, "character: HP at +16h")
	check(c.poison == 0xff and c.bp_total == 5, "character: fields keep their width")
	c.inv_add(3)
	c.inv_add(0x85)
	c.inv_add(7)
	check(c.inv_count() == 3 and c.inv_find(5) == 1 and c.inv_find(9) == -1, "character: inventory")
	c.inv_remove(0)
	check(c.inv(0) == 0x85 and c.inv(1) == 7 and c.inv(2) == 0, "character: removing an item")


# ------------------------------------------------------------------ input

func test_keys_matrix() -> void:
	var keys := Keys.new()
	keys.scripted = {&"forward": true}
	check(keys.pad_bits() == 0x0800, "keys: keypad 8 is group 8 bit 3")
	keys.scripted = {&"turn_right": true, &"forward": true}
	check(keys.pad_bits() == 0x0801, "keys: two keys held together")
	keys.scripted = {&"attack": true, &"command": true}
	check(keys.group(5) == 0x0a, "keys: Z and C in group 5")
	var reads := [0]
	keys.on_matrix_read = func() -> void: reads[0] += 1
	keys.pad_bits()
	check(reads[0] == 2, "keys: the keypad word is two matrix reads")
	keys.push(65)
	check(keys.peek() == 65 and keys.take() == 65 and keys.take() == -1 and keys.read() == 0, "keys: queue")
	for i in 20:
		keys.push(i + 1)
	check(keys.pending() == 16, "keys: the queue holds 16 keys like the BIOS buffer")


func test_input_map() -> void:
	var keys := Keys.new()
	var expect := {
		&"forward": [KEY_KP_8, KEY_W], &"back": [KEY_KP_2, KEY_S], &"turn_left": [KEY_KP_4, KEY_A],
		&"turn_right": [KEY_KP_6, KEY_D], &"open_door": [KEY_KP_5, KEY_E], &"flee": [KEY_KP_0, KEY_Q],
		&"attack": [KEY_Z], &"defend": [KEY_X], &"command": [KEY_C], &"cancel": [KEY_ESCAPE],
		&"confirm": [KEY_ENTER, KEY_KP_ENTER], &"cursor_up": [KEY_UP], &"debug_help": [KEY_END],
		&"debug_shift": [KEY_SHIFT], &"debug_ctrl": [KEY_CTRL], &"debug_f1": [KEY_F1], &"debug_w": [KEY_W],
	}
	for action: StringName in expect:
		check(InputMap.has_action(action), "input map: %s exists" % action)
		for key: Key in expect[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			e.pressed = true
			Input.parse_input_event(e)
			Input.flush_buffered_events()
			check(keys.held(action), "input map: %s held with %s" % [action, OS.get_keycode_string(key)])
			e = e.duplicate()
			e.pressed = false
			Input.parse_input_event(e)
			Input.flush_buffered_events()
			check(not keys.held(action), "input map: %s released" % action)
	# the gamepad: left stick and buttons
	var pad := {&"forward": [JOY_AXIS_LEFT_Y, -1.0], &"back": [JOY_AXIS_LEFT_Y, 1.0],
			&"turn_left": [JOY_AXIS_LEFT_X, -1.0], &"turn_right": [JOY_AXIS_LEFT_X, 1.0]}
	for action: StringName in pad:
		var m := InputEventJoypadMotion.new()
		m.axis = pad[action][0]
		m.axis_value = pad[action][1]
		Input.parse_input_event(m)
		Input.flush_buffered_events()
		check(keys.held(action), "gamepad: %s with the left stick" % action)
		m = m.duplicate()
		m.axis_value = 0.0
		Input.parse_input_event(m)
		Input.flush_buffered_events()
	for b in [[JOY_BUTTON_X, &"attack"], [JOY_BUTTON_Y, &"defend"], [JOY_BUTTON_BACK, &"command"],
			[JOY_BUTTON_LEFT_SHOULDER, &"flee"], [JOY_BUTTON_RIGHT_SHOULDER, &"open_door"]]:
		var e := InputEventJoypadButton.new()
		e.button_index = b[0]
		e.pressed = true
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		check(keys.held(b[1]), "gamepad: button %d is %s" % [b[0], b[1]])
		e = e.duplicate()
		e.pressed = false
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	await process_frame


func test_host_keyboard() -> void:
	var keys := Keys.new()
	var kb := HostKeyboard.new(keys)
	var press := func(code: Key, unicode := 0, echo := false) -> void:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.unicode = unicode
		e.pressed = true
		e.echo = echo
		kb.key_event(e)
	for k in [[KEY_UP, Keys.K_UP], [KEY_RIGHT, Keys.K_RIGHT], [KEY_DOWN, Keys.K_DOWN], [KEY_LEFT, Keys.K_LEFT],
			[KEY_DELETE, Keys.K_DEL], [KEY_BACKSPACE, Keys.K_DEL], [KEY_ENTER, Keys.K_SPACE],
			[KEY_KP_ENTER, Keys.K_SPACE], [KEY_SPACE, Keys.K_SPACE], [KEY_ESCAPE, Keys.K_ESC]]:
		press.call(k[0])
		check(keys.take() == k[1], "keyboard: %s" % OS.get_keycode_string(k[0]))
	press.call(KEY_A, 0x41)
	check(keys.take() == 0x41, "keyboard: a letter is typed")
	press.call(KEY_KP_7, 0x37)
	check(keys.take() == 0x37, "keyboard: keypad digits are typed too")
	press.call(KEY_W, 0x77, true)
	check(keys.take() == -1, "keyboard: a held walking key doesn't repeat in the queue")
	press.call(KEY_B, 0x62, true)
	check(keys.take() == 0x62, "keyboard: other keys repeat")
	for b in [[JOY_BUTTON_A, Keys.K_SPACE], [JOY_BUTTON_B, Keys.K_ESC], [JOY_BUTTON_DPAD_UP, Keys.K_UP],
			[JOY_BUTTON_DPAD_DOWN, Keys.K_DOWN], [JOY_BUTTON_DPAD_LEFT, Keys.K_LEFT],
			[JOY_BUTTON_DPAD_RIGHT, Keys.K_RIGHT]]:
		var e := InputEventJoypadButton.new()
		e.button_index = b[0]
		e.pressed = true
		kb.joy_event(e)
		check(keys.take() == b[1], "gamepad: button %d types %d" % b)
	check(not kb.kana, "keyboard: KANA starts off")
	press.call(KEY_QUOTELEFT)
	check(kb.kana, "keyboard: ` turns KANA on")
	for ch in "ka":
		press.call(KEY_A + (ch.unicode_at(0) - 0x61) as Key, ch.unicode_at(0))
	check(keys.take() == "ｶ".unicode_at(0), "keyboard: romaji in KANA mode")
	kb.kana_allowed = false  # the text isn't in Japanese
	press.call(KEY_QUOTELEFT)
	check(not kb.kana, "keyboard: ` turns KANA off (always)")
	press.call(KEY_QUOTELEFT)
	check(not kb.kana, "keyboard: and not on when the text isn't Japanese")


# ------------------------------------------------------------------ sound

func test_beeper() -> void:
	var b := Beeper.new()  # not in the tree: no audio device involved
	var rate := int(Beeper.RATE)
	b.schedule(0, 1000, 1000, 3)  # 3 x (1 ms on, 1 ms off)
	var buf := b.render(rate / 100)  # 10 ms
	var on := func(i: int) -> bool: return buf[i] != Vector2.ZERO
	check(on.call(0) and on.call(40) and not on.call(50) and not on.call(80), "beeper: 1 ms on, 1 ms off")
	check(on.call(90) and on.call(180) and not on.call(140), "beeper: the pattern repeats")
	check(not on.call(270) and not on.call(400), "beeper: 3 times, then silence (6 ms)")
	check(is_equal_approx(absf(buf[0].x), Beeper.VOLUME) and buf[0].x == buf[0].y,
			"beeper: square wave at the volume, both ears")
	var flips := 0
	for i in range(1, 44):
		if signf(buf[i].x) != signf(buf[i - 1].x):
			flips += 1
	check(flips >= 3 and flips <= 5, "beeper: about 2 kHz (%d sign changes in 1 ms)" % flips)
	b.schedule(0, 1000, 0, 1)
	b.schedule(0, 1000, 0, 1)
	var later := b.render(rate / 1000 * 3)
	check(later[10] != Vector2.ZERO and later[50] != Vector2.ZERO and later[100] == Vector2.ZERO,
			"beeper: patterns that overlap play one after the other")
	b.free()
	var sys := Sys.new()
	var heard := [0]
	sys.audio = _AudioProbe.new(heard)
	sys.sound(100, 100, 1)
	sys.muted = true
	sys.sound(100, 100, 1)
	check(heard[0] == 1, "sound: nothing reaches the beeper when muted")


class _AudioProbe:
	var heard: Array

	func _init(h: Array) -> void:
		heard = h

	func beep(_t: int, _on: int, _off: int, _n: int) -> void:
		heard[0] += 1


# ------------------------------------------------------------------ saving

func _keep(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _put_back(path: String, d: PackedByteArray) -> void:
	if d.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	else:
		FileAccess.open(path, FileAccess.WRITE).store_buffer(d)


func test_roster_file() -> void:
	var kept := _keep(Chara.SAVE_PATH)
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	var game := Game.create(screen)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Chara.SAVE_PATH))
	game.chara.load_roster()
	check(game.chara.roster.size() == 8, "roster: 8 slots")
	game.chara.save_roster()
	check(FileAccess.get_file_as_bytes(Chara.SAVE_PATH) == game.data.roster_default,
			"roster: without a save, the disk's CHAR file; saved unchanged, byte for byte")
	var c := Character.new()  # a new screamer in the first free slot
	game.chara.roster[game.chara.roster_count()] = c
	c.name = "NEW"
	c.hp = 77
	c.inv_add(0x85)
	game.chara.save_roster()
	var again := Game.create(screen)
	again.chara.load_roster()
	var back := again.chara.roster[again.chara.roster_count() - 1]
	check(back.name == "NEW" and back.hp == 77 and back.inv(0) == 0x85, "roster: a saved screamer comes back")
	check(FileAccess.get_file_as_bytes(Chara.SAVE_PATH).size() == 0x400, "roster: the CHAR file stays 1 KB")
	game.dispose()
	again.dispose()
	screen.queue_free()
	_put_back(Chara.SAVE_PATH, kept)


func test_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "lang", "ja")
	cfg.save(GameData.settings_file)
	var d := GameData.new()
	check(d.lang == "ja", "settings: the game starts in the language the window's settings keep")
	d.set_lang("en")
	check(GameData.new().lang == "ja", "settings: changing the language in the game doesn't write the settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameData.settings_file))
	check(GameData.new().lang == "en", "settings: English without settings")
	check(d.translate("ｱｲｳｴｵ") == "ｱｲｳｴｵ", "translation: unknown text is shown as it is")
	d.lang = "ja"
	check(d.keyword_for("drug") == "", "translation: no English keywords in Japanese")
	d.lang = "en"
	check(d.keyword_for("Pow-Drug") == d.talk[0]["keyword"], "translation: English keywords, any spelling")


func test_typing_flag() -> void:
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	var game := Game.create(screen)
	var seen := []
	game.keys.on_empty_poll = func() -> void:
		seen.append(game.ui.typing)
		for k in [0x41, Keys.K_RIGHT, 0x42, Keys.K_SPACE]:
			game.keys.push(k)
	check(not game.ui.typing, "typing: not before line input")
	game.ui.line_input()
	check(seen == [true] and game.ui.input == "A B" and not game.ui.typing,
			"typing: set while line input waits, cleared after (%s, %s)" % [seen, game.ui.input])
	game.dispose()
	screen.queue_free()


func test_modern_font() -> void:
	var font: FontFile = load(ModernText.FONT_PATH)
	var missing := []
	for g: int in ModernText.CHARS:
		var ch: String = ModernText.CHARS[g]
		if not font.has_char(ch.unicode_at(0)):
			missing.append("%02x %s" % [g, ch])
	check(missing.is_empty(), "modern font: has every character it stands for (missing %s)" % str(missing))
	# what stays a bitmap: blank, cursor block, arrow, box drawing, the checker, the little figure
	var bitmaps := []
	for g in 256:
		if not ModernText.has(g) and g != 0x20:
			bitmaps.append(g)
	var expect := [0x00, 0x01, 0x02] + range(0x11, 0x1d) + [0x60, 0x7f, 0xa0, 0xfe, 0xff]
	check(bitmaps == expect, "modern font: only graphics stay bitmaps (%s)" % str(bitmaps.map(func(x: int) -> String: return "%02x" % x)))
	check(ModernText.CHARS[0x5c] == "¥" and ModernText.CHARS[0xb1] == "ｱ" and ModernText.CHARS[0x91] == "あ"
			and ModernText.CHARS[0xfd] == "ん" and ModernText.CHARS[0x03] == "水" and ModernText.CHARS[0x41] == "A",
			"modern font: glyph codes map to the characters of the PC-98 font")
	# the text layer leaves those glyphs to the overlay, and the overlay follows its changes
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	screen.modern_font = true
	var v := screen.text.version
	screen.text.put(0, 0, 0x41, 7)
	check(screen.text.modern and screen.text.version == v + 1 and screen.get_node("TextView/ModernText").visible,
			"modern font: switched on, the overlay sees text changes")
	var pv := screen.palette_version
	screen.out_palette(0xa8, 0x00)
	check(screen.palette_version > pv, "modern font: the overlay sees palette changes")
	screen.modern_font = false
	check(not screen.text.modern and not screen.get_node("TextView/ModernText").visible, "modern font: switched off")
	var m := screen.get_node("Display").material as ShaderMaterial
	screen.modern_font = true
	check(m.get_shader_parameter("text_on") == true and m.get_shader_parameter("text_tex") != null,
			"modern font: its layer goes into the display shader")
	screen.modern_font = false
	check(m.get_shader_parameter("text_on") == false, "modern font: and out")
	# colour schemes: the shader and the modern font use the same colours
	screen.reset_palette()
	screen.scheme = "colour_blind"
	var cols: PackedVector3Array = m.get_shader_parameter("colours")
	var c2: Color = Screen.SCHEMES["colour_blind"][2]
	check(cols[2].is_equal_approx(Vector3(c2.r, c2.g, c2.b)) and screen.display_colour(2) == c2, "colours: the scheme reaches the shader and the text")
	screen.out_palette(0xac, 0x66)  # red shows as yellow (6)
	check(screen.display_colour(2) == Screen.SCHEMES["colour_blind"][6], "colours: through the game's palette")
	screen.scheme = "nonsense"
	check(screen.scheme == "original", "colours: unknown schemes fall back to the original")
	# fades: from what was shown, over FADE_S
	screen.reset_palette()
	screen.smooth_fades = true
	screen.out_palette(0xac, 0x00)
	check(m.get_shader_parameter("fade") == 0.0 and Array(m.get_shader_parameter("prev_pal")) == [0, 1, 2, 3, 4, 5, 6, 7]
			and Array(m.get_shader_parameter("pal"))[2] == 0, "fades: a palette change starts a fade from the old colours")
	screen._process(Screen.FADE_S / 2)
	check(is_equal_approx(m.get_shader_parameter("fade"), 0.5), "fades: half way")
	screen._process(1.0)
	check(m.get_shader_parameter("fade") == 1.0, "fades: done")
	screen.graphics_visible = false
	check(Array(m.get_shader_parameter("pal")) == [0, 0, 0, 0, 0, 0, 0, 0], "fades: hidden graphics fade to black too")
	screen.smooth_fades = false
	screen.graphics_visible = true
	check(m.get_shader_parameter("fade") == 1.0, "fades: off, changes at once")
	screen.style = Screen.Style.CRT
	check((screen.get_node("Display").material as ShaderMaterial).get_shader_parameter("style") == Screen.Style.CRT, "CRT: the shader gets it")
	screen.queue_free()


func test_settings_file() -> void:
	var path := "user://test_settings.cfg"
	var s := Settings.new()
	s.lang = "ja"
	s.modern_font = true
	s.style = "crt"
	s.integer_scale = true
	s.fullscreen = true
	s.volume = 35
	s.muted = true
	s.bindings = {&"attack": {"key": KEY_K}, &"flee": {"pad": [JOY_AXIS_TRIGGER_LEFT, 1]}}
	s.save_file(path)
	var t := Settings.new()
	t.load_file(path)
	check(t.lang == "ja" and t.modern_font and t.style == "crt" and t.integer_scale and t.fullscreen and t.volume == 35 and t.muted,
			"settings: options come back")
	check(t.bindings == s.bindings, "settings: bindings come back (%s)" % str(t.bindings))
	var d := GameData.new()  # the game's language setting lives in the same file
	var cfg := ConfigFile.new()
	cfg.load(path)
	check(cfg.get_value("game", "lang") == "ja" and GameData.SETTINGS == Settings.PATH, "settings: the language where the game keeps it")
	var u := Settings.new()
	u.load_file("user://no_such_settings.cfg")
	check(u.lang == "en" and not u.modern_font and u.volume == 80 and u.bindings.is_empty(), "settings: defaults without a file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_rebinding() -> void:
	var s := Settings.new()
	s.reset_bindings()
	check(Settings.describe_key(Settings.key_event_of(&"attack")) == "Z", "rebinding: attack is Z")
	check(Settings.pad_event_of(&"forward") is InputEventJoypadMotion, "rebinding: forward is the stick")
	s.bind_key(&"attack", KEY_K)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	k.pressed = true
	var z := InputEventKey.new()
	z.physical_keycode = KEY_Z
	z.pressed = true
	check(InputMap.event_is_action(k, &"attack") and not InputMap.event_is_action(z, &"attack"), "rebinding: K attacks, Z no longer")
	check(Settings.is_action_key(KEY_K) and not Settings.is_action_key(KEY_Z), "rebinding: K doesn't repeat when held, Z does")
	s.bind_key(&"defend", KEY_K)  # K moves to defend
	check(InputMap.event_is_action(k, &"defend") and not InputMap.event_is_action(k, &"attack"), "rebinding: a key drives one action")
	var kp8 := InputEventKey.new()
	kp8.physical_keycode = KEY_KP_8
	kp8.pressed = true
	s.bind_key(&"forward", KEY_I)
	check(InputMap.event_is_action(kp8, &"forward"), "rebinding: the keypad keys stay")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_Y
	b.pressed = true
	s.bind_pad(&"open_door", b)
	check(InputMap.event_is_action(b, &"open_door") and not InputMap.event_is_action(b, &"defend"), "rebinding: Y opens doors now")
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_TRIGGER_RIGHT
	m.axis_value = 0.9
	s.bind_pad(&"attack", m)
	check(InputMap.event_is_action(m, &"attack") and Settings.describe_pad(Settings.pad_event_of(&"attack")) == "Trigger 5",
			"rebinding: a trigger attacks")
	# the game reads its matrix through the rebound actions
	var keys := Keys.new()
	Input.parse_input_event(m)
	Input.flush_buffered_events()
	check(keys.group(5) & 0x02 != 0, "rebinding: the game sees the trigger as Z in its key matrix")
	var up := m.duplicate()
	up.axis_value = 0.0
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	var t := Settings.new()  # what was saved applies the same
	t.bindings = s.bindings.duplicate(true)
	s.reset_bindings()
	check(InputMap.event_is_action(z, &"attack") and not InputMap.event_is_action(b, &"open_door"), "rebinding: reset to the defaults")
	t.apply_bindings()
	check(InputMap.event_is_action(b, &"open_door") and InputMap.event_is_action(k, &"defend"), "rebinding: saved bindings apply")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	check(InputMap.event_is_action(a, &"ui_accept"), "menus: gamepad A accepts")
	s.reset_bindings()


func test_roster_manager() -> void:
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	var game := Game.create(screen)
	var saved := [game.data.roster_default]
	game.chara.save_load = func() -> PackedByteArray: return saved[0]
	game.chara.save_store = func(d: PackedByteArray) -> void: saved[0] = d
	var d: PackedByteArray = game.data.roster_default
	check(RosterFile.valid(d), "roster manager: the disk's roster is valid")
	var names := RosterFile.entries(d).map(func(c: Character) -> String: return c.name)
	check(names == ["ari-ken", "Google", "Ryo"], "roster manager: lists the disk's screamers (%s)" % str(names))
	var e := RosterFile.delete(d, 1)
	names = RosterFile.entries(e).map(func(c: Character) -> String: return c.name)
	check(names == ["ari-ken", "Ryo"] and e.size() == RosterFile.BYTES and RosterFile.valid(e),
			"roster manager: delete moves the later ones up (%s)" % str(names))
	check(e.slice(7 * 0x80, 8 * 0x80).count(0xff) == 0x80, "roster manager: the last slot is left free (FFh)")
	check(e.slice(0x80, 0x100) == d.slice(0x100, 0x180), "roster manager: records move byte for byte")
	var bad := d.duplicate()
	bad[0x80] = 0xff  # a free slot before a used one
	check(not RosterFile.valid(bad) and not RosterFile.valid(d.slice(0, 0x200)), "roster manager: refuses broken files")
	check(RosterFile.describe(RosterFile.entries(d)[0]).begins_with("ari-ken"), "roster manager: describes a screamer")
	# the menu's file actions, with the game at registration
	game.chara.load_roster()
	game.town.roster_count = game.chara.roster_count()
	var menu := SettingsMenu.new()
	root.add_child(menu)
	menu.setup(Settings.new(), game)
	check(menu.roster_editable(), "roster manager: editable before a screamer is chosen")
	SettingsMenu.apply_roster(game, e)
	check(saved[0] == e and game.town.roster_count == 2 and game.chara.roster[1].name == "Ryo",
			"roster manager: the game's file and memory get the new roster")
	var out := "user://test_CHAR"
	check(menu.file_action("export", out).begins_with("Exported") and FileAccess.get_file_as_bytes(out) == e,
			"roster manager: export writes the CHAR file")
	FileAccess.open(out, FileAccess.WRITE).store_buffer(d)
	check(menu.file_action("import", out).begins_with("Imported") and saved[0] == d and game.town.roster_count == 3,
			"roster manager: import reads one")
	FileAccess.open(out, FileAccess.WRITE).store_buffer(d.slice(0, 100))
	check(menu.file_action("import", out).contains("isn't a roster") and saved[0] == d, "roster manager: import refuses other files")
	game.st.chr.name = "Ryo"  # a screamer in play
	check(not menu.roster_editable() and menu.file_action("import", out).contains("registration"),
			"roster manager: no changes while a screamer is in play")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out))
	menu.queue_free()
	game.dispose()
	screen.queue_free()


func test_osk() -> void:
	var keys := Keys.new()
	var osk := Osk.new()
	osk.keys = keys
	root.add_child(osk)
	var pad := func(button: JoyButton) -> bool:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = true
		return osk.joy_event(e)
	var codes := func() -> Array:
		var out := []
		while keys.pending() > 0:
			out.append(keys.take())
		return out
	pad.call(JOY_BUTTON_A)
	pad.call(JOY_BUTTON_DPAD_RIGHT)
	pad.call(JOY_BUTTON_A)
	pad.call(JOY_BUTTON_X)
	pad.call(JOY_BUTTON_B)
	pad.call(JOY_BUTTON_START)
	check(codes.call() == [0x41, 0x42, Keys.K_RIGHT, Keys.K_DEL, Keys.K_SPACE],
			"OSK: A types, X is a space (→), B deletes, Start is OK")
	pad.call(JOY_BUTTON_DPAD_LEFT)
	pad.call(JOY_BUTTON_DPAD_LEFT)  # wraps to the end of the row
	pad.call(JOY_BUTTON_A)
	pad.call(JOY_BUTTON_DPAD_UP)  # wraps to the bottom row: Space Delete Page OK
	pad.call(JOY_BUTTON_A)
	check(codes.call() == [0x4c, Keys.K_SPACE], "OSK: the cursor wraps round (L, then OK)")
	pad.call(JOY_BUTTON_RIGHT_SHOULDER)
	pad.call(JOY_BUTTON_RIGHT_SHOULDER)
	osk.row = 0
	osk.col = 0
	pad.call(JOY_BUTTON_A)
	osk.col = 10
	pad.call(JOY_BUTTON_A)  # the voiced mark
	check(osk.page == 2 and codes.call() == [0xff71, 0xff9e], "OSK: the katakana page types half-width katakana (ｱ, ﾞ)")
	osk.kana_page = false
	check(osk.page == 0, "OSK: no katakana page when the text isn't Japanese")
	osk.set_page(osk.page + 1)
	osk.set_page(osk.page + 1)
	check(osk.page == 0, "OSK: ABC, abc, ABC")
	osk.kana_page = true
	osk.set_page(2)
	var odd := []
	for p in Osk.PAGES:
		for r: String in p:
			for i in r.length():
				var c := r.unicode_at(i)
				if not (c < 0x7f or (c >= 0xff61 and c <= 0xff9f)) or GameText.encode(r[i]).size() != 1:
					odd.append(r[i])
	check(odd.is_empty(), "OSK: every key is a character the game has (%s)" % str(odd))
	pad.call(JOY_BUTTON_LEFT_SHOULDER)
	check(osk.page == 1 and osk.char_at(0, 0) == "a", "OSK: LB goes back a page")
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_LEFT_X
	m.axis_value = 0.9
	osk.row = 0
	osk.col = 0
	osk.joy_event(m)
	osk.joy_event(m)  # held: one step only
	m.axis_value = 0.0
	osk.joy_event(m)
	check(osk.col == 1, "OSK: the stick moves one key per push")
	var other := InputEventJoypadButton.new()
	other.button_index = JOY_BUTTON_GUIDE
	other.pressed = true
	check(not osk.joy_event(other), "OSK: leaves other buttons alone")
	osk.queue_free()


# ------------------------------------------------------------------ real time

func test_pacing() -> void:
	var kept := _keep(Chara.SAVE_PATH)
	var main: Node = _main()
	root.add_child(main)
	var game: Game = main.game
	await create_timer(2.0).timeout  # past the splash's first wait (1.5 s ahead of real time)
	var lags := []
	for i in 8:
		await create_timer(0.25).timeout
		lags.append(main.now_us() - game.sys.clock)
	# the splash waits in steps of 100 ms: the clock is at most that far ahead, and never far behind
	check(lags.all(func(l: int) -> bool: return l > -110000 and l < 50000),
			"pacing: the game's clock follows real time (%s us)" % str(lags))
	check(game.sys.clock > 2500000, "pacing: about 4 s have run (%d us)" % game.sys.clock)
	main.queue_free()
	await process_frame
	_put_back(Chara.SAVE_PATH, kept)


func test_fast_forward() -> void:
	var kept := _keep(Chara.SAVE_PATH)
	var main: Node = _main()
	root.add_child(main)
	var game: Game = main.game
	await create_timer(1.0).timeout
	# instant typewriter text: the host clock doesn't hold the game back while it prints
	main.settings.instant_text = true
	game.sys.hurry = 1
	check(main.now_us() == 1 << 62, "instant text: no waiting while typewriter text prints")
	game.sys.hurry = 0
	check(absi(main.now_us() - game.sys.clock) < 5000, "instant text: then real time goes on from where the text ended")
	main.settings.instant_text = false
	game.sys.hurry = 1
	check(main.now_us() < 1 << 40, "instant text: off, typewriter text keeps its pace")
	game.sys.hurry = 0
	# fast-forward: x4
	main.settings.ff_speed = 4
	main.fast_forward = true
	await process_frame
	var c0: int = game.sys.clock
	var t0 := Time.get_ticks_usec()
	await create_timer(1.0).timeout
	var ratio := float(game.sys.clock - c0) / (Time.get_ticks_usec() - t0)
	check(ratio > 2.8 and ratio < 4.5 and main.beeper.speed == 4.0, "fast-forward: the game runs about 4x (%.2f)" % ratio)
	main.fast_forward = false
	await process_frame
	c0 = game.sys.clock
	t0 = Time.get_ticks_usec()
	await create_timer(1.0).timeout
	ratio = float(game.sys.clock - c0) / (Time.get_ticks_usec() - t0)
	check(ratio > 0.7 and ratio < 1.3 and main.beeper.speed == 1.0, "fast-forward: off, real time again (%.2f)" % ratio)
	# the beeper plays patterns shorter by the same factor
	var b := Beeper.new()
	b.speed = 4.0
	b.schedule(0, 1000, 1000, 10)
	check(b._busy_until == roundi(0.005 * Beeper.RATE), "fast-forward: beeps shortened 4x")
	b.free()
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_ff_settings.cfg"))
	_put_back(Chara.SAVE_PATH, kept)


func test_sound_options() -> void:
	# beeper tones: the same pattern, three shapes
	var shapes := {}
	for tone in ["square", "soft", "sine"]:
		var b := Beeper.new()
		b.tone = tone
		b.schedule(0, 1000, 0, 1)
		var buf := b.render(44)
		var vals := {}
		for v in buf:
			vals[snappedf(v.x, 0.001)] = true
		shapes[tone] = vals.size()
		check(buf[5].x != 0.0 and absf(buf[5].x) <= Beeper.VOLUME + 0.001, "beeper %s: sounds, no louder than the original" % tone)
		b.free()
	check(shapes["square"] == 2 and shapes["soft"] > 4 and shapes["sine"] > 4, "beeper tones: square has two levels, the others are rounded (%s)" % str(shapes))
	# ambience: seamless loops, the area from where the game is
	for a in ["bias", "town", "combat"]:
		var w := Ambience.render(a)
		var n := w.data.size() / 2
		var steps := 0
		for i in range(1, n, 97):
			steps = maxi(steps, absi(w.data.decode_s16(i * 2) - w.data.decode_s16(i * 2 - 2)))
		var seam := absi(w.data.decode_s16(0) - w.data.decode_s16((n - 1) * 2))
		check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and n == Ambience.RATE * Ambience.SECONDS and seam <= steps * 2,
				"ambience %s: a loop with no click at the seam (%d vs steps up to %d)" % [a, seam, steps])
	check(Ambience.area_of(&"dungeon_loop") == "bias" and Ambience.area_of(&"combat") == "combat"
			and Ambience.area_of(&"town_menu") == "town" and Ambience.area_of(&"title") == "", "ambience: follows the game's place")
	var amb := Ambience.new()
	root.add_child(amb)
	amb.area = "town"
	check(not amb._players[0].playing and not amb._players[1].playing, "ambience: silent while off")
	amb.enabled = true
	var p: AudioStreamPlayer = amb._players[amb._current]
	check(p.playing and p.get_meta("area") == "town", "ambience: on, the town's loop plays")
	amb.area = "bias"
	check(amb._players[amb._current] != p and amb._players[amb._current].get_meta("area") == "bias", "ambience: crossfades to BIAS")
	amb.queue_free()
	await process_frame


func test_accessibility() -> void:
	# reading aloud: the lines that changed, when the text has settled
	var t := TextLayer.new()
	root.add_child(t)
	var r := Reader.new()
	r.text = t
	var said := []
	r.speak = func(s: String) -> void: said.append(s)
	root.add_child(r)
	r.enabled = true
	for i in "Hello  there".length():
		t.put(3 + i, 2, "Hello  there".unicode_at(i), 7)
	t.put(0, 0, 0x18, 7)  # a frame corner: not read
	r._process(0.1)
	r._process(0.3)
	check(said.is_empty(), "reader: waits while the text changes or is new")
	r._process(Reader.SETTLE_S)
	check(said == ["Hello there"], "reader: reads the new line, spaces squeezed (%s)" % str(said))
	r._process(1.0)
	check(said.size() == 1, "reader: once")
	var k := GameText.encode("ｽｸﾘｰﾏｰ")
	for i in k.size():
		t.put(3 + i, 5, k[i], 6)
	r._process(0.0)
	r._process(Reader.SETTLE_S)
	check(said.size() == 2 and said[1] == "ｽｸﾘｰﾏｰ", "reader: only what changed; katakana as characters (%s)" % str(said))
	r.enabled = false
	t.clear_all()
	r._process(0.0)
	r._process(Reader.SETTLE_S)
	check(said.size() == 2, "reader: quiet when off")
	r.queue_free()
	t.queue_free()
	# a held d-pad button repeats
	var kept := _keep(Chara.SAVE_PATH)
	var main: Node = _main()
	root.add_child(main)
	await process_frame
	main.settings.pad_repeat_delay = 200
	main.settings.pad_repeat_rate = 50
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_DPAD_DOWN
	e.pressed = true
	Input.parse_input_event(e)
	await create_timer(0.45).timeout
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	var n: int = main.pad_repeats
	await create_timer(0.2).timeout
	check(n >= 3 and n <= 6 and main.pad_repeats == n, "d-pad repeat: after the delay, at the rate, until released (%d)" % n)
	main.settings.pad_repeat = false
	Input.parse_input_event(e)
	await create_timer(0.45).timeout
	Input.parse_input_event(up)
	await process_frame
	check(main.pad_repeats == n, "d-pad repeat: off")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_access_settings.cfg"))
	_put_back(Chara.SAVE_PATH, kept)


func test_automap() -> void:
	var path := "user://test_automap.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	var game := Game.create(screen)
	var m := Automap.new()
	m.path = path
	m.game = game
	root.add_child(m)
	game.st.chr.name = "MAPPER"
	game.st.floor = 1
	game.common.load_floor_file()
	for p in [[3, 4], [3, 3], [3, 3], [4, 3]]:
		game.st.pos_x = p[0]
		game.st.pos_y = p[1]
		m.record()
	check(m.visited(1, 3, 4) and m.visited(1, 3, 3) and m.visited(1, 4, 3) and not m.visited(1, 5, 3) and not m.visited(2, 3, 4),
			"automap: the cells stood on, per floor")
	var again := Automap.load_map(path, "MAPPER")
	check(again.has(1) and (again[1] as PackedByteArray).count(1) == 3, "automap: kept per screamer")
	check(Automap.load_map(path, "OTHER").is_empty(), "automap: another screamer has their own")
	game.st.chr.name = "OTHER"
	m.record()
	check(not m.visited(1, 3, 4) and m.visited(1, 4, 3), "automap: switching screamer switches maps")
	Automap.forget(path, "MAPPER")
	check(Automap.load_map(path, "MAPPER").is_empty() and not Automap.load_map(path, "OTHER").is_empty(),
			"automap: a deleted screamer's map goes")
	game.st.pos_x = 0x30  # off the floor (the original's warp can't, but no crash)
	m.record()
	m.visible = true
	m.queue_redraw()
	await process_frame
	check(true, "automap: draws")
	m.queue_free()
	game.dispose()
	screen.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_save_game() -> void:
	var dir := "user://test_saves"
	SaveGame.dir = dir
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	var saved := [PackedByteArray()]
	var mk := func() -> Game:
		var g := Game.create(screen)
		g.chara.save_load = func() -> PackedByteArray: return saved[0]
		g.chara.save_store = func(d: PackedByteArray) -> void: saved[0] = d
		return g
	var g: Game = mk.call()
	saved[0] = g.data.roster_default
	g.program.boot()
	g.chara.load_roster()
	g.town.roster_count = g.chara.roster_count()
	g.st.chr = g.chara.roster[1].copy()  # Google
	g.st.chr.credits = 1234
	g.st.floor = 3
	g.common.load_floor_file()
	g.st.map.set_b(FloorMap.cell_off(2, 2), 0x55)  # the floor changes while playing
	g.st.pos_x = 7
	g.st.pos_y = 9
	g.st.facing = 2
	g.st.rng_seed = 0x4321
	g.st.mon.hp = 33
	g.dungeon._regen_count = 5
	g.dungeon._poison_counters = [1, 2, 3, 4, 5]
	g.combat.noise_timer = 7
	g.items.show_prices = 1
	g.sys.clock = 123456789
	check(SaveGame.write(SaveGame.path_of("1"), g) != "", "saves: not while the game isn't at rest")
	g.ui.rest = &"bias"
	check(SaveGame.write(SaveGame.path_of("1"), g) == "", "saves: written at rest")
	var d := SaveGame.read(SaveGame.path_of("1"))
	check(d["where"] == "bias" and d["name"] == "Google" and d["floor"] == 3 and SaveGame.describe(d).begins_with("Google  —  BIAS floor 3"),
			"saves: what and where (%s)" % SaveGame.describe(d))
	var h: Game = mk.call()
	SaveGame.restore(h, d["state"])
	var sa := var_to_str(SaveGame.snapshot(g)).split("\n")
	var sb := var_to_str(SaveGame.snapshot(h)).split("\n")
	var diff := []
	for i in mini(sa.size(), sb.size()):
		if sa[i] != sb[i]:
			diff.append(sa[i].left(80) + " | " + sb[i].left(80))
	check(sa.size() == sb.size() and diff.is_empty(), "saves: a loaded game has exactly the saved state %s" % str(diff.slice(0, 4)))
	check(JSON.stringify(h.st.canonical()) == JSON.stringify(g.st.canonical()), "saves: the state the comparisons check, the same")
	check(h.st.chr.credits == 1234 and h.st.map.b(FloorMap.cell_off(2, 2)) == 0x55 and h.dungeon._poison_counters == [1, 2, 3, 4, 5]
			and h.combat.noise_timer == 7 and h.sys.clock == 123456789, "saves: screamer, floor changes, module state, clock")
	check(SaveGame.target_of(&"bias") == &"dungeon" and SaveGame.target_of(&"town") == &"town", "saves: loading enters BIAS or the town")
	# a loaded game runs from there to the rest point again (no host: it runs until it polls keys)
	for where: StringName in [&"bias", &"town"]:
		var l: Game = mk.call()
		SaveGame.restore(l, d["state"])
		l.st.stood = 1
		var reached := [&"", 0]
		l.keys.on_empty_poll = func() -> void:
			reached[1] += 1
			if l.ui.rest != &"" or reached[1] > 2000:  # (a message waiting for Space: give up)
				reached[0] = l.ui.rest
				l.sys.halt()
		l.sys.on_advance = func() -> void:  # BIAS is at rest while it waits in advance()
			if l.ui.rest != &"" and reached[0] == &"":
				reached[0] = l.ui.rest
				l.sys.halt()
			elif l.sys.clock > 600000000:
				l.sys.halt()
		l.program.run_from(SaveGame.target_of(where))
		check(reached[0] == where and l.st.pos_x == 7 and l.st.pos_y == 9, "saves: loaded into %s, the game reaches its rest point there" % where)
		l.dispose()
	# the screamer must be in the roster for the town to save them later
	var r := RosterFile.delete(saved[0], 1)
	saved[0] = r
	h.chara.load_roster()
	check(h.chara.find_in_roster() < 0 and SaveGame.ensure_in_roster(h) and h.chara.find_in_roster() == 2
			and RosterFile.entries(saved[0]).size() == 3, "saves: a screamer deleted since comes back to the roster")
	check(SaveGame.read(SaveGame.path_of("2")).is_empty() and SaveGame.describe({}) == "(empty)", "saves: an empty slot")
	FileAccess.open(SaveGame.path_of("3"), FileAccess.WRITE).store_string("garbage")
	check(SaveGame.read(SaveGame.path_of("3")).is_empty(), "saves: a broken file reads as empty")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	SaveGame.dir = SaveGame.DIR
	g.dispose()
	h.dispose()
	screen.queue_free()


func test_translations() -> void:
	var d := GameData.new()
	check(d.languages() == ["en", "fr", "ja"] and d.language_name("en") == "English" and d.language_name("ja") == "Japanese (original)",
			"translations: the packs (English, French), and the original (%s)" % str(d.languages()))
	for code in ["en", "fr"]:
		var l: Dictionary = d._langs[code]
		check(l["game"].size() == 672 and l["demo"].size() == 8 and l["password"].size() == 1,
				"translations: %s.po has every message (%d, %d)" % [code, l["game"].size(), l["demo"].size()])
	var kw: String = d.talk[0]["keyword"]
	d.lang = "en"
	check(d.translate("ｱｲｳｴｵ") == "ｱｲｳｴｵ" and d.keyword_for("Pow Drug!") == kw, "translations: English lookups")
	check(d.keyword_for("I'm a pervert") == d.table("shops_password"), "translations: the password typed in English")
	d.lang = "fr"
	check(d.keyword_for("Drogue force") == kw and d.keyword_for("Je suis un pervers") == d.table("shops_password"),
			"translations: French lookups")
	# another language, as a translator would write it: keys are digests of the original strings
	var path := "user://test_xx.po"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('msgid ""\nmsgstr ""\n"Language: xx\\n"\n"X-Language-Name: Testish\\n"\n\n'
			+ '#. width: 39\nmsgctxt "game"\nmsgid "%s"\nmsgstr "L\'écran \\"crié\\" — ¿Qué?"\n\n' % d.digest("ｱｲｳｴｵ")
			+ 'msgctxt "game"\nmsgid "%s"\nmsgstr ""\n\n' % d.digest("ｶｷｸｹｺ")
			+ 'msgctxt "demo"\nmsgid "%s"\nmsgstr ""\n"two "\n"lines"\n\n' % d.digest("ｻｼｽｾｿ")
			+ 'msgctxt "keyword"\nmsgid "%s"\nmsgstr "Drogue|médicament"\n' % d.digest(kw))
	f.close()
	var xx := d.read_po(path)
	check(xx["name"] == "Testish", "translations: the language's name from the header")
	d._langs["xx"] = xx
	d.lang = "xx"
	check(d.translate("ｱｲｳｴｵ") == "L'ecran \"crie\" - ?Que?", "translations: escapes read, accents dropped for the font (%s)" % d.translate("ｱｲｳｴｵ"))
	check(d.translate("ｶｷｸｹｺ") == "ｶｷｸｹｺ", "translations: untranslated messages stay Japanese")
	check(d.translate_demo("ｻｼｽｾｿ") == "two lines", "translations: strings over several lines")
	check(d.keyword_for("MEDICAMENT") == kw and d.keyword_for("drogue") == kw and d.keyword_for("drug") == "",
			"translations: the language's own keywords, any case or accents")
	check(d.matches_translation("l'ecran crie que", "ｱｲｳｴｵ") and not d.matches_translation("x", "ｱｲｳｴｵ"),
			"translations: typed names match the translation")
	check(GameText.encode(d.translate("ｱｲｳｴｵ")).size() == d.translate("ｱｲｳｴｵ").length(), "translations: what's shown has a glyph for every character")
	d.lang = "ja"
	check(d.translate("ｱｲｳｴｵ") == "ｱｲｳｴｵ" and d.keyword_for("drogue") == "", "translations: none in Japanese")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_fix_bugs() -> void:
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	var g := Game.create(screen)
	g.program.boot()
	# random doors (no shipped floor has any: a made-up one, every inner wall random): with the fix,
	# both sides of each rolled wall agree
	var opposite := [2, 3, 0, 1]
	var step := [-FloorMap.W * 8, 8, FloorMap.W * 8, -8]  # to the cell N, E, S, W
	var made := g.data.floor_bytes(1)
	for y in FloorMap.W:
		for x in FloorMap.W:
			for k in 4:
				# some walls (the game's random(1) alternates 0, 1: with all of them random,
				# opposite walls would come out the same by chance)
				if (x * 7 + y * 3 + k) % 3 == 0:
					made[FloorMap.cell_off(x, y) + k] = 0x41
	g.data._floors["1"] = Marshalls.raw_to_base64(made)
	for fix in [false, true]:
		g.sys.fix_bugs = fix
		var bad := 0
		var rolled := 0
		for floor in [1]:
			g.st.floor = floor
			var orig := g.data.floor_bytes(floor)
			g.st.rng_seed = 0x1234
			g.dungeon.randomize_doors()
			var m := g.st.map
			for idx in range(0, FloorMap.W * FloorMap.W, 2):  # the cells the game rolls
				var si := idx * 8
				for k in 4:
					if not (orig[si + k] & 0x40):
						continue
					var x := idx % FloorMap.W
					if (k == 1 and x == FloorMap.W - 1) or (k == 3 and x == 0):
						continue
					var other: int = si + step[k] + opposite[k]
					if other < 0 or other >= FloorMap.W * FloorMap.W * 8:
						continue
					rolled += 1
					if (m.b(si + k) & 1) != (m.b(other) & 1):
						bad += 1
		if fix:
			check(rolled > 150 and bad == 0, "fix bugs: random doors agree on both sides (%d walls)" % rolled)
			var items_same := true
			for c in FloorMap.W * FloorMap.W:
				items_same = items_same and g.st.map.b(c * 8 + 7) == made[c * 8 + 7]
			check(items_same, "fix bugs: no item byte touched")
		else:
			var items_same := true
			for c in FloorMap.W * FloorMap.W:
				items_same = items_same and g.st.map.b(c * 8 + 7) == made[c * 8 + 7]
			check(not items_same, "original: random west doors change item bytes")
		if not fix:
			check(bad > 0, "original: random doors can differ from the other side (%d of %d)" % [bad, rolled])
	# fog ball and noise machine
	for fix in [false, true]:
		g.sys.fix_bugs = fix
		g.combat.fogged = 0
		g.combat.noise_timer = 5
		var fogged_by_noise: bool = g.combat.fogged != 0
		g.combat.fogged = 0x00ff  # the fog ball
		var noise_left: int = g.combat.noise_timer
		if fix:
			check(not fogged_by_noise and noise_left == 5 and g.combat.fogged == 0xff, "fix bugs: fog and noise are separate")
		else:
			check(fogged_by_noise and noise_left == 0, "original: noise counts as fog, the fog ball stops the noise")
	g.dispose()
	screen.queue_free()


## a game with no host (it runs without waiting) that answers every other key poll with Space
## (every poll would make drain_keys() loop for ever)
func _quick_game(screen: Screen) -> Game:
	var g := Game.create(screen)
	g.program.boot()
	g.data.lang = "ja"
	var polls := [0]
	g.keys.on_empty_poll = func() -> void:
		polls[0] += 1
		if polls[0] % 2 == 1:
			g.keys.push(Keys.K_SPACE)
	return g


## the window, with its own empty settings (not the player's: their language would change the interface)
func _main() -> Node:
	var main: Node = load("res://main.tscn").instantiate()
	main.settings_path = "user://unit_test_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.settings_path))
	return main


func _screen_text(screen: Screen) -> String:
	return "\n".join(Reader.lines(screen.text))


func test_fix_bugs_items_combat() -> void:
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	# the inventory holds 30 items (the 30th at record byte 53h, the one the game tests for "full")
	var c := Character.new()
	for i in 30:
		c.inv_add(0x10 + i)
	check(c.inv_count() == 30 and c.inv_full != 0 and c.inv_find(0x10 + 29) == 29 and c.inv(30) == 0,
			"inventory: 30 items, the last one found, then full (%d)" % c.inv_count())
	# the noise machine's flag: the original never clears it
	for fix in [false, true]:
		var g := _quick_game(screen)
		g.sys.fix_bugs = fix
		g.combat.noise_on = 0x32
		g.combat.noise_timer = 1
		await g.combat._timers()
		var after_wear_off: int = g.combat.noise_on
		g.combat._mon_facing = 0xff
		g.st.monster = 1
		g.st.mon = Monster.new(g.data.monster_record(1))
		await g.combat._setup()
		if fix:
			check(after_wear_off == 0 and g.combat.noise_on == 0 and g.combat._mon_facing == 0,
					"fix bugs: the noise machine wears off (and a new fight starts clean)")
		else:
			check(after_wear_off != 0 and g.combat.noise_on != 0 and g.combat._mon_facing == 0xff,
					"original: after the noise machine no monster attacks again; facing kept")
		g.dispose()
	# the bacillus sensor: poison level L is the L-th name
	for fix in [false, true]:
		var got := []
		for level in range(1, 6):
			var g := _quick_game(screen)
			g.sys.fix_bugs = fix
			g.st.game_mode = 3
			g.st.floor_item = 0x10
			g.st.floor_item_poison = level
			screen.clear_screen()
			var seen := [""]  # the screen while it waits for Space (which clears the message)
			var polls := [0]
			g.keys.on_empty_poll = func() -> void:
				polls[0] += 1
				seen[0] += _screen_text(screen)
				if polls[0] % 2 == 1:
					g.keys.push(Keys.K_SPACE)
			await g.items._bacillus_sensor(0)
			var t: String = seen[0]
			var name := ""
			var names: Array = g.data.table("bacillus_names").filter(func(x: String) -> bool: return x != "")
			for i in names.size():  # (the table's names: types A, I, P, T and H)
				if t.contains(String(names[i]).replace("{", "").replace("}", "").replace("|", "")):
					name = ["A", "I", "P", "T", "H"][i]
			got.append(name if name != "" else "-")
			g.dispose()
		if fix:
			check(got == ["A", "I", "P", "T", "H"], "fix bugs: the sensor detects and names every poison (%s)" % str(got))
		else:
			check(got == ["-", "-", "-", "A", "I"], "original: the sensor misses levels 1-3 and misnames 4, 5 (%s)" % str(got))
	# the guest card doesn't carry door_unlocked to the exit
	for fix in [false, true]:
		var g := _quick_game(screen)
		g.sys.fix_bugs = fix
		g.st.game_mode = 3
		g.st.floor = 3
		g.common.load_floor_file()
		g.st.chr.inv_add(0x44)
		g.st.door_unlocked = 1
		var idx := g.st.chr.inv_find(0x44)
		var card := g.data.item(0x44)
		await g.items._guest_card(idx)
		check(g.st.floor == 1 and g.st.door_unlocked == (0 if fix else 1),
				("fix bugs" if fix else "original") + ": after the guest card door_unlocked is %d (%s)" % [g.st.door_unlocked, card["name"]])
		g.dispose()
	screen.queue_free()


func test_fix_bugs_shops_bias() -> void:
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	var mk := func(fix: bool) -> Game:
		var g := _quick_game(screen)
		g.sys.fix_bugs = fix
		g.chara.load_roster()
		g.st.chr = Character.new()
		g.st.chr.name = "TESTER"
		return g
	var table: Array
	for fix in [false, true]:
		var tag := "fix bugs" if fix else "original"
		# beast points to credits: a 16-bit word
		var g: Game = mk.call(fix)
		table = g.data.table("shops_class_bp")
		g.st.chr.inv_add(0xd2)  # the FRD, equipped
		g.st.chr.credits = 65000
		g.st.chr.bp = 2000
		await g.shops._show_frd()
		check(g.st.chr.credits == (65535 if fix else 1464), "%s: credits after 2000 BP at 65000 (%d)" % [tag, g.st.chr.credits])
		# reaching master class during the visit
		g.st.chr.hc = 24
		g.st.chr.bp_total = int(table[24]) - 1
		g.st.chr.bp = 10
		await g.shops._show_frd()
		check(g.st.chr.hc == 25 and (g.chara.has_item(0x4a) >= 0) == fix, "%s: the memento pendant on making master class: %s" % [tag, g.chara.has_item(0x4a) >= 0])
		g.dispose()
		# exactly on the class's value
		g = mk.call(fix)
		g.st.chr.hc = 0
		g.st.chr.bp_total = int(table[0])
		var left: int = await g.shops._class_check()
		check(g.st.chr.hc == (1 if fix else 0), "%s: class up exactly on the value (hc %d, %d to go)" % [tag, g.st.chr.hc, left])
		g.dispose()
		# the hospital: 6 credits
		g = mk.call(fix)
		g.st.chr.hp = 10
		g.st.chr.hp_max = 100
		g.st.chr.credits = 100
		g.keys.push(0x36)  # "6", then Space from the poll
		await g.shops._treat(0, "HP", &"hp")
		check(g.st.chr.hp == (11 if fix else 12) and g.st.chr.credits == (95 if fix else 94),
				"%s: 6 credits at the hospital: HP %d, credits %d" % [tag, g.st.chr.hp, g.st.chr.credits])
		g.dispose()
		# giving: the pendant chain in BIAS (the hunter who wants the white pendant gives the yellow)
		g = mk.call(fix)
		g.st.game_mode = 3
		g.st.chr.inv_add(0x4a)
		g.shops._give_person = 6
		await g.shops._give_item()
		check((g.chara.has_item(0x4b) >= 0) == fix and g.chara.has_item(0x4a) < 0,
				"%s: the white pendant to hunter 6 gets the yellow one: %s" % [tag, g.chara.has_item(0x4b) >= 0])
		# the samurai (8) gives the blade for the red pendant
		g.st.chr = Character.new()
		g.st.chr.inv_add(0x51)
		g.shops._give_person = 8
		await g.shops._give_item()
		check((g.chara.has_item(0x19) >= 0) == fix, "%s: the red pendant to the samurai gets the Samurai Blade: %s" % [tag, g.chara.has_item(0x19) >= 0])
		g.dispose()
		# giving an equipped item that's wanted (the bar: person 3 wants a hand bomb)
		g = mk.call(fix)
		g.st.game_mode = 2
		g.st.chr.inv_add(0x05 | Character.EQUIPPED)
		g.shops._give_person = 3
		await g.shops._give_item()
		check((g.chara.has_item(0x3c) >= 0) == fix, "%s: an equipped hand bomb is accepted: %s" % [tag, g.chara.has_item(0x3c) >= 0])
		g.dispose()
		# selling an equipped FRD drops its points
		g = mk.call(fix)
		g.st.game_mode = 2
		g.st.chr.inv_add(0xd2)
		g.st.chr.bp = 500
		await g.shops._sell()
		check(g.st.chr.inv_count() == 0 and (g.st.chr.bp == 0) == fix, "%s: selling the equipped FRD: BP %d" % [tag, g.st.chr.bp])
		g.dispose()
		# BIAS: an item on a stairs cell is looked for once on arriving (stood is 1 there)
		g = mk.call(fix)
		g.st.floor = 1
		g.st.pos_x = 13
		g.st.pos_y = 17
		g.st.stood = 1
		var first: bool = g.dungeon.look_for_item()
		g.dungeon._item_cell = Vector3i(1, 13, 17)
		g.st.stood = 0  # back from a fight in the cell
		var again: bool = g.dungeon.look_for_item()
		check(first == fix and again == (not fix), "%s: items on stairs cells / again after a fight: %s / %s" % [tag, first, again])
		# the first bump into a wall
		g.common.load_floor_file()
		g.st.pos_x = 0
		g.st.pos_y = 0
		g.st.facing = 0
		g.st.cell = g.st.map.bytes.slice(0, 8)
		await g.dungeon._move_forward()
		check(g.dungeon._bump == (2 if fix else 255), "%s: the bump counter after the first bump (%d)" % [tag, g.dungeon._bump])
		g.dispose()
		# a pit: using a command (Space picks the menu's first, Examine) climbs out in the original
		g = mk.call(fix)
		g.st.game_mode = 3
		g.st.floor = 1
		g.common.load_floor_file()
		g.st.cell = g.st.map.bytes.slice(0, 8)
		g.st.chr.hp = 50
		g.st.chr.hp_max = 50
		var polls := [0]
		g.keys.on_empty_poll = func() -> void:
			polls[0] += 1
			if polls[0] == 40:
				g.keys.scripted[&"open_door"] = true  # numpad 5: climb out
			if polls[0] % 2 == 1:
				g.keys.push(Keys.K_SPACE)
		g.st.trap_done = 0
		g.ui.menu_reset(10)  # the BIAS command menu (run_dungeon)
		await g.events._pit()
		check((polls[0] >= 40) == fix, "%s: a command in a pit %s (%d polls)" % [tag, "keeps you there" if fix else "climbs out", polls[0]])
		g.dispose()
	screen.queue_free()


## the doors around floor 5's stairs to floor 6 (the last floor): codes 5-7 open (to the password
## prompt) only with the Samurai Blade, code 8 only without; checked in the game, both ways
func test_last_doors() -> void:
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	var results := {}
	for open_way in [false, true]:
		for door in [[16, 3, 0, 7], [19, 1, 0, 5], [19, 4, 1, 6], [17, 5, 0, 8]]:  # x, y, facing, code
			for blade in [false, true]:
				var g := _quick_game(screen)
				g.sys.pendant_fix = open_way
				g.st.game_mode = 3
				g.st.floor = 5
				g.common.load_floor_file()
				g.st.pos_x = door[0]
				g.st.pos_y = door[1]
				g.st.facing = door[2]
				g.st.cell = g.st.map.bytes.slice(g.st.cell_off, g.st.cell_off + 8)
				if blade:
					g.st.chr.inv_add(0x19)
				var seen := [""]
				var polls := [0]
				var asked := [false]  # the door asks for its password: the game waits for typed text
				g.keys.on_empty_poll = func() -> void:
					polls[0] += 1
					seen[0] += _screen_text(screen)
					asked[0] = asked[0] or g.ui.typing
					if polls[0] % 2 == 1:
						g.keys.push(Keys.K_SPACE)
				await g.dungeon._open_door()
				results[[open_way, door[3], blade]] = asked[0]
				g.dispose()
	var ok := true
	for code in [5, 6, 7]:
		ok = ok and not results[[false, code, false]] and results[[false, code, true]]
	ok = ok and results[[false, 8, false]] and not results[[false, 8, true]]
	check(ok, "the last doors as shipped: codes 5-7 need the blade, code 8 needs to be without (%s)" % str(results))
	var open_ok := true
	for code in [5, 6, 7, 8]:
		open_ok = open_ok and results[[true, code, false]] and results[[true, code, true]]
	check(open_ok, "the last doors, the way to floor 6 open: the password alone, blade or not")
	screen.queue_free()


## floor 4's wall writing number 1: the original shows it empty (its skip loop wraps)
func test_wall_text_one() -> void:
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	for fix in [false, true]:
		var g := _quick_game(screen)
		g.sys.fix_bugs = fix
		g.data.set_lang("en")  # (the hint is looked for in the English pack's words)
		g.st.floor = 4
		g.common.load_floor_file()
		g.st.pos_x = 1
		g.st.pos_y = 8
		g.st.cell = g.st.map.bytes.slice(g.st.cell_off, g.st.cell_off + 8)
		var seen := [""]
		var polls := [0]
		g.keys.on_empty_poll = func() -> void:
			polls[0] += 1
			seen[0] += _screen_text(screen)
			if polls[0] % 2 == 1:
				g.keys.push(Keys.K_SPACE)
		check(g.st.cell_wall_text == 1, "floor 4 (1,8) has wall writing 1")
		await g.items._read_wall()
		var hint: bool = seen[0].contains(g.data.translate(g.data.table("wall_texts")[0]).substr(0, 12))
		check(hint == fix and seen[0].contains("\""),
				("fix bugs: the hint" if fix else "original: an empty writing") + " on floor 4's wall (%s)" % hint)
		g.dispose()
	screen.queue_free()


## the pendant chain on its own setting: on by default in the game, off in the core (comparisons)
func test_pendant_fix() -> void:
	check(Settings.new().pendant_fix and not Settings.new().fix_bugs and not Sys.new().pendant_fix,
			"pendant fix: on by default in the settings, the other fixes off, the core faithful")
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	for on in [false, true]:
		var g := _quick_game(screen)
		g.sys.pendant_fix = on
		g.chara.load_roster()
		g.st.chr = Character.new()
		g.st.game_mode = 3
		g.st.chr.inv_add(0x51)
		g.shops._give_person = 8
		await g.shops._give_item()
		check((g.chara.has_item(0x19) >= 0) == on, "pendant fix %s: the samurai gives the blade: %s" % [on, g.chara.has_item(0x19) >= 0])
		# the bar keeps its own table either way (person 1 wants a hand light for a Samson drug)
		g.st.chr = Character.new()
		g.st.game_mode = 2
		g.st.chr.inv_add(0x42)
		g.shops._give_person = 1
		await g.shops._give_item()
		check(g.chara.has_item(0x39) >= 0, "pendant fix %s: the bar's gifts unchanged" % on)
		g.dispose()
	screen.queue_free()


func test_rewind() -> void:
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	var g := Game.create(screen)
	g.program.boot()
	g.st.chr.name = "WALKER"
	g.st.floor = 1
	g.common.load_floor_file()
	var r := Rewind.new()
	g.ui.rest = &""
	r.record(g)
	check(r.snaps.is_empty(), "rewind: nothing recorded away from rest")
	g.ui.rest = &"bias"
	for i in Rewind.KEEP + 5:
		g.st.pos_y = i
		r.record(g)
		r.record(g)  # the same place: once
	check(r.snaps.size() == Rewind.KEEP, "rewind: one state per place, the last %d kept" % Rewind.KEEP)
	check(r.back("WALKER", 1)["state"]["st"]["pos_y"] == Rewind.KEEP + 4 and r.back("WALKER", 3)["state"]["st"]["pos_y"] == Rewind.KEEP + 2,
			"rewind: n steps back")
	check(r.back("WALKER", Rewind.KEEP + 1).is_empty() and r.back("OTHER", 1).is_empty(), "rewind: nothing further back, nothing for another screamer")
	var h := Game.create(screen)
	SaveGame.restore(h, r.back("WALKER", 2)["state"])
	check(h.st.pos_y == Rewind.KEEP + 3 and h.st.chr.name == "WALKER", "rewind: a state restores like a saved game")
	# a state kept in memory doesn't change with the game (the character, the map...)
	g.st.chr.hp_max = 40
	g.st.chr.hp = 30
	var kept := SaveGame.snapshot(g)
	g.st.chr.hp = 1
	g.st.map.set_b(0, 0x5a)
	g.ui.input_buf.resize(16)
	g.ui.input_buf[0] = 0x41
	var k := Game.create(screen)
	SaveGame.restore(k, kept)
	check(k.st.chr.hp == 30 and k.st.map.b(0) != 0x5a and (k.ui.input_buf.is_empty() or k.ui.input_buf[0] != 0x41),
			"rewind: a state is a copy, not the game going on (hp %d)" % k.st.chr.hp)
	k.st.chr.hp = 2
	var k2 := Game.create(screen)
	SaveGame.restore(k2, kept)
	check(k2.st.chr.hp == 30, "rewind: and going back to it twice gives it twice")
	k.dispose()
	k2.dispose()
	r.clear()
	check(r.snaps.is_empty(), "rewind: cleared")
	g.dispose()
	h.dispose()
	screen.queue_free()


func test_ui_translation() -> void:
	check("ja" in UiText.languages(), "interface: a Japanese translation")
	UiText.use("ja")
	check(TranslationServer.translate("Settings") == "設定" and TranslationServer.get_locale() == "ja",
			"interface: in Japanese (%s)" % TranslationServer.translate("Settings"))
	check(TranslationServer.translate("Loaded %s") % "TEST" == "TEST をロードしました", "interface: messages with values")
	check(TranslationServer.translate("no such message") == "no such message", "interface: unknown messages stay")
	# every character of the translation is in the font
	var font: FontFile = load(ModernText.FONT_PATH)
	var missing := {}
	for line in FileAccess.get_file_as_string("res://data/ui/ja.po").split("\n"):
		if line.begins_with("msgstr"):
			for i in line.length():
				var c := line.unicode_at(i)
				if c > 0x7e and not font.has_char(c):
					missing[line[i]] = true
	check(missing.is_empty(), "interface: the font has every character of the Japanese (missing %s)" % str(missing.keys()))
	# the PC-98 interface font: the game's glyphs, then DotGothic16, not the modern font, for all of it
	UiFont.pixel = true
	var dot: Font = (UiFont.font() as FontFile).fallbacks[0]
	var pixel := Import.pixel_font()  # (without fallbacks: has_char() looks in them too)
	var left := {}
	for line in FileAccess.get_file_as_string("res://data/ui/ja.po").split("\n"):
		if line.begins_with("msgstr"):
			for i in line.length():
				var c := line.unicode_at(i)
				if c > 0x7e and not pixel.has_char(c) and not dot.has_char(c):
					left[line[i]] = true
	check(left.keys() == [] or left.keys().all(func(c: String) -> bool: return c in "◀▶"),
			"interface: the PC-98 font (with DotGothic16) has the Japanese (left to the modern font: %s)" % str(left.keys()))
	check(pixel.has_char("A".unicode_at(0)) and pixel.has_char(0xff71) and not pixel.has_char("あ".unicode_at(0)),
			"interface: the game's glyphs for ASCII and half-width katakana only")
	check(UiFont.font().fallbacks.size() == 2, "interface: the PC-98 font falls back to DotGothic16, then Noto")
	UiFont.pixel = false
	UiText.use("en")
	check(TranslationServer.translate("Settings") == "Settings", "interface: back in English")
	UiText.use("xx")
	check(TranslationServer.get_locale() == "en", "interface: English for a language without a translation")


func test_journal() -> void:
	var screen: Screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	var path := "user://journal_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var g := _quick_game(screen)
	g.st.chr.name = "WALKER"
	g.st.floor = 2
	g.st.pos_x = 3
	g.st.pos_y = 4
	var j := Journal.new()
	j.path = path
	j.game = g
	g.sys.on_journal = j.add
	g.sys.journal(&"wall", "", "ABC")
	g.sys.journal(&"item", "ITEM", "")
	g.sys.journal(&"wall", "", "ABC")  # again: moved to the top
	g.sys.journal(&"victory", "RAT", "5")
	g.sys.journal(&"victory", "RAT", "5")  # each fight counts
	var e := j.entries()
	check(e.size() == 4 and e[0]["kind"] == "item" and e[1]["kind"] == "wall" and e[3]["kind"] == "victory",
			"journal: entries, oldest first, repeats moved to the top (%d)" % e.size())
	check(e[1]["floor"] == 2 and e[1]["x"] == 3 and e[1]["y"] == 4, "journal: where it happened")
	check(Journal.load_entries(path, "WALKER").size() == 4 and Journal.load_entries(path, "OTHER").is_empty(),
			"journal: kept per screamer")
	g.st.chr.name = "OTHER"
	check(j.entries().is_empty(), "journal: another screamer's own journal")
	Journal.forget(path, "WALKER")
	check(Journal.load_entries(path, "WALKER").is_empty(), "journal: forgotten with the screamer")
	check(j.shown("{ｱｲｳ}ｱ|_ﾝ") == "あいうｱ ﾝ", "journal: hiragana where { } asks, markup gone (%s)" % j.shown("{ｱｲｳ}ｱ|_ﾝ"))
	check(j.shown("{ｶﾞﾊﾟｳﾞ}ﾀﾞ") == "がぱゔﾀﾞ", "journal: voiced hiragana (%s)" % j.shown("{ｶﾞﾊﾟｳﾞ}ﾀﾞ"))
	check(j.shown("[b]") == "[lb]b]", "journal: no bbcode from the game text")
	UiText.use("en")
	var samurai: String = g.data.demo_strings["0x2eb"].trim_prefix("Name      : ").get_slice("_", 0).strip_edges()
	check(j.line({"kind": "hunter", "subject": "8", "text": "", "floor": 3, "x": 0, "y": 1}).ends_with("Met the hunter " + samurai),
			"journal: lines (%s)" % j.line({"kind": "hunter", "subject": "8", "text": "", "floor": 3, "x": 0, "y": 1}))
	# in English, nothing the journal can show stays in Japanese
	g.data.set_lang("en")
	var shown_texts := []
	for t in g.data.table("wall_texts") + g.data.table("ring_texts"):
		shown_texts.append(j.shown(t))
	for entry: Dictionary in g.data.talk:
		for r in entry["replies"]:
			shown_texts.append(j.shown(r))
	for i in range(0x40, 0x5b):
		shown_texts.append(j.shown(g.chara.item_name(i)))
	for k in g.data._monsters:
		var m := Monster.new()
		m.record = g.data.monster_record(int(k))
		shown_texts.append(j.shown(m.name))
	for n in range(1, Journal.HUNTER_PROFILES.size() + 1):
		shown_texts.append(j.hunter_name(n))
	var japanese := shown_texts.filter(func(t: String) -> bool:
		for i in t.length():
			var c := t.unicode_at(i)
			if (c >= 0xff61 and c <= 0xff9f) or (c >= 0x3041 and c <= 0x30ff):
				return true
		return false)
	check(japanese.is_empty(), "journal: all in English in English (%d of %d left: %s)" % [japanese.size(), shown_texts.size(), str(japanese.slice(0, 3))])
	g.data.set_lang("ja")
	# the game reports wall writings itself
	g.st.chr.name = "WALKER"
	g.sys.fix_bugs = true
	g.st.floor = 4
	g.common.load_floor_file()
	g.st.pos_x = 1
	g.st.pos_y = 8
	g.st.cell = g.st.map.bytes.slice(g.st.cell_off, g.st.cell_off + 8)
	await g.items._read_wall()
	e = j.entries()
	check(not e.is_empty() and e[-1]["kind"] == "wall" and e[-1]["floor"] == 4 and e[-1]["text"] != "",
			"journal: the game notes a wall writing")
	j.free()
	g.dispose()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	screen.queue_free()

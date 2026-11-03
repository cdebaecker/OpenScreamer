## The game window: the screen, the bar under it (KANA input, text language, sound, keyboard,
## settings, help), the keyboard and gamepad, the on-screen keyboard, the settings menu, the
## beeper, and real-time pacing of the game's virtual clock.
extends Control

## emitted every frame; the game coroutine waits on it when its virtual clock is ahead
signal tick

## the help: a heading and its text per row, laid out as a table so wrapped lines stay
## in their column whatever the font
const HELP := [
	["Menus", "Up / Down choose,  Space / Enter select,  Esc cancel"],
	["Walking in BIAS", "numeric keypad 8 forward, 4 6 turn, 2 turn around, 5 open a door\nwithout a keypad: W A D S and E\ngamepad: left stick, RB opens a door"],
	["Fighting", "4 6 walk, 8 jump (with 4/6 to leap), 2 crouch, 0 run away  (A D W S Q)\nZ attack, X defend, C command mode (items)\ngamepad: X attack, Y defend, Back command, LB run away; in menus d-pad, A select, B cancel"],
	["Typing", "names end with Space; Right types a space.\nTo talk to people, type a word to ask about: in a translation plain words work (in English e.g. drug, FRD, password, a monster's name).  In Japanese mode they only understand katakana: press ` (or the KANA button) and type romaji, e.g. doraggu gives ﾄﾞﾗｯｸﾞ.\nWith a gamepad, an on-screen keyboard comes up (also the Keyboard button): A types, B deletes, X space, LB/RB page (ABC, abc, katakana), Start OK."],
	["Port", "F6 quick save (in the town's menu or standing in BIAS),  F7 quick load\nF8 or M map of the floor (in BIAS; gamepad R3),  J journal (gamepad L3),  F9 fast-forward (RT)\nF10 / Start settings: language, font, display, sound, accessibility, saves, controls, roster\nF11 full screen,  F12 this help\nSaving, and going back a few steps on death: the Modern difficulty (settings: Game; Original plays as in 1985).\nOn a touch screen, touch it: buttons come up beside the picture (settings: Access)."],
]
const HELP_NOTICE := "THE SCREAMER — original game © 1985 Magical Zoo / ASCII Corporation, used with permission. This is an unofficial, non-commercial fan port, not affiliated with or endorsed by the copyright holders. It may not be sold or monetised in any way."


var game: Game
var keyboard: HostKeyboard
var settings := Settings.new()
var menu: SettingsMenu
var ambience: Ambience
var reader: Reader
var automap: Automap
var journal: Journal
var touch: TouchControls
var menu_theme := Theme.new()  # the menus, the journal, the map, the on-screen keyboard...
var bar_theme := Theme.new()  # the bar, the help, the notes
var rewind := Rewind.new()
var rewind_prompt: RewindPrompt
var _death_seen := false  # the game is (or was, until this frame) on the death screen
## the last load_slot / load_state worked
var last_load_ok := false  # the rewind prompt was shown for this game over
## a held d-pad button repeats (settings: Access): the button, and when it next repeats (ms)
var _pad_held := -1
var _pad_next := 0
var pad_repeats := 0  # counted, for tests
var osk: Osk
## where settings are kept (tests use another file)
var settings_path := Settings.PATH

## the host clock: real time, times `_speed` (fast-forward), from (_real0, _host0)
var _real0 := 0
var _host0 := 0
var _speed := 1.0
## fast-forward: toggled by F9, held with the gamepad's right trigger
var fast_forward := false
var _ff_trigger := false
var _hurried := false
## the last input came from a gamepad: the on-screen keyboard comes up for typing
var _pad_last := false
## the Keyboard button: show the on-screen keyboard for typing whatever the input
var _osk_on := false

@onready var screen: Screen = $Screen
@onready var beeper: Beeper = $Beeper
@onready var _kana_button: Button = $Bar/KanaToggle  # (it shows KANA mode and the romaji typed)
@onready var _lang_button: Button = $Bar/Lang
@onready var _mute_button: Button = $Bar/Mute
@onready var _help: PanelContainer = $Help
@onready var _osk_button: Button = $Bar/OskButton
@onready var _rewind_button: Button = $Bar/RewindButton
@onready var _ff_label: Label = $FastForward
@onready var _note: Label = $Note
var _note_until := 0


func now_us() -> int:
	if game.sys.hurry > 0 and settings.instant_text:  # typewriter text: no waiting
		_hurried = true
		return 1 << 62
	if _hurried:  # and on from where the text ended
		_hurried = false
		_rebase(game.sys.clock)
	return _host0 + int((Time.get_ticks_usec() - _real0) * _speed)


## the host clock reads `host_us` now and runs on at the current speed
func _rebase(host_us: int) -> void:
	_real0 = Time.get_ticks_usec()
	_host0 = host_us


func _set_speed(s: float) -> void:
	if s != _speed:
		_rebase(now_us())
		_speed = s
		beeper.speed = s


func _ready() -> void:
	GameData.settings_file = settings_path  # (the text language is kept with the other settings)
	game = Game.create(screen)
	keyboard = HostKeyboard.new(game.keys)
	keyboard.changed.connect(_update_kana)
	beeper.sys = game.sys
	game.sys.audio = beeper
	$Bar/KanaToggle.pressed.connect(keyboard.toggle_kana)
	_lang_button.pressed.connect(_toggle_lang)
	_mute_button.pressed.connect(_toggle_mute)
	$Bar/HelpButton.pressed.connect(_toggle_help)
	_osk_button.pressed.connect(_toggle_osk)
	$Bar/SettingsButton.pressed.connect(open_settings)
	_rewind_button.pressed.connect(_open_rewind)
	RenderingServer.set_default_clear_color(Color.BLACK)  # (around the picture: the touch controls' room)
	var t := menu_theme  # menus show names in katakana: use the font that has them
	theme = bar_theme  # the bar and the help: the same font (it has the interface's kanji)
	UiFont.set_size($Help/Text, &"normal_font_size", 11)
	UiFont.set_size($Help/Text, &"bold_font_size", 11)
	UiFont.set_size(_note, &"font_size", 15)
	osk = Osk.new()
	osk.keys = game.keys
	osk.theme = t
	osk.visible = false
	osk.position = Vector2(8, 6)
	osk.size = Vector2(624, 0)
	add_child(osk)
	ambience = Ambience.new()
	add_child(ambience)
	reader = Reader.new()
	reader.text = screen.text
	add_child(reader)
	automap = Automap.new()
	automap.game = game
	automap.theme = t
	automap.size = Vector2(640, 400)
	add_child(automap)
	journal = Journal.new()
	journal.game = game
	journal.theme = t
	journal.position = Vector2(20, 14)
	journal.size = Vector2(600, 380)
	add_child(journal)
	game.sys.on_journal = journal.add
	rewind_prompt = RewindPrompt.new()
	rewind_prompt.theme = t
	rewind_prompt.position = Vector2(120, 140)
	rewind_prompt.size = Vector2(400, 0)
	rewind_prompt.chosen.connect(_rewind_chosen)
	add_child(rewind_prompt)
	touch = TouchControls.new()
	touch.setup()
	touch.used.connect(_touch_used)
	add_child(touch)
	get_tree().root.size_changed.connect(layout_touch)
	menu = SettingsMenu.new()
	menu.theme = t
	menu.position = Vector2(14, 8)
	menu.size = Vector2(612, 424)
	add_child(menu)
	if not FileAccess.file_exists(settings_path) and OS.get_environment("SteamDeck") == "1":
		settings.fullscreen = true  # the first time on a Steam Deck
	settings.load_file(settings_path)
	settings.lang = game.data.lang
	settings.apply_bindings()
	menu.host = self
	menu.setup(settings, game)
	menu.changed.connect(_settings_changed)
	apply_settings()
	_update_kana()
	_rebase(0)
	game.sys.host = self
	game.program.run_program()  # runs as a coroutine driven by `tick`


func _exit_tree() -> void:
	game.dispose()  # break the module reference cycles


# ------------------------------------------------------------------ saved games

## save to a slot ("1".."5", "quick"); returns what happened
func save_slot(slot: String) -> String:
	if not settings.saves_allowed():
		return tr("No saving at the Original difficulty")
	var err := SaveGame.write(SaveGame.path_of(slot), game)
	return err if err != "" else (tr("Saved (quick save)") if slot == "quick" else tr("Saved (slot %s)") % slot)


## load a slot: the running game stops, a new one goes on from the saved state
func load_slot(slot: String) -> String:
	last_load_ok = false
	if not settings.saves_allowed():
		return tr("No loading at the Original difficulty")
	var d := SaveGame.read(SaveGame.path_of(slot))
	if d.is_empty():
		return tr("Nothing saved there")
	return load_state(d)


## a saved game's data (a slot's, or a rewind state): the running game stops, a new one goes on
func load_state(d: Dictionary) -> String:
	var g := Game.create(screen)
	# where the roster is kept stays the same, when it was replaced (scripted runs): the defaults
	# are the old game's own methods, gone with it
	if game.chara.save_load.get_object() != game.chara:
		g.chara.save_load = game.chara.save_load
		g.chara.save_store = game.chara.save_store
	g.data.set_lang(game.data.lang)
	SaveGame.restore(g, d["state"])
	if not SaveGame.ensure_in_roster(g):
		g.dispose()
		return tr("%s isn't in the roster and it's full: delete someone first") % d["name"]
	g.st.stood = 1  # back at the cell, as after turning: no new encounter on loading
	_replace_game(g)
	screen.clear_screen()
	screen.reset_palette()
	g.common.set_color4(g.st.color4)
	if d["where"] == "bias":  # the name, as the town printed it on the way in (town_screen_reset)
		g.txt.at(0x3d, 8, 0x3d)
		g.txt.print_raw(g.st.chr.name)
		g.txt.kana_mode = 0xff
	_rebase(g.sys.clock)
	g.program.run_from(SaveGame.target_of(StringName(d["where"])))
	last_load_ok = true
	return tr("Loaded %s") % d["name"]


## on the death screen, the bar's "Go back…" (R, gamepad Y): how far?
func _open_rewind() -> void:
	if _rewind_button.visible:
		rewind_prompt.open(rewind.of(game.st.chr.name).size())


## the player's answer: go back that many steps, or (0) not now (back to the death screen)
func _rewind_chosen(steps: int) -> void:
	var name := game.st.chr.name
	var d := rewind.back(name, steps)
	if steps == 0 or d.is_empty():
		return
	_death_seen = false  # (leaving the death screen this way isn't dying for good)
	# the states after it are gone (they lead here)
	var mine := rewind.of(name)
	for i in steps:
		rewind.snaps.erase(mine[mine.size() - 1 - i])
	rewind._last = ""
	load_state(d)
	notify((tr("Back 1 step: %s") if steps == 1 else tr("Back %d steps: %s") % [steps, "%s"]) % game.st.chr.name)


func _replace_game(g: Game) -> void:
	var old := game
	old.dispose()  # its coroutine stops at its next wait
	game = g
	keyboard = HostKeyboard.new(g.keys)
	keyboard.changed.connect(_update_kana)
	osk.keys = g.keys
	beeper.sys = g.sys
	g.sys.audio = beeper
	automap.game = g
	journal.game = g
	g.sys.on_journal = journal.add
	menu.game = g
	g.sys.host = self
	apply_settings()


func _update_kana() -> void:
	_kana_button.text = (tr("KANA ON") + " " + keyboard.pending).strip_edges() if keyboard.kana else tr("KANA OFF")
	_kana_button.add_theme_color_override(&"font_color", Color(0.29, 0.85, 0.57) if keyboard.kana else Color(0.7, 0.7, 0.76))


func _toggle_lang() -> void:
	var langs := game.data.languages()  # the next language
	settings.lang = langs[(langs.find(settings.lang) + 1) % langs.size()]
	_settings_changed()


func _show_lang() -> void:
	_lang_button.text = tr("Text: %s") % tr(game.data.language_name(game.data.lang)).get_slice(" (", 0).get_slice("（", 0)


func _toggle_mute() -> void:
	settings.muted = not settings.muted
	_settings_changed()


func _toggle_osk() -> void:
	_osk_on = not _osk_on
	_toggle_osk_text()


func _toggle_osk_text() -> void:
	_osk_button.text = tr("Keyboard: on") if _osk_on else tr("Keyboard: auto")


func open_settings() -> void:
	_help.visible = false
	menu.open_menu()


func _settings_changed() -> void:
	apply_settings()
	settings.save_file(settings_path)


## settings -> the window, the screen, the sound, the text
func apply_settings() -> void:
	UiText.use(settings.lang)  # the interface in the text's language (English if there's none)
	($Help/Text as RichTextLabel).text = _help_text()
	# KANA (typing katakana in romaji) is for talking to people in Japanese: translations take plain words
	var kana_ok := settings.lang == "ja"
	keyboard.kana_allowed = kana_ok
	if keyboard.kana and not kana_ok:
		keyboard.toggle_kana()
	_kana_button.visible = kana_ok
	osk.kana_page = kana_ok
	if not settings.saves_allowed():
		rewind.clear()
	_apply_ui_font()
	_update_kana()
	_toggle_osk_text()
	if menu.settings != null:
		menu._refresh()
	if game.data.lang != settings.lang:
		game.data.set_lang(settings.lang)
	_show_lang()
	screen.modern_font = settings.modern_font
	screen.style = {"sharp": Screen.Style.SHARP, "crt": Screen.Style.CRT, "soft": Screen.Style.SOFT}[settings.style]
	screen.scheme = settings.scheme
	screen.smooth_fades = settings.smooth_fades
	screen.large_text = settings.large_text
	get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if settings.integer_scale \
			else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if DisplayServer.get_name() != "headless":
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if full != settings.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	beeper.volume_db = linear_to_db(settings.volume / 100.0) if settings.volume > 0 else -80.0
	game.sys.muted = settings.muted
	game.sys.fix_bugs = settings.fix_bugs
	game.sys.pendant_fix = settings.pendant_fix
	beeper.tone = settings.tone
	ambience.enabled = settings.ambience and not settings.muted
	ambience.volume = settings.ambience_volume / 100.0
	reader.enabled = settings.screen_reader
	reader.lang = settings.lang
	_mute_button.text = tr("Sound: off") if settings.muted else tr("Sound: on")
	touch.mode = settings.touch
	layout_touch()


## the interface's font (Settings, Display)
func _apply_ui_font() -> void:
	UiFont.pixel = settings.ui_font == "pc98"
	menu_theme.default_font = UiFont.font()
	menu_theme.default_font_size = UiFont.size(13)
	bar_theme.default_font = UiFont.font()
	bar_theme.default_font_size = UiFont.size(14)  # (room for the longer Japanese labels)
	UiFont.refresh(self)
	touch.restyle()


## the touch controls shown or not; when shown, the game is centred in a window stretched to the
## screen's shape, so the controls fit beside it on a wide screen
func layout_touch() -> void:
	var root := get_tree().root
	var want := touch.wanted()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if want else Window.CONTENT_SCALE_ASPECT_KEEP
	var view := root.get_visible_rect().size
	touch.update(view)
	root.canvas_transform = Transform2D(0, ((view - TouchControls.GAME) / 2).floor() if want else Vector2.ZERO)


func _touch_used() -> void:
	if not touch.visible:
		layout_touch()


## a short message over the screen (saving, loading)
func notify(msg: String) -> void:
	_note.text = msg
	_note.visible = true
	_note_until = Time.get_ticks_msec() + 2500


func _toggle_help() -> void:
	_help.visible = not _help.visible


func _help_text() -> String:
	var rows := ""
	for row: Array in HELP:
		rows += "[cell padding=0,0,12,8][b]%s[/b][/cell][cell expand=1 padding=0,0,0,8]%s[/cell]" % [tr(row[0]), tr(row[1])]
	return "[table=2]%s[/table]\n%s" % [rows, tr(HELP_NOTICE)]


func _unhandled_input(event: InputEvent) -> void:
	if menu.visible or rewind_prompt.visible:  # they take their input themselves
		return
	if _help_event(event) or _rewind_event(event) or _map_event(event) or _journal_event(event):
		get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	if k != null:
		_pad_last = false
	elif pad:
		_pad_last = true
	if (k != null or pad) and event.device != TouchControls.DEVICE and touch.mode == "auto" and touch.touched:
		touch.touched = false  # back on the keyboard or a gamepad: the touch controls go away
		layout_touch()
	_update_osk()
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_F11:
			settings.fullscreen = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
			_settings_changed()
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_F12:
			_toggle_help()
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_F10:
			open_settings()
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_F9:
			fast_forward = not fast_forward
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_F6 or k.keycode == KEY_F7:
			notify(save_slot("quick") if k.keycode == KEY_F6 else load_slot("quick"))
			get_viewport().set_input_as_handled()
			return
	var trig := event as InputEventJoypadMotion
	if trig != null and trig.axis == JOY_AXIS_TRIGGER_RIGHT and Settings.pad_event_of_any(trig) == &"":
		_ff_trigger = trig.axis_value > 0.5
		get_viewport().set_input_as_handled()
		return
	var jb := event as InputEventJoypadButton
	if jb != null and jb.button_index >= JOY_BUTTON_DPAD_UP and jb.button_index <= JOY_BUTTON_DPAD_RIGHT:
		if jb.pressed:
			_pad_held = jb.button_index
			_pad_next = Time.get_ticks_msec() + settings.pad_repeat_delay
		elif jb.button_index == _pad_held:
			_pad_held = -1
	var used := _route(event)
	if used:
		get_viewport().set_input_as_handled()


## F8 / M / gamepad R3 show the map in BIAS; while it's shown, it takes all input (Esc / B close it too)
func _map_event(event: InputEvent) -> bool:
	var k := event as InputEventKey
	var jb := event as InputEventJoypadButton
	# (M as well: run from the Godot editor, F8 stops the game)
	var toggle := (k != null and k.pressed and not k.echo and (k.keycode == KEY_F8 or (k.physical_keycode == KEY_M and not game.ui.typing))) or \
			(jb != null and jb.pressed and jb.button_index == JOY_BUTTON_RIGHT_STICK)
	if toggle and (automap.visible or Ambience.area_of(game.program.current) == "bias"):
		automap.toggle()
		return true
	if automap.visible:
		if (k != null and k.pressed and k.keycode == KEY_ESCAPE) or (jb != null and jb.pressed and jb.button_index == JOY_BUTTON_B):
			automap.toggle()
		return true
	return false


## while the help is shown it takes all input (F12, Esc or the gamepad's B close it) and the game waits
func _help_event(event: InputEvent) -> bool:
	if not _help.visible:
		return false
	var k := event as InputEventKey
	var jb := event as InputEventJoypadButton
	if (k != null and k.pressed and not k.echo and k.keycode in [KEY_ESCAPE, KEY_F12]) or 			(jb != null and jb.pressed and jb.button_index == JOY_BUTTON_B):
		_toggle_help()
	return true


## R / gamepad Y on the death screen: go back a few steps
func _rewind_event(event: InputEvent) -> bool:
	if not _rewind_button.visible:
		return false
	var k := event as InputEventKey
	var jb := event as InputEventJoypadButton
	if (k != null and k.pressed and not k.echo and k.physical_keycode == KEY_R) or 			(jb != null and jb.pressed and jb.button_index == JOY_BUTTON_Y):
		_open_rewind()
		return true
	return false


## J / gamepad L3 show the journal (not while typing); while it's shown it takes all input
func _journal_event(event: InputEvent) -> bool:
	var k := event as InputEventKey
	var jb := event as InputEventJoypadButton
	var toggle := (k != null and k.pressed and not k.echo and k.physical_keycode == KEY_J and not game.ui.typing) or \
			(jb != null and jb.pressed and jb.button_index == JOY_BUTTON_LEFT_STICK)
	if toggle and (journal.visible or game.st.chr.name != ""):
		journal.toggle()
		return true
	if journal.visible:
		if (k != null and k.pressed and k.keycode == KEY_ESCAPE) or (jb != null and jb.pressed and jb.button_index == JOY_BUTTON_B):
			journal.toggle()
		return true
	return false


## a key or gamepad event to the game (or the on-screen keyboard); true when used
func _route(event: InputEvent) -> bool:
	var k := event as InputEventKey
	var used := false
	if k != null:
		used = keyboard.key_event(k)
	elif osk.visible and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		used = osk.joy_event(event)
	elif event is InputEventJoypadButton:
		if event.pressed and event.button_index == JOY_BUTTON_START:
			open_settings()
			used = true
		else:
			used = keyboard.joy_event(event)
	return used


func _update_osk() -> void:
	osk.visible = game.ui.typing and (_pad_last or _osk_on or touch.visible) and not menu.visible
	if osk.visible:  # out of the way of the line being typed
		osk.position.y = 400 - osk.size.y - 4 if game.txt.row < 13 else 6


func _process(_delta: float) -> void:
	_update_osk()
	touch.make_way(menu.visible)
	if _note.visible and Time.get_ticks_msec() > _note_until:
		_note.visible = false
	ambience.area = Ambience.area_of(game.program.current)
	if ambience.area == "bias":
		automap.record()
	elif automap.visible:
		automap.toggle()
	if _pad_held >= 0 and settings.pad_repeat and not menu.visible and Time.get_ticks_msec() >= _pad_next:
		_pad_next = Time.get_ticks_msec() + settings.pad_repeat_rate
		var e := InputEventJoypadButton.new()
		e.button_index = _pad_held as JoyButton
		e.pressed = true
		_route(e)
		pad_repeats += 1
	if settings.saves_allowed():
		rewind.record(game)
	# on the death screen (left as the original shows it) the bar offers going back a few steps
	var dead := game.program.current == &"game_over"
	_rewind_button.visible = dead and settings.saves_allowed() and not rewind.of(game.st.chr.name).is_empty()
	if dead:
		_death_seen = true
	elif _death_seen:  # Space on the death screen: dead for good, nothing to go back to any more
		_death_seen = false
		rewind.clear()
	if menu.visible or automap.visible or rewind_prompt.visible or journal.visible or _help.visible:
		return  # paused: the game waits for the next tick
	_set_speed(float(settings.ff_speed) if fast_forward or _ff_trigger else 1.0)
	_ff_label.visible = _speed > 1.0
	_ff_label.text = "» x%d" % int(_speed)
	tick.emit()
	# the virtual clock follows real time; after a stall it doesn't try to catch up
	var lag := now_us() - game.sys.clock
	if lag > 200000:
		_host0 -= lag - 20000

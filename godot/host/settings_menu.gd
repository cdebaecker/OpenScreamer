## The settings menu (F10, the Settings button, or Start on the gamepad): game, display, sound and
## accessibility options, controls (rebinding keys and gamepad buttons), and the roster of
## registered screamers.  The game is
## paused while it's open.  Works with the mouse, the keyboard (arrows, Enter, Esc) and a gamepad
## (d-pad, A, B; LB / RB change the page).
class_name SettingsMenu
extends PanelContainer

signal closed
## the settings changed: apply them (and save)
signal changed

var settings: Settings
var game: Game
## the window: saves and loads games (save_slot, load_slot)
var host: Node
var _save_rows := {}  # slot -> [label, save button, load button, delete button]

var _tabs: TabContainer
var _rows := {}  # option name -> its value button / control
var _bind_buttons := {}  # [action, "key" | "pad"] -> Button
var _capture: Array = []  # [action, "key" | "pad"] while waiting for an input to bind
var _status: Label
var _roster_list: VBoxContainer
var _roster_note: Label
var _roster_sel := -1
var _delete_button: Button
var _delete_armed := false
var _file_dialog: FileDialog
var _file_mode := ""

## the option pages: [page, rows]; a row is ["choice", title, setting, [[value, label], ...]],
## ["check", title, setting] or ["slider", title, setting, min, max, step]
const PAGES := [
	["Game", [
		["choice", "Text language", "lang", []],  # filled from the game's languages
		["choice", "Typewriter text", "instant_text", [[false, "Original speed"], [true, "Instant"]]],
		["choice", "Fast-forward (F9, RT)", "ff_speed", [[2, "x2"], [4, "x4"], [8, "x8"]]],
		["choice", "The way to floor 6", "pendant_fix", [[true, "Open, as on the PC-88"], [false, "Closed, as on the PC-98"]]],
		["choice", "Difficulty", "difficulty", [["modern", "Modern: saving, going back on death"], ["original", "Original (1985): no saving, death is final"]]],
		["choice", "Other original bugs", "fix_bugs", [[false, "Kept, as in 1985"], [true, "Fixed (changes the game)"]]],
	]],
	["Display", [
		["choice", "Game text font", "modern_font", [[false, "PC-98 (original 8x8)"], [true, "Modern (Noto Sans JP)"]]],
		["choice", "Interface font", "ui_font", [["pc98", "PC-98 (the game's own)"], ["modern", "Modern (Noto Sans JP)"]]],
		["choice", "Text size", "large_text", [[false, "Normal"], [true, "Large (modern font)"]]],
		["choice", "Style", "style", [["sharp", "Sharp"], ["crt", "CRT (curved glass, scanlines)"], ["soft", "Soft (dithering blended)"]]],
		["choice", "Colours", "scheme", [["original", "Original"], ["high_contrast", "High contrast"], ["colour_blind", "Colour-blind friendly"]]],
		["choice", "Colour changes", "smooth_fades", [[false, "At once (original)"], [true, "Smooth fades"]]],
		["choice", "Window scaling", "integer_scale", [[false, "Fit the window"], [true, "Whole multiples (sharp pixels)"]]],
		["check", "Full screen (F11)", "fullscreen"],
	]],
	["Sound", [
		["choice", "Sound", "muted", [[false, "On"], [true, "Off"]]],
		["slider", "Beeper volume", "volume", 0, 100, 5],
		["choice", "Beeper sound", "tone", [["square", "PC-98 beeper"], ["soft", "Softer"], ["sine", "Pure tone"]]],
		["check", "Background ambience", "ambience"],
		["slider", "Ambience volume", "ambience_volume", 0, 100, 5],
	]],
	["Access", [
		["check", "Read new text aloud", "screen_reader"],
		["choice", "Touch controls", "touch", [["auto", "On a touch screen, once touched"], ["on", "Always shown"], ["off", "Never"]]],
		["check", "Held d-pad repeats in menus", "pad_repeat"],
		["slider", "Repeat delay (ms)", "pad_repeat_delay", 150, 1000, 50],
		["slider", "Repeat rate (ms)", "pad_repeat_rate", 30, 400, 10],
	]],
]
## shown under the Access page
const ACCESS_NOTE := "Also: Display has large text, high-contrast and colour-blind colours, and smooth colour changes; Controls rebinds keys and buttons; Game has instant text and fast-forward."


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.07, 0.1)
	bg.border_color = Color(0.3, 0.3, 0.36)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(10)
	add_theme_stylebox_override("panel", bg)


func setup(s: Settings, g: Game) -> void:
	settings = s
	game = g
	var box := VBoxContainer.new()
	add_child(box)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(func(_t: int) -> void: _focus_first())
	box.add_child(_tabs)
	for p: Array in PAGES:
		_tabs.add_child(_option_page(p[0], p[1]))
	_tabs.add_child(_saves_page())
	_tabs.add_child(_controls_page())
	_tabs.add_child(_roster_page())
	var foot := HBoxContainer.new()
	box.add_child(foot)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	UiFont.set_size(_status, &"font_size", 11)
	_status.modulate = Color(0.75, 0.75, 0.82)
	_status.text = tr("LB / RB: page   B / Esc: back to the game")
	foot.add_child(_status)
	var close := Button.new()
	close.text = UiText.N_("Back to the game")
	close.pressed.connect(close_menu)
	foot.add_child(close)


func open_menu() -> void:
	visible = true
	_capture = []
	_refresh()
	_focus_first()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	_capture = []
	_delete_armed = false
	var f := get_viewport().gui_get_focus_owner()
	if f != null:
		f.release_focus()
	closed.emit()


func _focus_first() -> void:
	var page := _tabs.get_current_tab_control()
	if page == null:
		return
	var c := _first_focusable(page)
	if c != null:
		c.grab_focus.call_deferred()


func _first_focusable(n: Node) -> Control:
	for c in n.get_children():
		var ctl := c as Control
		if ctl != null and ctl.visible and ctl.focus_mode == Control.FOCUS_ALL and not (ctl is BaseButton and ctl.disabled):
			return ctl
		var deeper := _first_focusable(c)
		if deeper != null:
			return deeper
	return null


# ------------------------------------------------------------------ option pages

func _option_page(title: String, rows: Array) -> Control:
	var box := VBoxContainer.new()
	box.name = title
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for r: Array in rows:
		grid.add_child(_label(r[1]))
		var key: String = r[2]
		match r[0]:
			"choice":
				var b := Button.new()
				b.custom_minimum_size = Vector2(300, 0)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.clip_text = true  # (a long choice doesn't widen the menu)
				b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.pressed.connect(_step_choice.bind(key, 1))
				b.gui_input.connect(func(e: InputEvent) -> void:
					if e.is_action_pressed(&"ui_left") or e.is_action_pressed(&"ui_right"):
						_step_choice(key, -1 if e.is_action_pressed(&"ui_left") else 1)
						b.accept_event())
				grid.add_child(b)
				_rows[key] = [b, r[3] if key != "lang" else _languages()]
			"check":
				var c := CheckButton.new()
				c.toggled.connect(func(on: bool) -> void:
					settings.set(key, on)
					changed.emit())
				grid.add_child(c)
				_rows[key] = [c]
			"slider":
				var h := HBoxContainer.new()
				var sl := HSlider.new()
				sl.min_value = r[3]
				sl.max_value = r[4]
				sl.step = r[5]
				sl.custom_minimum_size = Vector2(220, 0)
				sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var val := _label("")
				sl.value_changed.connect(func(v: float) -> void:
					settings.set(key, int(v))
					val.text = str(int(v))
					changed.emit())
				h.add_child(sl)
				h.add_child(val)
				grid.add_child(h)
				_rows[key] = [sl, val]
	if title == "Access":
		var note := _label(ACCESS_NOTE)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiFont.set_size(note, &"font_size", 11)
		note.modulate = Color(0.7, 0.7, 0.78)
		box.add_child(note)
	return box


## the text languages: the original Japanese, and the translations the game has
func _languages() -> Array:
	var out := []
	for l: String in game.data.languages():
		out.append([l, game.data.language_name(l)])
	return out


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _step_choice(key: String, d: int) -> void:
	var opts: Array = _rows[key][1]
	var i := 0
	for j in opts.size():
		if opts[j][0] == settings.get(key):
			i = j
	settings.set(key, opts[posmod(i + d, opts.size())][0])
	_refresh()
	changed.emit()


## show a page by its name
func show_page(name: String) -> void:
	for i in _tabs.get_tab_count():
		if _tabs.get_tab_control(i).name == name:
			_tabs.current_tab = i


# ------------------------------------------------------------------ the saves page

func _saves_page() -> Control:
	var box := VBoxContainer.new()
	box.name = "Saves"
	var note := _label(UiText.N_("Save in the town's menu or standing in BIAS (F6 quick save, F7 quick load). Loading goes back to the town or the cell; the roster keeps the screamer as last saved in town."))
	UiFont.set_size(note, &"font_size", 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color(0.7, 0.7, 0.78)
	box.add_child(note)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var slots := ["quick"]
	for i in SaveGame.SLOTS:
		slots.append(str(i + 1))
	for slot: String in slots:
		var l := _label("")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.custom_minimum_size = Vector2(330, 0)
		grid.add_child(l)
		var row := [l]
		for act in ["Save", "Load", "Delete"]:
			var b := Button.new()
			b.text = {"Save": UiText.N_("Save"), "Load": UiText.N_("Load"), "Delete": UiText.N_("Delete")}[act]
			b.pressed.connect(_save_action.bind(slot, act))
			grid.add_child(b)
			row.append(b)
		_save_rows[slot] = row
	return box


func _save_action(slot: String, act: String) -> void:
	var msg := ""
	match act:
		"Save":
			msg = host.save_slot(slot)
		"Load":
			msg = host.load_slot(slot)
			if host.last_load_ok:
				close_menu()
				host.notify(msg)
				return
		"Delete":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path_of(slot)))
			msg = tr("Deleted the saved game")
	_status.text = msg
	_fill_saves()


func _fill_saves() -> void:
	var allowed: bool = host.settings.saves_allowed()
	var can_save := allowed and game.ui.rest != &""
	for slot: String in _save_rows:
		var r: Array = _save_rows[slot]
		var d := SaveGame.read(SaveGame.path_of(slot))
		(r[0] as Label).text = "%s:  %s" % [tr("Quick") if slot == "quick" else tr("Slot %s") % slot, SaveGame.describe(d)]
		(r[1] as Button).disabled = not can_save
		(r[2] as Button).disabled = d.is_empty() or not allowed
		(r[3] as Button).disabled = d.is_empty()


# ------------------------------------------------------------------ the controls page

func _controls_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Controls"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for t in [UiText.N_("Action"), UiText.N_("Keypad"), UiText.N_("Key"), UiText.N_("Gamepad")]:
		var l := _label(t)
		l.modulate = Color(0.7, 0.7, 0.78)
		grid.add_child(l)
	for a in Settings.ACTIONS:
		grid.add_child(_label(Settings.ACTION_NAMES[a]))  # (translated by the Label)
		grid.add_child(_label(""))  # keypad keys, filled in _refresh
		for kind in ["key", "pad"]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(120, 0)
			b.pressed.connect(_start_capture.bind(a, kind))
			grid.add_child(b)
			_bind_buttons[[a, kind]] = b
	var reset := Button.new()
	reset.text = UiText.N_("Reset to the defaults")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void:
		settings.reset_bindings()
		_refresh()
		changed.emit())
	box.add_child(reset)
	var note := _label(UiText.N_("Menus: arrows, Space / Enter, Esc; gamepad d-pad, A, B.  The keypad keys stay as on the PC-98.  Start / F10: this menu,  F11: full screen,  F12: help."))
	UiFont.set_size(note, &"font_size", 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color(0.7, 0.7, 0.78)
	box.add_child(note)
	return scroll


func _start_capture(action: StringName, kind: String) -> void:
	_capture = [action, kind]
	(_bind_buttons[_capture] as Button).text = tr("press a key…") if kind == "key" else tr("press a button…")
	_status.text = tr("Esc / Start: cancel")


## keys the menu and the window keep for themselves
const RESERVED_KEYS := [KEY_ESCAPE, KEY_F10, KEY_F11, KEY_F12, KEY_QUOTELEFT, KEY_ENTER, KEY_KP_ENTER,
		KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_BACKSPACE, KEY_DELETE]
const RESERVED_BUTTONS := [JOY_BUTTON_START, JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]


## while capturing: the event to bind, if it is one; returns true when the event was used
func capture_event(e: InputEvent) -> bool:
	if _capture.is_empty():
		return false
	var k := e as InputEventKey
	var jb := e as InputEventJoypadButton
	var jm := e as InputEventJoypadMotion
	if (k != null and k.pressed and k.physical_keycode == KEY_ESCAPE) or (jb != null and jb.pressed and jb.button_index == JOY_BUTTON_START):
		_end_capture("")
		return true
	var action: StringName = _capture[0]
	if _capture[1] == "key" and k != null and k.pressed and not k.echo:
		var code := int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
		if code in RESERVED_KEYS or (code >= KEY_KP_MULTIPLY and code <= KEY_KP_9):
			_status.text = tr("%s is kept for menus and typing; choose another key") % OS.get_keycode_string(code)
			return true
		settings.bind_key(action, code)
		_end_capture("")
		return true
	if _capture[1] == "pad":
		if jb != null and jb.pressed:
			if jb.button_index in RESERVED_BUTTONS:
				_status.text = tr("%s is kept for menus; choose another button") % Settings.describe_pad(jb)
				return true
			settings.bind_pad(action, jb)
			_end_capture("")
			return true
		if jm != null and absf(jm.axis_value) > 0.6:
			settings.bind_pad(action, jm)
			_end_capture("")
			return true
	# swallow everything else while waiting (but not the mouse)
	return k != null or jb != null or jm != null


func _end_capture(msg: String) -> void:
	var b: Button = _bind_buttons.get(_capture)
	_capture = []
	_refresh()
	if b != null:
		b.grab_focus()
	_status.text = msg if msg != "" else tr("LB / RB: page   B / Esc: back to the game")
	changed.emit()


# ------------------------------------------------------------------ the roster page

func _roster_page() -> Control:
	var box := VBoxContainer.new()
	box.name = "Roster"
	_roster_note = _label("")
	UiFont.set_size(_roster_note, &"font_size", 11)
	_roster_note.modulate = Color(0.7, 0.7, 0.78)
	_roster_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_roster_note)
	_roster_list = VBoxContainer.new()
	_roster_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_roster_list)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_delete_button = Button.new()
	_delete_button.pressed.connect(_delete_pressed)
	actions.add_child(_delete_button)
	var restore := Button.new()
	restore.text = UiText.N_("Empty the roster")
	restore.pressed.connect(func() -> void: _write_roster(GameData.empty_roster(), tr("Emptied the roster")))
	actions.add_child(restore)
	if not OS.has_feature("web"):
		var exp := Button.new()
		exp.text = UiText.N_("Export…")
		exp.set_meta("always", true)  # (exporting works whenever)
		exp.pressed.connect(_open_file.bind("export"))
		actions.add_child(exp)
		var imp := Button.new()
		imp.text = UiText.N_("Import…")
		imp.pressed.connect(_open_file.bind("import"))
		actions.add_child(imp)
	return box


## the roster as saved (the game keeps a copy in memory from registration on)
func roster_bytes() -> PackedByteArray:
	var d: PackedByteArray = game.chara.save_load.call()
	return d if RosterFile.valid(d) else GameData.empty_roster()


## the roster can change only before a screamer is picked (title, demo, registration questions):
## later the game holds one of them
func roster_editable() -> bool:
	return game.st.chr.record[0] == 0


func _fill_roster() -> void:
	for c in _roster_list.get_children():
		_roster_list.remove_child(c)
		c.queue_free()
	var list := RosterFile.entries(roster_bytes())
	if _roster_sel >= list.size():
		_roster_sel = -1
	var group := ButtonGroup.new()
	for i in list.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%d.  %s" % [i + 1, RosterFile.describe(list[i])]
		b.button_pressed = i == _roster_sel
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_roster_sel = i
				_delete_armed = false
				_update_roster_buttons())
		_roster_list.add_child(b)
	if list.is_empty():
		_roster_list.add_child(_label(UiText.N_("(no one registered)")))
	var editable := roster_editable()
	_roster_note.text = (tr("%d of 7 places taken.  Select a screamer to delete them.") % list.size()) if editable else \
			tr("%d of 7 places taken.  The roster can be changed at the registration screen, before a screamer is chosen.") % list.size()
	_update_roster_buttons()


func _update_roster_buttons() -> void:
	var editable := roster_editable()
	var list := RosterFile.entries(roster_bytes())
	_delete_button.disabled = not editable or _roster_sel < 0
	if _delete_armed and _roster_sel >= 0:
		_delete_button.text = tr("Really delete %s?") % list[_roster_sel].name
	else:
		_delete_button.text = tr("Delete")
	for c in _delete_button.get_parent().get_children():
		if c != _delete_button and c is Button:
			(c as Button).disabled = not editable and not c.has_meta("always")


func _delete_pressed() -> void:
	if _roster_sel < 0 or not roster_editable():
		return
	if not _delete_armed:
		_delete_armed = true
		_update_roster_buttons()
		return
	var name := RosterFile.entries(roster_bytes())[_roster_sel].name
	_write_roster(RosterFile.delete(roster_bytes(), _roster_sel), tr("Deleted %s") % name)
	Automap.forget(Automap.PATH, name)
	Journal.forget(Journal.PATH, name)
	_roster_sel = -1


## save a new roster and give it to the game
func _write_roster(d: PackedByteArray, msg: String) -> void:
	if not roster_editable():
		return
	apply_roster(game, d)
	_delete_armed = false
	_fill_roster()
	_status.text = msg
	_focus_first()


static func apply_roster(g: Game, d: PackedByteArray) -> void:
	g.chara.save_store.call(d)
	g.chara.load_roster()
	g.town.roster_count = g.chara.roster_count()


func _open_file(mode: String) -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.use_native_dialog = true
		_file_dialog.file_selected.connect(_file_chosen)
		add_child(_file_dialog)
	_file_mode = mode
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if mode == "export" else FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.title = tr("Export the roster (CHAR file)") if mode == "export" else tr("Import a roster (CHAR file)")
	_file_dialog.current_file = "CHAR"
	_file_dialog.popup_centered(Vector2i(560, 360))


func _file_chosen(path: String) -> void:
	_status.text = file_action(_file_mode, path)


## export the roster to a file, or import one; returns what happened
func file_action(mode: String, path: String) -> String:
	if mode == "export":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return tr("Couldn't write %s") % path
		f.store_buffer(roster_bytes())
		f.close()
		return tr("Exported to %s") % path
	if not roster_editable():
		return tr("The roster can be changed at the registration screen")
	var d := FileAccess.get_file_as_bytes(path)
	if not RosterFile.valid(d):
		return tr("%s isn't a roster (a CHAR file is 1024 bytes)") % path.get_file()
	_write_roster(d, tr("Imported %s") % path.get_file())
	return _status.text


# ------------------------------------------------------------------ showing the values

func _refresh() -> void:
	for i in _tabs.get_tab_count():
		_tabs.set_tab_title(i, tr(String(_tabs.get_tab_control(i).name)))
	for key: String in _rows:
		var r: Array = _rows[key]
		var v: Variant = settings.get(key)
		if r[0] is CheckButton:
			(r[0] as CheckButton).set_pressed_no_signal(v)
		elif r[0] is HSlider:
			(r[0] as HSlider).set_value_no_signal(v)
			(r[1] as Label).text = str(v)
		else:
			for o: Array in r[1]:
				if o[0] == v:
					(r[0] as Button).text = "◀  %s  ▶" % tr(o[1])
	for k: Array in _bind_buttons:
		var b: Button = _bind_buttons[k]
		if k == _capture:
			continue
		b.text = Settings.describe_key(Settings.key_event_of(k[0])) if k[1] == "key" else Settings.describe_pad(Settings.pad_event_of(k[0]))
	var grid := (_bind_buttons[[Settings.ACTIONS[0], "key"]] as Button).get_parent()
	for i in Settings.ACTIONS.size():
		var names := Settings.keypad_keys_of(Settings.ACTIONS[i]).map(func(e: InputEventKey) -> String: return OS.get_keycode_string(e.physical_keycode))
		(grid.get_child(4 + i * 4 + 1) as Label).text = ", ".join(names) if not names.is_empty() else "—"
	_fill_roster()
	_fill_saves()


# ------------------------------------------------------------------ input

func _input(e: InputEvent) -> void:
	if not visible:
		return
	if capture_event(e):
		get_viewport().set_input_as_handled()
		return
	if _file_dialog != null and _file_dialog.visible:
		return
	var k := e as InputEventKey
	var jb := e as InputEventJoypadButton
	if (k != null and k.pressed and not k.echo and k.keycode in [KEY_ESCAPE, KEY_F10]) or \
			(jb != null and jb.pressed and jb.button_index in [JOY_BUTTON_B, JOY_BUTTON_START]):
		close_menu()
		get_viewport().set_input_as_handled()
	elif jb != null and jb.pressed and jb.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		_tabs.current_tab = posmod(_tabs.current_tab + (1 if jb.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1), _tabs.get_tab_count())
		get_viewport().set_input_as_handled()

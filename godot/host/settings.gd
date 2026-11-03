## The player's settings, kept in user://settings.cfg: text language, font, display, sound, game
## options, accessibility, and the rebound keys and gamepad buttons.  All of it is presentation and
## input, except fix_bugs (off by default), which changes how the game behaves.
class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"

## the actions the player can rebind: a key (besides the keypad's, which stay as on the PC-98) and
## a gamepad button or stick direction each
const ACTIONS: Array[StringName] = [&"forward", &"back", &"turn_left", &"turn_right", &"open_door", &"flee",
		&"attack", &"defend", &"command"]
const ACTION_NAMES := {
	&"forward": "Walk forward / jump", &"back": "Turn around / crouch", &"turn_left": "Turn left / step left",
	&"turn_right": "Turn right / step right", &"open_door": "Open a door", &"flee": "Run away",
	&"attack": "Attack", &"defend": "Defend", &"command": "Command (items)",
}

var lang := "en"  # "ja" (the original), "en", or another translation pack
# display
var modern_font := false  # the game's text
## the interface's font: "pc98" (the game's own glyphs) or "modern" (Noto Sans JP)
var ui_font := "pc98"
var large_text := false  # the modern font, bigger
var style := "sharp"  # "sharp", "crt", "soft"
var scheme := "original"  # colours: "original", "high_contrast", "colour_blind"
var smooth_fades := false
var integer_scale := false
var fullscreen := false
# sound
var muted := false
var volume := 80  # the beeper, percent
var tone := "square"  # the beeper's sound: "square" (the PC-98's), "soft", "sine"
var ambience := false  # a quiet background layer (town, BIAS)
var ambience_volume := 40
# game
var instant_text := false  # typewriter text (item reports, the credits) shown at once
var ff_speed := 4  # how fast fast-forward runs the game (F9 / gamepad right trigger)
var fix_bugs := false  # the original's bugs fixed (see Ui / Town): changes the game, off by default
## the way to floor 6 open (as on the PC-88): the pendant chain and the last doors (Sys.pendant_fix)
var pendant_fix := true
## "modern": saving at rest points (quick save, slots) and going back a few steps on death (Rewind);
## "original": neither, as in 1985 (the roster still keeps the screamer, as the original does)
var difficulty := "modern"
# accessibility
var screen_reader := false  # read new text aloud (text to speech)
## the on-screen touch controls: "auto" (on a touch screen, once touched), "on", "off"
var touch := "auto"
var pad_repeat := true  # held d-pad repeats in menus
var pad_repeat_delay := 400  # ms
var pad_repeat_rate := 90  # ms
## action -> {"key": physical keycode} and/or {"pad": [button] or [axis, direction]}; only the
## changed ones are kept, the others come from the project's input map
var bindings := {}

## the stored settings: name -> [section, allowed values: choices, a [min, max] range of ints (two
## ints), or null for a bool]
const FIELDS := {
	"lang": ["game", null], "instant_text": ["game", null], "ff_speed": ["game", [2, 4, 8]],
	"fix_bugs": ["game", null], "pendant_fix": ["game", null], "difficulty": ["game", ["modern", "original"]],
	"modern_font": ["display", null], "ui_font": ["display", ["pc98", "modern"]], "large_text": ["display", null],
	"style": ["display", ["sharp", "crt", "soft"]], "scheme": ["display", ["original", "high_contrast", "colour_blind"]],
	"smooth_fades": ["display", null], "integer_scale": ["display", null], "fullscreen": ["display", null],
	"muted": ["sound", null], "volume": ["sound", [0, 100]], "tone": ["sound", ["square", "soft", "sine"]],
	"ambience": ["sound", null], "ambience_volume": ["sound", [0, 100]],
	"screen_reader": ["access", null], "touch": ["access", ["auto", "on", "off"]], "pad_repeat": ["access", null],
	"pad_repeat_delay": ["access", [150, 1000]], "pad_repeat_rate": ["access", [30, 400]],
}


## saving, loading and rewinding allowed (the Modern difficulty)
func saves_allowed() -> bool:
	return difficulty == "modern"


func load_file(path := PATH) -> void:
	var f := ConfigFile.new()
	if f.load(path) != OK:
		return
	for k: String in FIELDS:
		var sec: String = FIELDS[k][0]
		var allowed: Variant = FIELDS[k][1]
		var v: Variant = f.get_value(sec, k, get(k))
		if k == "lang":
			if v is String and (v as String).length() in [2, 3, 5]:
				set(k, v)
		elif allowed == null:
			set(k, bool(v))
		elif allowed.size() == 2 and allowed[0] is int:  # a range
			set(k, clampi(int(v), allowed[0], allowed[1]))
		elif v in allowed:
			set(k, v)
	if f.get_value("display", "crt", false) == true and not f.has_section_key("display", "style"):
		style = "crt"  # settings from before display styles
	bindings = {}
	var b: Variant = f.get_value("input", "bindings", {})
	if b is Dictionary:
		for a in b:
			if StringName(a) in ACTIONS and b[a] is Dictionary:
				bindings[StringName(a)] = b[a]


func save_file(path := PATH) -> void:
	var f := ConfigFile.new()
	f.load(path)  # keep what others keep there
	for k: String in FIELDS:
		f.set_value(FIELDS[k][0], k, get(k))
	if f.has_section_key("display", "crt"):
		f.erase_section_key("display", "crt")
	var b := {}
	for a: StringName in bindings:
		b[String(a)] = bindings[a]
	f.set_value("input", "bindings", b)
	f.save(path)


# ------------------------------------------------------------------ bindings

## the project's input map, then the player's changes
static func reset_input_map() -> void:
	InputMap.load_from_project_settings()
	# menus with a gamepad: A accepts, B cancels (Godot's defaults have them on the keyboard only)
	for pair in [[&"ui_accept", JOY_BUTTON_A], [&"ui_cancel", JOY_BUTTON_B]]:
		var b := InputEventJoypadButton.new()
		b.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], b):
			InputMap.action_add_event(pair[0], b)


func apply_bindings() -> void:
	reset_input_map()
	for a: StringName in bindings:
		var b: Dictionary = bindings[a]
		if b.has("key"):
			_replace(a, key_event_of(a), _key(int(b["key"])))
		if b.has("pad"):
			_replace(a, pad_event_of(a), _pad(b["pad"]))


func bind_key(action: StringName, keycode: int) -> void:
	var b: Dictionary = bindings.get(action, {})
	b["key"] = keycode
	bindings[action] = b
	apply_bindings()


## a gamepad event: a button press or a stick pushed (axis, direction)
func bind_pad(action: StringName, e: InputEvent) -> void:
	var b: Dictionary = bindings.get(action, {})
	b["pad"] = pad_spec(e)
	bindings[action] = b
	apply_bindings()


func reset_bindings() -> void:
	bindings = {}
	apply_bindings()


static func pad_spec(e: InputEvent) -> Array:
	if e is InputEventJoypadButton:
		return [int(e.button_index)]
	var m := e as InputEventJoypadMotion
	return [int(m.axis), 1 if m.axis_value > 0 else -1]


static func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	return e


static func _pad(spec: Array) -> InputEvent:
	if spec.size() == 1:
		var b := InputEventJoypadButton.new()
		b.button_index = int(spec[0]) as JoyButton
		return b
	var m := InputEventJoypadMotion.new()
	m.axis = int(spec[0]) as JoyAxis
	m.axis_value = 1.0 if int(spec[1]) > 0 else -1.0
	return m


static func _is_keypad(e: InputEventKey) -> bool:
	return e.physical_keycode >= KEY_KP_MULTIPLY and e.physical_keycode <= KEY_KP_9


## the rebindable key of an action: its key that isn't on the keypad
static func key_event_of(action: StringName) -> InputEventKey:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and not _is_keypad(e):
			return e
	return null


## the rebindable action a gamepad input drives, &"" if none
static func pad_event_of_any(e: InputEvent) -> StringName:
	for a in ACTIONS:
		if _same(pad_event_of(a), e) if pad_event_of(a) != null else false:
			return a
	return &""


static func pad_event_of(action: StringName) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			return e
	return null


## the keypad keys of an action (fixed)
static func keypad_keys_of(action: StringName) -> Array[InputEventKey]:
	var out: Array[InputEventKey] = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and _is_keypad(e):
			out.append(e)
	return out


## a key bound to a gameplay action doesn't repeat while held (see HostKeyboard)
static func is_action_key(keycode: int) -> bool:
	for a in ACTIONS:
		var e := key_event_of(a)
		if e != null and int(e.physical_keycode) == keycode:
			return true
	return false


static func _replace(action: StringName, old: InputEvent, new: InputEvent) -> void:
	if old != null:
		InputMap.action_erase_event(action, old)
	# one key or pad input drives one action: take it from any other
	for a in ACTIONS:
		if a != action:
			for e in InputMap.action_get_events(a):
				if _same(e, new):
					InputMap.action_erase_event(a, e)
	InputMap.action_add_event(action, new)


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


static func describe_key(e: InputEventKey) -> String:
	return "—" if e == null else OS.get_keycode_string(e.physical_keycode)


const PAD_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}


static func describe_pad(e: InputEvent) -> String:
	if e == null:
		return "—"
	if e is InputEventJoypadButton:
		return PAD_BUTTONS.get(e.button_index, "Button %d" % e.button_index)
	var m := e as InputEventJoypadMotion
	var stick := "Left stick" if m.axis <= JOY_AXIS_LEFT_Y else "Right stick" if m.axis <= JOY_AXIS_RIGHT_Y else "Trigger %d" % m.axis
	var dir := ""
	if m.axis == JOY_AXIS_LEFT_X or m.axis == JOY_AXIS_RIGHT_X:
		dir = " right" if m.axis_value > 0 else " left"
	elif m.axis == JOY_AXIS_LEFT_Y or m.axis == JOY_AXIS_RIGHT_Y:
		dir = " down" if m.axis_value > 0 else " up"
	return stick + dir

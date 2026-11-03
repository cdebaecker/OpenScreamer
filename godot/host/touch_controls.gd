## Touch controls: an on-screen gamepad for phones, tablets and the Steam Deck's screen.  On a screen
## wider than the game's 640 x 440 (a phone held sideways) they go in the space either side of the
## picture; otherwise they lie over it, half transparent.
##
##   left:  Map (R3), Journal (L3); the movement cross (walk / turn around / turn, Door in the middle,
##          the keypad's 8 2 4 6 5); Run away, Command
##   right: Menu (Start); the cursor cross (the d-pad); Attack, Defend; A (Space), B (Esc)
##
## The buttons act like the gamepad's: typed buttons (A, B, the d-pad, Start, L3, R3) are sent as
## joypad button events, so they go where the gamepad's go (the on-screen keyboard too); held
## actions (walking, attacking...) are pressed and released in the input map.  Several fingers at
## once work.  Settings, Access: shown on a touch screen once it's touched (auto), always, or never.
class_name TouchControls
extends CanvasLayer

const GAME := Vector2(640, 440)  # the game's canvas
const SIDE := 120.0  # a side column's width (the space needed beside the picture)
const KEY := 38.0  # a button's size
## the device of the joypad events sent (so the host can tell them from a real gamepad's)
const DEVICE := 63

## [id, label, x, y, w, h, side, what]: what is a JoyButton (typed, like the gamepad's) or an
## action name (held); x, y within the side column (y from the top, or from the bottom when < 0)
const BUTTONS := [
	["map", "Map", 2, 6, 56, 30, 0, JOY_BUTTON_RIGHT_STICK],
	["journal", "Journal", 62, 6, 56, 30, 0, JOY_BUTTON_LEFT_STICK],
	["walk", "▲", 41, -262, KEY, KEY, 0, &"forward"],
	["turn_left", "◀", 2, -223, KEY, KEY, 0, &"turn_left"],
	["door", "Door", 41, -223, KEY, KEY, 0, &"open_door"],
	["turn_right", "▶", 80, -223, KEY, KEY, 0, &"turn_right"],
	["about", "▼", 41, -184, KEY, KEY, 0, &"back"],
	["flee", "Run", 2, -96, 56, 40, 0, &"flee"],
	["command", "Items", 62, -96, 56, 40, 0, &"command"],
	["start", "Menu", 62, 6, 56, 30, 1, JOY_BUTTON_START],
	["up", "△", 41, -290, KEY, KEY, 1, JOY_BUTTON_DPAD_UP],
	["left", "◁", 2, -251, KEY, KEY, 1, JOY_BUTTON_DPAD_LEFT],
	["right", "▷", 80, -251, KEY, KEY, 1, JOY_BUTTON_DPAD_RIGHT],
	["down", "▽", 41, -212, KEY, KEY, 1, JOY_BUTTON_DPAD_DOWN],
	["attack", "Attack", 2, -150, 56, 40, 1, &"attack"],
	["defend", "Defend", 62, -150, 56, 40, 1, &"defend"],
	["b", "B", 6, -96, 52, 52, 1, JOY_BUTTON_B],
	["a", "A", 64, -96, 52, 52, 1, JOY_BUTTON_A],
]

signal used  # a button was touched (the host shows the controls, the on-screen keyboard...)

## "auto": on a touch screen, once it's touched (and hidden again by a key or a gamepad); "on"; "off"
var mode := "auto"
var touched := false
## beside the picture (the window is wide enough) or over it
var beside := false

var _keys := {}  # id -> Control
var _down := {}  # touch index -> id


func _init() -> void:
	layer = 5
	visible = false


func setup() -> void:
	for b: Array in BUTTONS:
		var c := _Key.new()
		c.label = b[1]
		c.size = Vector2(b[4], b[5])
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_keys[b[0]] = c
		add_child(c)


## the interface's font changed
func restyle() -> void:
	for c: Control in _keys.values():
		c.queue_redraw()


## whether they're wanted (the host makes room for them)
func wanted() -> bool:
	return mode == "on" or (mode == "auto" and touched)


## shown or not, and where (call when the window's size or the setting changes)
func update(view: Vector2) -> void:
	visible = wanted()
	if not visible:
		release_all()
	beside = view.x >= GAME.x + 2 * SIDE
	var left := (view.x - GAME.x) / 2.0 - SIDE if beside else 0.0
	var right := (view.x + GAME.x) / 2.0 if beside else view.x - SIDE
	for b: Array in BUTTONS:
		var c: _Key = _keys[b[0]]
		var y: float = b[3] if b[3] >= 0 else view.y + b[3]
		c.position = Vector2((left if b[6] == 0 else right) + b[2], y)
		c.faint = not beside
		c.queue_redraw()


## over the picture, they make way for the settings (which are touched directly); beside it, they stay
func make_way(menu_open: bool) -> void:
	var v := wanted() and (beside or not menu_open)
	if v != visible:
		visible = v
		if not v:
			release_all()


## the button under a point, "" for none
func key_at(p: Vector2) -> String:
	for id: String in _keys:
		var c: Control = _keys[id]
		if c.get_global_rect().grow(4).has_point(p):
			return id
	return ""


func _input(e: InputEvent) -> void:
	var t := e as InputEventScreenTouch
	var d := e as InputEventScreenDrag
	if t != null and t.pressed and not touched and mode == "auto":
		touched = true
		used.emit()  # the host makes room and shows them
		return  # (that touch doesn't press what appears under it)
	if not visible:
		return
	if t != null:
		if t.pressed:
			var id := key_at(t.position)
			if id != "":
				_press(t.index, id)
				get_viewport().set_input_as_handled()
		elif _down.has(t.index):
			_release(t.index)
			get_viewport().set_input_as_handled()
	elif d != null and _down.has(d.index):
		# sliding a finger from one button to the next (around the crosses)
		var id := key_at(d.position)
		if id != "" and id != _down[d.index]:
			_release(d.index)
			_press(d.index, id)
		get_viewport().set_input_as_handled()


func _press(index: int, id: String) -> void:
	_down[index] = id
	_send(id, true)
	(_keys[id] as _Key).down = true
	(_keys[id] as _Key).queue_redraw()
	used.emit()


func _release(index: int) -> void:
	var id: String = _down[index]
	_down.erase(index)
	if id in _down.values():
		return  # another finger holds it
	_send(id, false)
	(_keys[id] as _Key).down = false
	(_keys[id] as _Key).queue_redraw()


func release_all() -> void:
	for i: int in _down.keys():
		_release(i)


func _send(id: String, pressed: bool) -> void:
	var what: Variant = null
	for b: Array in BUTTONS:
		if b[0] == id:
			what = b[7]
	if what is StringName:
		if pressed:
			Input.action_press(what)
		else:
			Input.action_release(what)
	else:
		var e := InputEventJoypadButton.new()
		e.device = DEVICE
		e.button_index = what
		e.pressed = pressed
		Input.parse_input_event(e)


## a button, drawn (it takes no input itself: the layer finds the finger's button)
class _Key:
	extends Control
	var label := ""
	var down := false
	var faint := false

	func _draw() -> void:
		var a := 0.45 if faint else 0.9
		var r := Rect2(Vector2.ZERO, size)
		var bg := Color(0.85, 0.55, 0.1, a) if down else Color(0.12, 0.12, 0.17, a * 0.8)
		draw_style_box(_box(bg, Color(0.5, 0.5, 0.62, a)), r)
		var text := tr(label)
		var font := UiFont.font()
		var fs := UiFont.size(15 if text.length() <= 2 else 11)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var squeeze := minf(1.0, (size.x - 6.0) / w)  # a long label: narrower, not smaller
		draw_set_transform(Vector2((size.x - w * squeeze) / 2.0, 0), 0, Vector2(squeeze, 1))
		draw_string(font, Vector2(0, size.y / 2.0 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(1, 1, 1, minf(1.0, a + 0.2)))
		draw_set_transform(Vector2.ZERO)

	static func _box(bg: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(1)
		s.set_corner_radius_all(8)
		return s

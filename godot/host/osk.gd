## On-screen keyboard for typing names and words to ask people about, with a gamepad (or the mouse
## / a touch screen).  It types into the game's key queue like the keyboard does: characters as
## their code, a space as → (as the game's line input wants it), Delete, and Space to finish.
##
## Gamepad: d-pad / left stick move, A types the key, B deletes, X types a space, LB / RB or Y
## change the page (ABC, abc, katakana), Start finishes the entry (OK).
class_name Osk
extends PanelContainer

const COLS := 12
const PAGES := [
	["ABCDEFGHIJKL", "MNOPQRSTUVWX", "YZ0123456789", ".,-!?'&/:()+"],
	["abcdefghijkl", "mnopqrstuvwx", "yz0123456789", ".,-!?'&/:()+"],
	["ｱｶｻﾀﾅﾊﾏﾔﾗﾜﾞｧ", "ｲｷｼﾁﾆﾋﾐｬﾘｦﾟｨ", "ｳｸｽﾂﾇﾌﾑﾕﾙﾝｰｩ", "ｴｹｾﾃﾈﾍﾒｭﾚｯ･ｪ", "ｵｺｿﾄﾉﾎﾓﾖﾛｮ｡ｫ"],
]
const PAGE_NAMES := ["ABC", "abc", "ｶﾅ"]
## the bottom row
const SPECIAL := ["Space", "Delete", "Page", "OK"]

var keys: Keys
var page := 0
## the katakana page offered (the game text is in Japanese)
var kana_page := true:
	set(v):
		kana_page = v
		if page >= _pages():
			page = 0
		if _grid != null:
			_build()
## cursor: row (the last row is SPECIAL), column
var row := 0
var col := 0

var _grid: GridContainer
var _bottom: HBoxContainer
var _title: Label
var _stick := Vector2i.ZERO
var _hilite: StyleBoxFlat


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.09)
	bg.border_color = Color(0.35, 0.35, 0.45)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(8)
	add_theme_stylebox_override("panel", bg)
	_hilite = StyleBoxFlat.new()
	_hilite.bg_color = Color(0.85, 0.55, 0.1)
	_hilite.set_corner_radius_all(3)
	var box := VBoxContainer.new()
	add_child(box)
	_title = Label.new()
	UiFont.set_size(_title, &"font_size", 11)
	_title.modulate = Color(0.7, 0.7, 0.78)
	box.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	box.add_child(_grid)
	_bottom = HBoxContainer.new()
	_bottom.add_theme_constant_override("separation", 3)
	box.add_child(_bottom)
	for i in SPECIAL.size():
		var b := _button(SPECIAL[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_special.bind(i))
		_bottom.add_child(b)
	_build()


func _button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 24)
	UiFont.set_size(b, &"font_size", 15)
	return b


func _rows() -> Array:
	return PAGES[page]


## the character of a key, "" for none
func char_at(r: int, c: int) -> String:
	var rows := _rows()
	if r >= rows.size():
		return ""
	var s: String = rows[r]
	return s[c] if c < s.length() else ""


func _build() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var rows := _rows()
	for r in rows.size():
		for c in COLS:
			var ch := char_at(r, c)
			var b := _button(ch)
			b.disabled = ch == ""
			b.pressed.connect(_type_at.bind(r, c))
			_grid.add_child(b)
	(_bottom.get_child(2) as Button).text = tr("Page: %s") % PAGE_NAMES[(page + 1) % _pages()]
	_title.text = tr("On-screen keyboard  %s   —  A type · B delete · X space · LB/RB page · Start OK") % PAGE_NAMES[page]
	row = mini(row, rows.size())
	_show_cursor()


func set_page(p: int) -> void:
	page = posmod(p, _pages())
	_build()


func _pages() -> int:
	return PAGES.size() if kana_page else 2


func _show_cursor() -> void:
	var rows := _rows().size()
	for i in _grid.get_child_count():
		var b := _grid.get_child(i) as Button
		if i / COLS == row and i % COLS == col:
			b.add_theme_stylebox_override("normal", _hilite)
		else:
			b.remove_theme_stylebox_override("normal")
	var bc := _bottom_index()
	for i in _bottom.get_child_count():
		var b := _bottom.get_child(i) as Button
		if row == rows and i == bc:
			b.add_theme_stylebox_override("normal", _hilite)
		else:
			b.remove_theme_stylebox_override("normal")


func _bottom_index() -> int:
	return mini(col * SPECIAL.size() / COLS, SPECIAL.size() - 1)


func move(dx: int, dy: int) -> void:
	var rows := _rows().size()
	if dy != 0:
		row = posmod(row + dy, rows + 1)
	if dx != 0:
		if row == rows:  # the bottom row: jump between its buttons
			var i := posmod(_bottom_index() + dx, SPECIAL.size())
			col = (i * COLS + COLS / 2) / SPECIAL.size()
		else:
			col = posmod(col + dx, COLS)
	_show_cursor()


## A: the key under the cursor
func press() -> void:
	if row == _rows().size():
		_special(_bottom_index())
	else:
		_type_at(row, col)


func _type_at(r: int, c: int) -> void:
	var ch := char_at(r, c)
	if ch != "":
		keys.push(ch.unicode_at(0))


func _special(i: int) -> void:
	match i:
		0:
			keys.push(Keys.K_RIGHT)  # the game's line input types a space for →
		1:
			keys.push(Keys.K_DEL)
		2:
			set_page(page + 1)
		3:
			keys.push(Keys.K_SPACE)


## gamepad events while the keyboard is shown; true when used
func joy_event(e: InputEvent) -> bool:
	var b := e as InputEventJoypadButton
	if b != null:
		if not b.pressed:
			return true
		match b.button_index:
			JOY_BUTTON_DPAD_UP:
				move(0, -1)
			JOY_BUTTON_DPAD_DOWN:
				move(0, 1)
			JOY_BUTTON_DPAD_LEFT:
				move(-1, 0)
			JOY_BUTTON_DPAD_RIGHT:
				move(1, 0)
			JOY_BUTTON_A:
				press()
			JOY_BUTTON_B:
				_special(1)
			JOY_BUTTON_X:
				_special(0)
			JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER:
				set_page(page + 1)
			JOY_BUTTON_LEFT_SHOULDER:
				set_page(page - 1)
			JOY_BUTTON_START:
				_special(3)
			_:
				return false
		return true
	var m := e as InputEventJoypadMotion
	if m != null and (m.axis == JOY_AXIS_LEFT_X or m.axis == JOY_AXIS_LEFT_Y):
		# the stick moves one key each time it's pushed past half way
		var v := 0 if absf(m.axis_value) < 0.5 else (1 if m.axis_value > 0 else -1)
		var i := 0 if m.axis == JOY_AXIS_LEFT_X else 1
		if v != _stick[i] and v != 0:
			move(v if i == 0 else 0, v if i == 1 else 0)
		_stick[i] = v
		return true
	return false

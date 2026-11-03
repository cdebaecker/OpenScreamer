## Reading keys, the command menu, cursor choices, prompts and line input.
class_name Ui
extends Mod

## virtual time spent by one empty key poll in a waiting loop
const POLL_US := 200

# command menu
var menu_sel := 0
var menu_count := 0
var menu_hilite := 0
var last_key := 0
## the keypad direction last read
var numpad_dir := 0
## the last line typed with line_input()
var input := ""
## the original's input buffer behind `input`: 16 bytes, written in place, so bytes past
## the end of a short line are left over from earlier ones (they end up in saved names)
var input_buf := PackedByteArray()
## true while line_input() waits for typing (the host shows its on-screen keyboard; not game state)
var typing := false
## where the game is waiting for the player at rest (&"town": the town's command menu, &"bias":
## standing in BIAS), &"" elsewhere: the host can save the game there (not game state)
var rest := &""
## the delay loop calibration the original measures at start (8 MHz); see _debug_wait_time()
var cpu_speed := 8


## the next key: a character, or Keys.K_UP..K_LEFT / K_DEL; 0 = nothing
func read_key() -> int:
	return keys.read()


## wait for any key
func wait_key() -> int:
	while true:
		var k := read_key()
		if k:
			return k
		await sys.advance(POLL_US)
	return 0


## drain the key queue (`mov ah,5 / int 18h / cmp bh,0 / jne`)
func drain_keys() -> void:
	while keys.take() >= 0:
		pass


## keypad direction held: forward 1, turn right 2, turn round 3, turn left 4, door 5
func numpad() -> int:
	var ax := keys.pad_bits()
	var al := 0
	if ax == 0x0800:
		al = 1
	elif ax == 0x0001:
		al = 2
	elif ax == 0x0008:
		al = 3
	elif ax == 0x4000:
		al = 4
	elif ax == 0x8000:
		al = 5
	numpad_dir = al
	return al


## pause `count` x 9 units unless a different keypad direction is pressed
func hold_pause(count: int) -> void:
	var first := numpad_dir
	for i in count:
		await sys.delay(9)
		var k := numpad()
		if k != 0 and k != first:
			break


# ------------------------------------------------------------------ the command menu

## text cell of the current menu item (two rows per item from row 5, column 5)
func _menu_cell() -> Vector2i:
	return Vector2i(5, 5 + (menu_sel - 1) * 2)


## the red arrow (one per `id`) at a board position
func draw_arrow(pos: Vector2i, id := &"menu_arrow") -> void:
	screen.sprite(id, art.piece("ui/arrow"), pos, false)


func erase_arrow(id := &"menu_arrow") -> void:
	screen.hide_sprite(id)


## the selected menu item in red (hilite) or back to white
func _paint_selection(hilite: bool) -> void:
	menu_hilite = 0xff if hilite else 0
	var c := _menu_cell()
	screen.text.recolour(c.x + 1, c.y, 11, Screen.RED if hilite else Screen.WHITE)


## one poll of the command menu.  Returns the chosen item (1-based) when SPACE is
## pressed, or 0.  Cursor up/down move the arrow.  ESC picks the last item in town.
func menu_poll() -> int:
	await _debug_wait_time()
	draw_arrow(_menu_cell() * 8)
	if menu_hilite != 0:
		_paint_selection(false)
	while true:
		var k := read_key()
		if not k:
			return 0
		last_key = k
		if k == Keys.K_SPACE:
			_paint_selection(true)
			erase_arrow()
			return menu_sel
		if k == Keys.K_DOWN or k == Keys.K_UP:
			if k == Keys.K_DOWN:
				menu_sel = (menu_sel + 1) & 0xff
				if menu_count < menu_sel:
					menu_sel = 1
			else:
				menu_sel = (menu_sel - 1) & 0xff
				if menu_sel == 0:
					menu_sel = menu_count
			draw_arrow(_menu_cell() * 8)
			return 0
		if k == Keys.K_ESC:
			return menu_count if st.game_mode == 2 else 0
	return 0


## loop on menu_poll until something is chosen
func menu_choose() -> int:
	while true:
		var r: int = await menu_poll()
		if r:
			return r
		await sys.advance(POLL_US)
	return 0


## set up a command menu: count items, select the first
func menu_reset(count: int) -> void:
	menu_count = count
	menu_sel = 1


# ------------------------------------------------------------------ cursor choice

## Move an arrow between fixed positions with the cursor keys; returns the item chosen with
## SPACE (1-based).  nav: 4 entries per item, the item reached with up, right, down, left
## (0 = none); positions: the arrow's board position for each item.
func choose(nav: Array, positions: Array) -> int:
	var item := 1
	draw_arrow(positions[0], &"choice_arrow")
	while true:
		var dir := -1
		while true:
			var k: int = await wait_key()
			if k == Keys.K_UP:
				dir = 0
			elif k == Keys.K_RIGHT:
				dir = 1
			elif k == Keys.K_DOWN:
				dir = 2
			elif k == Keys.K_LEFT:
				dir = 3
			elif k == Keys.K_SPACE:
				return item  # the arrow stays until its window is cleared
			else:
				continue
			break
		var next: int = nav[(item - 1) * 4 + dir]
		if next == 0:
			continue
		item = next
		draw_arrow(positions[item - 1], &"choice_arrow")
	return 0


## positions table (VRAM offsets in the original) -> board positions
static func positions(offsets: Array) -> Array:
	return offsets.map(func(o: int) -> Vector2i: return Screen.px(o))


## " Yes   No" in the message window; true for Yes
func yes_no() -> bool:
	txt.at(0x18, 0x17, txt.margin)
	txt.puts(data.msg(&"ui.01"))
	var r: int = await choose(data.table("yes_no_nav"), positions(data.table("yes_no_pos")))
	screen.clear_window(Screen.MESSAGE)
	return r == 1


## "Push Space Key" and wait for SPACE
func wait_space() -> void:
	txt.col = 0x1f
	txt.row = 0x17
	txt.puts(data.msg(&"ui.02"))
	while (await wait_key()) != Keys.K_SPACE:
		pass
	screen.clear_window(Screen.MESSAGE)


# ------------------------------------------------------------------ line input

## Read up to 15 characters into `input`; SPACE ends, right-cursor types a space.
func line_input() -> void:
	typing = true
	txt.kana_mode = 0
	input = ""
	if input_buf.size() != 0x10:
		input_buf.resize(0x10)
	var draw_cursor := true
	while true:
		if draw_cursor and input.length() < 0x0f:
			txt.put_char(0x5f)
			txt.col -= 1
		draw_cursor = true
		var k: int = await wait_key()
		var typed_space := k == Keys.K_RIGHT
		if k == Keys.K_LEFT or k == Keys.K_DEL:
			if input.is_empty():
				draw_cursor = false
				continue
			input = input.substr(0, input.length() - 1)  # the byte stays in input_buf
			txt.put_char(0x20)
			txt.col -= 1
			txt.put_char(0x08)
			continue
		if k == Keys.K_SPACE:
			if input.length() < 0x0f:
				txt.put_char(0x20)
			input_buf[input.length()] = 0
			typing = false
			return
		if k < 0x20 and not typed_space:
			draw_cursor = false
			continue
		if input.length() >= 0x0f:
			draw_cursor = false
			continue
		var ch := " " if typed_space else String.chr(k)
		input += ch
		input_buf[input.length() - 1] = GameText.encode(ch)[0]
		txt.put_char(GameText.encode(ch)[0])


## the decimal number in `s` (spaces around it allowed); -1 if it isn't one
static func parse_number(s: String) -> int:
	s = s.lstrip(" ")
	var v := 0
	for i in s.length():
		var c := s.unicode_at(i)
		if c == 0x20:
			return v if s.substr(i).strip_edges() == "" else -1
		var d := c - 0x30
		if d < 0 or d >= 10:
			return -1
		v = v * 10 + d
		if v > 0xffff:
			return -1
	return v


# ------------------------------------------------------------------ debug: waiting time

## HELP+T: the original's hidden option to re-calibrate its delay loop
func _debug_wait_time() -> void:
	if keys.group(7) != 0x80 or keys.group(2) != 0x10:
		return
	screen.clear_window(Screen.MESSAGE)
	txt.at(0x13, 0x11)
	txt.puts(data.msg(&"ui.03"))
	var v: int = await number_spin(cpu_speed & 0xff, 0x63)
	if v:
		cpu_speed = v  # shown only: the port's clock doesn't depend on it
	screen.clear_window(Screen.MESSAGE)


## two-digit number picker driven by the held cursor keys
## (right +1, up +10, left -1, down -10, RETURN accepts, ESC cancels -> 0).
func number_spin(value: int, max_value: int) -> int:
	while keys.group(3) == 0x10:  # wait for RETURN to be released
		await sys.advance(POLL_US)
	_show_spin(value)
	await sys.delay(0xbb8)
	while true:
		read_key()
		var g7 := keys.group(7)
		if g7 == 0x04 or g7 == 0x08 or g7 == 0x10 or g7 == 0x20:
			if g7 == 0x10:
				value = mini(value + 1, max_value)
			elif g7 == 0x04:
				value = mini(value + 10, max_value)
			elif g7 == 0x08:
				value = 1 if value - 1 <= 0 else value - 1
			else:
				value = 1 if value <= 10 else value - 10
			_show_spin(value)
			await sys.delay(0xbb8)
			continue
		if keys.group(0) == 0x01:
			return 0
		if keys.group(3) == 0x10:
			return value
		await sys.advance(POLL_US)
	return 0


func _show_spin(v: int) -> void:
	var c := txt.col
	var r := txt.row
	txt.put_char(0x30 + v / 10)
	txt.put_char(0x30 + v % 10)
	txt.col = c
	txt.row = r

## The player's input as the game sees it: a queue of typed keys (menus, text) and the actions
## held down (walking, fighting), from the project's input map.
##
## The original read both through the PC-98 BIOS: a key buffer, and a key matrix polled in
## groups of eight keys.  `group(n)` rebuilds a group's bits from the held actions so routines can
## keep their original key tests; each call counts as one matrix read for scripted runs.
class_name Keys
extends RefCounted

# queue codes: characters are their Unicode code point (typed katakana as half-width katakana)
const K_UP := 1
const K_RIGHT := 2
const K_DOWN := 3
const K_LEFT := 4
const K_DEL := 8  # Delete, and Backspace (character 8)
const K_ESC := 0x1b
const K_SPACE := 0x20  # Space, Enter, gamepad A

## action -> [matrix group, bit] of the PC-98 key it stands for
const MATRIX := {
	&"cancel": [0, 0x01],  # ESC
	&"debug_w": [2, 0x02],  # W (also walks: "forward")
	&"debug_t": [2, 0x10],  # T
	&"debug_i": [2, 0x80],  # I
	&"debug_bs": [1, 0x40],  # BS
	&"debug_tab": [1, 0x80],  # TAB
	&"debug_f1": [0x0c, 0x04],
	&"debug_f2": [0x0c, 0x08],
	&"debug_f3": [0x0c, 0x10],
	&"debug_f4": [0x0c, 0x20],
	&"debug_f5": [0x0c, 0x40],
	&"debug_shift": [0x0e, 0x01],
	&"debug_ctrl": [0x0e, 0x10],
	&"confirm": [3, 0x10],  # RETURN
	&"attack": [5, 0x02],  # Z
	&"defend": [5, 0x04],  # X
	&"command": [5, 0x08],  # C
	&"cursor_up": [7, 0x04],
	&"cursor_left": [7, 0x08],
	&"cursor_right": [7, 0x10],
	&"cursor_down": [7, 0x20],
	&"debug_help": [7, 0x80],  # HELP
	&"forward": [8, 0x08],  # keypad 8
	&"open_door": [8, 0x80],  # keypad 5
	&"turn_left": [8, 0x40],  # keypad 4
	&"turn_right": [9, 0x01],  # keypad 6
	&"back": [9, 0x08],  # keypad 2
	&"flee": [9, 0x40],  # keypad 0
}

var _queue: Array[int] = []
## held actions for scripted runs (merged with the real input)
var scripted := {}
## called when the game polls an empty key queue (used by scripted runs)
var on_empty_poll := Callable()
## called on every matrix read (used by scripted runs)
var on_matrix_read := Callable()


## int 18h AH=05h: the next key, 0 if there is none (a key with no meaning also reads as 0)
func read() -> int:
	return maxi(take(), 0)


## the next key, -1 if there is none
func take() -> int:
	if _queue.is_empty() and on_empty_poll.is_valid():
		on_empty_poll.call()
	if _queue.is_empty():
		return -1
	return _queue.pop_front()


## int 18h AH=01h: the next key without taking it, -1 if there is none
func peek() -> int:
	if _queue.is_empty() and on_empty_poll.is_valid():
		on_empty_poll.call()
	return -1 if _queue.is_empty() else _queue[0]


func push(code: int) -> void:
	if _queue.size() < 16:
		_queue.append(code)


func flush() -> void:
	_queue.clear()


func pending() -> int:
	return _queue.size()


func held(action: StringName) -> bool:
	if scripted.has(action):
		return true
	return InputMap.has_action(action) and Input.is_action_pressed(action)


## int 18h AH=04h: the bits of matrix group `n` (see MATRIX)
func group(n: int) -> int:
	if on_matrix_read.is_valid():
		on_matrix_read.call()
	var bits := 0
	for action: StringName in MATRIX:
		var g: Array = MATRIX[action]
		if g[0] == n and held(action):
			bits |= g[1]
	return bits


## groups 8 and 9 (the keypad) as one word, as the original tests them: two matrix reads
func pad_bits() -> int:
	var hi := group(8)
	return (hi << 8) | group(9)

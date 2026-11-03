## Small helpers for patterns repeated all over the original code.
class_name Common
extends Mod


## a beep, remembered as the last one
func beep(on: int, off: int, count: int) -> void:
	await sys.beep(on, off, count)


## the "someone talks" blip used before every NPC line
func blip() -> void:
	await sys.beep(2, 4, 0xc8)


## a delay, remembered as the last one
func wait(n: int) -> void:
	await sys.delay(n)


## delay that also eats one key per unit (used in combat)
func wait_eat_keys(n: int) -> void:
	for i in n:
		keys.take()
		await sys.delay(1)


## beeper loop built on
func beep_eat_keys(on: int, off: int, count: int) -> void:
	sys.beep_on = on
	sys.beep_off = off
	sys.beep_count = count
	sys.sound(on * Sys.DELAY_UNIT_US, off * Sys.DELAY_UNIT_US, count)
	for i in count:
		await wait_eat_keys(on)
		await wait_eat_keys(off)


## kana mode on, cursor at (col, row) with the same left margin, print
func say(col: int, row: int, s: String) -> void:
	txt.kana_mode = 0xff
	txt.at(col, row, col)
	txt.puts(s)


## kana mode on, cursor at (col, row) leaving the margin alone, print
func say_at(col: int, row: int, s: String) -> void:
	txt.kana_mode = 0xff
	txt.col = col
	txt.row = row
	txt.puts(s)


## clear the message window and print a message at (12h, 11h)
func message(s: String) -> void:
	screen.clear_window(Screen.MESSAGE)
	say(0x12, 0x11, s)


## clear the message window, blip, and print an NPC line at (13h, 11h)
func npc(s: String) -> void:
	screen.clear_window(Screen.MESSAGE)
	txt.kana_mode = 0xff
	txt.at(0x13, 0x11, 0x13)
	await blip()
	txt.puts(s)


# ------------------------------------------------------------------ pictures

## where show_monster() and show_picture() draw (the original's and, VRAM offsets)
var monster_dest := 0
var picture_dest := 0


## monster or portrait Gnn (160x100) at `monster_dest`; for numbers below
## 40 the monster's record also becomes the one being fought (even for portraits, like the original)
func show_monster(n: int) -> void:
	if n < 40:
		st.mon = Monster.new(data.monster_record(n))
	screen.draw(art.monster(n), Screen.px(monster_dest))


## scene picture Pnn (320x100) at `picture_dest`
func show_picture(n: int) -> void:
	screen.draw(art.picture(n), Screen.px(picture_dest))


func show_picture_at(n: int, dest: int) -> void:
	picture_dest = dest
	show_picture(n)


## palette register 0xAE (colours 0 and 4), remembered in st.color4
func set_color4(al: int) -> void:
	st.color4 = al & 0xff
	screen.out_palette(0xae, al & 0x0f)


## load the current floor's map
func load_floor_file() -> void:
	st.map = FloorMap.new(data.floor_bytes(st.floor))

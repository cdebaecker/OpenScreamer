## The player character: the status panel, stat changes, the roster of registered screamers.
class_name Chara
extends Mod

const SAVE_PATH := "user://CHAR"

## the 8 roster slots (the CHAR file); a slot whose name starts with byte FFh is free
var roster: Array[Character] = []
## where the roster is kept: user://CHAR, in the original's format (scripted runs replace these)
var save_load := _file_load
var save_store := _file_save

var _picture_window: Array = []


# ------------------------------------------------------------------ items

## the item table entry for an item number (bit 7 ignored)
func item_name(item: int) -> String:
	return data.item(item)["name"]


func item_price(item: int) -> int:
	return data.item(item)["price"]


func item_value(item: int) -> int:
	return data.item(item)["value"]


func item_kind(item: int) -> int:
	return data.item(item)["kind"]


## index of item `id` in the inventory (bit 7 ignored), -1 if not carried
func has_item(id: int) -> int:
	return st.chr.inv_find(id)


# ------------------------------------------------------------------ status

## HP / AC / HC / BP on the right-hand panel
func status_panel() -> void:
	txt.num_format = 2
	for r in [[0x0a, st.chr.hp], [0x0c, st.chr.ac], [0x0e, st.chr.hc], [0x10, st.chr.bp]]:
		txt.col = 0x44
		txt.row = r[0]
		txt.print_number(0, r[1])


## recompute armour class from the equipped protectors
func recalc_ac() -> void:
	var c := st.chr
	c.ac = 0
	for i in c.inv_count():
		var it := c.inv(i)
		if not (it & Character.EQUIPPED):
			continue
		var kind := item_kind(it)
		if kind >= 3 and kind < 7:
			c.ac += item_value(it)
	status_panel()


## add dx to a stat (0 HP, 1 AGL, 2 POW, 3 TEC, 4 IQ), kept within 1..its maximum.
## HP reaching zero ends the game: this jumps to game_over, so callers must check sys.unwinding.
func adjust_stat(which: int, dx: int) -> void:
	if which > 4:
		return
	var c := st.chr
	var stat: StringName = Character.STATS[which]
	if which == 0:
		var hp := (c.hp + dx) & 0xffff
		if hp == 0 or hp & 0x8000:
			c.hp = 0
			status_panel()
			sys.jump(&"game_over")
			return
	var v := (int(c.get(stat)) + dx) & 0xffff
	if v == 0 or v & 0x8000:
		v = 1
	var max_v: int = c.get(StringName(String(stat) + "_max"))
	if max_v < v:
		v = max_v
	c.set(stat, v)
	status_panel()


## drugs that pushed a stat to 250 wear off back to the maximum
func drugs_wear_off() -> void:
	var c := st.chr
	for stat in [&"agl", &"pow", &"tec", &"iq"]:
		if c.get(stat) == 0xfa:
			c.set(stat, c.get(StringName(String(stat) + "_max")))


# ------------------------------------------------------------------ the abilities

## keep and put back what the picture window shows
func save_picture_window() -> void:
	_picture_window = screen.snapshot(_picture_rect())


func restore_picture_window() -> void:
	screen.restore(_picture_window)


func _picture_rect() -> Rect2i:
	return Rect2i(Screen.px(0x792), Vector2i(0x28 * 8, 0x68))


func show_abilities() -> void:
	var c := st.chr
	screen.clear_window(Screen.MESSAGE)
	txt.at(0x13, 0x11)
	txt.puts(data.msg(&"char.01"))
	save_picture_window()
	screen.clear_window(Screen.VIEW)
	txt.kana_mode = 0
	txt.col = 0x13
	txt.row = 7
	txt.print_raw(c.name)
	txt.at(0x14, 8)
	for e in [[c.pow, data.msg(&"char.02")], [c.iq, data.msg(&"char.03")], [c.tec, data.msg(&"char.04")], [c.agl, data.msg(&"char.05")],
			[c.luck, data.msg(&"char.06")]]:
		txt.set_number(e[0], 1)
		txt.puts(e[1])
	txt.at(0x26, 8)
	for e in [[c.credits, data.msg(&"char.07")], [c.bp, data.msg(&"char.08")], [c.hc, data.msg(&"char.09")], [c.hp, data.msg(&"char.10")],
			[c.ac, data.msg(&"char.11")]]:
		txt.set_number(e[0], 1)
		txt.puts(e[1])
	txt.puts(data.msg(&"char.12"))
	txt.puts(data.msg(&"char.13") if c.poison != 0 else data.msg(&"char.14"))
	await ui.wait_space()
	restore_picture_window()


# ------------------------------------------------------------------ roster file

## read the roster (8 slots of 80h bytes)
func load_roster() -> void:
	var d: PackedByteArray = save_load.call()
	if d.size() < 8 * Character.SIZE:
		d = GameData.empty_roster()  # (no one registered yet)
	roster.clear()
	for i in 8:
		roster.append(Character.new(d.slice(i * Character.SIZE, (i + 1) * Character.SIZE)))


## the registered slots: they come first, up to the first free one
func roster_count() -> int:
	var n := 0
	while n < roster.size() and roster[n].record[0] != 0xff:
		n += 1
	return n


## write the roster back
func save_roster() -> void:
	var d := PackedByteArray()
	for c in roster:
		d.append_array(c.record)
	save_store.call(d)


## the slot holding the current character's name, -1 if none
func find_in_roster() -> int:
	var name := st.chr.record.slice(0, 0x10)
	for i in roster_count():
		var other := roster[i].record
		var j := 0
		while true:
			if other[j] != name[j]:
				break
			if other[j] == 0:
				return i
			j += 1
			if j >= 0x10:
				break
	return -1


func _file_load() -> PackedByteArray:
	if not FileAccess.file_exists(SAVE_PATH):
		return PackedByteArray()
	# (without the disk's own screamers, which earlier versions copied into the player's roster)
	return data.without_disk_screamers(FileAccess.get_file_as_bytes(SAVE_PATH))


func _file_save(d: PackedByteArray) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:  # storage unavailable: the roster just isn't kept
		f.store_buffer(d)

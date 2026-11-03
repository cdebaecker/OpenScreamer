## Inventory: the item list widget and the item commands (look / equip / unequip / drop / use /
## pick up / examine).
class_name Items
extends Mod

## break_item() target for the item lying on the floor instead of one in the inventory
const FLOOR_ITEM := -1

# item list
## the list row under the arrow; after a pick, the item chosen
var list_sel := 0
var saved_color := 0
## shops set this to show prices in the list
var show_prices := 0
var list_filter := 0
## the noise machine failed to read the monster ()
var noise_failed := 0

## what the list shows: item numbers; for the inventory, list index = inventory index
var _list: Array[int] = []


# ------------------------------------------------------------------ item list

## the list to show: the inventory (filter 0) or the items a shop sells
func _build_list(filter: int) -> void:
	list_filter = filter
	_list.clear()
	if filter == 0:
		for i in st.chr.inv_count():
			_list.append(st.chr.inv(i))
		return
	for e in data.items:
		if int(e["shops"]) & filter:
			_list.append(int(e["id"]))


func _arrow_pos() -> Vector2i:
	return Screen.px((list_sel * 0x280 + 0xa17) & 0xffff)


## one line of the list: name, (price), "Equipped"
func _draw_list_line(p: int) -> void:
	txt.row = list_sel + 4
	txt.col = 0x19
	var item := _list[p]
	txt.kana_mode = 0
	txt.puts(chara.item_name(item))
	txt.put_char(0x20)
	txt.put_char(0x20)
	if show_prices != 0:
		var price := chara.item_price(item)
		if list_filter == 0:
			price >>= 1
		txt.print_number(0, price)
	txt.col = 0x31
	txt.puts(data.table("price_tag_sold") if item & Character.EQUIPPED else data.table("price_tag_new"))


## let the player pick an item; filter 0 lists the inventory, otherwise a shop mask.
## Returns {"item": item number (0 = cancelled), "index": its place in the list (for the
## inventory: its inventory index)}.
func pick_item(filter: int) -> Dictionary:
	_build_list(filter)
	var p := 0
	if _list.is_empty():
		return _end_pick(0, -1)
	txt.colour = 4
	chara.save_picture_window()
	screen.clear_window(Screen.VIEW)
	saved_color = st.color4
	common.set_color4(7)
	txt.num_format = 1
	list_sel = 0
	for n in mini(0x0b, _list.size()):
		_draw_list_line(n)
		list_sel += 1
	list_sel = 0
	ui.draw_arrow(_arrow_pos(), &"list_arrow")
	while true:
		var k: int = await ui.wait_key()
		if k == Keys.K_UP:
			p = _list_up(p)
		elif k == Keys.K_DOWN:
			p = _list_down(p)
		elif k == Keys.K_SPACE:
			ui.erase_arrow(&"list_arrow")
			return _end_pick(_list[p], p)
		elif k == Keys.K_ESC:
			return _end_pick(0, p)
	return {}


## common exit (also taken when the list is empty)
func _end_pick(item: int, index: int) -> Dictionary:
	txt.colour = 7
	common.set_color4(saved_color)
	screen.clear_window(Screen.MESSAGE)
	screen.clear_window(Screen.VIEW)
	if not chara._picture_window.is_empty():
		chara.restore_picture_window()
	list_sel = item & 0xff
	return {"item": item, "index": index if item else -1}


func _list_down(p: int) -> int:
	if p + 1 >= _list.size():
		return p
	p += 1
	if list_sel < 0x0a:
		list_sel += 1
		ui.draw_arrow(_arrow_pos(), &"list_arrow")
		return p
	_scroll_list(-1)
	_draw_list_line(p)
	return p


func _list_up(p: int) -> int:
	if p == 0:
		return p
	p -= 1
	if list_sel != 0:
		list_sel -= 1
		ui.draw_arrow(_arrow_pos(), &"list_arrow")
		return p
	_scroll_list(1)
	_draw_list_line(p)
	return p


## the list's ten lower (dir -1) or upper (dir 1) text rows move one row; the row they leave
## keeps its text (the original copies plane G only, rows 4..14 from column 18)
func _scroll_list(dir: int) -> void:
	var rows := range(4, 14) if dir < 0 else range(14, 4, -1)
	for row in rows:
		for col in range(18, 58):
			var src_row: int = row - dir
			var g := screen.text.glyph_at(col, src_row)
			if g < 0:
				screen.text.clear(Rect2i(col * 8, row * 8, 8, 8))
			else:
				screen.text.put(col, row, g, screen.text._colour[src_row * TextLayer.COLS + col])


# ------------------------------------------------------------------ weapon bookkeeping

## remember the equipped weapon's kind and strength for combat
func _note_weapon(item: int) -> void:
	if chara.item_kind(item) >= 3:
		return
	combat.weapon_kind = chara.item_kind(item)
	combat.weapon_pow = chara.item_value(item)


## forget the weapon when it is taken off
func _forget_weapon(item: int) -> void:
	if chara.item_kind(item) >= 3:
		return
	combat.weapon_kind = 0
	combat.weapon_pow = 0


## an item breaks (inventory index, or FLOOR_ITEM for the one on the floor)
func break_item(index: int) -> void:
	var item := st.floor_item if index == FLOOR_ITEM else st.chr.inv(index)
	var kind := chara.item_kind(item)
	var ah := 0x55
	if kind >= 3:
		ah += 1
	if kind >= 7:
		ah += 1
	if index == FLOOR_ITEM:
		st.floor_item = ah
	else:
		st.chr.set_inv(index, ah)
	chara.recalc_ac()


# ------------------------------------------------------------------ commands

func _msg12(s: String) -> void:
	common.say(0x12, 0x11, s)


## look at the items
func look_items() -> void:
	screen.clear_window(Screen.MESSAGE)
	if st.chr.inv(0) == 0:
		_msg12(data.msg(&"item.01"))
		await ui.wait_space()
		return
	if st.game_mode == 2:
		show_prices = 0
	txt.col = 0x1f
	txt.row = 0x17
	txt.puts(data.msg(&"item.02"))
	await pick_item(0)


## drop
func drop_item() -> void:
	screen.clear_window(Screen.MESSAGE)
	if st.chr.inv(0) == 0:
		_msg12(data.msg(&"item.03"))
		await ui.wait_space()
		return
	_msg12(data.msg(&"item.04"))
	var p: Dictionary = await pick_item(0)
	if not p.item:
		return
	var i: int = p.index
	if p.item & Character.EQUIPPED:
		_forget_weapon(st.chr.inv(i))
	if (st.chr.inv(i) & 0x7f) == 0x52:
		st.chr.bp = 0
		st.chr.bp_total = 0
		chara.status_panel()
	st.chr.inv_remove(i)
	chara.recalc_ac()
	chara.status_panel()
	screen.clear_window(Screen.MESSAGE)
	_msg12(data.msg(&"item.05"))
	await common.wait(0x2710)
	screen.clear_window(Screen.MESSAGE)


## slot class used to refuse two items of the same sort: kinds 0/1 -> 1/2, 2 stays 2
func _slot_class(item: int) -> int:
	var k := chara.item_kind(item)
	return k + 1 if k < 2 else k


func _say13(s: String, pause: bool) -> void:
	screen.clear_window(Screen.MESSAGE)
	txt.at(0x13, 0x11, 0x13)
	txt.puts(s)
	if pause:
		await ui.wait_space()


## equip
func equip_item() -> void:
	screen.clear_window(Screen.MESSAGE)
	if st.chr.inv(0) == 0:
		screen.clear_window(Screen.MESSAGE)
		txt.at(0x13, 0x11, 0x13)
		txt.puts(data.msg(&"item.06"))
		await ui.wait_space()
		return
	txt.at(0x13, 0x11, 0x13)
	txt.puts(data.msg(&"item.07"))
	var p: Dictionary = await pick_item(0)
	if not p.item:
		return
	var i: int = p.index
	var ah := _slot_class(list_sel)
	if ah >= 7 and (st.chr.inv(i) & 0x7f) != 0x52:
		await _say13(data.msg(&"item.08"), true)
		return
	if st.chr.inv(i) & Character.EQUIPPED:
		await _say13(data.msg(&"item.09"), true)
		return
	for j in st.chr.inv_count():
		var it := st.chr.inv(j)
		if not (it & Character.EQUIPPED):
			continue
		if _slot_class(it) == ah:
			await _say13(data.msg(&"item.10"), true)
			return
	st.chr.set_inv(i, st.chr.inv(i) | Character.EQUIPPED)
	_note_weapon(st.chr.inv(i))
	chara.recalc_ac()
	await _say13(data.msg(&"item.11"), false)
	await common.wait(0x2710)
	screen.clear_window(Screen.MESSAGE)


## unequip
func unequip_item() -> void:
	screen.clear_window(Screen.MESSAGE)
	if st.chr.inv(0) == 0:
		_msg12(data.msg(&"item.12"))
		await ui.wait_space()
		return
	_msg12(data.msg(&"item.13"))
	var p: Dictionary = await pick_item(0)
	if not p.item:
		return
	var i: int = p.index
	if not (st.chr.inv(i) & Character.EQUIPPED):
		_msg12(data.msg(&"item.14"))
		await ui.wait_space()
		screen.clear_window(Screen.MESSAGE)
		return
	st.chr.set_inv(i, st.chr.inv(i) & 0x7f)
	_forget_weapon(st.chr.inv(i))
	chara.recalc_ac()
	chara.status_panel()
	screen.clear_window(Screen.MESSAGE)
	_msg12(data.msg(&"item.15"))
	await common.wait(0x2710)
	screen.clear_window(Screen.MESSAGE)


## pick up
func pick_up() -> void:
	if st.floor_item == 0:
		_msg12(data.msg(&"item.16"))
		await ui.wait_space()
		return
	if st.chr.inv_full != 0:
		_msg12(data.msg(&"item.17"))
		await ui.wait_space()
		return
	screen.clear_window(Screen.MESSAGE)
	_msg12(data.msg(&"item.18"))
	var lvl := st.floor_item_poison
	if lvl != 0:
		st.chr.poison |= ((0x80 << lvl) | (0x80 >> (8 - lvl))) & 0xff
		txt.puts(data.msg(&"item.19"))
	txt.kana_mode = 0
	txt.puts(chara.item_name(st.floor_item))
	txt.puts(data.msg(&"item.20"))
	await ui.wait_space()
	st.chr.inv_add(st.floor_item)
	sys.journal(&"item", chara.item_name(st.floor_item))
	var off := st.cell_off + FloorMap.ITEM
	st.map.set_b(off, st.map.b(off) & 0x0f)
	st.floor_item = 0
	st.floor_item_poison = 0


## is there writing on the wall in front?
func _wall_writing() -> bool:
	if st.cell_wall_text == 0:
		return false
	return (st.map.b(st.cell_off + st.facing) & 0x90) != 0


## examine
func examine() -> void:
	if st.floor_item != 0:
		_msg12(data.msg(&"item.21"))
		txt.kana_mode = 0
		txt.puts(chara.item_name(st.floor_item))
		txt.puts(data.msg(&"item.22"))
		await ui.wait_space()
		if _wall_writing():
			await _read_wall()
		return
	if _wall_writing():
		await _read_wall()
		return
	_msg12(data.msg(&"item.23"))
	await ui.wait_space()


## reading a wall.  Writing number 1 (floor 4, at 1,8) makes the original skip 65536
## strings through its whole data segment (its `loop` counter starts at 0) and land on an empty
## one: the wall reads "" (seen running the original).  Fixed, it reads the first text
func _read_wall() -> void:
	_msg12(data.msg(&"item.24"))
	var texts: Array = data.table("wall_texts")
	txt.kana_mode = 0xff
	if st.cell_wall_text == 1 and not sys.fix_bugs:
		pass  # (the original's empty text)
	else:
		txt.puts(texts[clampi(st.cell_wall_text - 1, 0, texts.size() - 1)])
		sys.journal(&"wall", "", texts[clampi(st.cell_wall_text - 1, 0, texts.size() - 1)])
	txt.puts(data.msg(&"item.25"))
	await ui.wait_space()


# ------------------------------------------------------------------ use

func _nothing_happens() -> void:
	_msg12(data.msg(&"item.26"))
	await ui.wait_space()
	screen.clear_window(Screen.MESSAGE)


func _no_use_in_combat() -> void:
	_msg12(data.msg(&"item.27"))
	await ui.wait_space()
	screen.clear_window(Screen.MESSAGE)


func _only_in_combat() -> void:
	_msg12(data.msg(&"item.28"))
	await ui.wait_space()
	screen.clear_window(Screen.MESSAGE)


## the screen flashes five times
func flash_screen() -> void:
	for i in 5:
		screen.graphics_visible = false
		await common.beep(0x190, 0x64, 2)
		screen.graphics_visible = true
		await common.beep(0x190, 0x64, 2)


## use: may jump to dungeon_loop (guest card), so callers must check sys.unwinding
func use_item() -> void:
	screen.clear_window(Screen.MESSAGE)
	if st.chr.inv(0) == 0:
		_msg12(data.msg(&"item.29"))
		await ui.wait_space()
		return
	_msg12(data.msg(&"item.30"))
	var p: Dictionary = await pick_item(0)
	if not p.item:
		return
	screen.clear_window(Screen.MESSAGE)
	var i: int = p.index
	var kind := chara.item_kind(st.chr.inv(i))
	var n := (st.chr.inv(i) & 0x7f) - 0x33
	if (kind == 7 or kind == 9) and n >= 0 and n < 0x17:
		await _use_table()[n].call(i)
		return
	_msg12(data.msg(&"item.31"))
	await ui.wait_space()


## items 33h..49h; each entry takes the inventory index
func _use_table() -> Array[Callable]:
	return [
		_restore.bind(data.msg(&"item.32"), [&"pow"]),  # 33 Pow drug
		_restore.bind(data.msg(&"item.33"), [&"agl"]),  # 34 Ag drug
		_restore.bind(data.msg(&"item.34"), [&"pow", &"agl", &"tec", &"iq", &"hp"]),  # 35 Hyper drug
		_restore.bind(data.msg(&"item.35"), [&"hp"]),  # 36 H.P drug
		_restore.bind(data.msg(&"item.36"), [&"tec"]),  # 37 Tec drug
		_restore.bind(data.msg(&"item.37"), [&"iq"]),  # 38 I.Q drug
		_boost.bind(data.msg(&"item.38"), &"pow", &"fx_samson"),  # 39 Samson drug
		_boost.bind(data.msg(&"item.39"), &"iq", &"fx_brain"),  # 3A Brain upper
		_boost.bind(data.msg(&"item.40"), &"tec", &"fx_tec"),  # 3B Tec upper
		_boost.bind(data.msg(&"item.41"), &"agl", &"fx_responser"),  # 3C Responser
		_revelation_ring,  # 3D
		_bacillus_sensor,  # 3E
		_bacillus_cleaner,  # 3F
		_wide_mapper,  # 40
		_xray_searcher,  # 41
		_hand_light,  # 42
		_sound_barrier,  # 43
		_guest_card,  # 44
		_ex_card,  # 45
		_bio_searcher,  # 46
		_noise_machine,  # 47
		_squash_ball,  # 48
		_fog_ball,  # 49
	]


func _mode() -> int:
	return st.game_mode


## drugs that bring stats back to their maximum (consumed)
func _restore(i: int, text: String, stats: Array) -> void:
	st.chr.inv_remove(i)
	_msg12(text)
	for s: StringName in stats:
		st.chr.set(s, st.chr.get(StringName(String(s) + "_max")))
	chara.status_panel()
	await ui.wait_space()


## drugs that push a stat to 250 for a while (consumed)
func _boost(i: int, text: String, stat: StringName, flag: StringName) -> void:
	st.chr.inv_remove(i)
	_msg12(text)
	st.chr.set(stat, 0xfa)
	st.set(flag, 1)
	chara.status_panel()
	await ui.wait_space()


## reveals the meaning of a locked door (not consumed)
func _revelation_ring(_i: int) -> void:
	if _mode() == 4:
		await _no_use_in_combat()
		return
	if st.door_unlocked == 0:
		await _nothing_happens()
		return
	var off := st.cell_off + st.facing
	if not (st.map.b(off) & 0x20):
		await _nothing_happens()
		return
	st.map.set_b(off, st.map.b(off) & 0xdf)
	st.door_unlocked = 0
	st.ring_flag = 0
	st.hide_hunter = 0
	screen.clear_window(Screen.VIEW)
	dungeon.render_view()
	var doors: Array = data.table("ring_doors")
	var cx := 1
	var k := 0
	while k + 2 < doors.size() and not (st.floor == doors[k] and st.pos_x == doors[k + 1] and st.pos_y == doors[k + 2]):
		k += 3
		cx += 1
	var texts: Array = data.table("ring_texts")
	txt.puts(texts[mini(cx, texts.size() - 1)])
	sys.journal(&"ring", "", texts[mini(cx, texts.size() - 1)])
	await ui.wait_space()


func _bacillus_sensor(_i: int) -> void:
	if _mode() == 4:
		await _no_use_in_combat()
		return
	txt.at(0x13, 0x11, 0x13)
	await txt.print_slow(data.msg(&"item.46"))
	# poison level L (1..5) is poison bit L-1, named bacillus_names[L]; the original subtracts 3,
	# so it misses levels 1, 2 and names 4, 5 wrongly (T and H come out as A and I)
	var lvl := st.floor_item_poison - (0 if sys.fix_bugs else 3)
	if st.floor_item == 0 or lvl < (1 if sys.fix_bugs else 0):
		await txt.print_slow(data.msg(&"item.47"))
		await ui.wait_space()
		return
	await txt.print_slow(data.msg(&"item.48"))
	# (level 0 makes the original skip 65536 strings and print what it lands on: nothing here)
	var names: Array = data.table("bacillus_names")
	txt.puts(names[lvl] if lvl < names.size() else "")
	await ui.wait_space()


## 3F Bacillus cleaner
func _bacillus_cleaner(_i: int) -> void:
	if st.chr.poison == 0:
		await _nothing_happens()
		return
	st.chr.poison = 0
	_msg12(data.msg(&"item.42"))
	chara.status_panel()
	await ui.wait_space()


func _wide_mapper(_i: int) -> void:
	screen.clear_window(Screen.MESSAGE)
	txt.num_format = 0
	txt.num_hi = 0
	txt.num_lo = st.floor
	txt.at(0x13, 0x11, 0x13)
	await txt.print_slow(data.msg(&"item.49"))
	txt.num_hi = 0
	txt.num_lo = st.pos_x + 1
	await txt.print_slow(data.msg(&"item.50"))
	txt.num_hi = 0
	txt.num_lo = st.pos_y + 1
	await txt.print_slow(data.msg(&"item.51"))
	await ui.wait_space()


func _xray_searcher(_i: int) -> void:
	if _mode() == 4:
		await _no_use_in_combat()
		return
	txt.at(0x13, 0x11, 0x13)
	await txt.print_slow(data.msg(&"item.46"))
	var step: int = data.table("xray_steps")[st.facing & 3]
	if step >= 0x8000:
		step -= 0x10000
	var ahead := st.cell_off + step
	if (st.map.b(ahead + FloorMap.EVENT) & 0x3f) == 3:
		await txt.print_slow(data.msg(&"item.52"))
	else:
		await txt.print_slow(data.msg(&"item.53"))
	await ui.wait_space()


## 42 Hand light
func _hand_light(_i: int) -> void:
	if not (st.cell_event & 0x40):
		await _nothing_happens()
		return
	st.lamp_on = 1
	common.set_color4(6)


## 43 Sound barrier
func _sound_barrier(i: int) -> void:
	break_item(i)
	st.sound_barrier = 0x0a
	_msg12(data.msg(&"item.43"))
	await ui.wait_space()


## an android guides you out of BIAS
func _guest_card(i: int) -> void:
	if _mode() == 4:
		await _no_use_in_combat()
		return
	break_item(i)
	if st.floor == 6:
		await _nothing_happens()
		return
	screen.clear_window(Screen.VIEW)
	dungeon.monster_backdrop()
	common.show_monster(0x0e)
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11,
			data.msg(&"item.54"))
	await ui.wait_space()
	st.floor = 1
	st.pos_x = 0
	st.pos_y = 0x15
	st.facing = 2
	if sys.fix_bugs:
		# the original keeps door_unlocked from where the card was used: after a ring cell, the
		# revelation ring then works on the exit door here (and reads past its table)
		st.door_unlocked = 0
	common.load_floor_file()
	dungeon.randomize_doors()
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11, data.msg(&"item.55"))
	await ui.wait_space()
	screen.clear_window(Screen.VIEW)
	sys.jump(&"dungeon_loop")


## opens a card-locked door
func _ex_card(_i: int) -> void:
	if _mode() == 4:
		await _no_use_in_combat()
		return
	var ev := (st.cell_event & 0x3f) - 0x14
	if ev < 0 or ev >= 5:
		await _nothing_happens()
		return
	if not (st.cell[st.facing & 3] & 0x20):
		await _nothing_happens()
		return
	var off := st.cell_off + st.facing
	st.map.set_b(off, st.map.b(off) & 0xdf)
	screen.clear_window(Screen.MESSAGE)
	_msg12(data.msg(&"item.56"))
	await ui.wait_space()


func _bio_searcher(_i: int) -> void:
	if _mode() == 3:
		await _only_in_combat()
		return
	screen.clear_window(Screen.MESSAGE)
	txt.col = 0x1b
	txt.row = 0x11
	await txt.print_slow(data.msg(&"item.57"))
	txt.col = 0x1b
	txt.row = 0x13
	await txt.print_slow(data.msg(&"item.58"))
	txt.print_raw(st.mon.name)
	txt.set_number(st.mon.hp, 0)
	txt.col = 0x1b
	txt.row = 0x14
	await txt.print_slow(data.msg(&"item.59"))
	txt.num_hi = 0
	txt.num_lo = st.mon.ac
	txt.col = 0x1b
	txt.row = 0x15
	await txt.print_slow(data.msg(&"item.60"))
	txt.num_hi = 0
	txt.num_lo = st.mon.pow
	txt.col = 0x1b
	txt.row = 0x16
	txt.puts(data.msg(&"item.61"))
	await ui.wait_space()


## type in the monster's data to jam it
func _noise_machine(_i: int) -> void:
	if _mode() == 3:
		await _only_in_combat()
		return
	screen.clear_window(Screen.MESSAGE)
	var fail := false
	noise_failed = 0
	txt.col = 0x1a
	txt.row = 0x11
	await txt.print_slow(data.msg(&"item.62"))
	txt.col = 0x1a
	txt.row = 0x13
	await txt.print_slow(data.msg(&"item.58"))
	await ui.line_input()
	if ui.input != st.mon.name and not data.matches_translation(ui.input, st.mon.name):
		fail = true
	txt.col = 0x1a
	txt.row = 0x14
	await txt.print_slow(data.msg(&"item.63"))
	await ui.line_input()
	var v := Ui.parse_number(ui.input)
	if v < 0 or v != st.mon.hp:
		fail = true
	txt.col = 0x1a
	txt.row = 0x15
	await txt.print_slow(data.msg(&"item.64"))
	await ui.line_input()
	v = Ui.parse_number(ui.input)
	if v < 0 or (v & 0xff) != st.mon.ac:
		fail = true
	txt.col = 0x1a
	txt.row = 0x16
	await txt.print_slow(data.msg(&"item.65"))
	await ui.line_input()
	v = Ui.parse_number(ui.input)
	if v < 0 or (v & 0xff) != st.mon.pow:
		fail = true
	if fail:
		noise_failed = 0xff
	screen.clear_window(Screen.MESSAGE)
	if not fail:
		txt.col = 0x1a
		txt.row = 0x14
		txt.puts(data.msg(&"item.66"))
		await ui.wait_space()
		await flash_screen()
		combat.noise_on = 0x32
		combat.noise_timer = 0x32
		common.say_at(0x12, 0x16, data.msg(&"item.67"))
		await ui.wait_space()
	else:
		txt.col = 0x1a
		txt.row = 0x14
		await txt.print_slow(data.msg(&"item.68"))
		await ui.wait_space()


## 48 Squash ball
func _squash_ball(_i: int) -> void:
	if _mode() == 3:
		await _only_in_combat()
		return
	await flash_screen()
	combat.frozen = 0x32
	combat.frozen_timer = 0x32
	common.say_at(0x12, 0x16, data.msg(&"item.44"))
	await ui.wait_space()


## 49 Fog ball
func _fog_ball(_i: int) -> void:
	if _mode() == 3:
		await _only_in_combat()
		return
	await flash_screen()
	combat.fogged = 0x00ff
	combat.fog_timer = 0x32
	common.say_at(0x12, 0x16, data.msg(&"item.45"))
	await ui.wait_space()

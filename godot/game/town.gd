## Registration at the BIAS gate, the Beast City menu, entering BIAS, death.
class_name Town
extends Mod

## registered screamers in the roster, and the one picked (the original's,)
var roster_count := 0
var roster_sel := 0
## the "pick a screamer" navigation table, rebuilt for each list (in the original's data, town_pick_nav)
var _pick_nav: Array = []


func _tables_ready() -> void:
	if _pick_nav.is_empty():
		_pick_nav = (data.table("town_pick_nav") as Array).map(func(v): return int(v))
		var r: Array = data.table("town_init_roster")
		roster_count = int(r[0])
		roster_sel = int(r[1])


## frame and "DATA & INPUT WINDOW" logo of the registration screen
func _draw_entry_frame() -> void:
	screen.draw(art.tex("frames/entry"), Vector2i.ZERO, false)


## the town/dungeon screen: frame, panel labels, DATA logo and title
func draw_main_frame() -> void:
	screen.sprite(&"main_frame", art.tex("frames/main"), Vector2i.ZERO, false)


func _choose(nav: String, pos: String) -> int:
	return await ui.choose(data.table(nav), Ui.positions(data.table(pos)))


# ------------------------------------------------------------------ registration

## registration at the BIAS gate (flow target "registration")
func registration() -> void:
	_tables_ready()
	st.game_mode = 1
	common.set_color4(4)
	screen.clear_screen()
	_draw_entry_frame()
	txt.at(0x34, 0x15, 0x34)
	txt.kana_mode = 0xff
	await sys.beep_last()
	txt.puts(data.msg(&"town.01"))
	common.show_picture_at(2, 0x282)
	chara.load_roster()
	roster_count = chara.roster_count()
	st.chr = Character.new()
	await registration_restart()
	if sys.unwinding: return


## speech of the gatekeeper in the lower window (clear it, blip, then the text at column 3, row 15)
func _gatekeeper(s: String) -> void:
	screen.clear_window(Screen.BIG_MESSAGE)
	await common.blip()
	common.say(3, 0x0f, s)


## "new or registered?" (flow target "registration_restart")
func registration_restart() -> void:
	_tables_ready()
	ui.drain_keys()
	await _gatekeeper(data.msg(&"town.02"))
	if sys.unwinding: return
	screen.clear_window(Screen.DATA)
	txt.at(0x3a, 0x0b, 0x3a)
	await common.blip()
	if sys.unwinding: return
	txt.puts(data.msg(&"town.03"))
	var choice: int = await _choose("town_new_or_registered_nav", "town_new_or_registered_pos")
	if sys.unwinding: return
	if choice == 2:
		if roster_count == 0:
			await _gatekeeper(data.msg(&"town.04"))
			if sys.unwinding: return
			await common.wait(0x4e20)
			sys.jump(&"registration_restart")
			return
		await _registered()
		return
	if roster_count == 7:
		await _roster_full()
		return
	await _newcomer()


## Yes/No in the data window
func _yes_no_data() -> int:
	txt.at(0x3a, 0x0f, 0x3a)
	await sys.beep_last()
	txt.puts(data.msg(&"town.05"))
	return await _choose("town_yes_no_nav", "town_yes_no_pos")


func _newcomer() -> void:
	await _gatekeeper(data.msg(&"town.06"))
	if sys.unwinding: return
	await _enter_name()
	if sys.unwinding: return
	_new_stats()
	if ui.input == data.table("town_name_cheat_stats"):
		_cheat_stats()
	chara.roster[roster_count] = st.chr.copy()
	await _gatekeeper(data.msg(&"town.07"))
	if sys.unwinding: return
	await _enter_city()


func _enter_name() -> void:
	screen.clear_window(Screen.DATA)
	txt.col = 0x32
	txt.row = 0x0b
	await common.blip()
	if sys.unwinding: return
	txt.puts(data.msg(&"town.08"))
	await ui.line_input()
	if sys.unwinding: return
	if ui.input.is_empty():
		await _gatekeeper(data.msg(&"town.09"))
		if sys.unwinding: return
		await common.wait(0x4e20)
		sys.jump(&"registration_restart")
		return
	# the 16 bytes of the input buffer become the name, with whatever earlier, longer input left
	# after its end (Ui.input_buf when Ui keeps the raw buffer; otherwise zeroes)
	var raw: Variant = ui.get(&"input_buf")
	var b: PackedByteArray = raw if raw is PackedByteArray else GameText.encode(ui.input)
	for i in 0x10:
		st.chr.record[i] = b[i] if i < b.size() else 0
	if chara.find_in_roster() >= 0:
		await _gatekeeper(data.msg(&"town.10"))
		if sys.unwinding: return
		await common.wait(0x4e20)
		sys.jump(&"registration_restart")
		return
	await _gatekeeper(data.msg(&"town.11"))
	if sys.unwinding: return
	var yes: int = await _yes_no_data()
	if sys.unwinding: return
	if yes != 1:
		sys.jump(&"registration_restart")


## a fresh screamer
func _new_stats() -> void:
	var c := st.chr
	for s in [&"hp", &"hp_max", &"agl", &"pow", &"tec", &"iq", &"luck", &"agl_max", &"pow_max", &"tec_max", &"iq_max"]:
		c.set(s, 10)
	c.hc = 0
	c.ac = 0
	c.poison = 0
	c.bp = 0
	c.bp_total = 0
	c.credits = 500


## "-I LOVE ASCII-"
func _cheat_stats() -> void:
	var c := st.chr
	c.hp = 0xff
	c.hp_max = 0xff
	for s in [&"agl", &"agl_max", &"pow", &"pow_max", &"tec", &"tec_max", &"iq", &"iq_max", &"luck"]:
		c.set(s, 0xfa)
	c.hc = 0x19
	c.ac = 0
	c.poison = 0
	c.bp = 0
	c.bp_total = 0
	c.credits = 0x8000
	var items := [0xd2, 0x98, 0xa6, 0xa7, 0xa8, 0xa9]
	for i in range(0x33, 0x4a):
		items.append(i)
	for i in items.size():
		c.set_inv(i, items[i])


func _registered() -> void:
	await _gatekeeper(data.msg(&"town.12"))
	if sys.unwinding: return
	await _pick_character()
	if sys.unwinding: return
	screen.clear_window(Screen.DATA)
	await _gatekeeper(data.msg(&"town.13"))
	if sys.unwinding: return
	var yes: int = await _yes_no_data()
	if sys.unwinding: return
	if yes == 2:
		sys.jump(&"registration_restart")
		return
	st.chr = chara.roster[roster_sel - 1].copy()
	await _gatekeeper(data.msg(&"town.14"))
	if sys.unwinding: return
	await _enter_city()


## list the roster in the data window and pick one
func _pick_character() -> void:
	screen.clear_window(Screen.DATA)
	await common.blip()
	if sys.unwinding: return
	txt.at(0x35, 6, 0x35)
	for i in chara.roster_count():
		txt.print_raw(chara.roster[i].name)
		txt.put_char(0x0d)
		txt.put_char(0x0d)
		txt.kana_mode = 0xff
	# vertical navigation table for roster_count items
	var cl := (roster_count + 1) & 0xff
	var al := 1
	var bx := 0
	while true:
		al = (al - 1) & 0xff
		_pick_nav[bx] = al
		_pick_nav[bx + 1] = 0
		bx += 2
		al = (al + 2) & 0xff
		if al >= cl:
			break
		_pick_nav[bx] = al
		_pick_nav[bx + 1] = 0
		bx += 2
	_pick_nav[bx] = 0
	roster_sel = await ui.choose(_pick_nav, Ui.positions(data.table("town_pick_pos")))


func _roster_full() -> void:
	await _gatekeeper(data.msg(&"town.15"))
	if sys.unwinding: return
	screen.clear_window(Screen.DATA)
	var yes: int = await _yes_no_data()
	if sys.unwinding: return
	if yes == 2:
		sys.jump(&"registration_restart")
		return
	await _gatekeeper(data.msg(&"town.16"))
	if sys.unwinding: return
	await _pick_character()
	if sys.unwinding: return
	screen.clear_window(Screen.DATA)
	await _gatekeeper(data.msg(&"town.17"))
	if sys.unwinding: return
	yes = await _yes_no_data()
	if sys.unwinding: return
	if yes == 2:
		sys.jump(&"registration_restart")
		return
	var slot := roster_sel - 1
	screen.clear_window(Screen.BIG_MESSAGE)
	txt.at(2, 0x0f, 2)
	txt.print_raw(chara.roster[slot].name)
	txt.kana_mode = 0xff
	txt.puts(data.msg(&"town.18"))
	# the later slots move up; the last one is left free
	for i in range(slot, 7):
		chara.roster[i] = chara.roster[i + 1]
	var free := PackedByteArray()
	free.resize(Character.SIZE)
	free.fill(0xff)
	chara.roster[7] = Character.new(free)
	roster_count -= 1
	await common.wait(0x4e20)
	sys.jump(&"registration_restart")


## save the roster and walk into Beast City (or meet one of the joke names)
func _enter_city() -> void:
	chara.save_roster()
	await common.wait(0x4e20)
	screen.clear_screen()
	common.picture_dest = 0x832
	var name := st.chr.name
	if name == data.table("town_name_dead"):
		screen.clear_screen()
		txt.col = 0x1e
		txt.row = 0x0a
		txt.puts(data.msg(&"town.19"))
		await common.wait(0x9c40)
		sys.jump(&"game_over")
		return
	if name == data.table("town_name_drinker"):
		screen.clear_screen()
		txt.col = 0x1e
		txt.row = 0x0a
		txt.puts(data.msg(&"town.20"))
		await common.wait(0x9c40)
		screen.clear_screen()
		common.set_color4(4)
		draw_main_frame()
		st.game_mode = 2
		txt.at(0x3d, 8, 0x3d)
		txt.print_raw(st.chr.name)
		txt.kana_mode = 0xff
		chara.status_panel()
		screen.clear_window(Screen.MENU)
		screen.clear_window(Screen.MESSAGE)
		screen.clear_window(Screen.VIEW)
		st.hide_hunter = 0xff
		items.set(&"show_prices", 0)
		sys.jump(&"bar")
		return
	if name == data.table("town_name_porter"):
		screen.clear_screen()
		txt.col = 0x0a
		txt.row = 0x0a
		txt.puts(data.msg(&"town.21"))
		txt.col = 0x0c
		txt.row = 0x0b
		txt.puts(data.msg(&"town.22"))
		txt.col = 0x0d
		txt.row = 0x0c
		txt.puts(data.msg(&"town.23"))
		st.chr.credits = 10000
		await common.wait(0xc350)
		screen.clear_screen()
	sys.jump(&"town")


# ------------------------------------------------------------------ Beast City

## enter the town (flow target "town")
func run_town() -> void:
	st.game_mode = 2
	common.set_color4(4)
	draw_main_frame()
	await town_menu()


## draw the name, refresh the status and clear the three windows (shared by town and BIAS)
func town_screen_reset() -> void:
	txt.at(0x3d, 8, 0x3d)
	txt.print_raw(st.chr.name)
	txt.kana_mode = 0xff
	chara.recalc_ac()
	chara.status_panel()
	screen.clear_window(Screen.MENU)
	screen.clear_window(Screen.MESSAGE)
	screen.clear_window(Screen.VIEW)


## the town command menu (flow target "town_menu")
func town_menu() -> void:
	town_screen_reset()
	st.hide_hunter = 0xff
	items.set(&"show_prices", 0)
	common.show_picture_at(3, 0x832)
	ui.menu_reset(10)
	screen.clear_window(Screen.MENU)
	common.say(5, 3, data.msg(&"town.24"))
	while true:
		await common.blip()
		if sys.unwinding: return
		txt.at(0x13, 0x11, 0x13)
		txt.puts(data.msg(&"town.25"))
		ui.rest = &"town"
		var sel: int = await ui.menu_choose()
		ui.rest = &""
		if sys.unwinding: return
		match sel:
			1:
				await _bias_gate()
			2:
				await shops.frd_shop()
			3:
				await shops.hospital()
			4:
				await shops.bar()
			5:
				await shops.weapon_shop()
			6:
				await chara.show_abilities()
			7:
				await items.look_items()
			8:
				await items.unequip_item()
			9:
				await items.drop_item()
			10:
				await _leave_city()
		if sys.unwinding: return


func _leave_city() -> void:
	if ui.last_key == 0x1b:
		return
	_store_character()
	screen.clear_screen()
	txt.at(0x18, 0x0b, 0x18)
	txt.puts(data.msg(&"town.26"))
	while (await ui.wait_key()) != Keys.K_SPACE:
		pass
	sys.jump(&"registration")


## write the current character back into its roster slot and save
func _store_character() -> void:
	chara.load_roster()
	var slot := chara.find_in_roster()
	if slot >= 0:
		chara.roster[slot] = st.chr.copy()
	chara.save_roster()


# ------------------------------------------------------------------ the BIAS gate

func _bias_gate() -> void:
	common.show_picture(9)
	screen.clear_window(Screen.MESSAGE)
	txt.at(0x13, 0x11, 0x13)
	txt.puts(data.msg(&"town.27"))
	ui.menu_reset(7)
	screen.clear_window(Screen.MENU)
	common.say(5, 3, data.msg(&"town.28"))
	while true:
		var sel: int = await ui.menu_choose()
		if sys.unwinding: return
		match sel:
			1:
				await _enter_bias()
			2:
				await chara.show_abilities()
			3:
				await items.look_items()
			4:
				await items.equip_item()
			5:
				await items.unequip_item()
			6:
				await items.drop_item()
			7:
				sys.jump(&"town_menu")
				return
		if sys.unwinding: return


func _enter_bias() -> void:
	await common.npc(data.msg(&"town.29"))
	if sys.unwinding: return
	await ui.wait_space()
	if sys.unwinding: return
	common.show_picture(10)
	await common.npc(data.msg(&"town.30"))
	if sys.unwinding: return
	await common.wait(0x3a98)
	await _gate_opens()
	if sys.unwinding: return
	await common.wait(0x3a98)
	st.floor = 1
	st.pos_x = 0
	st.pos_y = 0x15
	st.facing = 0
	st.color4 = 7
	common.load_floor_file()
	dungeon.randomize_doors()
	sys.jump(&"dungeon")


## the gate slides open (the picture of it moves left 8 pixels at a time) while a
## lamp blinks.  The original moves 20 bytes of 93 rows, which hold the posts of
## the gate's frame as well (x 232..383): here only the door between them moves.
func _gate_opens() -> void:
	var rect := Rect2i(Vector2i(237, Screen.px(0xabd).y), Vector2i(143, 0x5d))
	# a clipped copy of what the rectangle shows slides over the original
	var clip := Control.new()
	clip.position = rect.position
	clip.size = rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = rect.size
	clip.add_child(bg)
	# clipped too: only what starts inside the rectangle moves (not the rest of the picture
	# behind it), and black comes in from the right
	var moving := Control.new()
	moving.size = rect.size
	moving.clip_contents = true
	clip.add_child(moving)
	for n in screen.nodes_in(rect):
		var d: Control = n.duplicate()
		d.position = n.global_position - screen.images.global_position - Vector2(rect.position)
		moving.add_child(d)
	screen.images.add_child(clip)
	var lamp := 0
	var tick := 0
	for n in 0x14:
		moving.position.x -= 8
		lamp ^= 0xff
		screen.draw(art.piece("town/gate_lamp_on" if lamp else "town/gate_lamp_off"), Screen.px(0xc12))
		tick ^= 0xff
		if tick:
			await sys.beep(0x64, 0x96, 6)
		else:
			await common.wait(0x5dc)


# ------------------------------------------------------------------ death

## death (flow target "game_over")
func game_over() -> void:
	chara.load_roster()
	var slot := chara.find_in_roster()
	if slot >= 0:
		# the screamer is struck off: the later slots move up, the last one is left free
		for i in range(slot, 7):
			chara.roster[i] = chara.roster[i + 1]
		var free := PackedByteArray()
		free.resize(Character.SIZE)
		free.fill(0xff)
		chara.roster[7] = Character.new(free)
		chara.save_roster()
	screen.clear_screen()
	common.monster_dest = 0x8dc
	common.show_monster(0x2a)
	txt.at(0x13, 0x11, 0x13)
	txt.puts(data.msg(&"town.31"))
	while (await ui.wait_key()) != Keys.K_SPACE:
		pass
	sys.jump(&"registration")

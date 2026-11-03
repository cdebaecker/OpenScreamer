## BIAS, the tower: the main loop, moving, the first-person view, encounters.
class_name Dungeon
extends Mod

## virtual time of one pass through the idle loop at
const IDLE_ITERATION_US := 600

## the view window's top-left corner on the board
const VIEW := Vector2i(144, 24)
## where the three parts of the ceiling lights go (0x79E, 0xE82, 0x1424)
const LIGHT_SPOTS: Array[Vector2i] = [Vector2i(240, 24), Vector2i(272, 46), Vector2i(288, 64)]
## compass letters: north, east, south, west spots of the compass box
const COMPASS_SPOTS: Array[Vector2i] = [Vector2i(536, 148), Vector2i(576, 168), Vector2i(536, 188), Vector2i(496, 168)]
const STEP_MARKER := Vector2i(528, 164)
const BACKDROP := Vector2i(304, 26)  # 0x846
const TITLE := Rect2i(200, 0, 208, 16)  # 0x19, 1Ah bytes x 10h lines

# idle-loop state
var _bump := 0  # walking into a wall: the message comes when it wraps to 0
var _light_sub := 0
var _light_sub2 := 0
var _light_frame := 0
var _regen_count := 0
var _poison_counters := [10, 10, 10, 10, 10]
var _step_toggle := 0
## (fixing the original's bugs) the cell whose floor item was last looked at
var _item_cell := Vector3i(-1, -1, -1)
var _debug_item := 1
# what lies ahead, for the ceiling lights
var _here_dark := 0
var _here_lit := 0
var _next_lit := 0
var _far_lit := 0
var _wall_here := 0
var _wall_next := 0
## the view composed by build_view(): [piece name, board position] in drawing order
var _view_pieces: Array = []
## the light nodes on the board (to put back after the walls are redrawn)
var _light_nodes: Array = [null, null, null]
var _title_negative: Texture2D
## the text cells the screen frame covers
var _frame_cells: Array[Rect2i] = []


# ------------------------------------------------------------------ map

const DOOR_PARTNERS := [[0, -0xf0], [1, 0x0a], [2, 0xc0], [3, -9]]
const DOOR_PARTNERS_FIXED := [[0, -0xbe], [1, 0x0b], [2, 0xc0], [3, -7]]


## load the floor and roll the random doors (wall bit 6)
func randomize_doors() -> void:
	common.load_floor_file()
	var map := st.map
	var si := 0
	for n in 0x120:
		# each wall byte with bit 6 opens or closes at random, together with a (mis-addressed)
		# partner byte; partners outside the map are lost (the original hits its work buffer).
		# Only the south wall's partner is right: north and east hit walls of other cells, and
		# west the item byte of the cell two to the left.  Fixed: the same wall seen from the
		# neighbouring cell (N <-> S of the cell above, E <-> W of the cell to the right...), none
		# past the floor's edge.  (No shipped floor has random doors: this only shows on others.)
		for p in DOOR_PARTNERS_FIXED if sys.fix_bugs else DOOR_PARTNERS:
			var k: int = p[0]
			var partner: int = si + p[1]
			if sys.fix_bugs and ((k == 1 and n % 12 == 11) or (k == 3 and n % 12 == 0)):
				partner = 0x10000  # (si / 8) % 24 is 2 * (n % 12): the east / west edge
			if not (map.b(si + k) & 0x40):
				continue
			if rng.random(1) == 0:
				map.set_b(si + k, map.b(si + k) | 1)
				map.set_b(partner, map.b(partner) | 1)
			else:
				map.set_b(si + k, map.b(si + k) & 0xfe)
				map.set_b(partner, map.b(partner) & 0xfe)
		si += 0x10


## take the current cell and compose the view (walls seen from here, by facing)
func build_view() -> void:
	var cell := st.cell_off
	st.cell = st.map.bytes.slice(cell, cell + 8)
	_view_pieces = [["view/p_60df", VIEW + Vector2i(0, 60)]]
	var offsets: Array = data.table("view_wall_offsets")
	var table: Array = data.table("view_pieces")
	for n in 0x1b:
		var wall := st.map.b((int(offsets[st.facing * 0x1b + n]) + cell) & 0xffff)
		if not (wall & 1):
			continue
		var src: int = table[n * 4 + 1] if wall & 2 else table[n * 4]
		var dst: int = table[n * 4 + 2] - 6  # in the original's work buffer, 28h bytes per line
		_view_pieces.append(["view/p_%04x" % src, VIEW + Vector2i((dst % 0x28) * 8, dst / 0x28)])


## show the composed view (green walls: their colour is palette entry 4) and pick
## the wall colour
func show_view() -> void:
	var al := st.color4
	if st.pos_x != 0x17:
		al = 7
		if st.cell_event & 0x40:
			al = 6 if st.color4 == 6 else 0
	common.set_color4(al)
	# the original rewrites only the walls' plane: the ceiling lights stay
	var lights := []
	for i in 3:
		var n: Array = _light_nodes[i] if _light_nodes[i] != null else []
		if not n.is_empty() and is_instance_valid(n[1]) and n[1].get_parent() == screen.images:
			lights.append([i, n[1].texture])
	screen.fill(Rect2i(VIEW, Vector2i(320, 104)), Screen.BLACK)
	for p in _view_pieces:
		var tex := art.piece(p[0])
		screen.fill(Rect2i(p[1], Vector2i(tex.get_size())), Screen.BLACK)
		screen.draw(tex, p[1], false)
	for l in lights:
		_draw_light(l[0], l[1])
	_compass()


func render_view() -> void:
	build_view()
	show_view()


## footstep marker and compass letters
func _compass() -> void:
	_step_marker()
	_compass_letters()
	_step_toggle ^= 0xff


func _step_marker() -> void:
	screen.sprite(&"step_marker", art.piece("dungeon/step", 0 if _step_toggle != 0 else 1), STEP_MARKER)


func _compass_letters() -> void:
	for i in 4:
		screen.sprite(StringName("compass_%d" % i), art.piece("dungeon/compass", (i + st.facing) & 3),
				COMPASS_SPOTS[i])


## what lies ahead (dark cells, walls) for the ceiling light animation
func look_ahead() -> void:
	var dx: int = data.table("ahead_dx")[st.facing]
	var si := st.cell_off
	var f := st.facing
	_here_lit = st.map.b(si + 6) & 0x80
	_here_dark = st.map.b(si + 6) & 0x40
	_wall_here = st.map.b(si + f) & 1
	si = (si + dx) & 0xffff
	_next_lit = st.map.b(si + 6) & 0x80
	_wall_next = st.map.b(si + f) & 1
	si = (si + dx) & 0xffff
	_far_lit = st.map.b(si + 6) & 0x80


## one frame of the ceiling lights (the original's plane B)
func _lights(frame: int) -> void:
	var ptr: int = data.table("light_frames")[frame & 7]
	if st.hunter != 0 or _here_dark != 0 or _here_lit != 0:
		return
	_draw_light(0, art.piece("view/light_%04x_0" % ptr))
	if _next_lit != 0 or _wall_here != 0:
		return
	_draw_light(1, art.piece("view/light_%04x_1" % ptr))
	if _far_lit != 0 or _wall_next != 0:
		return
	_draw_light(2, art.piece("view/light_%04x_2" % ptr))


## the original rewrites only the blue plane: the previous light goes, the walls stay
func _draw_light(i: int, tex: Texture2D) -> void:
	var old: Array = _light_nodes[i] if _light_nodes[i] != null else []
	if not old.is_empty() and is_instance_valid(old[1]) and old[1].get_parent() == screen.images:
		old[1].queue_free()
		screen.images.remove_child(old[1])
	_light_nodes[i] = [null, screen.draw(tex, LIGHT_SPOTS[i], false)]


func lights_off() -> void:
	_lights(7)


func lights_on() -> void:
	_lights(_light_frame)


func _lights_tick() -> void:
	_light_sub = (_light_sub + 0x20) & 0xff
	if _light_sub != 0:
		return
	_light_sub2 = (_light_sub2 + 0x80) & 0xff
	if _light_sub2 != 0:
		return
	_light_frame = (_light_frame + 1) & 0xff
	_lights(_light_frame)


# ------------------------------------------------------------------ entering and the main loop

## (flow target "dungeon")
func run_dungeon() -> void:
	st.game_mode = 3
	_draw_frame()
	screen.clear_window(Screen.VIEW)
	screen.clear_window(Screen.MESSAGE)
	screen.clear_window(Screen.MENU)
	items.show_prices = 0
	st.hide_hunter = 0
	txt.kana_mode = 0xff
	txt.at(5, 3, 5)
	common.picture_dest = 0x832
	common.monster_dest = 0x832
	st.idle_count = 0
	ui.menu_reset(10)
	screen.clear_window(Screen.MENU)
	common.say(5, 3, data.msg(&"bias.01"))
	await dungeon_loop()


## (frame 1): the frame paints over whatever was there, text included
func _draw_frame() -> void:
	var tex := art.tex("frames/main")
	screen.sprite(&"main_frame", tex, Vector2i.ZERO, false)
	if _frame_cells.is_empty():
		var img := tex.get_image()
		for row in 25:
			for col in 80:
				if not img.get_region(Rect2i(col * 8, row * 8, 8, 8)).is_invisible():
					_frame_cells.append(Rect2i(col * 8, row * 8, 8, 8))
	for r in _frame_cells:
		screen.text.clear(r)


## arrive at a cell (after moving, turning, or coming back from somewhere)
## (flow target "dungeon_loop")
func dungeon_loop() -> void:
	st.hide_hunter = 0
	chara.status_panel()
	keys.flush()
	if st.need_redraw != 0:
		screen.clear_window(Screen.MESSAGE)
		st.need_redraw = 0
	if st.hunter != 0:
		screen.clear_window(Screen.VIEW)
		st.hide_hunter = 0
		st.hunter = 0
	if st.ring_flag != 0:
		screen.clear_window(Screen.VIEW)
		st.ring_flag = 0
	await _sound_barrier_tick()
	if sys.unwinding: return
	lights_off()
	render_view()
	if st.stood == 0:
		await _footstep()
	else:
		await _turn_click()
	if sys.unwinding: return
	look_ahead()
	await events.run_event(st.cell_event & 0x3f)
	if sys.unwinding: return
	lights_on()
	for fx in [[&"fx_samson", data.msg(&"bias.02")], [&"fx_brain", data.msg(&"bias.03")],
			[&"fx_tec", data.msg(&"bias.04")], [&"fx_responser", data.msg(&"bias.05")]]:
		await _wear_off(fx[0], fx[1])
		if sys.unwinding: return
	if st.stood == 0:
		await _encounter_check()
		if sys.unwinding: return
	await _items_break()
	if sys.unwinding: return
	await _wall_notice()
	if sys.unwinding: return
	if look_for_item():
		await _floor_item()
		if sys.unwinding: return
	_regen_count = 0
	while true:
		await _poison_ticks()
		if sys.unwinding: return
		await _encounter_check()
		if sys.unwinding: return
		await _debug_keys()
		if sys.unwinding: return
		while true:
			# moving, opening doors and turning leave this loop through a jump; a bump or a
			# refused door comes straight back here without counting the pass
			_lights_tick()
			_regen()
			if sys.unwinding: return
			ui.rest = &"bias"
			await sys.advance(IDLE_ITERATION_US)
			ui.rest = &""
			var dir := ui.numpad()
			if dir == 1:
				await _move_forward()
				if sys.unwinding: return
				continue
			if dir == 5:
				await _open_door()
				if sys.unwinding: return
				continue
			if dir >= 2 and dir <= 4:
				await _turn(dir - 1)
				if sys.unwinding: return
			var sel: int = await ui.menu_poll()
			if sys.unwinding: return
			if sel:
				await run_command(sel)
				if sys.unwinding: return
			ui.drain_keys()
			st.idle_count = (st.idle_count + 1) & 0xffff
			if st.idle_count >= 0x1800:
				break
		st.idle_count = 0


## run a command chosen from the dungeon menu
func run_command(sel: int) -> void:
	lights_off()
	var commands: Array[Callable] = [
		items.examine,
		items.pick_up,
		items.drop_item,
		items.equip_item,
		items.unequip_item,
		items.use_item,
		shops.give,
		shops.talk,
		chara.show_abilities,
		items.look_items,
	]
	await commands[sel - 1].call()
	if sys.unwinding: return
	lights_on()


func _footstep() -> void:
	await common.beep(1, 1, 0x3e8)
	if sys.unwinding: return
	_step_marker()


func _turn_click() -> void:
	await common.beep(1, 1, 0x1f4)
	if sys.unwinding: return
	_compass_letters()


func _sound_barrier_tick() -> void:
	if st.stood != 0 or st.sound_barrier == 0:
		return
	st.sound_barrier = (st.sound_barrier - 1) & 0xff
	if st.sound_barrier != 0:
		return
	common.say(0x12, 0x11, data.msg(&"bias.06"))
	await ui.wait_space()


## a drug's effect runs out
func _wear_off(flag: StringName, text: String) -> void:
	if st.get(flag) == 0:
		return
	st.set(flag, 0)
	common.say(0x12, 0x11, text)
	chara.drugs_wear_off()
	await ui.wait_space()


## one HP back every 10000 idle passes
func _regen() -> void:
	_regen_count = (_regen_count + 1) & 0xffff
	if _regen_count < 0x2710:
		return
	_regen_count = 0
	chara.adjust_stat(0, 1)


## the five poisons: [bit, stat that suffers besides HP (-1 none)]
func _poison_ticks() -> void:
	var kinds := [[1, 1], [2, 4], [4, 2], [8, 3], [0x10, -1]]
	for i in 5:
		var bit: int = kinds[i][0]
		var stat: int = kinds[i][1]
		if not (st.chr.poison & bit):
			continue
		_poison_counters[i] = (_poison_counters[i] - 1) & 0xff
		if _poison_counters[i] != 0:
			continue
		_poison_counters[i] = 0x0a
		chara.adjust_stat(0, -(rng.random(2) + 1))
		if sys.unwinding: return
		if stat >= 0:
			chara.adjust_stat(stat, -(rng.random(2) + 1))
			if sys.unwinding: return


func _encounter_check() -> void:
	if st.monster != 0 or st.hunter != 0:
		return
	await _encounter()


## now and then something you carry breaks
func _items_break() -> void:
	if rng.random(0x7d) != 0:
		return
	if rng.random(7) != 0:
		return
	if st.chr.inv(0) == 0:
		return
	var i := rng.random(st.chr.inv_count() - 1)
	if chara.item_kind(st.chr.inv(i)) >= 8:
		return
	items.break_item(i)
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11, data.msg(&"bias.07"))
	await ui.wait_space()


func _wall_notice() -> void:
	if st.cell_wall_text == 0:
		return
	if not (st.cell[st.facing] & 0x90):
		return
	common.say(0x12, 0x11, data.msg(&"bias.08"))
	await ui.wait_space()


## an item may lie on the floor of the new cell
## the original looks for an item only after a step (stood 0): never on stairs and elevator cells
## or where they land (their items can't be had: F1's revelation ring), and again after each fight
## in the cell (an item lying there is gone).  Fixed: once per cell, on arriving
func look_for_item() -> bool:
	if not sys.fix_bugs:
		return st.stood == 0
	return Vector3i(st.floor, st.pos_x, st.pos_y) != _item_cell


func _floor_item() -> void:
	_item_cell = Vector3i(st.floor, st.pos_x, st.pos_y)
	st.floor_item = 0
	var item: int
	var placed := (st.cell_item & 0xf0) >> 4
	if placed != 0:
		item = data.table("placed_items")[placed - 1]
	else:
		if st.floor == 6:
			return
		if rng.random(0x7d) != 0:
			return
		if rng.random(3) != 0:
			return
		# per floor: a 0-terminated run, then a count and the items that may turn up
		var lists: Array = data.table("floor_items")
		var bx := 0
		var ch := st.floor
		while ch > 0:
			while true:
				var c: int = lists[bx]
				bx += 1
				if c == 0:
					break
			ch -= 1
		var n: int = lists[bx]
		bx += 1
		item = lists[bx + rng.random(n - 1)]
	st.floor_item = item
	if rng.random(0xfa) < 0x0a and chara.item_kind(item) < 8:
		items.break_item(Items.FLOOR_ITEM)  # it lies there broken
	var r := rng.random(0xfa)
	var cl := 0
	for t in [0xc8, 0xd2, 0xdc, 0xe6, 0xf0]:
		if r >= t:
			cl += 1
	st.floor_item_poison = cl
	common.say(0x12, 0x11, data.msg(&"bias.09"))
	await ui.wait_space()


# ------------------------------------------------------------------ moving

## turn right (1), around (2) or left (3)
func _turn(by: int) -> void:
	st.stood = 1
	st.door_msg = 0
	st.door_unlocked = 0
	st.facing = (by + st.facing) & 3
	lights_off()
	await ui.hold_pause(0x64)
	if sys.unwinding: return
	ui.drain_keys()
	sys.jump(&"dungeon_loop")


## step forward
func _move_forward() -> void:
	await _secret_wall()
	if sys.unwinding: return
	if not (st.map.b(st.facing + st.cell_off) & 1):
		await ui.hold_pause(0x32)
		if sys.unwinding: return
		ui.drain_keys()
		await arrive()
		return
	if sys.fix_bugs and _bump == 0:  # the original starts at 0: the first message needs 256 bumps
		_bump = 3
	_bump = (_bump - 1) & 0xff
	if _bump != 0:
		return
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11, data.msg(&"bias.10"))
	await ui.hold_pause(0x190)
	if sys.unwinding: return
	ui.drain_keys()
	screen.clear_window(Screen.MESSAGE)
	_bump = 3


## the step itself
func arrive() -> void:
	lights_off()
	st.monster = 0
	st.stood = 0
	st.door_msg = 0
	st.trap_done = 0
	st.door_unlocked = 0
	if st.revealed_walls != 0:
		# walls made solid by walking into them become invisible again
		var bx := st.cell_off
		for i in 4:
			if st.map.b(bx + i) & 8:
				st.map.set_b(bx + i, st.map.b(bx + i) & 0xfe)
		st.revealed_walls = 0
	match st.facing:
		0:
			st.pos_y = (st.pos_y - 1) & 0xff
		1:
			st.pos_x = (st.pos_x + 1) & 0xff
		2:
			st.pos_y = (st.pos_y + 1) & 0xff
		3:
			st.pos_x = (st.pos_x - 1) & 0xff
	sys.jump(&"dungeon_loop")


## walking into an invisible wall makes it solid (until you leave the cell).  The
## original slides the wall down into the view with no pause, and redraws the view
## straight after, so only the redraw is kept.
func _secret_wall() -> void:
	var bx := st.facing + st.cell_off
	if (st.map.b(bx) & 0x0b) != 8:
		return
	st.map.set_b(bx, st.map.b(bx) | 1)
	st.revealed_walls = st.map.b(bx)
	lights_off()
	render_view()
	look_ahead()
	lights_on()


## numpad 5 opens the door in front
func _open_door() -> void:
	if st.door_unlocked != 0:
		return
	var al := st.cell[st.facing]
	if al & 4:
		await _door_stuck()
		return
	if (al & 3) != 3:
		return
	if st.hunter != 0 or st.ring_flag != 0:
		screen.clear_window(Screen.VIEW)
		render_view()
	if not (st.map.b(st.facing + st.cell_off) & 0x20):
		await _door_opens()
		return
	var code := (st.cell_event & 0x3f) - 0x14
	if code < 0:
		await _door_opens()
		return
	# codes 5..8, the doors to floor 6: the blade test.  The Samurai, who gives the blade,
	# waits behind a code-7 door, and floor 6 behind his code-8 one: as shipped there is no way in.
	# With the way to floor 6 open (sys.pendant_fix, as on the PC-88, whose test is skipped for these
	# codes) the password alone opens them.
	if code >= 5 and not (sys.pendant_fix or sys.fix_bugs):
		var cl := 0xff if code == 8 else 0
		if chara.has_item(0x19) < 0:
			cl ^= 0xff
		if cl != 0:
			await _door_stuck()
			return
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11, data.msg(&"bias.11"))
	keys.take()  # one key is thrown away
	await ui.line_input()
	if sys.unwinding: return
	if ui.input == _password(code):
		await _door_opens()
		return
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11, data.msg(&"bias.12"))
	await ui.wait_space()


## the password of a speaking door (five bytes each, 0-terminated, in door_passwords)
func _password(code: int) -> String:
	var t := PackedByteArray(data.table("door_passwords"))
	var s := t.slice(code * 5)
	var z := s.find(0)
	return GameText.decode(s if z < 0 else s.slice(0, z))


func _door_stuck() -> void:
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11, data.msg(&"bias.13"))
	await ui.hold_pause(0x2bc)
	if sys.unwinding: return
	ui.drain_keys()
	screen.clear_window(Screen.MESSAGE)


func _door_opens() -> void:
	screen.clear_window(Screen.MESSAGE)
	_door_slide()
	await arrive()


## the door halves slide apart revealing the corridor behind.  The original composes
## the view with the door open (which also takes the cell) and slides plane G with no
## pause before the step redraws everything, so only the composing is kept.
func _door_slide() -> void:
	var bx := st.facing + st.cell_off
	st.map.set_b(bx, st.map.b(bx) & 0xfe)
	build_view()
	st.map.set_b(bx, st.map.b(bx) | 1)


# ------------------------------------------------------------------ encounters

func _encounter() -> void:
	if (st.stood == 0 and st.floor == 5 and st.pos_x == 0x11 and st.pos_y == 5
			and chara.has_item(0x19) < 0):
		st.hunter = 8
		await _meet_hunter()
		return
	if st.sound_barrier == 0:
		var rate: int = data.table("encounter_rates")[st.cell_item & 0x0f]
		if rate >= rng.random(0x63) + 1:
			await _monster_appears()
			return
	if st.floor == 6:
		return
	if rng.random(0xff) >= 1:
		return
	st.hunter = rng.random(6) + 1
	await _meet_hunter()


func _monster_appears() -> void:
	var mon := st.cell_monster
	if mon == 0:
		# per floor: a 0-terminated run, then a count and the monsters that may turn up
		var lists: Array = data.table("floor_monsters")
		var bx := 0
		var n := st.floor
		while true:
			bx += 1
			while lists[bx] != 0:
				bx += 1
			n = (n - 1) & 0xff
			if n == 0:
				break
		bx += 1
		var idx := rng.random(lists[bx] - 1)
		mon = lists[bx + 1 + idx]
	st.monster = mon
	if mon != 0x27:
		var bx := st.cell_off + 7  # a guardian, once met, stops guarding
		if (st.map.b(bx) & 0x0f) == 0x0f:
			st.map.set_b(bx, st.map.b(bx) & 0xf0)
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11, data.msg(&"bias.14"))
	await _title_flash()
	if sys.unwinding: return
	screen.clear_window(Screen.VIEW)
	var keep := st.color4
	common.set_color4(4)
	st.color4 = keep
	monster_backdrop()
	common.monster_dest = 0x832
	common.show_monster(st.monster)
	await common.wait(0x3a98)
	if sys.unwinding: return
	if st.monster == 0x27:
		screen.clear_window(Screen.MESSAGE)
		common.say(0x12, 0x11, data.msg(&"bias.15"))
		await common.wait(0x7530)
		if sys.unwinding: return
		common.say(0x12, 0x11, data.msg(&"bias.16"))
		await common.wait(0xea60)
		if sys.unwinding: return
	st.mon.hp = st.mon.hp - rng.random(0x14)
	st.hide_hunter = 0
	sys.jump(&"combat")


## the panel behind monsters (from B01)
func monster_backdrop() -> void:
	screen.draw(art.piece("dungeon/backdrop"), BACKDROP)


## another screamer crosses your path
func _meet_hunter() -> void:
	sys.journal(&"hunter", str(st.hunter))
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11, data.msg(&"bias.17"))
	screen.clear_window(Screen.VIEW)
	var keep := st.color4
	common.set_color4(4)
	st.color4 = keep
	monster_backdrop()
	common.monster_dest = 0x832
	common.show_monster(st.hunter + 0x2a)
	screen.clear_window(Screen.MESSAGE)
	st.hide_hunter = 1


## the title logo flashes in negative while the alarm sounds.  (The original's
## "negative" is half garbage from its work buffer: it computes only one byte; here it is the
## title with its colours inverted.)
func _title_flash() -> void:
	if _title_negative == null:
		var img: Image = art.tex("frames/main").get_image().get_region(TITLE)
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(1.0 - c.r, 1.0 - c.g, 1.0 - c.b, 1.0))
		_title_negative = ImageTexture.create_from_image(img)
	var title := AtlasTexture.new()
	title.atlas = art.tex("frames/main")
	title.region = Rect2(TITLE)
	for i in 0x0a:
		screen.sprite(&"title_flash", _title_negative, TITLE.position)
		await common.beep(2, 2, 0x28)
		if sys.unwinding: return
		screen.sprite(&"title_flash", title, TITLE.position)
		await common.beep(2, 2, 0x28)
		if sys.unwinding: return


# ------------------------------------------------------------------ debug keys
# The original's hidden keys (F1..F5, SHIFT, CTRL, BS, TAB with letters) have no actions in the
# input map, so these stay closed; the matrix reads are kept.

func _debug_keys() -> void:
	# F1..F5 + SHIFT + I or W: a taunt for people poking at the cheat keys
	if keys.group(0x0c) == 0x7c and (keys.group(0x0e) & 0x19) == 1:
		var g2 := keys.group(2)
		if g2 == 0x80 or g2 == 2:
			screen.clear_window(Screen.MESSAGE)
			common.say(0x12, 0x11, data.msg(&"bias.18"))
			await common.wait(0x4e20)
			if sys.unwinding: return
			screen.clear_window(Screen.MESSAGE)
	# SHIFT + BS + TAB + I: item number
	if (keys.group(0x0e) & 0x19) == 1 and keys.group(1) == 0xc0 and keys.group(2) == 0x80:
		screen.clear_window(Screen.MESSAGE)
		common.say(0x12, 0x11, data.msg(&"bias.19"))
		var n: int = await ui.number_spin(_debug_item, 0x57)
		if sys.unwinding: return
		if n == 0:
			screen.clear_window(Screen.MESSAGE)
		else:
			_debug_item = n
			if st.chr.inv_full != 0:
				screen.clear_window(Screen.MESSAGE)
				common.say(0x12, 0x11, data.msg(&"bias.20"))
				await ui.wait_space()
				if sys.unwinding: return
			else:
				st.chr.inv_add(n)
				screen.clear_window(Screen.MESSAGE)
				txt.kana_mode = 0
				txt.puts(chara.item_name(n))
				txt.puts(data.msg(&"bias.21"))
				await ui.wait_space()
				if sys.unwinding: return
	# SHIFT + CTRL + HELP + W: warp
	if (keys.group(0x0e) & 0x19) == 0x11 and keys.group(7) == 0x80 and keys.group(2) == 2:
		screen.clear_window(Screen.MESSAGE)
		common.say(0x12, 0x11, data.msg(&"bias.22"))
		var f: int = await ui.number_spin(st.floor, 6)
		if sys.unwinding: return
		if not f:
			screen.clear_window(Screen.MESSAGE)
			return
		st.floor = f
		txt.puts(data.msg(&"bias.23"))
		var x: int = await ui.number_spin(st.pos_x + 1, 0x16)
		if sys.unwinding: return
		if not x:
			screen.clear_window(Screen.MESSAGE)
			return
		st.pos_x = x - 1
		txt.puts(data.msg(&"bias.24"))
		var y: int = await ui.number_spin(st.pos_y + 1, 0x16)
		if sys.unwinding: return
		if not y:
			screen.clear_window(Screen.MESSAGE)
			return
		st.pos_y = y - 1
		await ui.wait_space()
		if sys.unwinding: return
		randomize_doors()
		lights_off()
		render_view()
		look_ahead()
		lights_on()

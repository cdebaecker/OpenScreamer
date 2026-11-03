## Things that happen when you step on a cell: traps, stairs, elevators, the exit door...
## The original's effects shovel VRAM around as fast as the CPU allows; here they move nodes, and
## cpu() charges the time the original took for each step so they play at the original pace.
class_name Events
extends Mod

## the view window (lines 24..127)
const VIEW_RECT := Rect2i(144, 24, 320, 104)

var _cpu_frac := 0.0
var _events: Array[Callable] = []
# road defender / ring: the two door halves and the robot's window (lifted regions)
var _door_left: Control
var _door_right: Control
var _robot: Control


## time for the original to shovel `bytes` bytes around in VRAM (8 MHz V30, ~10 clocks/byte);
## the fraction of a microsecond is carried to the next call
func cpu(bytes: int) -> void:
	_cpu_frac += bytes * 1.2
	var us := int(_cpu_frac)
	_cpu_frac -= us
	await sys.advance(us)


## the event of the current cell (1..12h); may jump (callers check sys.unwinding)
func run_event(ev: int) -> void:
	if ev == 0 or ev >= 0x13:
		return
	if _events.is_empty():
		_events = [
			_spinner,  # 1
			_noise,  # 2
			_pit,  # 3
			_pit_down,  # 4
			_thunder_road,  # 5
			_fire_road,  # 6
			_stairs_up,  # 7
			_stairs_down,  # 8
			_elevator_up,  # 9
			_elevator_down,  # 0A
			_road_defender,  # 0B
			_poison_fog.bind(1),  # 0C
			_poison_fog.bind(2),  # 0D
			_poison_fog.bind(4),  # 0E
			_poison_fog.bind(8),  # 0F
			_tower_exit,  # 10
			_debris,  # 11
			_ring,  # 12
		]
	await _events[ev - 1].call()


func _trap_once() -> bool:
	if st.trap_done != 0:
		return false
	st.trap_done = 1
	return true


func _tell(s: String) -> void:
	common.say(0x12, 0x11, s)


# ------------------------------------------------------------------ effects

## a clipping container over `rect`, on top of the board
func _clip(rect: Rect2i) -> Control:
	var c := Control.new()
	c.position = rect.position
	c.size = rect.size
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.images.add_child(c)
	return c


## Black out `rect` and return a clipping container holding copies of what was shown there, so
## that part of the picture can be moved on its own (the originals stay under the black).
func _lift(rect: Rect2i) -> Control:
	var under := screen.nodes_in(rect)
	var cover := ColorRect.new()
	cover.position = rect.position
	cover.size = rect.size
	cover.color = Color.BLACK
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.images.add_child(cover)
	var c := _clip(rect)
	c.set_meta("cover", cover)
	for n in under:
		var d: Control = n.duplicate()
		d.position = n.position - Vector2(rect.position)
		c.add_child(d)
	return c


## put a lifted region down: the originals show again
func _drop(group: Control) -> void:
	if group != null and is_instance_valid(group):
		_free(group.get_meta("cover"))
	_free(group)


func _shift(group: Control, dx: int, dy: int) -> void:
	for n in group.get_children():
		n.position += Vector2(dx, dy)


func _node(tex: Texture2D, pos: Vector2i) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.position = pos
	r.size = tex.get_size()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _free(n: Node) -> void:
	if n != null and is_instance_valid(n):
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.queue_free()


# ------------------------------------------------------------------ 1: rotating floor

func _spinner() -> void:
	if not _trap_once():
		return
	var al := rng.random(1) * 2 + 1
	st.facing = (al + st.facing) & 3
	dungeon.lights_off()
	dungeon.render_view()
	dungeon.look_ahead()


# ------------------------------------------------------------------ 2: noise

func _noise() -> void:
	if not _trap_once():
		return
	await common.beep(2, 2, 0x2000)
	chara.adjust_stat(0, -1)
	if sys.unwinding: return
	_tell(data.msg(&"event.01"))
	await ui.wait_space()


# ------------------------------------------------------------------ 3: pit and 4: pit to the floor below

## the view slides up as you fall, the pit coming up from below,
## four lines per step; returns the moved view
func _fall_animation() -> Control:
	var group := _lift(VIEW_RECT)
	group.add_child(_node(art.piece("events/pit"), Vector2i(0, VIEW_RECT.size.y)))
	for f in 0x1a:
		_shift(group, 0, -4)
		await cpu(0x64 * 0x28 + 4 * 0x28)
	return group


## the view in the window scrolls down, one line per step, while `incoming`
## (a container of nodes, or null for black) comes in from the top
func _view_scrolls_down(incoming: Control) -> void:
	var group := _lift(VIEW_RECT)
	if incoming != null:
		for n in incoming.get_children():
			var d: Control = n.duplicate()
			d.position.y -= VIEW_RECT.size.y
			group.add_child(d)
	for n in 0x68:
		_shift(group, 0, 1)
		await cpu(0x67 * 0x28)


func _pit() -> void:
	if st.trap_done != 0:
		return
	st.trap_done = 1
	dungeon.lights_off()
	_tell(data.msg(&"event.02"))
	# the view before the fall: the same cell is built again when climbing out
	var before := screen.nodes_in(VIEW_RECT)
	var view := Control.new()
	for n in before:
		var d: Control = n.duplicate()
		d.position = n.position - Vector2(VIEW_RECT.position)
		view.add_child(d)
	await _fall_animation()
	chara.adjust_stat(0, -1)
	if sys.unwinding:
		view.free()
		return
	# stuck in the pit until numpad 5, or until a command is used: the original falls through from
	# the command into the climb out; fixed, you stay in the pit
	while true:
		await sys.advance(Dungeon.IDLE_ITERATION_US)
		if ui.numpad() == 5:
			break
		var sel: int = await ui.menu_poll()
		if sys.unwinding:
			view.free()
			return
		if sel:
			await dungeon.run_command(sel)
			if sys.unwinding:
				view.free()
				return
			if not sys.fix_bugs:
				break
	screen.clear_window(Screen.MESSAGE)
	dungeon.build_view()
	await _view_scrolls_down(view)
	view.free()
	_tell(data.msg(&"event.03"))
	await ui.wait_space()


func _pit_down() -> void:
	_tell(data.msg(&"event.04"))
	await _fall_animation()
	st.floor = (st.floor - 1) & 0xff
	dungeon.randomize_doors()
	screen.clear_window(Screen.MESSAGE)
	screen.clear_window(Screen.VIEW)
	common.show_picture(0x0f)
	await common.wait(0x4e20)
	screen.clear_window(Screen.VIEW)
	chara.adjust_stat(0, -2)
	if sys.unwinding: return
	sys.jump(&"dungeon_loop")


# ------------------------------------------------------------------ 5: thunder road

func _thunder_road() -> void:
	if not _trap_once():
		return
	_tell(data.msg(&"event.05"))
	for i in 0x10:
		var bolt: Control = await _bolt()
		await common.wait(0x32)
		await _unbolt(bolt)
		await common.wait(0xc8)
	chara.adjust_stat(0, -2)
	if sys.unwinding: return
	screen.clear_window(Screen.MESSAGE)
	_tell(data.msg(&"event.06"))
	await ui.wait_space()


## a widening wedge in red, three lines per step from (256, 86)
func _bolt() -> Control:
	var group := Control.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.images.add_child(group)
	var x := 32
	var w := 0x0b
	for step in 0x0e:
		var r := ColorRect.new()
		r.color = Screen.COLOURS[Screen.RED]
		r.position = Vector2(x * 8, 86 + step * 3)
		r.size = Vector2(w * 8, 3)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(r)
		await common.beep(1, 1, 1)
		x -= 1
		w += 2
	return group


## the bolt in black: the wedge goes again, step by step
func _unbolt(group: Control) -> void:
	for r in group.get_children():
		r.visible = false
		await common.beep(1, 1, 1)
	_free(group)


# ------------------------------------------------------------------ 6: fire road

func _fire_road() -> void:
	if not _trap_once():
		return
	var fire: Array[Node] = []
	# the flames grow three times
	var rows := 0x0a
	var at := 0x2457
	for n in 3:
		fire.append(_flames(at, rows))
		await common.wait(0x1f4)
		fire.append(_flame_tops(at))
		await common.wait(0x1f4)
		rows += 0x0b
		at = (at - 0x370) & 0xffff
		_shift_flames(fire)
		await common.wait(0x1f4)
	await common.wait(0x1f4)
	await common.wait(0x1f4)
	_shift_flames(fire)
	chara.adjust_stat(0, -1)
	if sys.unwinding: return
	_tell(data.msg(&"event.07"))
	await ui.wait_space()


## the top `rows` lines of the flames (from B02, red) at VRAM offset `at`
func _flames(at: int, rows: int) -> Node:
	var a := AtlasTexture.new()
	a.atlas = art.piece("events/fire")
	a.region = Rect2(0, 0, 0x1e * 8, rows)
	return screen.draw(a, Screen.px(at), false)


## flame tongues 40 lines higher
func _flame_tops(at: int) -> Node:
	return screen.draw(art.piece("events/fire_top"), Screen.px((at + 0xf380) & 0xffff), false)


## the original smears the line above the flames down over them, which clears them
func _shift_flames(fire: Array[Node]) -> void:
	for n in fire:
		_free(n)
	fire.clear()


# ------------------------------------------------------------------ 7/8: stairs

func _stairs_up() -> void:
	if st.stood != 0:
		return
	st.stood = 1
	_tell(data.msg(&"event.08"))
	var yes: bool = await ui.yes_no()
	if not yes:
		return
	st.floor = (st.floor + 1) & 0xff
	dungeon.randomize_doors()
	screen.clear_window(Screen.MESSAGE)
	# the stairs replace the view, then scroll down out of the window
	var stairs := _lift(VIEW_RECT)
	for n in stairs.get_children():
		_free(n)
	stairs.add_child(_node(art.piece("events/stairs"), Vector2i.ZERO))
	dungeon.build_view()
	await _view_scrolls_down(null)  # the new view is drawn when the BIAS loop starts again
	sys.jump(&"dungeon_loop")


func _stairs_down() -> void:
	if st.stood != 0:
		return
	st.stood = 1
	_tell(data.msg(&"event.09"))
	var yes: bool = await ui.yes_no()
	if not yes:
		return
	st.floor = (st.floor - 1) & 0xff
	dungeon.randomize_doors()
	screen.clear_window(Screen.MESSAGE)
	# the view scrolls up out of the window, the stairs coming in from below
	var group := _lift(VIEW_RECT)
	group.add_child(_node(art.piece("events/stairs"), Vector2i(0, VIEW_RECT.size.y)))
	for n in 0x68:
		_shift(group, 0, -1)
		await cpu(0x67 * 0x28)
	sys.jump(&"dungeon_loop")


# ------------------------------------------------------------------ 9/A: elevators

## the shaft (events/elevator, 240 x 80) runs past the middle of the view `times` times
func _elevator_ride(times: int, dir: int) -> void:
	var rect := Rect2i(184, 36, 240, 80)
	var group := _lift(rect)
	for t in times:
		group.add_child(_node(art.piece("events/elevator"), Vector2i(0, -dir * rect.size.y)))
		for n in 0x50:
			_shift(group, 0, dir)
			await cpu(0x4f * 0x1e)


func _elevator_up() -> void:
	if st.stood != 0:
		return
	st.stood = 1
	_tell(data.msg(&"event.10"))
	var yes: bool = await ui.yes_no()
	if not yes:
		return
	var times: int
	if st.floor == 2:
		st.floor = 4
		times = 2
	else:
		st.floor = 5
		times = 4
	dungeon.randomize_doors()
	await _elevator_ride(times, 1)
	sys.jump(&"dungeon_loop")


func _elevator_down() -> void:
	if st.stood != 0:
		return
	st.stood = 1
	_tell(data.msg(&"event.11"))
	var yes: bool = await ui.yes_no()
	if not yes:
		return
	var times: int
	if st.floor == 4:
		st.floor = 2
		times = 2
	else:
		st.floor = 1
		times = 4
	dungeon.randomize_doors()
	await _elevator_ride(times, -1)
	sys.jump(&"dungeon_loop")


# ------------------------------------------------------------------ B: road defender and 12h: ring

## the door in front parts, its halves sliding out sideways (lines 48..115)
func _robot_door_opens() -> void:
	_door_left = _lift(Rect2i(208, 48, 96, 68))
	_door_right = _lift(Rect2i(304, 48, 104, 68))
	for n in 0x0b:
		_shift(_door_left, -8, 0)
		_shift(_door_right, 8, 0)
		await cpu(0x44 * 0x1c)
	_shift(_door_left, -8, 0)
	_shift(_door_right, 16, 0)


## the door closes again, the original picture coming back
func _robot_door_closes() -> void:
	_drop(_robot)
	_shift(_door_left, 8, 0)
	_shift(_door_right, -16, 0)
	for n in 0x0b:
		_shift(_door_left, 8, 0)
		_shift(_door_right, -8, 0)
		await cpu(0x44 * 0x1c)
	_drop(_door_left)
	_drop(_door_right)


## the robot (B03: red plane, then green), 112 x 54, on black
func _robot_texture() -> Texture2D:
	var r: Image = art.piece("events/robot_r").get_image()
	var g: Image = art.piece("events/robot_g").get_image()
	r.convert(Image.FORMAT_RGBA8)
	g.convert(Image.FORMAT_RGBA8)
	var img := Image.create_empty(r.get_width(), r.get_height(), false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := (2 if r.get_pixel(x, y).a > 0.5 else 0) | (4 if g.get_pixel(x, y).a > 0.5 else 0)
			img.set_pixel(x, y, Screen.COLOURS[c])
	return ImageTexture.create_from_image(img)


## the robot rises into the doorway, one line per step
func _robot_rises() -> void:
	var rect := Rect2i(248, 62, 112, 54)
	_robot = _lift(rect)
	_robot.add_child(_node(_robot_texture(), Vector2i(0, rect.size.y)))
	for n in 0x36:
		_shift(_robot, 0, -1)
		await cpu(2 * 0x35 * 0x0e)


## ...and sinks back
func _robot_sinks() -> void:
	for n in 0x36:
		_shift(_robot, 0, 1)
		await cpu(2 * 0x35 * 0x0e)


func _robot_flash() -> void:
	for i in 5:
		screen.graphics_visible = false
		await common.beep(0x3e8, 1, 1)
		screen.graphics_visible = true
		await common.wait(0x3e8)


func _road_defender() -> void:
	if not (st.cell[st.facing & 3] & 0x20):
		return
	if not _trap_once():
		return
	await _robot_door_opens()
	await common.wait(0x3e8)
	await _robot_rises()
	await _robot_flash()
	await common.wait(0x7d0)
	chara.adjust_stat(0, -3)
	if sys.unwinding: return
	_tell(data.msg(&"event.12"))
	await common.wait(0x2710)
	screen.clear_window(Screen.MESSAGE)
	await _robot_sinks()
	await _robot_door_closes()


func _ring() -> void:
	if not (st.cell[st.facing & 3] & 0x20):
		return
	st.hide_hunter = 1
	st.ring_flag = 1
	st.door_unlocked = 1
	await _robot_door_opens()
	await _robot_rises()
	await common.wait(0x1388)
	screen.clear_window(Screen.MESSAGE)
	_tell(data.msg(&"event.13"))
	await ui.wait_space()


# ------------------------------------------------------------------ 12 to 15: poison fog

func _poison_fog(kind: int) -> void:
	if st.trap_done != 0:
		return
	st.trap_done = 1
	st.chr.poison |= kind
	st.hide_hunter = 1
	st.ring_flag = 1
	await _fog()
	screen.clear_window(Screen.MESSAGE)
	_tell(data.msg(&"event.14"))
	await ui.wait_space()


## blue fog (events/fog, 8 bytes a line) rolls over the view from the left, 64 pixels a
## pass, hiding the walls under it.  Each pass gives every line a new piece of fog at the left
## and pushes the older ones right; the lines are visited 8 apart (rows of 13 text lines).
func _fog() -> void:
	var fog: Image = art.piece("events/fog").get_image()
	fog.convert(Image.FORMAT_RGBA8)
	var node: TextureRect = null
	for p in 5:
		var img := Image.create_empty(VIEW_RECT.size.x, VIEW_RECT.size.y, false, Image.FORMAT_RGBA8)
		var k := 0
		for line in 8:
			for r in 0x0d:
				var y := line + 8 * r
				for j in p + 1:
					var chunk := ((p - j) * 0x68 + k) % 0xff
					img.blit_rect(fog, Rect2i(0, chunk, 64, 1), Vector2i(64 * j, y))
				k += 1
		_free(node)
		node = screen.draw(ImageTexture.create_from_image(img), VIEW_RECT.position, false)
		await cpu(0x68 * 0x60)


# ------------------------------------------------------------------ 10h: the tower exit

func _tower_exit() -> void:
	if not (st.cell[st.facing & 3] & 0x20):
		return
	if st.door_msg != 0:
		return
	st.door_msg = 1
	screen.clear_window(Screen.MESSAGE)
	txt.kana_mode = 0xff
	txt.at(0x13, 0x11, 0x13)
	await common.blip()
	txt.puts(data.msg(&"event.15"))
	var yes: bool = await ui.yes_no()
	if not yes:
		return
	screen.clear_window(Screen.VIEW)
	common.show_picture(1)
	common.set_color4(4)
	await common.wait(0x7530)
	sys.jump(&"town")


# ------------------------------------------------------------------ 11h: flying debris

func _debris() -> void:
	if rng.random(0xff) >= 0x32:
		return
	if not _trap_once():
		return
	await common.beep(0x64, 0x0a, 0x46)
	chara.adjust_stat(0, -5)
	if sys.unwinding: return
	screen.clear_window(Screen.MESSAGE)
	_tell(data.msg(&"event.16"))
	await ui.wait_space()

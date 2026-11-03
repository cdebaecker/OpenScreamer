## DEMO2HDE.EXE: the attract sequence run before the game (AUTOEXEC: demo2hde, main2hde).
class_name Demo
extends Mod

## time of one key poll of the demo's wait loop (a pause runs 640 of them)
const SENSE_US := 60
const POLLS := 0x280  # [8] on an 8 MHz machine

## SPACE pressed: the whole demo ends (callers return as soon as they see it)
var _skip := false
var _cpu_frac := 0.0
## where portraits go (the demo's, a VRAM offset)
var _monster_dest := 0


## a short pause; SPACE ends the whole demo
func _pause() -> void:
	for i in POLLS:
		var k := keys.peek()
		if k >= 0:
			keys.take()
			if k == Keys.K_SPACE:
				_skip = true
				return
		await sys.advance(SENSE_US)


func _pauses(n: int) -> void:
	for i in n:
		await _pause()
		if _skip:
			return


## typewriter print of one of the demo's strings
func _print(off: int) -> void:
	txt.hi_mode = 0
	txt.kana_mode = 0
	var s: String = data.demo_strings["0x%x" % off]
	for ch in GameText.encode(data.translate_demo(s)):
		if ch == 0x7b or ch == 0x7d:
			txt.kana_mode ^= 0xff
		elif ch == 0x7c:
			txt.hi_mode ^= 0xff
		elif (ch == 0x5f and txt.hi_mode == 0) or ch == 0x7e:
			txt.put_char(0x20)
			txt.put_char(0x0d)
		else:
			txt.put_char(ch)
			txt.put_char(0x01)
			await _pause()
			if _skip:
				return
			txt.col -= 1
	txt.put_char(0x20)


## portrait Gnn
func _monster(n: int, dest: int = -1) -> void:
	if dest >= 0:
		_monster_dest = dest
	screen.draw(art.monster(n), Screen.px(_monster_dest))


## scene picture Pnn at
func _picture(n: int) -> void:
	screen.draw(art.picture(n), Screen.px(0x832))


## the time the original spends shovelling `bytes` bytes of VRAM (~1.2 us each)
func _cpu(bytes: int) -> void:
	_cpu_frac += bytes * 1.2
	var us := int(_cpu_frac)
	_cpu_frac -= us
	await sys.advance(us)


## the title opens from the middle of the screen while the collage parts, its top
## half scrolling up and its bottom half down, one line per step
func _title_reveal() -> void:
	var top := _clip(Rect2i(0, 0, 640, 100))
	var bottom := _clip(Rect2i(0, 100, 640, 100))
	for n in screen.nodes_in(Rect2i(0, 0, 640, 200)):
		for half in [top, bottom]:
			var d: Control = n.duplicate()
			d.position = n.position - half.position
			half.add_child(d)
		screen.images.remove_child(n)
		n.queue_free()
	var title := TextureRect.new()
	title.texture = art.tex("title")
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.size = Vector2(640, 200)  # stored at half height, each line shown twice
	var middle := _clip(Rect2i(0, 100, 640, 0))
	middle.add_child(title)
	var a := 0x63
	var b := 0x64
	while a != 0:
		# lines 1..a move up by one, lines b..199 move down by one, title lines a and b appear
		top.size.y = a
		for c in top.get_children():
			c.position.y -= 1
		bottom.position.y = b + 1  # the clip edge and its contents go down together
		bottom.size.y = 199 - b
		middle.position.y = a
		middle.size.y = b - a + 1
		title.position.y = -a
		await _cpu((a + 0xc7 - b) * 0x50 * 3)
		b += 1
		a -= 1
	screen.clear_screen()
	screen.draw(_title_texture(), Vector2i.ZERO)


func _clip(rect: Rect2i) -> Control:
	var c := Control.new()
	c.position = rect.position
	c.size = rect.size
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.images.add_child(c)
	return c


## the title at full height, as one texture
func _title_texture() -> Texture2D:
	var img: Image = art.tex("title").get_image()
	img.resize(640, 200, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func run() -> void:
	txt.colour = 7
	_skip = false
	await _run()


func _run() -> void:
	var profiles := [
		[0x2b, 0x0c, 0x34],
		[0x2c, 0x75, 0x35],
		[0x2d, 0xde, 0x36],
		[0x2e, 0x147, 0x37],
		[0x2f, 0x1b0, 0x38],
		[0x30, 0x219, 0x39],
		[0x31, 0x282, 0x3a],
		[0x32, 0x2eb, 0x3b],
	]
	screen.clear_screen()
	txt.at(0x10, 0x11)
	await _print(0x3e7)
	if _skip:
		return
	_monster_dest = 0x832
	for pr in profiles:
		_monster(pr[0])
		txt.at(0x28, 5)
		await _print(pr[1])
		if _skip:
			return
		await _pauses(0x20)
		if _skip:
			return
		_monster(pr[2])
		await _pauses(0x20)
		if _skip:
			return
	screen.clear_screen()
	txt.at(0x18, 0x0a)
	await _print(0x3b5)
	if _skip:
		return
	await _pauses(0x20)
	if _skip:
		return
	for pic in [0x0b, 0x0c, 0x0d]:
		_picture(pic)
		await _pauses(0x20)
		if _skip:
			return
	screen.clear_screen()
	txt.at(0x12, 0x14)
	await _print(0x3c2)
	if _skip:
		return
	await _pauses(0x20)
	if _skip:
		return
	_monster(0x3c)
	txt.at(0x28, 5)
	await _print(0x354)
	if _skip:
		return
	await _pauses(0x20)
	if _skip:
		return
	screen.clear_screen()
	var collage := [
		[0x35, 0x14], [0x3a, 0x1f68], [0x38, 0x1f40], [0x37, 0x3c],
		[0x34, 0], [0x3b, 0x1f7c], [0x39, 0x1f54], [0x36, 0x28],
	]
	for c in collage:
		_monster(c[0], c[1])
	await _pauses(0x20)
	if _skip:
		return
	await _title_reveal()

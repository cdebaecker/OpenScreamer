## The game's text: 80 x 25 cells of 8 x 8 pixels drawn with the original font
## (imported from the player's disk, 256 glyphs).  Each cell holds a glyph code and a colour index; a
## white cell also blacks out what is under it, like the original writing all three planes.
class_name TextLayer
extends Control

const COLS := 80
const ROWS := 25

var _glyph := PackedInt32Array()  # glyph code + 1, 0 = empty
var _colour := PackedByteArray()
var _font: Texture2D
## bumped on every change (ModernText redraws when it moves)
var version := 0
## the modern font draws the glyphs it has (ModernText); this layer keeps the others and the
## black behind white text
var modern := false:
	set(v):
		modern = v
		queue_redraw()


func _init() -> void:
	_glyph.resize(COLS * ROWS)
	_colour.resize(COLS * ROWS)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var img := Import.image("font")
	if img != null:
		_font = ImageTexture.create_from_image(img)
	queue_redraw()


func put(col: int, row: int, glyph: int, colour: int) -> void:
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return
	_glyph[row * COLS + col] = (glyph & 0xff) + 1
	_colour[row * COLS + col] = colour & 7
	_changed()


## glyph code at a cell, -1 if empty
func glyph_at(col: int, row: int) -> int:
	return _glyph[row * COLS + col] - 1


## remove the text in cells fully inside a pixel rectangle
func clear(rect: Rect2i) -> void:
	var c0 := ceili(rect.position.x / 8.0)
	var r0 := ceili(rect.position.y / 8.0)
	var c1 := rect.end.x / 8
	var r1 := rect.end.y / 8
	var changed := false
	for row in range(maxi(r0, 0), mini(r1, ROWS)):
		for col in range(maxi(c0, 0), mini(c1, COLS)):
			if _glyph[row * COLS + col] != 0:
				_glyph[row * COLS + col] = 0
				changed = true
	if changed:
		_changed()


func clear_all() -> void:
	_glyph.fill(0)
	_changed()


## change the colour of n cells from (col, row)
func recolour(col: int, row: int, n: int, colour: int) -> void:
	for i in n:
		if col + i < COLS:
			_colour[row * COLS + col + i] = colour & 7
	_changed()


func _changed() -> void:
	version += 1
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	for i in COLS * ROWS:
		var g := _glyph[i] - 1
		if g < 0:
			continue
		var pos := Vector2((i % COLS) * 8, (i / COLS) * 8)
		var c := _colour[i]
		if c == 7:
			draw_rect(Rect2(pos, Vector2(8, 8)), Color.BLACK)
		if modern and ModernText.has(g):
			continue
		draw_texture_rect_region(_font, Rect2(pos, Vector2(8, 8)), Rect2((g % 16) * 8, (g / 16) * 8, 8, 8),
				Screen.COLOURS[c])

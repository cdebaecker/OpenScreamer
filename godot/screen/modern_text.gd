## The "modern" font option: draws the text layer's letters, digits, kana and kanji with a smooth
## font (Noto Sans JP, assets/fonts) at the displayed size (8 x 16 per cell) instead of the
## original's 8 x 8 bitmap glyphs.  Glyphs with no font equivalent (box drawing, blocks, the
## cursor, the arrow) stay bitmaps, drawn by the TextLayer.  Presentation only: the text layer's
## cells and the game don't change.
class_name ModernText
extends Control

const FONT_PATH := "res://assets/fonts/NotoSansJP-Medium-subset.ttf"
const SIZE := 14
const BASELINE := 13  # from the top of a 16-pixel cell
## drawn at twice the display's size (its own viewport, composited by the display shader), so it
## stays sharp in a bigger window
const ZOOM := 2
## large text: a bigger size, squeezed into the cells
var large := false:
	set(v):
		large = v
		queue_redraw()

## glyph code -> character, for the glyphs the font draws (the imported font)
static var CHARS := _chars()

var text: TextLayer
var screen: Screen
var font: Font

var _seen_text := -1
var _seen_palette := -1


static func _chars() -> Dictionary:
	var m := {}
	var kanji := "水木金土日年円時分秒百千万"
	for i in kanji.length():
		m[0x03 + i] = kanji[i]
	m[0x10] = "π"
	m[0x1d] = "大"
	m[0x1e] = "中"
	m[0x1f] = "小"
	for c in range(0x21, 0x7f):
		if c != 0x60:  # 60h is a checker block in this font
			m[c] = String.chr(c)
	m[0x5c] = "¥"
	m[0x7c] = "¦"
	var suits := "♠♥♣♦○・"
	for i in suits.length():
		m[0x80 + i] = suits[i]
	var hira := "をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそ"
	for i in hira.length():
		m[0x86 + i] = hira[i]
	for c in range(0xa1, 0xe0):
		m[c] = String.chr(c - 0xa1 + 0xff61)
	hira = "たちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん"
	for i in hira.length():
		m[0xe0 + i] = hira[i]
	for i in Accents.CHARS.length():  # the translations' accented letters
		m[Accents.FIRST + i] = Accents.CHARS[i]
	return m


static func has(glyph: int) -> bool:
	return CHARS.has(glyph)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 400) * ZOOM


func _ready() -> void:
	font = load(FONT_PATH)


func _process(_delta: float) -> void:
	if text == null or screen == null:
		return
	if text.version != _seen_text or screen.palette_version != _seen_palette:
		_seen_text = text.version
		_seen_palette = screen.palette_version
		queue_redraw()


func _draw() -> void:
	if text == null or screen == null or font == null or not screen.graphics_visible:
		return
	var fs := (17 if large else SIZE) * ZOOM
	var cw := 8.0 * ZOOM
	var base := float((15 if large else BASELINE) * ZOOM)
	for i in TextLayer.COLS * TextLayer.ROWS:
		var g := text._glyph[i] - 1
		if g < 0 or not CHARS.has(g):
			continue
		var ch: String = CHARS[g]
		var cp := ch.unicode_at(0)
		var colour := screen.display_colour(text._colour[i])
		var x := float(i % TextLayer.COLS) * cw
		var y := float(i / TextLayer.COLS) * 16.0 * ZOOM + base
		var w := font.get_char_size(cp, fs).x
		if w <= cw + 1.0:
			draw_char(font, Vector2(x + (cw - w) / 2.0, y), ch, fs, colour)
		else:  # wide (kanji, hiragana; large text): squeezed into the cell
			draw_set_transform(Vector2(x, y), 0.0, Vector2(cw / w, 1.0))
			draw_char(font, Vector2.ZERO, ch, fs, colour)
			draw_set_transform(Vector2.ZERO)

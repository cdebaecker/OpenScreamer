## Accented letters for the translations (French...). The game's 8 x 8 font has none: these glyphs are
## made at run time from the font's own lowercase letters, with an accent drawn in the empty rows above
## them (a cedilla below). They get glyph codes from 100h, which the original never uses, and only
## translated text is printed with them (in the original's text, codes 80h..FFh are other glyphs).
## Capitals keep their plain glyph: the font's capitals fill their cell.
class_name Accents
extends RefCounted

const FIRST := 0x100
## the letters, their base letter, and their mark
const CHARS := "àâäéèêëîïôöùûüÿç"
const BASES := "aaaeeeeiioouuuyc"
const MARKS := "`^:'`^:^:^:`^::,"
## each mark: [row, pattern] lines of 8 dots (high bit leftmost)
const SHAPES := {
	"'": [[0, 0b00001100], [1, 0b00011000]],
	"`": [[0, 0b00110000], [1, 0b00011000]],
	"^": [[0, 0b00011000], [1, 0b00100100]],
	":": [[1, 0b01100110]],
	",": [[7, 0b00011000]],
}
## accented capitals and other letters, shown as the font can (the game's capitals have no room)
const FOLD := {"À": "A", "Â": "A", "Ä": "A", "Ç": "C", "É": "E", "È": "E", "Ê": "E", "Ë": "E", "Î": "I",
	"Ï": "I", "Ô": "O", "Ö": "O", "Ù": "U", "Û": "U", "Ü": "U", "Ÿ": "Y", "œ": "oe", "Œ": "OE", "æ": "ae",
	"Æ": "AE"}


## the glyph code of an accented letter, or -1
static func code(c: String) -> int:
	var i := CHARS.find(c)
	return FIRST + i if i >= 0 else -1


## the character of an accent glyph code ("" if it isn't one)
static func char_of(glyph: int) -> String:
	var i := glyph - FIRST
	return CHARS[i] if i >= 0 and i < CHARS.length() else ""


## the font picture (16 x 16 glyphs of 8 x 8, white on transparent) with a row of accented letters
## added below it (glyph codes 100h..10Fh)
static func extend_font(font: Image) -> Image:
	var img := Image.create_empty(128, 136, false, Image.FORMAT_RGBA8)
	img.blit_rect(font, Rect2i(0, 0, 128, 128), Vector2i.ZERO)
	for i in CHARS.length():
		var base := BASES.unicode_at(i)
		var sx := (base % 16) * 8
		var sy := (base / 16) * 8
		var dx := (i % 16) * 8
		var dy := 128 + (i / 16) * 8
		img.blit_rect(font, Rect2i(sx, sy, 8, 8), Vector2i(dx, dy))
		var mark := MARKS[i]
		if BASES[i] == "i":  # the dot of the i gives way to the accent
			for x in 8:
				img.set_pixel(dx + x, dy, Color(0, 0, 0, 0))
		for line: Array in SHAPES[mark]:
			for x in 8:
				if int(line[1]) & (0x80 >> x):
					img.set_pixel(dx + x, dy + int(line[0]), Color.WHITE)
	return img

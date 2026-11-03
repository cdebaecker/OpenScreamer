## Text output with the original's markup, onto the screen's text layer:
##   _ ~  new line ('_' is printed as is in | mode)     { }  switch katakana <-> hiragana glyphs
##   |    switch to the alternate glyph set (bit 7)      #    the number set with set_number()
## Strings are Unicode; the font has the original's 256 glyphs, so characters are turned into
## glyph codes: ASCII and U+0080..00FF as is, half-width katakana U+FF61..FF9F as A1..DF.
class_name GameText
extends Mod

var row := 0
var col := 0
var margin := 0
## 0xFF: katakana are printed with the hiragana glyphs (toggled by '{' and '}')
var kana_mode := 0xff
## toggled by '|': glyphs with bit 7 set, '_' and '#' printed as is
var hi_mode := 0
## text colour (the original's plane mask: 1 B, 2 R, 4 G)
var colour := 7
# the number printed for '#': hi:lo (24 bits) and its format (0 plain, 1 five columns, 2 eight)
var num_hi := 0
var num_lo := 0
var num_format := 0


static func encode(s: String) -> PackedByteArray:
	var out := PackedByteArray()
	for i in s.length():
		var c := s.unicode_at(i)
		if c <= 0xff:
			out.append(c)
		elif c >= 0xff61 and c <= 0xff9f:
			out.append(c - 0xff61 + 0xa1)
		else:
			push_error("no glyph for %s in %s" % [s[i], s])
	return out


## the glyph codes to print for a string: as encode(), but a translation's accented letters get
## their own glyphs (Accents); the original's text never does (its 80h..FFh are other glyphs)
static func glyphs(s: String, translated: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in s.length():
		var c := s.unicode_at(i)
		var a := Accents.code(s[i]) if translated and c > 0x7f else -1
		if a >= 0:
			out.append(a)
		elif c <= 0xff:
			out.append(c)
		elif c >= 0xff61 and c <= 0xff9f:
			out.append(c - 0xff61 + 0xa1)
		else:
			push_error("no glyph for %s in %s" % [s[i], s])
	return out


## what to print for an original string: its translation (with accents) or itself
func _shown(s: String) -> PackedInt32Array:
	var t := data.translate(s)
	return glyphs(t, t != s)


static func decode(b: PackedByteArray) -> String:
	var s := ""
	for c in b:
		s += String.chr(c - 0xa1 + 0xff61 if c >= 0xa1 and c <= 0xdf else c)
	return s


## cursor at (col, row); the left margin for new lines defaults to col
func at(c: int, r: int, m: int = -1) -> void:
	col = c & 0xff
	row = r & 0xff
	margin = col if m < 0 else m & 0xff


## the glyph for a character code, applying the '|' and '{}' modes
func _glyph(ch: int) -> int:
	if ch >= Accents.FIRST:
		return ch
	if hi_mode != 0 and ch != 0x20:
		ch |= 0x80
	if kana_mode != 0 and ch >= 0xa5:
		if ch < 0xc0:
			ch -= 0x20
		elif ch < 0xde:
			ch += 0x20
	return ch & 0xff


## put one character code (0x0D new line, 0x08 backspace)
func put_char(ch: int) -> void:
	if ch == 0x0d:
		row = (row + 1) & 0xff
		col = margin
		return
	if ch == 0x08:
		col = (col - 1) & 0xff
		put_char(0x20)
		col = (col - 1) & 0xff
		return
	screen.text.put(col, row, _glyph(ch), colour)
	col = (col + 1) & 0xff


func _end_string() -> void:
	hi_mode = 0
	kana_mode = 0xff


## print a string with the game's markup (translated when playing in English)
func puts(s: String) -> void:
	for ch in _shown(s):
		if ch == 0:
			break
		match ch:
			0x5f:  # '_'
				put_char(ch if hi_mode != 0 else 0x0d)
			0x7e:  # '~'
				put_char(0x0d)
			0x7b, 0x7d:  # '{' '}'
				kana_mode ^= 0xff
			0x7c:  # '|'
				hi_mode ^= 0xff
			0x23:  # '#'
				if hi_mode != 0:
					put_char(ch)
				else:
					print_number(num_hi, num_lo)
			_:
				put_char(ch)
	_end_string()


## print a string raw (no markup, katakana kept), e.g. names
func print_raw(s: String) -> void:
	kana_mode = 0
	hi_mode = 0
	for ch in _shown(s):
		put_char(ch)


func _slow_char(c: int) -> void:
	put_char(c)
	put_char(0x01)  # the block cursor
	await sys.delay(300)
	col = (col - 1) & 0xff


## "typewriter" print with a block cursor
func print_slow(s: String) -> void:
	sys.hurry += 1
	for ch in _shown(s):
		if ch == 0:
			break
		match ch:
			0x5f:
				if hi_mode != 0:
					await _slow_char(ch)
				else:
					put_char(0x20)
					put_char(0x0d)
			0x7e:
				put_char(0x20)
				put_char(0x0d)
			0x7b, 0x7d:
				kana_mode ^= 0xff
			0x7c:
				hi_mode ^= 0xff
			0x23:
				if hi_mode != 0:
					await _slow_char(ch)
				else:
					print_number(num_hi, num_lo)
			_:
				await _slow_char(ch)
	put_char(0x20)
	_end_string()
	sys.hurry -= 1


# ------------------------------------------------------------------ numbers

## print the 24-bit number hi:lo using `num_format`
func print_number(hi: int, lo: int) -> void:
	var s := "%08d" % ((hi & 0xff) * 0x10000 + (lo & 0xffff))
	if num_format == 0:
		var i := 0
		while i < 7 and s[i] == "0":
			i += 1
		s = s.substr(i)
	else:
		var i := 0
		while i < 7 and s[i] == "0":
			s[i] = " "
			i += 1
		if num_format == 1:
			s = s.substr(3)
	puts(s)  # printed as a string too, so it resets the modes afterwards


## set the number printed for '#': `=0,=v,=fmt`
func set_number(v: int, fmt: int) -> void:
	num_hi = 0
	num_lo = v & 0xffff
	num_format = fmt

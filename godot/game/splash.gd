## The opening notice: credit the copyright holders and state that this is an unofficial,
## non-commercial fan project that plays from the player's own copy.
class_name Splash
extends Mod

## OpenScreamer's logo (our own lettering, made by tools/openscreamer_spec/make_logo.py in the private
## repository), 560 x 84 board pixels, at the top
const LOGO := preload("res://assets/logo.png")

## the notice's lines, in the interface's language when the game's font can show it (French, with
## its accents; not Japanese, which stays in English)
const LINES := [
	# [row, text, colour]
	[11, "plays THE SCREAMER  (PC-9801, 1986)", Screen.GREEN | Screen.BLUE],
	[13, "Original game (C) 1985 Magical Zoo / ASCII Corporation.", Screen.WHITE],
	[15, "This port contains nothing of the original game:", Screen.WHITE],
	[16, "its graphics, text, maps and data are read from", Screen.WHITE],
	[17, "your own copy of the original disk.", Screen.WHITE],
	[19, "This is an UNOFFICIAL FAN PROJECT.", Screen.GREEN | Screen.RED],
	[20, "It is not affiliated with, nor endorsed by,", Screen.WHITE],
	[21, "the copyright holders of THE SCREAMER.", Screen.WHITE],
	[22, "Non-commercial: not for sale, no ads, no donations.", Screen.WHITE],
	[24, "PRESS SPACE KEY", Screen.RED],
]


## a line in the interface's language, if the game's font has all its letters
func _shown(s: String) -> String:
	var t := UiText.t(s)
	for i in t.length():
		var c := t.unicode_at(i)
		if (c < 0x20 or c > 0x7e) and Accents.code(t[i]) < 0:
			return s
	return t


func show() -> void:
	screen.reset_palette()
	screen.clear_screen()
	screen.draw(LOGO, Vector2i((640 - LOGO.get_width()) / 2, 2), false)
	for l in LINES:
		var g := GameText.glyphs(_shown(l[1]), true)
		for i in g.size():
			screen.text.put((80 - g.size()) / 2 + i, l[0], g[i], l[2])
	keys.flush()
	# wait for SPACE (or give up after ~12 s so the notice can't be skipped instantly by a held key)
	await sys.advance(1500000)
	keys.flush()
	for t in 120:
		var k := keys.take()
		if k == Keys.K_SPACE:
			break
		await sys.advance(100000)
	screen.clear_screen()
	keys.flush()

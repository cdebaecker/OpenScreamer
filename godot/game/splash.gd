## The opening notice: credit the copyright holders and state that this is an unofficial,
## non-commercial fan project that plays from the player's own copy.
class_name Splash
extends Mod

## Who holds the rights to the original game (shown on the splash screen).
const RIGHTS_HOLDER := "Magical Zoo / ASCII Corporation"

const LINES := [
	# [row, text, colour]
	[2, "THE SCREAMER", Screen.WHITE],
	[3, "PC-9801  1986", Screen.GREEN | Screen.BLUE],
	[6, "Original game (C) 1985 " + RIGHTS_HOLDER + ".", Screen.WHITE],
	[8, "This port contains nothing of the original game:", Screen.WHITE],
	[9, "its graphics, text, maps and data are read from", Screen.WHITE],
	[10, "your own copy of the original disk.", Screen.WHITE],
	[13, "This is an UNOFFICIAL FAN PROJECT.", Screen.GREEN | Screen.RED],
	[15, "It is not affiliated with, nor endorsed by,", Screen.WHITE],
	[16, "the copyright holders of THE SCREAMER.", Screen.WHITE],
	[18, "Non-commercial: not for sale, no ads, no donations.", Screen.WHITE],
	[22, "PRESS SPACE KEY", Screen.RED],
]


func show() -> void:
	screen.reset_palette()
	screen.clear_screen()
	for l in LINES:
		var s: String = l[1]
		for i in s.length():
			screen.text.put((80 - s.length()) / 2 + i, l[0], s.unicode_at(i), l[2])
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

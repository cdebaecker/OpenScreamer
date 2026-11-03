# the last monster falls and the story wraps up.
class_name Ending
extends Mod


## clear the message window (the original clears it twice), then an NPC line
func line(s: String) -> void:
	screen.clear_window(Screen.MESSAGE)
	screen.clear_window(Screen.MESSAGE)
	txt.kana_mode = 0xff
	txt.at(0x13, 0x11, 0x13)
	await common.blip()
	if sys.unwinding: return
	txt.puts(s)
	await ui.wait_space()


func face(n: int) -> void:
	screen.clear_window(Screen.VIEW)
	common.show_monster(n)


func run_ending() -> void:
	common.monster_dest = 0x8de
	screen.clear_screen()
	screen.clear_window(Screen.VIEW)
	common.show_monster(0x29)
	await line(data.msg(&"end.01"))
	if sys.unwinding: return
	common.show_picture(0x14)
	await line(data.msg(&"end.02"))
	if sys.unwinding: return
	face(0x29)
	await line(data.msg(&"end.03"))
	if sys.unwinding: return
	common.show_picture(0x14)
	await line(data.msg(&"end.04"))
	if sys.unwinding: return
	face(0x33)
	await line(data.msg(&"end.05"))
	if sys.unwinding: return
	common.show_picture(0x14)
	await line(data.msg(&"end.06"))
	if sys.unwinding: return
	face(0x33)
	await line(data.msg(&"end.07"))
	if sys.unwinding: return
	common.show_picture(0x14)
	await line(data.msg(&"end.08"))
	if sys.unwinding: return
	await line(data.msg(&"end.09"))
	if sys.unwinding: return
	face(0x33)
	await line(data.msg(&"end.10"))
	if sys.unwinding: return
	common.show_picture(0x14)
	await line(data.msg(&"end.11"))
	if sys.unwinding: return
	screen.clear_screen()
	common.show_picture(1)
	await line(data.msg(&"end.12"))
	if sys.unwinding: return
	common.show_picture(0x10)
	await line(data.msg(&"end.13"))
	if sys.unwinding: return
	face(0x33)
	await line(data.msg(&"end.14"))
	if sys.unwinding: return
	common.show_picture(0x10)
	await line(data.msg(&"end.15"))
	if sys.unwinding: return
	await line(data.msg(&"end.16"))
	if sys.unwinding: return
	face(0x33)
	await line(data.msg(&"end.17"))
	if sys.unwinding: return
	common.show_picture(0x11)
	await line(data.msg(&"end.18"))
	if sys.unwinding: return
	common.show_picture(0x10)
	await line(data.msg(&"end.19"))
	if sys.unwinding: return
	common.show_picture(0x12)
	screen.clear_window(Screen.MESSAGE)
	screen.clear_window(Screen.MESSAGE)
	txt.kana_mode = 0xff
	txt.at(0x13, 0x11, 0x13)
	await common.blip()
	if sys.unwinding: return
	txt.puts(data.msg(&"end.20"))
	await common.wait(0x4e20)
	if sys.unwinding: return
	screen.clear_screen()
	common.show_picture_at(0x13, 0x504)
	txt.at(0x32, 4, 0x32)
	txt.puts(data.msg(&"end.21"))
	await common.wait(0x2710)
	if sys.unwinding: return
	common.show_picture_at(0x12, 0x1c44)
	txt.at(0x0a, 0x10, 0x0a)
	txt.puts(data.msg(&"end.22"))
	await common.wait(0x4e20)
	if sys.unwinding: return
	for p in [0xa8, 0xaa, 0xac]:
		screen.out_palette(p, 0x77)
	screen.out_palette(0xae, 7)
	await common.wait(0x9c40)
	if sys.unwinding: return
	screen.clear_screen()
	txt.at(0x1a, 0x0c, 0x1a)
	await txt.print_slow(data.msg(&"end.23"))
	if sys.unwinding: return
	await common.wait(0xc350)
	if sys.unwinding: return
	screen.clear_screen()
	txt.at(0x0d, 1, 0x0d)
	await txt.print_slow(data.msg(&"end.24"))
	if sys.unwinding: return
	# typing "ASCII HSP" shows the staff of ASCII's software division
	var secret := "ASCII HSP"
	var i := 0
	while i < secret.length():
		var k := ui.read_key()
		if not k:
			await sys.advance(Ui.POLL_US)
			continue
		i = i + 1 if k == secret.unicode_at(i) else 0
	screen.clear_screen()
	txt.at(0x0d, 1, 0x0d)
	await txt.print_slow(data.msg(&"end.26"))
	if sys.unwinding: return
	# the original stops here for good
	while true:
		await sys.advance(100000)

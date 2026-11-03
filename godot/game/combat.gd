## Real-time combat: the screamer on the right, the monster on the left.
##   keypad 4/6 walk, 8 jump (8+4 / 8+6 jump sideways), 2 crouch, 0 try to escape
##   Z attack, X defend, C command mode (use items etc.)
## Positions are in the original's units: columns of 8 pixels, board lines.
class_name Combat
extends Mod

# effects of items used in a fight (set by Items too)
var fog_timer := 0
var noise_on := 0
var frozen := 0  # squash ball
var noise_timer := 0
var _fogged_lo := 0
## fog ball: in the original a word whose high byte is the noise machine's timer,
## so a running noise machine also counts as fogged, and the fog ball stops that timer.  With the
## original's bugs fixed (sys.fix_bugs) they're separate
var fogged: int:
	get: return _fogged_lo if sys.fix_bugs else (noise_timer << 8) | _fogged_lo
	set(v):
		_fogged_lo = v & 0xff
		if not sys.fix_bugs:
			noise_timer = (v >> 8) & 0xff
var frozen_timer := 0
var weapon_kind := 0
var weapon_pow := 0

var _mon_attack_count := 0
var _poison_tick := 0
var _x := 0  # player column
var _mon_x := 0  # monster column
var _action := 0  # 0F attack, F0 defend
var _facing := 0  # 0 right, FF left
var _mon_facing := 0
var _shot := 0  # player's attack in flight
var _mon_shot := 0  # monster's attack in flight
var _move := 0  # 0F right, F0 left, FF crouch
var _jump := 0
var _vy := 0  # vertical step of the jump (16-bit)
var _jump_ptr := 0  # index in the combat_jump table
var _y := 0  # player line
var _mon_action := 0
var _hit_pose := 0
var _mon_move := 0
## the monster's sprite: offset in its sprite set (0 facing right, 512 facing left), negative
var _mon_sprite := 0
var _mon_negative := false
# projectiles
var _p_dir := 0
var _shot_pos := 0  # VRAM offset
var _mon_shot_pos := 0
var _shot_dx := 0  # 16-bit
var _mon_shot_dx := 0
var _shot_col := 0
var _mon_shot_col := 0
var _shot_low := 0
var _mon_shot_low := 0
var _shot_facing := 0
var _mon_shot_facing := 0
var _shot_life := 0
var _mon_shot_life := 0

## shot checks: still flying, gone, or hit
const FLYING := -1
const GONE := 0
const HIT := 1


## (flow target "combat")
func run_combat() -> void:
	st.game_mode = 4
	_setup()
	while true:
		ui.drain_keys()
		await _player_tick()
		if sys.unwinding: return
		ui.drain_keys()
		await _monster_shot_tick()
		if sys.unwinding: return
		ui.drain_keys()
		await _monster_tick()
		if sys.unwinding: return
		ui.drain_keys()
		await _player_shot_tick()
		if sys.unwinding: return
		await _timers()
		if sys.unwinding: return
		ui.drain_keys()
		await common.wait_eat_keys(0x1f4)
		ui.drain_keys()


func _setup() -> void:
	# the first equipped weapon
	weapon_kind = 0
	weapon_pow = 0
	var c := st.chr
	for i in c.inv_count():
		var it := c.inv(i)
		if not (it & Character.EQUIPPED):
			continue
		if chara.item_kind(it) >= 3:
			continue
		weapon_kind = chara.item_kind(it)
		weapon_pow = chara.item_value(it)
		break
	_x = 0x23
	_mon_x = 2
	_y = 0x58
	_poison_tick = 0x0a
	_vy = 0
	_shot = 0
	_mon_shot = 0
	_mon_attack_count = 0
	frozen = 0
	frozen_timer = 0
	fog_timer = 0
	fogged = 0
	noise_timer = 0
	if sys.fix_bugs:  # the original never clears the noise machine's flag: see _timers()
		noise_on = 0
		_mon_facing = 0  # nor the monster's facing, only the sprite's
	_shot_life = 0
	_mon_shot_life = 0
	ui.menu_reset(5)
	screen.clear_window(Screen.MENU)
	txt.kana_mode = 0xff
	txt.at(5, 3, 5)
	txt.puts(data.msg(&"fight.01"))
	screen.clear_window(Screen.MESSAGE)
	draw_names()
	screen.clear_window(Screen.VIEW)
	screen.draw(art.piece("combat/backdrop_top"), Screen.px(0x792))
	screen.draw(art.piece("combat/backdrop_bottom"), Screen.px(0x2592))
	_move = 0
	_jump = 0
	_action = 0
	_facing = 0xff
	_draw_player()
	_mon_sprite = 0
	_mon_negative = false
	_draw_monster()
	keys.flush()


# ------------------------------------------------------------------ status line

## a name frame: 120 x 16 pixels, white (or red: poisoned)
func _frame(pos: Vector2i, colour: int) -> void:
	screen.fill(Rect2i(pos + Vector2i(8, 0), Vector2i(120, 1)), colour)
	screen.fill(Rect2i(pos + Vector2i(6, 0), Vector2i(2, 16)), colour)
	screen.fill(Rect2i(pos + Vector2i(128, 0), Vector2i(2, 16)), colour)
	screen.fill(Rect2i(pos + Vector2i(8, 15), Vector2i(120, 1)), colour)


## both names and their frames; a red frame when you are poisoned
func draw_names() -> void:
	txt.col = 0x2a
	txt.row = 0x11
	txt.kana_mode = 0
	txt.print_raw(st.chr.name)
	txt.col = 0x13
	txt.row = 0x11
	txt.print_raw(_monster_name())
	_frame(Screen.px(0x2e52), Screen.WHITE)
	_frame(Screen.px(0x2e69), Screen.WHITE if st.chr.poison == 0 else Screen.RED)


## the monster's record printed as a string, like the original (up to its first zero byte)
func _monster_name() -> String:
	var r := st.mon.record
	var z := r.find(0)
	return GameText.decode(r if z < 0 else r.slice(0, z))


# ------------------------------------------------------------------ sprites

## the screamer's pose at its place
func _draw_player() -> void:
	var bl := 0x0a if _facing == 0 else 0
	var no_action := false
	if _hit_pose == 0xff:
		bl += 9
		no_action = true
	elif _jump == 0xf0:
		bl += 6
	elif _move != 0xff:
		bl += 3
	if not no_action:
		if _action == 0xf0:
			bl += 2
		elif _action == 0x0f:
			bl += 1
	var pos := (0x50 * _y + _x + 0x11) & 0xffff
	screen.sprite(&"player", art.piece("combat/player", bl), Screen.px(pos))


## the monster at its place
func _draw_monster() -> void:
	var w := 4
	var h := 0x20
	var pos := _mon_x + 0x11
	if st.mon.kind == 0x10:
		pos += 0x2080
		w = 4 if st.mon.width == 4 else 8
		h = 0x10
	else:
		pos += 0x1b80
	screen.sprite(&"monster", _monster_texture(w, h), Screen.px(pos & 0xffff))


func _monster_texture(w: int, h: int) -> Texture2D:
	var key := "combat/g%02d_%x_%d_%d%s" % [st.monster, _mon_sprite, w, h, "_negative" if _mon_negative else ""]
	var d := data.monster_sprites(st.monster)
	if _mon_negative:  # its 384 bytes in negative
		for i in 0x180:
			d[_mon_sprite + i] = ~d[_mon_sprite + i] & 0xff
	return art.planar(key, d, _mon_sprite, w, h)


func _erase_monster() -> void:
	screen.hide_sprite(&"monster")


## the little attack lamps
func _mon_lamp(on: bool) -> void:
	if on:
		screen.sprite(&"monster_lamp", art.piece("combat/monster_lamp"), Screen.px(0x2fa3), false)
	else:
		screen.hide_sprite(&"monster_lamp")


func _my_lamp(on: bool) -> void:
	if on:
		screen.sprite(&"player_lamp", art.piece("combat/player_lamp"), Screen.px(0x2fa7), false)
	else:
		screen.hide_sprite(&"player_lamp")


# ------------------------------------------------------------------ the player

func _player_tick() -> void:
	if _vy == 0:
		await _read_controls()
		if sys.unwinding: return
	_move_player()
	_attack_start()
	_draw_player()


func _read_controls() -> void:
	st.chr.luck = rng.random(0xff)
	_move = 0
	_jump = 0
	_action = 0
	match keys.pad_bits():
		0x0040:
			await _try_escape()
			if sys.unwinding: return
		0x0008:
			_move = 0xff
		0x0001:
			_right()
		0x4000:
			_left()
		0x0800:
			_jump = 0xf0
		0x0801:
			_jump = 0xf0
			_right()
		0x4800:
			_jump = 0xf0
			_left()
	_action = 0
	match keys.group(5):
		0x08:
			await _command_mode()
			if sys.unwinding: return
		0x02:
			_action = 0x0f
		0x04:
			_action = 0xf0
	keys.flush()


func _right() -> void:
	_facing = 0
	_move = 0x0f


func _left() -> void:
	_facing = 0xff
	_move = 0xf0


## keypad 0
func _try_escape() -> void:
	var r := rng.random(0xff) + rng.random(0xff)
	if st.chr.luck + st.chr.agl < r:
		return
	if st.chr.luck < rng.random(0xff):
		return
	screen.clear_window(Screen.MESSAGE)
	common.say_at(0x12, 0x14, data.msg(&"fight.02"))
	await common.beep_eat_keys(0x2710, 1, 1)
	screen.clear_window(Screen.MESSAGE)
	sys.jump(&"dungeon")


## pause the fight and use the command menu
func _command_mode() -> void:
	screen.clear_window(Screen.MESSAGE)
	txt.col = 0x1d
	txt.row = 0x16
	txt.puts(data.msg(&"fight.03"))
	while true:
		var sel: int = await ui.menu_poll()
		if sys.unwinding: return
		if sel:
			var commands: Array[Callable] = [items.use_item, chara.show_abilities, items.look_items,
					items.unequip_item, items.equip_item, _no_command]
			await commands[sel - 1].call()
			if sys.unwinding: return
			break
		if ui.last_key == Keys.K_ESC:
			break
		await sys.advance(Ui.POLL_US)
	screen.clear_window(Screen.MESSAGE)
	while true:
		var sel: int = await ui.menu_poll()
		if sys.unwinding: return
		if not sel:
			break
		await sys.advance(Ui.POLL_US)
	draw_names()
	keys.flush()


func _no_command() -> void:
	pass


## would a body at column `col` (4 wide) touch the monster?
func _touches_monster(col: int) -> bool:
	if _mon_x >= ((col + 4) & 0xff):
		return false
	return col < ((_mon_x + st.mon.width) & 0xff)


## start a jump arc at entry `i` of the combat_jump table
func _jump_start(i: int) -> void:
	var arc: Array = data.table("combat_jump")
	_vy = arc[i]
	_jump_ptr = i + 1


func _jump_step() -> void:
	_y = (_y + _vy) & 0xff
	_vy = data.table("combat_jump")[_jump_ptr]
	_jump_ptr += 1


func _move_player() -> void:
	if _move == 0xff:
		return
	if _move == 0x0f:
		_move_right()
		return
	if _move == 0xf0:
		_move_left()
		return
	if _jump == 0:
		return
	# jump on the spot
	_move = 0
	if _vy == 0:
		_jump_start(0)
	_jump_step()


func _move_right() -> void:
	if _jump == 0:
		if _x == 0x25:
			return
		if ((_x + 4) & 0xff) == _mon_x:
			return
		_x = (_x + 1) & 0xff
		return
	_jump_right()


func _jump_right() -> void:
	while true:
		if _x == 0x25:
			_jump_left()
			return
		if st.mon.kind == 0x10:
			if _vy == 0x14 and _touches_monster(_x):
				_jump_start(1)
				continue
		elif _vy == 0x0c and _touches_monster((_x + 1) & 0xff):
			_jump_start(2)
			continue
		break
	_move = 0x0f
	if _vy != 0x14 and _vy != 0xffec:
		_x = (_x + 1) & 0xff
	if _vy == 0:
		_jump_start(0)
	_jump_step()


func _move_left() -> void:
	if _jump == 0:
		if _x == 1:
			return
		if ((_mon_x + st.mon.width) & 0xff) == _x:
			return
		_x = (_x - 1) & 0xff
		return
	_jump_left()


func _jump_left() -> void:
	while true:
		if _x == 1:
			_jump_right()
			return
		if st.mon.kind == 0x10:
			if _vy == 0x14 and _touches_monster(_x):
				_jump_start(1)
				continue
		elif _vy == 0x0c and _touches_monster((_x - 1) & 0xff):
			_jump_start(2)
			continue
		break
	_move = 0xf0
	if _vy != 0x14 and _vy != 0xffec:
		_x = (_x - 1) & 0xff
	if _vy == 0:
		_jump_start(0)
	_jump_step()


func _attack_start() -> void:
	if _action != 0x0f:
		return
	if _vy != 0:
		return
	_shot = 0xff
	_my_lamp(true)
	txt.col = 0x2a
	txt.row = 0x13
	txt.puts(data.msg(&"fight.04"))


# ------------------------------------------------------------------ projectiles

## an attack in flight (`id`) at a VRAM offset, pointing the way `_p_dir` says
func _draw_shot(id: StringName, pos: int) -> void:
	var tex := art.piece("combat/shot_right" if _p_dir == 0 else "combat/shot_left")
	screen.sprite(id, tex, Screen.px(pos & 0xffff))


func _player_shot_tick() -> void:
	if _shot == 0:
		txt.col = 0x2a
		txt.row = 0x13
		txt.puts("               ")
		return
	if _shot_life == 0:
		_shot_life = 0xff if weapon_kind == 1 else 5 if weapon_kind == 2 else 2
		_shot_low = 0xff if _move == 0xff else 0
		_shot_facing = _facing
		if _facing == 0:
			_shot_dx = 2
			_shot_col = (_x + 4) & 0xff
		else:
			_shot_dx = 0xfffe
			_shot_col = (_x - 4) & 0xff
		_p_dir = _shot_facing
		_shot_pos = (_shot_col + (0x1eb1 if _shot_low == 0 else 0x2091)) & 0xffff
		var r := _shot_check()
		if r == FLYING:
			_draw_shot(&"shot", _shot_pos)
			return
		await _shot_ended(r)
		return
	_p_dir = _shot_facing
	_shot_pos = (_shot_pos + _shot_dx) & 0xffff
	_shot_col = (_shot_col + _shot_dx) & 0xff
	var r := _shot_check()
	if r == FLYING:
		_draw_shot(&"shot", _shot_pos)
		return
	screen.hide_sprite(&"shot")
	await _shot_ended(r)


func _shot_ended(r: int) -> void:
	_shot_life = 0
	if r == HIT:
		await _player_hits()


func _shot_check() -> int:
	_shot_life = (_shot_life - 1) & 0xff
	var col := _shot_col
	if _shot_life == 0 or col == 0 or col >= 0x26:
		_shot = 0
		return GONE
	if _mon_x >= ((col + 4) & 0xff):
		return FLYING
	if col >= ((_mon_x + st.mon.width) & 0xff):
		return FLYING
	if _shot_low != 0 or st.mon.kind == 0x20:
		_shot = 0
		return HIT
	return FLYING


func _monster_shot_tick() -> void:
	if _mon_shot == 0:
		txt.col = 0x13
		txt.row = 0x13
		txt.puts("               ")
		return
	if _mon_shot_life == 0:
		_mon_shot_life = 0xff
		_mon_shot_low = 0xff if st.mon.kind == 0x10 else (rng.random(1) - 1) & 0xff
		_mon_shot_facing = _mon_facing
		if _mon_facing == 0:
			_mon_shot_dx = 2
			_mon_shot_col = (_mon_x + st.mon.width) & 0xff
		else:
			_mon_shot_dx = 0xfffe
			_mon_shot_col = (_mon_x - 4) & 0xff
		_p_dir = _mon_shot_facing
		_mon_shot_pos = (_mon_shot_col + (0x1c31 if _mon_shot_low == 0 else 0x2091)) & 0xffff
		var r := _mon_shot_check()
		if r == FLYING:
			_draw_shot(&"monster_shot", _mon_shot_pos)
			return
		await _mon_shot_ended(r)
		return
	_p_dir = _mon_shot_facing
	_mon_shot_pos = (_mon_shot_pos + _mon_shot_dx) & 0xffff
	_mon_shot_col = (_mon_shot_col + _mon_shot_dx) & 0xff
	var r := _mon_shot_check()
	if r == FLYING:
		_draw_shot(&"monster_shot", _mon_shot_pos)
		return
	screen.hide_sprite(&"monster_shot")
	await _mon_shot_ended(r)


func _mon_shot_ended(r: int) -> void:
	_mon_shot_life = 0
	if r == HIT:
		await _monster_hits()


func _mon_shot_check() -> int:
	_mon_shot_life = (_mon_shot_life - 1) & 0xff
	var col := _mon_shot_col
	if _mon_shot_life == 0 or col == 0 or col >= 0x26:
		_mon_shot = 0
		return GONE
	if _x >= ((col + 4) & 0xff):
		return FLYING
	if col >= ((_x + 4) & 0xff):
		return FLYING
	if _vy != 0:
		return FLYING
	if _mon_shot_low != 0 or _move != 0xff:
		_mon_shot = 0
		return HIT
	return FLYING


# ------------------------------------------------------------------ hits

## three blinks of a label with a beep
func _blink(col: int, text: String) -> void:
	for i in 3:
		common.say_at(col, 0x13, text)
		await common.beep_eat_keys(0x3e8, 1, 1)
		txt.col = col
		txt.row = 0x13
		txt.puts("           ")
		await common.wait_eat_keys(0x3e8)


## the player's attack reaches the monster
func _player_hits() -> void:
	var ch := st.chr.tec / 10 + rng.random(0x14)
	if (ch & 0xff) < st.mon.tec:
		_mon_lamp(false)
		await _blink(0x13, data.msg(&"fight.07"))
		_my_lamp(false)
		return
	if st.mon.ac >= rng.random(0x3c):
		_mon_lamp(false)
		await _blink(0x13, data.msg(&"fight.08"))
		_my_lamp(false)
		return
	await _monster_flash()
	var hp := st.mon.hp - (weapon_pow + st.chr.pow)
	st.mon.hp = hp
	if hp <= 0:
		await _victory()
		return
	if st.mon.tec >= rng.random(0x1a):
		return
	# knock the monster back
	var n := rng.random(0x0c) + 4
	if _x < _mon_x:
		for i in n:
			if ((_mon_x + st.mon.width) & 0xff) >= 0x29:
				return
			_mon_x = (_mon_x + 1) & 0xff
			_draw_monster()
			await common.wait_eat_keys(0x190)
	else:
		for i in n:
			if _mon_x <= 1:
				return
			_mon_x = (_mon_x - 1) & 0xff
			_draw_monster()
			await common.wait_eat_keys(0x190)


## the monster blinks in negative
func _monster_flash() -> void:
	_mon_lamp(false)
	for i in 3:
		common.say_at(0x13, 0x13, data.msg(&"fight.09"))
		_mon_negative = true
		_draw_monster()
		await common.beep_eat_keys(0x3e8, 1, 1)
		common.say_at(0x13, 0x13, "           ")
		_mon_negative = false
		_draw_monster()
		await common.wait_eat_keys(0x3e8)
	_my_lamp(false)


## the monster's attack reaches you
func _monster_hits() -> void:
	if _action == 0xf0:
		await _player_blocks()
		return
	var cl := (rng.random(0x46) + st.mon.pow) & 0xff
	var al := (rng.random(0x50) + st.chr.ac) & 0xff
	if al >= cl:
		await _player_blocks()
		return
	if fogged != 0:
		await _monster_misses()
		return
	var dx := rng.random(0xfa) + rng.random(0xfa) + st.chr.agl
	var ax := rng.random(0xfa) + rng.random(0xfa)
	if dx - ax >= 0:
		await _monster_misses()
		return
	await _player_flash(data.msg(&"fight.09"))
	chara.adjust_stat(0, -((st.mon.pow + 1) >> 1))
	if sys.unwinding: return
	if st.mon.poison != 0 and rng.random(1) == 0:
		await _player_flash(data.msg(&"fight.10"))
		st.chr.poison |= st.mon.poison
		draw_names()
	_mon_lamp(false)


func _player_flash(text: String) -> void:
	_my_lamp(false)
	_hit_pose = 0xff
	_draw_player()
	_hit_pose = 0
	for i in 3:
		common.say_at(0x2a, 0x13, text)
		await common.beep_eat_keys(0x3e8, 1, 1)
		txt.col = 0x2a
		txt.row = 0x13
		txt.puts("           ")
		await common.wait_eat_keys(0x3e8)
	_mon_lamp(false)
	_draw_player()


func _player_blocks() -> void:
	_my_lamp(false)
	await _blink(0x2a, data.msg(&"fight.08"))
	_mon_lamp(false)


func _monster_misses() -> void:
	_my_lamp(false)
	await _blink(0x2a, data.msg(&"fight.07"))
	_mon_lamp(false)


# ------------------------------------------------------------------ the monster

func _monster_tick() -> void:
	if _vy == 0:
		if rng.random(0xff) < 2 and rng.random(5) == 0:
			await _monster_flees()
			return
		_decide_move()
		_do_move()
		_decide_attack()
		if _mon_action == 0x0f:
			_mon_shot = 0xff
			_mon_lamp(true)
			txt.col = 0x13
			txt.row = 0x13
			txt.puts(data.msg(&"fight.04"))
	_draw_monster()


func _monster_flees() -> void:
	_erase_monster()
	screen.clear_window(Screen.MESSAGE)
	txt.col = 0x18
	txt.row = 0x15
	txt.puts(data.msg(&"fight.11"))
	await common.beep_eat_keys(0x2710, 1, 1)
	await ui.wait_space()
	sys.jump(&"dungeon")


func _decide_move() -> void:
	_mon_move = 0
	if frozen != 0:
		return
	if rng.random(0x0a) >= 6:
		return
	if _mon_x == _x:
		return
	if _mon_x < _x:
		_mon_move = 0xf0
		_mon_facing = 0
	else:
		_mon_move = 0x0f
		_mon_facing = 0xff


func _do_move() -> void:
	if _mon_move == 0x0f:
		_mon_left()
	elif _mon_move == 0xf0:
		_mon_right()


func _mon_right() -> void:
	if _x == 0x25:
		var al := (_mon_x + st.mon.width) & 0xff
		if al == _x:
			_mon_left()
			return
		if ((al + 1) & 0xff) == _x:
			return
	var al := (_mon_x + st.mon.width) & 0xff
	if al == 0x29:
		return
	if al == _x:
		return
	_mon_x = (_mon_x + 1) & 0xff
	_mon_sprite = 0


func _mon_left() -> void:
	if _x == 1:
		var al := (_x + 4) & 0xff
		if al == _mon_x:
			_mon_right()
			return
		if ((al + 1) & 0xff) == _mon_x:
			return
	if _mon_x == 1:
		return
	if ((_x + 4) & 0xff) == _mon_x:
		return
	_mon_x = (_mon_x - 1) & 0xff
	_mon_sprite = 0x200


func _decide_attack() -> void:
	_mon_action = 0
	if noise_on != 0:
		return
	var al := rng.random(0x0b)
	if al >= 4:
		_mon_attack_count = (_mon_attack_count + 1) & 0xff
		if _mon_attack_count == 3:
			_mon_attack_count = 0
			_mon_action = 0x0f
		return
	if al >= 2:
		return
	_mon_action = 0xf0


# ------------------------------------------------------------------ timers

func _timers() -> void:
	ui.drain_keys()
	if frozen_timer != 0:
		frozen_timer = (frozen_timer - 1) & 0xff
		if frozen_timer == 0:
			frozen = 0
			await _effect_over(data.msg(&"fight.12"))
	ui.drain_keys()
	if noise_timer != 0:
		noise_timer = (noise_timer - 1) & 0xff
		if noise_timer == 0:
			# "the monster attacks again", but in the original the flag that stops it stays set
			# (nothing ever clears the noise machine's flag: no monster attacks again until the program restarts)
			if sys.fix_bugs:
				noise_on = 0
			await _effect_over(data.msg(&"fight.13"))
	ui.drain_keys()
	if fog_timer != 0:
		fog_timer = (fog_timer - 1) & 0xff
		if fog_timer == 0:
			fogged = 0
			await _effect_over(data.msg(&"fight.14"))
	ui.drain_keys()
	if st.chr.poison != 0:
		_poison_tick = (_poison_tick - 1) & 0xff
		if _poison_tick == 0:
			chara.adjust_stat(0, -rng.random(2))
			if sys.unwinding: return
			_poison_tick = 0x0a
	ui.drain_keys()


func _effect_over(text: String) -> void:
	common.say_at(0x13, 0x16, text)
	await common.beep_eat_keys(0x2710, 1, 1)
	txt.col = 0x12
	txt.row = 0x16
	txt.puts("                                        ")


# ------------------------------------------------------------------ victory

func _victory() -> void:
	var frd := chara.has_item(0x52)
	if not (frd >= 0 and st.chr.inv(frd) & Character.EQUIPPED):
		st.mon.bp = 0
	st.chr.bp += st.mon.bp
	screen.clear_window(Screen.MESSAGE)
	common.say_at(0x1e, 0x12, data.msg(&"fight.16"))
	await common.beep_eat_keys(0x1388, 1, 1)
	txt.col = 0x18
	txt.row = 0x15
	txt.set_number(st.mon.bp, 1)
	txt.puts(data.msg(&"fight.17"))
	sys.journal(&"victory", st.mon.name, str(st.mon.bp))
	await ui.wait_space()
	chara.status_panel()
	if st.monster == 0x27:
		sys.jump(&"ending")
		return
	sys.jump(&"dungeon")

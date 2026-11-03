## A bot that plays THE SCREAMER from registration to the ending with the player's controls: keys
## for menus, prompts and typing, the keypad's held actions for walking and fighting.  No debug
## keys, no changes to the game state.  The game runs as in the Godot port's Modern difficulty: when
## the screamer dies, the bot goes back a few steps (like the Rewind prompt) and plays on.
##
## At each key poll it looks at what the game waits for (the call stack: a menu, "Push Space Key",
## a yes / no, a name, the BIAS loop) and answers; at each read of the keypad (walking, a pit, a
## fight) it decides what to hold.  What it knows is what a player can know: the screen, the
## character, the map of BIAS (the original's manual and wall writings give the passwords), and the
## items, people and floors as the game shows them.
##
##   godot --headless --path godot -s res://tools/playthrough.gd -- outdir [--log] [--limit N]
##   xvfb-run godot --path godot -s res://tools/playthrough.gd -- outdir --video run.mp4 [--fast S]
##
## With --video the same game (it plays the same: the game's clock is virtual) is filmed through
## ffmpeg: fast while it walks and fights (S seconds of game time per frame, 30 frames a second), in
## real time when something happens (the start, the pendant trades, the Samurai, floor 6, the
## guardian, the ending).
extends SceneTree

const NAME := "PLAYER"
const DX := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## the pendant chain: who (BIAS hunter number) wants which pendant
const WANTS := {1: 80, 2: 75, 3: 79, 4: 76, 5: 78, 6: 74, 7: 77, 8: 81}
const FRD := 0x52
const BLADE := 0x19
const BOSS := 0x27
const EX_CARD := 0x45
## the floor the stairs / elevators of a floor lead to, and where they are: [floor, x, y, event]
const TOWER_EXIT := Vector3i(1, 0, 21)

var game: Game
var screen: Screen
var out_dir := ""
var log_waits := false
var trace_from := -1  # --trace N: log every walking decision after N polls
var limit := 3000000
var saved := PackedByteArray()
var polls := 0
var deaths := 0
var won := false
var _last_sig := ""
var _seq: Array[int] = []  # keys still to type for the current prompt
var _pick_p := 0  # the item list's cursor (items.pick_item keeps it local)
var _menu_want := -1  # the menu item being moved to
var _use := 0  # an item to use from the command menu (the EX card at a door)
var _held := {}  # keypad actions held (Keys.scripted)
var _snaps: Array[Dictionary] = []  # states to go back to (BIAS cells, the town)
var _snap_key := ""
var _pending: Dictionary = {}  # a state to go on from (after a death)
var _rng := RandomNumberGenerator.new()
# plans
var _town_done := {}  # what was done during this visit to the town
var _bought := false
var _buy_confirmed := false

var _goal := ""
var _goal_cell := Vector3i(-1, -1, -1)
var _visits := {}  # Vector3i -> times stood there
var _retreat := false  # back to town at the next chance
var _last_place := Vector3i(-1, -1, -1)
var _stuck := 0
var _fights := 0
var _fight_log := -1
var _last_hp := 0
var _log_every := 0
var _deaths_here := 0  # deaths since the last visit to the town
var _last_hunter := 0
var _cmd_tries := {}  # "place command" -> times chosen there
var _blocked := {}  # Vector3i(floor, x, y) * 4 + dir... as "f x y d": ways that didn't let the screamer through
var _tried := -1  # the step last tried (see _edge)
var _matrix_at := ""
var _floor_maps := {}
var _path: Array[Vector3i] = []
var _path_goal := Vector3i(-9, 0, 0)
var _path_blocked := -1
var _path_has := -1
var _goal_steps := 0  # steps taken towards the goal
var _goal_len := 0  # the route's length when the goal was chosen
var _given_up := {}  # goal cell -> polls when it can be tried again


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() else "user://playthrough"
	log_waits = "--log" in args
	if "--trace" in args:
		trace_from = int(args[args.find("--trace") + 1])
	if "--replay" in args:
		var f := FileAccess.open(args[args.find("--replay") + 1], FileAccess.READ)
		replay = f.get_var()
	if "--video" in args:
		video = args[args.find("--video") + 1]
	if "--fast" in args:
		fast_us = int(float(args[args.find("--fast") + 1]) * 1000000)
	if "--checkpoint" in args:
		checkpoint = args[args.find("--checkpoint") + 1]
	if "--resume" in args:
		var f := FileAccess.open(args[args.find("--resume") + 1], FileAccess.READ)
		_resume = f.get_var()
	if "--limit" in args:
		limit = int(args[args.find("--limit") + 1])
	_rng.seed = 1985
	DirAccess.make_dir_recursive_absolute(out_dir)
	screen = load("res://screen/screen.tscn").instantiate()
	root.add_child(screen)
	_pending = {"new": true} if _resume.is_empty() else _resume


## the game's host: it runs SLICE_US of game time per engine frame (so the engine gets to do its
## deferred work: freeing nodes, redraws), as fast as the machine goes
signal tick
const SLICE_US := 2000000
var _host_clock := 0


func now_us() -> int:
	if video != "":
		return _host_clock
	# (no frame waits but at the BIAS loop, when _walk asks: a game resumed after a wait no longer
	# shows its callers on the call stack, which the answers read)
	return game.sys.clock - 1 if _yield_next else 1 << 60


func _process(_delta: float) -> bool:
	if won and (video == "" or game.sys.clock > _end_at):
		print("THE END: the guardian is beaten (%d polls, %d deaths, %d s of game time)" % [polls, deaths, game.sys.clock / 1000000])
		if replay.is_empty():
			var f := FileAccess.open(out_dir.path_join("recording.bin"), FileAccess.WRITE)
			f.store_var({"keys": _rec_keys, "holds": _rec_holds, "restores": _rec_restores, "polls": polls})
		_video_close()
		quit(0)
		return true
	if not _pending.is_empty():
		_start(_pending)
		return false
	if game == null:
		return false
	if video == "":
		if _yield_next:
			_yield_next = false
			tick.emit()
		return false
	_host_clock = game.sys.clock + _video_slice()
	tick.emit()
	_video_frame()
	return false


# ------------------------------------------------------------------ the replay

func _replay_poll() -> void:
	polls += 1
	if polls > limit:
		say("replay limit reached: " + _status())
		_video_close()
		game.sys.halt()
		quit(1)
		return
	var restores: Array = replay["restores"]
	if _ri[2] < restores.size() and restores[_ri[2]][0] == polls:
		_pending = restores[_ri[2]][1]
		_ri[2] += 1
		deaths += 1
		game.sys.halt()
		return
	var keys: Array = replay["keys"]
	while _ri[0] < keys.size() and keys[_ri[0]][0] == polls:
		game.keys.push(keys[_ri[0]][1])
		_ri[0] += 1
	if game.program.current == &"ending" and not won:
		won = true
		_end_at = game.sys.clock + 30000000
	if polls > int(replay["polls"]) and polls % 2 == 0:
		game.keys.push(Keys.K_SPACE)  # (the ending: on past its pauses)
	_moments()


func _replay_matrix() -> void:
	_reads += 1
	var holds: Array = replay["holds"]
	while _ri[1] < holds.size() and holds[_ri[1]][0] == _reads:
		var d := {}
		for a in holds[_ri[1]][1]:
			d[a] = true
		game.keys.scripted = d
		_ri[1] += 1


## what the video slows down for: a pendant changing hands, the Samurai (looked at now and then)
func _moments() -> void:
	if polls % 512 != 0:
		return
	var n := 0
	for it in range(0x4a, 0x52):
		n = n * 2 + int(game.chara.has_item(it) >= 0)
	n = n * 2 + int(game.chara.has_item(BLADE) >= 0)
	if n != _last_pendants:
		if _last_pendants >= 0:
			_slow(8.0)
		_last_pendants = n
	if game.st.hunter == 8:
		_slow(4.0)


# ------------------------------------------------------------------ the video

var video := ""
var replay := {}  # --replay recording.bin: the inputs of a run, played again (for the video)
var _rec_keys: Array = []  # [poll, key]
var _rec_holds: Array = []  # [matrix read, actions]
var _rec_restores: Array = []  # [poll, state]
var _reads := 0  # matrix reads
var _yield_next := false
var _last_yield := 0
var _ri := [0, 0, 0]  # replay positions in keys, holds, restores
var _last_pendants := -1
var checkpoint := ""  # --checkpoint file: the game at each visit to the town, to --resume from
var _resume := {}
var fast_us := 20000000
var _pipe: FileAccess
var _ffmpeg := -1
var _slow_until := 0
var _frames := 0
var _end_at := 1 << 62
const REAL_US := 33333  # a 30th of a second: real time
const SIZE := Vector2i(960, 600)


func _slow(seconds: float) -> void:
	_slow_until = maxi(_slow_until, game.sys.clock + int(seconds * 1000000))


func _video_slice() -> int:
	var st := game.st
	if won or (st.monster == BOSS and st.game_mode == 4) or game.sys.clock < _slow_until:
		return REAL_US
	if st.floor == 6 and st.game_mode >= 3:
		return REAL_US * 6  # (floor 6: six times as fast)
	return fast_us


func _video_open() -> void:
	DirAccess.make_dir_recursive_absolute(video + ".frames")
	_pipe = FileAccess.open(video + ".frames/count", FileAccess.WRITE)  # (a marker: frames are written)


func _video_frame() -> void:
	if _pipe == null:
		_video_open()
	var img := root.get_texture().get_image()
	img = img.get_region(Rect2i(0, 0, 1280, 800))
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
	img.save_jpg(video + ".frames/%07d.jpg" % _frames, 0.92)
	_frames += 1


func _video_close() -> void:
	if _pipe == null:
		return
	_pipe.store_string(str(_frames))
	_pipe.close()
	_pipe = null
	print("video: %d frames; encoding" % _frames)
	var out := []
	OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-framerate", "30", "-i", video + ".frames/%07d.jpg",
			"-c:v", "libx264", "-preset", "medium", "-crf", "22", "-pix_fmt", "yuv420p", video], out, true)
	print("".join(out))


func _start(p: Dictionary) -> void:
	_pending = {}
	if game != null:
		game.dispose()
	game = Game.create(screen)
	game.data.lang = "en"
	game.chara.save_load = func() -> PackedByteArray: return saved
	game.chara.save_store = func(d: PackedByteArray) -> void: saved = d
	game.sys.pendant_fix = true
	if replay.is_empty():
		game.keys.on_empty_poll = _poll
		game.keys.on_matrix_read = _matrix
	else:
		game.keys.on_empty_poll = _replay_poll
		game.keys.on_matrix_read = _replay_matrix
	game.sys.host = self
	_host_clock = game.sys.clock + SLICE_US
	if p.has("new") and video != "":
		_slow_until = 90000000  # (the start in real time)
	if p.has("new"):
		saved = game.data.roster_default
		game.program.run_main()
	else:
		if p.has("roster"):
			saved = p["roster"]
			polls = p["polls"]
		SaveGame.restore(game, p["state"])
		SaveGame.ensure_in_roster(game)
		game.st.stood = 1
		screen.clear_screen()
		screen.reset_palette()
		game.common.set_color4(game.st.color4)
		if p["where"] == "bias":  # the name, as the town printed it on the way in (as main.load_state)
			game.txt.at(0x3d, 8, 0x3d)
			game.txt.print_raw(game.st.chr.name)
			game.txt.kana_mode = 0xff
		_host_clock = game.sys.clock + SLICE_US
		game.program.run_from(SaveGame.target_of(StringName(p["where"])))


# ------------------------------------------------------------------ seeing

## what the game is waiting in: its function names, innermost first (game code only, without the
## key reading itself)
func _waiting() -> PackedStringArray:
	var out := PackedStringArray()
	for f: Dictionary in get_stack():
		var src: String = f["source"]
		if src.begins_with("res://game/"):
			var n: String = src.get_file().get_basename() + ":" + f["function"]
			if n in ["keys:take", "keys:read", "keys:peek", "ui:read_key", "ui:wait_key", "keys:group", "keys:pad_bits", "keys:held"]:
				continue
			out.append(n)
	return out


## the text on the screen, one line per row, spaces squeezed
func _screen() -> String:
	var rows := PackedStringArray()
	for row in TextLayer.ROWS:
		var line := ""
		for col in TextLayer.COLS:
			var g := screen.text.glyph_at(col, row)
			line += String.chr(g) if g > 0x20 and g < 0x7f else (String.chr(g - 0xa1 + 0xff61) if g >= 0xa1 and g <= 0xdf else " ")
		line = " ".join(line.split(" ", false))
		if line != "":
			rows.append(line)
	return " / ".join(rows)


func say(s: String) -> void:
	print("[%d] %s" % [polls, s])


func _chr() -> Character:
	return game.st.chr


func _status() -> String:
	var c := _chr()
	var keys := ""
	for it in range(0x4a, 0x52):
		if game.chara.has_item(it) >= 0:
			keys += "WYGPKBUR"[it - 0x4a]
	if game.chara.has_item(BLADE) >= 0:
		keys += "+blade"
	if game.chara.has_item(EX_CARD) >= 0:
		keys += "+EX"
	return "F%d (%d,%d) HP %d/%d HC %d BP %d CR %d AC %d POW %d TEC %d [%s]" % [game.st.floor, game.st.pos_x, game.st.pos_y,
			c.hp, c.hp_max, c.hc, c.bp, c.credits, c.ac, c.pow, c.tec, keys]


# ------------------------------------------------------------------ answering prompts

func _poll() -> void:
	polls += 1
	if polls % 500000 == 0:
		say("status: %s goal %s %s deaths %d states %d" % [_status(), _goal, _goal_cell, deaths, _snaps.size()])
	if polls > limit:
		say("poll limit reached: " + _status())
		if replay.is_empty():
			var f := FileAccess.open(out_dir.path_join("recording.bin"), FileAccess.WRITE)
			f.store_var({"keys": _rec_keys, "holds": _rec_holds, "restores": _rec_restores, "polls": polls})
		game.sys.halt()
		quit(1)
		return
	if not _pending.is_empty() or won:
		return
	if game.st.game_mode == 4 and polls % 32 != 0:
		return  # a fight polls the keyboard hundreds of times a tick: look now and then
	var w := _waiting()
	if "town:game_over" in w:
		_died()
		return
	if "ending:run_ending" in w:
		if not won:
			say("the ending: " + _status())
			_end_at = game.sys.clock + 30000000  # (the video films half a minute of it)
		won = true
		if video == "":
			game.sys.halt()
			return
		if w[0] in ["ui:wait_space", "ui:wait_key"]:
			_push(Keys.K_SPACE)
		return
	_keep_state(w)
	var sig := " < ".join(w.slice(0, 6))
	var fresh := sig != _last_sig
	if fresh:
		_last_sig = sig
		_seq.clear()
		if log_waits:
			say("%s | %s" % [sig, _screen().substr(0, 240)])
	var top := w[0] if not w.is_empty() else ""
	if fresh and "shops:_give_item" in w and video != "":
		_slow(6.0)
	if top in ["ui:drain_keys", "common:wait_eat_keys", "common:beep_eat_keys", "ui:hold_pause"]:
		return  # it empties the queue: nothing to answer
	if not _seq.is_empty():
		_push(_seq.pop_front())
		return
	var k := _answer(w, fresh)
	if k > 0:
		_push(k)


## a key for the game, recorded for the replay (see --replay)
func _push(k: int) -> void:
	game.keys.push(k)
	_rec_keys.append([polls, k])


func _type(s: String) -> void:
	for c in s:
		_seq.append(Keys.K_RIGHT if c == " " else c.unicode_at(0))
	_seq.append(Keys.K_SPACE)


## the key for what the game waits for (0: none)
func _answer(w: PackedStringArray, fresh: bool) -> int:
	var top := w[0]
	match top:
		"ui:wait_space":
			return Keys.K_SPACE
		"ui:line_input":
			if fresh:
				_type(_text_for(w))
				return _seq.pop_front()
			return 0
		"ui:choose":
			var want := _choice_for(w)
			if fresh and want == 2:
				_seq.append(Keys.K_SPACE)
				return Keys.K_RIGHT if ("ui:yes_no" in w or "shops:give" in w) else Keys.K_DOWN
			return Keys.K_SPACE if fresh else 0
		"ui:menu_poll":
			# (decided once per menu: moving the cursor polls again)
			if fresh or _menu_want < 0:
				_menu_want = _menu_for(w)
			var want := _menu_want
			if want <= 0:
				_menu_want = -1  # (the BIAS loop: decide again at its next poll)
				return 0
			if game.ui.menu_sel == want:
				_menu_want = -1
				if w.size() > 1 and w[1] == "dungeon:dungeon_loop":  # (a command used: counted, see _dungeon_command)
					var key := "%s %d" % [_place(), want]
					_cmd_tries[key] = int(_cmd_tries.get(key, 0)) + 1
				return Keys.K_SPACE
			return Keys.K_DOWN
		"items:pick_item":
			if fresh:
				_pick_p = 0
			var want := _pick_for(w)
			if want < 0:
				return Keys.K_ESC
			if _pick_p < want:
				_pick_p += 1
				return Keys.K_DOWN
			return Keys.K_SPACE
		"dungeon:_open_door":
			return 0x30  # (the door throws one key away before the password)
	if fresh:
		say("waiting: %s | %s" % [" < ".join(w.slice(0, 6)), _screen().substr(0, 200)])
	return Keys.K_SPACE


## a name, a password, an amount to type
func _text_for(w: PackedStringArray) -> String:
	if "town:_enter_name" in w:
		return NAME
	if "dungeon:_open_door" in w:
		var code := (game.st.cell_event & 0x3f) - 0x14
		return game.dungeon._password(code)
	if "shops:_treat" in w:
		var c := _chr()
		var need := 0
		match game.shops._treat_field:
			&"hp": need = c.hp_max - c.hp
			&"agl": need = c.agl_max - c.agl
			&"pow": need = c.pow_max - c.pow
			&"tec": need = c.tec_max - c.tec
			&"iq": need = c.iq_max - c.iq
		return str(mini(need * 5, c.credits - c.credits % 5))
	if "shops:_give_gold" in w:
		return "0"
	return ""


## 1 (the first choice: Yes, Newcomer...) or 2
func _choice_for(w: PackedStringArray) -> int:
	if "town:_roster_full" in w:
		return 1  # erase one (the disk's sample screamers)
	if "events:_stairs_up" in w or "events:_elevator_up" in w or "events:_stairs_down" in w or "events:_elevator_down" in w:
		var r := _route()
		return 1 if r.size() >= 2 and r[1].x != game.st.floor else 2
	if "events:_tower_exit" in w:
		return 1 if _goal.begins_with("town") else 2
	if "shops:give" in w:
		return 2  # an item, not gold
	if "shops:_buy" in w:
		if not _buy_confirmed:
			_buy_confirmed = true
			return 1
		return 2
	return 1


## the menu item wanted (1-based), 0 to wait
func _menu_for(w: PackedStringArray) -> int:
	if "dungeon:dungeon_loop" in w and w[1] == "dungeon:dungeon_loop":
		return _dungeon_command()
	if "town:town_menu" in w and w[2] == "town:town_menu":
		return _town_plan()
	if "town:_bias_gate" in w:
		if _next_to_unequip() >= 0:
			return 5
		if _next_to_equip() >= 0:
			return 4
		return 1
	if "shops:frd_shop" in w:
		if game.chara.has_item(FRD) < 0:
			return 2
		if _chr().bp > 0:
			return 1
		_town_done["frd"] = true
		return 4
	if "shops:hospital" in w:
		var c := _chr()
		if c.poison != 0 and c.credits >= 100 and not _town_done.has("antidote"):
			_town_done["antidote"] = true
			return 6
		var order := [[&"tec", 5], [&"pow", 3], [&"hp", 1], [&"agl", 2]]
		if c.hp * 5 < c.hp_max * 3:
			order = [[&"hp", 1], [&"tec", 5], [&"pow", 3], [&"agl", 2]]
		for s in order:
			if int(c.get(s[0])) < int(c.get(String(s[0]) + "_max")) and c.credits >= 5 and not _town_done.has(s[0]):
				_town_done[s[0]] = true
				return s[1]
		_town_done["doctor"] = true
		return 8
	if "shops:weapon_shop" in w:
		if not _bought and _to_buy() > 0:
			_bought = true
			_buy_confirmed = false
			return 1
		_town_done["shop"] = true
		return 4
	if "shops:bar" in w:
		return 0x7fff  # (not used)
	return 1


## the index in the item list (-1: none, ESC)
func _pick_for(w: PackedStringArray) -> int:
	var list: Array[int] = game.items._list
	if "items:equip_item" in w:
		return _next_to_equip()
	if "items:unequip_item" in w:
		return _next_to_unequip()
	if "shops:_buy" in w:
		return list.find(_to_buy())
	if "items:use_item" in w:
		var want := _use
		_use = 0
		for i in list.size():
			if (list[i] & 0x7f) == want:
				return i
		return -1
	if "shops:_give_item" in w:
		var want: int = WANTS.get(game.st.hunter, 0)
		for i in list.size():
			if (list[i] & 0x7f) == want:
				return i
	return -1


# ------------------------------------------------------------------ the town

func _town_plan() -> int:
	var c := _chr()
	if _town_done.is_empty():
		say("town: " + _status())
		if checkpoint != "":
			var f := FileAccess.open(checkpoint, FileAccess.WRITE)
			f.store_var({"where": "town", "state": SaveGame.snapshot(game), "roster": saved, "polls": polls})
		_deaths_here = 0
	if game.chara.has_item(FRD) < 0 or (c.bp > 0 and not _town_done.has("frd")):
		return 2
	var hurt := c.hp < c.hp_max or c.poison != 0 or c.pow < c.pow_max or c.tec < c.tec_max or c.agl < c.agl_max
	if hurt and c.credits >= 5 and not _town_done.has("doctor"):
		return 3
	if not _town_done.has("shop") and _to_buy() > 0:
		_bought = false
		return 5
	if c.hp * 4 < c.hp_max * 3:
		if c.credits < 5:
			say("too poor to be treated: " + _status())
		elif not _town_done.has("doctor"):
			return 3
	# off to BIAS
	_town_done.clear()
	_retreat = false

	_goal = ""
	return 1


## the best thing the weapon shop has that's worth buying now (0: none)
func _to_buy() -> int:
	var c := _chr()
	var best := 0
	var best_gain := 0
	var keep := 100  # (the doctor comes first: see _town_plan)
	for e: Dictionary in game.data.items:
		if not (int(e["shops"]) & 1):
			continue
		var id: int = e["id"]
		var kind: int = e["kind"]
		var price: int = e["price"]
		if price + keep > c.credits or kind < 1 or kind > 6:
			continue
		var have := _best_owned(kind)
		var gain: int = int(e["value"]) - have
		if kind <= 2:
			gain = int(e["value"]) - maxi(_best_owned(1), _best_owned(2))
			if kind == 1:
				gain += 10  # a gun shoots across the field
		if gain > best_gain:
			best_gain = gain
			best = id
	return best


## the best value among owned items of a kind (weapons: 1 gun, 2 hand-held; 3..6 armour)
func _best_owned(kind: int) -> int:
	var c := _chr()
	var v := 0
	for i in c.inv_count():
		var it := c.inv(i) & 0x7f
		if game.chara.item_kind(it) == kind:
			v = maxi(v, game.chara.item_value(it))
	return v


## the inventory index of something to equip (better than what's on), -1 if none
func _next_to_equip() -> int:
	var c := _chr()
	if c.inv(0) == 0:
		return -1
	# the FRD first
	for i in c.inv_count():
		if (c.inv(i) & 0x7f) == FRD and not (c.inv(i) & Character.EQUIPPED):
			return i
	for kind in [1, 2, 3, 4, 5, 6]:
		var best := -1
		var best_v := -1
		var on_v := -1
		for i in c.inv_count():
			var it := c.inv(i)
			var k := game.chara.item_kind(it & 0x7f)
			var slot_kind := 1 if k <= 2 else k
			if slot_kind != (1 if kind <= 2 else kind) or k < 1 or k > 6:
				continue
			var v := game.chara.item_value(it & 0x7f) + (10 if k == 1 else 0)
			if it & Character.EQUIPPED:
				on_v = v
			elif v > best_v:
				best_v = v
				best = i
		if best >= 0 and on_v < 0:
			return best
	return -1


## the inventory index of something on that something better could replace, -1 if none
func _next_to_unequip() -> int:
	var c := _chr()
	for i in c.inv_count():
		var it := c.inv(i)
		if not (it & Character.EQUIPPED):
			continue
		var k := game.chara.item_kind(it & 0x7f)
		if k < 1 or k > 6:
			continue
		var v := _gear_value(it & 0x7f)
		for j in c.inv_count():
			var o := c.inv(j)
			var ko := game.chara.item_kind(o & 0x7f)
			if o & Character.EQUIPPED or ko < 1 or ko > 6:
				continue
			if (ko <= 2) == (k <= 2) and (ko <= 2 or ko == k) and _gear_value(o & 0x7f) > v:
				return i
	return -1


func _gear_value(item: int) -> int:
	return game.chara.item_value(item) + (10 if game.chara.item_kind(item) == 1 else 0)


# ------------------------------------------------------------------ BIAS: commands

func _dungeon_command() -> int:
	var cmd := _dungeon_command_wanted()
	if cmd == 0:
		return 0
	var key := "%s %d" % [_place(), cmd]
	var n := int(_cmd_tries.get(key, 0))
	if n >= 4:
		if n == 4:
			say("command %d does nothing at %s: %s" % [cmd, _place(), _status()])
			_cmd_tries[key] = 5
		_use = 0
		return 0
	return cmd


## (counted when the menu item is chosen, see _menu_for)
func _dungeon_command_wanted() -> int:
	var st := game.st
	if _use != 0:
		return 6
	if st.floor_item != 0 and st.chr.inv_full == 0 and _wanted_item(st.floor_item):
		return 2
	if st.hunter != 0 and _has(WANTS.get(st.hunter, -1)):
		return 7
	if _next_to_equip() >= 0:
		return 4
	return 0


func _has(item: int) -> bool:
	return item > 0 and game.chara.has_item(item) >= 0


func _wanted_item(item: int) -> bool:
	var k := game.chara.item_kind(item)
	if k == 8:
		return true  # the pendants
	if k >= 1 and k <= 6:
		var v := game.chara.item_value(item)
		return v > _best_owned(k) and v > maxi(_best_owned(1), _best_owned(2)) * int(k <= 2)
	return item in [0x3d, 0x3e, 0x3f, 0x44, 0x45, 0x3a, 0x3b, 0x36, 0x33, 0x37]


# ------------------------------------------------------------------ the keypad

## a read of the key matrix: decide what to hold (walking, a pit, a fight)
func _matrix() -> void:
	_reads += 1
	if not _pending.is_empty() or won:
		return
	var w := _waiting()
	if w.is_empty():
		return
	# one decision per read of the keypad (it reads two groups of the matrix), or of the fight keys
	var at := "%d %s" % [game.sys.clock, w[1] if w.size() > 1 else ""]
	if at == _matrix_at:
		return
	_matrix_at = at
	if w[0] == "ui:numpad" and w.size() > 1 and w[1] == "dungeon:dungeon_loop":
		_keep_state(w)
		_hold(_walk())
	elif "events:_pit" in w and w[0] == "ui:numpad":
		_hold([&"open_door"])
	elif w[0] == "combat:_read_controls":
		_hold(_fight())
	elif w[0] == "ui:numpad" and w.size() > 1 and w[1] == "ui:hold_pause":
		pass  # keep what's held (a pause after a step)
	else:
		_hold([])


func _hold(actions: Array) -> void:
	var d := {}
	for a in actions:
		d[a] = true
	if d.keys() != game.keys.scripted.keys():
		_rec_holds.append([_reads, actions])
	game.keys.scripted = d


# ------------------------------------------------------------------ fighting

func _fight() -> Array:
	var cb := game.combat
	var st := game.st
	var c := _chr()
	_fights += 1
	if trace_from >= 0 and polls >= trace_from and cb._x == 0x25 and _fight_log != game.sys.clock / 100000000:
		_fight_log = game.sys.clock / 100000000
		say("fight %s (hp %d pow %d) at %s" % [st.mon.name, st.mon.hp, st.mon.pow, _status()])
	var me := cb._x
	var mon_l: int = cb._mon_x
	var mon_r: int = (cb._mon_x + st.mon.width) & 0xff
	var left := mon_r <= me
	var gap := me - mon_r if left else mon_l - (me + 4)
	if st.monster != BOSS and (c.hp * 4 < c.hp_max or _on_mission()):
		return [&"flee"]  # (on the way to the Samurai or the guardian: no time for the others)
	var reach := 30 if cb.weapon_kind == 1 else (6 if cb.weapon_kind == 2 else 2)
	var facing_ok := (cb._facing == 0xff) == left
	var danger: bool = cb._mon_shot != 0 and absi(int(cb._mon_shot_col) - me) < 10
	if log_waits and (_fights < 10 or _fights % 20 == 0):
		say("fight: me %d mon %d-%d gap %d facing %d shot %d mon_shot %d mon hp %d kind %x wk %d my hp %d" % [me, mon_l, mon_r, gap, cb._facing, cb._shot, cb._mon_shot, st.mon.hp, st.mon.kind, cb.weapon_kind, c.hp])
	if danger:
		return [&"back", &"defend"]  # crouch and guard
	if not facing_ok or gap > reach:
		return [&"turn_left" if left else &"turn_right"]
	return [&"back", &"attack"]


# ------------------------------------------------------------------ walking

## the floor the plan wants to be on (stairs / elevators answer to it)
func _wants_floor() -> int:
	return _goal_cell.x if _goal_cell.x > 0 else game.st.floor


func _place() -> Vector3i:
	return Vector3i(game.st.floor, game.st.pos_x, game.st.pos_y)


## what to hold in the BIAS loop: the next step of the route to the goal
func _walk() -> Array:
	var st := game.st
	var here := _place()
	if here == _last_place and _tried >= 0 and st.facing == (_tried & 3):
		_blocked[_tried] = int(_blocked.get(_tried, 0)) + 1
	_tried = -1
	if here != _last_place:
		_visits[here] = int(_visits.get(here, 0)) + 1
		_last_place = here
		_stuck = 0
		_goal_steps += 1
		if _goal_steps > maxi(150, _goal_len * 3) and not _goal.begins_with("town"):
			_given_up[_goal_cell] = polls + 5000000
			say("giving up on %s %s" % [_goal, _goal_cell])
			_goal = ""
	else:
		_stuck += 1
	_log_every += 1
	if _log_every % 20000 == 0:
		say("walking: %s goal %s %s" % [_status(), _goal, _goal_cell])
	if _dungeon_command() > 0:
		return []  # (the command menu: see _dungeon_command)
	if game.sys.clock - _last_yield > 60000000:
		_last_yield = game.sys.clock
		_yield_next = true  # (the engine's turn: see now_us)
		return []
	if _goal == "town" and here == TOWER_EXIT:
		# the exit asks when facing its door
		for d in 4:
			if st.map.b(st.cell_off + d) & 0x20:
				if st.facing == d:
					return [&"turn_right"] if _stuck % 8 == 7 else []  # (asked once per facing)
				var t := (d - st.facing) & 3
				return [&"turn_right"] if t == 1 else ([&"turn_left"] if t == 3 else [&"back"])
	if _goal.begins_with("explore here") and _goal_cell.x != st.floor:
		_goal = ""
	if st.hunter != _last_hunter:
		_last_hunter = st.hunter
		if st.hunter != 0:
			say("met hunter %d: %s" % [st.hunter, _status()])
			if st.hunter == 8 and video != "":
				_slow(25.0)
	if _goal_cell.y < 0 and _goal_cell.x == st.floor and not _goal.begins_with("explore"):
		_goal = ""  # (on the floor: now the cell itself)
	if _goal == "" or _goal_cell == here or _stuck > 40 or (not _goal.begins_with("town") and _needs_town()):
		_choose_goal()
		_goal_len = _route().size()
	var route := _route()
	var step := -1
	if route.size() >= 2:
		var nxt: Vector3i = route[1]
		if nxt.x != st.floor:
			# on stairs or a lift the route takes: they ask when stepped onto, so off and back on
			for d in 4:
				if _can_pass(Vector2i(st.pos_x, st.pos_y), d):
					step = d
					break
		else:
			for d in 4:
				if Vector2i(st.pos_x, st.pos_y) + DX[d] == Vector2i(nxt.y, nxt.z):
					step = d
	if step < 0 and not _goal.begins_with("explore here"):
		# no way there from here: look around this part of the floor for a while
		_given_up[_goal_cell] = polls + 3000000
		_goal = "explore here"
		_goal_cell = _explore_target(st.floor)
		_goal_steps = 0
		var r2 := _route()
		if r2.size() >= 2 and r2[1].x == st.floor:
			for d in 4:
				if Vector2i(st.pos_x, st.pos_y) + DX[d] == Vector2i(r2[1].y, r2[1].z):
					step = d
	if step < 0:
		# nowhere to go: any open way
		for d in [_rng.randi_range(0, 3), 0, 1, 2, 3]:
			if _can_pass(Vector2i(st.pos_x, st.pos_y), d):
				step = d
				break
	if trace_from >= 0 and polls >= trace_from and _chr().hp < _last_hp - 15:
		say("hp dropped %d -> %d: %s event %x" % [_last_hp, _chr().hp, _status(), st.cell_event & 0x3f])
	_last_hp = _chr().hp
	if trace_from >= 0 and polls >= trace_from and _log_every % 25 == 0:
		say("walk %s facing %d goal %s %s step %d route %s" % [_status(), st.facing, _goal, _goal_cell, step, str(route.slice(0, 4))])
	if step < 0:
		_choose_goal()
		return []
	if st.facing != step:
		_tried = -1
		var d := (step - st.facing) & 3
		return [&"turn_right"] if d == 1 else ([&"turn_left"] if d == 3 else [&"back"])
	var wall := st.map.b(st.cell_off + st.facing)
	_tried = _edge(st.floor, Vector2i(st.pos_x, st.pos_y), st.facing)
	if (wall & 3) == 3:
		if (wall & 0x20) and (st.cell_event & 0x3f) == 0x14 + 4:
			_use = EX_CARD  # (the command menu: Use, the EX card)
			return []
		return [&"open_door"]
	return [&"forward"]


func _on_mission() -> bool:
	return (_has(0x51) and not _has(BLADE) and _safe_floor() >= 5) or (_has(BLADE) and _ready_for_boss())


func _needs_town() -> bool:
	var c := _chr()
	if _on_mission():
		return c.hp * 4 < c.hp_max
	var next_class: int = game.data.table("shops_class_bp")[mini(c.hc, 25)] - c.bp_total
	return _retreat or c.hp * 2 < c.hp_max or c.poison != 0 or c.bp >= maxi(next_class, 300 + c.hc * 100)


## pick what to do next in BIAS
func _choose_goal() -> void:
	var c := _chr()
	var st := game.st
	_stuck = 0
	_goal_steps = 0
	if _needs_town():
		_goal = "town"
		_goal_cell = TOWER_EXIT
		return
	if _has(BLADE) and _ready_for_boss():
		_goal = "the guardian"
		_goal_cell = Vector3i(6, 7, 16) if st.floor == 6 else Vector3i(6, -1, -1)
		return
	if _has(0x51) and not _has(BLADE) and _safe_floor() >= 5:
		_goal = "the samurai"
		_goal_cell = Vector3i(5, 17, 5) if st.floor == 5 else Vector3i(5, -1, -1)
		return
	var safe := _safe_floor()
	# explore: the least visited reachable cell on the floor wanted (one floor at a time)
	var f := safe
	if st.floor < safe:
		f = st.floor + 1
	elif st.floor > safe:
		f = st.floor - 1
	if int(_given_up.get(Vector3i(f, -1, -1), 0)) > polls:
		f = st.floor
	_goal = "explore F%d" % f
	_goal_cell = _explore_target(f)


func _ready_for_boss() -> bool:
	var c := _chr()
	return c.hc >= 18 and c.tec >= 180 and c.pow >= 150


## the deepest floor the screamer is strong enough for (by hunter class)
func _safe_floor() -> int:
	var hc := _chr().hc
	if hc >= 12: return 5
	if hc >= 8: return 4
	if hc >= 5: return 3
	if hc >= 2: return 2
	return 1


func _explore_target(f: int) -> Vector3i:
	if f != game.st.floor:
		return Vector3i(f, -1, -1)
	var best := Vector3i(f, game.st.pos_x, game.st.pos_y)
	var best_v := 1 << 30
	var reach := _reachable()
	for p: Vector3i in reach:
		var v: int = int(_visits.get(p, 0)) * 50 + int(reach[p]) + _rng.randi_range(0, 30)
		if v < best_v and p != _place() and int(_given_up.get(p, 0)) < polls:
			best_v = v
			best = p
	return best


## BFS on the floor from here: cell -> distance
func _reachable() -> Dictionary:
	var st := game.st
	var start := Vector2i(st.pos_x, st.pos_y)
	var dist := {start: 0}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		for d in 4:
			if not _can_pass(p, d):
				continue
			var n: Vector2i = p + DX[d]
			if dist.has(n):
				continue
			dist[n] = dist[p] + 1
			q.append(n)
	var out := {}
	for p: Vector2i in dist:
		out[Vector3i(st.floor, p.x, p.y)] = dist[p]
	return out


static func _edge(f: int, p: Vector2i, d: int) -> int:
	return ((f * 32 + p.x) * 32 + p.y) * 4 + d


## can the screamer go from cell p through its wall d (on this floor)
func _can_pass(p: Vector2i, d: int) -> bool:
	return _pass(game.st.floor, p, d)


## the map of a floor: as it is now for this one, as the disk has it for the others
func _map_of(f: int) -> FloorMap:
	if f == game.st.floor:
		return game.st.map
	if not _floor_maps.has(f):
		_floor_maps[f] = FloorMap.new(game.data.floor_bytes(f))
	return _floor_maps[f]


## the floors the event of a cell leads to (stairs, lifts)
func _links(f: int, p: Vector2i) -> int:
	var ev := _map_of(f).b(FloorMap.cell_off(p.x, p.y) + FloorMap.EVENT) & 0x3f
	match ev:
		7: return f + 1
		8: return f - 1
		9: return 4 if f == 2 else 5
		0x0a: return 2 if f == 4 else 1
	return 0


## the way to the goal across floors: the cells, from here (empty: no way); kept while it's followed
func _route() -> Array[Vector3i]:
	var here := _place()
	if _path_goal == _goal_cell and _path_blocked == _blocked.size() and _path_has == _keys_held():
		var k := _path.find(here)
		if k >= 0 and k + 1 < _path.size():
			return _path.slice(k)
	_path = _plan()
	_path_goal = _goal_cell
	_path_blocked = _blocked.size()
	_path_has = _keys_held()
	return _path


## what changes which doors open
func _keys_held() -> int:
	return int(_has(BLADE)) + 2 * int(_has(EX_CARD))


func _plan() -> Array[Vector3i]:
	var p := _plan_with(true)  # round the traps and the guardians if there's a way
	return p if not p.is_empty() else _plan_with(false)


## a cell best kept away from: a trap, a guardian (a monster always there)
func _avoid(c: Vector3i) -> bool:
	var map := _map_of(c.x)
	var off := FloorMap.cell_off(c.y, c.z)
	var ev := map.b(off + FloorMap.EVENT) & 0x3f
	if ev in [2, 3, 4, 5, 6, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x11]:
		return true
	return (map.b(off + FloorMap.ITEM) & 0x0f) == 0x0f and map.b(off + FloorMap.MONSTER) != 0 and c != _goal_cell


func _plan_with(avoid: bool) -> Array[Vector3i]:
	var st := game.st
	var start := Vector3i(st.floor, st.pos_x, st.pos_y)
	var prev := {start: start}
	var q: Array[Vector3i] = [start]
	var found := Vector3i(-1, -1, -1)
	while not q.is_empty():
		var c: Vector3i = q.pop_front()
		if c != start and (c == _goal_cell or (_goal_cell.y < 0 and c.x == _goal_cell.x)):
			found = c
			break
		var p := Vector2i(c.y, c.z)
		for d in 4:
			if not _pass(c.x, p, d):
				continue
			var n := Vector3i(c.x, p.x + DX[d].x, p.y + DX[d].y)
			if not prev.has(n) and not (avoid and _avoid(n)):
				prev[n] = c
				q.append(n)
		var to := _links(c.x, p)
		if to >= 1 and to <= 6 and (to != 6 or _goal_cell.x == 6):
			var n := Vector3i(to, c.y, c.z)
			if not prev.has(n):
				prev[n] = c
				q.append(n)
	var out: Array[Vector3i] = []
	if found.x < 0:
		return out
	var c := found
	while c != start:
		out.push_front(c)
		c = prev[c]
	out.push_front(start)
	return out


func _pass(f: int, p: Vector2i, d: int) -> bool:
	var n: Vector2i = p + DX[d]
	if n.x < 0 or n.y < 0 or n.x >= 22 or n.y >= 22:
		return false
	if not _blocked.is_empty() and int(_blocked.get(_edge(f, p, d), 0)) >= 6:
		return false  # (tried, and it didn't let through)
	var map := _map_of(f)
	var off := FloorMap.cell_off(p.x, p.y)
	var wall := map.b(off + d)
	if (wall & 0x0b) == 8:
		return false  # a wall that turns solid when walked into
	if not (wall & 1):
		return true
	if (wall & 3) != 3 or (wall & 4):
		return false
	if not (wall & 0x20):
		return true
	var code := (map.b(off + FloorMap.EVENT) & 0x3f) - 0x14
	if code < 0:
		return true
	if code == 4:
		return _has(EX_CARD)  # (no password: the EX card lifts the lock)
	if code >= 5 and not game.sys.pendant_fix:
		return _has(BLADE) != (code == 8)
	return true


# ------------------------------------------------------------------ going back on death

func _keep_state(w: PackedStringArray) -> void:
	# (the game's rest hint is set while it waits for the next frame; here: its BIAS loop and town menu)
	var rest := &""
	if w.size() > 1 and w[1] == "dungeon:dungeon_loop" and w[0] in ["ui:menu_poll", "ui:numpad"]:
		rest = &"bias"
	elif w.size() > 2 and w[0] == "ui:menu_poll" and w[2] == "town:town_menu":
		rest = &"town"
	if rest == &"" or _chr().hp * 2 < _chr().hp_max or _chr().poison != 0:
		return  # (only states worth going back to)
	var st := game.st
	var key := "%s %d %d %d %d" % [rest, st.floor, st.pos_x, st.pos_y, st.facing]
	if key == _snap_key:
		return
	_snap_key = key
	_snaps.append({"where": "bias" if rest == &"bias" else "town", "state": SaveGame.snapshot(game)})
	if _snaps.size() > 40:
		_snaps.pop_front()


func _died() -> void:
	deaths += 1
	_deaths_here += 1
	var back := mini(_snaps.size(), 2 + _deaths_here * 2)
	say("died (%d): %s; going back %d steps" % [deaths, _status(), back])
	if _snaps.is_empty():
		say("nothing to go back to")
		quit(3)
		return
	var s: Dictionary = _snaps[_snaps.size() - back]
	_snaps = _snaps.slice(0, _snaps.size() - back + 1)
	_snap_key = ""
	_retreat = true

	_goal = ""
	_town_done.clear()
	_pending = s
	_rec_restores.append([polls, s])
	game.sys.halt()

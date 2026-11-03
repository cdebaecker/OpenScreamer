## Boot sequence (fan-port notice, the attract demo, the game) and the flow targets.
class_name Program
extends Mod


## the game's start-up: initial values from its data segment
func boot() -> void:
	var b := PackedByteArray(data.table("init_state"))
	st.game_mode = b[0]
	st.color4 = b[1]
	st.fx_samson = b[2]
	st.fx_brain = b[3]
	st.fx_tec = b[4]
	st.fx_responser = b[5]
	st.lamp_on = b[6]
	st.sound_barrier = b[7]
	st.trap_done = b[8]
	st.ring_flag = b[9]
	st.door_unlocked = b[0x0a]
	st.need_redraw = b[0x0b]
	st.monster = b[0x0c]
	st.floor_item = b[0x0d]
	st.floor_item_poison = b[0x0e]
	st.facing = b.decode_u16(0x11)
	st.floor = b[0x13]
	st.pos_x = b[0x14]
	st.pos_y = b[0x15]
	st.cell = b.slice(0x16, 0x1e)
	st.stood = b[0x1e]
	st.door_msg = b[0x1f]
	st.hunter = b[0x20]
	st.idle_count = b.decode_u16(0x21)
	st.revealed_walls = b[0x23]
	st.mon = Monster.new(b.slice(0x25, 0x25 + Monster.SIZE))
	st.hide_hunter = data.table("init_hide_hunter")[0]
	st.map = FloorMap.new(PackedByteArray(data.table("init_map")))
	st.chr = Character.new(PackedByteArray(data.table("init_chr")))
	st.rng_seed = data.table("init_rng_seed")[0]
	var beep: Array = data.table("init_beep")
	sys.beep_on = beep[0]
	sys.beep_off = beep[1]
	sys.beep_count = beep[2]
	txt.colour = 7
	screen.reset_palette()


## Targets of the original's "reset the stack and jump" exits (mov sp, / jmp ...).
func _run_target(target: StringName) -> void:
	match target:
		&"registration":  # registration at the BIAS gate (start of the game)
			await town.registration()
		&"registration_restart":  # back to the "new or registered?" question
			await town.registration_restart()
		&"town":  # enter the town
			await town.run_town()
		&"town_menu":  # town command menu
			await town.town_menu()
		&"dungeon":  # enter BIAS
			await dungeon.run_dungeon()
		&"dungeon_loop":  # back to the BIAS loop
			await dungeon.dungeon_loop()
		&"game_over":  # death
			await town.game_over()
		&"ending":  # final boss defeated
			await ending.run_ending()
		&"combat":  # combat
			await combat.run_combat()
		&"bar":  # the bar
			await shops.bar()
		_:
			push_error("flow target not registered: " + target)
			sys.halt()


## run the game's flow, following the original's stack-resetting jumps
func run_main() -> void:
	boot()
	await run_from(&"registration")


## the game's flow from a target, with the state as it is (a loaded saved game)
func run_from(next: StringName) -> void:
	while true:
		current = next
		await _run_target(next)
		if sys.unwinding:
			sys.unwinding = false
			next = sys.jump_target
		else:
			next = &"registration"


## the flow target running now (&"title" before the game starts): a hint for the host (ambience,
## saves), not game state
var current := &"title"


## the splash and the demo, while they run: unwired with the game's modules (their references to
## each other would keep a stopped game in memory)
var _extra: Array[Mod] = []


func run_program(skip_splash := false, skip_demo := false) -> void:
	if not skip_splash:
		var s := Splash.new()
		s.wire(self)
		_extra.append(s)
		await s.show()
		_drop(s)
	if not skip_demo:
		var d := Demo.new()
		d.wire(self)
		_extra.append(d)
		await d.run()
		_drop(d)
	await run_main()


func _drop(m: Mod) -> void:
	m.unwire()
	_extra.erase(m)


func unwire() -> void:
	for m in _extra:
		m.unwire()
	_extra.clear()
	super()

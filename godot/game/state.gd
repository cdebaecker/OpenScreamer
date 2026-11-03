## Everything the game remembers between routines: the screamer, where they stand in BIAS, the
## monster being fought and the running effects.  (In the original: the data segment from
## and its game state.)
class_name GameState
extends RefCounted

## 1 registration, 2 town, 3 BIAS (dungeon), 4 combat
var game_mode := 0
## current colour of palette entry 4 (walls and other pure green)
var color4 := 0
# drug effects running out
var fx_samson := 0
var fx_brain := 0
var fx_tec := 0
var fx_responser := 0
var lamp_on := 0
var sound_barrier := 0  # steps left
var trap_done := 0
var ring_flag := 0
var door_unlocked := 0
var need_redraw := 0
var monster := 0  # monster number met
var floor_item := 0
var floor_item_poison := 0
var facing := 0  # 0 N, 1 E, 2 S, 3 W
var floor := 0
var pos_x := 0
var pos_y := 0
## a copy of the current cell's 8 bytes (FloorMap layout)
var cell := PackedByteArray()
var stood := 0  # already handled the event of this cell
var door_msg := 0
var hunter := 0  # hunter (rival screamer) met
var idle_count := 0
var revealed_walls := 0
var hide_hunter := 0
var rng_seed := 0

var chr := Character.new()
var mon := Monster.new()
var map := FloorMap.new()


func _init() -> void:
	cell.resize(8)


## offset of the current cell in the map (the original keeps an address)
var cell_off: int:
	get: return FloorMap.cell_off(pos_x, pos_y)

var cell_wall_text: int:
	get: return cell[FloorMap.WALL_TEXT]
var cell_monster: int:
	get: return cell[FloorMap.MONSTER]
var cell_event: int:
	get: return cell[FloorMap.EVENT]
var cell_item: int:
	get: return cell[FloorMap.ITEM]


## the state as plain data, for comparing runs (scripted tests)
func canonical() -> Dictionary:
	return {
		"game_mode": game_mode, "color4": color4, "fx_samson": fx_samson, "fx_brain": fx_brain,
		"fx_tec": fx_tec, "fx_responser": fx_responser, "lamp_on": lamp_on, "sound_barrier": sound_barrier,
		"trap_done": trap_done, "ring_flag": ring_flag, "door_unlocked": door_unlocked,
		"need_redraw": need_redraw, "monster": monster, "floor_item": floor_item,
		"floor_item_poison": floor_item_poison, "facing": facing, "floor": floor, "pos_x": pos_x,
		"pos_y": pos_y, "cell": Array(cell), "stood": stood, "door_msg": door_msg, "hunter": hunter,
		"idle_count": idle_count, "revealed_walls": revealed_walls, "hide_hunter": hide_hunter,
		"rng_seed": rng_seed, "chr": Marshalls.raw_to_base64(chr.record),
		"mon": Marshalls.raw_to_base64(mon.record), "map": Marshalls.raw_to_base64(map.bytes),
	}

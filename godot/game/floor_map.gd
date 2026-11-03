## One floor of BIAS (an Fnn file): 24 x 24 cells of 8 bytes, then 512 bytes of extra data.
## Cell bytes: 0..3 the walls N, E, S, W (bit 0 closed, bit 1 door, bit 6 random door, bit 4/7
## writing), 4 wall writing, 5 monster, 6 event (bit 6 dark, bit 7 lit), 7 item (high nibble:
## placed item, low nibble: encounter rate).
## The map is changed while playing (random doors, defeated guardians), so it is kept as the
## original bytes; `b()` addresses them from the start of the map like the original does.
class_name FloorMap
extends RefCounted

const SIZE := 0x1400
const W := 0x18
const CELL := 8
const WALL_TEXT := 4
const MONSTER := 5
const EVENT := 6
const ITEM := 7

var bytes := PackedByteArray()


func _init(from: PackedByteArray = PackedByteArray()) -> void:
	bytes = from.slice(0, SIZE)
	bytes.resize(SIZE)


## offset of cell (x, y) from the start of the map
static func cell_off(x: int, y: int) -> int:
	return (y * W + x) * CELL


func b(off: int) -> int:
	return bytes[off & 0xffff] if (off & 0xffff) < SIZE else 0


func set_b(off: int, v: int) -> void:
	if (off & 0xffff) < SIZE:
		bytes[off & 0xffff] = v & 0xff

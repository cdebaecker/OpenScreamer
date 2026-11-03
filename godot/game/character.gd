## A registered screamer.  The record keeps the original 128-byte layout (one slot of the CHAR
## file), so rosters stay compatible with the original disk; fields are typed properties over it.
class_name Character
extends RefCounted

const SIZE := 0x80
const INV := 0x36  # carried items: item numbers, bit 7 set when equipped, 0-terminated
const INV_MAX := 0x1e  # 30 items: the 30th is at 53h (inv_full), its terminator at 54h
const EQUIPPED := 0x80

var record := PackedByteArray()

var name: String:
	get:
		var s := record.slice(0, 0x10)
		var z := s.find(0)
		return GameText.decode(s if z < 0 else s.slice(0, z))
	set(v):
		var b := GameText.encode(v)
		for i in 0x10:
			record[i] = b[i] if i < b.size() else 0
var hc: int:  # hunter class
	get: return record.decode_u16(0x10)
	set(v): record.encode_u16(0x10, v & 0xffff)
var ac: int:  # armour class
	get: return record.decode_u16(0x12)
	set(v): record.encode_u16(0x12, v & 0xffff)
var bp: int:  # beast points
	get: return record.decode_u16(0x14)
	set(v): record.encode_u16(0x14, v & 0xffff)
var hp: int:
	get: return record.decode_u16(0x16)
	set(v): record.encode_u16(0x16, v & 0xffff)
var agl: int:
	get: return record.decode_u16(0x18)
	set(v): record.encode_u16(0x18, v & 0xffff)
var pow: int:
	get: return record.decode_u16(0x1a)
	set(v): record.encode_u16(0x1a, v & 0xffff)
var tec: int:
	get: return record.decode_u16(0x1c)
	set(v): record.encode_u16(0x1c, v & 0xffff)
var iq: int:
	get: return record.decode_u16(0x1e)
	set(v): record.encode_u16(0x1e, v & 0xffff)
var hp_max: int:
	get: return record.decode_u16(0x20)
	set(v): record.encode_u16(0x20, v & 0xffff)
var agl_max: int:
	get: return record.decode_u16(0x22)
	set(v): record.encode_u16(0x22, v & 0xffff)
var pow_max: int:
	get: return record.decode_u16(0x24)
	set(v): record.encode_u16(0x24, v & 0xffff)
var tec_max: int:
	get: return record.decode_u16(0x26)
	set(v): record.encode_u16(0x26, v & 0xffff)
var iq_max: int:
	get: return record.decode_u16(0x28)
	set(v): record.encode_u16(0x28, v & 0xffff)
var luck: int:
	get: return record.decode_u16(0x2a)
	set(v): record.encode_u16(0x2a, v & 0xffff)
var credits: int:
	get: return record.decode_u16(0x2c)
	set(v): record.encode_u16(0x2c, v & 0xffff)
var poison: int:  # one bit per poison kind (1, 2, 4, 8, 10h)
	get: return record[0x2e]
	set(v): record[0x2e] = v & 0xff
var inv_full: int:
	get: return record[0x53]
	set(v): record[0x53] = v & 0xff
var bp_total: int:  # beast points earned since the last class-up
	get: return record.decode_u16(0x55)
	set(v): record.encode_u16(0x55, v & 0xffff)


func _init(from: PackedByteArray = PackedByteArray()) -> void:
	record = from.slice(0, SIZE)
	record.resize(SIZE)


func copy() -> Character:
	return Character.new(record)


## stat names usable with get()/set(), in the order the original indexes them
const STATS := [&"hp", &"agl", &"pow", &"tec", &"iq"]


# ------------------------------------------------------------------ inventory
# The list is 0-terminated inside the record like the original's; it holds up to INV_MAX items
# (the game refuses more once inv_full, the 30th, is set).

func inv_count() -> int:
	var n := 0
	while n < INV_MAX and record[INV + n] != 0:
		n += 1
	return n


## item number at index i (bit 7 set when equipped), 0 past the end
func inv(i: int) -> int:
	return record[INV + i]


func set_inv(i: int, item: int) -> void:
	record[INV + i] = item & 0xff


## index of item `id` (bit 7 ignored), -1 if not carried
func inv_find(id: int) -> int:
	id &= 0x7f
	var i := 0
	while i < INV_MAX and record[INV + i] != 0:
		if (record[INV + i] & 0x7f) == id:
			return i
		i += 1
	return -1


## append an item
func inv_add(item: int) -> void:
	var i := inv_count()
	record[INV + i] = item & 0xff
	record[INV + i + 1] = 0


## remove the item at index i (the rest move down)
func inv_remove(i: int) -> void:
	while true:
		var v := record[INV + i + 1]
		record[INV + i] = v
		if v == 0:
			break
		i += 1

## The monster being fought: its 40-byte record from its Gnn file.
class_name Monster
extends RefCounted

const SIZE := 0x28

var record := PackedByteArray()

var name: String:
	get:
		var s := record.slice(0, 0x10)
		var z := s.find(0)
		return GameText.decode(s if z < 0 else s.slice(0, z))
var tec: int:
	get: return record[0x10]
	set(v): record[0x10] = v & 0xff
var ac: int:
	get: return record[0x11]
	set(v): record[0x11] = v & 0xff
var bp: int:  # beast points it is worth
	get: return record.decode_u16(0x12)
	set(v): record.encode_u16(0x12, v & 0xffff)
var hp: int:
	get: return record.decode_u16(0x14)
	set(v): record.encode_u16(0x14, v & 0xffff)
var pow: int:
	get: return record[0x16]
	set(v): record[0x16] = v & 0xff
var poison: int:
	get: return record[0x17]
	set(v): record[0x17] = v & 0xff
var width: int:  # in 8-pixel columns
	get: return record[0x18]
	set(v): record[0x18] = v & 0xff
var kind: int:  # 10h: a low, flat monster
	get: return record[0x19]
	set(v): record[0x19] = v & 0xff


func _init(from: PackedByteArray = PackedByteArray()) -> void:
	record = from.slice(0, SIZE)
	record.resize(SIZE)

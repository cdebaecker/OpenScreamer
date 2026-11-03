## The roster (the original disk's CHAR file: 8 slots of 128 bytes, registered screamers first, a
## free slot starting with byte FFh) as the settings menu manages it: list, delete, replace.
class_name RosterFile
extends RefCounted

const SLOTS := 8
const BYTES := SLOTS * Character.SIZE


## a file the game can read: 8 slots, the registered ones first
static func valid(d: PackedByteArray) -> bool:
	if d.size() != BYTES:
		return false
	var free := false
	for i in SLOTS:
		var used := d[i * Character.SIZE] != 0xff
		if used and free:
			return false
		free = free or not used
	return true


## the registered screamers, in slot order
static func entries(d: PackedByteArray) -> Array[Character]:
	var out: Array[Character] = []
	if d.size() < BYTES:
		return out
	for i in SLOTS:
		if d[i * Character.SIZE] == 0xff:
			break
		out.append(Character.new(d.slice(i * Character.SIZE, (i + 1) * Character.SIZE)))
	return out


## remove slot i: the later slots move up and the last one is left free, as the game does it
static func delete(d: PackedByteArray, i: int) -> PackedByteArray:
	var out := d.slice(0, i * Character.SIZE)
	out.append_array(d.slice((i + 1) * Character.SIZE, BYTES))
	var free := PackedByteArray()
	free.resize(Character.SIZE)
	free.fill(0xff)
	out.append_array(free)
	return out


## one line for the menu: name, hunter class, HP, credits
static func describe(c: Character) -> String:
	return "%s   —   HC %d,  HP %d/%d,  $%d" % [c.name, c.hc, c.hp, c.hp_max, c.credits]

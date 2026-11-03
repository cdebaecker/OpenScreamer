## Rewind (settings, on by default): the game state at each of the last KEEP places the screamer
## stood in BIAS (a new cell or facing, at rest: Ui.rest), so that on death the player can go
## back a few steps instead.  The states are saved games (SaveGame.snapshot) kept in memory.
class_name Rewind
extends RefCounted

const KEEP := 20

var snaps: Array[Dictionary] = []
var _last := ""


## called every frame: a state when the game rests in BIAS somewhere new
func record(g: Game) -> void:
	if g.ui.rest != &"bias":
		return
	var st := g.st
	var key := "%s %d %d %d %d" % [st.chr.name, st.floor, st.pos_x, st.pos_y, st.facing]
	if key == _last:
		return
	_last = key
	snaps.append({"version": SaveGame.VERSION, "where": "bias", "name": st.chr.name, "floor": st.floor,
			"hp": st.chr.hp, "hp_max": st.chr.hp_max, "time": int(Time.get_unix_time_from_system()),
			"state": SaveGame.snapshot(g)})
	if snaps.size() > KEEP:
		snaps.pop_front()


## the states of a screamer, oldest first
func of(name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in snaps:
		if s["name"] == name:
			out.append(s)
	return out


## the state `steps` places back (1 = the last one), {} if there's none
func back(name: String, steps: int) -> Dictionary:
	var mine := of(name)
	if steps < 1 or steps > mine.size():
		return {}
	return mine[mine.size() - steps]


func clear() -> void:
	snaps.clear()
	_last = ""

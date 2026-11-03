## Saved games (an addition to the original, which only keeps the roster): the whole game state
## at a point where the game waits for the player at rest (the town's command menu, standing in
## BIAS; Ui.rest), kept in user://saves/.  Loading builds a new game with that state and enters the
## town or BIAS the way the game does (as when coming back to the cell; the cell's event runs again,
## as it does after turning on the spot).
class_name SaveGame
extends RefCounted

const DIR := "user://saves"
const VERSION := 1
const SLOTS := 5  # numbered slots; "quick" is the quick-save slot (F6 / F7)

## the modules whose own variables are game state (the services that aren't: data, art, keys, screen)
const MODULES := ["txt", "ui", "common", "items", "shops", "town", "dungeon", "events", "combat", "ending"]
## host hints and caches in those modules, not saved
const SKIP := ["typing", "rest", "input", "_frame_cells", "_view_pieces", "_vars_ready", "fogged",
		"cell_off", "cell_wall_text", "cell_monster", "cell_event", "cell_item"]


## where saves go (tests use another folder)
static var dir := DIR


static func path_of(slot: String) -> String:
	return dir.path_join("slot_%s.save" % slot)


## a value that can be written as it is (no objects or callables inside)
static func _plain(v: Variant) -> bool:
	match typeof(v):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_ARRAY:
			for x in v:
				if not _plain(x):
					return false
		TYPE_DICTIONARY:
			for k in v:
				if not _plain(k) or not _plain(v[k]):
					return false
	return true


static func _vars(o: Object) -> Dictionary:
	var out := {}
	for p in o.get_property_list():
		if not (p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) or p["name"] in SKIP:
			continue
		var v: Variant = o.get(p["name"])
		if _plain(v):
			out[p["name"]] = _copy(v)
	return out


## a value of its own: arrays, dictionaries and packed arrays are shared, not copied, when assigned
## (a state kept in memory, like Rewind's, would otherwise change with the game)
static func _copy(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	if typeof(v) >= TYPE_PACKED_BYTE_ARRAY and typeof(v) <= TYPE_PACKED_VECTOR4_ARRAY:
		return v.duplicate()
	return v


static func _set_vars(o: Object, vars: Dictionary) -> void:
	for k: String in vars:
		var cur: Variant = o.get(k)
		var v: Variant = vars[k]
		if cur is Array and v is Array:  # keep typed arrays typed
			(cur as Array).assign(_copy(v))
		elif typeof(cur) == typeof(v) or (cur is float and v is int):
			o.set(k, _copy(v))


## the game state now
static func snapshot(g: Game) -> Dictionary:
	var mods := {}
	for m: String in MODULES:
		mods[m] = _vars(g.get(m))
	var st := _vars(g.st)
	st.erase("chr")
	st.erase("mon")
	st.erase("map")
	return {
		"st": st, "chr": g.st.chr.record.duplicate(), "mon": g.st.mon.record.duplicate(), "map": g.st.map.bytes.duplicate(),
		"sys": {"clock": g.sys.clock, "beep_on": g.sys.beep_on, "beep_off": g.sys.beep_off, "beep_count": g.sys.beep_count},
		"modules": mods,
	}


## put a snapshot into a game that hasn't started
static func restore(g: Game, s: Dictionary) -> void:
	g.program.boot()
	_set_vars(g.st, s["st"])
	g.st.chr = Character.new(_copy(s["chr"]))
	g.st.mon = Monster.new(_copy(s["mon"]))
	g.st.map = FloorMap.new(_copy(s["map"]))
	var sy: Dictionary = s["sys"]
	for k: String in sy:
		g.sys.set(k, sy[k])
	var mods: Dictionary = s["modules"]
	for m: String in mods:
		if m in MODULES:
			_set_vars(g.get(m), mods[m])
	g.chara.load_roster()
	g.town.roster_count = g.chara.roster_count()


## where a game at rest goes on: the flow target to enter
static func target_of(where: StringName) -> StringName:
	return &"dungeon" if where == &"bias" else &"town"


## write the game (at rest) to a file; returns an error message, "" when saved
static func write(path: String, g: Game) -> String:
	if g.ui.rest == &"":
		return UiText.t("The game can be saved in the town's menu or standing in BIAS")
	var d := {
		"version": VERSION, "where": String(g.ui.rest), "name": g.st.chr.name, "floor": g.st.floor,
		"hp": g.st.chr.hp, "hp_max": g.st.chr.hp_max, "time": int(Time.get_unix_time_from_system()),
		"lang": g.data.lang, "state": snapshot(g),
	}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return UiText.t("Couldn't write the saved game")
	f.store_string(var_to_str(d))
	return ""


## a saved game's data, {} if there's none (or it can't be read)
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = str_to_var(FileAccess.get_file_as_string(path))
	if not d is Dictionary or d.get("version", 0) != VERSION or not d.has("state"):
		return {}
	return d


## one line for the menu
static func describe(d: Dictionary) -> String:
	if d.is_empty():
		return UiText.t("(empty)")
	var where := UiText.t("BIAS floor %d") % int(d["floor"]) if d["where"] == "bias" else UiText.t("Beast City")
	var when := Time.get_datetime_string_from_unix_time(int(d["time"]) + int(Time.get_time_zone_from_system()["bias"]) * 60, true)
	return "%s  —  %s,  HP %d/%d  —  %s" % [d["name"], where, int(d["hp"]), int(d["hp_max"]), when.substr(0, 16)]


## the roster must have the saved screamer (the town saves them into their slot); returns false
## when they're not there and there's no room
static func ensure_in_roster(g: Game) -> bool:
	if g.chara.find_in_roster() >= 0:
		return true
	var n := g.chara.roster_count()
	if n >= 7:
		return false
	g.chara.roster[n] = g.st.chr.copy()
	g.chara.save_roster()
	g.town.roster_count = n + 1
	return true

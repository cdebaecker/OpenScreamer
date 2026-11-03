## Base of every game module.  Each module reaches the shared services and the other modules
## through these fields; Game wires them all together.
class_name Mod
extends RefCounted

var sys: Sys  # virtual clock, beeper, non-local jumps
var keys: Keys  # key queue and held actions
var st: GameState  # everything the game remembers
var data: GameData  # tables from the original disk, translation
var art: Art  # textures
var screen: Screen  # the display (nodes)
var txt: GameText  # text output with the game's markup
var ui: Ui  # menus, prompts, line input
var rng: Rng
var common: Common
var chara: Chara
var items: Items
var shops: Shops
var town: Town
var dungeon: Dungeon
var events: Events
var combat: Combat
var ending: Ending


func wire(hub: Mod) -> void:
	for p in ["sys", "keys", "st", "data", "art", "screen", "txt", "ui", "rng", "common", "chara", "items",
			"shops", "town", "dungeon", "events", "combat", "ending"]:
		set(p, hub.get(p))


func unwire() -> void:
	for p in ["sys", "keys", "st", "data", "art", "screen", "txt", "ui", "rng", "common", "chara", "items",
			"shops", "town", "dungeon", "events", "combat", "ending"]:
		set(p, null)

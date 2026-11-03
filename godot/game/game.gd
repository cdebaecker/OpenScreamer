## Creates the game's services and modules around a Screen and wires them together.
class_name Game
extends Mod

var program: Program
var _modules: Array[Mod] = []


static func create(p_screen: Screen) -> Game:
	var g := Game.new()
	g.screen = p_screen
	g.sys = Sys.new()
	g.keys = Keys.new()
	g.st = GameState.new()
	g.data = GameData.new()
	g.art = Art.new()
	g.txt = GameText.new()
	g.ui = Ui.new()
	g.rng = Rng.new()
	g.common = Common.new()
	g.chara = Chara.new()
	g.items = Items.new()
	g.shops = Shops.new()
	g.town = Town.new()
	g.dungeon = Dungeon.new()
	g.events = Events.new()
	g.combat = Combat.new()
	g.ending = Ending.new()
	g.program = Program.new()
	g._modules = [g.txt, g.ui, g.rng, g.common, g.chara, g.items, g.shops, g.town, g.dungeon, g.events,
			g.combat, g.ending, g.program]
	for m in g._modules:
		m.wire(g)
	return g


## break the reference cycles between the modules
func dispose() -> void:
	sys.halt()
	for m in _modules:
		m.unwire()
	_modules.clear()
	program = null
	unwire()

## The automap (F8 / gamepad R3 in BIAS): the cells of each floor the screamer has stood on, with
## their walls and doors as the floor has them now, and where the screamer is and faces.  The game
## is paused while it's shown.  Visited cells are kept per screamer (by name) in user://automap.cfg.
class_name Automap
extends Control

const PATH := "user://automap.cfg"
const CELL_PX := 14

## where the visited cells are kept (tests use another file)
var path := PATH
var game: Game

var _name := ""  # the screamer whose map this is
var _visited := {}  # floor -> PackedByteArray of W*W (1 = stood there)
var _last := Vector3i(-1, -1, -1)


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## called every frame: in BIAS, the cell the screamer stands on is visited
func record() -> void:
	var st := game.st
	var name := st.chr.name
	if name != _name:
		_name = name
		_visited = load_map(path, name)
		_last = Vector3i(-1, -1, -1)
	if name == "" or st.floor < 1 or st.floor > 6 or st.pos_x >= FloorMap.W or st.pos_y >= FloorMap.W:
		return
	var here := Vector3i(st.floor, st.pos_x, st.pos_y)
	if here == _last:
		return
	_last = here
	var v: PackedByteArray = _visited.get(st.floor, PackedByteArray())
	if v.is_empty():
		v.resize(FloorMap.W * FloorMap.W)
	var i := st.pos_y * FloorMap.W + st.pos_x
	if v[i] == 0:
		v[i] = 1
		_visited[st.floor] = v
		save_map(path, name, _visited)
	if visible:
		queue_redraw()


func visited(floor: int, x: int, y: int) -> bool:
	var v: PackedByteArray = _visited.get(floor, PackedByteArray())
	return not v.is_empty() and v[y * FloorMap.W + x] != 0


static func load_map(p: String, name: String) -> Dictionary:
	var out := {}
	var f := ConfigFile.new()
	if name == "" or f.load(p) != OK or not f.has_section(name):
		return out
	for k in f.get_section_keys(name):
		var b := Marshalls.base64_to_raw(String(f.get_value(name, k, "")))
		if b.size() == FloorMap.W * FloorMap.W:
			out[int(k)] = b
	return out


static func save_map(p: String, name: String, v: Dictionary) -> void:
	var f := ConfigFile.new()
	f.load(p)
	for floor: int in v:
		f.set_value(name, str(floor), Marshalls.raw_to_base64(v[floor]))
	f.save(p)


## forget a screamer's map (deleted from the roster)
static func forget(p: String, name: String) -> void:
	var f := ConfigFile.new()
	if f.load(p) == OK and f.has_section(name):
		f.erase_section(name)
		f.save(p)


func toggle() -> void:
	visible = not visible
	queue_redraw()


func _draw() -> void:
	if game == null or game.st == null:
		return
	var st := game.st
	var w := FloorMap.W * CELL_PX
	var origin := (size - Vector2(w, w)) / 2.0 + Vector2(0, 8)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.07, 0.94))
	var font := get_theme_default_font()
	draw_string(font, Vector2(origin.x, origin.y - 10), tr("BIAS  floor %d") % st.floor, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.95))
	draw_string(font, Vector2(origin.x + w - 150, origin.y - 10), tr("F8 / R3: back"), HORIZONTAL_ALIGNMENT_RIGHT, 150, 11, Color(0.6, 0.6, 0.7))
	draw_rect(Rect2(origin, Vector2(w, w)), Color(0.1, 0.1, 0.14))
	var wall := Color(0.85, 0.85, 0.9)
	var door := Color(1.0, 0.7, 0.2)
	for y in FloorMap.W:
		for x in FloorMap.W:
			if not visited(st.floor, x, y):
				continue
			var p := origin + Vector2(x, y) * CELL_PX
			draw_rect(Rect2(p, Vector2(CELL_PX, CELL_PX)), Color(0.22, 0.3, 0.45))
			var off := FloorMap.cell_off(x, y)
			# N, E, S, W sides
			var sides := [[p, p + Vector2(CELL_PX, 0)], [p + Vector2(CELL_PX, 0), p + Vector2(CELL_PX, CELL_PX)],
					[p + Vector2(0, CELL_PX), p + Vector2(CELL_PX, CELL_PX)], [p, p + Vector2(0, CELL_PX)]]
			for k in 4:
				var b := st.map.b(off + k)
				if b & 2:
					draw_line(sides[k][0], sides[k][1], door, 3.0)
				elif b & 1:
					draw_line(sides[k][0], sides[k][1], wall, 2.0)
	# the screamer: an arrow the way they face
	var c := origin + (Vector2(st.pos_x, st.pos_y) + Vector2(0.5, 0.5)) * CELL_PX
	var dir: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][st.facing & 3]
	var side := Vector2(-dir.y, dir.x)
	var r := CELL_PX * 0.42
	draw_colored_polygon(PackedVector2Array([c + dir * r, c - dir * r * 0.6 + side * r * 0.7, c - dir * r * 0.6 - side * r * 0.7]),
			Color(1, 0.3, 0.3))

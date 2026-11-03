## The game screen: a 640 x 200 board (the PC-98's 200-line graphics, shown with each line
## doubled) holding the pictures and pieces the game draws as TextureRect nodes, with the text
## layer on top, shown through the palette shader.
##
## Drawing works like painting: a new opaque image hides what it covers, so nodes it covers
## completely are freed (and so is the text under it); clear() blacks out a rectangle.  Positions
## are board pixels; px() converts the original's VRAM offsets (80 bytes of 8 pixels per line).
class_name Screen
extends Control

## the eight digital colours, index = G<<2 | R<<1 | B
const COLOURS: Array[Color] = [
	Color(0, 0, 0), Color(0, 0, 1), Color(1, 0, 0), Color(1, 0, 1),
	Color(0, 1, 0), Color(0, 1, 1), Color(1, 1, 0), Color(1, 1, 1),
]
const BLACK := 0
const BLUE := 1
const RED := 2
const GREEN := 4
const WHITE := 7

## the original's screen windows
const WINDOWS: Array[Rect2i] = [
	Rect2i(32, 24, 104, 172),  # 0: command menu
	Rect2i(144, 132, 320, 64),  # 1: message window
	Rect2i(144, 24, 320, 104),  # 2: picture / view window
	Rect2i(16, 120, 320, 72),  # 3: big message window (registration)
	Rect2i(360, 48, 264, 112),  # 4: data & input window
]
const MENU := 0
const MESSAGE := 1
const VIEW := 2
const BIG_MESSAGE := 3
const DATA := 4

## digital palette: colour index -> displayed colour index
var palette := PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7])
var graphics_visible := true:
	set(v):
		graphics_visible = v
		_update_palette()

# children of the scene, usable before _ready (the game may start drawing first)
var board: SubViewport:
	get: return get_node("Board")
var images: Control:
	get: return get_node("Board/Images")
## masks drawn over text: on the PC-98 a later write into one plane shows over earlier text
## (the red menu arrow, combat lamps): see sprite()
var overlay: Control:
	get: return get_node("Board/Overlay")
var text: TextLayer:
	get:
		if _text == null:
			_text = get_node("Board/Text")
		return _text
var _display: TextureRect:
	get: return get_node_or_null("Display")
var _text: TextLayer

var _sprites := {}
## bumped when the palette changes (ModernText redraws)
var palette_version := 0
var _modern: ModernText

var _text_view: SubViewport

# ------------------------------------------------------------------ presentation options (settings)

enum Style { SHARP, CRT, SOFT }

## colour schemes: the colours shown for the eight digital colours
const SCHEMES := {
	"original": COLOURS,
	# the dark ones lifted (blue and red on black are hard to read)
	"high_contrast": [Color(0, 0, 0), Color(0.35, 0.55, 1), Color(1, 0.3, 0.3), Color(1, 0.45, 1),
		Color(0.3, 1, 0.3), Color(0.3, 1, 1), Color(1, 1, 0.3), Color(1, 1, 1)],
	# Okabe & Ito's palette, told apart with any colour vision
	"colour_blind": [Color(0, 0, 0), Color(0, 0.447, 0.698), Color(0.835, 0.369, 0), Color(0.8, 0.475, 0.655),
		Color(0, 0.62, 0.451), Color(0.337, 0.706, 0.914), Color(0.941, 0.894, 0.259), Color(1, 1, 1)],
}

## the smooth font for text (ModernText, composited by the display shader)
var modern_font := false:
	set(v):
		modern_font = v
		text.modern = v
		if v and _modern == null:
			_text_view = SubViewport.new()
			_text_view.name = "TextView"
			_text_view.transparent_bg = true
			_text_view.disable_3d = true
			_text_view.size = Vector2i(640, 400) * ModernText.ZOOM
			_text_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(_text_view)
			_modern = ModernText.new()
			_modern.name = "ModernText"
			_modern.text = text
			_modern.screen = self
			_modern.large = large_text
			_text_view.add_child(_modern)
		if _modern != null:
			_modern.visible = v
		_update_palette()
var style := Style.SHARP:
	set(v):
		style = v
		_update_palette()
var scheme := "original":
	set(v):
		scheme = v if SCHEMES.has(v) else "original"
		_update_palette()
## the modern font, bigger
var large_text := false:
	set(v):
		large_text = v
		if _modern != null:
			_modern.large = v
## palette changes fade over FADE_S instead of switching at once
var smooth_fades := false
const FADE_S := 0.12

var _shown_palette := PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7])
var _fade := 1.0


func _ready() -> void:
	_update_palette()


## the colour shown for text in colour index c (palette, scheme)
func display_colour(c: int) -> Color:
	return SCHEMES[scheme][palette[c]] if graphics_visible else SCHEMES[scheme][0]


func _process(delta: float) -> void:
	if _fade < 1.0 and _display != null:
		_fade = minf(1.0, _fade + delta / FADE_S)
		(_display.material as ShaderMaterial).set_shader_parameter("fade", _fade)


## VRAM offset -> board position
static func px(off: int) -> Vector2i:
	return Vector2i((off % 80) * 8, off / 80)


# ------------------------------------------------------------------ drawing

## Draw a texture with its top-left corner at `pos`.  An opaque texture hides what it covers;
## a mask (transparent where the original drew nothing) only adds its pixels.
func draw(tex: Texture2D, pos: Vector2i, opaque := true) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.position = pos
	r.size = tex.get_size()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if opaque:
		_cover(Rect2i(pos, Vector2i(tex.get_size())))
	images.add_child(r)
	return r


## fill a rectangle with one colour (opaque)
func fill(rect: Rect2i, colour: int) -> ColorRect:
	_cover(rect)
	var r := ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.color = COLOURS[colour]
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	images.add_child(r)
	return r


## black out a rectangle (nodes and text inside it go away)
func clear(rect: Rect2i) -> void:
	var partial := false
	for n in overlay.get_children():
		if rect.encloses(_rect_of(n)):
			_free(n)
	for n in images.get_children():
		var nr := _rect_of(n)
		if rect.encloses(nr):
			_free(n)
		elif rect.intersects(nr):
			partial = true
	text.clear(rect)
	if partial:
		fill(rect, BLACK)


## clear one of the screen windows
func clear_window(n: int) -> void:
	clear(WINDOWS[n])


## clear the whole screen
func clear_screen() -> void:
	for n in images.get_children() + overlay.get_children():
		_free(n)
	_sprites.clear()
	text.clear_all()


## A retained image with a name (combat sprites, cursors): drawn again with the same id, it moves
## or changes texture instead of piling up.  Masks (opaque = false) show over the text.
func sprite(id: StringName, tex: Texture2D, pos: Vector2i, opaque := true) -> TextureRect:
	var found: Variant = _sprites.get(id)  # may be a node freed since (not assignable to a typed var)
	var r: TextureRect = found if is_instance_valid(found) else null
	if r == null or r.is_queued_for_deletion() or not r.is_inside_tree():
		if opaque:
			r = draw(tex, pos, true)
		else:
			r = TextureRect.new()
			r.texture = tex
			r.position = pos
			r.size = tex.get_size()
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.add_child(r)
		_sprites[id] = r
		return r
	if opaque:
		r.visible = false  # don't let _cover() free it
		_cover(Rect2i(pos, Vector2i(tex.get_size())))
	r.texture = tex
	r.size = tex.get_size()
	r.position = pos
	r.visible = true
	r.get_parent().move_child(r, -1)
	return r


func hide_sprite(id: StringName) -> void:
	var r: Variant = _sprites.get(id)
	if is_instance_valid(r) and r.get_parent() != null:
		_free(r)
	_sprites.erase(id)


## the image nodes (TextureRect / ColorRect) that intersect a rectangle, bottom first
func nodes_in(rect: Rect2i) -> Array[Control]:
	var out: Array[Control] = []
	for n in images.get_children():
		if n is Control and not n.is_queued_for_deletion() and rect.intersects(_rect_of(n)):
			out.append(n)
	return out


## Shift what is inside `rect` by (dx, dy) pixels, clipped to the rectangle (the original's
## block scrolls); vacated parts show black.  Text inside the rectangle is removed.
func scroll(rect: Rect2i, dx: int, dy: int) -> void:
	var group := _clip_group(rect)
	for n in group.get_children():
		if n.get_index() > 0:  # not the background
			n.position += Vector2(dx, dy)
	text.clear(rect)


# ------------------------------------------------------------------ saving a window

## what is drawn inside a rectangle, to put back later with restore()
func snapshot(rect: Rect2i) -> Array:
	var out := []
	for n in nodes_in(rect):
		out.append({"node": n.duplicate(), "pos": n.global_position - images.global_position})
	var cells := []
	for row in range(rect.position.y / 8, mini(rect.end.y / 8, TextLayer.ROWS)):
		for col in range(rect.position.x / 8, mini(rect.end.x / 8, TextLayer.COLS)):
			var g := text.glyph_at(col, row)
			if g >= 0:
				cells.append([col, row, g, text._colour[row * TextLayer.COLS + col]])
	return [rect, out, cells]


func restore(snap: Array) -> void:
	var rect: Rect2i = snap[0]
	clear(rect)
	var group := _clip_group(rect)
	for e in snap[1]:
		var n: Control = e["node"]
		n.position = Vector2(e["pos"]) - Vector2(rect.position)
		group.add_child(n)
	for c in snap[2]:
		text.put(c[0], c[1], c[2], c[3])


# ------------------------------------------------------------------ palette

## out 0xA8/0xAA/0xAC/0xAE: the digital palette registers, two colours each
func out_palette(port: int, v: int) -> void:
	var pairs := {0xa8: [3, 7], 0xaa: [1, 5], 0xac: [2, 6], 0xae: [0, 4]}
	var p: Array = pairs[port]
	palette[p[0]] = (v >> 4) & 7
	palette[p[1]] = v & 7
	_update_palette()


func reset_palette() -> void:
	palette = PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7])
	graphics_visible = true
	_update_palette()


func _update_palette() -> void:
	palette_version += 1
	if _display == null:
		return
	var m: ShaderMaterial = _display.material
	var shown := palette if graphics_visible else PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	if shown != _shown_palette:
		if smooth_fades:  # from what is on the screen now
			m.set_shader_parameter("prev_pal", _shown_palette)
			_fade = 0.0
		_shown_palette = shown.duplicate()
	if not smooth_fades:
		_fade = 1.0
	m.set_shader_parameter("pal", shown)
	m.set_shader_parameter("graphics_visible", true)
	m.set_shader_parameter("fade", _fade)
	var cols := PackedVector3Array()
	for c: Color in SCHEMES[scheme]:
		cols.append(Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("colours", cols)
	m.set_shader_parameter("style", style)
	m.set_shader_parameter("text_on", modern_font and _text_view != null)
	if _text_view != null:
		m.set_shader_parameter("text_tex", _text_view.get_texture())


# ------------------------------------------------------------------ internals

func _rect_of(n: Node) -> Rect2i:
	var c := n as Control
	if c == null:
		return Rect2i()
	return Rect2i(Vector2i(c.global_position - images.global_position), Vector2i(c.size))


## free the nodes fully covered by an opaque rectangle, and the text under it
func _cover(rect: Rect2i) -> void:
	for n in images.get_children() + overlay.get_children():
		if n is Control and n.visible and rect.encloses(_rect_of(n)):
			_free(n)
	text.clear(rect)


func _free(n: Node) -> void:
	n.queue_free()  # while still in the tree, so it is really deleted at the end of the frame
	n.get_parent().remove_child(n)


## A clipping container over `rect` (made once per rect) holding what is drawn inside it: nodes
## fully inside move into it; nodes reaching outside stay where they are and a clipped copy goes
## in, over a black background, so only the part inside the rectangle moves.
func _clip_group(rect: Rect2i) -> Control:
	var name := "Clip_%d_%d_%d_%d" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	var g: Control = images.get_node_or_null(name)
	if g == null:
		g = Control.new()
		g.name = name
		g.position = rect.position
		g.size = rect.size
		g.clip_contents = true
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		bg.size = rect.size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(bg)
		images.add_child(g)
	for n in images.get_children():
		if n == g or not (n is Control) or not rect.intersects(_rect_of(n)):
			continue
		var r := _rect_of(n)
		if rect.encloses(r):
			images.remove_child(n)
			g.add_child(n)
		elif n.get_meta(&"copied_into", "") == name:
			continue
		else:
			n.set_meta(&"copied_into", name)
			n = n.duplicate()
			g.add_child(n)
		n.position = Vector2(r.position - rect.position)
	images.move_child(g, -1)
	return g

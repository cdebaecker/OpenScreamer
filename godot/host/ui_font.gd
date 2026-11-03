## The interface's font (Settings, Display): "pc98", the game's own glyphs (8 x 16 dots, made from the
## player's disk by Import.pixel_font()) with DotGothic16 for the kanji and full-width kana the original
## lacks, or "modern", Noto Sans JP.  The pixel font is drawn at 16 px only (one dot per pixel): the sizes the
## interface asks for are set through set_size(), which keeps the modern size and gives 16 for pixels.
class_name UiFont
extends RefCounted

const MODERN := preload("res://assets/fonts/NotoSansJP-Medium-subset.ttf")
const PIXEL_SIZE := 16

static var pixel := false
static var _pixel_font: FontFile


## the interface's font now
static func font() -> Font:
	if not pixel:
		return MODERN
	if _pixel_font == null:
		_pixel_font = Import.pixel_font()
		if _pixel_font == null:
			return MODERN
		# (a bitmap font: no hinting or subpixel settings, which would empty its glyph cache)
		_pixel_font.fallbacks = [load("res://assets/fonts/DotGothic16-subset.ttf"), MODERN]
	return _pixel_font


## a size, for the font now
static func size(modern: int) -> int:
	return PIXEL_SIZE if pixel else modern


## a control's font size (`what`: "font_size", "normal_font_size"...), kept for refresh()
static func set_size(c: Control, what: StringName, modern: int) -> void:
	c.set_meta(&"ui_font_" + what, modern)
	c.add_theme_font_size_override(what, size(modern))


## the sizes set with set_size() under a node, again (the font changed)
static func refresh(n: Node) -> void:
	var c := n as Control
	if c != null:
		for m in c.get_meta_list():
			if String(m).begins_with("ui_font_"):
				c.add_theme_font_size_override(StringName(String(m).trim_prefix("ui_font_")), size(c.get_meta(m)))
	for child in n.get_children():
		refresh(child)

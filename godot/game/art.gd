## Textures made from the original graphics, read from the player's disk by Import
## (user://import).  All use the eight PC-98 digital colours exactly; the screen's palette shader
## maps them to what is shown.
class_name Art
extends RefCounted

static var _textures := {}  # shared by every game: the pictures don't change
static var _manifest := {}
var _cache := {}
var _pieces := {}


func _init() -> void:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(Import.path("pieces.json")))
	_pieces = _manifest


## forget the textures read (after importing again)
static func reload() -> void:
	_textures = {}
	_manifest = {}


func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		if not _textures.has(path):
			var img := Import.image(path)
			assert(img != null, "missing texture " + path)
			_textures[path] = ImageTexture.create_from_image(img)
		_cache[path] = _textures[path]
	return _cache[path]


## scene picture Pnn (320x100)
func picture(n: int) -> Texture2D:
	return tex("pictures/p%02d" % n)


## monster or portrait Gnn (160x100)
func monster(n: int) -> Texture2D:
	return tex("monsters/g%02d" % n)


## a piece from the catalogues (res://data/catalogue/*.json); `frame` picks one of its frames
func piece(name: String, frame: int = 0) -> Texture2D:
	var info: Dictionary = _pieces[name]
	if int(info["frames"]) == 1:
		return tex("pieces/" + name)
	var key := "%s#%d" % [name, frame]
	if not _cache.has(key):
		var a := AtlasTexture.new()
		a.atlas = tex("pieces/" + name)
		a.region = Rect2(frame * int(info["w"]), 0, int(info["w"]), int(info["h"]))
		_cache[key] = a
	return _cache[key]


## a texture made at run time from planar data (3 planes of w bytes x h lines, one after
## another), e.g. a monster's combat sprites; cached under `key`
func planar(key: String, data: PackedByteArray, off: int, w: int, h: int) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(w * 8, h, false, Image.FORMAT_RGBA8)
	var n := w * h
	for y in h:
		for xb in w:
			var i := off + y * w + xb
			var pb := data[i]
			var pr := data[i + n]
			var pg := data[i + 2 * n]
			for bit in 8:
				var s := 7 - bit
				var c := ((pb >> s) & 1) | (((pr >> s) & 1) << 1) | (((pg >> s) & 1) << 2)
				img.set_pixel(xb * 8 + bit, y, Screen.COLOURS[c])
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

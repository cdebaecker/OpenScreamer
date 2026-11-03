## The original game's files, read from the player's own disk image (nothing of the original is
## shipped).  `from_image()` reads a PC-98 disk image (raw, Virtual98 .fdd, Anex86 .fdi, D88, or a .zip holding one),
## finds the files in its FAT12 file system, checks each against res://data/disk.json, and writes what
## the game uses into user://import:
##   game.json   the tables (items, monsters, floors, conversations, the roster, the catalogues'
##               tables, every message of res://data/messages.json by its name)
##   *.png       pictures, portraits, the font, the title, the screen frames, the catalogues' pieces
## All pictures are in the eight PC-98 digital colours exactly; the screen's palette shader maps them.
class_name Import
extends RefCounted

const DIR := "user://import"
const VERSION := 1
const DIGESTS := "res://data/disk.json"
const MESSAGES := "res://data/messages.json"
const CATALOGUES := "res://data/catalogue"
const RAW_SIZE := 77 * 2 * 8 * 1024  # PC-98 2HD: 77 cylinders, 2 heads, 8 sectors of 1 KB

## where MAIN2HDE's and DEMO2HDE's data segments are in their program images, and how much is data
const MAIN_DS := 0xa7a0
const MAIN_END := 0x186c0
const DEMO_DS := 0x830
const DEMO_END := 0xc050

const RGB := [Color8(0, 0, 0), Color8(0, 0, 255), Color8(255, 0, 0), Color8(255, 0, 255),
	Color8(0, 255, 0), Color8(0, 255, 255), Color8(255, 255, 0), Color8(255, 255, 255)]
const PLANE_RGB := {"B": 1, "R": 2, "G": 4, "W": 7}


## is everything imported (by this version)?
static func ready() -> bool:
	var f := FileAccess.get_file_as_string(DIR.path_join("game.json"))
	if f == "":
		return false
	var d: Variant = JSON.parse_string(f)
	return d is Dictionary and int(d.get("version", 0)) == VERSION


## an imported file's path
static func path(rel: String) -> String:
	return DIR.path_join(rel)


## an imported picture
static func image(rel: String) -> Image:
	return Image.load_from_file(path(rel + ".png"))


# ------------------------------------------------------------------ the disk

## import from a disk image; returns "" or what went wrong
static func from_image(file: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(file)
	if bytes.is_empty():
		return "Can't read %s." % file
	if file.get_extension().to_lower() == "zip" or (bytes.size() > 4 and bytes.slice(0, 4) == PackedByteArray([0x50, 0x4b, 3, 4])):
		bytes = _from_zip(file)
		if bytes.is_empty():
			return "The zip file holds no disk image."
	var raw := disk_sectors(bytes)
	if raw.is_empty():
		return "This isn't a PC-98 disk image (raw, .fdd, .fdi or .d88)."
	var files := fat12(raw)
	if files.is_empty():
		return "The disk image has no file system that can be read."
	var err := check(files)
	if err != "":
		return err
	return write(files)


static func _from_zip(file: String) -> PackedByteArray:
	var z := ZIPReader.new()
	if z.open(file) != OK:
		return PackedByteArray()
	for name in z.get_files():
		var d := z.read_file(name)
		if not disk_sectors(d).is_empty():
			z.close()
			return d
	z.close()
	return PackedByteArray()


## the disk's sectors in order (cylinder, head, sector), from any of the image formats; empty if none
static func disk_sectors(d: PackedByteArray) -> PackedByteArray:
	if d.size() >= 0xdc and d.slice(0, 8).get_string_from_ascii() == "VFD1.00":
		return _vfd(d)
	if d.size() == RAW_SIZE:
		return d
	# Anex86 FDI: a header (its size at 8, the image's at 12, the sector size at 16), then the raw sectors
	if d.size() > 32 and d.decode_u32(8) + d.decode_u32(12) == d.size() and d.decode_u32(16) in [256, 512, 1024]:
		return d.slice(d.decode_u32(8))
	if d.size() > 0x2b0 and d.decode_u32(0x1c) == d.size():
		return _d88(d)
	return PackedByteArray()


static func _sorted_sectors(secs: Array) -> PackedByteArray:
	secs.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else (a[1] < b[1] if a[1] != b[1] else a[2] < b[2]))
	var out := PackedByteArray()
	for s: Array in secs:
		out.append_array(s[3])
	return out


## Virtual98: a table of 160 x 26 entries of 12 bytes at DCh (C, H, R, N, fill, 3 flags, 32-bit offset)
static func _vfd(d: PackedByteArray) -> PackedByteArray:
	var secs := []
	for i in 160 * 26:
		var e := 0xdc + i * 12
		var c := d[e]
		if c == 0xff:
			continue
		var size := 128 << d[e + 3]
		var off := d.decode_u32(e + 8)
		var data := PackedByteArray()
		if off == 0xffffffff:
			data.resize(size)
			data.fill(d[e + 4])
		else:
			data = d.slice(off, off + size)
		secs.append([c, d[e + 1], d[e + 2], data])
	return _sorted_sectors(secs)


## 164 track offsets at 20h, each track a run of sectors with a 16-byte header
static func _d88(d: PackedByteArray) -> PackedByteArray:
	var secs := []
	for t in 164:
		var p := d.decode_u32(0x20 + t * 4)
		if p == 0 or p >= d.size():
			continue
		var n := d.decode_u16(p + 4)
		for i in n:
			var size := d.decode_u16(p + 14)
			secs.append([d[p], d[p + 1], d[p + 2], d.slice(p + 16, p + 16 + size)])
			p += 16 + size
	return _sorted_sectors(secs)


## the files of the root directory of a FAT12 volume: {"NAME.EXT": bytes}
static func fat12(d: PackedByteArray) -> Dictionary:
	if d.size() < 64:
		return {}
	var bps := d.decode_u16(11)
	var spc := d[13]
	var rsv := d.decode_u16(14)
	var nfat := d[16]
	var nroot := d.decode_u16(17)
	var spf := d.decode_u16(22)
	if bps == 0 or spc == 0 or nfat == 0:
		return {}
	var fat_off := rsv * bps
	var root_off := (rsv + nfat * spf) * bps
	var data_off := root_off + nroot * 32
	var clus := bps * spc
	var out := {}
	for i in nroot:
		var e := root_off + i * 32
		if e + 32 > d.size() or d[e] == 0:
			break
		var attr := d[e + 11]
		if d[e] == 0xe5 or attr & 0x18:
			continue
		var name := d.slice(e, e + 8).get_string_from_ascii().strip_edges()
		var ext := d.slice(e + 8, e + 11).get_string_from_ascii().strip_edges()
		var size := d.decode_u32(e + 28)
		var c := d.decode_u16(e + 26)
		var body := PackedByteArray()
		var guard := 0
		while c >= 2 and c < 0xff8 and guard < 4096:
			var o := data_off + (c - 2) * clus
			body.append_array(d.slice(o, o + clus))
			var v := d.decode_u16(fat_off + c * 3 / 2)
			c = (v >> 4) if c & 1 else (v & 0xfff)
			guard += 1
		out[name + ("." + ext if ext != "" else "")] = body.slice(0, size)
	return out


## every file the game needs, with the right digest; "" or what is wrong
static func check(files: Dictionary) -> String:
	var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIGESTS))
	var missing := []
	var different := []
	for name: String in want:
		if not files.has(name):
			missing.append(name)
		elif name == "CHAR":
			if (files[name] as PackedByteArray).size() != 1024:
				different.append(name)
		elif sha1(files[name]) != want[name]:
			different.append(name)
	if not missing.is_empty():
		return "This isn't the disk of THE SCREAMER (PC-9801): it lacks %s." % ", ".join(missing)
	if not different.is_empty():
		return "These files of the disk aren't the ones expected: %s." % ", ".join(different)
	return ""


static func sha1(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA1)
	h.update(b)
	return h.finish().hex_encode()


# ------------------------------------------------------------------ what the game uses

## the original bytes as text: half-width katakana for A1h..DFh, the other bytes as code points 0..FFh
static func text(b: PackedByteArray) -> String:
	var s := ""
	for c in b:
		s += char(c - 0xa1 + 0xff61) if c >= 0xa1 and c <= 0xdf else char(c)
	return s


static func cstr(d: PackedByteArray, o: int) -> PackedByteArray:
	var e := o
	while e < d.size() and d[e] != 0:
		e += 1
	return d.slice(o, e)


static func _program(exe: PackedByteArray) -> PackedByteArray:
	return exe.slice(exe.decode_u16(8) * 16)


static func write(files: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var main := _program(files["MAIN2HDE.EXE"])
	var ds := main.slice(MAIN_DS, MAIN_END)
	ds.resize(0x10000)
	var demo := _program(files["DEMO2HDE.EXE"])
	var dds := demo.slice(DEMO_DS, DEMO_END)
	var src := {"DS": ds, "DEMO_DS": dds}
	for k: String in files:
		src[k] = files[k]
	var err := ""
	err += _save(_pictures(files), "")
	err += _save({"font": _font(ds), "title": _title(dds)}, "")
	err += _save(_frames(ds, files["B03"]), "frames/")
	var mons := {}
	var portraits := {}
	for n in range(1, 61):
		var g: PackedByteArray = files["G%02d" % n]
		var c := Canvas.new(160, 100)
		c.planar3(g, 0, 0x14, 0x64)
		portraits["g%02d" % n] = c.image()
		if n < 40:
			var rec := g.slice(0x1770, 0x1770 + 0x28)
			mons[str(n)] = {"name": text(cstr(rec.slice(0, 16), 0)), "record": Array(rec),
				"sprites": Marshalls.raw_to_base64(g.slice(0x1800, 0x1c00))}
	err += _save(portraits, "monsters/")
	var cat := _catalogues()
	var manifest := {}
	var pieces := {}
	for name: String in cat["pieces"]:
		var p: Dictionary = cat["pieces"][name]
		var data: PackedByteArray = src[p["src"]]
		var off := _num(p["off"])
		var w := _num(p["w"])
		var h := _num(p["h"])
		var frames := _num(p.get("frames", 1))
		var mode: String = p.get("mode", "3")
		var stride := _num(p.get("stride", w * h * (3 if mode == "3" else 1)))
		var c := Canvas.new(w * 8 * frames, h)
		for f in frames:
			if mode == "3":
				c.planar3(data, off + f * stride, w, h, f * w * 8)
			else:
				c.plane(data, off + f * stride, w, h, PLANE_RGB[mode], f * w * 8)
		pieces["pieces/" + name] = c.image()
		manifest[name] = {"w": w * 8, "h": h, "frames": frames}
	err += _save(pieces, "")
	var game := {
		"version": VERSION,
		"monsters": mons,
		"items": _items(ds),
		"floors": _floors(files),
		"talk": _talk(files["B01"]),
		"roster": Marshalls.raw_to_base64(files["CHAR"]),
		"demo_strings": _demo_strings(dds),
		"tables": _tables(cat["tables"], ds),
		"messages": _messages(files),
	}
	if err != "":
		return err
	var pf := FileAccess.open(path("pieces.json"), FileAccess.WRITE)
	if pf == null:
		return "Can't write %s." % path("pieces.json")
	pf.store_string(JSON.stringify(manifest))
	pf.close()
	var f := FileAccess.open(path("game.json"), FileAccess.WRITE)
	if f == null:
		return "Can't write %s." % path("game.json")
	f.store_string(JSON.stringify(game))
	f.close()
	return ""


static func _save(images: Dictionary, sub: String) -> String:
	for k: String in images:
		var p := path(sub + k + ".png")
		DirAccess.make_dir_recursive_absolute(p.get_base_dir())
		if (images[k] as Image).save_png(p) != OK:
			return "Can't write %s. " % p
	return ""


static func _num(v: Variant) -> int:
	return String(v).hex_to_int() if v is String else int(v)


static func _pictures(files: Dictionary) -> Dictionary:
	var out := {}
	for n in range(1, 21):
		var c := Canvas.new(320, 100)
		c.planar3(files["P%02d" % n], 0, 0x28, 0x64)
		out["pictures/p%02d" % n] = c.image()
	return out


## the 8x8 font: 256 glyphs, 16 to a row, white on transparent
static func _font(ds: PackedByteArray) -> Image:
	var c := Canvas.new(128, 128)
	for g in 256:
		c.plane(ds, 0x4e6a + g * 8, 1, 8, 7, (g % 16) * 8, (g / 16) * 8)
	return c.image()


## the attract demo's title: 100 lines of 240 bytes (80 of each plane)
static func _title(dds: PackedByteArray) -> Image:
	var c := Canvas.new(640, 100)
	for y in 100:
		c.planar3(dds.slice(0x5a5e + y * 0xf0, 0x5a5e + y * 0xf0 + 0xf0), 0, 0x50, 1, 0, y)
	return c.image()


## the screen frames: registration ("entry") and the town and BIAS ("main"), from their run tables
static func _frames(ds: PackedByteArray, b03: PackedByteArray) -> Dictionary:
	var out := {}
	for which in 2:
		var c := Canvas.new(640, 200)
		var bx := 0xa950 if which == 0 else 0xa9c2
		while ds[bx] != 0:
			var count := ds[bx]
			var di := ds.decode_u16(bx + 1)
			var si := ds.decode_u16(bx + 3)
			if ds[bx + 5] != 0:  # horizontal: 4 lines, one fill byte per plane each
				for row in 4:
					for x in count:
						c.byte3(di + x, ds[si], ds[si + 1], ds[si + 2])
					si += 3
					di += 0x50
			else:  # vertical: `count` copies of a 1-byte-wide, 4-line tile
				for k in count:
					var s := si
					for row in 4:
						c.byte3(di, ds[s], ds[s + 1], ds[s + 2])
						s += 3
						di += 0x50
			bx += 6
		if which == 0:  # the data and input window's title
			c.planar3(b03, 0x800, 0x20, 0x20, (0x2ad % 80) * 8, 0x2ad / 80)
		else:  # the panel's labels (white), the DATA plate and the title
			var labels := [[0xb9b6, 0x11bd], [0xb956, 0x11bf], [0xb9c6, 0x11c1], [0xb9a6, 0x11c3],
				[0xb966, 0x193d], [0xb986, 0x193f], [0xb956, 0x1e3d], [0xb976, 0x1e3f],
				[0xb966, 0x233d], [0xb976, 0x233f], [0xb996, 0x283d], [0xb986, 0x283f]]
			for l: Array in labels:
				c.plane(ds, l[0], 2, 8, 7, (l[1] % 80) * 8, l[1] / 80)
			c.planar3(b03, 0x3000, 0x11, 0x22, (0x5dc % 80) * 8, 0x5dc / 80)
			c.planar3(b03, 0x2800, 0x1a, 0x10, (0x19 % 80) * 8, 0x19 / 80)
		out["entry" if which == 0 else "main"] = c.image()
	return out


static func _floors(files: Dictionary) -> Dictionary:
	var out := {}
	for n in range(1, 7):
		var d: PackedByteArray = (files["F%02d" % n] as PackedByteArray).slice(0, 0x1400)
		d.resize(0x1400)
		out[str(n)] = Marshalls.raw_to_base64(d)
	return out


## the item table: 91 items of 18h bytes
static func _items(ds: PackedByteArray) -> Array:
	var out := []
	for n in range(1, 92):
		var e := ds.slice(0x570b + (n - 1) * 0x18, 0x570b + n * 0x18)
		out.append({"id": n, "shops": e[0], "name": text(cstr(e.slice(1, 0x11), 0)),
			"price": e.decode_u16(0x11), "value": e[0x13], "kind": e[0x15], "record": Array(e)})
	return out


## the conversation table at the start of B01: keyword, 0, its number, the IQ needed, the reply
## count, and where the replies are (an offset in B01, plus 0x5800)
static func _talk(b01: PackedByteArray) -> Array:
	var out := []
	var i := 0
	while b01[i] != 0:
		var kw := cstr(b01, i)
		var e := i + kw.size()
		var t := b01.decode_u16(e + 4) - 0x5800
		var replies := []
		for r in b01[e + 3]:
			var s := cstr(b01, t)
			replies.append(text(s))
			t += s.size() + 1
		out.append({"keyword": text(kw), "number": b01[e + 1], "iq": b01[e + 2], "replies": replies})
		i = e + 6
	return out


static func _demo_strings(dds: PackedByteArray) -> Dictionary:
	var out := {}
	for o in [0x0c, 0x75, 0xde, 0x147, 0x1b0, 0x219, 0x282, 0x2eb, 0x354, 0x3b5, 0x3c2, 0x3e7]:
		out["0x%x" % o] = text(cstr(dds, o))
	return out


static func _catalogues() -> Dictionary:
	var out := {"pieces": {}, "tables": {}}
	var names := DirAccess.get_files_at(CATALOGUES)
	names.sort()
	for f in names:
		if f.get_extension() != "json":
			continue
		var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUES.path_join(f)))
		for k in ["pieces", "tables"]:
			(out[k] as Dictionary).merge(c.get(k, {}))
	return out


static func _tables(tables: Dictionary, ds: PackedByteArray) -> Dictionary:
	var out := {}
	for name: String in tables:
		var t: Dictionary = tables[name]
		var off := _num(t["off"])
		var n := _num(t.get("n", 1))
		match String(t["type"]):
			"u8":
				out[name] = Array(ds.slice(off, off + n))
			"u16":
				var a := []
				for i in n:
					a.append(ds.decode_u16(off + 2 * i))
				out[name] = a
			"str":
				out[name] = text(cstr(ds, off))
			"strs":
				var a := []
				for i in n:
					var s := cstr(ds, off)
					a.append(text(s))
					off += s.size() + 1
				out[name] = a
	return out


## every message the game prints, by its name (res://data/messages.json: program, offset, length)
static func _messages(files: Dictionary) -> Dictionary:
	var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MESSAGES))
	var out := {}
	for id: String in want:
		var m: Dictionary = want[id]
		var d: PackedByteArray = files[m["file"]]
		var o := int(m["offset"])
		out[id] = text(d.slice(o, o + int(m["length"])))
	return out


# ------------------------------------------------------------------ the interface's pixel font

## the game's own 8x8 glyphs as an interface font: each drawn 8 x 16 (lines doubled), one dot per
## pixel at 16 px; only the half-width characters (see ModernText.CHARS) and the accented letters made
## for the translations (Accents), and no-break space as space
static func pixel_font() -> FontFile:
	var plain := image("font")
	if plain == null:
		return null
	var img := Accents.extend_font(plain)  # (with the translations' accented letters, codes 100h..)
	var lit := func(code: int, x: int, y: int) -> bool:
		return img.get_pixel((code % 16) * 8 + x, (code / 16) * 8 + y).a > 0.5
	var base_row := 0
	for y in 8:
		for x in 8:
			if lit.call(0x41, x, y):
				base_row = y + 1
	var ascent := base_row * 2
	var atlas := Image.create_empty(16 * 8, 17 * 16, false, Image.FORMAT_LA8)
	for code in Accents.FIRST + 16:
		for y in 16:
			for x in 8:
				if lit.call(code, x, y / 2):
					atlas.set_pixel((code % 16) * 8 + x, (code / 16) * 16 + y, Color(1, 1, 1, 1))
	var f := FontFile.new()
	f.fixed_size = 16
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	var sz := Vector2i(16, 0)
	f.set_cache_ascent(0, 16, ascent)
	f.set_cache_descent(0, 16, 16 - ascent)
	f.set_texture_image(0, sz, 0, atlas)
	var chars: Dictionary = ModernText.CHARS
	var map := {}
	for code: int in chars:
		var ch: String = chars[code]
		var u := ch.unicode_at(0)
		if u < 0x2000 or (u >= 0xff61 and u <= 0xff9f):
			map[u] = code
	map[0x20] = 0x20  # (the space, full width like the other glyphs)
	map[0xa0] = 0x20
	for u: int in map:
		var code: int = map[u]
		f.set_glyph_advance(0, 16, u, Vector2(8, 0))
		f.set_glyph_offset(0, sz, u, Vector2(0, -ascent))
		f.set_glyph_size(0, sz, u, Vector2(8, 16))
		f.set_glyph_uv_rect(0, sz, u, Rect2((code % 16) * 8, (code / 16) * 16, 8, 16))
		f.set_glyph_texture_idx(0, sz, u, 0)
	return f


## an RGBA picture in the eight colours, drawn from planar data
class Canvas:
	var w: int
	var h: int
	var px := PackedByteArray()

	func _init(width: int, height: int) -> void:
		w = width
		h = height
		px.resize(w * h * 4)

	func set_colour(x: int, y: int, c: int) -> void:
		if x < 0 or x >= w or y < 0 or y >= h:
			return
		var o := (y * w + x) * 4
		px[o] = 255 if c & 2 else 0
		px[o + 1] = 255 if c & 4 else 0
		px[o + 2] = 255 if c & 1 else 0
		px[o + 3] = 255

	## a 3-plane picture (B, R, G one after another), wb bytes x h lines, at pixel (x0, y0)
	func planar3(d: PackedByteArray, off: int, wb: int, lines: int, x0: int = 0, y0: int = 0) -> void:
		var n := wb * lines
		for y in lines:
			for xb in wb:
				var i := off + y * wb + xb
				var pb := d[i]
				var pr := d[i + n]
				var pg := d[i + 2 * n]
				for bit in 8:
					var s := 7 - bit
					set_colour(x0 + xb * 8 + bit, y0 + y, ((pb >> s) & 1) | (((pr >> s) & 1) << 1) | (((pg >> s) & 1) << 2))

	## one plane as a mask in colour `c` (transparent where the bit is clear)
	func plane(d: PackedByteArray, off: int, wb: int, lines: int, c: int, x0: int = 0, y0: int = 0) -> void:
		for y in lines:
			for xb in wb:
				var v := d[off + y * wb + xb]
				for bit in 8:
					if v & (0x80 >> bit):
						set_colour(x0 + xb * 8 + bit, y0 + y, c)

	## one byte of each plane at screen offset `di` (80 bytes to a line)
	func byte3(di: int, b: int, r: int, g: int) -> void:
		var x0 := (di % 80) * 8
		var y := di / 80
		for bit in 8:
			var s := 7 - bit
			set_colour(x0 + bit, y, ((b >> s) & 1) | (((r >> s) & 1) << 1) | (((g >> s) & 1) << 2))

	func image() -> Image:
		return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)

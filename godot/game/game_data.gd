## The game's tables, read from the player's disk by Import (user://import/game.json), and the
## translations: translation packs (gettext PO files) found in user://translations, in a
## "translations" folder next to the program, or in the repository's "translations" folder when
## running from source.  A pack's entries are keyed by a digest of the original string's bytes
## ("sha1:" and 16 hex digits), so packs hold none of the original's text.
## Text is Unicode: the original's katakana are half-width katakana.
class_name GameData
extends RefCounted

const SETTINGS := "user://settings.cfg"
## where the text language is kept (the window's settings file; tests point it elsewhere)
static var settings_file := SETTINGS
## the folders searched for translation packs, in order
static var pack_dirs := _pack_dirs()

static var _game := {}  # the imported game.json, read once
static var _packs := {}  # pack folders (joined) -> {code: pack}

## item number (1..91) -> {name, price, value, kind, shops, record}
var items: Array = []
## monster number (1..39) -> {name, record (40 bytes), sprites (base64, 1024 bytes)}
var _monsters := {}
var _floors := {}
## conversation keywords: [{keyword, number, iq, replies}]
var talk: Array = []
## named tables from the original data segment (see res://data/catalogue/*.json)
var tables := {}
var demo_strings := {}
var roster_default := PackedByteArray()
## the original's messages by name (res://data/messages.json)
var _messages := {}

var lang := "en"  # "ja" (the original) or a translation's code
## code -> {"name", "game": {digest: text}, "demo": {...}, "keyword": {typed form: digest},
## "password": {typed form: true}}
var _langs := {}
## digest -> original keyword
var _keywords := {}
var _digests := {}  # original string -> its digest (cache)
var _non_alnum := RegEx.create_from_string("[^a-z0-9]")


static func _pack_dirs() -> PackedStringArray:
	var dirs := PackedStringArray(["user://translations"])
	if OS.has_feature("template"):
		dirs.append(OS.get_executable_path().get_base_dir().path_join("translations"))
	else:
		dirs.append(ProjectSettings.globalize_path("res://").path_join("../translations").simplify_path())
	return dirs


func _init() -> void:
	if _game.is_empty():
		_game = JSON.parse_string(FileAccess.get_file_as_string(Import.path("game.json")))
	var d := _game
	items = d["items"]
	_monsters = d["monsters"]
	_floors = d["floors"]
	talk = d["talk"]
	tables = d["tables"]
	demo_strings = d["demo_strings"]
	roster_default = Marshalls.base64_to_raw(d["roster"])
	_messages = d["messages"]
	for t: Dictionary in talk:
		_keywords[digest(t["keyword"])] = t["keyword"]
	var key := ",".join(pack_dirs)
	if not _packs.has(key):
		var found := {}
		for dir in pack_dirs:
			if not DirAccess.dir_exists_absolute(dir):
				continue
			for f in DirAccess.get_files_at(dir):
				if f.get_extension() == "po" and not found.has(f.get_basename()):
					var l := read_po(dir.path_join(f))
					if not l.is_empty():
						found[f.get_basename()] = l
		_packs[key] = found
	_langs = _packs[key]
	var l := "en"
	var cfg := ConfigFile.new()
	if cfg.load(settings_file) == OK:
		l = str(cfg.get_value("game", "lang", "en"))
	lang = l if l == "ja" or _langs.has(l) else ("en" if _langs.has("en") else "ja")


## forget what was read (after importing again, or adding a translation pack)
static func reload() -> void:
	_game = {}
	_packs = {}


## one of the original's messages, by its name in res://data/messages.json
func msg(id: StringName) -> String:
	assert(_messages.has(String(id)), "missing message " + id)
	return _messages[String(id)]


## the item table entry for an item number (bit 7, "equipped", ignored)
func item(n: int) -> Dictionary:
	return items[(n & 0x7f) - 1]


func monster_record(n: int) -> PackedByteArray:
	return PackedByteArray(_monsters[str(n)]["record"])


## the combat sprite set of a monster below 40 (1024 bytes of planar images)
func monster_sprites(n: int) -> PackedByteArray:
	return Marshalls.base64_to_raw(_monsters[str(n)]["sprites"])


func floor_bytes(n: int) -> PackedByteArray:
	return Marshalls.base64_to_raw(_floors[str(n)])


## a named table (Array of ints, a String, or an Array of Strings)
func table(name: String) -> Variant:
	assert(tables.has(name), "missing table " + name)
	return tables[name]


# ------------------------------------------------------------------ translation

## a translation pack's key for an original string: "sha1:" and the first 16 hex digits of the
## SHA-1 of its bytes
func digest(s: String) -> String:
	if not _digests.has(s):
		var h := HashingContext.new()
		h.start(HashingContext.HASH_SHA1)
		h.update(GameText.encode(s))
		_digests[s] = "sha1:" + h.finish().hex_encode().substr(0, 16)
	return _digests[s]


## the text languages: the translations (English first), then "ja" (the original)
func languages() -> Array[String]:
	var out: Array[String] = []
	for l: String in _langs:
		out.append(l)
	out.sort_custom(func(a: String, b: String) -> bool: return a == "en" or (b != "en" and a < b))
	out.append("ja")
	return out


func language_name(l: String) -> String:
	return "Japanese (original)" if l == "ja" else String(_langs.get(l, {}).get("name", l))


## (the window keeps the choice in its settings file; scripted runs and tests leave it alone)
func set_lang(l: String) -> void:
	lang = l


## the current translation's entries of a kind ("game", "demo", "keyword", "password"); {} in Japanese
func _tr(kind: String) -> Dictionary:
	return _langs[lang][kind] if _langs.has(lang) else {}


## the text to show for an original string
func translate(s: String) -> String:
	if not _langs.has(lang):
		return s
	var t: String = _tr("game").get(digest(s), "")
	return t if t != "" else s


## the same for the intro program's strings
func translate_demo(s: String) -> String:
	if not _langs.has(lang):
		return s
	var t: String = _tr("demo").get(digest(s), "")
	return t if t != "" else s


## a typed word, compared without case, accents, spaces or punctuation
func norm(s: String) -> String:
	return _non_alnum.sub(fold(s).to_lower(), "", true)


## a word typed when talking (in the translation's language) -> the original katakana keyword, or
## the password ("" if neither)
func keyword_for(typed: String) -> String:
	var d: String = _tr("keyword").get(norm(typed), "")
	if d != "":
		return _keywords.get(d, "")
	if _tr("password").has(norm(typed)):
		return table("shops_password")
	return ""


## does the typed text match the translation of the original string `orig`?
func matches_translation(typed: String, orig: String) -> bool:
	var e := norm(_tr("game").get(digest(orig), ""))
	return e == norm(typed) and e != ""


# ------------------------------------------------------------------ translation files

## the game's font has ASCII only: accented letters lose their accents
const _FOLD := {"ß": "ss", "æ": "ae", "Æ": "AE", "œ": "oe", "Œ": "OE", "ø": "o", "Ø": "O", "ł": "l", "Ł": "L",
	"‘": "'", "’": "'", "“": "\"", "”": "\"", "–": "-", "—": "-", "…": "...", "«": "\"", "»": "\"", "¡": "!", "¿": "?"}
const _ACCENTED := "ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÑñÒÓÔÕÖòóôõöÙÚÛÜùúûüÝýÿĀāĂăĄąĆćČčĎďĒēĘęĚěĞğĪīİıŃńŇňŌōŐőŘřŚśŞşŠšŤťŪūŮůŰűŹźŻżŽž"
const _PLAIN := "AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiNnOOOOOoooooUUUUuuuuYyyAaAaAaCcCcDdEeEeEeGgIiIiNnNnOoOoRrSsSsSsTtUuUuUuZzZzZz"


static func fold(s: String) -> String:
	var out := ""
	for i in s.length():
		var c := s[i]
		var k := _ACCENTED.find(c)
		if k >= 0:
			out += _PLAIN[k]
		else:
			out += _FOLD.get(c, c)
	return out


## a translation: {"name", "game", "demo", "keyword"} ({} if the file can't be read).  Texts are
## folded to what the game's font shows; keyword forms are normalised.
func read_po(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var out := {"name": path.get_file().get_basename(), "game": {}, "demo": {}, "keyword": {}, "password": {}}
	var cur := {}
	var field := ""
	for line in (text + "\n").split("\n"):
		line = line.strip_edges()
		if line == "" or line.begins_with("#"):
			if cur.has("msgid") and line == "":
				_po_entry(out, cur)
				cur = {}
			continue
		if line.begins_with("\""):
			cur[field] = String(cur[field]) + _po_unquote(line)
			continue
		var sp := line.find(" ")
		field = line.substr(0, sp)
		cur[field] = _po_unquote(line.substr(sp + 1))
	return out


func _po_entry(out: Dictionary, e: Dictionary) -> void:
	var id: String = e.get("msgid", "")
	var s: String = e.get("msgstr", "")
	var ctxt: String = e.get("msgctxt", "")
	if id == "":  # the header
		for h in s.split("\n"):
			if h.begins_with("X-Language-Name:"):
				out["name"] = h.substr(16).strip_edges()
		return
	if s == "" or not out.has(ctxt) or ctxt == "name":
		return
	if ctxt == "keyword":
		for w in s.split("|"):
			if norm(w) != "":
				out["keyword"][norm(w)] = id
	elif ctxt == "password":
		for w in s.split("|"):
			if norm(w) != "":
				out["password"][norm(w)] = true
	else:
		out[ctxt][id] = fold(s)


static func _po_unquote(q: String) -> String:
	var s := q.substr(1, q.length() - 2)
	return s.c_unescape() if s.contains("\\") else s

## The journal (J, gamepad L3): what the screamer has been told and has found (what people answered,
## wall writings, the revelation ring's words, items found and given, hunters met, monsters
## beaten), newest first.  Kept per screamer (by name) in user://journal.cfg.  The game reports
## these through Sys.journal() with the original strings; they're shown in the current language.
## The game is paused while the journal is shown.
class_name Journal
extends PanelContainer

const PATH := "user://journal.cfg"
const KEEP := 300
## the hunters met in BIAS, by number (the intro's profiles; the pendant chain matches them)
## the intro's profiles of hunters 1 to 8, which hold their names (offsets in DEMO2HDE's data)
const HUNTER_PROFILES := [0x0c, 0x75, 0xde, 0x147, 0x1b0, 0x219, 0x282, 0x2eb]
const _PROFILE := "Name      : "

var path := PATH
var game: Game

var _name := ""
var _entries: Array = []  # [{kind, subject, text, floor, x, y, time}], oldest first
var _text: RichTextLabel


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.09)
	bg.border_color = Color(0.35, 0.35, 0.45)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(12)
	add_theme_stylebox_override("panel", bg)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = true
	UiFont.set_size(_text, &"normal_font_size", 12)
	UiFont.set_size(_text, &"bold_font_size", 12)
	add_child(_text)


## the game reports something (Sys.on_journal)
func add(kind: StringName, subject: String, text: String) -> void:
	var st := game.st
	_switch(st.chr.name)
	if _name == "":
		return
	var in_town := Ambience.area_of(game.program.current) == "town"
	var e := {"kind": String(kind), "subject": subject, "text": text, "floor": 0 if in_town else st.floor, "x": st.pos_x, "y": st.pos_y,
			"time": int(Time.get_unix_time_from_system())}
	# the same thing again (a wall read twice, the same answer): moved to the top, not doubled
	for i in range(_entries.size() - 1, -1, -1):
		var o: Dictionary = _entries[i]
		if o["kind"] == e["kind"] and o["subject"] == subject and o["text"] == text and kind != &"victory":
			_entries.remove_at(i)
			break
	_entries.append(e)
	if _entries.size() > KEEP:
		_entries.pop_front()
	save_entries(path, _name, _entries)
	if visible:
		_show()


func entries() -> Array:
	_switch(game.st.chr.name)
	return _entries


func _switch(name: String) -> void:
	if name != _name:
		_name = name
		_entries = load_entries(path, name)


static func load_entries(p: String, name: String) -> Array:
	var f := ConfigFile.new()
	if name == "" or f.load(p) != OK:
		return []
	var v: Variant = f.get_value(name, "entries", [])
	return v if v is Array else []


static func save_entries(p: String, name: String, e: Array) -> void:
	var f := ConfigFile.new()
	f.load(p)
	f.set_value(name, "entries", e)
	f.save(p)


## forget a screamer's journal (deleted from the roster)
static func forget(p: String, name: String) -> void:
	var f := ConfigFile.new()
	if f.load(p) == OK and f.has_section(name):
		f.erase_section(name)
		f.save(p)


func toggle() -> void:
	visible = not visible
	if visible:
		_show()


# ------------------------------------------------------------------ showing

func _show() -> void:
	var lines := PackedStringArray()
	lines.append("[b]%s[/b]   %s\n" % [tr("Journal of %s") % game.st.chr.name, tr("J / L3: back")])
	var list := entries()
	if list.is_empty():
		lines.append(tr("Nothing yet: what people tell you, wall writings and what you find will be noted here."))
	for i in range(list.size() - 1, -1, -1):
		lines.append(line(list[i]))
	_text.text = "\n".join(lines)


## one entry, in the current language
func line(e: Dictionary) -> String:
	var where := tr("Town") if int(e["floor"]) == 0 else tr("Floor %d (%d, %d)") % [int(e["floor"]), int(e["x"]) + 1, int(e["y"]) + 1]
	var subject := shown(e["subject"])
	var text := shown(e["text"])
	var what := ""
	match e["kind"]:
		"talk": what = tr("Asked about %s: %s") % [subject, text]
		"wall": what = tr("Written on the wall: %s") % text
		"ring": what = tr("The revelation ring: %s") % text
		"item": what = tr("Found %s") % subject
		"gift": what = tr("Was given %s: %s") % [subject, text]
		"hunter":
			var n := int(e["subject"])
			what = tr("Met the hunter %s") % (hunter_name(n) if n > 0 and n <= HUNTER_PROFILES.size() else "?")
		"victory": what = tr("Beat %s (%s beast points)") % [subject, e["text"]]
		_: what = text
	return "[color=#8890a0]%s[/color]  %s" % [where, what]


## a hunter's name in the text's language: from the intro's profile of them ("Name      : ...")
func hunter_name(n: int) -> String:
	var profile: String = game.data.demo_strings["0x%x" % HUNTER_PROFILES[n - 1]]
	var t := game.data.translate_demo(profile)
	return t.trim_prefix(_PROFILE).get_slice("_", 0).strip_edges()


## an original string as the journal shows it: translated, without the game's markup (new lines,
## the hiragana switch { }, the | switch), its half-width katakana in hiragana where { } asked for it
func shown(s: String) -> String:
	if s == "":
		return ""
	s = game.data.translate(s)
	var out := ""
	var hira := false
	for i in s.length():
		var c := s[i]
		match c:
			"{":
				hira = not hira
			"}":
				hira = not hira
			"|":
				pass
			"_", "~":
				if not out.ends_with(" "):
					out += " "
			"ﾞ", "ﾟ":
				# a voiced mark after a hiragana: the voiced hiragana (か゛→が, は゜→ぱ)
				var v := _voiced(out.right(1), c == "ﾟ")
				out = out.left(-1) + v if v != "" else out + c
			_:
				out += _hiragana(c) if hira else c
	return out.strip_edges().replace("[", "[lb]")


const _KATA := "ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ"
const _HIRA := "をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん"


## the voiced (or, with semi, half-voiced) form of a hiragana, "" if it has none
static func _voiced(h: String, semi: bool) -> String:
	if h == "う" and not semi:
		return "ゔ"
	var rows := "はひふへほ" if semi else "かきくけこさしすせそたちつてとはひふへほ"
	if h == "" or not rows.contains(h):
		return ""
	return String.chr(h.unicode_at(0) + (2 if semi else 1))


static func _hiragana(c: String) -> String:
	var k := _KATA.find(c)
	return _HIRA[k] if k >= 0 else c

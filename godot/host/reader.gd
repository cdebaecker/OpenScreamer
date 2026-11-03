## Reads new text aloud (settings: Access): when the text on the screen has settled, the lines
## that changed since the last reading are spoken with the system's text to speech, in the
## language of the game's text.  Presentation only.
class_name Reader
extends Node

## how long the text must stay unchanged before it's read (s)
const SETTLE_S := 0.6

var enabled := false:
	set(v):
		enabled = v
		if not v:
			stop()
var text: TextLayer
var lang := "en"
## speaks a string (tests replace it); by default the system's text to speech
var speak := _tts

var _heard := PackedStringArray()  # the lines as last read
var _seen_version := -1
var _quiet := 0.0
var _voices := {}
var _spoke := false


func _process(delta: float) -> void:
	if not enabled or text == null:
		return
	if text.version != _seen_version:
		_seen_version = text.version
		_quiet = 0.0
		return
	_quiet += delta
	if _quiet >= SETTLE_S and _quiet - delta < SETTLE_S:
		read_new()


## the screen's text, line by line (graphics characters left out)
static func lines(t: TextLayer) -> PackedStringArray:
	var out := PackedStringArray()
	for row in TextLayer.ROWS:
		var s := ""
		for col in TextLayer.COLS:
			var g := t.glyph_at(col, row)
			s += " " if g < 0 or g == 0x20 else ModernText.CHARS.get(g, " ")
		out.append(s)
	return out


## the text of the lines that changed since `before` (runs of spaces squeezed)
static func changed_text(before: PackedStringArray, now: PackedStringArray) -> String:
	var parts := PackedStringArray()
	for i in now.size():
		if i >= before.size() or before[i] != now[i]:
			var s := now[i].strip_edges()
			while s.contains("  "):
				s = s.replace("  ", " ")
			if s != "":
				parts.append(s)
	return "\n".join(parts)


func read_new() -> void:
	var now := lines(text)
	var said := changed_text(_heard, now)
	_heard = now
	if said != "":
		speak.call(said)


func stop() -> void:
	if _spoke:
		DisplayServer.tts_stop()
		_spoke = false


func _tts(s: String) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	if not _voices.has(lang):
		var v := DisplayServer.tts_get_voices_for_language(lang)
		_voices[lang] = v[0] if not v.is_empty() else ""
	if _voices[lang] == "":
		return
	DisplayServer.tts_speak(s, _voices[lang], 50, 1.0, 1.0, 0, true)
	_spoke = true

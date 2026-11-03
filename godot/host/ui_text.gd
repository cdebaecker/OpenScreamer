## The port's own interface text (menus, prompts, help), translated with Godot's TranslationServer
## from gettext files in res://data/ui (<code>.po, started from template.pot, which
## tools/gen_ui_pot.py writes from the scripts).  The interface follows the game text's language;
## English is the source.
##
## In the scripts: a text set once on a Label / Button is the English message marked with N_() and
## Godot translates it (live, when the language changes); a text made with values uses tr(...) and
## is made again when the language changes.
class_name UiText
extends RefCounted

const DIR := "res://data/ui"

static var _loaded := {}


## marks an interface message for tools/gen_ui_pot.py; Godot translates the node's text itself
static func N_(s: String) -> String:
	return s


## a message translated now (for static code, where Object.tr() isn't at hand)
static func t(s: String) -> String:
	return TranslationServer.translate(s)


## the interface in this language (the game text's code: "en", "ja", ...)
static func use(lang: String) -> void:
	var path := DIR.path_join(lang + ".po")
	if lang != "en" and not _loaded.has(lang) and ResourceLoader.exists(path):
		var t: Translation = load(path)
		if t != null:
			t.locale = lang
			TranslationServer.add_translation(t)
			_loaded[lang] = t
	TranslationServer.set_locale(lang if _loaded.has(lang) else "en")


## the interface languages there are translations for (besides English)
static func languages() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.get_extension() == "po":
			out.append(f.get_basename())
	return out

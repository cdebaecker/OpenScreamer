# Turns the host's key events into the game's key queue (menus, names, conversation): cursor
# keys, Space/Enter, Esc, Backspace/Delete and typed characters, plus the gamepad's A, B and d-pad.
# Held actions (walking, fighting) come from the project's input map instead (see game/keys.gd).
# Typing katakana (needed to talk to people in Japanese) works through a KANA mode with romaji.
class_name HostKeyboard
extends RefCounted

# ------------------------------------------------------------------ romaji -> half-width katakana

const ROMAJI := {
	"a": "ｱ", "i": "ｲ", "u": "ｳ", "e": "ｴ", "o": "ｵ",
	"ka": "ｶ", "ki": "ｷ", "ku": "ｸ", "ke": "ｹ", "ko": "ｺ", "ga": "ｶﾞ", "gi": "ｷﾞ", "gu": "ｸﾞ", "ge": "ｹﾞ", "go": "ｺﾞ",
	"sa": "ｻ", "si": "ｼ", "shi": "ｼ", "su": "ｽ", "se": "ｾ", "so": "ｿ", "za": "ｻﾞ", "zi": "ｼﾞ", "ji": "ｼﾞ", "zu": "ｽﾞ", "ze": "ｾﾞ", "zo": "ｿﾞ",
	"ta": "ﾀ", "ti": "ﾁ", "chi": "ﾁ", "tu": "ﾂ", "tsu": "ﾂ", "te": "ﾃ", "to": "ﾄ", "da": "ﾀﾞ", "di": "ﾁﾞ", "du": "ﾂﾞ", "de": "ﾃﾞ", "do": "ﾄﾞ",
	"na": "ﾅ", "ni": "ﾆ", "nu": "ﾇ", "ne": "ﾈ", "no": "ﾉ",
	"ha": "ﾊ", "hi": "ﾋ", "hu": "ﾌ", "fu": "ﾌ", "he": "ﾍ", "ho": "ﾎ", "ba": "ﾊﾞ", "bi": "ﾋﾞ", "bu": "ﾌﾞ", "be": "ﾍﾞ", "bo": "ﾎﾞ",
	"pa": "ﾊﾟ", "pi": "ﾋﾟ", "pu": "ﾌﾟ", "pe": "ﾍﾟ", "po": "ﾎﾟ",
	"ma": "ﾏ", "mi": "ﾐ", "mu": "ﾑ", "me": "ﾒ", "mo": "ﾓ", "ya": "ﾔ", "yu": "ﾕ", "yo": "ﾖ",
	"ra": "ﾗ", "ri": "ﾘ", "ru": "ﾙ", "re": "ﾚ", "ro": "ﾛ", "wa": "ﾜ", "wo": "ｦ", "nn": "ﾝ", "n'": "ﾝ",
	"kya": "ｷｬ", "kyu": "ｷｭ", "kyo": "ｷｮ", "gya": "ｷﾞｬ", "gyu": "ｷﾞｭ", "gyo": "ｷﾞｮ",
	"sha": "ｼｬ", "shu": "ｼｭ", "sho": "ｼｮ", "she": "ｼｪ", "sya": "ｼｬ", "syu": "ｼｭ", "syo": "ｼｮ",
	"ja": "ｼﾞｬ", "ju": "ｼﾞｭ", "jo": "ｼﾞｮ", "je": "ｼﾞｪ", "jya": "ｼﾞｬ", "jyu": "ｼﾞｭ", "jyo": "ｼﾞｮ", "zya": "ｼﾞｬ", "zyu": "ｼﾞｭ", "zyo": "ｼﾞｮ",
	"cha": "ﾁｬ", "chu": "ﾁｭ", "cho": "ﾁｮ", "che": "ﾁｪ", "tya": "ﾁｬ", "tyu": "ﾁｭ", "tyo": "ﾁｮ",
	"nya": "ﾆｬ", "nyu": "ﾆｭ", "nyo": "ﾆｮ", "hya": "ﾋｬ", "hyu": "ﾋｭ", "hyo": "ﾋｮ", "bya": "ﾋﾞｬ", "byu": "ﾋﾞｭ", "byo": "ﾋﾞｮ",
	"pya": "ﾋﾟｬ", "pyu": "ﾋﾟｭ", "pyo": "ﾋﾟｮ", "mya": "ﾐｬ", "myu": "ﾐｭ", "myo": "ﾐｮ", "rya": "ﾘｬ", "ryu": "ﾘｭ", "ryo": "ﾘｮ",
	"fa": "ﾌｧ", "fi": "ﾌｨ", "fe": "ﾌｪ", "fo": "ﾌｫ", "thi": "ﾃｨ", "dhi": "ﾃﾞｨ", "dhu": "ﾃﾞｭ", "twu": "ﾄｩ",
	"wi": "ｳｨ", "we": "ｳｪ", "va": "ｳﾞｧ", "vi": "ｳﾞｨ", "vu": "ｳﾞ", "ve": "ｳﾞｪ", "vo": "ｳﾞｫ", "tsa": "ﾂｧ",
	"xa": "ｧ", "xi": "ｨ", "xu": "ｩ", "xe": "ｪ", "xo": "ｫ", "la": "ｧ", "li": "ｨ", "lu": "ｩ", "le": "ｪ", "lo": "ｫ",
	"xya": "ｬ", "xyu": "ｭ", "xyo": "ｮ", "lya": "ｬ", "lyu": "ｭ", "lyo": "ｮ", "xtu": "ｯ", "ltu": "ｯ", "xtsu": "ｯ",
	"-": "ｰ", ".": "｡", ",": "､", "[": "｢", "]": "｣", "/": "･",
}

const ROMAJI_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-.,[]/'"
const DOUBLED := "bcdfghjklmpqrstvwxz"

var kana := false
## KANA can be switched on (the game text is in Japanese)
var kana_allowed := true
var pending := ""
signal changed

var _keys: Keys
var _prefixes := {}


func _init(keys: Keys) -> void:
	_keys = keys
	for k: String in ROMAJI:
		for i in range(1, k.length() + 1):
			_prefixes[k.substr(0, i)] = true


func _has_longer(p: String) -> bool:
	for x: String in _prefixes:
		if x.length() > p.length() and x.begins_with(p):
			return true
	return false


## feed one romaji character; complete syllables become katakana
func _romaji(ch: String) -> void:
	pending += ch
	while true:
		var p := pending
		if p.is_empty():
			return
		var longer := _has_longer(p)
		if ROMAJI.has(p) and not longer:
			_emit(ROMAJI[p])
			pending = ""
			return
		if longer:
			return  # wait for more letters
		# p cannot grow into a syllable: resolve its head
		if p.length() >= 2 and p[0] == "n" and not "aiueoy".contains(p[1]):
			_emit("ﾝ")
			pending = p.substr(1)
			continue
		if p.length() >= 2 and p[0] == p[1] and DOUBLED.contains(p[0]):
			_emit("ｯ")
			pending = p.substr(1)
			continue
		var k := p.length() - 1
		while k > 0 and not ROMAJI.has(p.substr(0, k)):
			k -= 1
		if k > 0:
			_emit(ROMAJI[p.substr(0, k)])
		pending = p.substr(maxi(k, 1))


func _emit(s: String) -> void:
	for i in s.length():
		_keys.push(s.unicode_at(i))


## flush a dangling "n" when KANA mode ends or a non-letter is typed
func _settle() -> void:
	if pending == "n":
		_emit("ﾝ")
	pending = ""


func toggle_kana() -> void:
	_settle()
	kana = not kana
	changed.emit()


## keys that also stand for held actions (W A S D E Q Z X C unless rebound) don't repeat in the queue


## returns true when the event was used
func key_event(e: InputEventKey) -> bool:
	if not e.pressed:
		return false
	var code := e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
	if code == KEY_QUOTELEFT or code == KEY_JIS_KANA or code == KEY_JIS_EISU:
		if not e.echo and (kana_allowed or kana):
			toggle_kana()
		return true
	if e.ctrl_pressed or e.meta_pressed:
		return false
	var keypad := code >= KEY_KP_MULTIPLY and code <= KEY_KP_9
	if e.echo and (keypad or Settings.is_action_key(code)):
		return true
	match code:
		KEY_UP:
			_special(Keys.K_UP)
			return true
		KEY_RIGHT:
			_special(Keys.K_RIGHT)
			return true
		KEY_DOWN:
			_special(Keys.K_DOWN)
			return true
		KEY_LEFT:
			_special(Keys.K_LEFT)
			return true
		KEY_DELETE:
			_special(Keys.K_DEL)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_special(Keys.K_SPACE)
			return true
		KEY_ESCAPE:
			_special(Keys.K_ESC)
			return true
		KEY_BACKSPACE:
			if not pending.is_empty():
				pending = pending.substr(0, pending.length() - 1)
				changed.emit()
			else:
				_keys.push(Keys.K_DEL)
			return true
	if e.unicode >= 0x20:  # keypad digits are typed too, like on the PC-98
		var ch := String.chr(e.unicode)
		if kana and ROMAJI_CHARS.contains(ch):
			_romaji(ch.to_lower())
			changed.emit()
			return true
		_settle()
		if e.unicode < 0x7f:
			_keys.push(e.unicode)
		changed.emit()
		return true
	return false


## gamepad: A = Space, B = Esc, d-pad = cursor keys
func joy_event(e: InputEventJoypadButton) -> bool:
	if not e.pressed:
		return false
	var code: int = {JOY_BUTTON_A: Keys.K_SPACE, JOY_BUTTON_B: Keys.K_ESC, JOY_BUTTON_DPAD_UP: Keys.K_UP,
			JOY_BUTTON_DPAD_DOWN: Keys.K_DOWN, JOY_BUTTON_DPAD_LEFT: Keys.K_LEFT,
			JOY_BUTTON_DPAD_RIGHT: Keys.K_RIGHT}.get(e.button_index, 0)
	if code == 0:
		return false
	_special(code)
	return true


func _special(code: int) -> void:
	_settle()
	_keys.push(code)

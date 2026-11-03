## Optional background ambience (settings, off by default): a quiet loop for where the screamer is
## (the city, BIAS, a fight), crossfaded when that changes.  The original has no music; this is an
## added layer, made here from sine partials and filtered noise (no recordings): partials make whole
## numbers of cycles in a loop, and the noise's seam is crossfaded, so it loops without a click.
class_name Ambience
extends Node

const RATE := 11025
const SECONDS := 6  # every partial makes a whole number of cycles in this time: seamless loops
const FADE_S := 1.5

var enabled := false:
	set(v):
		enabled = v
		_apply()
var volume := 0.4:  # 0..1
	set(v):
		volume = v
		_apply()
var area := "":  # "town", "bias", "combat", "" for silence
	set(v):
		if v != area:
			area = v
			_apply()

var _players: Array[AudioStreamPlayer] = []
var _loops := {}
var _current := 0  # the player now fading in


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


## where the game is (Program.current) -> the ambience for it
static func area_of(target: StringName) -> String:
	match target:
		&"dungeon", &"dungeon_loop":
			return "bias"
		&"combat":
			return "combat"
		&"town", &"town_menu", &"bar", &"registration", &"registration_restart":
			return "town"
	return ""


func _apply() -> void:
	if _players.is_empty():
		return
	var want := area if enabled and volume > 0.0 else ""
	var p := _players[_current]
	var playing_area: String = p.get_meta("area", "")
	if want == playing_area and (want == "" or p.playing):
		_fade(p, _db(), 0.3)
		return
	# fade the current one out, the other one in with the new loop
	_fade(p, -80.0, FADE_S)
	if want == "":
		return
	_current = 1 - _current
	var q := _players[_current]
	q.stream = loop(want)
	q.set_meta("area", want)
	q.volume_db = -80.0
	q.play()
	_fade(q, _db(), FADE_S)


func _db() -> float:
	return linear_to_db(volume) - 6.0


func _fade(p: AudioStreamPlayer, db: float, s: float) -> void:
	var t := create_tween()
	t.tween_property(p, "volume_db", db, s)
	if db <= -79.0:
		t.tween_callback(func() -> void:
			if p.volume_db <= -79.0:
				p.stop()
				p.set_meta("area", ""))


## the loop for an area (made the first time it's needed)
func loop(name: String) -> AudioStreamWAV:
	if not _loops.has(name):
		_loops[name] = render(name)
	return _loops[name]


## sine partials [cycles per loop, amplitude, phase], band-passed noise [centre Hz, Q, amplitude]
## (or none), and slow swells per loop, for each area
static func _recipe(name: String) -> Dictionary:
	match name:
		"bias":  # a low drone a fifth apart, and a wind
			return {"parts": [[330, 0.30, 0.0], [495, 0.16, 1.0], [660, 0.05, 2.0]], "noise": [420.0, 1.2, 0.5], "swell": 1}
		"town":  # a soft major chord with a faint hiss of the street
			return {"parts": [[660, 0.11, 0.0], [825, 0.08, 0.5], [990, 0.07, 1.0], [1320, 0.03, 1.5]],
				"noise": [2500.0, 0.8, 0.08], "swell": 2}
		"combat":  # a deep drone beating against itself, pulsing twice a second
			return {"parts": [[248, 0.30, 0.0], [251, 0.20, 1.3], [372, 0.14, 0.7]], "noise": [], "swell": 12}
	return {"parts": [], "noise": [], "swell": 1}


static func render(name: String) -> AudioStreamWAV:
	var r := _recipe(name)
	var n := RATE * SECONDS
	var m := RATE / 2  # the noise's seam is crossfaded over half a second
	var noise := PackedFloat32Array()
	noise.resize(n)
	var nz: Array = r["noise"]
	if not nz.is_empty():
		# white noise through a band-pass (RBJ biquad); n + m samples, the tail blended into the head
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(name)
		var w0 := TAU * float(nz[0]) / RATE
		var alpha := sin(w0) / (2.0 * float(nz[1]))
		var a0 := 1.0 + alpha
		var b0 := alpha / a0
		var a1 := -2.0 * cos(w0) / a0
		var a2 := (1.0 - alpha) / a0
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		var raw := PackedFloat32Array()
		raw.resize(n + m)
		for i in n + m:
			var x := rng.randf() * 2.0 - 1.0
			var y := b0 * x - b0 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			raw[i] = y * float(nz[2])
		for i in n:
			noise[i] = raw[i] if i >= m else lerpf(raw[n + i], raw[i], float(i) / m)
	var parts: Array = r["parts"]
	var swell: int = r["swell"]
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / n  # 0..1 over the loop
		var v := noise[i]
		for p: Array in parts:
			v += p[1] * sin(TAU * p[0] * t + p[2])
		v *= 0.65 + 0.35 * sin(TAU * swell * t)
		data.encode_s16(i * 2, clampi(int(v * 32767.0 * 0.8), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

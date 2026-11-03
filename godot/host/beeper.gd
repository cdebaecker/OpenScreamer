# The PC-98 beeper: a ~2 kHz square wave the game gates on and off (int 18h AH=17h/18h)
# in timed loops.  Each gated pattern is placed on the audio stream at the matching point
# of the virtual timeline and rendered as the stream is filled.
class_name Beeper
extends AudioStreamPlayer

const BEEP_HZ := 2000.0
const VOLUME := 0.12
const RATE := 44100.0

var sys: Sys
## the sound of the beeper (settings): "square" as on the PC-98, "soft" (filtered), "sine"
var tone := "square"
var _lp := 0.0  # the "soft" tone's filter
## how fast the host runs the game's clock (fast-forward): patterns play that much shorter
var speed := 1.0
var _playback: AudioStreamGeneratorPlayback
var _pushed := 0  # samples pushed so far
var _busy_until := 0
var _patterns: Array[Dictionary] = []  # {start, end (samples), on_us, off_us}
var _silence := PackedVector2Array()


func _ready() -> void:
	# streamed, not as a sample: on the web, Godot plays samples by default, and a generator
	# can't be one (the beeper would stay silent)
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.1
	stream = gen
	play()
	_playback = get_stream_playback()


func beep(t: int, on_us: int, off_us: int, count: int) -> void:
	if playing and _playback != null:
		schedule(t, on_us, off_us, count)


## place a gated pattern on the stream where the virtual clock says it starts, relative to the
## host clock, and after anything still playing
func schedule(t: int, on_us: int, off_us: int, count: int) -> void:
	on_us = roundi(on_us / speed)
	off_us = roundi(off_us / speed)
	var total := (on_us + off_us) * count
	if total <= 0:
		return
	var n := clampi(roundi(total / 1e6 * RATE), 1, int(RATE) * 10)
	var ahead := maxi(0, roundi((t - sys.host.now_us()) / speed)) if sys != null and sys.host != null else 0
	var start := maxi(_pushed + roundi(ahead / 1e6 * RATE), _busy_until)
	_patterns.append({"start": start, "end": start + n, "on_us": on_us, "period": on_us + off_us})
	_busy_until = start + n


func _process(_delta: float) -> void:
	if not playing:  # not started yet (on the web, audio waits for the player's first click)
		play()
		_playback = get_stream_playback()
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n > 0:
		_playback.push_buffer(render(n))


## the next n samples of the stream
func render(n: int) -> PackedVector2Array:
	var end := _pushed + n
	while not _patterns.is_empty() and _patterns[0]["end"] <= _pushed:
		_patterns.pop_front()
	if _patterns.is_empty() or _patterns[0]["start"] >= end:
		if _silence.size() != n:
			_silence.resize(n)
		_pushed = end
		return _silence
	var buf := PackedVector2Array()
	buf.resize(n)
	var pi := 0
	for i in n:
		var s := _pushed + i
		while pi < _patterns.size() and _patterns[pi]["end"] <= s:
			pi += 1
		if pi >= _patterns.size():
			break
		var p: Dictionary = _patterns[pi]
		if s < p["start"]:
			continue
		var us := (s - int(p["start"])) / RATE * 1e6
		if fmod(us, float(p["period"])) >= float(p["on_us"]):
			continue
		var phase := fmod(us * BEEP_HZ / 1e6, 1.0)
		var v := VOLUME if phase < 0.5 else -VOLUME
		if tone == "sine":
			v = VOLUME * sin(TAU * phase)
		elif tone == "soft":  # a one-pole low-pass rounds the square's edges
			_lp += (v - _lp) * 0.18
			v = _lp
		buf[i] = Vector2(v, v)
	_pushed = end
	return buf


func _exit_tree() -> void:
	stop()
	_playback = null

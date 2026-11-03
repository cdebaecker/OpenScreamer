## Time and flow.
##
## Game routines are coroutines driven by a virtual clock that runs at the pace of the original
## 8 MHz PC-9801: `advance()` suspends whenever the virtual clock gets ahead of the host's real
## clock.  Delays and beeps are expressed in the original's delay units (~50 us).
##
## The original leaves deep call chains by resetting the stack and jumping (`mov sp, /
## jmp target`).  GDScript has no exceptions, so `jump()` raises `unwinding`: every caller
## returns as soon as it sees the flag after a call, and Program starts the target.
class_name Sys
extends RefCounted

## One delay unit of the original busy-wait loop is ~50 us on an 8 MHz machine.
const DELAY_UNIT_US := 50

## never emitted: a halted program waits on it forever
signal _never

## virtual clock in microseconds
var clock := 0
## Real-time host: an object with `now_us() -> int` and a `tick` signal emitted every frame.
## Without one (headless runs) the virtual clock never waits.
var host: Object = null
## sound output: an object with `beep(t_us, on_us, off_us, count)`, or null
var audio: Object = null
var muted := false

## the last beeper parameters (the beeper reads them again)
var beep_on := 0
var beep_off := 0
var beep_count := 0

## set by jump(): callers return until Program picks up `jump_target`
var unwinding := false
var jump_target := &""
## the program has ended (or a scripted run is over): the game coroutine stops for good
var halted := false
## called after the clock advances (used by scripted runs)
var on_advance := Callable()
## the player's option to fix the original's bugs (off: the game as in 1985).  Each fix is marked
## `sys.fix_bugs` where it is; the list is in ARCHITECTURE.md
var fix_bugs := false
## the way to floor 6, as on the PC-88: the pendant chain works in BIAS (the PC-98 port reads the
## wrong gift table there) and the last doors open with their password alone (the PC-98's blade test
## seals the Samurai's room and floor 6 behind doors that need the blade and its absence); a setting
## of its own, on by default in the game
var pendant_fix := false
## the host's journal: called with what the screamer learns or finds (kind, subject, text: original
## strings); a hint for the host, not game state
var on_journal := Callable()
## > 0 while typewriter text prints (a hint for the host, which can show it at once; not game state)
var hurry := 0


func advance(us: int) -> void:
	clock += us
	if on_advance.is_valid():
		on_advance.call()
	if halted:
		await _never
	if host != null:
		while clock > host.now_us():
			await host.tick
			if halted:
				await _never


func journal(kind: StringName, subject: String, text: String = "") -> void:
	if on_journal.is_valid():
		on_journal.call(kind, subject, text)


## busy-wait `units` delay units
func delay(units: int) -> void:
	await advance(units * DELAY_UNIT_US)


## the beeper, `count` times (on `on` units, off `off` units)
func beep(on: int, off: int, count: int) -> void:
	beep_on = on
	beep_off = off
	beep_count = count
	await beep_last()


## a beep with the parameters of the previous one
func beep_last() -> void:
	var on_us := beep_on * DELAY_UNIT_US
	var off_us := beep_off * DELAY_UNIT_US
	sound(on_us, off_us, beep_count)
	await advance((on_us + off_us) * beep_count)


## schedule a beeper pattern at the current virtual time without waiting for it
func sound(on_us: int, off_us: int, count: int) -> void:
	if audio != null and not muted:
		audio.beep(clock, on_us, off_us, count)


## leave the current call chain and continue at a flow target (see Program)
func jump(target: StringName) -> void:
	unwinding = true
	jump_target = target


## end the program: the game coroutine is parked for good
func halt() -> void:
	halted = true

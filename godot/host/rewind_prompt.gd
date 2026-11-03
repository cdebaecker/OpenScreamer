## On the death screen, from the bar's "Go back…" (when rewinding is on and there are states to go
## back to): go back 1..N steps, or not now.  ← → (d-pad) choose how far, Space / Enter / A go back,
## Esc / B back to the death screen (where Space accepts death, as in the original).  The game is
## paused while it's shown.
class_name RewindPrompt
extends PanelContainer

signal chosen(steps: int)  # 0: accept death

var available := 0
var steps := 1

var _label: Label


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.02, 0.03)
	bg.border_color = Color(0.7, 0.15, 0.15)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(14)
	add_theme_stylebox_override("panel", bg)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func open(n: int) -> void:
	available = n
	steps = mini(3, n)
	visible = true
	_show()


func _show() -> void:
	_label.text = (tr("Your screamer has died.\n\nGo back  ◀  1 step  ▶  before it happened?\n\nSpace / A: go back      Esc / B: not now")
			if steps == 1 else tr("Your screamer has died.\n\nGo back  ◀  %d steps  ▶  before it happened?\n\nSpace / A: go back      Esc / B: not now") % steps)


func _input(e: InputEvent) -> void:
	if not visible:
		return
	var k := e as InputEventKey
	var jb := e as InputEventJoypadButton
	var pressed := (k != null and k.pressed and not k.echo) or (jb != null and jb.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if e.is_action_pressed(&"ui_left") or e.is_action_pressed(&"ui_right"):
		steps = clampi(steps + (-1 if e.is_action_pressed(&"ui_left") else 1), 1, available)
		_show()
	elif e.is_action_pressed(&"ui_accept"):
		visible = false
		chosen.emit(steps)
	elif e.is_action_pressed(&"ui_cancel"):
		visible = false
		chosen.emit(0)

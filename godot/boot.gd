## The first screen: the game when the original disk has been imported, otherwise a page asking for
## the player's disk image (chosen with a file dialog, or dropped on the window).  Nothing of the
## original game comes with the program: Import reads it from that image.
extends Control

const GAME := "res://main.tscn"

var _status: Label
var _dialog: FileDialog


func _ready() -> void:
	if Import.ready():
		_start.call_deferred()
		return
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.043, 0.063)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 40)
	box.size = Vector2(560, 360)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := Label.new()
	title.text = "THE SCREAMER"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = tr("This program plays the PC-9801 version of THE SCREAMER from your own copy of the game: it comes with nothing from the original.\n\nChoose the image of the original disk (.fdd, .hdm, .d88, or a .zip holding one), or drop it on this window. It is read once and kept on this computer.")
	box.add_child(text)
	var choose := Button.new()
	choose.text = tr("Choose the disk image…")
	choose.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	choose.pressed.connect(_choose)
	box.add_child(choose)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
	box.add_child(_status)
	var notice := Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size", 11)
	notice.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	notice.text = tr("THE SCREAMER © 1985 Magical Zoo / ASCII Corporation. This is an unofficial, non-commercial fan project, not affiliated with or endorsed by the copyright holders.")
	box.add_child(notice)
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.filters = PackedStringArray(["*.fdd, *.hdm, *.xdf, *.tfd, *.d88, *.d98, *.zip ; " + tr("Disk images")])
	_dialog.file_selected.connect(_import)
	add_child(_dialog)
	get_window().files_dropped.connect(func(files: PackedStringArray) -> void: _import(files[0]))
	choose.grab_focus()


func _choose() -> void:
	_dialog.popup_centered_ratio(0.6)


func _import(file: String) -> void:
	_status.text = tr("Reading %s…") % file.get_file()
	await get_tree().process_frame
	var err := Import.from_image(file)
	if err != "":
		_status.text = err
		return
	GameData.reload()
	Art.reload()
	_start()


func _start() -> void:
	get_tree().change_scene_to_file(GAME)

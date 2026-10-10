class_name SlotScreen
extends Control
## Picking a save slot (week 41): three slots, each showing who lived there
## last ("Ossik, life 4, year 2031, 1 h 12 min"). In NEW mode an empty slot
## starts a world at once and a used one asks to be pressed twice (it will
## be overwritten); in LOAD mode only used slots can be picked.

signal chosen(slot: int)
signal closed

enum Mode { NEW, LOAD }

var mode := Mode.LOAD
var _list: VBoxContainer
var _title: Label
var _armed := -1  # A used slot pressed once in NEW mode.


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 200)
	centre.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)
	_list = VBoxContainer.new()
	root.add_child(_list)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	root.add_child(back)
	UiSounds.wire(self)
	visible = false


func open(new_mode: Mode) -> void:
	mode = new_mode
	_armed = -1
	_title.text = "New game: pick a slot" if mode == Mode.NEW else "Load: pick a slot"
	_refresh()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var first: Button = null
	for slot in SaveSystem.SLOTS:
		var info := SaveSystem.summary(slot)
		var button := Button.new()
		button.text = "%d.  %s" % [slot, describe(info)]
		if _armed == slot:
			button.text = "%d.  Press again to overwrite %s" % [slot, info.get("host", "it")]
		button.disabled = mode == Mode.LOAD and info.is_empty()
		button.pressed.connect(_on_slot.bind(slot, info.is_empty()))
		_list.add_child(button)
		if first == null and not button.disabled:
			first = button
	if first:
		first.grab_focus.call_deferred()


func _on_slot(slot: int, empty: bool) -> void:
	if mode == Mode.NEW and not empty and _armed != slot:
		_armed = slot
		_refresh()
		return
	visible = false
	chosen.emit(slot)


## "Ossik, life 4, year 2031, 1 h 12 min" or "Empty".
static func describe(info: Dictionary) -> String:
	if info.is_empty():
		return "Empty"
	var minutes := int(info.get("seconds", 0.0) / 60.0)
	var played := "%d h %d min" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d min" % minutes
	return "%s, life %d, year %d, %s" % [info.get("host", "?"), info.get("lives", 1), info.get("year", 0), played]

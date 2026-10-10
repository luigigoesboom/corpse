class_name HistoryLog
extends Control
## F2 toggles the event log: everything that ever happened in this world,
## oldest first, as sentences (EventText). A debug tool (ARCHITECTURE.md):
## players will learn history from murals and rumors instead (weeks 30, 34).
## Up / Down / Page Up / Page Down scroll.

var _text: RichTextLabel


func _ready() -> void:
	visible = false
	process_mode = PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_text = RichTextLabel.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = 12
	_text.offset_top = 10
	_text.offset_right = -12
	_text.offset_bottom = -10
	_text.scroll_following = false
	_text.bbcode_enabled = true
	add_child(_text)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_history"):
		visible = not visible
		if visible:
			refresh()
		get_viewport().set_input_as_handled()
	elif visible:
		var bar := _text.get_v_scroll_bar()
		var step := 0.0
		if event.is_action_pressed("ui_down"):
			step = 16.0
		elif event.is_action_pressed("ui_up"):
			step = -16.0
		elif event is InputEventKey and event.pressed and event.keycode == KEY_PAGEDOWN:
			step = 300.0
		elif event is InputEventKey and event.pressed and event.keycode == KEY_PAGEUP:
			step = -300.0
		if step != 0.0:
			bar.value += step
			get_viewport().set_input_as_handled()


func refresh() -> void:
	if WorldState.data == null:
		return
	var lines := PackedStringArray()
	lines.append("[color=#e0b84a]%d events. F2 closes.[/color]" % WorldState.data.events.size())
	for event in WorldState.data.events:
		lines.append(EventText.line(event, WorldState.data))
	_text.text = "\n".join(lines)


func line_count() -> int:
	return WorldState.data.events.size() if WorldState.data else 0

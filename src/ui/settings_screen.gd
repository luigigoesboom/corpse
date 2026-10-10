class_name SettingsScreen
extends Control
## Settings (week 41): Sound (a slider per bus), Display (fullscreen, screen
## shake), Controls (every rebindable action: click it, press a key or mouse
## button; Esc cancels). Opened from the main menu and the pause menu; the
## Settings autoload applies and saves each change at once.

signal closed

const TABS := ["Sound", "Display", "Controls"]
const BUS_NAMES := {&"Master": "Everything", &"Music": "Music", &"Ambience": "The body", &"SFX": "Sounds", &"UI": "Menus"}

var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _key_buttons := {}  # action -> Button
var _waiting_for: StringName = &""


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	UiSounds.wire(self)
	Settings.changed.connect(_refresh_keys)
	visible = false


func open(tab := 0) -> void:
	visible = true
	_show_tab(tab)


func close() -> void:
	_waiting_for = &""
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _waiting_for != &"":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode != KEY_ESCAPE:
				Settings.rebind(_waiting_for, event)
			_waiting_for = &""
			_refresh_keys()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			Settings.rebind(_waiting_for, event)
			_waiting_for = &""
			_refresh_keys()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 280)
	centre.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(header)
	for i in TABS.size():
		var button := Button.new()
		button.text = TABS[i]
		button.custom_minimum_size = Vector2(90, 0)
		button.toggle_mode = true
		button.pressed.connect(_show_tab.bind(i))
		header.add_child(button)
		_tab_buttons.append(button)
	var pages := MarginContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages)
	_pages = [_build_sound(), _build_display(), _build_controls()]
	for page in _pages:
		pages.add_child(page)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	root.add_child(back)


func _show_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].button_pressed = i == index
	_tab_buttons[index].grab_focus()


func _row(page: Container, label: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var text := Label.new()
	text.text = label
	text.custom_minimum_size = Vector2(150, 0)
	row.add_child(text)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	page.add_child(row)


func _build_sound() -> Control:
	var page := VBoxContainer.new()
	for bus in Settings.BUSES:
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.volumes[bus]
		slider.value_changed.connect(func(v): Settings.set_volume(bus, v))
		slider.drag_ended.connect(func(_c): Sfx.play(&"ui_select" if bus in [&"UI", &"Master"] else &"squelch"))
		_row(page, BUS_NAMES[bus], slider)
	return page


func _build_display() -> Control:
	var page := VBoxContainer.new()
	var full := CheckBox.new()
	full.text = "Fullscreen"
	full.button_pressed = Settings.fullscreen
	full.toggled.connect(Settings.set_fullscreen)
	_row(page, "Window", full)
	var shake := HSlider.new()
	shake.min_value = 0.0
	shake.max_value = 1.0
	shake.step = 0.1
	shake.value = Settings.screen_shake
	shake.value_changed.connect(Settings.set_screen_shake)
	_row(page, "Screen shake", shake)
	return page


func _build_controls() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	for action in Settings.REBINDABLE:
		var button := Button.new()
		button.pressed.connect(func():
			_waiting_for = action
			button.text = "Press a key... (Esc: keep)")
		_key_buttons[action] = button
		_row(page, Settings.REBINDABLE[action], button)
	var reset := Button.new()
	reset.text = "Reset all to defaults"
	reset.pressed.connect(Settings.reset_bindings)
	page.add_child(reset)
	var note := Label.new()
	note.text = "A gamepad works too: its buttons are not changed here."
	note.modulate = Color(1, 1, 1, 0.6)
	page.add_child(note)
	_refresh_keys()
	return scroll


func _refresh_keys() -> void:
	for action in _key_buttons:
		if action != _waiting_for:
			_key_buttons[action].text = Settings.binding_text(action)

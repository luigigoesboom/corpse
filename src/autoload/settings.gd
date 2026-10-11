extends Node
## Player settings (week 41), kept in user://settings.cfg and applied at
## start: volume per bus, fullscreen, screen shake strength, and key
## bindings. The settings screen (src/ui/settings_screen.gd) changes them
## through the functions below; each change is applied and saved at once.

signal changed

const PATH := "user://settings.cfg"
const BUSES := [&"Master", &"Music", &"Ambience", &"SFX", &"UI"]
## Actions a player may rebind, in the order the Controls tab shows them,
## with the name it shows.
const REBINDABLE := {
	&"move_left": "Move left", &"move_right": "Move right", &"move_down": "Down (drop through)", &"jump": "Jump", &"attack": "Attack",
	&"dodge": "Dodge roll", &"sneak": "Sneak", &"interact": "Talk / take / use",
	&"ability_mouth": "Mouth mutation", &"ability_arm": "Arm mutation", &"ability_head": "Head mutation", &"inventory": "Inventory",
	&"quick_save": "Quick save", &"quick_load": "Quick load",
}

## Where settings are kept (tests point it elsewhere so they never touch yours).
var path := PATH
var volumes := {}  # bus -> 0..1
var fullscreen := false
## 0 (no shake) .. 1 (full).
var screen_shake := 1.0
## Vignette, fog, grading, motes (src/world/atmosphere.gd): 0 (off) .. 1 (full).
var atmosphere := 1.0
var film_grain := true
## action -> serialized keyboard / mouse event (joypad events are kept as they are).
var _bindings := {}
var _defaults := {}  # action -> Array[InputEvent] from project.godot


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for action in REBINDABLE:
		_defaults[action] = InputMap.action_get_events(action).duplicate()
	for bus in BUSES:
		volumes[bus] = 1.0 if bus != &"Music" else 0.8
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for bus in BUSES:
		volumes[bus] = clampf(float(cfg.get_value("sound", String(bus), volumes[bus])), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	screen_shake = clampf(float(cfg.get_value("display", "screen_shake", screen_shake)), 0.0, 1.0)
	atmosphere = clampf(float(cfg.get_value("display", "atmosphere", atmosphere)), 0.0, 1.0)
	film_grain = bool(cfg.get_value("display", "film_grain", film_grain))
	for action in REBINDABLE:
		var saved = cfg.get_value("keys", String(action)) if cfg.has_section_key("keys", String(action)) else null
		if saved is Dictionary:
			_bindings[action] = saved


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in BUSES:
		cfg.set_value("sound", String(bus), volumes[bus])
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "screen_shake", screen_shake)
	cfg.set_value("display", "atmosphere", atmosphere)
	cfg.set_value("display", "film_grain", film_grain)
	for action in _bindings:
		cfg.set_value("keys", String(action), _bindings[action])
	cfg.save(path)


func apply() -> void:
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)) + _base_db(bus))
			AudioServer.set_bus_mute(index, volumes[bus] <= 0.001)
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	for action in REBINDABLE:
		_apply_binding(action)
	changed.emit()


func set_volume(bus: StringName, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	apply()
	save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	save_settings()


func set_screen_shake(value: float) -> void:
	screen_shake = clampf(value, 0.0, 1.0)
	save_settings()


func set_atmosphere(value: float) -> void:
	atmosphere = clampf(value, 0.0, 1.0)
	save_settings()


func set_film_grain(on: bool) -> void:
	film_grain = on
	save_settings()


## Binds `action` to a key or mouse button instead of its keyboard / mouse
## default. Joypad buttons stay as they are.
func rebind(action: StringName, event: InputEvent) -> void:
	if event is InputEventKey:
		_bindings[action] = {"type": "key", "physical_keycode": event.physical_keycode}
	elif event is InputEventMouseButton:
		_bindings[action] = {"type": "mouse", "button_index": event.button_index}
	else:
		return
	_apply_binding(action)
	save_settings()
	changed.emit()


func reset_bindings() -> void:
	_bindings.clear()
	for action in REBINDABLE:
		_apply_binding(action)
	save_settings()
	changed.emit()


## What a player presses for an action, as text: "Space", "Left mouse".
func binding_text(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if event.physical_keycode != 0 and DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(code)  # As labelled on this keyboard.
			return OS.get_keycode_string(code)
		if event is InputEventMouseButton:
			return ["", "Left mouse", "Right mouse", "Middle mouse"][clampi(event.button_index, 0, 3)] if event.button_index <= 3 else "Mouse %d" % event.button_index
	return "-"


func _apply_binding(action: StringName) -> void:
	InputMap.action_erase_events(action)
	var custom: Dictionary = _bindings.get(action, {})
	for event in _defaults[action]:
		var keyboard_or_mouse: bool = event is InputEventKey or event is InputEventMouseButton
		if custom.is_empty() or not keyboard_or_mouse:
			InputMap.action_add_event(action, event)
	if custom.get("type") == "key":
		var key := InputEventKey.new()
		key.physical_keycode = custom.physical_keycode
		InputMap.action_add_event(action, key)
	elif custom.get("type") == "mouse":
		var button := InputEventMouseButton.new()
		button.button_index = custom.button_index
		InputMap.action_add_event(action, button)


## The bus layout's own level (Ambience sits lower than the rest).
func _base_db(bus: StringName) -> float:
	return -6.0 if bus == &"Ambience" else 0.0

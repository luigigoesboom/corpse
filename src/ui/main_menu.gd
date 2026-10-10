extends Control
## Title screen (week 41): the body drifting behind the title; Continue (the
## most recent save), New game (pick a slot), Load, Settings, Quit; the
## controls along the bottom. Test arenas only in debug builds.

const GAME := "res://game.tscn"
const BACKDROP := preload("res://scenes/backdrop.tscn")
const TITLE := preload("res://assets/ui/title.png")
const ARENAS := {
	"Combat test: tight": "res://scenes/arenas/arena_tight.tscn",
	"Combat test: loose": "res://scenes/arenas/arena_loose.tscn",
	"Boss: the Gullet Matron": "res://scenes/arenas/boss_arena.tscn",
}

var _backdrop: CanvasLayer
var _settings: SettingsScreen
var _slots: SlotScreen
var _buttons: VBoxContainer
var _status: Label
var _hint: Label
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = BACKDROP.instantiate()
	_backdrop.set_process(false)  # No camera here: we drift it ourselves.
	add_child(_backdrop)
	_build()
	_settings = SettingsScreen.new()
	_settings.closed.connect(_focus_first)
	add_child(_settings)
	_slots = SlotScreen.new()
	_slots.chosen.connect(_on_slot_chosen)
	_slots.closed.connect(_focus_first)
	add_child(_slots)
	UiSounds.wire(self)
	Settings.changed.connect(_refresh_hint)
	_refresh_hint()
	_focus_first()


func _process(delta: float) -> void:
	_time += delta
	var material: ShaderMaterial = _backdrop.get_node("Wall").material
	material.set_shader_parameter("camera_position", Vector2(_time * 14.0, sin(_time * 0.2) * 60.0))
	material.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)


func _build() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var title := TextureRect.new()
	title.texture = TITLE
	title.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	title.custom_minimum_size = Vector2(0, TITLE.get_height())
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "a god fell, and we live inside it"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.7)
	column.add_child(subtitle)
	var centre := CenterContainer.new()
	column.add_child(centre)
	_buttons = VBoxContainer.new()
	_buttons.custom_minimum_size = Vector2(180, 0)
	_buttons.add_theme_constant_override("separation", 3)
	centre.add_child(_buttons)
	var latest := SaveSystem.latest_slot()
	if latest >= 0:
		var host: String = SaveSystem.summary(latest).get("host", "")
		_button("Continue" + ("  (%s)" % host if host != "" else ""), _on_continue.bind(latest))
	_button("New game", func(): _slots.open(SlotScreen.Mode.NEW))
	if latest >= 0:
		_button("Load", func(): _slots.open(SlotScreen.Mode.LOAD))
	_button("Settings", func(): _settings.open())
	_button("Quit", get_tree().quit)
	if OS.is_debug_build():  # Test arenas, small, in one row.
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(row)
		for name in ARENAS:
			var b := Button.new()
			b.text = name.replace("Combat test: ", "Test ").replace("Boss: the ", "")
			b.modulate = Color(1, 1, 1, 0.5)
			b.pressed.connect(get_tree().change_scene_to_file.bind(ARENAS[name]))
			row.add_child(b)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -22
	_hint.offset_bottom = -4
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(1, 1, 1, 0.6)
	add_child(_hint)


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	_buttons.add_child(button)
	return button


func _focus_first() -> void:
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus.call_deferred()


func _refresh_hint() -> void:
	var parts := PackedStringArray()
	var short := {&"move_left": "Left", &"move_right": "Right", &"jump": "Jump", &"attack": "Attack",
		&"dodge": "Roll", &"sneak": "Sneak", &"interact": "Use", &"inventory": "Inventory"}
	for action in short:
		parts.append("%s %s" % [short[action], Settings.binding_text(action)])
	_hint.text = "   ".join(parts) + "   Esc pause"


func _on_continue(slot: int) -> void:
	var err := SaveSystem.load_game(slot)
	if err != OK:
		_status.text = "Could not load the save: %s" % error_string(err)
		return
	get_tree().change_scene_to_file(GAME)


func _on_slot_chosen(slot: int) -> void:
	if _slots.mode == SlotScreen.Mode.LOAD:
		_on_continue(slot)
		return
	WorldState.clear()  # The game starts a fresh world when there is none...
	WorldState.slot = slot  # ...and saves it here.
	get_tree().change_scene_to_file(GAME)

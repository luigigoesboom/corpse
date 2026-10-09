extends Control
## The pockets (grid of slots, details, Eat / Drop) and the host's body slots.
## Works with mouse, keyboard (arrows + Enter) and gamepad (d-pad + A).

const SLOT_SIZE := Vector2(96, 96)

var _selected := 0
var _slots: Array[Button] = []

@onready var _grid: GridContainer = %Grid
@onready var _name: Label = %ItemName
@onready var _description: Label = %ItemDescription
@onready var _drop: Button = %DropButton
@onready var _eat: Button = %EatButton
@onready var _body: Label = %Body


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for i in WorldData.INVENTORY_SIZE:
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.clip_text = true
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.expand_icon = false
		slot.focus_entered.connect(_select.bind(i))
		slot.mouse_entered.connect(slot.grab_focus)
		slot.pressed.connect(_on_slot_pressed)
		_grid.add_child(slot)
		_slots.append(slot)
	_drop.pressed.connect(_on_drop_pressed)
	_eat.pressed.connect(_on_eat_pressed)
	EventBus.inventory_changed.connect(_refresh)
	EventBus.mutations_changed.connect(_refresh)


## Called by GameUI when the screen opens.
func open() -> void:
	_refresh()
	_slots[_selected].grab_focus()


func _refresh() -> void:
	if WorldState.data == null:
		return
	for i in _slots.size():
		var item_id: StringName = WorldState.data.inventory[i]
		var def := ItemDb.get_def(item_id) if item_id != &"" else null
		_slots[i].text = ItemDb.display_name(item_id) if item_id != &"" else ""
		_slots[i].icon = _swatch(def.color) if def else null
	var lines := PackedStringArray()
	for slot in ["head", "mouth", "back", "arm", "belly"]:
		var mutation := MutationDb.get_def(WorldState.data.mutations.get(slot, &""))
		lines.append("%s: %s" % [slot.capitalize(), mutation.display_name if mutation else "-"])
	_body.text = "\n".join(lines)
	_select(_selected)


func _select(slot: int) -> void:
	_selected = slot
	var item_id: StringName = WorldState.data.inventory[slot]
	var def := ItemDb.get_def(item_id) if item_id != &"" else null
	_name.text = def.display_name if def else "Empty pocket"
	_description.text = def.description if def else ""
	_drop.disabled = item_id == &""
	_eat.disabled = def == null or def.grants_mutation == &""
	var mutation := MutationDb.get_def(def.grants_mutation) if def and def.grants_mutation != &"" else null
	if mutation:
		_description.text += "\n\nEating it grows a %s (%s)." % [mutation.display_name, mutation.slot]


func _on_slot_pressed() -> void:
	if not _eat.disabled:
		_eat.grab_focus()
	elif not _drop.disabled:
		_drop.grab_focus()


func _on_eat_pressed() -> void:
	EventBus.eat_requested.emit(_selected)
	_slots[_selected].grab_focus()


func _on_drop_pressed() -> void:
	EventBus.drop_requested.emit(_selected)
	_slots[_selected].grab_focus()


## Placeholder icon until item art exists: a square in the item's color.
func _swatch(color: Color) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

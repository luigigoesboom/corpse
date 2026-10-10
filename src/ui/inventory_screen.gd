extends Control
## The inventory (week 25 rework): three tabs.
##   Pockets: the 8 pockets and what the selected item does. Enter eats, X drops.
##   Body:    this host and the part in each body slot, with its key.
##   Lives:   every host so far, where its body lies and what is still on it.
##   History: what the fragment has read on murals and tablets, per people (week 35).
## Q / E (LB / RB on a pad) switch tabs, Tab or Esc closes (GameUI).
## Keyboard and gamepad move the selection; the mouse selects by hovering and
## uses the buttons. Built in code: the .tscn is just this script on a Control.

const TABS := ["Pockets", "Body", "Lives", "History"]
const BODY_SLOTS := ["head", "mouth", "back", "arm", "belly"]
const SLOT_SIZE := Vector2(52, 52)
const CREATURE_NAMES: Dictionary = preload("res://src/ui/death_screen.gd").CREATURE_NAMES
const WARN := Color(1, 0.75, 0.45)
const DIM_TEXT := Color(0.75, 0.7, 0.72)
const PANEL_COLOR := Color(0.08, 0.04, 0.05, 0.97)
const BORDER_COLOR := Color(0.45, 0.2, 0.23)
const TAB_ON_COLOR := Color(0.38, 0.13, 0.16)

var tab := 0
var _selected := 0
var _slots: Array[Button] = []
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []

var _name: Label
var _description: Label
var _effect: Label
var _eat: Button
var _drop: Button
var _host: Label
var _body_list: GridContainer
var _lives_list: VBoxContainer
var _history_scroll: ScrollContainer
var _history_list: VBoxContainer
var _lives_scroll: ScrollContainer
var _hints: Label


func _ready() -> void:
	UiSounds.wire(self)  # Hover and select sounds (week 40).
	process_mode = PROCESS_MODE_ALWAYS
	_build()
	EventBus.inventory_changed.connect(_refresh)
	EventBus.mutations_changed.connect(_refresh)


## Called by GameUI when the screen opens.
func open() -> void:
	show_tab(tab)


func show_tab(index: int) -> void:
	if index != tab:
		Sfx.play(&"ui_tab")
	tab = posmod(index, TABS.size())
	for i in _pages.size():
		_pages[i].visible = i == tab
		_tab_buttons[i].button_pressed = i == tab
	_refresh()
	match tab:
		0:
			_slots[_selected].grab_focus()
			_hints.text = "Arrows: choose    Enter: eat    X: drop    Q / E: tabs    Tab: close"
		1:
			_tab_buttons[tab].grab_focus()
			_hints.text = "Q / E: tabs    Tab: close"
		2, 3:
			_tab_buttons[tab].grab_focus()
			_scroll_of(tab).scroll_vertical = 0
			_hints.text = "Up / Down: scroll    Q / E: tabs    Tab: close"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_tab_prev"):
		show_tab(tab - 1)
	elif event.is_action_pressed("ui_tab_next"):
		show_tab(tab + 1)
	elif tab == 0 and event.is_action_pressed("ui_drop"):
		_on_drop_pressed()
	elif tab >= 2 and event.is_action_pressed("ui_down"):
		_scroll_of(tab).scroll_vertical += 24
	elif tab >= 2 and event.is_action_pressed("ui_up"):
		_scroll_of(tab).scroll_vertical -= 24
	else:
		return
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	if WorldState.data == null or _slots.is_empty():
		return
	var data := WorldState.data
	for i in _slots.size():
		var item_id: StringName = data.inventory[i]
		var def := ItemDb.get_def(item_id) if item_id != &"" else null
		_slots[i].text = ItemDb.display_name(item_id) if def else ""
		_slots[i].icon = _swatch(def.color) if def else null
	_select(_selected)
	_refresh_body()
	_refresh_lives()
	_refresh_history()


# --- Pockets ---------------------------------------------------------------

func _select(slot: int) -> void:
	_selected = slot
	var data := WorldState.data
	var item_id: StringName = data.inventory[slot]
	var def := ItemDb.get_def(item_id) if item_id != &"" else null
	_name.text = def.display_name if def else "Empty pocket"
	_description.text = def.description if def else "Pick things up with E. Some of them can be eaten."
	_effect.text = ""
	var mutation := MutationDb.get_def(def.grants_mutation) if def and def.grants_mutation != &"" else null
	if mutation:
		_effect.text = "Eating it grows %s (%s): %s" % [_a(mutation.display_name), mutation.slot, mutation.description]
		var current := MutationDb.get_def(data.mutations.get(mutation.slot, &""))
		if current and current != mutation:
			_effect.text += "\nIt replaces your %s." % current.display_name
		elif current == mutation:
			_effect.text += "\nYou already have one."
	_eat.disabled = mutation == null
	_drop.disabled = def == null


func _on_slot_pressed(slot: int) -> void:
	# Keyboard / gamepad "accept" on a pocket eats it. Mouse users hover to
	# select and click the buttons (slots ignore mouse clicks).
	_select(slot)
	if not _eat.disabled:
		_on_eat_pressed()


func _on_eat_pressed() -> void:
	if _eat.disabled:
		return
	EventBus.eat_requested.emit(_selected)
	_slots[_selected].grab_focus()


func _on_drop_pressed() -> void:
	if _drop.disabled:
		return
	EventBus.drop_requested.emit(_selected)
	_slots[_selected].grab_focus()


# --- Body ------------------------------------------------------------------

func _refresh_body() -> void:
	var data := WorldState.data
	var life := data.current_life()
	var host := HostDb.get_def(life.host_type) if life else null
	if life and host:
		_host.text = "%s, %s. %d hearts.\n%s" % [life.host_name, _a(host.display_name), host.max_health, host.description]
	for child in _body_list.get_children():
		child.queue_free()
	for slot in BODY_SLOTS:
		var mutation := MutationDb.get_def(data.mutations.get(slot, &""))
		var slot_label := _label(slot.capitalize(), 16, DIM_TEXT)
		slot_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_body_list.add_child(slot_label)
		var text := "-"
		if mutation:
			text = mutation.display_name
			if mutation.control_hint != "":
				text += "  [%s]" % mutation.control_hint
			text += "\n" + mutation.description
		var part := _label(text)
		part.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		part.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body_list.add_child(part)


# --- Lives -----------------------------------------------------------------

func _refresh_lives() -> void:
	var data := WorldState.data
	for child in _lives_list.get_children():
		child.queue_free()
	# The fragment itself (week 34): what it has banked and become.
	var owned := Boons.ORDER.filter(func(id): return data.has_boon(id)).map(func(id): return Boons.display_name(id))
	var fragment := _label("The fragment: %d ichor banked. %s" % [data.ichor_banked,
		("Boons: %s." % ", ".join(owned)) if not owned.is_empty() else "No boons yet."], 16, Color(1, 0.55, 0.5))
	fragment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lives_list.add_child(fragment)
	for i in range(data.lives.size() - 1, -1, -1):
		var life: LifeRecord = data.lives[i]
		var host := HostDb.get_def(life.host_type)
		var kind := host.display_name if host else String(life.host_type).capitalize()
		var title := _label("%d. %s, %s%s" % [i + 1, life.host_name, _a(kind), "  (you, now)" if life.is_alive() else ""], 16)
		_lives_list.add_child(title)
		var lines := PackedStringArray()
		if life.is_alive():
			lines.append("Woke at %s in year %d." % [life.origin, life.start_year])
		else:
			var cause := "of causes no one saw"
			if life.killed_by != &"":
				cause = "killed by %s" % _a(CREATURE_NAMES.get(life.killed_by, [String(life.killed_by).capitalize()])[0])
			lines.append("Woke at %s, died in year %d, %s." % [life.origin, life.death_year, cause])
			var site: SiteData = WorldState.data.sites.get(life.corpse_site)
			var keepers := EventText._faction(WorldState.data, life.corpse_faction)
			match life.corpse_state:
				&"enshrined":
					lines.append("%s keep it in their shrine at %s." % [keepers.substr(0, 1).to_upper() + keepers.substr(1), site.name if site else "their home"])
				&"studied":
					lines.append("%s took it to %s and cut it open." % [keepers.substr(0, 1).to_upper() + keepers.substr(1), site.name if site else "their home"])
				&"eaten":
					lines.append("%s fed on it. It lies %s." % [keepers.substr(0, 1).to_upper() + keepers.substr(1), _where(life.corpse_position)])
				_:
					lines.append("The body lies %s." % _where(life.corpse_position))
			if life.corpse_state == &"scavenged" and not life.has_corpse_loot():
				lines.append("Something has picked it clean.")
			elif life.has_corpse_loot():
				lines.append("Still on it: %s." % ", ".join(_corpse_things(life)))
			else:
				lines.append("Nothing is left on it.")
		var body := _label("\n".join(lines), 16, DIM_TEXT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lives_list.add_child(body)


func _corpse_things(life: LifeRecord) -> PackedStringArray:
	var things := PackedStringArray()
	if life.corpse_ichor > 0:
		things.append("%d ichor" % life.corpse_ichor)
	for item in life.corpse_items:
		things.append(ItemDb.display_name(item))
	for slot in life.corpse_mutations:
		var mutation := MutationDb.get_def(life.corpse_mutations[slot])
		things.append(mutation.display_name if mutation else String(life.corpse_mutations[slot]))
	return things


## "near the cavern floor": the closest named place (SpawnPoint) to a spot.
func _where(pos: Vector2) -> String:
	var best := ""
	var best_distance := INF
	for point in get_tree().get_nodes_in_group(&"spawn_points"):
		var distance: float = point.global_position.distance_to(pos)
		if distance < best_distance:
			best_distance = distance
			best = point.place_name
	if best == "":
		return "where it fell"
	return ("near %s" if best_distance < 1200.0 else "far from %s") % best


# --- Building the screen ---------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, BORDER_COLOR))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(540, 300)
	panel.position = -panel.custom_minimum_size / 2.0
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# Tab header: Q  [Pockets] [Body] [Lives]  E
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	root.add_child(header)
	header.add_child(_label("Q", 16, DIM_TEXT))
	var group := ButtonGroup.new()
	for i in TABS.size():
		var button := Button.new()
		button.text = TABS[i]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(80, 0)
		button.add_theme_stylebox_override("pressed", _box(TAB_ON_COLOR, BORDER_COLOR))
		button.add_theme_stylebox_override("hover_pressed", _box(TAB_ON_COLOR, BORDER_COLOR))
		button.pressed.connect(show_tab.bind(i))
		header.add_child(button)
		_tab_buttons.append(button)
	header.add_child(_label("E", 16, DIM_TEXT))

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.custom_minimum_size = Vector2(0, 220)
	root.add_child(pages)
	_pages = [_build_pockets(), _build_body(), _build_lives(), _build_history()]
	for page in _pages:
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		pages.add_child(page)

	_hints = _label("", 16, DIM_TEXT)
	root.add_child(_hints)
	# Reachable as %Grid / %EatButton / %DropButton (tests use them). Only
	# works once they are inside this screen's tree.
	for node in [_slots[0].get_parent(), _eat, _drop]:
		node.unique_name_in_owner = true
		node.owner = self


func _build_pockets() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	page.add_child(grid)
	for i in WorldData.INVENTORY_SIZE:
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.clip_text = true
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 16)
		slot.button_mask = 0  # Mouse clicks do nothing; hovering selects.
		slot.focus_entered.connect(_select.bind(i))
		slot.mouse_entered.connect(slot.grab_focus)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(slot)
		_slots.append(slot)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	page.add_child(details)
	_name = _label("", 16)
	details.add_child(_name)
	_description = _label("")
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(250, 0)
	details.add_child(_description)
	_effect = _label("", 16, WARN)
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_effect)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(spacer)
	var actions := HBoxContainer.new()
	details.add_child(actions)
	_eat = Button.new()
	_eat.name = "EatButton"
	_eat.text = "Eat  [Enter]"
	_eat.focus_mode = Control.FOCUS_NONE  # Keys act on the selected pocket.
	_eat.pressed.connect(_on_eat_pressed)
	actions.add_child(_eat)
	_drop = Button.new()
	_drop.name = "DropButton"
	_drop.text = "Drop  [X]"
	_drop.focus_mode = Control.FOCUS_NONE
	_drop.pressed.connect(_on_drop_pressed)
	actions.add_child(_drop)
	return page


func _build_body() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	_host = _label("", 16)
	_host.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_host)
	_body_list = GridContainer.new()
	_body_list.columns = 2
	_body_list.add_theme_constant_override("h_separation", 12)
	_body_list.add_theme_constant_override("v_separation", 5)
	page.add_child(_body_list)
	page.add_child(_label("Eat god-matter to grow parts. Each slot holds one; a new part replaces the old.", 16, DIM_TEXT))
	return page


func _build_lives() -> Control:
	_lives_scroll = ScrollContainer.new()
	_lives_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lives_list = VBoxContainer.new()
	_lives_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lives_list.add_theme_constant_override("separation", 3)
	_lives_scroll.add_child(_lives_list)
	return _lives_scroll


func _build_history() -> Control:
	_history_scroll = ScrollContainer.new()
	_history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 3)
	_history_scroll.add_child(_history_list)
	return _history_scroll


func _scroll_of(index: int) -> ScrollContainer:
	return _lives_scroll if index == 2 else _history_scroll


# --- History ----------------------------------------------------------------

## Everything read on murals and tablets, per people, oldest first: the past
## pieced together from what you found.
func _refresh_history() -> void:
	var data := WorldState.data
	for child in _history_list.get_children():
		child.queue_free()
	var known := Lore.known_by_people(data)
	if known.is_empty():
		var empty := _label("You know nothing of the past yet. Read the murals in settlements and what is left in ruins.", 16, DIM_TEXT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_history_list.add_child(empty)
		return
	var peoples := known.keys()
	peoples.sort_custom(func(a, b): return known[a][0].year < known[b][0].year)
	for people in peoples:
		var faction: FactionData = data.factions.get(people)
		var title := _label(EventText._faction(data, people).capitalize() if faction == null else faction.display_name, 16)
		if faction:
			title.add_theme_color_override("font_color", faction.color.lightened(0.3))
		_history_list.add_child(title)
		var lines := PackedStringArray()
		for event in known[people]:
			lines.append(EventText.line(event, data))
		var body := _label("
".join(lines), 16, DIM_TEXT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_history_list.add_child(body)


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(3)
	return box


## "a Gut Leech", "an Acid Gland".
func _a(noun: String) -> String:
	return ("an " if noun.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + noun


func _label(text: String, size := 16, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	return label


## Placeholder icon until item art exists: a square in the item's color.
func _swatch(color: Color) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

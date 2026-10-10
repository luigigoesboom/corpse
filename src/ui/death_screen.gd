extends Control
## Shown when the host dies: a short epitaph of the life that just ended.

## "Wake in a new host" on the epitaph: the game runs the aftermath now.
signal continue_pressed
## A host was chosen on the time screen: start the next life as it.
## `option` is one of the game's rebirth options (empty = default host).
signal wake_pressed(option: Dictionary)

## Display names for creature kinds (CombatRules.kind_of).
const CREATURE_NAMES := {
	&"gut_leech": ["Gut Leech", "Gut Leeches"],
	&"rot_fly": ["Rot Fly", "Rot Flies"],
	&"bile_spitter": ["Bile Spitter", "Bile Spitters"],
	&"colony_npc": ["settlement guard", "settlement guards"],
}


var _showing_time := false


func _ready() -> void:
	UiSounds.wire(self)  # Hover and select sounds (week 40).
	process_mode = PROCESS_MODE_ALWAYS
	%ContinueButton.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	if _showing_time:
		wake_pressed.emit({})
	else:
		continue_pressed.emit()


## Second step: how much time passed, a hint or two of what changed, and
## the hosts to wake as (one button each; none = a plain "Wake" button).
func show_time(report: Dictionary, options: Array = []) -> void:
	Sfx.play(&"years")
	_showing_time = true
	%Title.text = Aftermath.gap_text(report)
	var hints: Array = report.hints
	%Summary.text = "\n".join(hints) if not hints.is_empty() else "The body goes on without you."
	for child in %Options.get_children():
		child.queue_free()
	%ContinueButton.visible = options.is_empty()
	for option in options:
		var host := HostDb.get_def(option.host_type)
		var button := Button.new()
		button.text = "%s, a %s, wakes at %s  (%d hearts)" % [option.host_name, host.display_name, option.place, host.max_health + (1 if WorldState.data.has_boon(&"hardy") else 0)]
		button.tooltip_text = host.description
		button.pressed.connect(wake_pressed.emit.bind(option))
		%Options.add_child(button)
	if options.is_empty():
		%ContinueButton.text = "Wake"
		%ContinueButton.grab_focus()
	else:
		%Options.get_child(0).grab_focus.call_deferred()


func show_life(life: LifeRecord, life_number: int) -> void:
	Sfx.play(&"death_sting")
	_showing_time = false
	for child in %Options.get_children():
		child.queue_free()
	%ContinueButton.visible = true
	%ContinueButton.text = "Wake in a new host"
	%Title.text = "Here lies %s" % life.host_name
	var lines := PackedStringArray()
	lines.append("%s, host number %d." % [String(life.host_type).capitalize(), life_number])
	lines.append("Woke in year %d, died in year %d, after %s." % [life.start_year, life.death_year, _duration(life.seconds_alive)])
	if life.killed_by == &"":
		lines.append("Died of causes no one saw.")
	else:
		lines.append("Killed by a %s." % _creature(life.killed_by, 1))
	if not life.carried_mutations.is_empty():
		var parts := PackedStringArray()
		for slot in life.carried_mutations:
			var mutation := MutationDb.get_def(life.carried_mutations[slot])
			parts.append(mutation.display_name if mutation else String(life.carried_mutations[slot]))
		lines.append("Grew: %s." % ", ".join(parts))
	if life.carried_ichor > 0:
		lines.append("%d ichor stays in the body." % life.carried_ichor)
	if not life.carried_items.is_empty():
		lines.append("Carried: %s." % ", ".join(life.carried_items.map(func(id): return ItemDb.display_name(id))))
	if life.has_corpse_loot():
		lines.append("It all stays on the body, where it fell.")
	if life.kills.is_empty():
		lines.append("Killed nothing.")
	else:
		var killed := PackedStringArray()
		for kind in life.kills:
			killed.append("%d %s" % [life.kills[kind], _creature(kind, life.kills[kind])])
		lines.append("Killed %s." % ", ".join(killed))
	%Summary.text = "\n".join(lines)
	%ContinueButton.grab_focus()


func _creature(kind: StringName, count: int) -> String:
	var names: Array = CREATURE_NAMES.get(kind, [String(kind).capitalize(), String(kind).capitalize()])
	return names[0] if count == 1 else names[1]


func _duration(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%d min %d s" % [minutes, int(seconds) % 60] if minutes > 0 else "%d seconds" % int(seconds)

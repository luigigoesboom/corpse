extends "res://tests/test_case.gd"
## Time passing on death (week 23, D-021).


func run() -> void:
	# --- The rules on plain data, with a fixed seed. ---
	var data := WorldData.create(5)
	data.start_life(&"colonist")
	data.inventory[0] = &"bile_bulb"
	data.inventory[1] = &"bone_shard"
	data.inventory[2] = &"breath_sac"
	data.mutations = {"mouth": &"acid_gland", "arm": &"bone_spur"}
	data.removed_entities = {"LeechA": &"gut_leech", "BulbX": &"item", "OldSave": true}
	for i in 10:
		data.add_dropped_item(Vector2i(0, 0), &"bone_shard", Vector2(100 + i, 100))
	data.end_life(Vector2(500, 500), Vector2(500, 522), &"gut_leech")
	var year_before := data.year

	var report := Aftermath.apply(data, 3, SeededRng.make(["test", 1]))  # Decades: strongest.
	var body: LifeRecord = data.lives[0]
	check(data.year - year_before >= 20 and report.years == data.year - year_before, "decades later: the year moves on 20+ years (%d)" % report.years)
	check(body.corpse_items.size() + body.corpse_mutations.size() >= 1, "the newest body always keeps at least one thing")
	check(body.corpse_items.size() + body.corpse_mutations.size() < 5, "but loses some of it to scavengers and rot")
	check(not data.removed_entities.has("LeechA"), "a killed creature can be replaced")
	check(data.removed_entities.has("BulbX") and data.removed_entities.has("OldSave"), "picked-up items never come back")
	check(data.items_in_chunk(Vector2i(0, 0)).size() < 10, "some dropped items rot away (%d of 10 left)" % data.items_in_chunk(Vector2i(0, 0)).size())
	var types := data.events.map(func(event): return event.type)
	check(&"host_died" in types and (&"corpse_scavenged" in types or &"corpse_rotted" in types), "the death and what happened to the body are in the event log")
	check(not report.hints.is_empty(), "the player gets a hint that something changed")

	# Same world, same death: same outcome.
	var a := _world_with_one_death(9)
	var b := _world_with_one_death(9)
	Aftermath.run(a)
	Aftermath.run(b)
	check(a.year == b.year and a.lives[0].corpse_items == b.lives[0].corpse_items, "time passing is repeatable for the same world")

	check(Aftermath.gap_text({"tier": &"days", "years": 0}) == "A few days later.", "gap text: days")
	check(Aftermath.gap_text({"tier": &"years", "years": 17}) == "Seventeen years later.", "gap text: years in words")
	check(Aftermath.gap_text({"tier": &"decades", "years": 43}) == "43 years later.", "gap text: big numbers in digits")

	# --- In the game: die, see the time screen, wake later. ---
	await start_scene("res://game.tscn")
	var state := autoload("WorldState")
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	var screen = game.get_node("UI").death_screen
	var year_at_death: int = state.data.year
	screen.continue_pressed.emit()
	await wait_frames(2)
	check(screen.visible and screen.get_node("%Title").text.ends_with("later."), "after the epitaph: how much time passed")
	screen.wake_pressed.emit()
	await wait_frames(2)
	check(state.data.current_life() != null and state.data.current_life().start_year == state.data.year and state.data.year >= year_at_death,
		"the new host is born in the new year")


func _world_with_one_death(seed_value: int) -> WorldData:
	var data := WorldData.create(seed_value)
	data.start_life(&"colonist")
	data.inventory[0] = &"bile_bulb"
	data.inventory[1] = &"bone_shard"
	data.end_life(Vector2.ZERO, Vector2.ZERO, &"")
	return data

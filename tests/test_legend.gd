extends "res://tests/test_case.gd"
## Legend standing (week 32): deeds follow the fragment across bodies, and
## people who sense the fragment (Choir priests) recognize you.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	await start_scene("res://game.tscn")
	var data = state.data

	# Life one: kill someone at the Choir's chapel.
	await goto(Vector2(3400, 3170), 40)
	var chapel = entity("ChoirChapel")
	var faction: StringName = chapel.site.faction if chapel and chapel.site else &""
	check(faction == &"choir_of_waking" and not chapel.residents.is_empty(), "the Choir lives in its chapel")
	if faction != &"choir_of_waking" or chapel.residents.is_empty():
		return
	player.health.invulnerable = true
	var victim = chapel.residents[chapel.residents.size() - 1]
	victim.health.set_current(1)
	await _strike(victim)
	await wait_frames(3)
	var deeds: Array = data.current_life().deed_event_ids
	var kills = data.events.filter(func(e): return e.type == &"resident_killed")
	check(kills.size() == 1 and kills[0].id in deeds, "the killing is a deed of this life")
	check(data.legend_standing(&"choir_of_waking") < 0, "and the fragment's legend with the Choir falls (%d)" % data.legend_standing(&"choir_of_waking"))
	player.health.invulnerable = false
	var legend_after: int = data.legend_standing(&"choir_of_waking")

	# Life two does nothing much; life three meets a priest.
	for life in 2:
		player.health.take_damage(99, player.global_position + Vector2(10, 0))
		await create_timer(1.5).timeout
		game.get_node("UI").death_screen.wake_pressed.emit({})
		await wait_frames(5)
	check(data.lives.size() == 3 and data.current_life().deed_event_ids.is_empty(), "two deaths later, a third body with no deeds of its own")
	var priest := Talk.new(data, "Vexith", &"choir_of_waking", 1)
	check(priest.recognized and "Two bodies ago" in priest.recognition and "We have not forgiven it" in priest.recognition,
		"a Choir priest remembers what you did two lives ago (\"%s\")" % priest.recognition)
	var site_name: String = chapel.site.name
	check(site_name in priest.recognition, "and where")
	check(not Talk.new(data, "Ossa", &"flesh_tenders", 1).recognized, "a Flesh-Tender cannot sense the fragment and does not know you")
	var choir: FactionDef = FactionDb.get_def(&"choir_of_waking")
	var expected := clampi(int(choir.host_attitudes.get(data.current_life().host_type, 0)) + roundi(legend_after * data.factions[&"choir_of_waking"].senses_fragment), -100, 100)
	check(data.standing(&"choir_of_waking") == expected and data.standing(&"choir_of_waking") < data.host_standing(&"choir_of_waking"),
		"the Choir holds it against the new body too (%d)" % data.standing(&"choir_of_waking"))
	check(data.standing(&"flesh_tenders") == data.host_standing(&"flesh_tenders"), "the Flesh-Tenders only see the body")

	# The legend is saved.
	data.player_position = player.global_position
	saves.save_game(98)
	saves.load_game(98)
	await wait_frames(5)
	data = state.data
	check(data.legend_standing(&"choir_of_waking") == legend_after and Talk.new(data, "Vexith", &"choir_of_waking", 1).recognized,
		"the legend survives a save and load")

	# Some deeds everyone hears of, and the Choir is glad of them.
	data.log_deed(&"boss_slain", [], {"boss": "the Gullet Matron"})
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	game.get_node("UI").death_screen.wake_pressed.emit({})
	await wait_frames(5)
	var told: String = Talk.new(data, "Vexith", &"choir_of_waking", 1).recognition
	check("Your last body" in told and "Gullet Matron" in told and "glad" in told, "slaying the Matron is remembered gladly (\"%s\")" % told)


## Stands left of `target`, faces it and swings the sword.
func _strike(target: Node2D) -> void:
	await goto(target.global_position + Vector2(-40, -26), 2)
	player._facing = 1.0
	await press("attack", 2)
	await wait_frames(6)

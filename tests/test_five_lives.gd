extends "res://tests/test_case.gd"
## Milestone 4 (week 37): five lives in a row through the real death, time
## and rebirth flow, each doing something different. Afterwards the world
## must carry the marks of every one of them.

var state
var data


func run() -> void:
	state = autoload("WorldState")
	await start_scene("res://game.tscn")
	data = state.data
	var start_year: int = data.year
	var chapel_site = data.site_in_slot("ChoirChapel")
	var chapel_people_start: int = chapel_site.population

	# Life 1: a devout one. Offers ichor at the Choir's altar.
	var altar := RootTalk.new(data, &"choir_of_waking")
	data.add_ichor(80)
	altar.bank()
	check(data.current_life().offerings.get(&"choir_of_waking", 0) == 80, "life 1 offers 80 ichor at the Choir's altar")
	await _die_and_wake()
	check(_has(&"offerings_fed", &"choir_of_waking"), "the offerings fed the Choir while you were gone")

	# Life 2: goes down and kills the Gullet Matron.
	player.health.invulnerable = true
	await goto(Vector2(6500, 3840), 30)
	var boss = null
	for i in 120:
		boss = entity("GulletMatron")
		if boss:
			break
		await physics_frame
	check(boss != null, "the Gullet Matron lives in the deep tunnel")
	if boss == null:
		return
	var ichor_before: int = data.ichor
	boss.health.invulnerable = false
	boss.health.take_damage(999, boss.global_position + Vector2(-20, 0), 0.0, &"player")
	await create_timer(2.2).timeout
	check(data.removed_entities.get("GulletMatron") == &"gullet_matron" and data.ichor >= ichor_before + 60, "she dies, and gives a lot of ichor (%d)" % (data.ichor - ichor_before))
	player.health.invulnerable = false
	await _die_and_wake()
	check(_has(&"deep_settled", &""), "with her dead, settlers went down into the deep")
	check(data.removed_entities.has("GulletMatron"), "and she does not come back")

	# Life 3: a murderer. Kills a chorister.
	await goto(Vector2(3400, 3170), 40)
	var chapel = entity("ChoirChapel")
	player.health.invulnerable = true
	var victim = chapel.residents[chapel.residents.size() - 1]
	victim.health.set_current(1)
	await goto(victim.global_position + Vector2(-40, -26), 2)
	player._facing = 1.0
	await press("attack", 2)
	await wait_frames(8)
	player.health.invulnerable = false
	var host3: String = data.current_life().host_name
	await _die_and_wake()
	check(data.events.any(func(e): return e.type == &"vengeance_sworn" and host3 in e.actors), "the Choir swore vengeance on %s" % host3)

	# Life 4: dies in the Choir's land; they enshrine the body.
	await goto(Vector2(3300, 3170), 20)
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	var places := {}
	for template in game._entities.templates():
		if template.has_method("body_spot") and not template.has_method("bars_player"):
			places[String(template.get_meta(&"entity_key"))] = template.body_spot()
	CorpseFate.claim(data, data.lives.size() - 1, &"choir_of_waking", &"enshrined", chapel_site, places)
	var host4: String = data.lives[-1].host_name
	game.get_node("UI").death_screen.continue_pressed.emit()
	await wait_frames(3)
	game.get_node("UI").death_screen.wake_pressed.emit({})
	await wait_frames(5)
	check(data.events.any(func(e): return e.type == &"pilgrims_came" and host4 in e.actors), "pilgrims come to kneel at %s's body" % host4)

	# Life 5: looks around.
	check(data.lives.size() == 5 and data.year > start_year, "five lives, %d years on" % (data.year - start_year))
	var choir_talk := Talk.new(data, "Vexith", &"choir_of_waking", 3)
	check(choir_talk.recognized, "a Choir priest still knows the fragment (\"%s\")" % choir_talk.recognition)
	var gossip: Array = Rumors.candidates(data, &"choir_of_waking").slice(0, 8).map(func(c): return c.event.type)
	var ours: Array = gossip.filter(func(t): return t in [&"host_died", &"resident_killed", &"boss_slain", &"corpse_claimed", &"vengeance_sworn", &"deep_settled", &"pilgrims_came", &"offerings_fed"])
	check(ours.size() >= 4, "the Choir's talk is full of what you did (%s)" % [gossip])
	var echoes: Array = data.events.filter(func(e): return e.type in [&"offerings_fed", &"deep_settled", &"vengeance_sworn", &"pilgrims_came"])
	check(echoes.size() >= 4, "%d echoes of your lives are in the history" % echoes.size())
	check(chapel_site.population != chapel_people_start, "the Choir's chapel has changed (%d -> %d people)" % [chapel_people_start, chapel_site.population])
	var between: Array = data.events.filter(func(e): return e.year > start_year and not e.type in [&"host_died", &"corpse_scavenged", &"corpse_rotted", &"creatures_returned"])
	check(between.size() >= 5, "history went on between lives (%d events after year %d)" % [between.size(), start_year])
	var ordered := true
	for i in range(1, data.events.size()):
		ordered = ordered and data.events[i].year >= data.events[i - 1].year
	check(ordered, "and the event log still reads in order")
	print("--- what the world remembers ---")
	for e in data.events.filter(func(e): return e.year >= start_year):
		print(EventText.line(e, data))


func _die_and_wake() -> void:
	player.health.invulnerable = false
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	game.get_node("UI").death_screen.continue_pressed.emit()
	await wait_frames(3)
	game.get_node("UI").death_screen.wake_pressed.emit({})
	await wait_frames(5)


func _has(type: StringName, faction: StringName) -> bool:
	return data.events.any(func(e): return e.type == type and (faction == &"" or faction in e.actors))

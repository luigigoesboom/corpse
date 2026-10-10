extends "res://tests/test_case.gd"
## The Gut's valve key (week 38): history puts it in the Choir's reliquary
## or the Gullet Matron's nest. Either way there are at least two ways to
## get it, and a body that dies with it may lose it to the Choir.

var state
var data


func run() -> void:
	state = autoload("WorldState")
	await start_scene("res://game.tscn")
	data = state.data
	var key := ValveKeys.GUT
	check(data.key_places.get(key, "") in [ValveKeys.CHOIR_RELIQUARY, ValveKeys.MATRON_NEST], "history put the key somewhere (%s)" % data.key_places.get(key))
	check(data.events.any(func(e): return e.type in [&"key_kept", &"key_swallowed"]), "and the log says where")

	# --- The Choir keeps it. ---
	data.key_places[key] = ValveKeys.CHOIR_RELIQUARY
	_clear_pockets()
	# 1. As their friend, you ask for it.
	data.current_life().standing[&"choir_of_waking"] = 60
	var talk := Talk.new(data, "Vexith", &"choir_of_waking", 1)
	check(talk.key_here and talk.can_ask_key, "a friend of the Choir may ask for the key")
	talk.ask_key()
	check(key in data.inventory and data.key_places[key] == "", "and they give it (\"%s\")" % talk.key_text)
	_put_back(ValveKeys.CHOIR_RELIQUARY)
	# 2. Not their friend: you pay.
	data.current_life().standing[&"choir_of_waking"] = 0
	talk = Talk.new(data, "Vexith", &"choir_of_waking", 1)
	check(not talk.can_ask_key and not talk.can_buy_key, "a stranger without ichor gets nothing")
	data.add_ichor(ValveKeys.CHOIR_PRICE)
	talk = Talk.new(data, "Vexith", &"choir_of_waking", 1)
	talk.buy_key()
	check(key in data.inventory and data.ichor == 0, "with %d ichor, you buy it" % ValveKeys.CHOIR_PRICE)
	_put_back(ValveKeys.CHOIR_RELIQUARY)
	# 3. You steal it from the reliquary.
	await goto(Vector2(3450, 3170), 40)
	var reliquary = entity("ChoirReliquary")
	var chapel = entity("ChoirChapel")
	check(reliquary != null and reliquary.has_key(), "the key lies in the reliquary in the chapel")
	Input.action_press("sneak")
	await wait_frames(30)
	for npc in chapel.residents:  # Everyone off at the far end, looking away.
		npc.position.x = maxf(npc.position.x, 60.0)
		npc._facing = 1.0
	var before: int = data.standing(&"choir_of_waking")
	reliquary.interact()
	Input.action_release("sneak")
	check(key in data.inventory and data.standing(&"choir_of_waking") == before, "sneaking, while they look away, you steal it unseen")
	_put_back(ValveKeys.CHOIR_RELIQUARY)
	var watcher = chapel.residents[0]
	watcher.global_position = Vector2(3400, watcher.global_position.y)
	watcher._facing = 1.0
	watcher._timer = 10.0
	reliquary.interact()
	await wait_frames(2)
	check(key in data.inventory and data.standing(&"choir_of_waking") < before and chapel.is_hostile(),
		"in plain sight, it is theft: the chapel turns on you (%d)" % data.standing(&"choir_of_waking"))
	check(data.events.any(func(e): return e.type == &"key_stolen" and e.data.seen), "and remembered")
	data.current_life().standing[&"choir_of_waking"] = 0
	data.legend[&"choir_of_waking"] = 0

	# --- The Matron's nest. ---
	_put_back(ValveKeys.MATRON_NEST)
	player.health.invulnerable = true
	# 1. Sneak to her nest from the east without waking her.
	Input.action_press("sneak")
	await goto(Vector2(7900, 3840), 40)
	var boss = entity("GulletMatron")
	var nest = entity("MatronNest")
	check(boss != null and nest != null and nest.has_key(), "the key lies in her nest, past her, at the end of the deep")
	await goto(nest.global_position + Vector2(10, -26), 20)
	check(boss.state == 0, "sneaking, you reach the nest %d px from her and she sleeps on" % int(boss.global_position.distance_to(player.global_position)))
	nest.interact()
	Input.action_release("sneak")
	check(key in data.inventory, "you take the key from under her")
	_put_back(ValveKeys.MATRON_NEST)
	# Walking up, she wakes.
	await goto(nest.global_position + Vector2(10, -26), 20)
	check(boss.state != 0, "walking up, she wakes")
	# 2. Kill her, then take it.
	boss.health.invulnerable = false
	boss.health.take_damage(999, boss.global_position + Vector2(20, 0), 0.0, &"player")
	await create_timer(2.0).timeout
	nest.interact()
	check(key in data.inventory and data.removed_entities.has("GulletMatron"), "or kill her and take it")
	player.health.invulnerable = false

	# --- Lost with a body: the Choir senses it and takes it home. ---
	await goto(Vector2(3300, 3170), 20)
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	var body = data.lives[-1]
	check(key in body.corpse_items, "die with the key, and it lies on your body")
	CorpseFate.claim(data, data.lives.size() - 1, &"choir_of_waking", &"looted", null, {})
	check(not key in body.corpse_items and data.key_places[key] == ValveKeys.CHOIR_RELIQUARY, "the Choir takes it from the body back to its reliquary")


func _clear_pockets() -> void:
	for i in data.inventory.size():
		data.inventory[i] = &""


func _put_back(place: String) -> void:
	_clear_pockets()
	data.key_places[ValveKeys.GUT] = place

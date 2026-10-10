extends "res://tests/test_case.gd"
## Non-combat options (week 36): the Choir's watch over the shaft down to
## the deep lets only the faithful pass. Get by without a fight: sneak past
## while the sentries look away, or bribe one. And eat what you kill.

var post


func run() -> void:
	var state := autoload("WorldState")
	var dm := autoload("DialogueManager")
	await start_scene("res://game.tscn")
	var data = state.data
	data.current_life().standing[&"choir_of_waking"] = 0
	await goto(Vector2(3800, 3170), 40)
	post = entity("ShaftWatch")
	check(post != null and post.residents.size() == 2, "two Choir sentries watch the shaft")
	if post == null:
		return
	check(post.bars_player(), "a colonist is not one of the faithful: kept out")
	var sentries: Array = post.residents

	# Walking straight in while they watch: seen, warned, attacked.
	for s in sentries:
		s._facing = -1.0
		s._timer = 8.0
	await _walk_to(4250.0, false, 300)
	await wait_frames(20)
	check(sentries.any(func(s): return s.noticed), "walking up, you are noticed")
	check(sentries.any(func(s): return s._bark.visible and "faithful" in s._bark.text), "a sentry steps in your way and warns you")
	check(player.global_position.y < 3260.0 and not post.is_grate_open(), "a bone grate keeps you out of the shaft")
	await wait_frames(80)
	check(post.is_hostile(), "standing on it, the watch attacks")
	await _reset()

	# Sneaking: crouched, dim and silent, behind their backs, into the shaft.
	for s in sentries:
		s._facing = 1.0  # Both looking away, along their ledge.
		s._timer = 8.0
	await _walk_to(4150.0, true, 900)
	var latch = post.get_children().filter(func(n): return n.has_method("interact") and "post" in n)[0]
	latch.interact()
	await wait_frames(5)
	check(post.is_grate_open() and not sentries.any(func(s): return s.noticed), "sneaking behind their backs to the latch, you lift it unseen")
	var through := await _walk_to(4224.0, true, 300)
	await wait_frames(30)
	check(through and player.global_position.y > 3260.0 and not sentries.any(func(s): return s.noticed),
		"and slip down the shaft (y %d)" % player.global_position.y)
	await _reset()

	# Sneaking is not invisible: crawl up in front of them and they see you.
	for s in sentries:
		s._facing = -1.0
		s._timer = 8.0
	await _walk_to(4150.0, true, 400)
	await wait_frames(150)
	check(sentries.any(func(s): return s.noticed), "sneak up while they look your way, by the brazier, and they see you")
	await _reset()

	# Bribing: talk to a sentry and pay to pass.
	var offer: Array = post.bribe_offer()
	check(offer[1] > 0, "a sentry would take %d ichor to look away" % offer[1])
	var talk := Talk.new(data, "Sentry", &"choir_of_waking", 1)
	talk.offer_bribe(offer[0], offer[1])
	var resource = load("res://data/dialogue/resident.dialogue")
	var line = await dm.get_next_dialogue_line(resource, "start", [talk])
	if talk.recognized:
		line = await dm.get_next_dialogue_line(resource, line.next_id, [talk])
	line = await dm.get_next_dialogue_line(resource, line.next_id, [talk])
	var options: Array = line.responses.map(func(r): return r.text)
	check(("Offer %d ichor to look away." % offer[1]) in options, "talking, they halt you and name a price (%s)" % [options])
	check(not talk.can_bribe, "you cannot pay with ichor you do not have")
	data.add_ichor(offer[1] + 5)
	talk.bribe()
	check(data.ichor == 5 and not post.bars_player(), "pay, and they let you by")
	through = await _walk_to(4224.0, false, 400)
	await wait_frames(30)
	check(through and player.global_position.y > 3260.0 and not post.is_hostile(), "walking straight past them into the shaft")

	# Eating what you kill.
	await goto(Vector2(3800, 3170), 20)
	player.health.set_current(player.health.max_health - 1)
	var leech = entity("LeechChamber")
	if leech:
		leech.get_node("Health").last_hit_source = &"player"
		game._on_entity_killed(leech)
		var carcasses: Array = game.get_children().filter(func(n): return n.has_method("interact") and "kind" in n)
		check(carcasses.size() == 1, "a dead leech leaves a carcass")
		var hp: int = player.health.current
		var ichor: int = data.ichor
		carcasses[0].interact()
		check(player.health.current == hp + 1 and data.ichor == ichor + 1, "eating it gives back a heart and a drop of ichor")


## Holds right (and sneak) until the player passes `x` or falls into the
## shaft. True if it got there.
func _walk_to(x: float, sneaking: bool, frames: int) -> bool:
	if sneaking:
		Input.action_press("sneak")
	Input.action_press("move_right")
	var reached := false
	for i in frames:
		await physics_frame
		if player.global_position.x >= x or player.global_position.y > 3260.0:
			reached = true
			break
	Input.action_release("move_right")
	Input.action_release("sneak")
	return reached


## Back to the chamber, the watch calmed down.
func _reset() -> void:
	player.health.heal_full()
	await goto(Vector2(3800, 3170), 10)
	await goto(Vector2(3300, 3170), 10)
	post._alarm = false
	post._warned = 0.0
	for s in post.residents:
		s.awareness = 0.0
		s.noticed = false
		s.position.x = s.home_x
		s.state = 0
	await goto(Vector2(3960, 3170), 10)

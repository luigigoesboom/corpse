extends "res://tests/test_case.gd"
## The Gullet Matron (boss): readable, fair, winnable with skill, deadly to
## mashing and to standing still. Fights are played by tests/boss_bot.gd.
## run-with: --fixed-fps 60

const Bot := preload("res://tests/boss_bot.gd")
const ARENA := "res://scenes/arenas/boss_arena.tscn"
const DEAD := 8
const STAGGER := 6
const PHASE_SHIFT := 7


func run() -> void:
	# Readable: every attack telegraphs long enough to react to and leaves
	# a window to punish, even in phase 2 (20% faster).
	var boss_script = load("res://src/actors/bosses/gullet_matron.gd")
	var readable := true
	for id in boss_script.ATTACKS:
		var a: Dictionary = boss_script.ATTACKS[id]
		readable = readable and a.windup * 0.8 >= 0.35 and a.recover * 0.8 >= 0.5
	check(readable, "every attack winds up for at least 0.35 s and rests at least 0.5 s, in both phases")

	# A skilled player wins most fights, in a fight that lasts.
	var wins := 0
	var lengths: Array = []
	var seen := {}
	var staggered := false
	var self_harm := false
	var drops := 0
	var cleared := false
	for seed_value in [1, 3, 5, 6, 7, 8]:
		var result: Dictionary = await _fight("skilled", seed_value)
		seen.merge(result.attacks)
		staggered = staggered or result.staggers > 0
		self_harm = self_harm or result.self_harm
		if result.won:
			wins += 1
			lengths.append(result.seconds)
			drops = result.drops
			cleared = cleared or result.cleared
	check(wins >= 4, "a skilled player wins %d of 6 fights" % wins)
	check(lengths.all(func(s): return s >= 40.0 and s <= 120.0), "each win takes 40-120 s (%s)" % [lengths.map(func(s): return int(s))])
	check(seen.size() == 5 and staggered and seen.has(5), "both phases show: all five attacks seen, brood included, and she can be staggered")
	check(not self_harm, "only the player ever hurts her (her own bile and ripples spare her)")
	check(drops == 3 and cleared, "when she dies she drops her loot and the pit counts as cleared")

	# Mashing and standing still lose.
	var careless_wins := 0
	for seed_value in [1, 2]:
		var result: Dictionary = await _fight("careless", seed_value)
		careless_wins += 1 if result.won else 0
	check(careless_wins == 0, "walking up and mashing attack never wins")
	var idle: Dictionary = await _fight("idle", 1)
	check(not idle.won and idle.seconds < 40.0, "standing still dies in %.0f s" % idle.seconds)


func _fight(mode: String, seed_value: int) -> Dictionary:
	var arena: Node = load(ARENA).instantiate()
	arena.get_node("CombatFeel").hitstop_enabled = false
	root.add_child(arena)
	await wait_frames(5)
	var boss = arena.get_node("Enemies/GulletMatron")
	var hero = arena.get_node("Player")
	boss._rng.seed = seed_value
	seed(seed_value)
	var bot = Bot.new()
	bot.careless = mode == "careless"
	var bus := autoload("EventBus")
	var result := {"won": false, "seconds": 0.0, "attacks": {}, "staggers": 0, "self_harm": false, "drops": 0, "cleared": false}
	var on_drop := func(_item, _pos): result.drops += 1
	var on_note := func(text): if text.begins_with("Clear in"): result.cleared = true
	bus.item_drop_requested.connect(on_drop)
	bus.notify.connect(on_note)
	boss.health.hurt.connect(func(_amount, _from, _knockback):
		if boss.health.last_hit_source != &"player":
			result.self_harm = true)
	var last: int = boss.state
	var t := 0.0
	while t < 150.0 and not hero.is_dead() and boss.state != DEAD:
		if mode != "idle":
			bot.tick(boss, hero, arena)
		await physics_frame
		t += 1.0 / 60.0
		if boss.attack != 0:
			result.attacks[boss.attack] = true
		if boss.state != last:
			if boss.state == STAGGER:
				result.staggers += 1
			last = boss.state
	bot.release_all()
	result.won = boss.state == DEAD
	result.seconds = t
	if result.won:
		await create_timer(2.0).timeout  # Her death throes, then the loot.
	bus.item_drop_requested.disconnect(on_drop)
	bus.notify.disconnect(on_note)
	arena.queue_free()
	await wait_frames(2)
	return result

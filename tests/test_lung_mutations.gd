extends "res://tests/test_case.gd"
## The Lungs' mutations and valve key (week 51): the Bellows Heart gives one
## more jump in the air; the Gust Bladder throws creatures back (a Puffsac
## popped from afar bursts out of reach) and pushes the host away; the
## Lungs' key starts with the Kin or in the High Aerie, as history says,
## shows there, can be taken, and the Kin talk about it when they keep it.

const T := 32.0


func run() -> void:
	await start_scene("res://game.tscn", 4242)
	var data = autoload("WorldState").data
	player.health.invulnerable = true

	# --- Bellows Heart: a jump in the air, once until you land.
	await goto(Vector2(2000, 3178), 30)
	data.graft("belly", &"bellows_heart")
	autoload("EventBus").mutations_changed.emit()
	await wait_frames(5)
	await press("jump", 4)
	for i in 30:  # Up to the top of the jump and over it.
		await physics_frame
		if player.velocity.y > 50.0:
			break
	Input.action_press("jump")  # Held, for the whole puff (a tap cuts it short, like a jump).
	await wait_frames(2)
	check(player.velocity.y < -400.0, "jumping again in the air puffs the host up (%.0f)" % player.velocity.y)
	await wait_frames(10)
	Input.action_release("jump")
	await wait_frames(2)
	check(not player.is_on_floor(), "(still in the air)")
	var vy: float = player.velocity.y
	await press("jump", 2)
	check(player.velocity.y >= vy - 50.0, "but only once until it lands")
	await wait_frames(90)
	check(player.is_on_floor(), "(landed)")

	# --- Gust Bladder: a Puffsac popped from afar bursts where it floats.
	data.graft("head", &"gust_bladder")
	autoload("EventBus").mutations_changed.emit()
	await wait_frames(5)
	player.health.invulnerable = false
	player.health.heal_full()
	var hp: int = player.health.current
	var sac: Node2D = load("res://src/actors/creatures/puffsac.tscn").instantiate()
	sac.position = player.global_position + Vector2(80, -12)
	sac.trigger_range = 0.0
	game.add_child(sac)
	await wait_frames(3)
	player._facing = 1.0
	var x0: float = player.global_position.x
	await press("ability_head", 2)
	await wait_frames(10)
	check(sac.is_dead(), "the gust pops the Puffsac")
	check(sac.global_position.x - player.global_position.x > 90.0, "and throws it further off (%.0f px)" % (sac.global_position.x - player.global_position.x))
	check(player.global_position.x < x0, "the host is pushed the other way")
	await wait_frames(60)
	check(player.health.current == hp, "it bursts out of reach")

	# --- The Lungs' key: where history put it.
	var place: String = data.key_places.get(&"valve_key_lungs", "")
	check(place in ["kin_roost", "high_aerie"], "the Lungs' key starts with the Kin or in the High Aerie (%s)" % place)
	var told: Array = data.events.filter(func(e): return e.type in [&"key_kept", &"key_nested"] and e.data.get("key") == &"valve_key_lungs")
	check(told.size() == 1, "and the log says so")
	var cache_name := "KinKeyString" if place == "kin_roost" else "AerieKey"
	var cache_at: Vector2 = Vector2(13680, 3398) if place == "kin_roost" else Vector2(15056, 422)
	await goto(cache_at + Vector2(-60, -28), 40)
	var cache: Node = entity(cache_name)
	check(cache != null and cache.has_key(), "the key shows at %s" % cache_name)
	var talk_script: GDScript = load("res://src/dialogue/talk.gd")
	var talk = talk_script.new(data, "Ula", &"bellows_kin", 3)
	check(talk.key_here == (place == "kin_roost") and (talk.key_line != "") == (place == "kin_roost"), "the Kin talk about it only while they keep it")
	player.health.invulnerable = true
	player.global_position = cache.global_position + Vector2(0, -28)
	await wait_frames(5)
	cache.interact()
	await wait_frames(5)
	check(&"valve_key_lungs" in data.inventory and not cache.has_key(), "the host takes it")

	# Claimed with the host's body by the Kin, it goes back to their roost.
	var life = data.current_life()
	life.corpse_items = [&"valve_key_lungs"]
	data.key_places[&"valve_key_lungs"] = ""
	ValveKeys.reclaim_from_body(data, life, &"bellows_kin")
	check(ValveKeys.lies_at(data, &"valve_key_lungs", "kin_roost"), "the Kin carry it home from a body they claim")
	ValveKeys.reclaim_from_body(data, life, &"choir_of_waking")
	check(ValveKeys.lies_at(data, &"valve_key_lungs", "kin_roost"), "the Choir do not keep the Lungs' key")

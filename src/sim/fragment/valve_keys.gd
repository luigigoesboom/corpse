class_name ValveKeys
extends RefCounted
## The valve keys that seal the heart (week 38). Each is an item (so it can
## be carried, dropped, left on a corpse, reclaimed), and while nobody
## carries it, it lies at a hand-made place: WorldData.key_places
## (key id -> place id, "" = it is an item somewhere in the world).
## History decides where a key starts; between lives, people who sense the
## fragment take keys from its bodies back to their reliquary.

const GUT := &"valve_key_gut"
const CHOIR_RELIQUARY := "choir_reliquary"
const MATRON_NEST := "matron_nest"
## Ichor the Choir asks for its key.
const CHOIR_PRICE := 100


## Where the Gut key starts, from the world's past: a Choir that found
## relics or had prophets keeps it in its reliquary; otherwise it lies in
## the Gullet Matron's nest. Logs the event that says so.
static func place_at_start(data: WorldData) -> void:
	if data.key_places.has(GUT):
		return
	var choir_signs := data.events.filter(func(e): return &"choir_of_waking" in e.actors and e.type in [&"wonder", &"prophet"]).size()
	var rng := SeededRng.make([data.world_seed, "valve_key"])
	var choir_keeps := choir_signs >= 2 or (choir_signs == 1 and rng.randf() < 0.5)
	data.key_places[GUT] = CHOIR_RELIQUARY if choir_keeps else MATRON_NEST
	if choir_keeps:
		var chapel := data.site_in_slot("ChoirChapel")
		data.log_event(&"key_kept", [&"choir_of_waking"], {"site": chapel.id if chapel else "", "key": GUT})
	else:
		data.log_event(&"key_swallowed", [], {"key": GUT})


static func lies_at(data: WorldData, key: StringName, place: String) -> bool:
	return data.key_places.get(key, "") == place


## Takes a key from its place into the host's pockets. False if it is not
## there or the pockets are full.
static func take(data: WorldData, key: StringName, place: String) -> bool:
	if not lies_at(data, key, place) or data.add_to_inventory(key) < 0:
		return false
	data.key_places[key] = ""
	return true


## Between lives (CorpseFate): a people who sense the fragment and claim a
## body with a key on it carry the key home.
static func reclaim_from_body(data: WorldData, life: LifeRecord, faction: StringName) -> void:
	var people: FactionData = data.factions.get(faction)
	if people == null or people.senses_fragment < 0.5:
		return
	for key in [GUT]:
		if key in life.corpse_items:
			life.corpse_items.erase(key)
			data.key_places[key] = CHOIR_RELIQUARY
			data.log_event(&"key_taken", [faction, life.host_name], {"key": key})


static func is_key(item: StringName) -> bool:
	return item == GUT

class_name ValveKeys
extends RefCounted
## The valve keys that seal the heart (week 38; one per region, the Lungs'
## in week 51). Each is an item (so it can be carried, dropped, left on a
## corpse, reclaimed), and while nobody carries it, it lies at a hand-made
## place: WorldData.key_places (key id -> place id, "" = it is an item
## somewhere in the world). History decides where a key starts: with the
## region's keepers (their `kept` place), or out in the wild (`wild`).
## Between lives, the keepers take a key from a body they claim back home.

const GUT := &"valve_key_gut"
const LUNGS := &"valve_key_lungs"
const CHOIR_RELIQUARY := "choir_reliquary"
const MATRON_NEST := "matron_nest"
const KIN_ROOST := "kin_roost"
const HIGH_AERIE := "high_aerie"
## Ichor the Choir asks for its key.
const CHOIR_PRICE := 100

## Per key:
##   keeper  the people who may keep it (and take it home from bodies)
##   kept    their place for it;  slot: their settlement slot (the event names it)
##   wild    where it lies if they do not have it; wild_event logs that
##   signs   event types in the keepers' past that make them keep it (two or
##           more, or one and a coin toss)
##   price   ichor they ask for it
const KEYS := {
	GUT: {"keeper": &"choir_of_waking", "kept": CHOIR_RELIQUARY, "slot": "ChoirChapel", "wild": MATRON_NEST,
		"wild_event": &"key_swallowed", "signs": [&"wonder", &"prophet"], "price": CHOIR_PRICE},
	LUNGS: {"keeper": &"bellows_kin", "kept": KIN_ROOST, "slot": "KinRoost", "wild": HIGH_AERIE,
		"wild_event": &"key_nested", "signs": [&"wonder", &"trade_pact"], "price": 120},
}


## Where each key starts, from the world's past (keys already placed stay).
## Logs the event that says so.
static func place_at_start(data: WorldData) -> void:
	for key in KEYS:
		if data.key_places.has(key):
			continue
		var info: Dictionary = KEYS[key]
		var signs := data.events.filter(func(e): return info.keeper in e.actors and e.type in info.signs).size()
		# The Gut's generator is the one it always had (week 38).
		var rng := SeededRng.make([data.world_seed, "valve_key"] if key == GUT else [data.world_seed, "valve_key", key])
		var kept := data.factions.has(info.keeper) and (signs >= 2 or (signs == 1 and rng.randf() < 0.5))
		data.key_places[key] = info.kept if kept else info.wild
		if kept:
			var home := data.site_in_slot(info.slot)
			data.log_event(&"key_kept", [info.keeper], {"site": home.id if home else "", "key": key})
		else:
			data.log_event(info.wild_event, [], {"key": key})


static func lies_at(data: WorldData, key: StringName, place: String) -> bool:
	return data.key_places.get(key, "") == place


## The key a people keep at their place right now, or &"".
static func kept_by(data: WorldData, faction: StringName) -> StringName:
	for key in KEYS:
		if KEYS[key].keeper == faction and lies_at(data, key, KEYS[key].kept):
			return key
	return &""


static func price_of(key: StringName) -> int:
	return KEYS[key].price if KEYS.has(key) else CHOIR_PRICE


## Takes a key from its place into the host's pockets. False if it is not
## there or the pockets are full.
static func take(data: WorldData, key: StringName, place: String) -> bool:
	if not lies_at(data, key, place) or data.add_to_inventory(key) < 0:
		return false
	data.key_places[key] = ""
	return true


## Between lives (CorpseFate): a key's keepers who claim a body with that
## key on it carry it home.
static func reclaim_from_body(data: WorldData, life: LifeRecord, faction: StringName) -> void:
	for key in KEYS:
		if KEYS[key].keeper == faction and key in life.corpse_items:
			life.corpse_items.erase(key)
			data.key_places[key] = KEYS[key].kept
			data.log_event(&"key_taken", [faction, life.host_name], {"key": key})


static func is_key(item: StringName) -> bool:
	return KEYS.has(item)

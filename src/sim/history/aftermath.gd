class_name Aftermath
extends RefCounted
## What happens to the world between one host's death and the next (D-021).
##
## Nothing is simulated year by year. Each death rolls a time gap tier; the
## tier's strength (0..1) scales a short list of rules. Each rule is a small
## function below, and later systems (factions, rot) add their own.
## Plain data in, plain data out: no nodes, so it can run anywhere.

## name, chance weight, years min/max, strength.
## Creature kinds that never come back once killed.
const BOSSES := [&"gullet_matron"]

const TIERS := [
	{"name": &"days", "weight": 2, "years": [0, 0], "strength": 0.1},
	{"name": &"months", "weight": 3, "years": [0, 1], "strength": 0.3},
	{"name": &"years", "weight": 4, "years": [3, 15], "strength": 0.6},
	{"name": &"decades", "weight": 1, "years": [20, 60], "strength": 1.0},
]


## Rolls the gap for this death and applies it. Deterministic per world and death.
## `places`: settlement slot -> floor point, so factions can carry bodies home.
static func run(data: WorldData, places: Dictionary = {}) -> Dictionary:
	var rng := SeededRng.make([data.world_seed, "aftermath", data.lives.size()])
	var total := 0
	for tier in TIERS:
		total += tier.weight
	var pick := rng.randi_range(1, total)
	for i in TIERS.size():
		pick -= TIERS[i].weight
		if pick <= 0:
			return apply(data, i, rng, places)
	return apply(data, 0, rng, places)


## Applies tier `tier_index`. Returns a report:
##   {"tier", "years", "strength", "hints": [short vague lines for the player]}
static func apply(data: WorldData, tier_index: int, rng: RandomNumberGenerator, places: Dictionary = {}) -> Dictionary:
	var tier: Dictionary = TIERS[tier_index]
	var years := rng.randi_range(tier.years[0], tier.years[1])
	var strength: float = tier.strength
	data.year += years
	var report := {"tier": tier.name, "years": years, "strength": strength, "hints": []}
	# The years pass (week 37), then what the last host did echoes in them.
	var happened := HistorySim.between_lives(data, years, SeededRng.make([data.world_seed, "between", data.lives.size()]))
	DeedEchoes.apply(data, _last_dead(data), report)
	_hint_history(data, happened, report)
	CorpseFate.apply(data, strength, rng, places, report)  # Factions first (week 33).
	_scavenge_bodies(data, strength, rng, report)
	_creatures_return(data, strength, rng, report)
	_dropped_items_vanish(data, strength, rng, report)
	return report


static func _last_dead(data: WorldData) -> LifeRecord:
	for i in range(data.lives.size() - 1, -1, -1):
		if not data.lives[i].is_alive():
			return data.lives[i]
	return null


## The biggest thing that happened while you were gone, if it touched a
## people you can meet.
static func _hint_history(data: WorldData, happened: Array, report: Dictionary) -> void:
	var known := {}
	for site: SiteData in data.sites.values():
		if site.slot != "" and site.is_lived_in():
			known[site.faction] = true
	for type in [&"war_declared", &"peace", &"site_taken", &"disaster", &"schism", &"prophet", &"wonder"]:
		for event in happened:
			if event.type == type and event.actors.any(func(a): return known.has(StringName(str(a)))):
				report.hints.append("While you were gone: %s" % EventText.describe(event, data))
				return


## Old bodies lose things to scavengers and rot. The newest body always
## keeps at least one thing, so going back for it is never pointless.
## Enshrined bodies are guarded: nothing gets at them.
static func _scavenge_bodies(data: WorldData, strength: float, rng: RandomNumberGenerator, report: Dictionary) -> void:
	var newest := data.lives.size() - 1
	while newest >= 0 and data.lives[newest].is_alive():
		newest -= 1
	for i in data.lives.size():
		var life: LifeRecord = data.lives[i]
		if life.is_alive() or not life.has_corpse_loot() or life.corpse_state == &"enshrined":
			continue
		var protect := i == newest
		# Ichor dries out of a body (week 34): up to 40% over decades.
		var dried := floori(life.corpse_ichor * strength * 0.4)
		life.corpse_ichor -= dried
		var taken: Array = []
		for item in life.corpse_items.duplicate():
			if rng.randf() < strength * 0.7 and not (protect and _loot_count(life) <= 1):
				life.corpse_items.erase(item)
				taken.append(item)
		var rotted: Array = []
		for slot in life.corpse_mutations.keys():
			if rng.randf() < strength * 0.5 and not (protect and _loot_count(life) <= 1):
				rotted.append(life.corpse_mutations[slot])
				life.corpse_mutations.erase(slot)
		if not taken.is_empty():
			if life.corpse_state == &"intact":
				life.corpse_state = &"scavenged"
			data.log_event(&"corpse_scavenged", [life.host_name], {"items": taken})
		if not rotted.is_empty():
			data.log_event(&"corpse_rotted", [life.host_name], {"mutations": rotted})
		if i == newest and (not taken.is_empty() or not rotted.is_empty()):
			report.hints.append("Something has been at your old body.")


static func _loot_count(life: LifeRecord) -> int:
	return life.corpse_items.size() + life.corpse_mutations.size()


## Creatures killed by any host may be replaced by new ones.
static func _creatures_return(data: WorldData, strength: float, rng: RandomNumberGenerator, report: Dictionary) -> void:
	var returned: Array = []
	for key in data.removed_entities.keys():
		var kind = data.removed_entities[key]
		# Only creatures come back; picked-up items (&"item") and old saves (true) do not.
		if kind is StringName and kind != &"item" and not kind in BOSSES and rng.randf() < strength:
			data.removed_entities.erase(key)
			returned.append(kind)
	if not returned.is_empty():
		data.log_event(&"creatures_returned", returned, {})
		report.hints.append("The Gut has bred new things where you killed the old.")


## Things left lying around rot or get carried off.
static func _dropped_items_vanish(data: WorldData, strength: float, rng: RandomNumberGenerator, _report: Dictionary) -> void:
	for chunk in data.chunk_diffs.keys():
		for record in data.items_in_chunk(chunk).duplicate():
			if String(record.item).begins_with("artifact_") or ValveKeys.is_key(record.item):
				continue  # One of a kind: they do not rot away.
			if rng.randf() < strength * 0.5:
				data.remove_dropped_item(chunk, record.id)


## "Seventeen years later" etc., for the rebirth screen.
static func gap_text(report: Dictionary) -> String:
	match report.tier:
		&"days":
			return "A few days later."
		&"months":
			return "Some months later." if report.years == 0 else "A year later."
	var words := ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
		"Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen", "Twenty"]
	var years: int = report.years
	return "%s years later." % (words[years] if years < words.size() else str(years))

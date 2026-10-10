class_name Lore
extends RefCounted
## Murals and lore objects (week 35): history you can read in the world.
## Each piece shows a few events from the log, picked for a place; reading
## it adds them to what the fragment knows (WorldData.known_events), and the
## History tab lays everything known out per people, by year, so a past can
## be pieced together from several places. Words come from EventText when
## shown, like everything else made from events. Plain data.

## Events a people would paint about themselves, most important first.
const WORTH_PAINTING := [&"faction_founded", &"people_arrived", &"prophet", &"schism", &"wonder", &"war_declared",
	&"site_razed", &"last_stand", &"site_taken", &"raid_repelled", &"peace", &"trade_pact", &"disaster",
	&"site_founded", &"site_abandoned", &"faction_fell", &"pilgrims_joined"]
## What murals are made of, by archetype (invented peoples) or faction id.
const MEDIUM := {
	&"choir_of_waking": "gold leaf and dried bile on a slab of rib",
	&"flesh_tenders": "pressed and stitched gut-lining, stretched on a frame",
	&"farmers": "pressed gut-lining",
	&"diggers": "lines cut into bone",
	&"hunters": "soot and blood on hide",
	&"cult": "scratches in wax over bone",
	&"scavengers": "scraps nailed to a board",
}
const PANELS := ["first", "second", "third", "fourth", "fifth"]


## The story a people tells about itself, in at most `count` events spread
## over its whole past, oldest first. `rng_seed` picks which, so two murals
## of the same people show different moments.
static func mural_events(data: WorldData, faction: StringName, rng_seed: int, count := 4) -> Array:
	var theirs := data.events.filter(func(e): return e.type in WORTH_PAINTING and faction in e.actors)
	if theirs.size() <= count:
		return theirs.map(func(e): return e.id)
	# The founding always; then a spread of the rest, weighted to the big moments.
	var rng := SeededRng.make(["mural", faction, rng_seed])
	var picked := [theirs[0]]
	var rest: Array = theirs.slice(1)
	var buckets := count - 1
	for b in buckets:
		var from := b * rest.size() / buckets
		var to := (b + 1) * rest.size() / buckets
		var best: EventRecord = null
		var best_score := -1.0
		for i in range(from, to):
			var score := float(WORTH_PAINTING.size() - WORTH_PAINTING.find(rest[i].type)) + rng.randf() * 6.0
			if score > best_score:
				best_score = score
				best = rest[i]
		if best:
			picked.append(best)
	return picked.map(func(e): return e.id)


## What happened at one place, at most `count` events, oldest first.
static func site_events(data: WorldData, site_id: String, count := 3) -> Array:
	var here := ArtifactForge.events_at(data, site_id).filter(func(e): return e.type in WORTH_PAINTING)
	if here.size() > count:
		here = [here[0]] + here.slice(here.size() - count + 1)  # How it began, and how it ended.
	return here.map(func(e): return e.id)


## "A mural of gold leaf and dried bile on a slab of rib. In the first panel, ..."
static func describe_mural(data: WorldData, faction: StringName, ids: Array) -> String:
	var people: FactionData = data.factions.get(faction)
	var medium: String = MEDIUM.get(faction, MEDIUM.get(people.archetype if people else &"", "paint on stone"))
	var lines := PackedStringArray(["A mural of %s." % medium])
	for i in ids.size():
		var event := event_by_id(data, ids[i])
		if event:
			lines.append("In the %s panel (year %d): %s" % [PANELS[mini(i, PANELS.size() - 1)], event.year, _lower_first(EventText.describe(event, data))])
	if ids.is_empty():
		lines.append("It has been scraped away.")
	return "\n".join(lines)


## A stone or bone left at a place, telling what happened there.
static func describe_tablet(data: WorldData, ids: Array) -> String:
	var lines := PackedStringArray(["Words cut into a shard of bone, worn almost smooth:"])
	for id in ids:
		var event := event_by_id(data, id)
		if event:
			lines.append("\"%s\"" % EventText.line(event, data))
	return "\n".join(lines)


## Everything the fragment has read, per people (faction id -> [EventRecord]
## by year). An event shows under every people it involves (a war under
## both sides); events with no people go under &"".
static func known_by_people(data: WorldData) -> Dictionary:
	var out := {}
	for event in data.events:
		if not data.known_events.has(event.id):
			continue
		var peoples := event.actors.filter(func(a): return data.factions.has(StringName(str(a))))
		if peoples.is_empty():
			peoples = [&""]
		for who in peoples:
			out.get_or_add(StringName(str(who)), []).append(event)
	return out


static func event_by_id(data: WorldData, id: int) -> EventRecord:
	for event in data.events:
		if event.id == id:
			return event
	return null


static func _lower_first(text: String) -> String:
	return text.substr(0, 1).to_lower() + text.substr(1)

class_name EventText
extends RefCounted
## Turns an EventRecord into a sentence, when it is shown (never stored, so
## better writing later improves old saves too). Names come from the world's
## factions and sites by id. Each event type has a few phrasings; the event's
## id picks one, so the same event always reads the same.

const FAMOUS_RELICS := ["a tooth the size of a door", "a knuckle that still twitched", "a hair of the god, warm to the touch",
	"a scale from the god's tongue", "a nerve that hummed at night"]
const SAYINGS := ["is only sleeping", "dreams of us", "will wake hungry", "is listening through the walls",
	"chose to fall", "is dying slower than we are"]
const DISASTER_TEXT := {
	&"bile_flood": ["A bile flood drowned {n} in {site}.", "The bile rose in {site} and took {n} people with it."],
	&"rot_plague": ["Rot sickness swept through {site}; {n} died.", "A grey rot came to {site}. {n} did not see it pass."],
	&"spasm": ["The body spasmed and the tunnels of {site} caved in on {n}.", "A great spasm shook {site}; {n} were buried."],
	&"famine": ["The lining went barren around {site} and {n} starved.", "Nothing grew near {site} for a year; {n} starved."],
}


## "Year 312: the Pale Diggers founded Gallwell."
static func line(event: EventRecord, data: WorldData) -> String:
	return "Year %d: %s" % [event.year, describe(event, data)]


static func describe(event: EventRecord, data: WorldData) -> String:
	var a := _faction(data, event.actors[0]) if event.actors.size() > 0 else "someone"
	var b := _faction(data, event.actors[1]) if event.actors.size() > 1 else "someone"
	var d := event.data
	var site := _site(data, d.get("site", ""))
	var pick := event.id
	var text := ""
	match event.type:
		&"people_arrived":
			text = _one(pick, ["%s came down from %s and settled at %s." % [a, d.get("from", "elsewhere"), site],
				"%s arrived out of %s and dug in at %s." % [a, d.get("from", "elsewhere"), site]])
		&"faction_founded":
			if d.get("pilgrims", false):
				text = "Pilgrims who heard the heart followed %s to %s and called themselves %s." % [d.get("founder", "a stranger"), site, a]
			else:
				text = "%s gathered the first of %s at %s." % [d.get("founder", "Someone"), a, site]
		&"site_founded":
			text = _one(pick, ["%s founded %s." % [a, site], "Settlers of %s founded %s." % [a, site],
				"%s grew crowded; some of them left to found %s." % [_site(data, d.get("from_site", "")), site]]) if d.has("from_site") else "%s founded %s." % [a, site]
		&"schism":
			text = "%s broke with %s %s. Those who followed settled %s and became %s." % [d.get("prophet", "A prophet"), b, d.get("cause", ""), site, a]
		&"war_declared":
			text = _one(pick, ["%s went to war with %s over %s." % [a, b, d.get("cause", "nothing")],
				"War between %s and %s, over %s." % [a, b, d.get("cause", "nothing")]])
		&"site_taken":
			text = _one(pick, ["%s took %s from %s. %d died." % [a, site, b, d.get("dead", 0)],
				"%s fell to %s; %d of %s died defending it." % [site, a, d.get("dead", 0), b]])
		&"site_razed":
			text = _one(pick, ["%s burned %s, a settlement of %s, to the walls. %d died." % [a, site, b, d.get("dead", 0)],
				"%s razed %s. None of its %d people were left." % [a, site, d.get("dead", 0)]])
		&"raid_repelled":
			text = _one(pick, ["%s drove %s back from %s." % [b, a, site], "%s attacked %s and were thrown back; %d died." % [a, site, d.get("dead", 0)]])
		&"last_stand":
			text = "%s held %s against %s, though %d fell." % [b, site, a, d.get("dead", 0)]
		&"peace":
			text = _one(pick, ["%s and %s made peace." % [a, b], "The war between %s and %s burned out." % [a, b]])
		&"trade_pact":
			text = _one(pick, ["%s and %s began to trade %s." % [a, b, d.get("goods", "goods")],
				"Caravans of %s ran between %s and %s." % [d.get("goods", "goods"), a, b]])
		&"disaster":
			var options: Array = DISASTER_TEXT.get(d.get("kind", &""), ["Something terrible happened at {site}; {n} died."])
			text = _one(pick, options).format({"site": site, "n": d.get("dead", 0)})
		&"site_abandoned":
			text = _one(pick, ["The last of %s's people left. It stood empty." % site, "%s gave up %s." % [a, site]])
		&"wonder":
			text = _wonder(d.get("kind", &""), a, site, str(d.get("person", "someone")), pick)
		&"prophet":
			text = "%s, a prophet of %s, said the god %s." % [d.get("person", "Someone"), a, SAYINGS[int(d.get("saying", 0)) % SAYINGS.size()]]
		&"pilgrims_joined":
			text = _one(pick, ["Pilgrims kept coming to %s; %d of them stayed with %s." % [site, d.get("count", 0), a],
				"%s swelled with %d newcomers who had heard of %s." % [site, d.get("count", 0), a]])
		&"faction_fell":
			text = _one(pick, ["%s were no more. %s was the last of them to fall silent." % [a, site] if d.get("site", "") != "" else "%s were no more." % a,
				"Nobody was left who called themselves %s." % a])
		&"resident_attacked":
			text = "%s, a host, attacked %s at %s." % [event.actors[1] if event.actors.size() > 1 else "Someone", a, site]
		&"resident_killed":
			text = "%s, a host, killed %s of %s at %s." % [event.actors[1] if event.actors.size() > 1 else "Someone", d.get("victim", "someone"), a, site]
		&"boss_slain":
			text = "%s, a host, killed %s." % [event.actors[0] if event.actors.size() > 0 else "Someone", d.get("boss", "a great beast")]
		&"host_died":
			text = "%s, a host, died." % (event.actors[0] if event.actors.size() > 0 else "Someone")
		&"corpse_scavenged":
			text = "Something picked over the body of %s." % (event.actors[0] if event.actors.size() > 0 else "someone")
		&"corpse_rotted":
			text = "The body of %s rotted further." % (event.actors[0] if event.actors.size() > 0 else "someone")
		&"creatures_returned":
			text = "Creatures came back to the places they had been cleared from."
		_:
			text = String(event.type).capitalize() + "."
	return text.substr(0, 1).to_upper() + text.substr(1)


static func _wonder(kind: StringName, faction: String, site: String, person: String, pick: int) -> String:
	match kind:
		&"relic":
			return "%s of %s found %s near %s." % [person, faction, FAMOUS_RELICS[pick % FAMOUS_RELICS.size()], site]
		&"vein":
			return "%s struck a warm vein beneath %s." % [faction, site]
		&"hunt":
			return "The hunters of %s brought down a beast the size of a hall; %s ate for a season." % [faction, site]
		&"salvage":
			return "%s led %s to a hoard of old things in a collapsed fold near %s." % [person, faction, site]
	return "%s had a harvest so rich that %s still sing about it." % [site, faction]


static func _one(pick: int, options: Array) -> String:
	return options[absi(pick) % options.size()]


## A faction's name as it reads mid-sentence: "the Flesh-Tenders".
static func _faction(data: WorldData, id) -> String:
	var faction: FactionData = data.factions.get(StringName(str(id)))
	if faction == null:
		return str(id)
	var faction_name := faction.display_name
	if not faction_name.begins_with("the ") and not faction_name.begins_with("Children"):
		faction_name = "the " + faction_name
	return faction_name


static func _site(data: WorldData, id) -> String:
	var site: SiteData = data.sites.get(str(id))
	return site.name if site else "a place now forgotten"

class_name ArtifactForge
extends RefCounted
## Makes artifacts out of history (week 29). Looks at what happened at a
## site, picks the most memorable event, and turns it into an object with a
## name: a relic someone found there, the staff of the prophet who split off
## there, the last banner of a town that burned. Plain data.

## Event types worth an artifact, most memorable first.
const PRIORITY := [&"wonder", &"schism", &"site_razed", &"last_stand", &"faction_fell", &"site_abandoned",
	&"disaster", &"site_taken", &"faction_founded", &"people_arrived", &"site_founded"]
const RELIC_NAMES := ["Door-Tooth", "Twitching Knuckle", "Warm Hair", "Tongue-Scale", "Humming Nerve"]


## Every event that happened at a site, oldest first.
static func events_at(data: WorldData, site_id: String) -> Array:
	return data.events.filter(func(e): return e.data.get("site", "") == site_id)


## The most memorable event at a site, or null.
static func best_event(data: WorldData, site_id: String) -> EventRecord:
	var events := events_at(data, site_id)
	for type in PRIORITY:
		for event in events:
			if event.type == type:
				return event
	return null


## Forges the artifact of a site and adds it to data.artifacts. Null if
## nothing ever happened there.
static func forge_for_site(data: WorldData, site: SiteData) -> ArtifactData:
	var event := best_event(data, site.id)
	if event == null:
		return null
	var artifact := ArtifactData.new()
	artifact.id = "artifact_%d" % data.new_id()
	artifact.event_id = event.id
	artifact.site_id = site.id
	artifact.faction = site.faction
	var maker: FactionData = data.factions.get(site.faction)
	artifact.color = maker.color if maker else Color(0.85, 0.8, 0.65)
	var place := site.name
	var faction_name := maker.display_name.trim_prefix("the ") if maker else "the forgotten"
	match event.type:
		&"wonder":
			match event.data.get("kind", &""):
				&"relic":
					artifact.kind = &"relic"
					artifact.name = "the %s of %s" % [RELIC_NAMES[absi(event.id) % RELIC_NAMES.size()], place]
					artifact.color = Color(0.95, 0.85, 0.55)
				&"vein":
					artifact.kind = &"lamp"
					artifact.name = "the Vein-Lamp of %s" % place
				&"hunt":
					artifact.kind = &"keepsake"
					artifact.name = "the Great Jaw of %s" % place
				&"salvage":
					artifact.kind = &"keepsake"
					artifact.name = "%s's Hoard-Key" % event.data.get("person", "Someone")
				_:
					artifact.kind = &"keepsake"
					artifact.name = "the Harvest Sickle of %s" % place
		&"schism":
			artifact.kind = &"staff"
			artifact.name = "the Staff of %s" % event.data.get("prophet", "the Prophet")
		&"site_razed":
			artifact.kind = &"banner"
			var defender: FactionData = data.factions.get(event.actors[1]) if event.actors.size() > 1 else maker
			artifact.name = "the Last Banner of %s" % place
			if defender:
				artifact.color = defender.color
				artifact.faction = defender.id
		&"last_stand":
			artifact.kind = &"shield"
			artifact.name = "the Shield-Bone of %s" % place
		&"faction_fell":
			artifact.kind = &"lamp"
			artifact.name = "the Last Lamp of the %s" % faction_name
		&"site_abandoned":
			artifact.kind = &"bell"
			artifact.name = "the Silent Bell of %s" % place
		&"disaster":
			artifact.kind = &"idol"
			var kinds := {&"bile_flood": "Drowned Idol", &"rot_plague": "Plague Mask", &"spasm": "Buried Lantern", &"famine": "Empty Bowl"}
			artifact.name = "the %s of %s" % [kinds.get(event.data.get("kind", &""), "Broken Idol"), place]
		_:
			artifact.kind = &"stone"
			artifact.name = "the Founding Stone of %s" % place
	data.artifacts[artifact.id] = artifact
	return artifact

class_name Rumors
extends RefCounted
## What people say about what happened (week 30). Picks an event from the
## world's log that a member of a faction would talk about, and tells it the
## way they would: how long ago, what happened (EventText, so it matches the
## log), and how they feel about it. Plain data.

## Older than this is rarely talked about, unless it was about the speaker's own people.
const MEMORY_YEARS := 400
const PRIDE := ["And we would do it again.", "We are not ashamed of it.", "They had it coming.", "Ask anyone. We won."]
const GRIEF := ["We have not forgotten.", "Some of us still pray for them.", "I had family there.", "We will not forget."]
const SPITE := ["Never trust them.", "That is what they are like.", "Remember that, if you deal with them."]


## Events this speaker might bring up, with how likely each is.
## Returns [{"event": EventRecord, "weight": float}], best first.
static func candidates(data: WorldData, speaker_faction: StringName, exclude: Array = []) -> Array:
	var out := []
	for event: EventRecord in data.events:
		if event.id in exclude:
			continue
		var age := data.year - event.year
		var ours := speaker_faction != &"" and speaker_faction in event.actors
		if age > MEMORY_YEARS and not ours:
			continue
		var weight := 1.0 / (1.0 + age / 40.0)
		if ours:
			weight *= 3.0
		if event.type in [&"host_died", &"resident_killed", &"boss_slain", &"corpse_claimed", &"vengeance_sworn", &"deep_settled", &"pilgrims_came", &"key_stolen", &"key_taken", &"key_given", &"key_bought", &"key_found", &"beast_slain_by_host"]:
			weight *= 10.0  # Everybody talks about the strangers who die here, and who kill.
		elif event.type in [&"corpse_scavenged", &"corpse_rotted", &"creatures_returned", &"wonder", &"prophet", &"trade_pact", &"site_founded"]:
			weight *= 0.5
		elif event.type in [&"faction_fell", &"site_razed", &"schism", &"war_declared", &"disaster", &"rot_spread", &"rot_bloom", &"rot_sickness", &"beast_raided", &"beast_arose", &"beast_slain"]:
			weight *= 1.5
		var site: SiteData = data.sites.get(str(event.data.get("site", "")))
		if site and site.slot != "":
			weight *= 2.0  # A place you can walk to.
		out.append({"event": event, "weight": weight})
	out.sort_custom(func(a, b): return a.weight > b.weight)
	return out


## A weighted pick among the candidates, or null if there is nothing to tell.
static func pick(data: WorldData, speaker_faction: StringName, rng: RandomNumberGenerator, exclude: Array = []) -> EventRecord:
	var options := candidates(data, speaker_faction, exclude)
	var total := 0.0
	for option in options:
		total += option.weight
	var roll := rng.randf() * total
	for option in options:
		roll -= option.weight
		if roll <= 0.0:
			return option.event
	return options[0].event if not options.is_empty() else null


## The rumor as a speaker of `speaker_faction` tells it.
static func tell(event: EventRecord, data: WorldData, speaker_faction: StringName, senses_fragment := 0.0) -> String:
	var age := data.year - event.year
	var when := "Just this year,"
	if age >= 300:
		when = "In the old days, they say,"
	elif age >= 80:
		when = "Long ago,"
	elif age >= 30:
		when = "In my grandmother's time,"
	elif age >= 5:
		when = "Some years back,"
	elif age >= 1:
		when = "A little while ago,"
	var what := clause(_host_death(event, data) if event.type == &"host_died" else EventText.describe(event, data))
	var text := "%s %s" % [when, what]
	var pick := absi(event.id)
	if event.type == &"host_died":
		text += " You have the look of one of them." if senses_fragment < 0.5 else " ...You were there. Weren't you? It is in you still."
	elif speaker_faction != &"" and event.actors.size() > 1 and event.type in [&"site_razed", &"site_taken", &"war_declared", &"last_stand", &"raid_repelled"]:
		if event.actors[0] == speaker_faction:
			text += " " + PRIDE[pick % PRIDE.size()]
		elif event.actors[1] == speaker_faction:
			text += " " + GRIEF[pick % GRIEF.size()]
		elif data.relation(speaker_faction, event.actors[0]) < -40:
			text += " " + SPITE[pick % SPITE.size()]
	elif speaker_faction != &"" and speaker_faction in event.actors and event.type in [&"disaster", &"faction_fell", &"site_abandoned", &"resident_killed"]:
		text += " " + GRIEF[pick % GRIEF.size()]
	return text


## A sentence as it reads after "Long ago,": "The Pale Diggers ..." becomes
## "the Pale Diggers ...", names stay capitalized.
static func clause(sentence: String) -> String:
	if sentence.begins_with("The ") or sentence.begins_with("A ") or sentence.begins_with("An "):
		return sentence.substr(0, 1).to_lower() + sentence.substr(1)
	return sentence


## "a colonist named Wenul died in the Flesh-Tenders' land, killed by a Gut Leech."
static func _host_death(event: EventRecord, data: WorldData) -> String:
	var life: LifeRecord = null
	for record in data.lives:
		if event.actors.size() > 0 and record.host_name == event.actors[0]:
			life = record
	var kind := String(life.host_type) if life else "stranger"
	var where := "out in the dark"
	var spot: Vector2 = event.data.get("position", Vector2.ZERO)
	var holder := data.faction_at(ChunkData.world_to_chunk(spot))
	if holder != &"" and data.factions.has(holder):
		where = "in the land of %s" % EventText._faction(data, holder)
	var killer := ""
	var by: StringName = event.data.get("killed_by", &"")
	if by != &"":
		killer = ", killed by %s" % ("a guard" if by == &"colony_npc" else "something that crawls" if String(by).contains("leech") else "something that flies" if String(by).contains("fly") else "something with teeth")
	return "a %s named %s died %s%s." % [kind, event.actors[0] if event.actors.size() > 0 else "someone", where, killer]

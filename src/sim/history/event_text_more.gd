class_name EventTextMore
extends RefCounted
## Sentences for the events of the simulation interlude (D-033): the body's
## rot, beasts, figures, quests, the body's moods, migrations. EventText
## hands every type it does not know to describe() here. Returns "" for a
## type nobody knows.


static func describe(event: EventRecord, data: WorldData) -> String:
	var a := EventText._faction(data, event.actors[0]) if event.actors.size() > 0 else "someone"
	var d := event.data
	var site := EventText._site(data, d.get("site", ""))
	var place: String = str(d.get("place", "somewhere in the body"))
	var pick := event.id
	match event.type:
		&"rot_spread":
			return EventText._one(pick, ["The rot crept into %s." % place, "Grey rot reached %s and stayed." % place,
				"%s went soft and grey; the rot had come." % place])
		&"rot_receded":
			if event.actors.is_empty():
				return EventText._one(pick, ["The rot drew back from %s." % place, "%s dried and hardened again; the rot was gone." % place])
			return EventText._one(pick, ["%s burned the rot back out of %s." % [a, place], "%s scraped %s clean of rot." % [a, place]])
		&"rot_bloom":
			return EventText._one(pick, ["A rot bloom burst open near %s." % place, "Something split near %s and the rot poured out." % place,
				"Near %s the flesh blistered overnight into a field of rot." % place])
		&"rot_sickness":
			return EventText._one(pick, ["Rot sickness took %d in %s." % [d.get("dead", 0), site], "%s coughed grey for a season; %d died." % [site, d.get("dead", 0)]])
		&"beast_arose", &"beast_raided", &"beast_slain", &"beast_slain_by_host", &"beast_died", &"beast_escaped":
			return _beast(event, data, a, site, pick)
	return ""


static func _beast(event: EventRecord, data: WorldData, a: String, site: String, pick: int) -> String:
	var beast: BeastData = data.beasts.get(str(event.data.get("beast", "")))
	var who := beast.full_name() if beast else "a nameless beast"
	var what := Beasts.describe(beast) if beast else "a beast"
	var d := event.data
	match event.type:
		&"beast_arose":
			return EventText._one(pick, ["Something grew too big in %s: %s, %s." % [d.get("place", "a dark fold"), who, what],
				"%s, %s, made its lair in %s." % [who, what, d.get("place", "a dark fold")],
				"People began to speak of %s, %s that lived in %s." % [who, what, d.get("place", "a dark fold")]])
		&"beast_raided":
			return EventText._one(pick, ["%s came out of the dark and killed %d of %s at %s." % [who, d.get("dead", 0), a, site],
				"%s took %d people from %s." % [who, d.get("dead", 0), site],
				"%s raided %s; %s buried %d." % [who, site, a, d.get("dead", 0)]])
		&"beast_slain":
			return EventText._one(pick, ["%s hunted down %s and killed it." % [a, who], "The hunters of %s brought back the head of %s." % [a, who]])
		&"beast_slain_by_host":
			return "%s, a host, killed %s." % [event.actors[0] if not event.actors.is_empty() else "Someone", who]
		&"beast_died":
			return EventText._one(pick, ["%s died, and nobody knows how." % who, "%s was found dead in its lair." % who])
		&"beast_escaped":
			return "%s hunted %s, but it slipped away." % [a, who]
	return ""

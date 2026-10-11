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
	return ""

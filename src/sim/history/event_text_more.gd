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
		&"body_mood":
			var where := "the Lungs" if d.get("region", &"gut") == &"lungs" else "the Gut"
			if d.get("mood", &"") == &"spasm":
				return EventText._one(pick, ["The body spasmed; %s shook for a minute." % where, "A spasm went through %s." % where])
			return EventText._one(pick, ["A fever burned through %s." % where, "%s ran hot with the god's fever." % where.substr(0, 1).to_upper() + where.substr(1)])
		&"quest_done":
			return "%s, a host, did what %s asked of them." % [event.actors[1] if event.actors.size() > 1 else "Someone", a]
		&"leader_rose", &"leader_died", &"leader_overthrown", &"leader_deed", &"leader_killed":
			return _leader(event, data, a, site, pick)
	return ""


static func _leader(event: EventRecord, data: WorldData, a: String, site: String, pick: int) -> String:
	var d := event.data
	var f: FigureData = data.figures.get(str(d.get("figure", "")))
	var who := f.full_name() if f else "their leader"
	match event.type:
		&"leader_rose":
			return EventText._one(pick, ["%s chose %s to lead them." % [a, who], "%s took the lead of %s." % [who, a]])
		&"leader_died":
			var cause := f.cause if f else "something"
			var heir: FigureData = data.figures.get(str(d.get("heir", "")))
			var after := (" They chose %s." % heir.full_name()) if heir else ""
			if cause in Figures.DEATHS:
				return EventText._one(pick, ["%s of %s died of %s.%s" % [who, a, cause, after], "%s mourned %s, dead of %s.%s" % [a, who, cause, after]])
			return "%s of %s was killed by %s.%s" % [who, a, cause, after]
		&"leader_overthrown":
			var fallen: FigureData = data.figures.get(str(d.get("fallen", "")))
			var fallen_name := fallen.full_name() if fallen else "the old leader"
			return EventText._one(pick, ["%s put a knife in %s and took the lead of %s." % [who, fallen_name, a],
				"%s fell to %s, who now leads %s." % [fallen_name, who, a]])
		&"leader_killed":
			return "%s, a host, killed %s, leader of %s." % [event.actors[1] if event.actors.size() > 1 else "Someone", who, a]
		&"leader_deed":
			var other := EventText._faction(data, d.get("other", "")) if d.has("other") else "their neighbours"
			match d.get("deed", &""):
				&"cruel":
					return EventText._one(pick, ["%s purged %s; %d were thrown into the dark." % [who, site, d.get("dead", 0)], "%s hanged %d of their own people in %s." % [who, d.get("dead", 0), site]])
				&"paranoid":
					return "%s saw traitors everywhere in %s and drove out %d of them." % [who, site, d.get("dead", 0)]
				&"pious":
					return EventText._one(pick, ["%s raised a shrine to the god in %s." % [who, site], "%s ordered a year of fasting in %s." % [who, site]])
				&"wise":
					return "%s made peace with %s." % [who, other]
				&"ambitious":
					return "%s laid claim to the lands of %s." % [who, other]
				&"greedy":
					return "%s doubled the tolls on the traders of %s." % [who, other]
				&"kind":
					return EventText._one(pick, ["%s held a feast in %s and invited every neighbour." % [who, site], "%s opened the stores of %s to the hungry." % [who, site]])
				&"brave":
					var beast: BeastData = data.beasts.get(str(d.get("beast", "")))
					if beast:
						return "%s went alone into the lair of %s and came back with its head." % [who, beast.full_name()]
					return "%s led the hunters of %s into the deep and came back." % [who, a]
				&"mad":
					return String(Figures.MAD_DECREES[int(d.get("decree", 0)) % Figures.MAD_DECREES.size()]).format({"n": who, "site": site})
				&"craven":
					return "%s had the walls of %s built higher, and higher again." % [who, site]
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

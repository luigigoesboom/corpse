class_name Legend
extends RefCounted
## What fragment-sensing people remember about you across bodies (week 32).
## The fragment's deeds are events in WorldData.events, listed per life in
## LifeRecord.deed_event_ids; a priest of the Choir looks at what you did in
## earlier bodies and tells you so.

## Deeds everybody hears about, whoever they were done to.
const FAMOUS := [&"boss_slain", &"beast_slain_by_host"]
## Deeds they are glad of; the rest are held against you.
const GOOD := [&"boss_slain", &"beast_slain_by_host"]


## The latest deed from an earlier body that matters to `faction`:
## {"event": EventRecord, "lives_ago": int}, or {} if there is none.
static func remembered_deed(data: WorldData, faction: StringName) -> Dictionary:
	var now := data.lives.size() - 1
	if data.current_life() == null:
		now = data.lives.size()
	for i in range(now - 1, -1, -1):
		var life: LifeRecord = data.lives[i]
		for j in range(life.deed_event_ids.size() - 1, -1, -1):
			var event := _event(data, life.deed_event_ids[j])
			if event and (faction in event.actors or event.type in FAMOUS):
				return {"event": event, "lives_ago": now - i}
	return {}


## What a speaker who senses the fragment says on seeing you, or "".
static func recognition(data: WorldData, faction: StringName) -> String:
	var deed := remembered_deed(data, faction)
	var feeling := data.legend_standing(faction)
	if deed.is_empty():
		return "" if absi(feeling) < 10 else "You... I know what lives inside you, whatever body it wears."
	var event: EventRecord = deed.event
	var when := "Your last body" if deed.lives_ago == 1 else "%s bodies ago" % ["Two", "Three", "Four", "Five"][mini(deed.lives_ago, 5) - 2] if deed.lives_ago <= 5 else "Many bodies ago"
	var site: SiteData = data.sites.get(str(event.data.get("site", "")))
	var place := site.name if site else "the dark"
	var what := "you did something we remember"
	match event.type:
		&"resident_killed":
			what = "you killed %s at %s" % [event.data.get("victim", "one of us"), place]
		&"resident_attacked":
			what = "you drew our blood at %s" % place
		&"key_stolen":
			what = "you stole the heart-key from us"
		&"shrine_robbed":
			what = "you robbed the body we laid in our shrine at %s" % place
		&"boss_slain":
			what = "you slew %s" % event.data.get("boss", "a great beast")
		&"leader_killed":
			var leader: FigureData = data.figures.get(str(event.data.get("figure", "")))
			what = "you killed %s, who led us, at %s" % [leader.full_name() if leader else "our leader", place]
		&"beast_slain_by_host":
			var beast: BeastData = data.beasts.get(str(event.data.get("beast", "")))
			what = "you slew %s" % (beast.full_name() if beast else "a great beast")
	var how := "The heart was glad of it." if event.type in GOOD else "We have not forgiven it."
	return "I know you, whatever face you wear now. %s, %s. %s" % [when, what, how]


static func _event(data: WorldData, id: int) -> EventRecord:
	for event in data.events:
		if event.id == id:
			return event
	return null

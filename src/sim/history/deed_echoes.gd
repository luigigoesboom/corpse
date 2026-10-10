class_name DeedEchoes
extends RefCounted
## What the last host did, felt in the years after it died (week 37): an
## Aftermath rule that turns deeds into history, so the world after a few
## lives is shaped by them. Each echo is an event (rumors, murals and the
## log tell it) and a change you can see. Plain data.
##
##   resident_killed  -> the dead person's people swear vengeance on the
##                       killer's name (rumors)
##   ichor offered    -> the keepers' home grows on it (more residents)
##   boss_slain       -> settlers go down into the safer deep: the
##                       strongest Gut people grows
##   body enshrined   -> pilgrims come to see the fragment's body
##   shrine_robbed    -> the keepers' relations with everyone sour

## Residents gained per ichor offered.
const PEOPLE_PER_OFFERING := 0.5
const PILGRIMS_PER_BODY := 20
const DEEP_SETTLERS := 40
const DESECRATION_BITTERNESS := 15


static func apply(data: WorldData, life: LifeRecord, report: Dictionary) -> void:
	if life == null or life.is_alive():
		return
	var deeds := life.deed_event_ids.map(func(id): return Lore.event_by_id(data, id)).filter(func(e): return e != null)
	# Vengeance, once per people wronged.
	var wronged := {}
	for event in deeds:
		if event.type == &"resident_killed" and not event.actors.is_empty():
			wronged[event.actors[0]] = wronged.get(event.actors[0], 0) + 1
	for faction in wronged:
		data.log_event(&"vengeance_sworn", [faction, life.host_name], {"dead": wronged[faction]})
	# Offerings at a people's heart-root feed them.
	for faction in life.offerings:
		var home := _home(data, StringName(str(faction)))
		var grown := roundi(life.offerings[faction] * PEOPLE_PER_OFFERING)
		if home and grown > 0:
			home.population += grown
			data.log_event(&"offerings_fed", [faction], {"site": home.id, "count": grown})
			report.hints.append(_capital("Your offerings fed %s; they grew." % EventText._faction(data, faction)))
	# The Matron dead: the deep is safer, and people go down into it.
	if deeds.any(func(e): return e.type == &"boss_slain"):
		var settlers := _strongest_defined(data)
		var home := _home(data, settlers.id) if settlers else null
		if home:
			home.population += DEEP_SETTLERS
			data.log_event(&"deep_settled", [settlers.id], {"site": home.id, "count": DEEP_SETTLERS})
			report.hints.append(_capital("With the Matron dead, %s went down into the deep." % EventText._faction(data, settlers.id)))
	# Pilgrims to every enshrined body of the fragment.
	for other: LifeRecord in data.lives:
		if other.corpse_state == &"enshrined" and other.corpse_site != "":
			var site: SiteData = data.sites.get(other.corpse_site)
			if site and site.is_lived_in():
				site.population += PILGRIMS_PER_BODY
				if not _told(data, &"pilgrims_came", other.host_name):
					data.log_event(&"pilgrims_came", [site.faction, other.host_name], {"site": site.id, "count": PILGRIMS_PER_BODY})
	# A robbed shrine makes its keepers bitter towards everyone.
	for event in deeds:
		if event.type == &"shrine_robbed" and not event.actors.is_empty():
			var keepers := StringName(str(event.actors[0]))
			for other: FactionData in data.factions.values():
				if other.id != keepers and other.is_alive():
					data.set_relation(keepers, other.id, data.relation(keepers, other.id) - DESECRATION_BITTERNESS)
			data.log_event(&"shrine_desecrated", [keepers], {"site": event.data.get("site", "")})


## A people's home: a hand-made place first, then the biggest.
static func _home(data: WorldData, faction: StringName) -> SiteData:
	var best: SiteData = null
	for site: SiteData in data.sites.values():
		if site.faction != faction or not site.is_lived_in():
			continue
		if best == null or (site.slot != "" and best.slot == "") \
				or ((site.slot != "") == (best.slot != "") and site.population > best.population):
			best = site
	return best


static func _strongest_defined(data: WorldData) -> FactionData:
	var best: FactionData = null
	for faction: FactionData in data.factions.values():
		if faction.defined and faction.is_alive() and (best == null or faction.strength > best.strength):
			best = faction
	return best


static func _told(data: WorldData, type: StringName, host: String) -> bool:
	return data.events.any(func(e): return e.type == type and host in e.actors)


static func _capital(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)

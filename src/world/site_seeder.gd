class_name SiteSeeder
extends RefCounted
## Puts sites into the hand-made Settlement slots of world.tscn (weeks 27,
## 28). History (HistorySim) founds sites all over the body; a slot takes
## the biggest lived-in site of its preferred faction (or of whoever holds
## the slot's chunk) that is not in a slot yet. If that faction has none
## left, a new one is founded now. A slot nobody can fill gets an empty site.
## Slots that already have a site keep it: from then on it is history's.


static func fill_slots(data: WorldData, settlements: Array) -> void:
	for slot in settlements:
		var key := EntityLayer.key_of(slot)
		if data.site_in_slot(key):
			continue
		var owner: StringName = slot.preferred_faction
		if not (data.factions.has(owner) and data.factions[owner].is_alive()):
			owner = data.faction_at(ChunkData.world_to_chunk(slot.position))
		var site: SiteData = null
		for candidate: SiteData in data.sites.values():
			if candidate.faction == owner and owner != &"" and candidate.is_lived_in() and candidate.slot == "" \
					and (site == null or candidate.population > site.population):
				site = candidate
		if site == null:
			site = SiteData.new()
			site.id = "site_%d" % data.new_id()
			site.name = Names.place_name(data.world_seed, key)
			site.founded_year = data.year
			if owner != &"":
				site.faction = owner
				site.population = SiteData.PEOPLE_PER_RESIDENT * 3
			data.sites[site.id] = site
		site.slot = key

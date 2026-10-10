class_name SiteSeeder
extends RefCounted
## Fills WorldData.sites when a world starts (week 27): one SiteData per
## Settlement slot in world.tscn. A slot goes to its preferred faction, or
## else to whoever holds its chunk; nobody = an empty site. Residents scale
## with the owner's strength, up to the slot's capacity. History changes
## sites after this (week 28 on).

## Strength per resident shown.
const STRENGTH_PER_RESIDENT := 20


static func seed_sites(data: WorldData, settlements: Array) -> void:
	data.sites.clear()
	for slot in settlements:
		var site := SiteData.new()
		site.id = EntityLayer.key_of(slot)
		site.name = Names.place_name(data.world_seed, site.id)
		site.founded_year = data.year
		var owner: StringName = slot.preferred_faction
		if not data.factions.has(owner):
			owner = data.faction_at(ChunkData.world_to_chunk(slot.position))
		if owner != &"":
			site.faction = owner
			site.population = clampi(data.factions[owner].strength / STRENGTH_PER_RESIDENT, 2, slot.capacity)
		data.sites[site.id] = site

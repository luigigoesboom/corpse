class_name Migration
extends RefCounted
## Peoples moving between regions (D-033, roadmap week 70 pulled forward).
## Each year of history (worldgen and between lives), a people under
## pressure (at war, in a crowded region, or hit by a disaster lately) may
## send part of its people down the vessels and airways to another region
## with a past of its own. They found a new people there, the exiles, kin
## to the old (a parent, warm relations), with a settlement of their own.
## Logged as people_migrated.

const CHANCE := 0.0015
const MIN_STRENGTH := 160


## One year of migration across all simulated regions.
static func tick(data: WorldData, rng: RandomNumberGenerator) -> void:
	var regions: Array = Regions.IDS.filter(func(r): return Regions.info(r).history)
	if regions.size() < 2:
		return
	for faction: FactionData in data.factions.values().duplicate():
		if not faction.is_alive() or faction.strength < MIN_STRENGTH or faction.defined and rng.randf() < 0.7:
			continue
		var pushed := 1.0 + faction.wars.size() + (1.5 if _pressure(data, faction.region) > 0.85 else 0.0)
		if rng.randf() > CHANCE * pushed:
			continue
		var others: Array = regions.filter(func(r): return r != faction.region)
		var to: StringName = others[rng.randi() % others.size()]
		_migrate(data, faction, to, rng)


static func _migrate(data: WorldData, parent: FactionData, to: StringName, rng: RandomNumberGenerator) -> void:
	var sites := data.sites.values().filter(func(s): return s.faction == parent.id and s.is_lived_in())
	if sites.is_empty():
		return
	sites.sort_custom(func(a, b): return a.population > b.population)
	var from_site: SiteData = sites[0]
	var leaving := int(from_site.population * rng.randf_range(0.2, 0.35))
	if leaving < 20:
		return
	from_site.population -= leaving
	var exiles := FactionData.new()
	exiles.id = StringName("people_%d" % data.new_id())
	exiles.region = to
	HistoryNames.make_splinter(exiles, parent, rng)
	if rng.randf() < 0.5:
		exiles.display_name = "the Exiles of %s" % from_site.name
	exiles.parent = parent.id
	exiles.founded_year = data.year
	data.factions[exiles.id] = exiles
	var previous := HistorySim.region
	HistorySim.region = to
	var site := HistorySim._new_site(data, exiles, leaving, rng)
	HistorySim._update_strength(data, exiles)
	HistorySim.region = parent.region
	HistorySim._update_strength(data, parent)
	HistorySim.region = previous
	data.set_relation(parent.id, exiles.id, 40)
	data.log_event(&"people_migrated", [exiles.id, parent.id], {"site": site.id, "from": parent.region, "to": to, "count": leaving})


static func _pressure(data: WorldData, region: StringName) -> float:
	var total := 0
	for site: SiteData in data.sites.values():
		if site.is_lived_in() and site.region == region:
			total += site.population
	return total / float(Regions.info(region).capacity)

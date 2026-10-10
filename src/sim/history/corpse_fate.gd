class_name CorpseFate
extends RefCounted
## Week 33: the factions near a dead host's body decide what becomes of it,
## instead of random scavengers. Runs as an Aftermath rule.
##
## Who decides: the faction whose land the body lies in, or (less often) a
## faction that senses the fragment and comes looking for its old bodies.
## What they do comes from FactionDef.corpse_fates (fate -> weight):
##   enshrined: carried to their settlement's shrine, kept whole and guarded;
##              taking from it is a deed against them (CorpseLayer).
##   studied:   carried to their settlement, the god-matter cut out of it.
##   eaten:     left where it lay, the mutations eaten, the things left.
##   looted:    left where it lay, the pockets emptied.
## A faction that hates the fragment (legend < -30) never enshrines it.
## Plain data: positions of settlements come in as `places` (slot -> point).

const CLAIMED := [&"enshrined", &"studied", &"eaten", &"looted"]
## Legend below which a faction will not honour the fragment's body.
const SPITE := -30
## Room between bodies laid out in the same shrine, in px.
const BODY_SPACING := 40.0
## Standing lost with the keepers for taking from a body they enshrined.
const ROB_DEED := -40


## Decides the fate of every body nobody has claimed yet.
static func apply(data: WorldData, strength: float, rng: RandomNumberGenerator, places: Dictionary, report: Dictionary) -> void:
	var newest := _newest_dead(data)
	for i in data.lives.size():
		var life: LifeRecord = data.lives[i]
		if life.is_alive() or life.corpse_state in CLAIMED:
			continue
		var faction := _claimant(data, life, strength, rng)
		if faction == &"":
			continue
		var fate := _pick_fate(data, faction, rng)
		var site: SiteData = _home(data, faction, places) if fate in [&"enshrined", &"studied"] else null
		if fate in [&"enshrined", &"studied"] and site == null:
			fate = &"looted"  # Nowhere to carry it.
		var hint := claim(data, i, faction, fate, site, places)
		if i == newest and hint != "":
			report.hints.append(hint)


## Applies `fate` to body `index` on behalf of `faction`. Returns a hint.
static func claim(data: WorldData, index: int, faction: StringName, fate: StringName, site: SiteData, places: Dictionary) -> String:
	var life: LifeRecord = data.lives[index]
	var who := _faction_name(data, faction)  # "the Choir of Waking"
	var details := {"fate": fate, "faction": faction}
	life.corpse_state = fate
	life.corpse_faction = faction
	match fate:
		&"enshrined", &"studied":
			var already := data.lives.filter(func(l): return l.corpse_site == site.id).size()
			life.corpse_position = places[site.slot] + Vector2(BODY_SPACING * already, 0)
			life.corpse_site = site.id
			details["site"] = site.id
			if fate == &"studied":
				details["mutations"] = life.corpse_mutations.values()
				details["ichor"] = life.corpse_ichor
				life.corpse_mutations.clear()
				life.corpse_ichor = 0  # They bled it to study it.
		&"eaten":
			details["mutations"] = life.corpse_mutations.values()
			details["ichor"] = life.corpse_ichor
			life.corpse_mutations.clear()
			life.corpse_ichor = 0
		&"looted":
			details["items"] = life.corpse_items.duplicate()
			details["ichor"] = life.corpse_ichor / 2
			life.corpse_items.clear()
			life.corpse_ichor -= life.corpse_ichor / 2
	data.log_event(&"corpse_claimed", [life.host_name, faction], details)
	var hint := ""
	match fate:
		&"enshrined":
			hint = "%s carried your old body to their shrine at %s." % [who, site.name]
		&"studied":
			hint = "%s took your old body to %s, to see what grew in it." % [who, site.name]
		&"eaten":
			hint = "%s have fed on your old body." % who
		_:
			hint = "%s went through your old body's pockets." % who
	return hint.substr(0, 1).to_upper() + hint.substr(1)


static func _newest_dead(data: WorldData) -> int:
	var newest := data.lives.size() - 1
	while newest >= 0 and data.lives[newest].is_alive():
		newest -= 1
	return newest


## The faction that gets to the body first, or &"" if nobody does.
static func _claimant(data: WorldData, life: LifeRecord, strength: float, rng: RandomNumberGenerator) -> StringName:
	var holder := data.faction_at(ChunkData.world_to_chunk(life.corpse_position))
	if holder != &"" and rng.randf() < strength * 0.9:
		return holder
	for faction: FactionData in data.factions.values():
		if faction.id != holder and faction.is_alive() and faction.senses_fragment > 0.0:
			if rng.randf() < strength * faction.senses_fragment * 0.6:
				return faction.id
	return &""


static func _pick_fate(data: WorldData, faction: StringName, rng: RandomNumberGenerator) -> StringName:
	var def := FactionDb.get_def(faction)
	var weights: Dictionary = def.corpse_fates.duplicate() if def and not def.corpse_fates.is_empty() else {&"looted": 1}
	if data.legend_standing(faction) < SPITE and weights.has(&"enshrined"):
		weights[&"looted"] = weights.get(&"looted", 0) + weights[&"enshrined"]
		weights.erase(&"enshrined")
	var total := 0
	for fate in weights:
		total += int(weights[fate])
	var pick := rng.randi_range(1, maxi(total, 1))
	for fate in weights:
		pick -= int(weights[fate])
		if pick <= 0:
			return fate
	return &"looted"


## The faction's biggest lived-in settlement with a place on the map.
static func _home(data: WorldData, faction: StringName, places: Dictionary) -> SiteData:
	var best: SiteData = null
	for site: SiteData in data.sites.values():
		if site.faction == faction and site.is_lived_in() and places.has(site.slot):
			if best == null or site.population > best.population:
				best = site
	return best


static func _faction_name(data: WorldData, faction: StringName) -> String:
	var f: FactionData = data.factions.get(faction)
	var faction_name := f.display_name if f else String(faction).capitalize()
	return faction_name if faction_name.begins_with("the ") else "the " + faction_name

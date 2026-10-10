class_name SiteData
extends RefCounted
## A place in the world (weeks 27, 28). Plain data in WorldData.sites.
## History founds sites, fights over them and abandons them; some of them sit
## in a hand-made slot in the built world (`slot` = the Settlement node's name
## in world.tscn), the rest are elsewhere in the body. Ruins and shrines
## (week 29) use the same record with another `kind`.

## Inhabitants per resident shown in a settlement.
const PEOPLE_PER_RESIDENT := 25

var id: String
## &"settlement" (lived in) or &"ruin" (abandoned, razed). Later &"shrine".
var kind: StringName = &"settlement"
## FactionData id of the owners, or &"" if nobody lives here.
var faction: StringName = &""
## Generated name, e.g. "Bilewell".
var name := ""
## Inhabitants.
var population := 0
var founded_year := 0
## Year it was abandoned or destroyed, or -1.
var ended_year := -1
## The hand-made slot it occupies in the built world, or "" (elsewhere).
var slot := ""


func is_lived_in() -> bool:
	return kind == &"settlement" and faction != &"" and population > 0


## How many residents a settlement slot shows for this site.
func residents_shown(capacity: int) -> int:
	if not is_lived_in():
		return 0
	return clampi(roundi(population / float(PEOPLE_PER_RESIDENT)), 1, capacity)


func to_dict() -> Dictionary:
	return {"id": id, "kind": kind, "faction": faction, "name": name, "population": population,
		"founded_year": founded_year, "ended_year": ended_year, "slot": slot}


static func from_dict(d: Dictionary) -> SiteData:
	var site := SiteData.new()
	site.id = d.get("id", "")
	site.kind = d.get("kind", &"settlement")
	site.faction = d.get("faction", &"")
	site.name = d.get("name", "")
	site.population = int(d.get("population", 0))
	site.founded_year = int(d.get("founded_year", 0))
	site.ended_year = int(d.get("ended_year", -1))
	site.slot = d.get("slot", site.id)  # Before week 28 a site's id was its slot.
	return site

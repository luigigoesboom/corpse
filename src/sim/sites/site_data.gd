class_name SiteData
extends RefCounted
## A place in the world the history can fill (week 27): for now a settlement
## in a hand-placed slot (a Settlement node in world.tscn). Plain data, saved
## in WorldData.sites under the slot's node name. Ruins and shrines (week 29)
## use the same record with another `kind`.

var id: String
## &"settlement" (lived in) or, later, &"ruin", &"shrine".
var kind: StringName = &"settlement"
## FactionDef id of the owners, or &"" if nobody lives here.
var faction: StringName = &""
## Generated name, e.g. "Bilewell".
var name := ""
## Residents shown in the world.
var population := 0
var founded_year := 0


func is_lived_in() -> bool:
	return kind == &"settlement" and faction != &"" and population > 0


func to_dict() -> Dictionary:
	return {"id": id, "kind": kind, "faction": faction, "name": name, "population": population, "founded_year": founded_year}


static func from_dict(d: Dictionary) -> SiteData:
	var site := SiteData.new()
	site.id = d.get("id", "")
	site.kind = d.get("kind", &"settlement")
	site.faction = d.get("faction", &"")
	site.name = d.get("name", "")
	site.population = int(d.get("population", 0))
	site.founded_year = int(d.get("founded_year", 0))
	return site

class_name BeastData
extends RefCounted
## One legendary beast (D-033): a creature of a common kind grown into
## something with a name, two traits, a lair and a past. Plain data in
## WorldData.beasts, keyed by `id`. What it looks like and how it fights in
## play comes from its kind and traits (BeastLair applies them).

var id := ""
var name := ""          ## "Vrask"
var epithet := ""       ## "the Gnawer"
var kind: StringName    ## The creature kind it grew from (&"gut_leech"...).
var region: StringName = Regions.GUT
var lair := ""          ## The BeastLair slot it lives in.
var traits: Array = []  ## StringNames from Beasts.TRAITS.
var born_year := 0
var died_year := -1
## Who ended it: a faction id, a host's name, or "age".
var slain_by := ""
## How many people it has killed in its raids.
var kills := 0


func is_alive() -> bool:
	return died_year < 0


## "Vrask the Gnawer"
func full_name() -> String:
	return "%s %s" % [name, epithet] if epithet != "" else name


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "epithet": epithet, "kind": kind, "region": region, "lair": lair, "traits": traits.duplicate(),
		"born_year": born_year, "died_year": died_year, "slain_by": slain_by, "kills": kills}


static func from_dict(d: Dictionary) -> BeastData:
	var b := BeastData.new()
	b.id = d.get("id", "")
	b.name = d.get("name", "")
	b.epithet = d.get("epithet", "")
	b.kind = d.get("kind", &"gut_leech")
	b.region = d.get("region", Regions.GUT)
	b.lair = d.get("lair", "")
	b.traits = d.get("traits", []).duplicate()
	b.born_year = int(d.get("born_year", 0))
	b.died_year = int(d.get("died_year", -1))
	b.slain_by = d.get("slain_by", "")
	b.kills = int(d.get("kills", 0))
	return b

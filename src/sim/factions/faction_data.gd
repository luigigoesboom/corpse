class_name FactionData
extends RefCounted
## A faction's current state in this world (week 26). Plain data, saved in
## WorldData.factions. The unchanging part (name, creed, temperament) is its
## FactionDef, found by `id`.

var id: StringName
## Roughly how many members. 0 = the faction is gone (kept for history).
var strength := 0
## Chunks it holds (Vector2i), sorted.
var territory: Array[Vector2i] = []
## Other faction id -> -100 (war) .. 100 (kin).
var relations: Dictionary = {}
var founded_year := 0


func is_alive() -> bool:
	return strength > 0


func holds(chunk: Vector2i) -> bool:
	return chunk in territory


## Where it starts: strength and relations from its FactionDef.
static func from_def(def: FactionDef, year: int) -> FactionData:
	var faction := FactionData.new()
	faction.id = def.id
	faction.strength = def.strength
	faction.relations = def.relations.duplicate()
	faction.founded_year = year
	return faction


func to_dict() -> Dictionary:
	return {
		"id": id,
		"strength": strength,
		"territory": territory.duplicate(),
		"relations": relations.duplicate(),
		"founded_year": founded_year,
	}


static func from_dict(d: Dictionary) -> FactionData:
	var faction := FactionData.new()
	faction.id = d.get("id", &"")
	faction.strength = int(d.get("strength", 0))
	for chunk in d.get("territory", []):
		faction.territory.append(chunk)
	faction.relations = d.get("relations", {}).duplicate()
	faction.founded_year = int(d.get("founded_year", 0))
	return faction

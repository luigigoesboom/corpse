class_name FigureData
extends RefCounted
## A notable person (D-033): for now the leader of a people. Plain data in
## WorldData.figures, keyed by `id`. Their traits bend how their people
## behave while they lead (Figures.TRAITS); `applied` remembers exactly
## what was changed, so it can be given back when they go.

var id := ""
var name := ""
var title := ""          ## "Elder", "Cantor", "Windmaster"...
var faction: StringName
var role: StringName = &"leader"
var traits: Array = []   ## StringNames from Figures.TRAITS.
var born_year := 0
var rose_year := 0
var died_year := -1
var cause := ""          ## How they died: "old age", "a host", "the rot"...
## Temperament changes made to their faction: field -> amount.
var applied: Dictionary = {}


func is_alive() -> bool:
	return died_year < 0


## "Elder Belet the Cruel"
func full_name() -> String:
	var epithet := ""
	if not traits.is_empty():
		epithet = " " + Figures.EPITHETS.get(traits[0], "")
	return ("%s %s%s" % [title, name, epithet]).strip_edges()


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "title": title, "faction": faction, "role": role, "traits": traits.duplicate(),
		"born_year": born_year, "rose_year": rose_year, "died_year": died_year, "cause": cause, "applied": applied.duplicate()}


static func from_dict(d: Dictionary) -> FigureData:
	var f := FigureData.new()
	f.id = d.get("id", "")
	f.name = d.get("name", "")
	f.title = d.get("title", "")
	f.faction = d.get("faction", &"")
	f.role = d.get("role", &"leader")
	f.traits = d.get("traits", []).duplicate()
	f.born_year = int(d.get("born_year", 0))
	f.rose_year = int(d.get("rose_year", 0))
	f.died_year = int(d.get("died_year", -1))
	f.cause = d.get("cause", "")
	f.applied = d.get("applied", {}).duplicate()
	return f

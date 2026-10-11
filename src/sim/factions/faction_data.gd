class_name FactionData
extends RefCounted
## A faction in this world (weeks 26, 28). Plain data, saved in
## WorldData.factions. Hand-made factions (data/factions, FactionDef) copy
## their identity from the def; peoples invented by the history sim (D-025)
## have only this record. Either way the sim reads only this.

var id: StringName
## Has a FactionDef (hand-made, destined to exist in the present).
var defined := false
var display_name := ""
## One member: "a Flesh-Tender".
var member_name := ""
var color := Color.WHITE
## What kind of people they are (history archetype), e.g. &"farmers".
var archetype: StringName = &""
var values: Array = []
var aggression := 0.5
var expansion := 0.5
var piety := 0.5
var trade := 0.5
var senses_fragment := 0.0
## Roughly how many members. 0 = the faction is gone (kept for history).
var strength := 0
## Chunks it holds in the built world (Vector2i), sorted. Peoples living
## elsewhere in the body have none.
var territory: Array[Vector2i] = []
## Other faction id -> -100 (war) .. 100 (kin).
var relations: Dictionary = {}
## Faction ids it is at war with.
var wars: Array = []
## Faction ids it has a trade pact with.
var trade_partners: Array = []
var founded_year := 0
## Year it died out, or -1.
var fell_year := -1
## Faction it split from (schism), or &"".
var parent: StringName = &""
## The region it lives in (Regions, week 46).
var region: StringName = Regions.GUT


func is_alive() -> bool:
	return strength > 0


func holds(chunk: Vector2i) -> bool:
	return chunk in territory


## A hand-made faction at its founding: identity from its FactionDef.
static func from_def(def: FactionDef, year: int) -> FactionData:
	var faction := FactionData.new()
	faction.id = def.id
	faction.strength = def.strength
	faction.relations = def.relations.duplicate()
	faction.founded_year = year
	faction.copy_identity(def)
	return faction


func copy_identity(def: FactionDef) -> void:
	defined = true
	display_name = def.display_name
	member_name = def.member_name
	color = def.color
	values = def.values.duplicate()
	region = def.region
	aggression = def.aggression
	expansion = def.expansion
	piety = def.piety
	trade = def.trade
	senses_fragment = def.senses_fragment


func to_dict() -> Dictionary:
	return {
		"id": id, "defined": defined, "display_name": display_name, "member_name": member_name,
		"color": color, "archetype": archetype, "values": values.duplicate(),
		"aggression": aggression, "expansion": expansion, "piety": piety, "trade": trade,
		"senses_fragment": senses_fragment, "strength": strength,
		"territory": territory.duplicate(), "relations": relations.duplicate(), "wars": wars.duplicate(), "trade_partners": trade_partners.duplicate(),
		"founded_year": founded_year, "fell_year": fell_year, "parent": parent, "region": region,
	}


static func from_dict(d: Dictionary) -> FactionData:
	var faction := FactionData.new()
	faction.id = d.get("id", &"")
	faction.strength = int(d.get("strength", 0))
	for chunk in d.get("territory", []):
		faction.territory.append(chunk)
	faction.relations = d.get("relations", {}).duplicate()
	faction.wars = d.get("wars", []).duplicate()
	faction.trade_partners = d.get("trade_partners", []).duplicate()
	faction.founded_year = int(d.get("founded_year", 0))
	faction.fell_year = int(d.get("fell_year", -1))
	faction.parent = d.get("parent", &"")
	faction.archetype = d.get("archetype", &"")
	faction.region = d.get("region", Regions.GUT)
	var def := FactionDb.get_def(faction.id)
	if not d.has("display_name") and def:
		faction.copy_identity(def)  # Saved before week 28: identity lived only in the def.
	else:
		faction.defined = bool(d.get("defined", false))
		faction.display_name = d.get("display_name", String(faction.id))
		faction.member_name = d.get("member_name", "")
		faction.color = d.get("color", Color.WHITE)
		faction.values = d.get("values", []).duplicate()
		faction.aggression = float(d.get("aggression", 0.5))
		faction.expansion = float(d.get("expansion", 0.5))
		faction.piety = float(d.get("piety", 0.5))
		faction.trade = float(d.get("trade", 0.5))
		faction.senses_fragment = float(d.get("senses_fragment", 0.0))
	return faction

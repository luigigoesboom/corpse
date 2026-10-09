class_name LifeRecord
extends RefCounted
## One host the player has had: who it was, when and how it lived and died,
## what it carried and did. Lives are kept forever in WorldData.lives; they are
## how the world remembers you (corpses, legends, rumors build on them).
## Plain data: refers to things by id (item ids, mutation ids, creature kinds).

var host_type: StringName = &"colonist"
var host_name := ""
var start_year := 0
## -1 while the host is alive.
var death_year := -1
## Play time spent in this body.
var seconds_alive := 0.0
var death_position := Vector2.ZERO
## Creature kind that dealt the killing blow (e.g. &"gut_leech"), &"" if unknown.
var killed_by: StringName = &""
## Item ids in the pockets at death.
var carried_items: Array = []
## Body slot -> mutation id at death.
var carried_mutations: Dictionary = {}
## Creature kind -> how many this host killed.
var kills: Dictionary = {}
## Links into WorldData.events, once the history sim exists (phase 4).
var deed_event_ids: Array = []
## What became of the body: intact, looted, eaten, enshrined, studied (week 22+).
var corpse_state: StringName = &"intact"


func is_alive() -> bool:
	return death_year < 0


func to_dict() -> Dictionary:
	return {
		"host_type": host_type, "host_name": host_name,
		"start_year": start_year, "death_year": death_year, "seconds_alive": seconds_alive,
		"death_position": death_position, "killed_by": killed_by,
		"carried_items": carried_items.duplicate(), "carried_mutations": carried_mutations.duplicate(),
		"kills": kills.duplicate(), "deed_event_ids": deed_event_ids.duplicate(),
		"corpse_state": corpse_state,
	}


static func from_dict(d: Dictionary) -> LifeRecord:
	var life := LifeRecord.new()
	life.host_type = d.get("host_type", &"colonist")
	life.host_name = d.get("host_name", "")
	life.start_year = int(d.get("start_year", 0))
	life.death_year = int(d.get("death_year", -1))
	life.seconds_alive = float(d.get("seconds_alive", 0.0))
	life.death_position = d.get("death_position", Vector2.ZERO)
	life.killed_by = d.get("killed_by", &"")
	life.carried_items = d.get("carried_items", [])
	life.carried_mutations = d.get("carried_mutations", {})
	life.kills = d.get("kills", {})
	life.deed_event_ids = d.get("deed_event_ids", [])
	life.corpse_state = d.get("corpse_state", &"intact")
	return life

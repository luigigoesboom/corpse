class_name LifeRecord
extends RefCounted
## One host the player has had: who it was, when and how it lived and died,
## what it carried and did. Lives are kept forever in WorldData.lives; they are
## how the world remembers you (corpses, legends, rumors build on them).
## Plain data: refers to things by id (item ids, mutation ids, creature kinds).

var host_type: StringName = &"colonist"
var host_name := ""
## Name of the place this host woke (a SpawnPoint's place_name).
var origin := ""
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
## Host standing (week 31): faction id -> -100..100, how that faction feels
## about this body. Missing = the faction's attitude to this host type
## (WorldData.standing()). Fresh for every host; the fragment's legend is
## separate (week 32).
var standing: Dictionary = {}
var corpse_state: StringName = &"intact"
## Where the body lies (on the ground under where the host died).
var corpse_position := Vector2.ZERO
## What is still on the body. Starts as everything the host had; shrinks as
## a later host (or someone else) takes things.
var corpse_items: Array = []
var corpse_mutations: Dictionary = {}


func is_alive() -> bool:
	return death_year < 0


func to_dict() -> Dictionary:
	return {
		"host_type": host_type, "host_name": host_name, "origin": origin, "standing": standing.duplicate(),
		"start_year": start_year, "death_year": death_year, "seconds_alive": seconds_alive,
		"death_position": death_position, "killed_by": killed_by,
		"carried_items": carried_items.duplicate(), "carried_mutations": carried_mutations.duplicate(),
		"kills": kills.duplicate(), "deed_event_ids": deed_event_ids.duplicate(),
		"corpse_state": corpse_state, "corpse_position": corpse_position,
		"corpse_items": corpse_items.duplicate(), "corpse_mutations": corpse_mutations.duplicate(),
	}


static func from_dict(d: Dictionary) -> LifeRecord:
	var life := LifeRecord.new()
	life.host_type = d.get("host_type", &"colonist")
	life.standing = d.get("standing", {}).duplicate()
	life.host_name = d.get("host_name", "")
	life.origin = d.get("origin", "")
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
	life.corpse_position = d.get("corpse_position", life.death_position)
	life.corpse_items = d.get("corpse_items", [])
	life.corpse_mutations = d.get("corpse_mutations", {})
	return life


func has_corpse_loot() -> bool:
	return not corpse_items.is_empty() or not corpse_mutations.is_empty()

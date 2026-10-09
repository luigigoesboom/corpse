class_name EventRecord
extends RefCounted
## One thing that happened, kept forever in WorldData.events (append only).
## Text for murals, rumors and epitaphs is made from these when shown, never
## stored, so better writing later improves old saves too.
##
## Types so far: host_died, corpse_scavenged, corpse_rotted, creatures_returned.

var id: int
var year: int
var type: StringName
## Who was involved, by id or name (host names, creature kinds, faction ids later).
var actors: Array = []
## Type-specific details (e.g. {"items": [...]} for corpse_scavenged).
var data: Dictionary = {}


func to_dict() -> Dictionary:
	return {"id": id, "year": year, "type": type, "actors": actors.duplicate(), "data": data.duplicate(true)}


static func from_dict(d: Dictionary) -> EventRecord:
	var event := EventRecord.new()
	event.id = int(d.get("id", 0))
	event.year = int(d.get("year", 0))
	event.type = d.get("type", &"")
	event.actors = d.get("actors", [])
	event.data = d.get("data", {})
	return event

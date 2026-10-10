class_name ArtifactData
extends RefCounted
## A one-of-a-kind object that came out of history (week 29): a relic found,
## the last banner of a burned town, a prophet's staff. Plain data in
## WorldData.artifacts, keyed by `id`, which is also its item id (so it can
## lie on the ground, sit in a pocket or on a corpse like any item).
## Its name is stored (it is what people call it); its description is made
## from the events it came from when shown (ArtifactText).

var id: String
var name := ""
## &"relic", &"staff", &"banner", &"shield", &"lamp", &"bell", &"idol", &"stone", &"keepsake".
var kind: StringName = &"keepsake"
## The event it came from (EventRecord.id).
var event_id := -1
## The site it is tied to (SiteData.id).
var site_id := ""
## Who made or kept it (FactionData id).
var faction: StringName = &""
var color := Color.WHITE


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "kind": kind, "event_id": event_id, "site_id": site_id, "faction": faction, "color": color}


static func from_dict(d: Dictionary) -> ArtifactData:
	var artifact := ArtifactData.new()
	artifact.id = d.get("id", "")
	artifact.name = d.get("name", "")
	artifact.kind = d.get("kind", &"keepsake")
	artifact.event_id = int(d.get("event_id", -1))
	artifact.site_id = d.get("site_id", "")
	artifact.faction = d.get("faction", &"")
	artifact.color = d.get("color", Color.WHITE)
	return artifact

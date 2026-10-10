class_name ArtifactText
extends RefCounted
## An artifact's description, made when shown (like EventText): what it looks
## like, then the history behind it in the same words as the event log, so
## what you read on the thing matches what happened.

const LOOKS := {
	&"relic": "Wrapped in old cloth. It is still warm.",
	&"staff": "A staff of polished bone, notched all over with small names.",
	&"banner": "A scorched rag of a banner. The color is still theirs.",
	&"shield": "A plate of shoulder-bone, hacked and dented, strapped for an arm.",
	&"lamp": "A lamp of hollowed cartilage. Someone kept it filled for a long time.",
	&"bell": "A small bell cast from the god's mineral sweat. It no longer rings.",
	&"idol": "A crude figure of the god, worn smooth by hands.",
	&"stone": "A flat stone with a name scratched into it, and a year.",
	&"keepsake": "Old, handled, kept. Nobody throws a thing like this away.",
}


static func describe(artifact: ArtifactData, data: WorldData) -> String:
	var lines := PackedStringArray([LOOKS.get(artifact.kind, LOOKS[&"keepsake"])])
	var origin: EventRecord = null
	for event in data.events:
		if event.id == artifact.event_id:
			origin = event
			break
	if origin:
		lines.append("")
		lines.append(EventText.line(origin, data))
	var ending := ending_event(data, artifact.site_id)
	if ending and ending != origin:
		lines.append(EventText.line(ending, data))
	return "\n".join(lines)


## The event that ended a site (burned, abandoned, its people gone), or null.
static func ending_event(data: WorldData, site_id: String) -> EventRecord:
	var site: SiteData = data.sites.get(site_id)
	if site == null or site.ended_year < 0:
		return null
	for i in range(data.events.size() - 1, -1, -1):
		var event: EventRecord = data.events[i]
		if event.data.get("site", "") == site_id and event.type in [&"site_razed", &"site_abandoned", &"faction_fell"]:
			return event
	return null


## Item definitions for every artifact, for ItemDb (so artifacts work like items).
static func item_defs(data: WorldData) -> Dictionary:
	var defs := {}
	for artifact: ArtifactData in data.artifacts.values():
		var def := ItemDef.new()
		def.id = StringName(artifact.id)
		def.display_name = artifact.name.substr(0, 1).to_upper() + artifact.name.substr(1)
		def.description = describe(artifact, data)
		def.color = artifact.color
		defs[def.id] = def
	return defs

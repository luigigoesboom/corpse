class_name QuestData
extends RefCounted
## A task a people asked of the fragment (D-033). Plain data in
## WorldData.quests, keyed by `id`. Quests belong to the fragment, not the
## body: a new host can finish what an old one took on.

var id := ""
var kind: StringName   ## &"slay", &"relic", &"fetch", &"cull", &"deliver"
var giver: StringName  ## The faction that asked.
var site := ""         ## Their settlement (SiteData id), for the telling.
## What it is about: a beast id (slay), an item id (relic, fetch), a
## creature kind (cull), a faction id (deliver).
var target := ""
var count := 1
var progress := 0
var ichor := 0
var standing := 0
## The item given to carry (deliver), or "".
var item := ""
## &"active", &"done" (ready to turn in), &"rewarded", &"failed".
var state: StringName = &"active"
var year := 0


func is_open() -> bool:
	return state == &"active" or state == &"done"


func to_dict() -> Dictionary:
	return {"id": id, "kind": kind, "giver": giver, "site": site, "target": target, "count": count, "progress": progress,
		"ichor": ichor, "standing": standing, "item": item, "state": state, "year": year}


static func from_dict(d: Dictionary) -> QuestData:
	var q := QuestData.new()
	q.id = d.get("id", "")
	q.kind = d.get("kind", &"fetch")
	q.giver = d.get("giver", &"")
	q.site = d.get("site", "")
	q.target = d.get("target", "")
	q.count = int(d.get("count", 1))
	q.progress = int(d.get("progress", 0))
	q.ichor = int(d.get("ichor", 0))
	q.standing = int(d.get("standing", 0))
	q.item = d.get("item", "")
	q.state = d.get("state", &"active")
	q.year = int(d.get("year", 0))
	return q

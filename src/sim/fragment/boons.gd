class_name Boons
extends RefCounted
## What banked ichor buys (week 34, D-027): lasting gifts to the fragment,
## kept across every life. Owned boons are WorldData.boons (id -> true).
## Effects live where they apply (Game, WorldData.end_life, the HUD); this
## is the list.

const ALL := {
	&"sense_bodies": {"name": "Sense the old bodies", "cost": 15,
		"text": "Feel where your last body lies, whatever the distance."},
	&"hardy": {"name": "A sturdier host", "cost": 30,
		"text": "Every body you wear holds one more heart."},
	&"wider_choice": {"name": "More bodies to choose", "cost": 40,
		"text": "Wake with four hosts to choose from, not three."},
	&"lasting_graft": {"name": "A graft that stays", "cost": 60,
		"text": "When a host dies, one of its mutations follows you into the next."},
}
## In the order they are offered (cheapest first).
const ORDER := [&"sense_bodies", &"hardy", &"wider_choice", &"lasting_graft"]


static func cost(id: StringName) -> int:
	return int(ALL[id].cost) if ALL.has(id) else 0


static func display_name(id: StringName) -> String:
	return ALL[id].name if ALL.has(id) else String(id)

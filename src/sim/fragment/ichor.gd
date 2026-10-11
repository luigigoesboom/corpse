class_name Ichor
extends RefCounted
## Ichor (week 34, D-027): the god's dried blood, what each life is after.
## Creatures give it when a host kills them, more the deeper they lived.
## The host carries it (WorldData.ichor); at death it stays on the corpse;
## poured into a heart-root it is banked for good (WorldData.ichor_banked)
## and buys Boons.

## Creature kind -> ichor for killing one at the top of the world.
const CREATURE_VALUES := {
	&"gut_leech": 3,
	&"rot_fly": 2,
	&"bile_spitter": 4,
	&"gullet_matron": 60,
	&"puffsac": 3,
	&"cilia_lasher": 4,
	&"bellows_ray": 5,
}
## Each chunk row further down the body gives this much more (1.0 = +100%).
const DEPTH_BONUS := 0.25


## Ichor for killing a creature of `kind` at `position`.
static func for_kill(kind: StringName, position: Vector2) -> int:
	return roundi(CREATURE_VALUES.get(kind, 0) * depth_factor(position))


## 1.0 at the top chunk row, more below.
static func depth_factor(position: Vector2) -> float:
	return 1.0 + maxf(0.0, floorf(position.y / ChunkData.SIZE_PX)) * DEPTH_BONUS

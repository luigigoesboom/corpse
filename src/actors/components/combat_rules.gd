class_name CombatRules
extends RefCounted
## Game-wide combat switches, for comparing combat styles (roadmap week 19-20).

const PLAYER_ATTACKS := 16  # Physics layer 5.
const ENEMY_ATTACKS := 32   # Physics layer 6.

## When on, enemy attacks also hurt other enemies (spit, bites): the
## "systemic" style, where you can turn creatures against each other.
static var friendly_fire := false


## The physics layer a creature's attacks should be on right now.
static func enemy_attack_layer() -> int:
	return ENEMY_ATTACKS | (PLAYER_ATTACKS if friendly_fire else 0)

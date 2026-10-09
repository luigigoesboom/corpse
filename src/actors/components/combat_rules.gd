class_name CombatRules
extends RefCounted
## Game-wide combat switches, for comparing combat styles (roadmap week 19-20).

const PLAYER_ATTACKS := 16  # Physics layer 5.
const ENEMY_ATTACKS := 32   # Physics layer 6.

## On by default (D-018, the systemic style): enemy attacks also hurt other
## enemies (spit, bites), so you can turn creatures against each other.
const DEFAULT_FRIENDLY_FIRE := true

static var friendly_fire := DEFAULT_FRIENDLY_FIRE


## What kind of thing a node is, from the scene it was made from:
## res://src/actors/creatures/gut_leech.tscn -> &"gut_leech", the player -> &"player".
static func kind_of(node: Node) -> StringName:
	if node == null or node.scene_file_path == "":
		return &""
	return StringName(node.scene_file_path.get_file().get_basename())


## The physics layer a creature's attacks should be on right now.
static func enemy_attack_layer() -> int:
	return ENEMY_ATTACKS | (PLAYER_ATTACKS if friendly_fire else 0)

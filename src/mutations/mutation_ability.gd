class_name MutationAbility
extends Node
## Base for mutation abilities. MutationHost adds one as a node per mutation
## and removes it when the mutation is replaced or the world reloads.
##
## Abilities work on any "host": the player or a creature. A host is a
## CharacterBody2D that provides:
##   health: Health, run_speed: float, a "Visual" child node (flips with facing)
##   facing() -> float               1 = right, -1 = left
##   can_act() -> bool               alive and in control
##   socket(slot) -> Node2D          where the part sits ("mouth", "arm", ...)
##   ability_pressed(slot) -> bool   this frame: use the ability in this slot
##   ability_held(slot) -> bool      held down (for gliding)
##   attack_layer() -> int           physics layer for its attacks
## Optional: spit_velocity(from) -> Vector2 to aim projectiles (creatures).
## The player answers ability_pressed() from input, creatures from their AI.
##
## The host calls physics_tick() every physics frame, after its own movement
## and before move_and_slide(), so an ability can change host.velocity.
## Nodes an ability adds to the host must be removed in _exit_tree().

var host: CharacterBody2D
var def: MutationDef


func physics_tick(_delta: float) -> void:
	pass

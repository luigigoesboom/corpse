class_name MutationAbility
extends Node
## Base for mutation abilities. MutationHost adds one as a node per grafted
## mutation and removes it when the mutation is replaced or the world reloads.
##
## The player calls physics_tick() every physics frame, after its own movement
## and before move_and_slide(), so an ability can change player.velocity.
## Nodes an ability adds to the player must be removed in _exit_tree().

var player: Player
var def: MutationDef


func physics_tick(_delta: float) -> void:
	pass

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
## Its strain (D-033, MutationStrains): the player's come from
## WorldData.strains, creatures' are plain.
var strain: StringName = &"plain"
var _use_power := 1.0


func physics_tick(_delta: float) -> void:
	pass


## Cooldowns are multiplied by this.
func cooldown_scale() -> float:
	return MutationStrains.info(strain).get("cooldown", 1.0)


## Added to the damage it deals.
func damage_bonus() -> int:
	return MutationStrains.info(strain).get("damage", 0)


## Speeds, lifts and pushes are multiplied by this (rolled per use for a
## strange strain: call try_use() first).
func power() -> float:
	return _use_power


## Call when the ability is used. False if this use fails (a wild strain
## misfiring, a hungry one with no ichor to eat); a bleeding strain may
## cost the host a heart.
func try_use() -> bool:
	var info := MutationStrains.info(strain)
	_use_power = info.get("power", 1.0)
	if info.has("wild_power"):
		_use_power = randf_range(info.wild_power[0], info.wild_power[1])
	if randf() < info.get("misfire", 0.0):
		Sfx.play(&"squelch", host.global_position)
		return false
	var cost: int = info.get("ichor", 0)
	if cost > 0 and WorldState.data and host.is_in_group(&"player"):
		if WorldState.data.ichor < cost:
			EventBus.notify.emit("Your %s is hungry, and you have no ichor to feed it." % def.display_name)
			return false
		WorldState.data.add_ichor(-cost)
		EventBus.ichor_changed.emit()
	if randf() < info.get("bleed", 0.0) and host.health.current > 1:
		host.health.take_damage(1, host.global_position, 0.0, &"strain")
	return true

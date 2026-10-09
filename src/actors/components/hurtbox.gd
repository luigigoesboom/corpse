class_name Hurtbox
extends Area2D
## The part of a body that can be hit. Every physics frame it checks the
## Hitboxes it overlaps and passes damage to its Health.
##
## Checking every frame (instead of only on "area entered") means standing in
## an enemy keeps hurting you once your invulnerability runs out.

@export var health: Health


func _ready() -> void:
	monitorable = false


func _physics_process(_delta: float) -> void:
	if health == null or health.is_dead() or health.is_invulnerable():
		return
	for area in get_overlapping_areas():
		var hitbox := area as Hitbox
		if hitbox and hitbox.try_hit(self):
			if health.take_damage(hitbox.damage, hitbox.global_position, hitbox.knockback):
				EventBus.hit_landed.emit(get_parent(), hitbox.damage)
			return

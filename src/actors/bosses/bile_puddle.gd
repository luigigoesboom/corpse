extends Node2D
## Burning bile on the floor (boss volley): burns whatever steps in it, once
## each, for a few seconds, then dries up.

const LIFETIME := 2.5

var _age := 0.0


func _ready() -> void:
	$Hitbox.collision_layer = CombatRules.enemy_attack_layer()  # Its thrower set exclude before this.


## For anything that wants to avoid stepping in it.
func is_bile_puddle() -> bool:
	return true


func _process(delta: float) -> void:
	_age += delta
	modulate.a = clampf((LIFETIME - _age) / 0.6, 0.0, 1.0)
	if _age > LIFETIME:
		queue_free()

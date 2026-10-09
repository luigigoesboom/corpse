class_name Health
extends Node
## Hit points for anything that can be hurt. Add as a child, point a Hurtbox at it.

signal changed(current: int, max_value: int)
## `from` is where the hit came from (for knockback direction).
signal hurt(amount: int, from: Vector2, knockback: float)
signal died

@export var max_health := 3
## Seconds after a hit during which further hits are ignored.
@export var invulnerable_time := 0.0

var current := 0
## Set by abilities (e.g. a dash) to ignore hits for a while.
var invulnerable := false
var _invulnerable_timer := 0.0


func _ready() -> void:
	current = max_health


func _physics_process(delta: float) -> void:
	_invulnerable_timer -= delta


func is_invulnerable() -> bool:
	return invulnerable or _invulnerable_timer > 0.0


func is_dead() -> bool:
	return current <= 0


## Returns true if the hit landed.
func take_damage(amount: int, from: Vector2, knockback := 0.0) -> bool:
	if is_dead() or is_invulnerable():
		return false
	current = maxi(0, current - amount)
	_invulnerable_timer = invulnerable_time
	hurt.emit(amount, from, knockback)
	changed.emit(current, max_health)
	if current == 0:
		died.emit()
	return true


func set_current(value: int) -> void:
	current = clampi(value, 0, max_health)
	changed.emit(current, max_health)


func heal_full() -> void:
	set_current(max_health)

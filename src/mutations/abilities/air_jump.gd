extends MutationAbility
## Bellows Heart (belly, week 51): a second heart that is a bellows. Press
## jump in the air for one more jump, a puff of breath out of the ribs. It
## fills again on the ground, on a membrane, or clinging to a wall.

## The puff's upward speed (a normal jump is about 667).
const PUFF := 560.0
## A press this soon after leaving the ground is a normal (late) jump.
const GRACE := 0.12

var _charges := 1
var _air_time := 0.0


func physics_tick(delta: float) -> void:
	var grounded: bool = host.is_on_floor() or (host.has_method("is_clinging") and host.is_clinging())
	if grounded:
		_charges = 1
		_air_time = 0.0
		return
	_air_time += delta
	if _charges > 0 and _air_time > GRACE and host.can_act() and host.ability_pressed(def.slot):
		_charges -= 1
		if not try_use():
			return
		host.velocity.y = -PUFF * clampf(power(), 0.8, 1.25)
		Sfx.play(&"puff", host.global_position)
		var puff := GustPuff.new()
		puff.direction = Vector2.DOWN
		puff.position = host.global_position + Vector2(0, 10)
		host.get_parent().add_child(puff)


func charges() -> int:
	return _charges

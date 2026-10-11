extends Node2D
## Wind bones (week 48, moving since week 52): a string of small bones
## hanging from a ceiling. The breath swings them, and they click.

## How far they swing for a full wind (radians).
const SWING := 0.35

var _time := 0.0
var _clicked := false


func _process(delta: float) -> void:
	_time += delta
	var wind := Breath.wind_at(global_position)
	var push := clampf(wind.x / 900.0, -1.0, 1.0)
	var wobble := sin(_time * 2.3 + position.x) * 0.06 * (0.3 + absf(Breath.strength()))
	$Art.rotation = lerp_angle($Art.rotation, -push * SWING + wobble, minf(1.0, delta * 3.0))
	# They click once as the wind swings them hard.
	var hard := absf(push) > 0.6
	if hard and not _clicked:
		Sfx.play(&"bones_click", global_position)
	_clicked = hard

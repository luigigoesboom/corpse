class_name PropLayout
extends RefCounted
## Lays SettlementProp scenes out along a stretch of floor (settlements,
## ruins): the kit in a shuffled but repeatable order, repeated until the
## floor is full, spread evenly. Origins end up on the floor line (y = 0).


## Adds the props to `parent` (marked as built) and returns them.
static func lay_out(parent: Node2D, kit: Array, width: float, edge: float, rng: RandomNumberGenerator) -> Array[SettlementProp]:
	var chosen: Array[SettlementProp] = []
	if kit.is_empty():
		return chosen
	var order: Array = kit.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = order[i]
		order[i] = order[j]
		order[j] = swap
	var used := 0.0
	var i := 0
	while i < order.size() * 3:
		var prop: SettlementProp = order[i % order.size()].instantiate()
		if used + prop.width > width - 2.0 * edge:
			prop.free()
			break
		used += prop.width
		chosen.append(prop)
		i += 1
	var gap := (width - 2.0 * edge - used) / (chosen.size() + 1)
	var x := -width / 2.0 + edge + gap
	for prop in chosen:
		prop.position = Vector2(roundf(x + prop.width / 2.0), 0)
		prop.set_meta(&"built", true)
		parent.add_child(prop)
		x += prop.width + gap
	return chosen

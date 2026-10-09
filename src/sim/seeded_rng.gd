class_name SeededRng
extends RefCounted
## Deterministic random number generators.
##
## Generation code must get its randomness from here, never from the global
## randi()/randf(). The global RNG depends on what ran before, so a chunk would
## come out differently depending on which order you walked into things.


## Same world seed + same chunk = same sequence of numbers, every time.
static func for_chunk(world_seed: int, chunk: Vector2i) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, chunk.x, chunk.y])
	return rng


## A generator for anything repeatable: the same parts give the same numbers.
## E.g. SeededRng.make([world_seed, "host_name", index]).
static func make(parts: Array) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(parts)
	return rng

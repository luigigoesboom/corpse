class_name Names
extends RefCounted
## Generated names. Deterministic: the same world seed and index always give
## the same name, so a save never needs to store how a name was made.

const STARTS := ["Ash", "Bel", "Cor", "Dru", "Eth", "Gor", "Hul", "Isk", "Mav", "Nor",
	"Oss", "Pyr", "Ruk", "Sev", "Tor", "Ulm", "Vex", "Wen", "Yth", "Zar"]
const ENDS := ["a", "ek", "ith", "ul", "ora", "en", "isk", "um", "ae", "ol", "ix", "et"]


## Name for the player's `index`-th host in this world.
static func host_name(world_seed: int, index: int) -> String:
	var rng := SeededRng.make([world_seed, "host_name", index])
	return STARTS[rng.randi() % STARTS.size()] + ENDS[rng.randi() % ENDS.size()]

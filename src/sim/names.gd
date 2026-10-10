class_name Names
extends RefCounted
## Generated names. Deterministic: the same world seed and index always give
## the same name, so a save never needs to store how a name was made.

const STARTS := ["Ash", "Bel", "Cor", "Dru", "Eth", "Gor", "Hul", "Isk", "Mav", "Nor",
	"Oss", "Pyr", "Ruk", "Sev", "Tor", "Ulm", "Vex", "Wen", "Yth", "Zar"]
const ENDS := ["a", "ek", "ith", "ul", "ora", "en", "isk", "um", "ae", "ol", "ix", "et"]


const PLACE_STARTS := ["Bile", "Gall", "Marrow", "Sinew", "Mire", "Hollow", "Rot", "Vein",
	"Clot", "Ichor", "Lumen", "Fester", "Pulse", "Sallow", "Cyst", "Wick"]
const PLACE_ENDS := ["well", "rest", "hold", "reach", "fold", "mouth", "pit", "hearth",
	"cradle", "steps", "choir", "gate", "drift", "bloom"]


## Name for a place, e.g. "Bilewell". `key` is anything stable (a site id).
static func place_name(world_seed: int, key: String) -> String:
	var rng := SeededRng.make([world_seed, "place_name", key])
	return PLACE_STARTS[rng.randi() % PLACE_STARTS.size()] + PLACE_ENDS[rng.randi() % PLACE_ENDS.size()]


## Name for the `index`-th resident of a site.
static func resident_name(world_seed: int, site_id: String, index: int) -> String:
	var rng := SeededRng.make([world_seed, "resident", site_id, index])
	return STARTS[rng.randi() % STARTS.size()] + ENDS[rng.randi() % ENDS.size()]


## Name for the player's `index`-th host in this world.
static func host_name(world_seed: int, index: int) -> String:
	var rng := SeededRng.make([world_seed, "host_name", index])
	return STARTS[rng.randi() % STARTS.size()] + ENDS[rng.randi() % ENDS.size()]

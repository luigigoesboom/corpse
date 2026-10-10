class_name HistoryNames
extends RefCounted
## Names and temperaments for the peoples the history sim invents (D-025).
## All randomness comes from the generator passed in, so history is repeatable.

## archetype -> temperament ranges [min, max] and what their names sound like.
const ARCHETYPES := {
	&"farmers": {"aggression": [0.1, 0.4], "expansion": [0.3, 0.6], "piety": [0.1, 0.5], "trade": [0.5, 0.9],
		"nouns": ["Growers", "Herders", "Tillers", "Keepers"], "values": [&"tending", &"waste_not"]},
	&"diggers": {"aggression": [0.3, 0.6], "expansion": [0.4, 0.8], "piety": [0.1, 0.4], "trade": [0.4, 0.7],
		"nouns": ["Diggers", "Burrowers", "Carvers", "Delvers"], "values": [&"labor", &"the_deep"]},
	&"hunters": {"aggression": [0.6, 0.9], "expansion": [0.4, 0.7], "piety": [0.2, 0.5], "trade": [0.1, 0.4],
		"nouns": ["Brood", "Hunters", "Teeth", "Pack"], "values": [&"strength", &"the_hunt"]},
	&"cult": {"aggression": [0.3, 0.7], "expansion": [0.3, 0.6], "piety": [0.7, 1.0], "trade": [0.1, 0.4],
		"nouns": ["Covenant", "Mourners", "Listeners", "Kneelers"], "values": [&"devotion", &"omens"]},
	&"scavengers": {"aggression": [0.4, 0.7], "expansion": [0.6, 0.9], "piety": [0.1, 0.3], "trade": [0.5, 0.8],
		"nouns": ["Pickers", "Gleaners", "Rag-Kin", "Lantern-Bearers"], "values": [&"salvage", &"the_road"]},
}
const ADJECTIVES := ["Pale", "Hollow", "Bitter", "Silent", "Red", "Weeping", "Sunken", "Ninefold", "Low",
	"Last", "Grey", "Salt", "Blind", "Warm"]
const BODY_PLACES := ["Third Rib", "Long Vein", "Bile Sea", "Low Lung", "Quiet Heart", "Ninth Fold", "Warm Wall",
	"Split Tendon", "Old Scar"]


static func random_archetype(rng: RandomNumberGenerator) -> StringName:
	var keys := ARCHETYPES.keys()
	return keys[rng.randi() % keys.size()]


## Fills name, member name, color and temperament for an invented people.
static func make_people(faction: FactionData, archetype: StringName, rng: RandomNumberGenerator) -> void:
	var kind: Dictionary = ARCHETYPES[archetype]
	faction.archetype = archetype
	if rng.randf() < 0.25:
		var place: String = BODY_PLACES[rng.randi() % BODY_PLACES.size()]
		faction.display_name = "Children of the " + place
		faction.member_name = "a child of the " + place
	else:
		var adjective: String = ADJECTIVES[rng.randi() % ADJECTIVES.size()]
		var noun: String = kind.nouns[rng.randi() % kind.nouns.size()]
		faction.display_name = "the %s %s" % [adjective, noun]
		faction.member_name = ("one of the %s %s" % [adjective, noun]) if not noun.ends_with("s") else ("a %s %s" % [adjective, noun.trim_suffix("s")])
	faction.color = Color.from_hsv(rng.randf(), rng.randf_range(0.35, 0.6), rng.randf_range(0.6, 0.85))
	for temper in ["aggression", "expansion", "piety", "trade"]:
		faction.set(temper, snappedf(rng.randf_range(kind[temper][0], kind[temper][1]), 0.01))
	faction.values = kind.values.duplicate()


## A splinter group's name, from its parent's: "the True Pale Diggers".
static func make_splinter(faction: FactionData, parent: FactionData, rng: RandomNumberGenerator) -> void:
	var base := parent.display_name.trim_prefix("the ")
	var prefix: String = ["True", "Reformed", "Lesser", "Free", "Silent"][rng.randi() % 5]
	faction.display_name = "the %s %s" % [prefix, base]
	faction.member_name = "a %s splinter of %s" % [prefix.to_lower(), parent.display_name]
	faction.archetype = parent.archetype
	faction.color = parent.color.lightened(0.15).darkened(rng.randf_range(0.0, 0.3))
	for temper in ["aggression", "expansion", "piety", "trade"]:
		faction.set(temper, clampf(parent.get(temper) + rng.randf_range(-0.25, 0.25), 0.0, 1.0))
	faction.values = parent.values.duplicate()


## A leader or prophet's name.
static func person(rng: RandomNumberGenerator) -> String:
	return Names.STARTS[rng.randi() % Names.STARTS.size()] + Names.ENDS[rng.randi() % Names.ENDS.size()]


## A place's name, e.g. "Marrowhold".
static func place(rng: RandomNumberGenerator) -> String:
	return Names.PLACE_STARTS[rng.randi() % Names.PLACE_STARTS.size()] + Names.PLACE_ENDS[rng.randi() % Names.PLACE_ENDS.size()]

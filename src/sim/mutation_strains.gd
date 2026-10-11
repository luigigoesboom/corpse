class_name MutationStrains
extends RefCounted
## No two grafts grow alike (D-033): when a mutation takes root in a body
## slot it rolls a strain, kept in WorldData.strains (slot -> strain). The
## ability reads it (MutationAbility: cooldown_scale(), damage_bonus(),
## power(), try_use()). Most strains are plain; the rest trade something
## for something.

## weight: how often; cooldown: x; damage: +; power: x (speed, lift, push);
## misfire: chance a use fails; bleed: chance a use costs the host a heart;
## ichor: ichor each use costs (none, and it fails); wild_power: power
## rolled per use between the two.
const STRAINS := {
	&"plain": {"weight": 8, "text": ""},
	&"potent": {"weight": 3, "damage": 1, "power": 1.15, "text": "potent: it works harder"},
	&"quick": {"weight": 3, "cooldown": 0.65, "text": "quick: it recovers fast"},
	&"sluggish": {"weight": 2, "cooldown": 1.4, "damage": 1, "power": 1.1, "text": "sluggish: slow, but heavy"},
	&"wild": {"weight": 2, "power": 1.4, "damage": 1, "misfire": 0.15, "text": "wild: strong, but it sometimes fails you"},
	&"bleeding": {"weight": 1, "damage": 2, "bleed": 0.2, "text": "bleeding: it hits very hard, and sometimes it costs you"},
	&"hungry": {"weight": 1, "cooldown": 0.5, "ichor": 1, "text": "hungry: very fast, and it feeds on your ichor"},
	&"gentle": {"weight": 2, "power": 0.85, "cooldown": 0.8, "text": "gentle: weaker, but quicker"},
	&"strange": {"weight": 1, "wild_power": [0.6, 1.6], "text": "strange: never the same twice"},
}


## Whether grafts roll strains (tests turn it off: they count exact
## damage and speeds; a rolled strain would change them).
static var rolling := true


## Mutations that move the host rather than hit things: only strains that
## change how strongly they work.
const MOVEMENT := [&"lung_sac", &"bellows_heart"]
const MOVEMENT_STRAINS := [&"plain", &"potent", &"gentle", &"wild", &"strange"]


static func roll(rng: RandomNumberGenerator, mutation: StringName = &"") -> StringName:
	if not rolling:
		return &"plain"
	var pool: Array = MOVEMENT_STRAINS if mutation in MOVEMENT else STRAINS.keys()
	var total := 0
	for s in pool:
		total += STRAINS[s].weight
	var pick := rng.randi_range(1, total)
	for s in pool:
		pick -= STRAINS[s].weight
		if pick <= 0:
			return s
	return &"plain"


static func info(strain: StringName) -> Dictionary:
	return STRAINS.get(strain, STRAINS[&"plain"])


## "Acid Gland (wild)", or just the name for a plain strain.
static func label(mutation_name: String, strain: StringName) -> String:
	return mutation_name if strain == &"plain" or strain == &"" else "%s (%s)" % [mutation_name, strain]


## A sentence for when it grows: "It is a wild strain: strong, but it misfires."
static func grown_text(strain: StringName) -> String:
	var text: String = info(strain).text
	return "" if text == "" else "It is a %s." % text.replace(":", " strain:")

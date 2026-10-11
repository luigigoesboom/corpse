class_name Beasts
extends RefCounted
## Legendary beasts (D-033): named creatures that arise in lairs, raid the
## settlements of their region, grow old, get hunted and die. Plain data;
## the lairs are given by the world layer (BodyMap.context() "lairs":
## [{"slot", "name", "region", "kinds"}]).
##
## A new world gets the beasts of its recent past (seed_past(): when each
## arose, the raids since). Between lives (between_lives()) each year a
## living beast may raid, be hunted down by a warlike or hunting people, or
## die of age, and an empty lair may breed a new one.

## What traits do: hp (health x), scale (size x), speed (x), damage (+),
## sight (x), tint, raid (raids x), escape (chance to slip hunters), and
## words for epithets.
const TRAITS := {
	&"huge": {"hp": 2.0, "scale": 1.5, "damage": 1, "words": ["the Great", "the Swollen", "Mountain-Gut"]},
	&"swift": {"speed": 1.6, "words": ["Quickmouth", "the Darting", "Who Is Already There"]},
	&"armored": {"hp": 2.5, "tint": Color(0.85, 0.82, 0.7), "words": ["Bone-Hide", "the Shelled", "the Unbitten"]},
	&"venomous": {"damage": 1, "tint": Color(0.75, 1.0, 0.6), "words": ["the Bitter", "Greenmouth", "the Poisoner"]},
	&"ancient": {"hp": 1.6, "scale": 1.25, "tint": Color(0.8, 0.75, 0.75), "words": ["the Old", "Who Remembers the Fall", "Grandmother"]},
	&"hungry": {"raid": 2.0, "words": ["the Hungry", "the Gnawer", "Who Is Never Full"]},
	&"cunning": {"escape": 0.6, "sight": 1.5, "words": ["the Sly", "the Patient", "Who Waits"]},
	&"many_eyed": {"sight": 2.2, "tint": Color(1.0, 0.85, 0.85), "words": ["Many-Eyes", "the Watcher", "Who Sees"]},
	&"glowing": {"tint": Color(1.25, 1.15, 0.8), "words": ["the Lantern", "Bright-Belly", "the Shining"]},
}
## Kind words: "a <adjective> <kind>" when told.
const KIND_NAMES := {&"gut_leech": "gut leech", &"bile_spitter": "bile spitter", &"rot_fly": "rot fly",
	&"cilia_lasher": "cilia lasher", &"bellows_ray": "bellows ray", &"puffsac": "puffsac"}
const KIND_EPITHETS := {&"gut_leech": ["the Gnawer", "the Sucking Mouth", "the Long Leech"],
	&"bile_spitter": ["the Bile-Mother", "Who Spits Fire", "the Gall"],
	&"rot_fly": ["Lord of Flies", "the Buzzing", "the Carrion Prince"],
	&"cilia_lasher": ["the Lash", "Who Whips the Floor", "the Whip"],
	&"bellows_ray": ["the Gliding Death", "Wide-Wing", "Who Falls From Above"],
	&"puffsac": ["the Swollen", "the Bladder", "Who Bursts Twice"]}
const SYLLABLES := ["vr", "ask", "gul", "mor", "thra", "ug", "zek", "kre", "ox", "ul", "bra", "ghe", "ssk", "or", "ith", "nar", "dro", "ak", "um", "yx"]
const ARISE_CHANCE := 0.012   # Per empty lair per year.
const RAID_CHANCE := 0.06     # Per beast per year.
const HUNT_CHANCE := 0.012    # Per beast per year, scaled by the hunters.
const OLD_AGE := 180


## Gives a world the beasts of its recent past, once. `lairs` from BodyMap.
static func seed_past(data: WorldData, lairs: Array, rng: RandomNumberGenerator) -> void:
	if data.beasts_seeded:
		return
	data.beasts_seeded = true
	var now := data.year
	for lair in lairs:
		if rng.randf() > 0.7:
			continue
		var born := now - rng.randi_range(8, 220)
		var beast := _arise(data, lair, born, rng)
		# Its raids since, as history.
		var year := born
		while true:
			year += rng.randi_range(8, 60)
			if year >= now:
				break
			_raid(data, beast, rng, year)
	data.sort_events()


## `years` years of beasts between two lives. Returns the events logged.
static func between_lives(data: WorldData, lairs: Array, years: int, rng: RandomNumberGenerator) -> Array:
	var first := data.events.size()
	if not data.beasts_seeded:
		seed_past(data, lairs, rng)
		first = data.events.size()
	var start := data.year - years
	for i in years:
		var year := start + i + 1
		for beast: BeastData in data.beasts.values():
			if not beast.is_alive():
				continue
			if rng.randf() < RAID_CHANCE * _trait(beast, "raid", 1.0):
				_raid(data, beast, rng, year)
			if not beast.is_alive():
				continue
			var hunter := _hunter(data, beast.region, rng)
			if hunter != null and rng.randf() < HUNT_CHANCE * (hunter.strength / 250.0) * (1.0 + hunter.aggression):
				if rng.randf() < _trait(beast, "escape", 0.0):
					data.log_event(&"beast_escaped", [hunter.id], {"beast": beast.id}, year)
				else:
					_die(data, beast, String(hunter.id), year)
					data.log_event(&"beast_slain", [hunter.id], {"beast": beast.id}, year)
			elif year - beast.born_year > OLD_AGE and rng.randf() < 0.03:
				_die(data, beast, "age", year)
				data.log_event(&"beast_died", [], {"beast": beast.id}, year)
		for lair in lairs:
			if living_in(data, lair.slot) == null and rng.randf() < ARISE_CHANCE:
				_arise(data, lair, year, rng)
	var logged := data.events.slice(first)
	data.sort_events()
	return logged


## The living beast in a lair, or null.
static func living_in(data: WorldData, slot: String) -> BeastData:
	for beast: BeastData in data.beasts.values():
		if beast.lair == slot and beast.is_alive():
			return beast
	return null


## A host killed it (the game calls this): a famous deed. Returns the event.
static func slain_by_host(data: WorldData, beast: BeastData, host_name: String) -> EventRecord:
	_die(data, beast, host_name, data.year)
	return data.log_deed(&"beast_slain_by_host", [host_name], {"beast": beast.id})


## What is cut from a beast: the trophy (an artifact: an item that never
## rots, wanted by traders, its description its story).
const TROPHY_PARTS := {&"gut_leech": "jaw", &"bile_spitter": "bile-sac", &"rot_fly": "wing", &"cilia_lasher": "cilium",
	&"bellows_ray": "wing-fin", &"puffsac": "bladder"}


static func trophy(data: WorldData, beast: BeastData, event: EventRecord) -> ArtifactData:
	var artifact := ArtifactData.new()
	artifact.id = "artifact_%d" % data.new_id()
	artifact.name = "the %s of %s" % [TROPHY_PARTS.get(beast.kind, "head"), beast.full_name()]
	artifact.kind = &"trophy"
	artifact.event_id = event.id if event else -1
	artifact.color = tint(beast)
	data.artifacts[artifact.id] = artifact
	return artifact


## The peoples a beast has raided (faction ids).
static func raided(data: WorldData, beast: BeastData) -> Array:
	var out := []
	for event in data.events:
		if event.type == &"beast_raided" and event.data.get("beast") == beast.id and not event.actors.is_empty():
			var f: StringName = StringName(str(event.actors[0]))
			if not f in out and data.factions.has(f):
				out.append(f)
	return out


## What a trait gives: TRAITS[t][key] multiplied (or added, for damage) over
## the beast's traits, starting from `base`.
static func _trait(beast: BeastData, key: String, base: float) -> float:
	var out := base
	for t in beast.traits:
		var info: Dictionary = TRAITS.get(t, {})
		if info.has(key):
			out = out + float(info[key]) if key in ["damage", "escape"] else out * float(info[key])
	return out


static func stat(beast: BeastData, key: String, base: float) -> float:
	return _trait(beast, key, base)


static func tint(beast: BeastData) -> Color:
	var c := Color.WHITE
	for t in beast.traits:
		c *= TRAITS.get(t, {}).get("tint", Color.WHITE)
	return c


## "a huge, venomous gut leech"
static func describe(beast: BeastData) -> String:
	var adjectives := PackedStringArray(beast.traits.map(func(t): return String(t).replace("_", "-")))
	return "a %s %s" % [", ".join(adjectives), KIND_NAMES.get(beast.kind, String(beast.kind))]


static func _arise(data: WorldData, lair: Dictionary, year: int, rng: RandomNumberGenerator) -> BeastData:
	var beast := BeastData.new()
	beast.id = "beast_%d" % data.new_id()
	var kinds: Array = lair.get("kinds", [])
	beast.kind = kinds[rng.randi() % kinds.size()] if not kinds.is_empty() else &"gut_leech"
	beast.region = lair.get("region", Regions.GUT)
	beast.lair = lair.slot
	beast.born_year = year
	var keys := TRAITS.keys()
	while beast.traits.size() < 2:
		var t: StringName = keys[rng.randi() % keys.size()]
		if not t in beast.traits:
			beast.traits.append(t)
	beast.name = _name(rng)
	var words: Array = []
	words.append_array(KIND_EPITHETS.get(beast.kind, ["the Beast"]))
	for t in beast.traits:
		words.append_array(TRAITS[t].words)
	beast.epithet = words[rng.randi() % words.size()]
	data.beasts[beast.id] = beast
	data.log_event(&"beast_arose", [], {"beast": beast.id, "place": lair.get("name", "a dark fold")}, year)
	return beast


## It comes out and kills people of a settlement of its region.
static func _raid(data: WorldData, beast: BeastData, rng: RandomNumberGenerator, year: int) -> void:
	var targets := data.sites.values().filter(func(s): return s.is_lived_in() and s.region == beast.region)
	if targets.is_empty():
		return
	var site: SiteData = targets[rng.randi() % targets.size()]
	var dead := mini(site.population - 10, rng.randi_range(2, 9) * int(_trait(beast, "hp", 1.0)))
	if dead <= 0:
		return
	site.population -= dead
	beast.kills += dead
	var faction: FactionData = data.factions.get(site.faction)
	if faction:
		faction.strength = maxi(0, faction.strength - dead)
	data.log_event(&"beast_raided", [site.faction], {"beast": beast.id, "site": site.id, "dead": dead}, year)


## Someone who would hunt it: the people of its region who are most warlike
## (or hunters by trade), or null if nobody lives there.
static func _hunter(data: WorldData, region: StringName, rng: RandomNumberGenerator) -> FactionData:
	var best: FactionData = null
	for f: FactionData in data.factions.values():
		if not f.is_alive() or f.region != region:
			continue
		var score := f.aggression + (0.5 if f.archetype == &"hunters" else 0.0) + rng.randf() * 0.3
		if best == null or score > best.aggression + (0.5 if best.archetype == &"hunters" else 0.0):
			best = f
	return best


static func _die(_data: WorldData, beast: BeastData, by: String, year: int) -> void:
	beast.died_year = year
	beast.slain_by = by


static func _name(rng: RandomNumberGenerator) -> String:
	var n := ""
	for i in rng.randi_range(2, 3):
		n += SYLLABLES[rng.randi() % SYLLABLES.size()]
	return n.substr(0, 1).to_upper() + n.substr(1)

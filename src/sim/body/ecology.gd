class_name Ecology
extends RefCounted
## Creatures as populations (D-033): how many of each kind live in each
## region, WorldData.fauna (region -> kind -> count, of at most CAP). Plain data.
##
## Year by year (between lives): each kind breeds toward its cap (rot flies'
## cap grows with the rot of the region), the region's hunting peoples thin
## it, and:
##   - a kind past SWARM swarms: it falls on a settlement (kind_swarmed) and,
##     in play, more of it turn up around the host (Swarms);
##   - a kind under GONE has vanished from the region (kind_vanished): what
##     the host killed of it does not come back; now and then a few wander
##     back in (kind_returned).
## The host's kills thin it (on_kill(), Game). Between lives, a killed
## creature comes back with a chance that follows its kind's numbers
## (return_chance(), Aftermath).

const KINDS := {&"gut": [&"gut_leech", &"bile_spitter", &"rot_fly"], &"lungs": [&"cilia_lasher", &"bellows_ray", &"puffsac"]}
const CAP := 100
const GROWTH := 0.18
const SWARM := 0.92
const GONE := 0.04
const NAMES := {&"gut_leech": "gut leeches", &"bile_spitter": "bile spitters", &"rot_fly": "rot flies",
	&"cilia_lasher": "cilia lashers", &"bellows_ray": "bellows rays", &"puffsac": "puffsacs"}


static func ensure(data: WorldData) -> void:
	for region in KINDS:
		var kinds: Dictionary = data.fauna.get_or_add(String(region), {})
		for kind in KINDS[region]:
			if not kinds.has(String(kind)):
				kinds[String(kind)] = int(CAP * 0.6)


static func count(data: WorldData, region: StringName, kind: StringName) -> int:
	return int(data.fauna.get(String(region), {}).get(String(kind), CAP / 2))


static func region_of_kind(kind: StringName) -> StringName:
	for region in KINDS:
		if kind in KINDS[region]:
			return region
	return &""


## How likely a killed creature of this kind is to come back (0..1).
static func return_chance(data: WorldData, kind: StringName) -> float:
	var region := region_of_kind(kind)
	if region == &"" or not data.fauna.has(String(region)):
		return 1.0  # Not counted (a world without numbers yet): as before.
	var n := count(data, region, kind)
	if n < CAP * GONE:
		return 0.0
	return clampf(n / float(CAP) * 1.3, 0.0, 1.0)


## The host killed one.
static func on_kill(data: WorldData, kind: StringName) -> void:
	var region := region_of_kind(kind)
	if region == &"":
		return
	ensure(data)
	data.fauna[String(region)][String(kind)] = maxi(0, count(data, region, kind) - 2)


## Kinds swarming in a region now (for Swarms).
static func swarming(data: WorldData, region: StringName) -> Array:
	return KINDS.get(region, []).filter(func(k): return count(data, region, k) >= CAP * SWARM)


## `years` of breeding, hunting, swarming and vanishing. Returns the events.
static func run(data: WorldData, years: int, rng: RandomNumberGenerator, rot_by_region: Dictionary = {}) -> Array:
	ensure(data)
	var first := data.events.size()
	var start := data.year - years
	for i in clampi(years, 1, 60):
		var year := start + i + 1 if years > 0 else data.year
		for region in KINDS:
			var hunters := 0.0
			for f: FactionData in data.factions.values():
				if f.is_alive() and f.region == region:
					hunters += f.strength / 1000.0 * (f.aggression + (0.6 if f.archetype == &"hunters" else 0.0))
			for kind in KINDS[region]:
				var n := float(count(data, region, kind))
				var cap := float(CAP)
				if kind == &"rot_fly":
					cap *= 0.7 + 1.6 * float(rot_by_region.get(region, 0.0))
				var was_gone := n < CAP * GONE
				if was_gone:
					if rng.randf() < 0.05:
						n = CAP * 0.15
						data.log_event(&"kind_returned", [], {"kind": kind, "region": region}, year)
				else:
					n += GROWTH * n * (1.0 - n / cap) + rng.randf_range(-3.0, 3.0)
					n -= hunters * rng.randf_range(0.5, 2.0)
				n = clampf(n, 0.0, CAP)
				if not was_gone and n < CAP * GONE:
					data.log_event(&"kind_vanished", [], {"kind": kind, "region": region}, year)
				elif n >= CAP * SWARM and rng.randf() < 0.08:
					var sites := data.sites.values().filter(func(s): return s.is_lived_in() and s.region == region)
					if not sites.is_empty():
						var site: SiteData = sites[rng.randi() % sites.size()]
						var dead := mini(site.population - 10, rng.randi_range(3, 12))
						if dead > 0:
							site.population -= dead
							data.log_event(&"kind_swarmed", [site.faction], {"kind": kind, "region": region, "site": site.id, "dead": dead}, year)
					n *= 0.8  # A swarm burns itself out a little.
				data.fauna[String(region)][String(kind)] = roundi(n)
	var logged := data.events.slice(first)
	data.sort_events()
	return logged

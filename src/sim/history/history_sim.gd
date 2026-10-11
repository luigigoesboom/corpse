class_name HistorySim
extends RefCounted
## The body's past, simulated year by year when a world is created (D-025,
## week 28). Plain data in, plain data out: factions (WorldData.factions),
## sites (WorldData.sites) and the event log (WorldData.events). Text is made
## from the events when shown (EventText), never stored.
##
## Peoples arrive, found settlements, grow, trade, go to war, split in
## schisms, suffer floods and plagues, and die out. Each region (Regions,
## D-030) has a past of its own: its peoples only meet each other, and its
## own seeded generator drives it, so the same world seed always gives the
## same history and adding a region never changes another's story. The
## years of all regions run side by side, so the log stays in order.
##
## The hand-made factions are destined (DESTINED): in the Gut the
## Flesh-Tenders are among the early peoples and the Choir of Waking is born
## as a prophet's schism mid-history; none of them can vanish before the
## present. The Lungs (week 50) have the Bellows-Kin, gliders who arrive early.

const YEARS := 2000
## Between lives (week 37): hand-made places (sites in a slot) cannot be
## taken, razed or abandoned, so the places the player knows stay; their
## people, numbers, wars and neighbours still change.
static var protect_slots := false
const TENDERS := &"flesh_tenders"
const CHOIR := &"choir_of_waking"
const KIN := &"bellows_kin"
## The hand-made factions of each region and how they come to be:
##   early   founded in years `from`..`to` of the past, like any people
##   schism  born in years `from`..`to` as a prophet's split (`cause`) from
##           the most devout people of the day, or from pilgrims
const DESTINED := {
	&"gut": [
		{"id": TENDERS, "how": "early", "from": 5, "to": 220},
		{"id": CHOIR, "how": "schism", "from": 700, "to": 1500, "cause": "over whether the god only sleeps"},
	],
	&"lungs": [
		{"id": KIN, "how": "early", "from": 40, "to": 400},
	],
}
## The region being simulated: _alive(), _living_sites() and new peoples
## and sites belong to it.
static var region: StringName = Regions.GUT
## A settlement this big gets crowded and sends settlers off.
const SITE_CAPACITY := 360
const MAX_SITES_PER_FACTION := 6
const MAX_LIVING_FACTIONS := 7
## A destined faction's last settlement never drops below this.
const DESTINED_FLOOR := 20
## A destined faction this small in the present gets pilgrims (an event).
const DESTINED_PRESENT_MIN := 80
## How many people a region can feed is its Regions "capacity" (the Gut:
## 2600). The fuller it gets, the slower everyone grows and the more readily
## neighbours turn on each other. Where newcomers come from and what is
## traded are per region too.
const WAR_CAUSES := ["the bile cisterns of %s", "an old insult", "the warm wall near %s", "a stolen relic",
	"grazing rights on the lining", "who may bury their dead at %s", "a prophecy about %s", "a murdered envoy"]
const SCHISM_CAUSES := ["over whether the god only sleeps", "over the right way to bury the dead",
	"over a vision seen in a spasm", "over who should lead after the flood", "over eating the god's flesh"]
const DISASTERS := [&"bile_flood", &"rot_plague", &"spasm", &"famine"]


## Runs YEARS (or `years`) of history ending at data.year, in every region
## whose past is simulated (Regions INFO "history"). Expects a world without
## peoples in those regions; afterwards data.year is unchanged.
static func run(data: WorldData, years := YEARS) -> void:
	run_regions(data, Regions.IDS.filter(func(r): return Regions.info(r).history), years)


## Regions whose past is simulated but that have no peoples in this world
## yet: all of them for a new world, a new region for an old save.
static func regions_without_past(data: WorldData) -> Array:
	return Regions.IDS.filter(func(r): return Regions.info(r).history \
		and not data.factions.values().any(func(f): return f.region == r))


## Runs the past of some regions only (also for an old world that gains a
## region it did not have: its events are then sorted in among the others).
static func run_regions(data: WorldData, regions: Array, years := YEARS) -> void:
	var had_events := not data.events.is_empty()
	var now := data.year
	var start := now - years
	var plans := {}  # region -> {rng, founding: {year: [DESTINED entries]}}
	for r in regions:
		# The Gut's generator is the one history always had, so old seeds
		# keep their past word for word.
		var rng := SeededRng.make([data.world_seed, "history"] if r == Regions.GUT else [data.world_seed, "history", r])
		var founding := {}
		for entry in DESTINED.get(r, []):
			founding.get_or_add(start + rng.randi_range(entry.from, entry.to), []).append(entry)
		plans[r] = {"rng": rng, "founding": founding}
	data.year = start
	for year in years:
		data.year += 1
		for r in plans:
			region = r
			var rng: RandomNumberGenerator = plans[r].rng
			if year == 0:
				for i in rng.randi_range(2, 3):
					_arrive(data, rng)
			for entry in plans[r].founding.get(data.year, []):
				_found_destined(data, rng, entry)
			tick(data, rng)
	data.year = now
	for r in plans:
		region = r
		_into_the_present(data, plans[r].rng)
	region = Regions.GUT
	if had_events:
		data.sort_events()


## History between two lives (week 37): `years` more years of the same
## yearly simulation in every region with people, ending at data.year, with
## hand-made places protected. The Gut uses `rng`, other regions their own
## generator for this gap. Returns the events it logged.
static func between_lives(data: WorldData, years: int, rng: RandomNumberGenerator) -> Array:
	var first := data.events.size()
	var now := data.year
	var rngs := {}
	for r in Regions.IDS:
		if Regions.info(r).history and data.factions.values().any(func(f): return f.region == r):
			rngs[r] = rng if r == Regions.GUT else SeededRng.make([data.world_seed, "between", r, now, data.lives.size()])
	data.year = now - years
	protect_slots = true
	for i in years:
		data.year += 1
		for r in rngs:
			region = r
			tick(data, rngs[r])
	protect_slots = false
	region = Regions.GUT
	data.year = now
	return data.events.slice(first)


## One year for every living faction and settlement.
static func tick(data: WorldData, rng: RandomNumberGenerator) -> void:
	var pressure := _pressure(data)
	for faction in _alive(data):
		_grow(data, faction, rng, pressure)
	for faction in _alive(data):
		_act(data, faction, rng)
	_relations(data, rng, pressure)
	_battles(data, rng)
	_disasters(data, rng)
	if _alive(data).size() < 4 and rng.randf() < (0.05 if _alive(data).size() < 2 else 0.006):
		_arrive(data, rng)
	_falls(data)


# --- Peoples ---------------------------------------------------------------

static func _arrive(data: WorldData, rng: RandomNumberGenerator) -> FactionData:
	var faction := FactionData.new()
	faction.id = StringName("people_%d" % data.new_id())
	faction.region = region
	HistoryNames.make_people(faction, HistoryNames.random_archetype(rng), rng)
	faction.founded_year = data.year
	data.factions[faction.id] = faction
	var site := _new_site(data, faction, rng.randi_range(40, 90), rng)
	var from: Array = Regions.info(region).from
	data.log_event(&"people_arrived", [faction.id], {"site": site.id, "from": from[rng.randi() % from.size()]})
	_update_strength(data, faction)
	return faction


## A destined faction comes to be (a DESTINED entry).
static func _found_destined(data: WorldData, rng: RandomNumberGenerator, entry: Dictionary) -> void:
	if entry.how == "schism":
		_found_by_schism(data, rng, entry.id, entry.cause)
	else:
		_found_early(data, rng, entry.id)


static func _found_early(data: WorldData, rng: RandomNumberGenerator, id: StringName) -> void:
	var faction := FactionData.from_def(FactionDb.get_def(id), data.year)
	faction.relations.clear()
	data.factions[faction.id] = faction
	var site := _new_site(data, faction, rng.randi_range(50, 80), rng)
	data.log_event(&"faction_founded", [faction.id], {"site": site.id, "founder": HistoryNames.person(rng)})
	_update_strength(data, faction)


## Born from the most devout people of the day, or, if there is nobody
## devout enough, from pilgrims who heard the heart (the Choir).
static func _found_by_schism(data: WorldData, rng: RandomNumberGenerator, id: StringName, cause: String) -> void:
	var parent: FactionData = null
	for faction in _alive(data):
		if not _sites_of(data, faction.id).is_empty() and (parent == null or faction.piety * faction.strength > parent.piety * parent.strength):
			parent = faction
	var born := FactionData.from_def(FactionDb.get_def(id), data.year)
	born.relations.clear()
	data.factions[born.id] = born
	var prophet := HistoryNames.person(rng)
	if parent == null:
		var site := _new_site(data, born, rng.randi_range(40, 70), rng)
		data.log_event(&"faction_founded", [born.id], {"site": site.id, "founder": prophet, "pilgrims": true})
	else:
		born.parent = parent.id
		var site := _split_off(data, parent, born, rng)
		data.set_relation(parent.id, born.id, -60)
		data.log_event(&"schism", [born.id, parent.id], {"site": site.id, "prophet": prophet, "cause": cause})
	_update_strength(data, born)


# --- Each year ---------------------------------------------------------------

static func _grow(data: WorldData, faction: FactionData, rng: RandomNumberGenerator, pressure: float) -> void:
	var rate := (0.004 + 0.008 * faction.expansion) * (1.0 - pressure) - 0.004 * faction.wars.size() + rng.randf_range(-0.003, 0.003)
	if faction.defined:
		rate += 0.003  # Destined: they are still here in the present.
	var own := _sites_of(data, faction.id)
	var sites := own.size()
	for site in own:
		var crowding: float = 1.0 - site.population / float(SITE_CAPACITY)
		site.population = maxi(1, site.population + _round(site.population * rate * maxf(crowding, 0.0), rng))
		if site.population > SITE_CAPACITY * 0.75 and sites < MAX_SITES_PER_FACTION and pressure < 0.9 and rng.randf() < 0.01 + 0.04 * faction.expansion:
			sites += 1
			var settlers := int(site.population * rng.randf_range(0.25, 0.4))
			site.population -= settlers
			var new_site := _new_site(data, faction, settlers, rng)
			data.log_event(&"site_founded", [faction.id], {"site": new_site.id, "from_site": site.id})
	_update_strength(data, faction)


static func _act(data: WorldData, faction: FactionData, rng: RandomNumberGenerator) -> void:
	var sites := _sites_of(data, faction.id)
	if sites.is_empty():
		return
	# Schism: big factions split, the devout ones more readily.
	if faction.strength > 350 and sites.size() >= 2 and _alive(data).size() < MAX_LIVING_FACTIONS \
			and rng.randf() < 0.0012 * (0.5 + faction.piety):
		var splinter := FactionData.new()
		splinter.id = StringName("people_%d" % data.new_id())
		HistoryNames.make_splinter(splinter, faction, rng)
		splinter.parent = faction.id
		splinter.region = faction.region
		splinter.founded_year = data.year
		data.factions[splinter.id] = splinter
		var site := _split_off(data, faction, splinter, rng)
		data.set_relation(faction.id, splinter.id, -60)
		data.log_event(&"schism", [splinter.id, faction.id], {"site": site.id, "prophet": HistoryNames.person(rng),
			"cause": SCHISM_CAUSES[rng.randi() % SCHISM_CAUSES.size()]})
		_update_strength(data, faction)
		_update_strength(data, splinter)
		return
	# Wonders: something worth remembering.
	if rng.randf() < 0.0012:
		var site: SiteData = sites[rng.randi() % sites.size()]
		site.population += int(site.population * 0.1)
		data.log_event(&"wonder", [faction.id], {"site": site.id, "kind": _wonder_kind(faction, rng), "person": HistoryNames.person(rng)})
	elif faction.piety > 0.65 and rng.randf() < 0.002:
		data.log_event(&"prophet", [faction.id], {"person": HistoryNames.person(rng), "saying": rng.randi() % 6})


static func _relations(data: WorldData, rng: RandomNumberGenerator, pressure: float) -> void:
	var alive := _alive(data)
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var a: FactionData = alive[i]
			var b: FactionData = alive[j]
			var current := data.relation(a.id, b.id)
			var shared := 0
			for value in a.values:
				if value in b.values:
					shared += 1
			var target := 15 * shared - int(40.0 * absf(a.piety - b.piety)) - int(25.0 * maxf(a.aggression, b.aggression)) - int(50.0 * pressure)
			current += signi(target - current) + rng.randi_range(-2, 2)
			data.set_relation(a.id, b.id, current)
			if b.id in a.wars:
				if rng.randf() < 0.05:
					_end_war(data, a, b)
					data.set_relation(a.id, b.id, -10)
					data.log_event(&"peace", [a.id, b.id], {})
			elif current < -40 and rng.randf() < 0.02 * maxf(a.aggression, b.aggression) * (0.5 + pressure) * _war_appetite(data, a, b):
				a.trade_partners.erase(b.id)
				b.trade_partners.erase(a.id)
				a.wars.append(b.id)
				b.wars.append(a.id)
				var their_sites := _sites_of(data, b.id)
				var place: String = their_sites[0].name if not their_sites.is_empty() else "the lining"
				var cause: String = WAR_CAUSES[rng.randi() % WAR_CAUSES.size()]
				data.log_event(&"war_declared", [a.id, b.id], {"cause": cause % place if "%s" in cause else cause})
			elif current > 15 and not b.id in a.trade_partners and rng.randf() < 0.004 * (a.trade + b.trade):
				a.trade_partners.append(b.id)
				b.trade_partners.append(a.id)
				data.set_relation(a.id, b.id, current + 20)
				var goods: Array = Regions.info(region).goods
				data.log_event(&"trade_pact", [a.id, b.id], {"goods": goods[rng.randi() % goods.size()]})


static func _battles(data: WorldData, rng: RandomNumberGenerator) -> void:
	var alive := _alive(data)
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var a: FactionData = alive[i]
			var b: FactionData = alive[j]
			if not b.id in a.wars or rng.randf() > 0.15:
				continue
			var attacker := a if rng.randf() < a.aggression / maxf(0.01, a.aggression + b.aggression) else b
			var defender := b if attacker == a else a
			var targets := _sites_of(data, defender.id)
			var homes := _sites_of(data, attacker.id)
			if targets.is_empty() or homes.is_empty():
				continue
			var site: SiteData = targets[rng.randi() % targets.size()]
			var attack := attacker.strength * (0.5 + attacker.aggression) * rng.randf_range(0.6, 1.4)
			var defense := site.population * 1.5 + defender.strength * 0.3
			var home: SiteData = homes[0]
			for h in homes:
				if h.population > home.population:
					home = h
			var last_stand := (defender.defined and targets.size() == 1) or (protect_slots and site.slot != "")
			if attack > defense and not last_stand:
				var dead := int(site.population * rng.randf_range(0.3, 0.6))
				home.population = maxi(5, home.population - int(home.population * rng.randf_range(0.05, 0.15)))
				if homes.size() < MAX_SITES_PER_FACTION and rng.randf() < 0.4 + 0.4 * attacker.expansion:
					site.population -= dead
					site.faction = attacker.id
					data.log_event(&"site_taken", [attacker.id, defender.id], {"site": site.id, "dead": dead})
				else:
					var everyone := site.population
					_end_site(data, site)
					data.log_event(&"site_razed", [attacker.id, defender.id], {"site": site.id, "dead": everyone})
			else:
				var lost := int(home.population * rng.randf_range(0.1, 0.25))
				home.population = maxi(5, home.population - lost)
				var dead := int(site.population * rng.randf_range(0.05, 0.2))
				site.population = maxi(DESTINED_FLOOR if defender.defined else 1, site.population - dead)
				# Only bloody failures are remembered; skirmishes are not history.
				var kind := &"last_stand" if last_stand and attack > defense else &"raid_repelled"
				if dead + lost >= (25 if kind == &"last_stand" else 30) and not _told_lately(data, kind, attacker.id, site.id, 30):
					data.log_event(kind, [attacker.id, defender.id], {"site": site.id, "dead": dead + lost})
			_update_strength(data, attacker)
			_update_strength(data, defender)


static func _disasters(data: WorldData, rng: RandomNumberGenerator) -> void:
	for site in _living_sites(data):
		if rng.randf() > 0.001:
			continue
		var kind: StringName = DISASTERS[rng.randi() % DISASTERS.size()]
		var dead := int(site.population * rng.randf_range(0.25, 0.6))
		var owner: FactionData = data.factions[site.faction]
		var protected: bool = (owner.defined and _sites_of(data, owner.id).size() == 1) or (protect_slots and site.slot != "")
		site.population -= dead
		if protected:
			site.population = maxi(DESTINED_FLOOR, site.population)
		data.log_event(&"disaster", [site.faction], {"site": site.id, "kind": kind, "dead": dead})
		if site.population < 8 and not protected:
			_end_site(data, site)
			data.log_event(&"site_abandoned", [owner.id], {"site": site.id})
		_update_strength(data, owner)


static func _falls(data: WorldData) -> void:
	for faction: FactionData in data.factions.values():
		if faction.fell_year >= 0 or faction.region != region:
			continue
		_update_strength(data, faction)
		if faction.strength >= 12 and not _sites_of(data, faction.id).is_empty():
			continue
		if faction.defined:
			continue  # Destined: protected elsewhere, never falls.
		if protect_slots and _sites_of(data, faction.id).any(func(s): return s.slot != ""):
			continue  # Between lives: a people the player can visit does not vanish.
		var last := ""
		for site in _sites_of(data, faction.id):
			last = site.id
			_end_site(data, site)
		for other in data.factions.values():
			if faction.id in other.wars:
				_end_war(data, faction, other)
		faction.strength = 0
		faction.fell_year = data.year
		data.log_event(&"faction_fell", [faction.id], {"site": last})


## The present: destined factions alive with a home, nobody left at war
## with the dead.
static func _into_the_present(data: WorldData, rng: RandomNumberGenerator) -> void:
	for entry in DESTINED.get(region, []):
		var id: StringName = entry.id
		if not data.factions.has(id):
			_found_destined(data, rng, entry)
		var faction: FactionData = data.factions[id]
		if _sites_of(data, id).is_empty():
			var site := _new_site(data, faction, 40, rng)
			data.log_event(&"site_founded", [id], {"site": site.id})
		_update_strength(data, faction)
		if faction.strength < DESTINED_PRESENT_MIN:
			var home: SiteData = _sites_of(data, id)[0]
			var arrivals := DESTINED_PRESENT_MIN + rng.randi_range(0, 40) - faction.strength
			home.population += arrivals
			data.log_event(&"pilgrims_joined", [id], {"site": home.id, "count": arrivals})
			_update_strength(data, faction)


# --- Helpers -----------------------------------------------------------------

## Whether the same kind of attack on the same place was already recorded
## in the last `years` years: a siege is one story, not seven.
static func _told_lately(data: WorldData, type: StringName, attacker: StringName, site_id: String, years: int) -> bool:
	for i in range(data.events.size() - 1, -1, -1):
		var event: EventRecord = data.events[i]
		if data.year - event.year > years:
			return false
		if event.type == type and event.actors[0] == attacker and event.data.get("site") == site_id:
			return true
	return false


## Less appetite for war against a destined faction holding on to its last
## settlement: it would only be a siege nobody remembers.
static func _war_appetite(data: WorldData, a: FactionData, b: FactionData) -> float:
	for faction in [a, b]:
		if faction.defined and _sites_of(data, faction.id).size() <= 1:
			return 0.3
	return 1.0


## Living factions of the region, oldest first. Dictionaries keep insertion
## order, and history inserts in a repeatable order, so this repeats too.
static func _alive(data: WorldData) -> Array:
	return data.factions.values().filter(func(faction): return faction.is_alive() and faction.region == region)


## 0 (an empty region) .. 1 (every mouth it can feed).
static func _pressure(data: WorldData) -> float:
	var total := 0
	for site in _living_sites(data):
		total += site.population
	return clampf(total / float(Regions.info(region).capacity), 0.0, 1.2)


static func _sites_of(data: WorldData, faction_id: StringName) -> Array:
	return _living_sites(data).filter(func(site): return site.faction == faction_id)


## Lived-in sites of the region, oldest first (insertion order, see _alive).
static func _living_sites(data: WorldData) -> Array:
	return data.sites.values().filter(func(site): return site.is_lived_in() and site.region == region)


static func _new_site(data: WorldData, faction: FactionData, population: int, rng: RandomNumberGenerator) -> SiteData:
	var site := SiteData.new()
	site.id = "site_%d" % data.new_id()
	site.faction = faction.id
	site.region = faction.region
	site.population = maxi(1, population)
	site.founded_year = data.year
	# Names are not reused. The Gut only looks at its own (as it always did,
	# so its past stays word for word); other regions avoid every name.
	var used := data.sites.values().filter(func(s): return faction.region != Regions.GUT or s.region == Regions.GUT).map(func(s): return s.name)
	site.name = HistoryNames.place(rng)
	for attempt in 6:
		if not site.name in used:
			break
		site.name = HistoryNames.place(rng)
	data.sites[site.id] = site
	return site


## A splinter takes one of the parent's settlements (not its biggest) if it
## has several, or leads settlers out of its biggest one.
static func _split_off(data: WorldData, parent: FactionData, splinter: FactionData, rng: RandomNumberGenerator) -> SiteData:
	var sites := _sites_of(data, parent.id)
	sites.sort_custom(func(x, y): return x.population > y.population)
	if sites.size() >= 2:
		var site: SiteData = sites[1 + rng.randi() % (sites.size() - 1)]
		site.faction = splinter.id
		return site
	var settlers := int(sites[0].population * 0.35)
	sites[0].population -= settlers
	return _new_site(data, splinter, settlers, rng)


static func _end_site(data: WorldData, site: SiteData) -> void:
	site.kind = &"ruin"
	site.ended_year = data.year
	site.population = 0


static func _end_war(_data: WorldData, a: FactionData, b: FactionData) -> void:
	a.wars.erase(b.id)
	b.wars.erase(a.id)


static func _update_strength(data: WorldData, faction: FactionData) -> void:
	var total := 0
	for site in _sites_of(data, faction.id):
		total += site.population
	faction.strength = total


static func _wonder_kind(faction: FactionData, rng: RandomNumberGenerator) -> StringName:
	var kinds := {&"farmers": &"harvest", &"diggers": &"vein", &"hunters": &"hunt", &"cult": &"relic", &"scavengers": &"salvage"}
	if faction.piety > 0.7 and rng.randf() < 0.5:
		return &"relic"
	return kinds.get(faction.archetype, &"harvest" if &"tending" in faction.values else &"relic")


## Rounds up with a chance equal to the fraction, so small growth adds up.
static func _round(value: float, rng: RandomNumberGenerator) -> int:
	var whole := floori(value)
	return whole + (1 if rng.randf() < value - whole else 0)

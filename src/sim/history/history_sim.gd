class_name HistorySim
extends RefCounted
## The Gut's past, simulated year by year when a world is created (D-025,
## week 28). Plain data in, plain data out: factions (WorldData.factions),
## sites (WorldData.sites) and the event log (WorldData.events). Text is made
## from the events when shown (EventText), never stored.
##
## Peoples arrive, found settlements, grow, trade, go to war, split in
## schisms, suffer floods and plagues, and die out. The hand-made factions
## are destined: the Flesh-Tenders are among the early peoples, the Choir of
## Waking is born as a prophet's schism mid-history, and neither can vanish
## before the present. Everything comes from one seeded generator, so the
## same world seed always gives the same history.

const YEARS := 2000
## Between lives (week 37): hand-made places (sites in a slot) cannot be
## taken, razed or abandoned, so the places the player knows stay; their
## people, numbers, wars and neighbours still change.
static var protect_slots := false
const TENDERS := &"flesh_tenders"
const CHOIR := &"choir_of_waking"
## A settlement this big gets crowded and sends settlers off.
const SITE_CAPACITY := 360
const MAX_SITES_PER_FACTION := 6
const MAX_LIVING_FACTIONS := 7
## A destined faction's last settlement never drops below this.
const DESTINED_FLOOR := 20
## A destined faction this small in the present gets pilgrims (an event).
const DESTINED_PRESENT_MIN := 80
## How many people the Gut can feed. The fuller it gets, the slower everyone
## grows and the more readily neighbours turn on each other.
const GUT_CAPACITY := 2600

const FROM := ["the Wound", "the upper veins", "the lung-dark", "a burst artery", "the scar tissue"]
const WAR_CAUSES := ["the bile cisterns of %s", "an old insult", "the warm wall near %s", "a stolen relic",
	"grazing rights on the lining", "who may bury their dead at %s", "a prophecy about %s", "a murdered envoy"]
const SCHISM_CAUSES := ["over whether the god only sleeps", "over the right way to bury the dead",
	"over a vision seen in a spasm", "over who should lead after the flood", "over eating the god's flesh"]
const GOODS := ["bile and salt", "dried gut-meat", "bone tools", "lamp oil", "spores", "relics", "cartilage"]
const DISASTERS := [&"bile_flood", &"rot_plague", &"spasm", &"famine"]


## Runs YEARS (or `years`) of history ending at data.year. Expects a world
## without factions; afterwards data.year is unchanged.
static func run(data: WorldData, years := YEARS) -> void:
	var rng := SeededRng.make([data.world_seed, "history"])
	var now := data.year
	var start := now - years
	var tenders_year := start + rng.randi_range(5, 220)
	var choir_year := start + rng.randi_range(700, 1500)
	data.year = start
	for year in years:
		data.year += 1
		if year == 0:
			for i in rng.randi_range(2, 3):
				_arrive(data, rng)
		if data.year == tenders_year:
			_found_tenders(data, rng)
		if data.year == choir_year:
			_found_choir(data, rng)
		tick(data, rng)
	data.year = now
	_into_the_present(data, rng)


## History between two lives (week 37): `years` more years of the same
## yearly simulation, ending at data.year, with hand-made places protected.
## Returns the events it logged.
static func between_lives(data: WorldData, years: int, rng: RandomNumberGenerator) -> Array:
	var first := data.events.size()
	var now := data.year
	data.year = now - years
	protect_slots = true
	for i in years:
		data.year += 1
		tick(data, rng)
	protect_slots = false
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
	HistoryNames.make_people(faction, HistoryNames.random_archetype(rng), rng)
	faction.founded_year = data.year
	data.factions[faction.id] = faction
	var site := _new_site(data, faction, rng.randi_range(40, 90), rng)
	data.log_event(&"people_arrived", [faction.id], {"site": site.id, "from": FROM[rng.randi() % FROM.size()]})
	_update_strength(data, faction)
	return faction


static func _found_tenders(data: WorldData, rng: RandomNumberGenerator) -> void:
	var faction := FactionData.from_def(FactionDb.get_def(TENDERS), data.year)
	faction.relations.clear()
	data.factions[faction.id] = faction
	var site := _new_site(data, faction, rng.randi_range(50, 80), rng)
	data.log_event(&"faction_founded", [faction.id], {"site": site.id, "founder": HistoryNames.person(rng)})
	_update_strength(data, faction)


## The Choir is born from the most devout people of the day, or, if there
## is nobody devout enough, from pilgrims who heard the heart.
static func _found_choir(data: WorldData, rng: RandomNumberGenerator) -> void:
	var parent: FactionData = null
	for faction in _alive(data):
		if not _sites_of(data, faction.id).is_empty() and (parent == null or faction.piety * faction.strength > parent.piety * parent.strength):
			parent = faction
	var choir := FactionData.from_def(FactionDb.get_def(CHOIR), data.year)
	choir.relations.clear()
	data.factions[choir.id] = choir
	var prophet := HistoryNames.person(rng)
	if parent == null:
		var site := _new_site(data, choir, rng.randi_range(40, 70), rng)
		data.log_event(&"faction_founded", [choir.id], {"site": site.id, "founder": prophet, "pilgrims": true})
	else:
		choir.parent = parent.id
		var site := _split_off(data, parent, choir, rng)
		data.set_relation(parent.id, choir.id, -60)
		data.log_event(&"schism", [choir.id, parent.id], {"site": site.id, "prophet": prophet, "cause": "over whether the god only sleeps"})
	_update_strength(data, choir)


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
				data.log_event(&"trade_pact", [a.id, b.id], {"goods": GOODS[rng.randi() % GOODS.size()]})


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
		if faction.fell_year >= 0:
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
	for id in [TENDERS, CHOIR]:
		if not data.factions.has(id):
			if id == TENDERS:
				_found_tenders(data, rng)
			else:
				_found_choir(data, rng)
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


## Living factions, oldest first. Dictionaries keep insertion order, and
## history inserts in a repeatable order, so this repeats too.
static func _alive(data: WorldData) -> Array:
	return data.factions.values().filter(func(faction): return faction.is_alive())


## 0 (empty Gut) .. 1 (every mouth it can feed).
static func _pressure(data: WorldData) -> float:
	var total := 0
	for site in _living_sites(data):
		total += site.population
	return clampf(total / float(GUT_CAPACITY), 0.0, 1.2)


static func _sites_of(data: WorldData, faction_id: StringName) -> Array:
	return _living_sites(data).filter(func(site): return site.faction == faction_id)


## Lived-in sites, oldest first (insertion order, see _alive).
static func _living_sites(data: WorldData) -> Array:
	return data.sites.values().filter(func(site): return site.is_lived_in())


static func _new_site(data: WorldData, faction: FactionData, population: int, rng: RandomNumberGenerator) -> SiteData:
	var site := SiteData.new()
	site.id = "site_%d" % data.new_id()
	site.faction = faction.id
	site.population = maxi(1, population)
	site.founded_year = data.year
	var used := data.sites.values().map(func(s): return s.name)
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

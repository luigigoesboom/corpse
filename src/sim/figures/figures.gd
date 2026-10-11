class_name Figures
extends RefCounted
## The leaders of peoples (D-033). Every living people has one. Each year
## (HistorySim.tick calls tick(), at worldgen and between lives) a leader
## may die (age, fever, battle, the rot), be overthrown by a rival, or do
## something that fits their nature: a cruel one purges, a pious one raises
## a shrine, a wise one makes peace, a mad one issues decrees nobody
## understands. While they lead, their traits bend their people's
## temperament (aggression, piety, trade, expansion); when they go it is
## given back. Plain data in WorldData.figures.

## What a trait does to their people while they lead, and their epithet.
const TRAITS := {
	&"cruel": {"aggression": 0.2},
	&"pious": {"piety": 0.2},
	&"greedy": {"trade": 0.2, "aggression": 0.05},
	&"wise": {"aggression": -0.15, "trade": 0.05},
	&"ambitious": {"expansion": 0.25, "aggression": 0.1},
	&"paranoid": {"aggression": 0.1, "trade": -0.2},
	&"mad": {"piety": 0.1},
	&"kind": {"aggression": -0.2, "trade": 0.1},
	&"brave": {"aggression": 0.1},
	&"craven": {"aggression": -0.25, "expansion": -0.1},
}
const EPITHETS := {&"cruel": "the Cruel", &"pious": "the Devout", &"greedy": "the Grasping", &"wise": "the Wise",
	&"ambitious": "the Climber", &"paranoid": "the Watchful", &"mad": "the Strange", &"kind": "the Gentle",
	&"brave": "the Bold", &"craven": "the Careful"}
## Titles by faction id, else by archetype, else "Chief".
const TITLES := {&"flesh_tenders": "Elder", &"choir_of_waking": "Cantor", &"bellows_kin": "Windmaster"}
const ARCHETYPE_TITLES := {&"farmers": "Elder", &"diggers": "Foreman", &"hunters": "Huntleader", &"cult": "Voice", &"scavengers": "Boss"}
const DEATHS := ["old age", "a fever", "a fall in the dark", "a bad meal", "a growth in the throat", "grief"]
## What a mad leader decrees ("{n}" is the leader, "{site}" their seat).
const MAD_DECREES := [
	"{n} forbade sleep in {site} for a whole season.",
	"{n} ordered every bell in {site} melted down into a bell for the god's ear.",
	"{n} declared the walls of {site} holy and had the people lick them clean.",
	"{n} married a leech before all of {site}.",
	"{n} had the dead of {site} dug up and asked them questions.",
	"{n} decreed that nobody in {site} could speak above a whisper, so the god could hear.",
	"{n} named a puddle the heir of {site}.",
	"{n} walked into the dark below {site} and came back a year later, and would not say where they had been.",
]
const DEED_CHANCE := 0.012
const COUP_CHANCE := 0.002


## One year of leaders in the region HistorySim is simulating.
static func tick(data: WorldData, rng: RandomNumberGenerator) -> void:
	for faction: FactionData in data.factions.values():
		if not faction.is_alive() or faction.region != HistorySim.region:
			continue
		var leader := leader_of(data, faction.id)
		if leader == null:
			_rise(data, faction, rng, data.year - rng.randi_range(20, 50), false)
			continue
		var age := data.year - leader.born_year
		if rng.randf() < 0.002 + maxf(0.0, age - 45) * 0.004:
			_die(data, leader, DEATHS[0] if age > 70 else DEATHS[rng.randi() % DEATHS.size()])
			var heir := _rise(data, faction, rng, data.year - rng.randi_range(18, 45), false)
			data.log_event(&"leader_died", [faction.id], {"figure": leader.id, "heir": heir.id})
		elif rng.randf() < COUP_CHANCE * (2.0 if &"paranoid" in leader.traits or &"cruel" in leader.traits else 1.0):
			var rival := _rise(data, faction, rng, data.year - rng.randi_range(18, 40), false, leader)
			data.log_event(&"leader_overthrown", [faction.id], {"figure": rival.id, "fallen": leader.id})
		elif rng.randf() < DEED_CHANCE:
			_deed(data, faction, leader, rng)


## The living leader of a people, or null.
static func leader_of(data: WorldData, faction: StringName) -> FigureData:
	for f: FigureData in data.figures.values():
		if f.faction == faction and f.role == &"leader" and f.is_alive():
			return f
	return null


## Living peoples without a leader get one (old saves, peoples made outside
## history), quietly.
static func ensure(data: WorldData, rng: RandomNumberGenerator) -> void:
	for faction: FactionData in data.factions.values():
		if faction.is_alive() and leader_of(data, faction.id) == null:
			_rise(data, faction, rng, data.year - rng.randi_range(25, 55), false)


## The host killed a leader (a resident of their seat): they are dead, the
## people will choose another between lives.
static func killed_by_host(data: WorldData, leader: FigureData, host_name: String, site_id := "") -> void:
	_die(data, leader, host_name)
	data.log_deed(&"leader_killed", [leader.faction, host_name], {"figure": leader.id, "site": site_id})


## Where the leader lives: the people's biggest lived-in settlement in a
## hand-made slot (a place you can walk to), else their biggest.
static func seat_of(data: WorldData, faction: StringName) -> SiteData:
	var best: SiteData = null
	for site: SiteData in data.sites.values():
		if site.faction != faction or not site.is_lived_in():
			continue
		var walkable := site.slot != ""
		var best_walkable := best != null and best.slot != ""
		if best == null or (walkable and not best_walkable) or (walkable == best_walkable and site.population > best.population):
			best = site
	return best


## What a resident says about their leader (Talk), or "".
static func leader_line(data: WorldData, faction: StringName, seed_value: int) -> String:
	var leader := leader_of(data, faction)
	if leader == null:
		return ""
	var years := data.year - leader.rose_year
	var how := {&"cruel": "Nobody speaks against them twice.", &"pious": "They pray more than they sleep.",
		&"greedy": "Everything passes through their hands, and some of it stays there.", &"wise": "They have kept us out of more wars than I can count.",
		&"ambitious": "They want more than we have. They always want more.", &"paranoid": "They trust nobody. Not even me.",
		&"mad": "They say strange things. Some of us write them down.", &"kind": "They know all our names.",
		&"brave": "They went into the dark after a beast once, alone.", &"craven": "They keep us safe. They keep us very, very safe."}
	var line := "We are led by %s%s. " % [leader.full_name(), (", these %d years" % years) if years > 1 else ", newly chosen"]
	return line + how.get(leader.traits[seed_value % leader.traits.size()], "")


static func _rise(data: WorldData, faction: FactionData, rng: RandomNumberGenerator, born: int, after_death: bool, overthrows: FigureData = null) -> FigureData:
	var f := FigureData.new()
	f.id = "figure_%d" % data.new_id()
	f.name = HistoryNames.person(rng)
	f.title = TITLES.get(faction.id, ARCHETYPE_TITLES.get(faction.archetype, "Chief"))
	f.faction = faction.id
	f.born_year = mini(born, data.year - 16)
	f.rose_year = data.year
	var keys := TRAITS.keys()
	while f.traits.size() < 2:
		var t: StringName = keys[rng.randi() % keys.size()]
		if not t in f.traits:
			f.traits.append(t)
	if overthrows:
		_die(data, overthrows, "the knife of " + f.name)
		if not &"cruel" in f.traits and not &"ambitious" in f.traits:
			f.traits[0] = &"ambitious" if rng.randf() < 0.5 else &"cruel"
	data.figures[f.id] = f
	# Their nature bends their people while they lead.
	for t in f.traits:
		for field in TRAITS[t]:
			var before: float = faction.get(field)
			faction.set(field, clampf(before + TRAITS[t][field], 0.0, 1.0))
			f.applied[field] = f.applied.get(field, 0.0) + faction.get(field) - before
	if after_death:  # Old saves have leader_rose events; new ones log successions in leader_died.
		data.log_event(&"leader_rose", [faction.id], {"figure": f.id})
	return f


static func _die(data: WorldData, f: FigureData, cause: String) -> void:
	f.died_year = data.year
	f.cause = cause
	var faction: FactionData = data.factions.get(f.faction)
	if faction:
		for field in f.applied:
			faction.set(field, clampf(faction.get(field) - f.applied[field], 0.0, 1.0))
	f.applied.clear()


## Something the leader does, after their nature (one trait, picked).
static func _deed(data: WorldData, faction: FactionData, leader: FigureData, rng: RandomNumberGenerator) -> void:
	var seat := seat_of(data, faction.id)
	if seat == null:
		return
	var t: StringName = leader.traits[rng.randi() % leader.traits.size()]
	var details := {"figure": leader.id, "site": seat.id, "deed": t}
	match t:
		&"cruel", &"paranoid":
			var dead := maxi(2, int(seat.population * rng.randf_range(0.03, 0.1)))
			seat.population = maxi(20, seat.population - dead)
			details.dead = dead
		&"pious":
			faction.piety = clampf(faction.piety + 0.03, 0.0, 1.0)
		&"wise":
			if not faction.wars.is_empty():
				var other: FactionData = data.factions.get(faction.wars[0])
				faction.wars.erase(other.id)
				if other:
					other.wars.erase(faction.id)
					details.other = other.id
			else:
				t = &"kind"
		&"ambitious", &"greedy":
			var others := data.factions.values().filter(func(o): return o.is_alive() and o.region == faction.region and o.id != faction.id)
			if others.is_empty():
				return
			var other: FactionData = others[rng.randi() % others.size()]
			data.set_relation(faction.id, other.id, data.relation(faction.id, other.id) - 20)
			details.other = other.id
		&"kind":
			for o: FactionData in data.factions.values():
				if o.is_alive() and o.region == faction.region and o.id != faction.id:
					data.set_relation(faction.id, o.id, data.relation(faction.id, o.id) + 8)
		&"brave":
			for beast: BeastData in data.beasts.values():
				if beast.is_alive() and beast.region == faction.region and rng.randf() < 0.5:
					beast.died_year = data.year
					beast.slain_by = String(faction.id)
					details.beast = beast.id
					break
		&"mad":
			details.decree = rng.randi() % MAD_DECREES.size()
		&"craven":
			pass
	details.deed = t
	data.log_event(&"leader_deed", [faction.id] + ([details.other] if details.has("other") else []), details)

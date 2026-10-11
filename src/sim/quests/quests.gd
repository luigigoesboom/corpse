class_name Quests
extends RefCounted
## Tasks peoples ask of the fragment (D-033), made from what is true in the
## world right now, Caves of Qud style. A people offers one task at a time
## (offer()), rolled from the kinds that are possible:
##   slay     kill a legendary beast of their region (one that raided them first)
##   relic    bring them an artifact lying somewhere in the body
##   fetch    bring them some of what they want (FactionDef wants)
##   cull     kill some creatures of a kind of their region
##   deliver  carry a sealed gift to another people (a generated item)
## Progress: kills (on_kill(), on_beast_slain()), items in your pockets
## (checked when you talk). Rewards: ichor and standing; delivering warms
## both peoples. Plain data in WorldData.quests.

const CULL_KINDS := {&"gut": [&"gut_leech", &"bile_spitter", &"rot_fly"], &"lungs": [&"cilia_lasher", &"bellows_ray", &"puffsac"]}
const KIND_PLURALS := {&"gut_leech": "gut leeches", &"bile_spitter": "bile spitters", &"rot_fly": "rot flies",
	&"cilia_lasher": "cilia lashers", &"bellows_ray": "bellows rays", &"puffsac": "puffsacs"}
const GIFT_PREFIX := "quest_gift_"


## The task a people would give now: their open one, or a new one (not yet
## taken: accept() stores it). null if they have nothing to ask.
static func offer(data: WorldData, faction: StringName, seed_value: int) -> QuestData:
	var open := open_from(data, faction)
	if open:
		return open
	var f: FactionData = data.factions.get(faction)
	var def := FactionDb.get_def(faction)
	if f == null or not f.is_alive() or def == null:
		return null
	var rng := SeededRng.make([data.world_seed, "quest", faction, data.lives.size(), data.quests.size(), seed_value % 3])
	var seat := Figures.seat_of(data, faction)
	var options := []
	# Slay: a beast of their region, the one that raided them if there is one.
	var beasts := data.beasts.values().filter(func(b): return b.is_alive() and b.region == f.region)
	if not beasts.is_empty():
		var raider: Array = beasts.filter(func(b): return faction in Beasts.raided(data, b))
		var beast: BeastData = (raider if not raider.is_empty() else beasts)[rng.randi() % (raider.size() if not raider.is_empty() else beasts.size())]
		options.append(_make(&"slay", faction, seat, beast.id, 1, 45, 25))
		options.append(options[-1])  # Twice as likely: the best kind of task.
	# Relic: an artifact lying on some floor (not a trophy).
	var lying := []
	for chunk in data.chunk_diffs:
		for record in data.items_in_chunk(chunk):
			var id := String(record.item)
			if id.begins_with("artifact_") and data.artifacts.has(id) and data.artifacts[id].kind != &"trophy":
				lying.append(id)
	if not lying.is_empty():
		options.append(_make(&"relic", faction, seat, lying[rng.randi() % lying.size()], 1, 35, 20))
	# Fetch: some of what they want.
	var wants := Array(def.wants).filter(func(w): return w != &"artifact")
	if not wants.is_empty():
		var want: StringName = wants[rng.randi() % wants.size()]
		var n := rng.randi_range(2, 3)
		options.append(_make(&"fetch", faction, seat, String(want), n, 8 * n, 10))
	# Cull: creatures of their region.
	var kinds: Array = CULL_KINDS.get(f.region, [])
	if not kinds.is_empty():
		var n := rng.randi_range(3, 5)
		options.append(_make(&"cull", faction, seat, String(kinds[rng.randi() % kinds.size()]), n, 6 * n, 15))
	# Deliver: a gift to another people with a home you can walk to.
	var others := data.factions.values().filter(func(o): return o.is_alive() and o.id != faction and FactionDb.get_def(o.id) != null \
		and data.sites.values().any(func(s): return s.faction == o.id and s.slot != "" and s.is_lived_in()))
	if not others.is_empty():
		var other: FactionData = others[rng.randi() % others.size()]
		options.append(_make(&"deliver", faction, seat, String(other.id), 1, 20, 15))
	if options.is_empty():
		return null
	var q: QuestData = options[rng.randi() % options.size()]
	q.id = "quest_%d_%d" % [data.quests.size() + 1, rng.randi() % 10000]
	return q


## Takes the task on. Gives the gift to carry for a delivery (false if there
## is no room in the pockets for it).
static func accept(data: WorldData, q: QuestData) -> bool:
	if q.kind == &"deliver":
		q.item = GIFT_PREFIX + q.id
		if data.add_to_inventory(StringName(q.item)) < 0:
			q.item = ""
			return false
	q.year = data.year
	q.state = &"active"
	data.quests[q.id] = q
	return true


## The open task a people gave, or null.
static func open_from(data: WorldData, faction: StringName) -> QuestData:
	for q: QuestData in data.quests.values():
		if q.giver == faction and q.is_open():
			return q
	return null


## A delivery meant for this people that you carry, or null.
static func delivery_for(data: WorldData, faction: StringName) -> QuestData:
	for q: QuestData in data.quests.values():
		if q.kind == &"deliver" and q.is_open() and q.target == String(faction) and data.inventory.has(StringName(q.item)):
			return q
	return null


## Whether it can be handed in now (talking to the giver, or for a delivery,
## to the people it is for).
static func ready(data: WorldData, q: QuestData) -> bool:
	match q.kind:
		&"slay", &"cull":
			return q.state == &"done"
		&"relic":
			return data.inventory.has(StringName(q.target))
		&"fetch":
			return data.inventory.count(StringName(q.target)) >= q.count
		&"deliver":
			return data.inventory.has(StringName(q.item))
	return false


## Hands it in: takes what was asked for, pays. Returns the ichor paid.
static func turn_in(data: WorldData, q: QuestData) -> int:
	match q.kind:
		&"relic":
			data.inventory[data.inventory.find(StringName(q.target))] = &""
		&"fetch":
			for i in q.count:
				data.inventory[data.inventory.find(StringName(q.target))] = &""
		&"deliver":
			data.inventory[data.inventory.find(StringName(q.item))] = &""
			data.change_standing(StringName(q.target), q.standing)
	q.state = &"rewarded"
	data.add_ichor(q.ichor)
	data.change_standing(q.giver, q.standing)
	data.log_event(&"quest_done", [q.giver, data.current_life().host_name if data.current_life() else "a host"], {"quest": q.id, "site": q.site})
	return q.ichor


## A creature was killed by the host.
static func on_kill(data: WorldData, kind: StringName) -> void:
	for q: QuestData in data.quests.values():
		if q.kind == &"cull" and q.state == &"active" and q.target == String(kind):
			q.progress += 1
			if q.progress >= q.count:
				q.state = &"done"


## A legendary beast was killed by the host.
static func on_beast_slain(data: WorldData, beast_id: String) -> void:
	for q: QuestData in data.quests.values():
		if q.kind == &"slay" and q.state == &"active" and q.target == beast_id:
			q.progress = 1
			q.state = &"done"


## Between lives: tasks that cannot be done any more fail (the beast was
## killed by someone else, the giver is gone).
static func check(data: WorldData) -> void:
	for q: QuestData in data.quests.values():
		if not q.is_open():
			continue
		var giver: FactionData = data.factions.get(q.giver)
		if giver == null or not giver.is_alive():
			q.state = &"failed"
		elif q.kind == &"slay" and q.state == &"active":
			var beast: BeastData = data.beasts.get(q.target)
			if beast == null or not beast.is_alive():
				q.state = &"failed"


## What they say when they ask.
static func ask_text(data: WorldData, q: QuestData) -> String:
	match q.kind:
		&"slay":
			var beast: BeastData = data.beasts.get(q.target)
			var name := beast.full_name() if beast else "the beast"
			return "%s comes for us out of the dark. Kill it, and %d ichor is yours." % [name, q.ichor] if beast and q.giver in Beasts.raided(data, beast) \
				else "There is a thing called %s, %s. Bring it down and we will pay %d ichor." % [name, Beasts.describe(beast) if beast else "a beast", q.ichor]
		&"relic":
			var artifact: ArtifactData = data.artifacts.get(q.target)
			var where := EventText._site(data, artifact.site_id) if artifact and artifact.site_id != "" else "somewhere below"
			return "%s lies in the ruins of %s. It should be with people who remember. Bring it to us: %d ichor." % [_cap(artifact.name if artifact else "a relic"), where, q.ichor]
		&"fetch":
			return "We need %d %s. Bring them and we will give you %d ichor." % [q.count, _plural(ItemDb.display_name(StringName(q.target)).to_lower(), q.count), q.ichor]
		&"cull":
			return "The %s are thick in our land. Kill %d of them: %d ichor." % [KIND_PLURALS.get(StringName(q.target), q.target), q.count, q.ichor]
		&"deliver":
			return "Carry a gift to %s for us, sealed. Hand it to any of them. They will know what it means." % EventText._faction(data, q.target)
	return "..."


## One line for the Tasks page: what, for whom, how far along.
static func summary(data: WorldData, q: QuestData) -> String:
	var who := EventText._faction(data, q.giver)
	match q.kind:
		&"slay":
			var beast: BeastData = data.beasts.get(q.target)
			return "Kill %s, for %s." % [beast.full_name() if beast else "the beast", who]
		&"relic":
			var artifact: ArtifactData = data.artifacts.get(q.target)
			return "Bring %s to %s." % [artifact.name if artifact else "the relic", who]
		&"fetch":
			return "Bring %d %s to %s (%d carried)." % [q.count, _plural(ItemDb.display_name(StringName(q.target)).to_lower(), q.count), who, data.inventory.count(StringName(q.target))]
		&"cull":
			return "Kill %d %s for %s (%d so far)." % [q.count, KIND_PLURALS.get(StringName(q.target), q.target), who, q.progress]
		&"deliver":
			return "Carry the sealed gift of %s to %s." % [who, EventText._faction(data, q.target)]
	return ""


## The gift items carried for deliveries, for ItemDb (like artifacts).
static func item_defs(data: WorldData) -> Dictionary:
	var defs := {}
	for q: QuestData in data.quests.values():
		if q.item == "":
			continue
		var def := ItemDef.new()
		def.id = StringName(q.item)
		def.display_name = "Sealed gift"
		def.description = "A bundle wrapped in skin and sealed with %s's mark, for %s. It is not yours to open." % [EventText._faction(data, q.giver), EventText._faction(data, q.target)]
		def.color = data.factions[q.giver].color if data.factions.has(q.giver) else Color.WHITE
		defs[def.id] = def
	return defs


static func _make(kind: StringName, giver: StringName, seat: SiteData, target: String, count: int, ichor: int, standing: int) -> QuestData:
	var q := QuestData.new()
	q.kind = kind
	q.giver = giver
	q.site = seat.id if seat else ""
	q.target = target
	q.count = count
	q.ichor = ichor
	q.standing = standing
	return q


static func _plural(word: String, n: int) -> String:
	if n == 1:
		return word
	return word + ("es" if word.ends_with("s") or word.ends_with("sh") else "s")


static func _cap(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)

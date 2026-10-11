class_name Rot
extends RefCounted
## The body's rot (D-033): a field over the whole map, one value 0..255 per
## CELL x CELL tiles, kept in WorldData.rot. Plain data; the world layer
## gives it a map of the body (BodyMap.context(): which cells have air,
## which region, how much rot is painted there, where the named places are).
##
## Year by year (between lives, and to settle a new world):
##   - painted rot (tiles.png) keeps welling up to its own level,
##   - ruins, bodies of hosts and sickened settlements feed it,
##   - it creeps from cell to open cell, and slowly dries away (the Lungs'
##     breath scours it much faster),
##   - peoples who tend the lining (value "tending": the Flesh-Tenders) burn
##     it back around their settlements, the more of them the further,
##   - now and then it blooms somewhere at random.
## What it does: a settlement deep in rot sickens and loses people; places
## the rot reaches or leaves are logged (rot_spread, rot_receded, rot_bloom,
## rot_sickness); the world layer turns heavy rot into rot rock, the
## atmosphere sickens, rot flies breed (Ecology).

const CELL := 8
## Where rot counts as heavy: places are "in the rot", rock turns.
const HEAVY := 0.55
const LIGHT := 0.25
const SPREAD := 0.14
const DRY := {&"gut": 0.006, &"lungs": 0.03}
const RUIN_FEED := 0.05
const BODY_FEED := 0.06
const BODY_YEARS := 12
const BLOOM_CHANCE := 0.04
const TEND_RADIUS := 3
## Fraction of a sick settlement lost per year in heavy rot.
const SICKNESS := 0.02


static func grid_size(map_tiles: Vector2i) -> Vector2i:
	return Vector2i(ceili(map_tiles.x / float(CELL)), ceili(map_tiles.y / float(CELL)))


## Makes data.rot the right size for the map (a new world, an old save).
## Returns true if it had to be made (then it should be settled).
static func ensure(data: WorldData, ctx: Dictionary) -> bool:
	var n: int = ctx.w * ctx.h
	if data.rot.size() == n and data.rot_width == ctx.w:
		return false
	data.rot = PackedByteArray()
	data.rot.resize(n)
	data.rot_width = ctx.w
	for i in n:
		data.rot[i] = ctx.painted[i]
	return true


## Rot at a world point (0..1); 0 outside the field.
static func at_point(data: WorldData, point: Vector2) -> float:
	return at_tile(data, Vector2i((point / 32.0).floor()))


static func at_tile(data: WorldData, tile: Vector2i) -> float:
	if data.rot_width <= 0:
		return 0.0
	var c := tile / CELL
	var h := data.rot.size() / data.rot_width
	if tile.x < 0 or tile.y < 0 or c.x >= data.rot_width or c.y >= h:
		return 0.0
	return data.rot[c.y * data.rot_width + c.x] / 255.0


static func cell_of_point(ctx: Dictionary, point: Vector2) -> int:
	var c := Vector2i((point / 32.0 / CELL).floor())
	return clampi(c.y, 0, ctx.h - 1) * ctx.w + clampi(c.x, 0, ctx.w - 1)


## `years` years of rot (at least one step, at most 40: longer gaps settle).
## Logs events about named places; returns them.
static func run(data: WorldData, ctx: Dictionary, years: int, rng: RandomNumberGenerator) -> Array:
	var first := data.events.size()
	var before := _place_levels(data, ctx)
	var steps := clampi(years, 1, 40)
	for s in steps:
		_step(data, ctx, rng)
	var after := _place_levels(data, ctx)
	for i in ctx.places.size():
		var place: Dictionary = ctx.places[i]
		var name := _place_name(data, place)
		if name == "":
			continue
		if before[i] < HEAVY and after[i] >= HEAVY:
			data.log_event(&"rot_spread", [_owner(data, place)], {"place": name, "region": place.get("region", &"gut")})
		elif before[i] >= HEAVY and after[i] < LIGHT:
			var by := _tenders_near(data, ctx, place.cell)
			data.log_event(&"rot_receded", [by] if by != &"" else [], {"place": name})
	return data.events.slice(first)


## Settles a fresh field: some decades of rot, without logging.
static func settle(data: WorldData, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	for s in 30:
		_step(data, ctx, rng, false)


static func _step(data: WorldData, ctx: Dictionary, rng: RandomNumberGenerator, log_events := true) -> void:
	var w: int = ctx.w
	var h: int = ctx.h
	var air: PackedByteArray = ctx.air
	var field := PackedFloat32Array()
	field.resize(w * h)
	for i in w * h:
		field[i] = data.rot[i] / 255.0
	# Sources.
	for i in w * h:
		var painted: float = ctx.painted[i] / 255.0
		if field[i] < painted:
			field[i] += (painted - field[i]) * 0.15
	for place in ctx.places:
		if place.kind == "ruin":
			field[place.cell] += RUIN_FEED
		elif place.kind == "settlement":
			var site := data.site_in_slot(place.slot) if place.has("slot") else null
			if site and field[place.cell] >= HEAVY:
				field[place.cell] += 0.02  # The sick feed it too.
	for life in data.lives:
		if not life.is_alive() and data.year - life.death_year <= BODY_YEARS and life.corpse_state != &"eaten":
			field[cell_of_point(ctx, life.corpse_position)] += BODY_FEED
	if rng.randf() < BLOOM_CHANCE:
		var i := rng.randi() % (w * h)
		if air[i]:
			field[i] += rng.randf_range(0.4, 0.8)
			if log_events:
				var near := _nearest_place(data, ctx, i)
				if near != "":
					data.log_event(&"rot_bloom", [], {"place": near})
	# Spread through open cells, then dry.
	var next := field.duplicate()
	for y in h:
		for x in w:
			var i := y * w + x
			if not air[i]:
				continue
			var sum := 0.0
			var n := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or not air[q.y * w + q.x]:
					continue
				sum += field[q.y * w + q.x]
				n += 1
			if n > 0:
				next[i] += SPREAD * (sum / n - field[i])
			var region: StringName = Regions.IDS[ctx.region[i]] if ctx.region[i] < Regions.IDS.size() else Regions.GUT
			next[i] -= DRY.get(region, 0.01)
	# Tending peoples burn it back around their homes.
	for place in ctx.places:
		if place.kind != "settlement" or not place.has("slot"):
			continue
		var site := data.site_in_slot(place.slot)
		if site == null or not site.is_lived_in():
			continue
		var faction: FactionData = data.factions.get(site.faction)
		if faction == null or not &"tending" in faction.values:
			continue
		var reach := TEND_RADIUS + int(site.population / 150)
		var c := Vector2i(place.cell % w, place.cell / w)
		for y in range(c.y - reach, c.y + reach + 1):
			for x in range(c.x - reach, c.x + reach + 1):
				if x >= 0 and y >= 0 and x < w and y < h:
					var falloff := 1.0 - Vector2(x - c.x, y - c.y).length() / (reach + 1.0)
					if falloff > 0.0:
						next[y * w + x] -= 0.06 * falloff
	# Sick settlements lose people.
	for place in ctx.places:
		if place.kind == "settlement" and place.has("slot") and next[place.cell] >= HEAVY:
			var site := data.site_in_slot(place.slot)
			if site and site.is_lived_in():
				var lost := maxi(1, int(site.population * SICKNESS * next[place.cell]))
				site.population = maxi(20, site.population - lost)
				if log_events and rng.randf() < 0.15:
					data.log_event(&"rot_sickness", [site.faction], {"site": site.id, "dead": lost})
	for i in w * h:
		data.rot[i] = clampi(roundi(clampf(next[i], 0.0, 1.0) * 255.0), 0, 255) if air[i] or ctx.painted[i] > 0 else 0


static func _place_levels(data: WorldData, ctx: Dictionary) -> Array:
	return ctx.places.map(func(p): return data.rot[p.cell] / 255.0 if p.cell < data.rot.size() else 0.0)


static func _place_name(data: WorldData, place: Dictionary) -> String:
	if place.has("slot"):
		var site := data.site_in_slot(place.slot)
		return site.name if site else ""
	return place.get("name", "")


static func _owner(data: WorldData, place: Dictionary) -> StringName:
	if place.has("slot"):
		var site := data.site_in_slot(place.slot)
		if site:
			return site.faction
	return &""


static func _nearest_place(data: WorldData, ctx: Dictionary, cell: int) -> String:
	var best := ""
	var best_d := 6.0
	var c := Vector2(cell % ctx.w, cell / ctx.w)
	for place in ctx.places:
		var d := c.distance_to(Vector2(place.cell % ctx.w, place.cell / ctx.w))
		if d < best_d:
			var name := _place_name(data, place)
			if name != "":
				best_d = d
				best = name
	return best


static func _tenders_near(data: WorldData, ctx: Dictionary, cell: int) -> StringName:
	var c := Vector2(cell % ctx.w, cell / ctx.w)
	for place in ctx.places:
		if place.kind != "settlement" or not place.has("slot"):
			continue
		var site := data.site_in_slot(place.slot)
		if site and site.is_lived_in() and &"tending" in data.factions[site.faction].values \
				and c.distance_to(Vector2(place.cell % ctx.w, place.cell / ctx.w)) <= TEND_RADIUS + 3:
			return site.faction
	return &""

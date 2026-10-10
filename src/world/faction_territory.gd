class_name FactionTerritory
extends RefCounted
## Starting faction territory from a painted map (week 26).
##
## data/maps/territory.png is the same size as world.png (1 px = 1 tile), so it
## can be painted as a layer over the world in Krita. Paint each faction's land
## in its FactionDef.color; leave the rest transparent. A chunk belongs to the
## faction with the most paint in it, if that is at least MIN_SHARE of the chunk.
## Applied once when a world starts, after its history (HistorySim) made the
## factions: the painted map is the present day. Only factions that exist and
## are alive get land; peoples the history invented live elsewhere.

const PATH := "res://data/maps/territory.png"
const MIN_SHARE := 0.1
## How close (RGB distance) a pixel must be to a faction's color to count.
const COLOR_TOLERANCE := 0.25


## Gives the painted territory to the factions in data.factions.
static func apply_territory(data: WorldData) -> void:
	for faction in data.factions.values():
		faction.territory.clear()
	var claims := read_claims()
	for chunk in claims:
		var faction: FactionData = data.factions.get(claims[chunk])
		if faction and faction.is_alive():
			faction.territory.append(chunk)
	for faction in data.factions.values():
		faction.territory.sort()


## Chunk (Vector2i) -> faction id, from the painted map. Empty if there is no map.
static func read_claims() -> Dictionary:
	if not FileAccess.file_exists(PATH) and not ResourceLoader.exists(PATH):
		return {}
	var image := WorldMap.read_image(PATH)
	var colors := {}
	for id in FactionDb.all_ids():
		colors[id] = FactionDb.get_def(id).color
	var counts := {}  # chunk -> {faction id -> painted tiles}
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			var id := _match(pixel, colors)
			if id == &"":
				continue
			var chunk := Vector2i(x / ChunkData.SIZE, y / ChunkData.SIZE)
			var per_chunk: Dictionary = counts.get_or_add(chunk, {})
			per_chunk[id] = per_chunk.get(id, 0) + 1
	var claims := {}
	var needed := int(ChunkData.SIZE * ChunkData.SIZE * MIN_SHARE)
	for chunk in counts:
		var best: StringName = &""
		for id in counts[chunk]:
			if best == &"" or counts[chunk][id] > counts[chunk][best]:
				best = id
		if counts[chunk][best] >= needed:
			claims[chunk] = best
	return claims


static func _match(pixel: Color, colors: Dictionary) -> StringName:
	var best: StringName = &""
	var best_distance := COLOR_TOLERANCE
	for id in colors:
		var c: Color = colors[id]
		var distance := Vector3(pixel.r - c.r, pixel.g - c.g, pixel.b - c.b).length()
		if distance < best_distance:
			best_distance = distance
			best = id
	return best

class_name ChunkGenerator
extends RefCounted
## Turns (world seed, chunk coord) into ChunkData. Pure function of its inputs:
## the same seed and coord always give the same chunk, in any load order.
##
## Prototype terrain: one noise field sampled in world tile coordinates, so
## caves line up across chunk borders on their own. Real Gut terrain (cellular
## automata, guaranteed border openings) is roadmap week 7. World size and
## spawn are hard-coded until the painted map arrives in week 4.

const WORLD_CHUNKS := Vector2i(16, 8)
## Tile the player spawns above. Center of chunk (8, 1).
const SPAWN_TILE := Vector2i(8 * ChunkData.SIZE + 32, ChunkData.SIZE + 32)
const SPAWN_ROOM_HALF := Vector2i(14, 5)
const BORDER := 2

var world_seed: int
var tunnel_width := 0.14
var chamber_threshold := 0.3
var _tunnels := FastNoiseLite.new()
var _chambers := FastNoiseLite.new()


func _init(seed_value: int) -> void:
	world_seed = seed_value
	# Both noises are seeded from the world seed, never from load order.
	_tunnels.seed = seed_value
	_tunnels.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_tunnels.frequency = 0.012
	_tunnels.fractal_octaves = 2
	_chambers.seed = seed_value + 1
	_chambers.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_chambers.frequency = 0.02
	_chambers.fractal_octaves = 3


func generate(chunk_coord: Vector2i) -> ChunkData:
	var data := ChunkData.new(chunk_coord)
	var origin := chunk_coord * ChunkData.SIZE

	# Sample solidity once, with a 1-tile border so edge cells can see their
	# neighbors in the next chunk.
	var w := ChunkData.SIZE + 2
	var solid := PackedByteArray()
	solid.resize(w * w)
	for y in w:
		for x in w:
			solid[y * w + x] = 1 if is_solid(origin + Vector2i(x - 1, y - 1)) else 0

	for y in ChunkData.SIZE:
		for x in ChunkData.SIZE:
			var i := (y + 1) * w + (x + 1)
			var cell := ChunkData.Cell.EMPTY
			if solid[i]:
				# Only cells next to open space get collision. Inner rock never
				# touches the player, and skipping it saves thousands of shapes.
				var buried := solid[i - 1] and solid[i + 1] and solid[i - w] and solid[i + w]
				cell = ChunkData.Cell.SOLID_INNER if buried else ChunkData.Cell.SOLID_EDGE
			data.cells[ChunkData.index_of(x, y)] = cell
	return data


func is_solid(tile: Vector2i) -> bool:
	var world_tiles := WORLD_CHUNKS * ChunkData.SIZE
	if tile.x < BORDER or tile.y < BORDER or tile.x >= world_tiles.x - BORDER or tile.y >= world_tiles.y - BORDER:
		return true

	# Spawn room: open box with a solid floor, so the first life never starts in rock.
	var d := tile - SPAWN_TILE
	if absi(d.x) <= SPAWN_ROOM_HALF.x:
		if d.y > 0 and d.y <= 3:
			return true
		if absi(d.y) <= SPAWN_ROOM_HALF.y:
			return false

	# Tunnels: open where the noise is close to zero, which traces winding lines.
	# Y is squashed so tunnels run more sideways than up, which suits a platformer.
	var tunnel := absf(_tunnels.get_noise_2d(tile.x, tile.y * 1.6))
	if tunnel < tunnel_width:
		return false
	# Chambers: open where a second, blobby noise is high.
	return _chambers.get_noise_2d(tile.x, tile.y * 1.3) < chamber_threshold


static func spawn_position() -> Vector2:
	return Vector2(SPAWN_TILE * ChunkData.TILE_PX) + Vector2(ChunkData.TILE_PX / 2.0, 0.0)


static func in_world(chunk_coord: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, WORLD_CHUNKS).has_point(chunk_coord)

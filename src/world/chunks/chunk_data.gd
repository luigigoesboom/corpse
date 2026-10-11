class_name ChunkData
extends RefCounted
## The generated contents of one chunk, as plain data. No nodes.
##
## WorldMap cuts this out of the painted map, the ChunkManager
## turns it into a TileMapLayer on the main thread.

const SIZE := 64          ## Tiles per side.
const TILE_PX := 32       ## Pixels per tile.
const SIZE_PX := SIZE * TILE_PX

## A cell is EMPTY or rock. Rock stores which tile it is and what kind of
## rock (art program, D-028): cell = 1 + tile + TILES * kind, where tile is
## its open-sides mask (0..15), NEAR (16: 2 tiles from air) or DEEP (17: 3+),
## and kind indexes KINDS (RockKinds: flesh, bile, bruise...). One byte holds
## both; tile_of() and kind_of() take it apart.
const EMPTY := 0
const NEAR := 16
const DEEP := 17
## Tiles per kind (16 masks + NEAR + DEEP).
const TILES := 18
## Kinds of rock, in atlas order (each kind is 5 more rows of the atlas):
## the table is RockKinds.
const KINDS := RockKinds.IDS
## Open-sides mask bits: which neighbors are open space.
const OPEN_UP := 1
const OPEN_RIGHT := 2
const OPEN_DOWN := 4
const OPEN_LEFT := 8
## Floors (D-022, D-023): a tile with air above has a 12 px top face drawn
## along its top edge, and its collision starts this many px lower, so feet
## stand in the middle of the face instead of on its back edge. Things placed
## by hand on a floor go at the tile's top edge + FLOOR_SINK; things placed
## by raycast land there anyway.
const FLOOR_SINK := 6

var coord: Vector2i
## SIZE * SIZE cells, row by row. Index with index_of(x, y).
var cells := PackedByteArray()


func _init(chunk_coord: Vector2i) -> void:
	coord = chunk_coord
	cells.resize(SIZE * SIZE)


static func cell_of(tile: int, kind: int) -> int:
	return 1 + tile + TILES * kind


static func tile_of(cell: int) -> int:
	return (cell - 1) % TILES


static func kind_of(cell: int) -> int:
	return (cell - 1) / TILES


static func index_of(x: int, y: int) -> int:
	return y * SIZE + x


static func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / SIZE_PX), floori(world_pos.y / SIZE_PX))


static func chunk_origin(chunk_coord: Vector2i) -> Vector2:
	return Vector2(chunk_coord * SIZE_PX)

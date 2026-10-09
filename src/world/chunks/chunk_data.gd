class_name ChunkData
extends RefCounted
## The generated contents of one chunk, as plain data. No nodes.
##
## The generator fills this in (later on a worker thread), the ChunkManager
## turns it into a TileMapLayer on the main thread.

const SIZE := 64          ## Tiles per side.
const TILE_PX := 32       ## Pixels per tile.
const SIZE_PX := SIZE * TILE_PX

enum Cell { EMPTY, SOLID_EDGE, SOLID_INNER }

var coord: Vector2i
## SIZE * SIZE cells, row by row. Index with index_of(x, y).
var cells := PackedByteArray()


func _init(chunk_coord: Vector2i) -> void:
	coord = chunk_coord
	cells.resize(SIZE * SIZE)


static func index_of(x: int, y: int) -> int:
	return y * SIZE + x


static func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / SIZE_PX), floori(world_pos.y / SIZE_PX))


static func chunk_origin(chunk_coord: Vector2i) -> Vector2:
	return Vector2(chunk_coord * SIZE_PX)

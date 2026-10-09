class_name WorldMap
extends RefCounted
## The hand-painted world, read from a PNG where 1 pixel = 1 tile.
##
## Palette (see docs/ART_PIPELINE.md, "Painting the world"):
##   dark (darker than mid-grey)            -> rock
##   light, or transparent                  -> open space
## Colors are matched loosely, so soft brush edges still read correctly.
## Everything outside the image counts as rock.
##
## Pixels are only looked at when a chunk is cut, so startup time does not grow
## with the size of the map.

const DEFAULT_PATH := "res://data/maps/world.png"

var size: Vector2i
## The painted image as loaded. Also used by the debug map.
var image: Image


static func load_from(path: String = DEFAULT_PATH) -> WorldMap:
	return WorldMap.new(read_image(path))


## Loads the map PNG. Shared with the editor preview.
static func read_image(path: String = DEFAULT_PATH) -> Image:
	var img: Image
	if OS.has_feature("editor"):
		# Read the PNG straight from disk, so a repaint in Krita shows up on the
		# next reload (F4) without restarting or waiting for Godot to reimport.
		img = Image.load_from_file(ProjectSettings.globalize_path(path))
	else:
		# Exported builds only contain Godot's imported copy.
		img = load(path)
	if img == null:
		push_error("WorldMap: could not load %s" % path)
		img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	return img


## The one rule that decides rock vs. open space. The editor preview shader
## (src/world/map_preview.gdshader) uses the same rule; keep them in sync.
static func is_rock_color(c: Color) -> bool:
	return c.a >= 0.5 and c.r + c.g + c.b < 1.5


func _init(img: Image) -> void:
	image = img
	if image.is_compressed():
		image.decompress()
	size = image.get_size()


func is_solid(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= size.x or tile.y >= size.y:
		return true
	return is_rock_color(image.get_pixelv(tile))


## Size of the world in chunks, rounding up. A partial chunk at the edge is
## padded with rock.
func size_in_chunks() -> Vector2i:
	return (size + Vector2i.ONE * (ChunkData.SIZE - 1)) / ChunkData.SIZE


func has_chunk(chunk_coord: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, size_in_chunks()).has_point(chunk_coord)


## Cuts one chunk out of the map as plain data.
func make_chunk(chunk_coord: Vector2i) -> ChunkData:
	var data := ChunkData.new(chunk_coord)
	var origin := chunk_coord * ChunkData.SIZE

	# Copy out the chunk plus a border, so cells near the edge can see into
	# the next chunk. The border is 3 tiles because depth looks 3 tiles deep.
	const B := 3
	var w := ChunkData.SIZE + 2 * B
	var solid := PackedByteArray()
	solid.resize(w * w)
	for y in w:
		for x in w:
			solid[y * w + x] = 1 if is_solid(origin + Vector2i(x - B, y - B)) else 0

	# Depth, one ring at a time: buried = rock whose 4 neighbors are rock,
	# deep1 = buried with 4 buried neighbors, deep2 = the same again.
	var buried := _ring(solid, w, 1)
	var deep1 := _ring(buried, w, 2)
	var deep2 := _ring(deep1, w, 3)

	for y in ChunkData.SIZE:
		for x in ChunkData.SIZE:
			var i := (y + B) * w + (x + B)
			var cell := ChunkData.EMPTY
			if deep2[i]:
				cell = ChunkData.DEEP
			elif deep1[i]:
				cell = ChunkData.NEAR
			elif solid[i]:
				# Which sides face open space picks the tile (rims, rounded corners).
				# Buried rock (mask 0) uses a tile without collision.
				var open := 0
				if not solid[i - w]: open |= ChunkData.OPEN_UP
				if not solid[i + 1]: open |= ChunkData.OPEN_RIGHT
				if not solid[i + w]: open |= ChunkData.OPEN_DOWN
				if not solid[i - 1]: open |= ChunkData.OPEN_LEFT
				cell = 1 + open
			data.cells[ChunkData.index_of(x, y)] = cell
	return data


## Cells set in `src` whose 4 neighbors are also set. Only computed `margin`
## cells in from the edge of the w x w grid, where all neighbors exist.
static func _ring(src: PackedByteArray, w: int, margin: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * w)
	for y in range(margin, w - margin):
		for x in range(margin, w - margin):
			var i := y * w + x
			if src[i] and src[i - 1] and src[i + 1] and src[i - w] and src[i + w]:
				out[i] = 1
	return out

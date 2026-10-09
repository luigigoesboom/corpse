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

	# Copy out the chunk plus a 1-tile border, so edge cells can see their
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
				# Only rock next to open space gets collision. Inner rock never
				# touches the player, and skipping it saves thousands of shapes.
				var buried := solid[i - 1] and solid[i + 1] and solid[i - w] and solid[i + w]
				cell = ChunkData.Cell.SOLID_INNER if buried else ChunkData.Cell.SOLID_EDGE
			data.cells[ChunkData.index_of(x, y)] = cell
	return data

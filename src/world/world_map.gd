class_name WorldMap
extends RefCounted
## The hand-painted world, read from a PNG where 1 pixel = 1 tile.
##
## Palette (see docs/ART_PIPELINE.md, "Painting the world"):
##   dark (darker than mid-grey)            -> rock
##   magenta (255, 0, 255)                  -> a membrane (open space with a
##                                             springy one-way floor, week 47)
##   light, or transparent                  -> open space
## Colors are matched loosely, so soft brush edges still read correctly.
## Everything outside the image counts as rock.
##
## Pixels are only looked at when a chunk is cut, so startup time does not grow
## with the size of the map.

const DEFAULT_PATH := "res://data/maps/world.png"
## Kinds of rock (D-028): a second painting the same size as world.png.
## Transparent = flesh; otherwise the nearest paint color in RockKinds.
const KINDS_PATH := "res://data/maps/tiles.png"
## Regions (week 46, D-030): a third painting the same size, each region in
## its Regions paint color; unpainted, or outside it, is the Gut.
const REGIONS_PATH := "res://data/maps/regions.png"

## The body's rot (D-033), copied from WorldData by Game whenever it changes
## (set_rot()): heavy rot turns rock into rot rock, with a ragged edge.
static var _rot := PackedByteArray()
static var _rot_width := 0
static var _rot_kind := -1

## The regions painting, read once (forget_regions() reads it again).
static var _regions: Image
static var _regions_read := false

var size: Vector2i
## The painted image as loaded. Also used by the debug map.
var image: Image
## The kinds painting, or null (all flesh).
var kinds: Image


static func load_from(path: String = DEFAULT_PATH) -> WorldMap:
	var map := WorldMap.new(read_image(path))
	if path == DEFAULT_PATH and (ResourceLoader.exists(KINDS_PATH) or FileAccess.file_exists(KINDS_PATH)):
		map.kinds = read_image(KINDS_PATH)
	return map


## Which region a tile is in (a Regions id).
static func region_at(tile: Vector2i) -> StringName:
	if not _regions_read:
		_regions_read = true
		_regions = read_image(REGIONS_PATH) if FileAccess.file_exists(REGIONS_PATH) or ResourceLoader.exists(REGIONS_PATH) else null
	if _regions == null or tile.x < 0 or tile.y < 0 or tile.x >= _regions.get_width() or tile.y >= _regions.get_height():
		return Regions.GUT
	return Regions.of_paint(_regions.get_pixelv(tile))


## Which region a point in the world (px) is in.
static func region_of(point: Vector2) -> StringName:
	return region_at(Vector2i((point / ChunkData.TILE_PX).floor()))


## How much of a screen around a point is in a region (0..1).
static func region_share(at: Vector2, region: StringName) -> float:
	var n := 0
	var inside := 0
	for dy in [-160.0, 0.0, 160.0]:
		for dx in [-300.0, -150.0, 0.0, 150.0, 300.0]:
			n += 1
			if region_of(at + Vector2(dx, dy)) == region:
				inside += 1
	return inside / float(n)


## Makes region_at() read the painting again (F4 reloads the map).
static func forget_regions() -> void:
	_regions_read = false


## Which kind of rock a tile is (index into ChunkData.KINDS): as painted,
## unless the rot has taken it.
func kind_at(tile: Vector2i) -> int:
	if rotten(tile):
		return _rot_kind
	return painted_kind_at(tile)


## The kind painted in tiles.png, rot or no rot.
func painted_kind_at(tile: Vector2i) -> int:
	if kinds == null or tile.x < 0 or tile.y < 0 or tile.x >= kinds.get_width() or tile.y >= kinds.get_height():
		return 0
	return kind_of_color(kinds.get_pixelv(tile))


static func set_rot(field: PackedByteArray, width: int) -> void:
	_rot = field
	_rot_width = width
	_rot_kind = RockKinds.IDS.find(&"rot")


## Whether rot has turned this tile: heavy rot in its cell, more surely the
## heavier, so the edge of a rotten patch is ragged (a hash per tile).
static func rotten(tile: Vector2i) -> bool:
	if _rot_width <= 0 or tile.x < 0 or tile.y < 0:
		return false
	var c := tile / Rot.CELL
	var i := c.y * _rot_width + c.x
	if c.x >= _rot_width or i >= _rot.size():
		return false
	var level := _rot[i] / 255.0
	if level < Rot.HEAVY - 0.15:
		return false
	return level > Rot.HEAVY - 0.15 + (hash(tile) % 1000) / 1000.0 * 0.3


## How much of each kind of rock is painted around a world point: a grid of
## samples over about a screen, as fractions (one per ChunkData.KINDS) that
## add up to 1. `kinds_image` may be null (then it is all flesh). Used by the
## backdrop's tint and the ambience (week 40).
static func kind_weights(kinds_image: Image, at: Vector2) -> Array:
	var out := []
	out.resize(ChunkData.KINDS.size())
	out.fill(0.0)
	if kinds_image == null:
		out[0] = 1.0
		return out
	var tile := Vector2i((at / ChunkData.TILE_PX).floor())
	var n := 0
	for dy in range(-8, 9, 4):
		for dx in range(-12, 13, 4):
			var p := tile + Vector2i(dx, dy)
			var kind := 0
			if rotten(p):
				kind = _rot_kind
			elif p.x >= 0 and p.y >= 0 and p.x < kinds_image.get_width() and p.y < kinds_image.get_height():
				kind = kind_of_color(kinds_image.get_pixelv(p))
			out[kind] += 1.0
			n += 1
	for k in out.size():
		out[k] /= n
	return out


## The kind a painted color means (index into ChunkData.KINDS).
static func kind_of_color(c: Color) -> int:
	return RockKinds.of_paint(c)


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


## Membranes (week 47) are painted magenta. They are not solid: rock sees
## them as open space, and things fall through them; only the host lands.
static func is_membrane_color(c: Color) -> bool:
	return c.a >= 0.5 and c.r > 0.7 and c.b > 0.7 and c.g < 0.35


func is_membrane(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= size.x or tile.y >= size.y:
		return false
	return is_membrane_color(image.get_pixelv(tile))


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
			var kind := kind_at(origin + Vector2i(x, y)) if solid[i] else 0
			if not solid[i]:
				var here := origin + Vector2i(x, y)
				if is_membrane(here):
					# Which ends are free: pinned to rock or joined to more membrane.
					var variant := (0 if is_membrane(here + Vector2i.LEFT) else 1) + (0 if is_membrane(here + Vector2i.RIGHT) else 2)
					cell = ChunkData.membrane_cell(variant)
			elif deep2[i]:
				cell = ChunkData.cell_of(ChunkData.DEEP, kind)
			elif deep1[i]:
				cell = ChunkData.cell_of(ChunkData.NEAR, kind)
			elif solid[i]:
				# Which sides face open space picks the tile (rims, rounded corners).
				# Buried rock (mask 0) uses a tile without collision.
				var open := 0
				if not solid[i - w]: open |= ChunkData.OPEN_UP
				if not solid[i + 1]: open |= ChunkData.OPEN_RIGHT
				if not solid[i + w]: open |= ChunkData.OPEN_DOWN
				if not solid[i - 1]: open |= ChunkData.OPEN_LEFT
				cell = ChunkData.cell_of(open, kind)
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

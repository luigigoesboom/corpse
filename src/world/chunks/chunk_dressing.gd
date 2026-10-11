class_name ChunkDressing
extends Node2D
## The stuff on the rock of one chunk (D-028): cilia, teeth, polyps and drips
## on flesh, crystals and slime on bile, ribs and shards on bone, mushrooms
## and roots on rot... drawn from assets/art/tiles/dressing.png (made by
## tools/pixel/recipes/dressing.gd). Only a view: nothing to save, no
## collision. Where things grow is a hash of the tile's world position, so a
## place always looks the same. The ChunkManager adds one to each chunk's
## TileMapLayer when it is built.

const BODY := preload("res://assets/art/tiles/dressing.png")
const GLOW := preload("res://assets/art/tiles/dressing_glow.png")
const BIG_BODY := preload("res://assets/art/tiles/dressing_big.png")
const BIG_GLOW := preload("res://assets/art/tiles/dressing_big_glow.png")
const ROWS := 5
const BIG := 64
const BIG_PER := 4
## Chance that a floor / ceiling tile carries one of the big pieces instead.
const BIG_DENSITY := [0.07, 0.08]
## Chance that buried rock shows something inside it.
const INLAY_DENSITY := 0.16
## How dark inlays are drawn (they are inside the rock).
const INLAY_TINT := Color(0.55, 0.5, 0.5)
const UNSHADED := preload("res://assets/materials/unshaded.tres")
const S := 32
const PER := 6
## Chance that a floor / ceiling / wall tile has something on it.
const DENSITY := [0.85, 0.65, 0.4, 0.4]
## Where a thing's 32 px cell goes, relative to its tile's top left corner:
## floors stand on the middle of the paved face (D-022), ceilings hang just
## under the rim, walls grow out of the rim.
const PLACE := [Vector2(0, 9 - S), Vector2(0, S - 3), Vector2(S - 4, 0), Vector2(4 - S, 0)]

var _items: Array = []  # [dest Rect2, source Rect2, texture, tint]
var _glow: GlowLayer


func setup(data: ChunkData) -> void:
	var origin := data.coord * ChunkData.SIZE
	for i in data.cells.size():
		var cell := data.cells[i]
		if cell == ChunkData.EMPTY or ChunkData.is_membrane(cell):
			continue
		var tile := ChunkData.tile_of(cell)
		var kind := ChunkData.kind_of(cell)
		var at := Vector2i(i % ChunkData.SIZE, i / ChunkData.SIZE)
		if tile >= 16 or tile == 0:  # Buried rock: now and then something inside it.
			var hb := hash(Vector3i(origin.x + at.x, origin.y + at.y, 9))
			if (hb % 1000) / 1000.0 < INLAY_DENSITY:
				var shift := Vector2((hb / 1000) % 9 - 4, (hb / 9000) % 9 - 4)
				_items.append([Rect2(Vector2(at * S) + shift, Vector2(S, S)), Rect2(((hb / 81000) % PER) * S, (kind * ROWS + 4) * S, S, S), BODY, INLAY_TINT])
			continue
		var sides := [tile & ChunkData.OPEN_UP, tile & ChunkData.OPEN_DOWN, tile & ChunkData.OPEN_RIGHT, tile & ChunkData.OPEN_LEFT]
		for row in 4:
			if sides[row] == 0:
				continue
			var h := hash(Vector3i(origin.x + at.x, origin.y + at.y, row))
			if row < 2 and (h % 997) / 997.0 < BIG_DENSITY[row]:
				var v := (h / 997) % BIG_PER
				var big_at := Vector2(at * S) + (Vector2(-16, 9 - BIG) if row == 0 else Vector2(-16, S - 3))
				_items.append([Rect2(big_at, Vector2(BIG, BIG)), Rect2(v * BIG, (kind * 2 + row) * BIG, BIG, BIG), BIG_BODY, Color.WHITE])
				continue
			if (h % 1000) / 1000.0 >= DENSITY[row]:
				continue
			var variant := (h / 1000) % PER
			var shift := float((h / 7000) % 13 - 6) if row < 2 else float((h / 7000) % 9 - 4)
			var offset: Vector2 = PLACE[row] + (Vector2(shift, 0) if row < 2 else Vector2(0, shift))
			var dest := Rect2(Vector2(at * S) + offset, Vector2(S, S))
			var source := Rect2(variant * S, (kind * ROWS + row) * S, S, S)
			_items.append([dest, source, BODY, Color.WHITE])
	_glow = GlowLayer.new()
	_glow.items = _items
	_glow.material = UNSHADED
	add_child(_glow)
	queue_redraw()


func _draw() -> void:
	# Inlays first (they are in the rock), then everything on it.
	for item in _items:
		if item[3] != Color.WHITE:
			draw_texture_rect_region(item[2], item[0], item[1], item[3])
	for item in _items:
		if item[3] == Color.WHITE:
			draw_texture_rect_region(item[2], item[0], item[1])


func count() -> int:
	return _items.size()


## The glowing bits, unshaded so they shine in the dark.
class GlowLayer extends Node2D:
	var items: Array = []

	func _draw() -> void:
		for item in items:
			if item[3] == Color.WHITE:
				draw_texture_rect_region(BIG_GLOW if item[2] == BIG_BODY else GLOW, item[0], item[1])

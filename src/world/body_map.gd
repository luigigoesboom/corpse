class_name BodyMap
extends RefCounted
## What the body-wide simulations (Rot, D-033) need to know about the painted
## map, as plain data: the world layer reads the map and the placed things,
## the sim never touches nodes. One cell = Rot.CELL x Rot.CELL tiles.
##
##   {"w", "h",
##    "air": PackedByteArray (1 = the cell has open space),
##    "region": PackedByteArray (index into Regions.IDS),
##    "painted": PackedByteArray (rot painted in tiles.png, 0..255),
##    "places": [{"kind": "settlement"|"ruin"|"landmark", "cell", "slot"|"name", "region"}]}


static func context(map: WorldMap, templates: Array, landmarks: Array) -> Dictionary:
	var size := Rot.grid_size(map.size)
	var n := size.x * size.y
	var air := PackedByteArray()
	var region := PackedByteArray()
	var painted := PackedByteArray()
	air.resize(n)
	region.resize(n)
	painted.resize(n)
	var rot_kind := RockKinds.IDS.find(&"rot")
	for cy in size.y:
		for cx in size.x:
			var open := 0
			var rotten := 0
			var rock := 0
			for y in range(cy * Rot.CELL, mini((cy + 1) * Rot.CELL, map.size.y)):
				for x in range(cx * Rot.CELL, mini((cx + 1) * Rot.CELL, map.size.x)):
					var t := Vector2i(x, y)
					if map.is_solid(t):
						rock += 1
						if map.painted_kind_at(t) == rot_kind:
							rotten += 1
					else:
						open += 1
			var i := cy * size.x + cx
			air[i] = 1 if open > 0 else 0
			painted[i] = clampi(int(255.0 * rotten / maxf(1.0, rock) * 0.85), 0, 255)
			var middle := Vector2i(cx * Rot.CELL + Rot.CELL / 2, cy * Rot.CELL + Rot.CELL / 2)
			region[i] = maxi(0, Regions.IDS.find(WorldMap.region_at(middle)))
	var ctx := {"w": size.x, "h": size.y, "air": air, "region": region, "painted": painted, "places": []}
	for t in templates:
		var place := {}
		if t is GuardPost:
			continue
		if t is Settlement:
			place = {"kind": "settlement", "slot": EntityLayer.key_of(t)}
		elif t is RuinSite:
			place = {"kind": "ruin", "slot": EntityLayer.key_of(t)}
		else:
			continue
		place.cell = Rot.cell_of_point(ctx, t.global_position + Vector2(0, -40))
		place.region = WorldMap.region_of(t.global_position)
		ctx.places.append(place)
	for l in landmarks:
		ctx.places.append({"kind": "landmark", "name": l.title, "cell": Rot.cell_of_point(ctx, l.global_position), "region": WorldMap.region_of(l.global_position)})
	return ctx

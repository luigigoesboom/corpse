class_name RockKinds
extends RefCounted
## Every kind of rock in one table (week 46; before this the list was copied
## into eight files). IDS is the order of the tile atlas (each kind is 5
## more rows of gut_tiles.png) and what a ChunkData cell stores, so new
## kinds go at the end and old ones never move.
##
## Adding a kind: a row in IDS and INFO, its ramp in assets/art/_source/
## gut.gpl, then run the tiles, dressing and sound recipes and paint it into
## data/maps/tiles.png (docs/ART_PIPELINE.md, "Kinds of rock").

const IDS := [&"flesh", &"bile", &"bruise", &"bone", &"rot", &"alveolus", &"cartilage"]

## id -> what goes with it:
##   ramp    the palette ramp its tiles and dressing are drawn in
##   paint   its color in data/maps/tiles.png (flesh is the unpainted default)
##   tint    how it tints the backdrop around it (src/world/backdrop.gd)
##   map     its walls on the minimap
##   sound   its ambience layer: [loudest dB, pitch for the pack's copy]
##   texture how its tiles are drawn (tools/pixel/recipes/tiles.gd):
##           cobble (lumps), honeycomb (round cells), rings (bands)
const INFO := {
	&"flesh": {"ramp": &"flesh", "paint": Color(0, 0, 0, 0), "tint": Color(1.0, 1.0, 1.0),
		"map": Color8(180, 72, 76), "sound": [-12.0, 0.9], "texture": "cobble"},
	&"bile": {"ramp": &"rock_bile", "paint": Color8(150, 180, 40), "tint": Color(0.72, 1.0, 0.5),
		"map": Color8(150, 168, 52), "sound": [-14.0, 0.5], "texture": "cobble"},
	&"bruise": {"ramp": &"rock_bruise", "paint": Color8(110, 60, 170), "tint": Color(0.72, 0.58, 1.15),
		"map": Color8(138, 96, 164), "sound": [-12.0, 0.8], "texture": "cobble"},
	&"bone": {"ramp": &"rock_bone", "paint": Color8(210, 200, 170), "tint": Color(0.9, 0.86, 0.82),
		"map": Color8(184, 172, 146), "sound": [-14.0, 0.75], "texture": "cobble"},
	&"rot": {"ramp": &"rock_rot", "paint": Color8(140, 85, 40), "tint": Color(1.0, 0.78, 0.5),
		"map": Color8(164, 114, 62), "sound": [-12.0, 1.0], "texture": "cobble"},
	# The Lungs (week 47): spongy lung and the rings of the airways.
	&"alveolus": {"ramp": &"rock_alveolus", "paint": Color8(230, 120, 170), "tint": Color(1.05, 0.86, 0.95),
		"map": Color8(200, 128, 142), "sound": [-13.0, 1.0], "texture": "honeycomb"},
	&"cartilage": {"ramp": &"rock_cartilage", "paint": Color8(150, 190, 220), "tint": Color(0.86, 0.92, 1.05),
		"map": Color8(170, 178, 196), "sound": [-14.0, 0.85], "texture": "rings"},
}


static func count() -> int:
	return IDS.size()


static func ramp(kind: StringName) -> StringName:
	return INFO[kind].ramp


static func tint(kind: StringName) -> Color:
	return INFO[kind].tint


static func map_color(kind: StringName) -> Color:
	return INFO[kind].map


static func sound(kind: StringName) -> Array:
	return INFO[kind].sound


static func texture(kind: StringName) -> String:
	return INFO[kind].get("texture", "cobble")


## The kind a color painted in tiles.png means (an index into IDS):
## transparent is flesh, otherwise the nearest paint color.
static func of_paint(c: Color) -> int:
	if c.a < 0.5:
		return 0
	var best := 0
	var best_d := INF
	for i in IDS.size():
		var p: Color = INFO[IDS[i]].paint
		if p.a < 0.5:
			continue
		var d := Vector3(c.r - p.r, c.g - p.g, c.b - p.b).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best

class_name Regions
extends RefCounted
## The body's regions (week 46, D-030): the Gut, the Lungs, later the Bones,
## the Nerves, the Wound and the Heart. Plain data, for the sim and the world.
##
## Each region has its own past: peoples arrive, grow, fight and fall inside
## one region (HistorySim runs once per region with its own generator), until
## cross-region history (roadmap week 70) lets them move between them. Every
## FactionData and SiteData says which region it belongs to.
##
## Where a region lies is painted: data/maps/regions.png, the same size as
## world.png, each region in its `paint` color (unpainted = the Gut).
## WorldMap.region_at() reads it.
##
## Per region (INFO):
##   name       how text names it ("the Lungs")
##   paint      its color in regions.png
##   capacity   how many people it can feed (history: the fuller, the slower
##              everyone grows and the readier neighbours are to fight)
##   history    whether its past is simulated yet
##   from       where newcomers say they came from (history)
##   goods      what its peoples trade (history)

const GUT := &"gut"
const LUNGS := &"lungs"
## In order: the order history runs them in. New regions go at the end.
const IDS := [GUT, LUNGS]

const INFO := {
	&"gut": {
		"name": "the Gut", "paint": Color8(200, 70, 70), "capacity": 2600, "history": true,
		"from": ["the Wound", "the upper veins", "the lung-dark", "a burst artery", "the scar tissue"],
		"goods": ["bile and salt", "dried gut-meat", "bone tools", "lamp oil", "spores", "relics", "cartilage"],
	},
	&"lungs": {
		"name": "the Lungs", "paint": Color8(110, 170, 230), "capacity": 1500, "history": true,
		"from": ["the windpipe", "the Gut below", "a collapsed lobe", "the far bronchi", "the Wound"],
		"goods": ["woven membrane", "breath-bladders", "cartilage", "dried spores", "kite silk", "bone pins"],
	},
}


static func display_name(region: StringName) -> String:
	return INFO.get(region, INFO[GUT]).name


static func info(region: StringName) -> Dictionary:
	return INFO.get(region, INFO[GUT])


## The region a color painted in regions.png means: the nearest paint color
## (unpainted is the Gut).
static func of_paint(c: Color) -> StringName:
	if c.a < 0.5:
		return GUT
	var best: StringName = GUT
	var best_d := INF
	for id in IDS:
		var p: Color = INFO[id].paint
		var d := Vector3(c.r - p.r, c.g - p.g, c.b - p.b).length_squared()
		if d < best_d:
			best_d = d
			best = id
	return best

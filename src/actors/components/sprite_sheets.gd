class_name SpriteSheets
extends RefCounted
## Builds SpriteFrames (Godot's animation set for AnimatedSprite2D) from a
## folder of PNG strips, so new art needs no setup in the editor:
##
##   <folder>/<anything>_<animation>.png
##
## One horizontal strip per animation, square frames: the strip's height is the
## frame size and width / height is the number of frames. So gut_leech_move.png
## at 192 x 48 is 4 frames of 48 x 48 for the animation "move".
## Speeds come from FPS below; animations in ONE_SHOT play once and stop.

const FPS := {
	&"idle": 5.0, &"run": 10.0, &"move": 8.0, &"jump": 8.0, &"fall": 8.0, &"cling": 6.0,
	&"windup": 8.0, &"attack": 16.0, &"hurt": 10.0, &"die": 8.0,
}
const DEFAULT_FPS := 8.0
const ONE_SHOT: Array[StringName] = [&"windup", &"attack", &"hurt", &"die"]

static var _cache := {}


static func load_dir(dir: String) -> SpriteFrames:
	if _cache.has(dir):
		return _cache[dir]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var pngs := {}
	for file in DirAccess.get_files_at(dir):
		# Exported builds list "x.png.import" instead of "x.png".
		file = file.trim_suffix(".import")
		if file.ends_with(".png"):
			pngs[file] = true
	for file in pngs:
		var base: String = file.get_basename()
		var anim := StringName(base.get_slice("_", base.get_slice_count("_") - 1))
		var texture: Texture2D = load(dir.path_join(file))
		var size := texture.get_height()
		frames.add_animation(anim)
		frames.set_animation_speed(anim, FPS.get(anim, DEFAULT_FPS))
		frames.set_animation_loop(anim, not anim in ONE_SHOT)
		for i in maxi(1, texture.get_width() / size):
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(i * size, 0, size, size)
			frames.add_frame(anim, frame)
	_cache[dir] = frames
	return frames

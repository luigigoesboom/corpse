class_name LayeredSprite
extends Node2D
## Frame-by-frame pixel animation in layers (D-017).
##
## The body plays an animation. Extra layers (mutation parts, gear) are sheets
## drawn over the same frames: they show the same animation and frame as the
## body, in front of it or behind it, so parts move with the body without
## redrawing it. A layer that lacks the current animation is hidden.
##
## A "glow" sheet (eyes, glands) is drawn unshaded, so it shines in the dark.
## Frames come from folders of PNG strips, see SpriteSheets.

signal animation_finished(animation: StringName)

## Folder of the body's strips, e.g. res://assets/art/creatures/gut_leech.
@export_dir var body_frames_dir: String
## Optional folder of strips drawn unshaded on top (glowing eyes etc.).
@export_dir var glow_frames_dir: String
## Shifts every frame, e.g. (0, -24) so a 48 px frame stands on the node's origin.
@export var frame_offset := Vector2.ZERO

const UNSHADED := preload("res://assets/materials/unshaded.tres")

var _body: AnimatedSprite2D
var _layers := {}  # StringName id -> AnimatedSprite2D


func _ready() -> void:
	_body = _make_sprite(SpriteSheets.load_dir(body_frames_dir))
	add_child(_body)
	_body.frame_changed.connect(_sync)
	_body.animation_changed.connect(_sync)
	_body.animation_finished.connect(func(): animation_finished.emit(_body.animation))
	if glow_frames_dir != "":
		add_layer(&"glow", SpriteSheets.load_dir(glow_frames_dir), false, UNSHADED)
	play(&"idle")


## Plays an animation, unless it is already the current one. A one-shot
## animation (die, attack...) that has finished stays on its last frame for as
## long as it keeps being asked for. Falls back to "idle", then to the first animation.
func play(animation: StringName) -> void:
	if not _body.sprite_frames.has_animation(animation):
		animation = &"idle"
		if not _body.sprite_frames.has_animation(animation):
			animation = _body.sprite_frames.get_animation_names()[0]  # E.g. a flyer only has "move".
	if _body.animation == animation:
		if _body.is_playing() or not _body.sprite_frames.get_animation_loop(animation):
			return
	_body.play(animation)


func current_animation() -> StringName:
	return _body.animation


func is_playing() -> bool:
	return _body.is_playing()


func add_layer(id: StringName, frames: SpriteFrames, behind := false, layer_material: Material = null) -> void:
	remove_layer(id)
	var sprite := _make_sprite(frames)
	sprite.name = String(id)
	if layer_material:
		sprite.material = layer_material
		sprite.use_parent_material = false
	add_child(sprite)
	if behind:
		move_child(sprite, 0)  # Drawn before (under) the body.
	_layers[id] = sprite
	_sync()


func remove_layer(id: StringName) -> void:
	if _layers.has(id):
		_layers[id].queue_free()
		_layers.erase(id)


func has_layer(id: StringName) -> bool:
	return _layers.has(id)


func _sync() -> void:
	for sprite: AnimatedSprite2D in _layers.values():
		if sprite.sprite_frames.has_animation(_body.animation):
			sprite.visible = true
			sprite.animation = _body.animation
			sprite.frame = mini(_body.frame, sprite.sprite_frames.get_frame_count(_body.animation) - 1)
		else:
			sprite.visible = false


func _make_sprite(frames: SpriteFrames) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.offset = frame_offset
	sprite.use_parent_material = true
	return sprite

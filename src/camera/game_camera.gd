class_name GameCamera
extends Node2D
## The game camera, run by the Phantom Camera addon (addons/phantom_camera):
## a Camera2D with a PhantomCameraHost, one PhantomCamera2D that follows
## `target`, and a noise emitter for screen shake. Add game_camera.tscn to any
## scene with a player and point `target` at it.
##
## Framing (D-023): the target stands low on screen, like Blasphemous, so most
## of the view is the space you move through rather than the rock under your
## feet. The view leads the way the target faces. Falling fast swings the view
## down to show where you will land.
## Phantom Camera concepts: the PhantomCamera2D decides where the view should
## be (follow mode, offset, damping, lookahead); the host moves the real
## Camera2D there every physics frame.

const PCam2D := preload("res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_2d.gd")
const PCamHost := preload("res://addons/phantom_camera/scripts/phantom_camera_host/phantom_camera_host.gd")
const NoiseEmitter2D := preload("res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_noise_emitter_2d.gd")
const Noise2D := preload("res://addons/phantom_camera/scripts/resources/phantom_camera_noise_2d.gd")
const SHAKE_LAYER := 1

@export var target: Node2D
## How far above the target the view is centred, in px (360 px tall view).
@export var framing_height := 72.0
## Falling faster than this (px/s) swings the view down...
@export var fall_look_speed := 450.0
## ...until the target is this far above the centre instead.
@export var fall_framing_height := -40.0
## How fast the framing swings between the two, in px/s.
@export var framing_speed := 260.0
## Damping per axis in seconds: higher is lazier. Vertical is lazier so small
## jumps do not bob the whole view.
@export var damping := Vector2(0.12, 0.22)
## How far the view leads in the direction the target faces, in px. Facing
## based, not velocity based: stopping does not swing the view back (that read
## as bouncing); only turning around pans it across.
@export var lead := 48.0
## How fast the lead pans across when turning, in px/s.
@export var lead_speed := 150.0

var pcam: Node2D
var camera: Camera2D
var _shake: Node


func _ready() -> void:
	# After the PhantomCameraHost (300) has placed the camera this physics step.
	process_physics_priority = 301
	camera = Camera2D.new()
	camera.name = "Camera2D"
	# Physics interpolation is on (project setting): the camera must move in
	# physics frames too, or Godot switches it and warns.
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.add_child(PCamHost.new())

	pcam = PCam2D.new()
	pcam.name = "FollowCam"
	pcam.priority = 10
	pcam.follow_mode = PCam2D.FollowMode.SIMPLE
	pcam.follow_offset = Vector2(0, -framing_height)
	pcam.follow_damping = true
	pcam.follow_damping_value = damping
	# No snap_to_pixel: see _physics_process for how the camera stays on the
	# pixel grid relative to the target instead.
	pcam.noise_emitter_layer = SHAKE_LAYER
	if target:
		pcam.global_position = target.global_position + pcam.follow_offset
		pcam.follow_target = target
		if target.has_signal(&"teleported"):
			target.connect(&"teleported", snap)
	add_child(pcam)

	_shake = NoiseEmitter2D.new()
	_shake.name = "Shake"
	var noise = Noise2D.new()
	noise.frequency = 6.0
	_shake.noise = noise
	_shake.duration = 0.06
	_shake.decay_time = 0.18
	_shake.noise_emitter_layer = SHAKE_LAYER
	add_child(_shake)
	EventBus.shake_requested.connect(shake)


func _physics_process(delta: float) -> void:
	if target == null or not ("velocity" in target):
		return
	var velocity: Vector2 = target.get(&"velocity")
	var height := fall_framing_height if velocity.y > fall_look_speed else framing_height
	var facing: float = target.call(&"facing") if target.has_method(&"facing") else 1.0
	var offset: Vector2 = pcam.follow_offset
	offset.x = move_toward(offset.x, facing * lead, lead_speed * delta)
	offset.y = move_toward(offset.y, -height, framing_speed * delta)
	pcam.follow_offset = offset
	# Keep the camera a whole number of pixels away from the target. The
	# project snaps 2D transforms to pixels, rounding target and camera
	# separately; with a fractional gap between them the two roundings
	# disagreed now and then and the player wobbled 1 px while running
	# (measured on rendered frames). A whole-pixel gap rounds the same way.
	var gap := camera.global_position - target.global_position
	camera.global_position = target.global_position + gap.round()


## Jumps straight to the target, skipping damping (after a teleport, a load).
func snap() -> void:
	var facing: float = target.call(&"facing") if target and target.has_method(&"facing") else 1.0
	pcam.follow_offset = Vector2(facing * lead, -framing_height)
	pcam.teleport_position()
	camera.reset_physics_interpolation()


## A short screen shake. `strength` is roughly the peak offset in px.
func shake(strength: float) -> void:
	strength *= Settings.screen_shake  # Settings: some players want none (week 41).
	if strength <= 0.0:
		return
	_shake.noise.amplitude = strength
	_shake.emit()

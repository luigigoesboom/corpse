class_name GameCamera
extends Node2D
## The game camera, run by the Phantom Camera addon (addons/phantom_camera):
## a Camera2D with a PhantomCameraHost, one PhantomCamera2D that follows
## `target`, and a noise emitter for screen shake. Add game_camera.tscn to any
## scene with a player and point `target` at it.
##
## Framing (D-023): the target stands low on screen, like Blasphemous, so most
## of the view is the space you move through rather than the rock under your
## feet. Falling fast swings the view down to show where you will land.
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
## Seconds of horizontal movement the view leads by (velocity based).
@export var lookahead_time := 0.3
@export var lookahead_max_speed := 260.0

var pcam: Node2D
var camera: Camera2D
var _shake: Node


func _ready() -> void:
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
	pcam.lookahead = true
	pcam.lookahead_time = Vector2(lookahead_time, 0.0)
	pcam.lookahead_max = true
	pcam.lookahead_max_value = Vector2(lookahead_max_speed, 0.0)
	pcam.snap_to_pixel = true  # Whole pixels, so pixel art does not shimmer.
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


func _physics_process(delta: float) -> void:
	if target == null or not ("velocity" in target):
		return
	var velocity: Vector2 = target.get(&"velocity")
	var height := fall_framing_height if velocity.y > fall_look_speed else framing_height
	var offset: Vector2 = pcam.follow_offset
	offset.y = move_toward(offset.y, -height, framing_speed * delta)
	pcam.follow_offset = offset


## Jumps straight to the target, skipping damping (after a teleport, a load).
func snap() -> void:
	pcam.follow_offset = Vector2(0, -framing_height)
	pcam.teleport_position()
	camera.reset_physics_interpolation()


## A short screen shake. `strength` is roughly the peak offset in px.
func shake(strength: float) -> void:
	_shake.noise.amplitude = strength
	_shake.emit()

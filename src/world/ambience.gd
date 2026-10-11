class_name Ambience
extends Node
## The Gut's background sound (week 40): looping layers on the Ambience bus,
## crossfaded by where the camera is.
##   body        always: a slow heartbeat over a low drone, louder deeper down
##   flesh, bile, bruise, bone, rot
##               by the kinds of rock painted around the camera (tiles.png)
##   settlement  near a settlement: people murmuring
##   boss        while a boss fight is on
## Each layer plays assets/audio/ambience/<layer>.wav if the licensed pack's
## copy is there (tools/copy_sfx.sh), else our own generated loop.
## Keeps playing while the game is paused (menus, dialogue).

const PACK_DIR := "res://assets/audio/ambience/"
const OWN_DIR := "res://assets/audio/generated/"
## layer: [loudest dB, pitch for the pack's copy]. Each kind of rock has a
## layer too, from RockKinds.
const LAYERS := {
	&"body": [-8.0, 1.0],
	&"settlement": [-16.0, 1.0],
	&"boss": [-10.0, 1.0],
}
## How fast layers fade in and out (fraction of the way per second).
const FADE := 0.8
## Settlements are heard from this far (px), fully within NEAR.
const SETTLEMENT_RANGE := 600.0
const SETTLEMENT_NEAR := 200.0

var _layers := {}  # LAYERS and the rock kinds' layers
var _players := {}  # layer -> AudioStreamPlayer
var _levels := {}  # layer -> current loudness 0..1
var _kinds: Image
var _boss := false
var _world_height := 4096.0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(WorldMap.KINDS_PATH) or ResourceLoader.exists(WorldMap.KINDS_PATH):
		_kinds = WorldMap.read_image(WorldMap.KINDS_PATH)
		_world_height = _kinds.get_height() * ChunkData.TILE_PX
	_layers = LAYERS.duplicate()
	for kind in RockKinds.IDS:
		_layers[kind] = RockKinds.sound(kind)
	for layer in _layers:
		var player := AudioStreamPlayer.new()
		player.bus = &"Ambience"
		var pack := PACK_DIR + "amb_%s.wav" % layer
		var own := OWN_DIR + "amb_%s.wav" % layer
		if ResourceLoader.exists(pack):
			player.stream = _looping(load(pack))
			player.pitch_scale = _layers[layer][1]
		elif ResourceLoader.exists(own):
			player.stream = _looping(load(own))
		else:
			continue
		player.volume_db = -80.0
		add_child(player)
		player.play()
		_players[layer] = player
		_levels[layer] = 0.0
	EventBus.boss_engaged.connect(func(_boss_node): _boss = true)
	EventBus.boss_defeated.connect(func(_boss_node): _boss = false)
	EventBus.player_died.connect(func(): _boss = false)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var at := camera.get_screen_center_position()
	var targets := targets_at(at)
	for layer in _players:
		_levels[layer] = move_toward(_levels[layer], targets.get(layer, 0.0), delta * FADE)
		var player: AudioStreamPlayer = _players[layer]
		player.volume_db = _layers[layer][0] + linear_to_db(maxf(_levels[layer], 0.0001))


## How loud each layer should be (0..1) with the camera at `at`.
func targets_at(at: Vector2) -> Dictionary:
	var t := {}
	t[&"body"] = lerpf(0.45, 1.0, clampf(at.y / _world_height, 0.0, 1.0))
	var weights := WorldMap.kind_weights(_kinds, at)
	for k in ChunkData.KINDS.size():
		t[ChunkData.KINDS[k]] = weights[k]
	var nearest := INF
	for node in get_tree().get_nodes_in_group(&"settlements"):
		nearest = minf(nearest, (node as Node2D).global_position.distance_to(at))
	t[&"settlement"] = clampf(1.0 - (nearest - SETTLEMENT_NEAR) / (SETTLEMENT_RANGE - SETTLEMENT_NEAR), 0.0, 1.0)
	t[&"boss"] = 1.0 if _boss else 0.0
	if _boss:
		for k in ChunkData.KINDS:
			t[k] *= 0.4  # The fight drowns the cave out.
	return t


## Makes a WAV loop over its whole length (the pack's files are not marked).
static func _looping(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var bytes_per_frame := (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / bytes_per_frame
	return stream

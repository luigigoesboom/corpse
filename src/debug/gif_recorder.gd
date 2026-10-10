class_name GifRecorder
extends Node
## Devlog clips (week 45): F12 starts recording what the game shows, F12
## again stops and writes a GIF to user://captures/ (on Windows
## %APPDATA%\Godot\app_userdata\Corpse\captures). Debug builds only; the
## game adds it. Frames are the game's own 640 x 360 picture, FPS per
## second, at most MAX_SECONDS; encoding runs on a worker thread so the game
## keeps going while the file is written.

const FPS := 15
const MAX_SECONDS := 12.0
const DIR := "user://captures"

var _recording := false
var _frames: Array[Image] = []
var _since := 0.0
var _task := -1


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS  # Menus and dialogue are worth a clip too.


func is_recording() -> bool:
	return _recording


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_record"):
		if _recording:
			stop()
		else:
			start()
		get_viewport().set_input_as_handled()


func start() -> void:
	if _task >= 0:
		EventBus.notify.emit("Still writing the last clip")
		return
	_frames.clear()
	_since = 1.0 / FPS
	_recording = true
	EventBus.notify.emit("Recording (F12 to stop)")
	if not RenderingServer.frame_post_draw.is_connected(_grab):
		RenderingServer.frame_post_draw.connect(_grab)


## Stops and writes the clip. Returns the file it will be written to ("" if
## nothing was recorded).
func stop() -> String:
	_recording = false
	if RenderingServer.frame_post_draw.is_connected(_grab):
		RenderingServer.frame_post_draw.disconnect(_grab)
	if _frames.is_empty():
		return ""
	var path := "%s/corpse_%s.gif" % [DIR, Time.get_datetime_string_from_system().replace(":", "-")]
	var frames := _frames.duplicate()
	_frames.clear()
	EventBus.notify.emit("Writing %d frames..." % frames.size())
	_task = WorkerThreadPool.add_task(_write.bind(frames, path))
	return path


## Waits for the clip being written (tests).
func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _process(delta: float) -> void:
	if _recording:
		_since += delta
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _grab() -> void:
	if not _recording or _since < 1.0 / FPS:
		return
	_since = fmod(_since, 1.0 / FPS)
	_frames.append(get_viewport().get_texture().get_image())
	if _frames.size() >= int(MAX_SECONDS * FPS):
		stop()


func _write(frames: Array, path: String) -> void:
	var err := GifWriter.save(frames, path, 1.0 / FPS)
	var message := "Clip saved: %s" % ProjectSettings.globalize_path(path) if err == OK else "Clip failed: %s" % error_string(err)
	EventBus.notify.emit.call_deferred(message)

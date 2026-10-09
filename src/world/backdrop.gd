extends CanvasLayer
## Feeds the camera position to the backdrop shader every frame.


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		$Wall.material.set_shader_parameter("camera_position", camera.get_screen_center_position())

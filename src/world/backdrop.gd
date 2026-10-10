extends CanvasLayer
## Feeds the backdrop shader every frame: where the camera is, how big the
## view is, and a tint for the kind of rock around the camera (D-028), eased
## so walking from flesh into bile slowly turns the back wall green.

const TINTS := {
	&"flesh": Color(1.0, 1.0, 1.0),
	&"bile": Color(0.72, 1.0, 0.5),
	&"bruise": Color(0.72, 0.58, 1.15),
	&"bone": Color(0.9, 0.86, 0.82),
	&"rot": Color(1.0, 0.78, 0.5),
}
## How fast the tint follows the camera (per second).
const EASE := 1.2

var _kinds: Image
var _tint := Color.WHITE


func _ready() -> void:
	if FileAccess.file_exists(WorldMap.KINDS_PATH) or ResourceLoader.exists(WorldMap.KINDS_PATH):
		_kinds = WorldMap.read_image(WorldMap.KINDS_PATH)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var centre := camera.get_screen_center_position()
	var material: ShaderMaterial = $Wall.material
	material.set_shader_parameter("camera_position", centre)
	material.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	_tint = _tint.lerp(_target_tint(centre), clampf(delta * EASE, 0.0, 1.0))
	material.set_shader_parameter("tint", Vector3(_tint.r, _tint.g, _tint.b))


## The average tint of the kinds of rock painted around a point.
func _target_tint(at: Vector2) -> Color:
	var weights := WorldMap.kind_weights(_kinds, at)
	var sum := Color(0, 0, 0)
	for k in weights.size():
		sum += TINTS[ChunkData.KINDS[k]] * weights[k]
	return sum

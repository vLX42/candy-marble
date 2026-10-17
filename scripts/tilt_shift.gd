class_name TiltShift
extends CanvasLayer
## The miniature look (tilt-shift, scripts/tilt_shift.gdshader) over the 3D
## view: a sharp band on the marble, the rest of the level blurred like a
## close-up photo of a toy model. It sits under the HUD, so text stays sharp.
## Settings.tilt_shift switches it off; fast graphics use fewer blur taps.

const SHADER := preload("res://scripts/tilt_shift.gdshader")

## Screen height (0 top, 1 bottom) of the sharp band.
var focus := 0.5
var _mat: ShaderMaterial


func _ready() -> void:
	layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	rect.material = _mat
	add_child(rect)
	_mat.set_shader_parameter("focus", focus)
	_apply()
	Settings.changed.connect(_apply)


func _apply() -> void:
	visible = Settings.tilt_shift
	_mat.set_shader_parameter("taps", 20 if Settings.graphics_high else 10)


## Glide the sharp band to where this world point is on screen.
func follow(camera: Camera3D, world_pos: Vector3, delta: float) -> void:
	if not visible or not camera:
		return
	var h := get_viewport().get_visible_rect().size.y
	var y := clampf(camera.unproject_position(world_pos).y / maxf(h, 1.0), 0.2, 0.8)
	focus = lerpf(focus, y, 1.0 - exp(-delta * 5.0))
	_mat.set_shader_parameter("focus", focus)

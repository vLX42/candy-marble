extends CanvasLayer
## Autoload: candy iris wipe between scenes. The circle closes on a pink
## sprinkle screen, the next scene loads behind it, then it opens again, so
## loading hitches never show.
##   Transition.go("res://scenes/main.tscn")

const SHADER := """
shader_type canvas_item;
uniform float radius = 1.5;
uniform vec2 aspect = vec2(1.777, 1.0);
void fragment() {
	vec2 p = (UV - 0.5) * aspect;
	float d = length(p);
	if (d < radius) discard;
	vec3 pink = vec3(0.969, 0.698, 0.753);
	vec3 cream = vec3(1.0, 0.957, 0.878);
	// Sprinkle dots on a soft diagonal stripe.
	vec2 g = fract(UV * aspect * 9.0 + vec2(0.0, TIME * 0.2)) - 0.5;
	float dots = smoothstep(0.16, 0.12, length(g));
	float stripe = step(0.5, fract((UV.x * aspect.x + UV.y) * 5.0));
	vec3 col = mix(pink, mix(pink, cream, 0.35), stripe);
	col = mix(col, cream, dots * 0.8);
	// Chocolate rim just outside the opening.
	float rim = smoothstep(radius + 0.03, radius, d);
	col = mix(col, vec3(0.353, 0.204, 0.149), rim);
	COLOR = vec4(col, 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var busy := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)


func go(path: String) -> void:
	if busy:
		return
	busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.visible = true
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", Vector2(vp.x / maxf(vp.y, 1.0), 1.0))
	_set_radius(1.2)
	var tw := create_tween()
	tw.tween_method(_set_radius, 1.2, 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	# Let the new scene build (and hitch) behind the closed iris.
	for i in 3:
		await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_method(_set_radius, 0.0, 1.2, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_rect.visible = false
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false


func _set_radius(r: float) -> void:
	_mat.set_shader_parameter("radius", r)

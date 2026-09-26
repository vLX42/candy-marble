extends Node3D
## Builds the greybox level: environment, island, entities, camera and HUD.

const BallScene := preload("res://scenes/ball.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const BumperScene := preload("res://scenes/bumper.tscn")
const BoosterScene := preload("res://scenes/booster.tscn")
const GoalScene := preload("res://scenes/goal.tscn")

const CAMERA_ROTATION := Vector3(-35.264, 45.0, 0.0)  # true isometric
const CAMERA_SIZE := 16.0
const CAMERA_FOLLOW := 5.0

var ball: Ball
var camera: Camera3D
var hud_status: Label
var hud_message: Label
var elapsed := 0.0
var falls := 0
var finished := false


func _ready() -> void:
	_setup_input()
	_setup_environment()
	add_child(Terrain.new())
	_spawn_entities()
	_setup_camera()
	_setup_hud()


func _setup_input() -> void:
	var keys := {
		"up": [KEY_W, KEY_UP],
		"down": [KEY_S, KEY_DOWN],
		"left": [KEY_A, KEY_LEFT],
		"right": [KEY_D, KEY_RIGHT],
		"restart": [KEY_R, KEY_ENTER],
	}
	var axes := {
		"up": [JOY_AXIS_LEFT_Y, -1.0],
		"down": [JOY_AXIS_LEFT_Y, 1.0],
		"left": [JOY_AXIS_LEFT_X, -1.0],
		"right": [JOY_AXIS_LEFT_X, 1.0],
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for k: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		if axes.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = axes[action][0]
			jm.axis_value = axes[action][1]
			InputMap.action_add_event(action, jm)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFF1F6")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 20.0, 0.0)
	sun.light_color = Color("#FFF6EC")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


func _spawn_entities() -> void:
	ball = BallScene.instantiate()
	ball.position = _on_ground(3.5, 5.0) + Vector3.UP * 0.6
	add_child(ball)
	ball.died.connect(_on_ball_died)

	# Enemy zone: two blocks crossing the lane out of phase.
	_place(EnemyScene, 31.0, 1.5, {"period": 2.8})
	_place(EnemyScene, 35.5, 1.5, {"period": 2.2, "phase": 0.5})

	# Pop bumpers among the hills.
	_place(BumperScene, 20.5, 6.8)
	_place(BumperScene, 27.2, 5.0)

	# Booster in front of the ramp, pointing +z (towards the goal).
	_place(BoosterScene, 39.0, 6.5)

	var goal: Goal = _place(GoalScene, 39.0, 22.0)
	goal.reached.connect(_on_goal)


func _place(scene: PackedScene, x: float, z: float, props: Dictionary = {}) -> Node3D:
	var node: Node3D = scene.instantiate()
	node.position = _on_ground(x, z)
	for key: String in props:
		node.set(key, props[key])
	add_child(node)
	return node


func _on_ground(x: float, z: float) -> Vector3:
	return Vector3(x, Terrain.height(x, z), z)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.far = 200.0
	camera.rotation_degrees = CAMERA_ROTATION
	add_child(camera)
	camera.global_position = _camera_target()
	camera.make_current()


func _camera_target() -> Vector3:
	return ball.global_position + camera.global_basis.z * 40.0


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_status = _label(28)
	hud_status.position = Vector2(24, 16)
	layer.add_child(hud_status)
	hud_message = _label(44)
	hud_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hud_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_message.position = Vector2(-400, 120)
	hud_message.size = Vector2(800, 120)
	hud_message.text = "Roll to the flag!  WASD / arrows / stick"
	layer.add_child(hud_message)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if not finished:
			hud_message.text = "")


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Palette.INK)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 8)
	return l


func _process(delta: float) -> void:
	if not finished:
		elapsed += delta
	hud_status.text = "Time %.1f   Falls %d" % [elapsed, falls]
	var k := 1.0 - exp(-CAMERA_FOLLOW * delta)
	camera.global_position = camera.global_position.lerp(_camera_target(), k)
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()


func _on_ball_died() -> void:
	falls += 1


func _on_goal() -> void:
	finished = true
	hud_message.text = "Goal!  %.1f s   (R to play again)" % elapsed

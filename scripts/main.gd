extends Node3D
## Game loop: loads levels, runs the Marble Madness style countdown (time left
## carries over to the next level), handles death, checkpoints, the golf hole,
## high scores and the HUD.

const LEVELS: Array[GDScript] = [
	preload("res://scripts/levels/level_1.gd"),
	preload("res://scripts/levels/level_2.gd"),
	preload("res://scripts/levels/level_3.gd"),
	preload("res://scripts/levels/level_4.gd"),
	preload("res://scripts/levels/level_5.gd"),
	preload("res://scripts/levels/level_6.gd"),
]

const SCENES := {
	"ball": preload("res://scenes/ball.tscn"),
	"enemy": preload("res://scenes/enemy.tscn"),
	"bumper": preload("res://scenes/bumper.tscn"),
	"booster": preload("res://scenes/booster.tscn"),
	"checkpoint": preload("res://scenes/checkpoint.tscn"),
	"goal": preload("res://scenes/goal.tscn"),
	"decor": preload("res://scenes/decor.tscn"),
	"loop": preload("res://scenes/loop.tscn"),
	"pinball": preload("res://scenes/pinball.tscn"),
}
## Medal thresholds as multiples of the level's par time.
const MEDALS := [[1.0, "GOLD"], [1.3, "SILVER"], [1.7, "BRONZE"]]

const SkyShader := preload("res://scripts/sky.gdshader")

const CAMERA_ROTATION := Vector3(-35.264, 45.0, 0.0)  # true isometric
const CAMERA_SIZE := 18.0
const CAMERA_FOLLOW := 5.0
const NEXT_LEVEL_DELAY := 3.0
## Entity dictionary keys that are not node properties.
const META_KEYS := ["type", "pos", "yaw", "ground_tile"]

@export var first_level := 0
## Off for tests: stay on the level after reaching the goal.
@export var auto_advance := true
## Off for tests: don't write high scores.
@export var save_scores := true

var level: LevelBase
var level_index := 0
var world: Node3D
var ball: Ball
var camera: Camera3D
var sfx: Sfx
var scores: Scores
var level_time := 0.0
var total_time := 0.0
var falls := 0
var level_falls := 0
var finished := false
var game_complete := false

var _hud_level: Label
var _hud_time: Label
var _hud_best: Label
var _hud_message: Label
var _hud_board: Label

var _message_token := 0
var _shake := 0.0


func _ready() -> void:
	add_to_group("game")
	scores = Scores.new(save_scores)
	_setup_input()
	_setup_environment()
	_setup_camera()
	_setup_hud()
	sfx = Sfx.new()
	add_child(sfx)
	start_level(first_level)


## Music per level (audio/*.mp3), crossfaded on level change.
const LEVEL_MUSIC := [
	"Ticking_Gumdrop_Lane", "Gumball_Velocity", "Spun_Sugar_Waltz",
	"Ticking_Gumdrop_Lane", "Spun_Sugar_Waltz", "Gumball_Velocity",
]
const FINISH_MUSIC := "Gold_Star_Finish"
const MUSIC_DB := -9.0

var _music: AudioStreamPlayer
var _music_name := ""


func play_music(track: String) -> void:
	if track == _music_name:
		return
	var path := "res://audio/%s.mp3" % track
	if not ResourceLoader.exists(path):
		return
	_music_name = track
	var stream: AudioStreamMP3 = load(path)
	stream.loop = true
	var old := _music
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -40.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 1.2)
	if old:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, 1.2)
		tw.tween_callback(old.queue_free)


# --- Levels -----------------------------------------------------------------

func start_level(index: int) -> void:
	level_index = index
	play_music(LEVEL_MUSIC[index % LEVEL_MUSIC.size()])
	var data: LevelBase = LEVELS[index].new()
	load_level(data)


## Loads any LevelBase (tests use this for their own maps).
func load_level(data: LevelBase) -> void:
	if world:
		remove_child(world)
		world.queue_free()
	level = data
	level.build()
	finished = false
	level_time = 0.0
	level_falls = 0
	_hud_board.text = ""

	world = Node3D.new()
	world.name = "World"
	add_child(world)
	world.add_child(Terrain.new(level))
	var backdrop := Backdrop.new()
	backdrop.setup(Rect2(0, 0, level.cols * LevelBase.TILE, level.rows * LevelBase.TILE), hash(level.title))
	world.add_child(backdrop)

	ball = SCENES.ball.instantiate()
	ball.position = ground(level.spawn) + Vector3.UP * 0.6
	world.add_child(ball)
	ball.died.connect(_on_ball_died)
	for e in level.entities:
		var node := _place(e)
		if node is Goal:
			node.reached.connect(_on_goal)

	camera.global_position = _camera_target()
	_update_best_label()
	show_message("%s\npar %.0f s" % [level.title, level.time_limit], 2.5)


func _place(e: Dictionary) -> Node3D:
	var node: Node3D = SCENES[e.type].instantiate()
	node.position = ground(e.pos)
	if e.has("ground_tile"):
		var gt: Vector2i = e.ground_tile
		node.position.y = level.surface(gt.x, gt.y, (gt.x + 0.5) * LevelBase.TILE, (gt.y + 0.5) * LevelBase.TILE)
	if e.type == "goal":
		node.position.y = level.height(e.pos.x + LevelBase.HOLE_RADIUS + 0.05, e.pos.y)
	node.rotation_degrees.y = e.get("yaw", 0.0)
	for key: String in e:
		if key not in META_KEYS:
			node.set(key, e[key])
	world.add_child(node)
	return node


func ground(p: Vector2) -> Vector3:
	return Vector3(p.x, level.height(p.x, p.y), p.y)


func _score_key() -> String:
	return "level:" + level.title


# --- Loop -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not finished and not game_complete:
		total_time += delta
		level_time += delta
	_hud_time.text = "%.2f" % level_time
	var over_par := level_time > level.time_limit
	_hud_time.add_theme_color_override("font_color", Palette.RASPBERRY if over_par else Palette.INK)
	_hud_level.text = "Level %d  %s\nPar %.0f s   Falls %d" % [level_index + 1, level.title, level.time_limit, falls]

	var k := 1.0 - exp(-CAMERA_FOLLOW * delta)
	camera.global_position = camera.global_position.lerp(_camera_target(), k)
	if _shake > 0.0:
		camera.h_offset = randf_range(-_shake, _shake)
		camera.v_offset = randf_range(-_shake, _shake)
		_shake = maxf(0.0, _shake - delta * 1.5)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	if Input.is_action_just_pressed("restart"):
		if game_complete:
			game_complete = false
			falls = 0
			total_time = 0.0
			start_level(0)
		else:
			start_level(level_index)


func _camera_target() -> Vector3:
	return ball.global_position + camera.global_basis.z * 40.0


# --- Events -----------------------------------------------------------------

func _on_ball_died() -> void:
	falls += 1
	level_falls += 1
	sfx.play("pop")
	burst(ball.global_position, [Palette.WHITE, Palette.RASPBERRY, Palette.PINK], 28, 5.0)
	_shake = 0.3


func _on_goal() -> void:
	if finished:
		return
	finished = true
	sfx.play("goal")
	burst(ball.global_position + Vector3.UP * 0.8, [Palette.LEMON, Palette.PINK, Palette.MINT, Palette.LILAC, Palette.SKY], 60, 7.0)
	var rank := scores.submit(_score_key(), level_time)
	_hud_board.text = "Best times\n" + Scores.format_board(scores.top(_score_key()), rank)
	_update_best_label()
	var badge := "  NEW BEST!" if rank == 0 else ("  #%d on the board" % (rank + 1) if rank > 0 else "")
	var medal := medal_for(level_time, level.time_limit)
	var medal_text := "%s medal" % medal if medal != "" else "over par"
	cheer(medal if medal != "" else "IN!", ball.global_position + Vector3.UP * 1.5)
	var idx := level_index
	if idx == LEVELS.size() - 1:
		game_complete = true
		play_music(FINISH_MUSIC)
		var run_rank := scores.submit("run", total_time)
		var run_badge := "  NEW RECORD!" if run_rank == 0 else ""
		_hud_board.text = "Best runs\n" + Scores.format_board(scores.top("run"), run_rank)
		show_message("In the hole!  %.2f s  %s%s\nAll %d levels: %.2f s, %d falls%s\nR to play again" % [
			level_time, medal_text, badge, LEVELS.size(), total_time, falls, run_badge])
		return
	show_message("In the hole!  %.2f s  %s%s" % [level_time, medal_text, badge])
	if not auto_advance:
		return
	await get_tree().create_timer(NEXT_LEVEL_DELAY).timeout
	if level_index == idx and finished:
		start_level(idx + 1)


static func medal_for(time: float, par: float) -> String:
	for m in MEDALS:
		if time <= par * m[0]:
			return m[1]
	return ""


func _update_best_label() -> void:
	var best := scores.best(_score_key())
	_hud_best.text = "Best %.2f" % best if best > 0.0 else ""


func on_bump(_pos: Vector3) -> void:
	sfx.play("boing")
	_shake = maxf(_shake, 0.12)


func on_boost(_pos: Vector3) -> void:
	sfx.play("boost", -9.0)


func on_checkpoint(_pos: Vector3) -> void:
	sfx.play("checkpoint")
	show_message("Checkpoint!", 1.2)


## Little floating shout for fun moments (loops, cannons, medals).
func cheer(text: String, at: Vector3) -> void:
	_popup(text, at, Palette.CORAL, 1.3)


func _popup(text: String, at: Vector3, col: Color, size: float = 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = int(64 * size)
	l.outline_size = 16
	l.modulate = col.lightened(0.1)
	l.outline_modulate = Palette.INK
	l.pixel_size = 0.01
	world.add_child(l)
	l.global_position = at
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position:y", at.y + 1.6, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


# --- Juice ------------------------------------------------------------------

func burst(pos: Vector3, colors: Array, amount: int, speed: float) -> void:
	var p := CPUParticles3D.new()
	var mesh := Palette.sphere(0.08)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.3
	mesh.material = mat
	p.mesh = mesh
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 1.2
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / colors.size())
		cols.append(colors[i])
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = offsets
	g.colors = cols
	p.color_initial_ramp = g
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


func show_message(text: String, duration: float = 0.0) -> void:
	_message_token += 1
	var token := _message_token
	_hud_message.text = text
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration).timeout
	if token == _message_token:
		_hud_message.text = ""


# --- Setup ------------------------------------------------------------------

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
		if action == "restart":
			var jb := InputEventJoypadButton.new()
			jb.button_index = JOY_BUTTON_START
			InputMap.action_add_event(action, jb)


func _setup_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFF1F6")
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#F6D5E6")
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 90.0
	env.fog_density = 0.6
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_color = Color("#FFF6EC")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.far = 200.0
	camera.rotation_degrees = CAMERA_ROTATION
	add_child(camera)
	camera.make_current()


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hud_level = _label(26)
	_hud_level.position = Vector2(24, 16)
	layer.add_child(_hud_level)

	_hud_time = _label(56)
	_hud_time.anchor_left = 1.0
	_hud_time.anchor_right = 1.0
	_hud_time.offset_left = -300.0
	_hud_time.offset_right = -24.0
	_hud_time.offset_top = 8.0
	_hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_hud_time)

	_hud_best = _label(24)
	_hud_best.anchor_left = 1.0
	_hud_best.anchor_right = 1.0
	_hud_best.offset_left = -300.0
	_hud_best.offset_right = -28.0
	_hud_best.offset_top = 78.0
	_hud_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_hud_best)

	_hud_message = _label(44)
	_hud_message.anchor_right = 1.0
	_hud_message.offset_top = 120.0
	_hud_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_hud_message)

	_hud_board = _label(26)
	_hud_board.anchor_left = 0.5
	_hud_board.anchor_right = 0.5
	_hud_board.offset_left = -140.0
	_hud_board.offset_right = 140.0
	_hud_board.offset_top = 290.0
	layer.add_child(_hud_board)


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Palette.INK)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 10)
	return l

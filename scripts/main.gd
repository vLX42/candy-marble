class_name MainGame
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
	"rival": preload("res://scenes/rival.tscn"),
	"chute": preload("res://scenes/chute.tscn"),
	"hopper": preload("res://scenes/hopper.tscn"),
	"stomper": preload("res://scenes/stomper.tscn"),
	"ghost": preload("res://scenes/ghost.tscn"),
	"windmill": preload("res://scenes/windmill.tscn"),
	"catapult": preload("res://scenes/catapult.tscn"),
	"goo": preload("res://scenes/goo.tscn"),
}
## Sugar Rush: pinball hits fill the meter; full = a few seconds of rush.
const RUSH_HITS := 6.0
const RUSH_TIME := 7.0
## Medal thresholds as multiples of the level's par time.
const MEDALS := [[1.0, "GOLD"], [1.3, "SILVER"], [1.7, "BRONZE"]]

const SkyShader := preload("res://scripts/sky.gdshader")

const CAMERA_ROTATION := Vector3(-35.264, 45.0, 0.0)  # true isometric
const CAMERA_FOLLOW := 5.0
## How fast the playfield turns to follow the track (follow camera setting).
const CAMERA_TURN := 1.6
const NEXT_LEVEL_DELAY := 3.0
## Entity dictionary keys that are not node properties.
const META_KEYS := ["type", "pos", "yaw", "ground_tile", "y", "tint"]
## Speed knobs per monster type: [property, true = bigger is faster].
const SPEED_KEYS := {
	"enemy": ["period", false], "stomper": ["period", false], "hopper": ["period", false],
	"ghost": ["speed", true], "windmill": ["spin", true],
}

## Set by the title screen before switching to this scene (-1 = use first_level).
static var requested_level := -1
## Custom quest to play instead of the built-in levels (null = campaign).
static var quest: Quest = null
## Test play from the level editor: Esc goes back to the editor, no scores.
static var test_mode := false
## Test play from a picked tile instead of the start (editor "Test from here").
static var test_start := Vector2i(-1, -1)

@export var first_level := 0
## Off for tests: stay on the level after reaching the goal.
@export var auto_advance := true
## Off for tests: don't write high scores.
@export var save_scores := true
## 3-2-1-GO before each level (tests turn it off).
@export var countdown := true

const COUNT_TIME := 2.4
## Course preview: the camera glides from the flag back to the start.
const FLY_TIME := 3.2
var _fly_left := 0.0
var _flown := ""
## Best-run ghost: position samples every GHOST_DT seconds of level time.
const GHOST_DT := 0.05
var _count_left := 0.0
var _count_shown := ""
var _ghost_rec := PackedVector3Array()
var _ghost_play := PackedVector3Array()
var _ghost: Node3D

var level: LevelBase
var level_index := 0
var world: Node3D
var ball: Ball
var rival: Rival
var race_lost := false
var rival_time := -1.0
var _route_world: Array[Vector2] = []
var camera: Camera3D
var sfx: Sfx
var scores: Scores
var level_time := 0.0
var total_time := 0.0
var falls := 0
var level_falls := 0
var rush_meter := 0.0
var rush_left := 0.0
var finished := false
var game_complete := false

var hud: Hud
var _shake := 0.0
var _cam_yaw := deg_to_rad(45.0)
var _env: Environment
var _sun: DirectionalLight3D


func _ready() -> void:
	add_to_group("game")
	# Keeps reading Esc while paused; the world below pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if test_mode:
		save_scores = false
		auto_advance = false
	scores = Scores.new(save_scores)
	_setup_input()
	_setup_environment()
	_setup_camera()
	_setup_hud()
	sfx = Sfx.new()
	add_child(sfx)
	if requested_level >= 0:
		first_level = requested_level
		requested_level = -1
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
	_music.bus = "Music"
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
	var data: LevelBase = quest.make_level(index) if quest else LEVELS[index].new()
	load_level(data)


func level_count() -> int:
	return quest.levels.size() if quest else LEVELS.size()


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
	rush_meter = 0.0
	rush_left = 0.0

	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.add_child(Terrain.new(level))
	var backdrop := Backdrop.new()
	backdrop.setup(level, hash(level.title))
	world.add_child(backdrop)

	ball = SCENES.ball.instantiate()
	ball.position = ground(level.spawn) + Vector3.UP * 0.6
	if test_mode and test_start.x >= 0 and level.is_tile_ground(test_start.x, test_start.y):
		ball.position = ground(level.tile_center(test_start.x, test_start.y)) + Vector3.UP * 0.6
	world.add_child(ball)
	ball.died.connect(_on_ball_died)
	ball.landed.connect(_on_ball_landed)
	ball.bonked.connect(func(impact: float) -> void:
		sfx.play("bonk", clampf(-20.0 + impact * 2.5, -20.0, -4.0), 0.12))
	ball.break_drop = level.break_drop * level.step + 0.3 if level.break_drop > 0 else 0.0
	rival = null
	race_lost = false
	rival_time = -1.0
	_route_world.clear()
	for t in level.route:
		_route_world.append(level.tile_center_f(t))
	if level.race:
		rival = SCENES.rival.instantiate()
		rival.level = level
		rival.position = ground(level.spawn + Vector2(0, LevelBase.TILE)) + Vector3.UP * 0.6
		rival.cruise *= level.rival_speed
		world.add_child(rival)
		Palette.tint(rival, level.rival_tint)
	for e in level.entities:
		var node := _place(e)
		if node is Goal:
			node.reached.connect(_on_goal)
			node.rival_reached.connect(_on_rival_goal)

	_cam_yaw = _track_yaw() if Settings.camera_follow else deg_to_rad(45.0)
	camera.rotation = Vector3(deg_to_rad(CAMERA_ROTATION.x), _cam_yaw, 0.0)
	camera.global_position = _camera_target()
	hud.set_level(level_index + 1, level.title, level.time_limit, level.race)
	_update_best_label()
	var intro := "%s\nPar %.0f s.  Roll to the hole!" % [level.title, level.time_limit]
	if level.race:
		intro = "%s\nRace the licorice ball to the hole!" % level.title
	if level.description != "":
		var d := level.description.replace("\n", " ")
		intro = "%s\n%s" % [level.title, d if d.length() <= 90 else d.substr(0, 87) + "..."]
	show_message(intro, 3.0)
	_count_left = COUNT_TIME if countdown else 0.0
	_count_shown = ""
	# Fly over the course the first time a level loads (not on restarts).
	var id := _score_key()
	_fly_left = FLY_TIME if countdown and _flown != id and _route_world.size() >= 2 else 0.0
	_flown = id
	if _fly_left > 0.0:
		_cam_yaw = deg_to_rad(45.0)
		camera.rotation = Vector3(deg_to_rad(CAMERA_ROTATION.x), _cam_yaw, 0.0)
		camera.global_position = _camera_target()
		camera.size = Settings.camera_size() * 1.35
	if _count_left > 0.0:
		ball.input_lock = _count_left + _fly_left
		if rival:
			rival.set("_wait", _count_left + _fly_left)
	_ghost_rec = PackedVector3Array()
	_setup_ghost()


func _place(e: Dictionary) -> Node3D:
	return MainGame.spawn_entity(e, level, world)


## Instances one level entity under `parent` (the editor uses this too).
static func spawn_entity(e: Dictionary, lvl: LevelBase, parent: Node3D) -> Node3D:
	var node: Node3D = SCENES[e.type].instantiate()
	node.position = Vector3(e.pos.x, lvl.height(e.pos.x, e.pos.y), e.pos.y)
	if e.has("ground_tile"):
		var gt: Vector2i = e.ground_tile
		node.position.y = lvl.surface(gt.x, gt.y, (gt.x + 0.5) * LevelBase.TILE, (gt.y + 0.5) * LevelBase.TILE)
	if e.has("y"):
		node.position.y = e.y
	if e.type == "goal":
		node.position.y = lvl.height(e.pos.x + LevelBase.HOLE_RADIUS + 0.05, e.pos.y)
	node.rotation_degrees.y = e.get("yaw", 0.0)
	for key: String in e:
		if key not in META_KEYS:
			node.set(key, e[key])
	if SPEED_KEYS.has(e.type) and not is_equal_approx(lvl.monster_speed, 1.0):
		var k: Array = SPEED_KEYS[e.type]
		var v: float = node.get(k[0])
		node.set(k[0], v * lvl.monster_speed if k[1] else v / maxf(lvl.monster_speed, 0.05))
	parent.add_child(node)
	if SPEED_KEYS.has(e.type):
		Palette.tint(node, e.get("tint", lvl.monster_tint))
	elif e.has("tint"):
		Palette.tint(node, e.tint)
	return node


func ground(p: Vector2) -> Vector3:
	return Vector3(p.x, level.height(p.x, p.y), p.y)


func _score_key() -> String:
	if quest:
		return "quest:%s:%d:%s" % [quest.id, level_index, level.title]
	return "level:" + level.title


func _run_key() -> String:
	return "quest_run:" + quest.id if quest else "run"


# --- Loop -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _handle_pause():
		return
	if _fly_left > 0.0:
		_fly_left -= delta
		for a in ["up", "down", "left", "right"]:
			if Input.is_action_just_pressed(a):
				_fly_left = 0.0
		if _fly_left <= 0.0:
			_fly_left = 0.0
			ball.input_lock = _count_left
			if rival:
				rival.set("_wait", _count_left)
	elif _count_left > 0.0:
		_count_left -= delta
		var n := "GO!" if _count_left <= 0.0 else str(ceili(_count_left / (COUNT_TIME / 3.0)))
		if n != _count_shown:
			_count_shown = n
			hud.show_count(n)
			sfx.play("go" if n == "GO!" else "tick", -4.0 if n == "GO!" else -8.0, 0.0)
	elif not finished and not game_complete:
		total_time += delta
		level_time += delta
		_record_ghost()
	_update_ghost()
	if ball and ball.alive and not finished:
		sfx.set_roll(Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length(), ball.is_grounded(), delta)
	else:
		sfx.set_roll(0.0, false, delta)
	var place := "1st" if race_position() == 1 else "2nd"
	if race_lost:
		place = "LOST"
	hud.update(level_time, level_time > level.time_limit, falls, place)
	_update_rush(delta)

	var target_yaw := _track_yaw() if Settings.camera_follow else deg_to_rad(45.0)
	if _fly_left > 0.0:
		target_yaw = deg_to_rad(45.0)
	_cam_yaw = lerp_angle(_cam_yaw, target_yaw, 1.0 - exp(-CAMERA_TURN * delta))
	camera.rotation = Vector3(deg_to_rad(CAMERA_ROTATION.x), _cam_yaw, 0.0)
	var want_size := Settings.camera_size() * (1.35 if _fly_left > 0.0 else 1.0)
	camera.size = lerpf(camera.size, want_size, 1.0 - exp(-3.0 * delta))
	var k := 1.0 - exp(-CAMERA_FOLLOW * delta)
	camera.global_position = camera.global_position.lerp(_camera_target(), k)
	if _shake > 0.0:
		camera.h_offset = randf_range(-_shake, _shake)
		camera.v_offset = randf_range(-_shake, _shake)
		_shake = maxf(0.0, _shake - delta * 1.5)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	if Input.is_action_just_pressed("pause") and (finished or game_complete):
		_leave()
		return
	if Input.is_action_just_pressed("restart"):
		_restart()


func _restart() -> void:
	if game_complete:
		game_complete = false
		falls = 0
		total_time = 0.0
		start_level(0)
	else:
		start_level(level_index)


# --- Pause ------------------------------------------------------------------

## Esc / Start pauses mid-level. Returns true while paused.
func _handle_pause() -> bool:
	var tree := get_tree()
	if tree.paused:
		sfx.stop_roll()
	if Input.is_action_just_pressed("pause") and not finished and not game_complete:
		if tree.paused:
			_resume()
		else:
			tree.paused = true
			hud.show_pause("Back to the editor" if test_mode else "Quit to menu")
			if not hud.pause_action.is_connected(_on_pause_action):
				hud.pause_action.connect(_on_pause_action)
		return true
	return tree.paused


func _resume() -> void:
	get_tree().paused = false
	hud.hide_pause()


func _on_pause_action(action: String) -> void:
	match action:
		"resume":
			_resume()
		"restart":
			_resume()
			start_level(level_index)
		"camera":
			Settings.set_value("camera_follow", not Settings.camera_follow)
			hud.show_pause("Back to the editor" if test_mode else "Quit to menu")
		"ghost":
			Settings.set_value("ghost", not Settings.ghost)
			_setup_ghost()
			hud.show_pause("Back to the editor" if test_mode else "Quit to menu")
		"quit":
			_resume()
			_leave()


func _leave() -> void:
	if test_mode:
		test_mode = false
		test_start = Vector2i(-1, -1)
		quest = null
		Transition.go("res://scenes/editor.tscn")
	else:
		if quest:
			TitleScreen.open_page = "quests"
		quest = null
		Transition.go("res://scenes/title.tscn")


# --- Best-run ghost -----------------------------------------------------------

func _ghost_path() -> String:
	return "user://ghosts/%s.ghost" % _score_key().md5_text()


func _record_ghost() -> void:
	if ball == null:
		return
	while _ghost_rec.size() * GHOST_DT <= level_time:
		_ghost_rec.append(ball.global_position)


func _save_ghost() -> void:
	if not save_scores or _ghost_rec.size() < 2:
		return
	DirAccess.make_dir_recursive_absolute("user://ghosts")
	var f := FileAccess.open(_ghost_path(), FileAccess.WRITE)
	if f:
		f.store_var(_ghost_rec)


## A see-through marble replaying your best run on this level.
func _setup_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_ghost_play = PackedVector3Array()
	if not save_scores or not Settings.ghost or not FileAccess.file_exists(_ghost_path()):
		return
	var f := FileAccess.open(_ghost_path(), FileAccess.READ)
	var data: Variant = f.get_var() if f else null
	if not data is PackedVector3Array or data.size() < 2:
		return
	_ghost_play = data
	_ghost = Node3D.new()
	world.add_child(_ghost)
	_ghost.global_position = _ghost_play[0]
	Palette.load_model(_ghost, "ball")
	Palette.tint(_ghost, Color("#8CC9F0"))
	Palette.ghostify(_ghost, 0.55)
	var tag := Label3D.new()
	tag.text = "BEST"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 40
	CandyText.style_3d(tag, Color(CandyText.PASTELS[4], 0.9))
	tag.fixed_size = true
	tag.pixel_size = 0.0011
	tag.outline_modulate = Color(CandyText.CHOCOLATE, 0.6)
	tag.position = Vector3.UP * 0.95
	_ghost.add_child(tag)


func _update_ghost() -> void:
	if _ghost == null or _ghost_play.is_empty():
		return
	var f := level_time / GHOST_DT
	var i := int(f)
	if i >= _ghost_play.size() - 1:
		_ghost.global_position = _ghost_play[_ghost_play.size() - 1]
		_ghost.visible = false
		return
	_ghost.visible = true
	_ghost.global_position = _ghost_play[i].lerp(_ghost_play[i + 1], f - i)


## Pinball toys call this. Only hits near the player count.
func charge(amount: float, at: Vector3) -> void:
	if ball == null or finished or rush_left > 0.0:
		return
	if at.distance_to(ball.global_position) > 4.0:
		return
	rush_meter = minf(1.0, rush_meter + amount / RUSH_HITS)
	if rush_meter >= 0.999:
		rush_meter = 0.0
		rush_left = RUSH_TIME
		ball.rush = true
		sfx.play("rush" if sfx.has("rush") else "boost")
		cheer("SUGAR RUSH!", ball.global_position + Vector3.UP * 2.2)
		if _music:
			_music.pitch_scale = 1.08


func _update_rush(delta: float) -> void:
	if rush_left > 0.0:
		rush_left -= delta
		hud.set_rush(rush_left / RUSH_TIME, true, rush_left)
		if rush_left <= 0.0 or finished:
			rush_left = 0.0
			ball.rush = false
			if _music:
				_music.pitch_scale = 1.0
	else:
		hud.set_rush(rush_meter, false, 0.0)


## 1 if the player is ahead of the rival along the route, else 2.
func race_position() -> int:
	if rival == null:
		return 1
	if rival.finished:
		return 1 if finished and not race_lost else 2
	var me := LevelBase.route_progress(_route_world, Vector2(ball.global_position.x, ball.global_position.z))
	var them := LevelBase.route_progress(_route_world, Vector2(rival.global_position.x, rival.global_position.z))
	return 1 if me >= them else 2


func _on_rival_goal() -> void:
	rival_time = level_time
	if finished:
		return
	# You can still roll home, but the level isn't cleared.
	race_lost = true
	sfx.play("timeup")
	cheer("RIVAL WINS", rival.global_position + Vector3.UP * 1.5)
	hud.sticky = "Rival wins!\nThe licorice ball got there first.  Finish anyway, or R to race again"
	show_message(hud.sticky)


## Camera yaw that points the track just ahead of the ball up the screen.
func _track_yaw() -> float:
	if _route_world.size() < 2 or ball == null:
		return _cam_yaw
	var p := LevelBase.route_progress(_route_world, Vector2(ball.global_position.x, ball.global_position.z))
	var here := _route_point(p)
	var ahead := _route_point(p + 1.5)
	var d := ahead - here
	if d.length() < 0.5:
		return _cam_yaw
	# Camera forward (-basis.z) along d: the track ahead points up the screen,
	# so "up" on the stick always means "forward".
	return atan2(-d.x, -d.y)


func _route_point(progress: float) -> Vector2:
	var i := clampi(int(progress), 0, _route_world.size() - 2)
	return _route_world[i].lerp(_route_world[i + 1], clampf(progress - i, 0.0, 1.5))


func _camera_target() -> Vector3:
	return _camera_focus() + camera.global_basis.z * 40.0


## What the camera looks at: the marble, or the flyover point along the route.
func _camera_focus() -> Vector3:
	if _fly_left <= 0.0 or _route_world.size() < 2:
		return ball.global_position
	# Ease from the flag (route end) back to the start.
	var u := 1.0 - _fly_left / FLY_TIME
	u = u * u * (3.0 - 2.0 * u)
	var p := _route_point((_route_world.size() - 1) * (1.0 - u))
	return Vector3(p.x, level.height(p.x, p.y), p.y)


# --- Events -----------------------------------------------------------------

func _on_ball_died() -> void:
	falls += 1
	level_falls += 1
	sfx.play("pop")
	burst(ball.global_position, [Palette.WHITE, Palette.RASPBERRY, Palette.PINK], 28, 5.0)
	_shake = 0.3


func _on_ball_landed(impact: float) -> void:
	sfx.play("land", clampf(-22.0 + impact * 1.6, -22.0, -3.0), 0.1)
	if impact > 5.0:
		dust(ball.global_position - Vector3.UP * 0.45, clampf(impact / 12.0, 0.3, 1.0))
		_shake = maxf(_shake, clampf(impact * 0.012, 0.0, 0.18))


## Candy-dust puff where the marble lands.
func dust(pos: Vector3, amount: float) -> void:
	var p := CPUParticles3D.new()
	var mesh := Palette.sphere(0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.97, 0.93, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = int(10 + 16 * amount)
	p.lifetime = 0.55
	p.direction = Vector3.UP
	p.spread = 85.0
	p.flatness = 0.7
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5 * amount + 1.5
	p.gravity = Vector3(0, -3, 0)
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


func _on_goal() -> void:
	# Nothing counts before GO (the marble can't move then anyway).
	if finished or _fly_left > 0.0 or _count_left > 0.0:
		return
	finished = true
	if race_lost:
		sfx.play("pop")
		hud.show_results({title = "2nd place", time = level_time,
			info = "The licorice ball won by %.2f s" % (level_time - rival_time),
			hint = "R  race again      Esc  %s" % ("editor" if test_mode else "menu")})
		return
	if rival and not race_lost:
		rival.finished = true
	if quest == null:
		scores.unlock(level_index + 2)
	sfx.play("goal")
	burst(ball.global_position + Vector3.UP * 0.8, [Palette.LEMON, Palette.PINK, Palette.MINT, Palette.LILAC, Palette.SKY], 60, 7.0)
	var rank := scores.submit(_score_key(), level_time)
	if rank == 0:
		_record_ghost()
		_save_ghost()
	_update_best_label()
	var medal := medal_for(level_time, level.time_limit)
	var res := {
		title = "You win the race!" if rival else "In the hole!",
		time = level_time, medal = medal,
		badge = "NEW BEST!" if rank == 0 else ("#%d ON THE BOARD" % (rank + 1) if rank > 0 else ""),
		info = "Par %.0f s   Falls %d" % [level.time_limit, level_falls],
		board_title = "BEST TIMES", board = scores.top(_score_key()), highlight = rank,
		hint = "Next level coming up...      R  retry" if auto_advance else "R  retry      Esc  menu",
		confetti = rank == 0 or medal == "GOLD",
	}
	if test_mode:
		res.hint = "R  retry      Esc  back to the editor"
		hud.show_results(res)
		return
	var idx := level_index
	if idx == level_count() - 1:
		game_complete = true
		play_music(FINISH_MUSIC)
		var run_rank := scores.submit(_run_key(), total_time)
		res.title = "%s complete!" % quest.name if quest else "All %d levels done!" % LEVELS.size()
		res.info = "Whole run %.2f s   %d falls%s" % [total_time, falls, "   NEW RECORD!" if run_rank == 0 else ""]
		res.board_title = "BEST RUNS"
		res.board = scores.top(_run_key())
		res.highlight = run_rank
		res.hint = "R  play again      Esc  menu"
		hud.show_results(res)
		return
	hud.show_results(res)
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
	hud.set_best(best)


## Positional-ish one-shot for toys: quieter the further from the marble.
func play_sound(sound: String, at: Vector3) -> void:
	var d := at.distance_to(ball.global_position) if ball else 0.0
	sfx.play(sound, clampf(-4.0 - d * 0.8, -26.0, -4.0))


func on_bump(pos: Vector3) -> void:
	sfx.play("boing")
	_shake = maxf(_shake, 0.12)
	charge(1.0, pos)


func on_stomp(pos: Vector3) -> void:
	var d := pos.distance_to(ball.global_position) if ball else 99.0
	if d < 14.0:
		sfx.play("pop", -14.0 + (14.0 - d))
		_shake = maxf(_shake, 0.25 * (1.0 - d / 14.0))


func on_boost(pos: Vector3) -> void:
	sfx.play("boost", -9.0)
	charge(0.5, pos)


func on_checkpoint(_pos: Vector3) -> void:
	sfx.play("checkpoint")
	show_message("Checkpoint!", 1.2)


## Sound for each shout (monsters, toys and hazards announce themselves).
const CHEER_SOUNDS := {"SPLAT!": "splat", "SOUR!": "goo", "WHOOSH!": "whoosh", "LOOP!": "whoosh",
	"WHEEE!": "whoosh", "SWAT!": "bonk", "ALL STARS!": "coin", "TARGETS!": "coin", "HOOP!": "coin",
	"BOOM": "cannon", "BOOM!": "cannon"}


## Little floating shout for fun moments (loops, cannons, medals).
func cheer(text: String, at: Vector3) -> void:
	if CHEER_SOUNDS.has(text):
		var d := at.distance_to(ball.global_position) if ball else 0.0
		sfx.play(CHEER_SOUNDS[text], clampf(-2.0 - d * 0.8, -24.0, -2.0))
	_popup(text, at, CandyText.PASTELS[2], 1.3)


func _popup(text: String, at: Vector3, col: Color, size: float = 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = int(72 * size)
	l.pixel_size = 0.01
	CandyText.style_3d(l, col)
	world.add_child(l)
	l.global_position = at
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", at.y + 1.6, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(1.1)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.4).set_delay(1.1)
	tw.chain().tween_callback(l.queue_free)
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
	hud.show_message(text, duration)


# --- Setup ------------------------------------------------------------------

func _setup_input() -> void:
	var keys := {
		"up": [KEY_W, KEY_UP],
		"down": [KEY_S, KEY_DOWN],
		"left": [KEY_A, KEY_LEFT],
		"right": [KEY_D, KEY_RIGHT],
		"restart": [KEY_R],
		"pause": [KEY_ESCAPE, KEY_P],
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
		if action in ["restart", "pause"]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = JOY_BUTTON_BACK if action == "restart" else JOY_BUTTON_START
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
	_env = env

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_color = Color("#FFF6EC")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	_sun = sun
	Settings.apply_graphics(_env, _sun)
	Settings.changed.connect(func() -> void: Settings.apply_graphics(_env, _sun))


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = Settings.camera_size()
	camera.far = 200.0
	camera.rotation_degrees = CAMERA_ROTATION
	add_child(camera)
	camera.make_current()


func _setup_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.stamp.connect(func() -> void: sfx.play("coin", -9.0, 0.1))

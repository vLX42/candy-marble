extends SceneTree
## Mechanics test on a purpose-built map. Run headless:
##   godot --headless --fixed-fps 120 -s tests/playtest.gd

class TestLevel extends LevelBase:
	func _init() -> void:
		title = "mechanics test"
		heights = [
			"0000000000000000",
			"0000000000000000",
			"0000000000000000",
			"000.........0000",
			"000.........0000",
			"000.........0000",
			"000.........0000",
			"000.........0000",
			"000.........ssss",
			"000.........ssss",
			"000.............",
			"000.........1111",
			"000.........1111",
			"000.........1111",
			"000.........1111",
		]
		objects = [
			"......B..z......",
			".S.......|......",
			"....G....|......",
			".............v..",
			"................",
			"................",
			".v..............",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
		]
		extras = [
			{type = "loop", tile = Vector2(1, 9), yaw = 0.0},
			{type = "cannon", tile = Vector2(14, 1), target_tile = Vector2(1, 13)},
		]

var main: Node3D
var ball: Ball
var t := 0.0
var phase := 0
var phase_start := 0.0
var max_speed := 0.0
var max_y := -100.0
var mark := 0
var landing := Vector3.INF
var rush_checked := false
var rush_charged := false
var results: Array[String] = []
var failed := false


func _initialize() -> void:
	# The input checks below assume the fixed isometric camera.
	root.get_node("Settings").camera_follow = false
	main = load("res://scenes/main.tscn").instantiate()
	main.save_scores = false
	main.auto_advance = false
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if phase == 0:
		main.load_level(TestLevel.new())
		_next()
		return false
	ball = main.ball
	var pt := t - phase_start
	match phase:
		1:
			if pt > 1.0:
				_check("ball rests on floor", absf(ball.global_position.y - 0.5) < 0.1, "y=%.2f" % ball.global_position.y)
				Input.action_press("right")
				Input.action_press("down")
				_next()
		2:
			max_speed = maxf(max_speed, ball.linear_velocity.length())
			if pt > 1.6:
				Input.action_release("right")
				Input.action_release("down")
				_check("input moves ball +x", ball.global_position.x > 6.0, "x=%.1f" % ball.global_position.x)
				_check("speed capped", max_speed < ball.max_speed + 1.5, "max=%.2f" % max_speed)
				_teleport(Vector3(10.0, 0.6, 1.0), Vector3(6, 0, 0))
				_next()
		3:  # bumper at tile (6,0) = (13, 1): ball flies at it from x=10
			if pt > 0.6:
				_check("bumper knocks ball back", ball.linear_velocity.x < -3.0, "vx=%.1f" % ball.linear_velocity.x)
				mark = main.falls
				_teleport(Vector3(19.0, 0.6, 3.0), Vector3.ZERO)
				_next()
		4:  # sweeper on column 9 (x=19)
			if pt > 3.5:
				_check("enemy pops ball", main.falls > mark, "falls=%d" % main.falls)
				_next()
		5:
			if pt > 1.2:
				_next()
		6:
			_teleport(Vector3(3.0, 0.6, 9.0), Vector3(0, 0, 5))
			max_y = -100.0
			_next()
		7:  # booster (1,6) into the loop at tile (1,9)
			max_y = maxf(max_y, ball.global_position.y)
			if pt > 5.0:
				var p := ball.global_position
				_check("loop goes all the way round", max_y > 3.5 and p.x > 4.0 and p.z > 21.0,
					"max_y=%.1f end=%s" % [max_y, p.snapped(Vector3.ONE * 0.1)])
				_teleport(Vector3(27.0, 0.6, 5.0), Vector3(0, 0, 2))
				max_y = -100.0
				_next()
		8:  # booster (13,3) -> kicker rows 8-9 -> landing rows 11+
			max_y = maxf(max_y, ball.global_position.y)
			if pt > 3.0:
				var p := ball.global_position
				_check("booster kicker jump lands", p.z > 22.0 and p.y > 0.8 and ball.alive,
					"pos=%s max_y=%.1f" % [p.snapped(Vector3.ONE * 0.1), max_y])
				_teleport(Vector3(26.0, 0.6, 3.0), Vector3(3, 0, 0))
				max_y = -100.0
				_next()
		9:  # cannon at tile (14,1) fires to tile (1,13): track where it first lands
			var p := ball.global_position
			max_y = maxf(max_y, p.y)
			if max_y > 2.5 and p.y < 1.2 and landing == Vector3.INF:
				landing = p
			if pt > 3.5:
				_check("cannon lands the ball on target", landing.distance_to(Vector3(3, 0.5, 27)) < 2.0 and ball.alive,
					"landed=%s" % landing.snapped(Vector3.ONE * 0.1))
				_teleport(Vector3(19.0, 0.6, 3.0), Vector3.ZERO)
				_next()
		10:  # Sugar Rush: fill the meter, then sit in the sweeper's path
			if not rush_charged:
				rush_charged = true
				mark = main.falls
				for k in 6:  # exactly one full meter
					main.charge(1.0, ball.global_position)
			if pt > 0.2 and not rush_checked:
				rush_checked = true
				_check("pinball hits trigger sugar rush", ball.rush and ball.max_speed > 10.0,
					"rush=%s max_speed=%.1f" % [ball.rush, ball.max_speed])
			if pt > 3.5:
				_check("sweepers can't pop a rushing ball", main.falls == mark, "falls %d -> %d" % [mark, main.falls])
				_teleport(Vector3(9.0 - 2.5, 0.6, 5.0), Vector3(1.5, 0, 0))
				_next()
		11:  # hole at tile (4,2) = (9, 5)
			if main.finished or pt > 4.0:
				_check("ball drops in the hole", main.finished, "pos=%s" % ball.global_position.snapped(Vector3.ONE * 0.1))
				print("\n".join(results))
				print("PLAYTEST ", "FAILED" if failed else "PASSED")
				quit(1 if failed else 0)
	return false


func _next() -> void:
	phase += 1
	phase_start = t


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true


func _teleport(pos: Vector3, vel: Vector3) -> void:
	PhysicsServer3D.body_set_state(ball.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, pos))
	PhysicsServer3D.body_set_state(ball.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, vel)
	PhysicsServer3D.body_set_state(ball.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)

extends SceneTree
## Scripted playtest. Run headless:
##   godot --headless -s tests/playtest.gd
## Or with a window to also save screenshots to tests/shots/:
##   godot -s tests/playtest.gd -- --shots

var main: Node3D
var ball: Ball
var t := 0.0
var phase := 0
var phase_start := 0.0
var max_speed_seen := 0.0
var falls_before := 0
var results: Array[String] = []
var failed := false
var shots := "--shots" in OS.get_cmdline_user_args()


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if ball == null:
		ball = main.ball
		return false
	var pt := t - phase_start
	match phase:
		0:  # settle on the floor
			if pt > 1.5:
				_check("ball rests on floor", absf(ball.global_position.y - 0.5) < 0.1,
					"y=%.2f" % ball.global_position.y)
				_shot("01_start")
				Input.action_press("right")
				Input.action_press("down")
				_next()
		1:  # roll +x along the lane, speed must cap near max_speed
			max_speed_seen = maxf(max_speed_seen, ball.linear_velocity.length())
			if pt > 3.0:
				_shot("02_rolling")
				Input.action_release("right")
				Input.action_release("down")
				_check("input moves ball +x", ball.global_position.x > 12.0,
					"x=%.1f" % ball.global_position.x)
				_check("speed capped", max_speed_seen < ball.max_speed + 1.5 and max_speed_seen > ball.max_speed - 2.0,
					"max=%.2f" % max_speed_seen)
				_teleport(Vector3(18.0, 0.6, 6.8), Vector3(7.0, 0, 0))
				_next()
		2:  # bumper at (20.5, 6.8) must knock the ball back
			if pt > 0.8:
				_check("bumper knocks ball back", ball.linear_velocity.x < -5.0 or ball.global_position.x < 18.0,
					"vx=%.1f x=%.1f" % [ball.linear_velocity.x, ball.global_position.x])
				falls_before = main.falls
				_teleport(Vector3(31.0, 0.6, 5.0), Vector3.ZERO)
				_next()
		3:  # enemy crossing (31, z 1.5..8.5) must pop the ball
			if pt > 0.6 and pt < 0.7:
				_shot("03_enemy")
			if pt > 3.0:
				_check("enemy pops ball", main.falls > falls_before, "falls=%d" % main.falls)
				_next()
		4:  # wait for respawn, then booster jump to the goal
			if pt > 1.5:
				_teleport(Vector3(39.0, 0.6, 3.5), Vector3(0, 0, 3.0))
				_next()
		5:
			if pt > 0.9 and pt < 1.0:
				_shot("04_jump")
			if main.finished or pt > 6.0:
				_check("booster + ramp jump reaches goal", main.finished,
					"pos=%s" % ball.global_position)
				_next()
		6:
			if shots:
				_shot("05_goal")
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


func _shot(name: String) -> void:
	if not shots:
		return
	DirAccess.make_dir_recursive_absolute("res://tests/shots")
	root.get_viewport().get_texture().get_image().save_png("res://tests/shots/%s.png" % name)

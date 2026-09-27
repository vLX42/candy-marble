extends SceneTree
## Marble Madness mechanics: hard landings, sour goo and humps.
##   godot --headless --fixed-fps 120 -s tests/madness_test.gd

var main: Node3D
var t := 0.0
var phase := 0
var phase_start := 0.0
var mark := 0
var results: Array[String] = []
var failed := false


func _initialize() -> void:
	var mg: GDScript = load("res://scripts/main.gd")
	var q := Quest.create("madness test")
	q.levels = [{
		title = "madness test", par = 30.0, step = 1.0, break_drop = 2,
		# Tier 6 shelf with a tier 5 step, a tier 0 floor below, and goo.
		heights = [
			"..................",
			".66666666555......",
			".66666666555......",
			"..................",
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
		],
		objects = [
			"..................",
			".S................",
			"..................",
			"..................",
			"..........A.......",
			"...MMMMMMMM.......",
			"...MMMMMMMM....G..",
		],
	}]
	mg.set("quest", q)
	mg.set("requested_level", 0)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_scores = false
	main.countdown = false
	main.auto_advance = false
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	var pt := t - phase_start
	var ball: Ball = main.ball
	match phase:
		0:
			if pt > 0.5:
				var l: LevelBase = main.level
				_check("level uses tall steps", is_equal_approx(l.height(3, 3), 6.0), "shelf y %.2f" % l.height(3, 3))
				var peak := l.height(8, 11)
				_check("humps rise out of the floor", peak > 0.8 and absf(l.height(10, 11)) < 0.05,
					"peak %.2f, dip %.2f" % [peak, l.height(10, 11)])
				_check("marble breaks on big drops", ball.break_drop > 2.0 and ball.break_drop < 2.5, "%.2f" % ball.break_drop)
				mark = main.falls
				# Roll off the one-step ledge (tier 6 -> 5): fine.
				_put(ball, Vector3(17.5, 6.6, 3.0), Vector3(1.5, 0, 0))
				_next()
		1:
			if pt > 1.5:
				_check("a one-step drop is safe", main.falls == mark and ball.alive, "falls %d -> %d" % [mark, main.falls])
				# Roll off the shelf onto the floor six steps down: splat.
				_put(ball, Vector3(5.0, 6.6, 4.4), Vector3(0, 0, 3))
				_next()
		2:
			if pt > 2.5:
				_check("a six-step drop breaks the marble", main.falls > mark, "falls %d -> %d" % [mark, main.falls])
				mark = main.falls
				_next()
		3:
			# Wait for the respawn after the splat, then drop onto the goo.
			if pt < 5.0 and ball.alive and phase_start >= 0.0 and not has_meta("dropped"):
				set_meta("dropped", pt)
				_put(ball, Vector3(21.0, 0.6, 9.0), Vector3.ZERO)
			if has_meta("dropped") and pt > float(get_meta("dropped")) + 1.0:
				_check("sour goo pops the marble", main.falls > mark, "falls %d -> %d" % [mark, main.falls])
				mark = main.falls
				_put(ball, Vector3(24.0, 0.6, 9.0), Vector3.ZERO)
				_next()
		4:
			if pt > 1.0:
				_check("next to the goo is safe", main.falls == mark, "falls %d -> %d" % [mark, main.falls])
				print("\n".join(results))
				print("MADNESS TEST ", "FAILED" if failed else "PASSED")
				quit(1 if failed else 0)
	return false


func _put(body: RigidBody3D, pos: Vector3, vel: Vector3) -> void:
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, pos))
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, vel)


func _next() -> void:
	phase += 1
	phase_start = t


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

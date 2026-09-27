extends SceneTree
## Race outcome test on level 2. Run headless:
##   godot --headless --fixed-fps 120 -s tests/race_test.gd
## 1) rival sinks first, player rolls in after: 2nd place, level not cleared.
## 2) player sinks first: race won, rival stops.

var main: Node3D
var t := 0.0
var phase := 0
var phase_start := 0.0
var results: Array[String] = []
var failed := false


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.first_level = 1
	main.save_scores = false
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	var pt := t - phase_start
	var hole: Vector3 = main.ground(main.level.goal) + Vector3.UP * 0.8
	match phase:
		0:
			if pt > 0.5:
				_put(main.rival, hole)
				_next()
		1:
			if pt > 1.5:
				_check("rival sinking first marks the race lost", main.race_lost and not main.finished,
					"race_lost=%s finished=%s" % [main.race_lost, main.finished])
				_put(main.ball, hole)
				_next()
		2:
			if pt > 1.5:
				var msg: String = main.hud.results_text()
				_check("player still finishes, in 2nd place", main.finished and msg.contains("2nd place"),
					"finished=%s msg=%s" % [main.finished, msg.replace("\n", " | ")])
				main.start_level(1)
				_next()
		3:
			if pt > 0.5:
				_put(main.ball, hole)
				_next()
		4:
			if pt > 1.5:
				_check("player sinking first wins the race", main.finished and not main.race_lost and main.rival.finished,
					"finished=%s race_lost=%s rival_stopped=%s" % [main.finished, main.race_lost, main.rival.finished])
				print("\n".join(results))
				print("RACE TEST ", "FAILED" if failed else "PASSED")
				quit(1 if failed else 0)
	return false


func _put(body: RigidBody3D, pos: Vector3) -> void:
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, pos))
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)


func _next() -> void:
	phase += 1
	phase_start = t


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

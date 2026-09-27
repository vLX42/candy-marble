extends SceneTree
## Checks each new hazard and the catapult on a small purpose-built map.
##   godot --headless --fixed-fps 120 -s tests/hazards_test.gd

class HazardLevel extends LevelBase:
	func _init() -> void:
		title = "hazards test"
		heights = [
			"000000000000000111111",
			"000000000000000000001",
			"000000000000000000001",
			"000000000000000000001",
			"000000000000000000001",
			"000000000000000111111",
			".....................",
			"00000...0000000000000",
			"00000...0000000000000",
			"00000...0000000000000",
		]
		objects = [
			"....................",
			".S..................",
			"....................",
			"....................",
			"....................",
			"....................",
			"....................",
			"....................",
			"....................",
			"....................",
		]
		extras = [
			{type = "stomper", tile = Vector2(3, 3), period = 2.0},
			{type = "hopper", tile = Vector2(8, 1), travel = Vector3(0, 0, 6), period = 2.0, hops = 1},
			{type = "ghost", tile = Vector2(13, 3), leash = 4.0},
			{type = "windmill", tile = Vector2(17, 3), spin = 1.5},
			{type = "catapult", tile = Vector2(3, 8), target_tile = Vector2(12, 8)},
		]

var main: Node3D
var ball: Ball
var t := 0.0
var phase := 0
var phase_start := 0.0
var mark := 0
var max_y := -99.0
var landing := Vector3.INF
var moved := 0.0
var results: Array[String] = []
var failed := false


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.save_scores = false
	main.auto_advance = false
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if phase == 0:
		root.get_node("Settings").camera_follow = false
		main.load_level(HazardLevel.new())
		_next()
		return false
	ball = main.ball
	var pt := t - phase_start
	match phase:
		1:  # park under the stomper
			if pt > 0.5:
				mark = main.falls
				_put(Vector3(7, 0.6, 7), Vector3.ZERO)
				_next()
		2:
			if pt > 2.5:
				_check("stomper squashes a ball underneath", main.falls > mark, "falls %d -> %d" % [mark, main.falls])
				mark = main.falls
				_put(Vector3(17, 0.6, 8.6), Vector3.ZERO)
				_next()
		3:  # sit on the hopper's path
			if pt > 3.0:
				_check("hopper pops a ball in its path", main.falls > mark, "falls %d -> %d" % [mark, main.falls])
				mark = main.falls
				_put(Vector3(27, 0.6, 11), Vector3.ZERO)
				_next()
		4:  # wait near the ghost's home: it drifts over
			if pt > 4.0:
				_check("ghost chases and pops a nearby ball", main.falls > mark, "falls %d -> %d" % [mark, main.falls])
				mark = main.falls
				_put(Vector3(37.2, 0.6, 4.6), Vector3.ZERO)  # inside the sweep, out of the ghost's range
				moved = 0.0
				_next()
		5:  # inside the windmill's sweep
			moved = maxf(moved, ball.linear_velocity.length())
			if pt > 4.0:
				_check("windmill swats but doesn't pop", moved > 2.0 and main.falls == mark,
					"max speed %.1f, falls %d -> %d" % [moved, mark, main.falls])
				max_y = -99.0
				landing = Vector3.INF
				_put(Vector3(1.0, 0.6, 17.0), Vector3(3, 0, 0))
				_next()
		6:  # roll into the catapult's spoon from behind
			var p := ball.global_position
			max_y = maxf(max_y, p.y)
			if max_y > 3.0 and p.y < 1.2 and landing == Vector3.INF:
				landing = p
			if pt > 5.0:
				var target := Vector3(25, 0.5, 17)
				_check("catapult flings the ball onto the target", landing.distance_to(target) < 2.5,
					"apex %.1f, landed %s" % [max_y, landing.snapped(Vector3.ONE * 0.1)])
				print("\n".join(results))
				print("HAZARDS TEST ", "FAILED" if failed else "PASSED")
				quit(1 if failed else 0)
	return false


func _put(pos: Vector3, vel: Vector3) -> void:
	PhysicsServer3D.body_set_state(ball.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, pos))
	PhysicsServer3D.body_set_state(ball.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, vel)


func _next() -> void:
	phase += 1
	phase_start = t


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

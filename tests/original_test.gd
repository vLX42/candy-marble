extends SceneTree
## The Marble Madness arcade features: pipes, ice, acid slime, the black
## steelie, the GOAL pad, the Silly Race and the arcade countdown.
##   godot --headless --fixed-fps 120 -s tests/original_test.gd

var main: Node3D
var mg: GDScript
var t := 0.0
var phase := 0
var phase_start := 0.0
var results: Array[String] = []
var failed := false
var mark := 0.0
var v0 := Vector3.ZERO
var steelie: Node3D
var enemy: Node3D


func _initialize() -> void:
	mg = load("res://scripts/main.gd")
	var base := {
		title = "arcade test", par = 30.0,
		heights = [
			"000000000000000000000",
			"000000000000000000000",
			"000000000000000000000",
			"0000000000eeee2222222",
			"0000000000eeee2222222",
			"0000000000eeee2222222",
			"000000000000000000000",
			"000000000000000000000",
			"000000000000000000000",
			"000000000000000000000",
		],
		objects = [
			".....................",
			".S...................",
			".....................",
			".....................",
			".....................",
			".....................",
			".....................",
			"IIIIIIII.............",
			"IIIIIIII.............",
			".....................",
		],
		extras = [
			{type = "pipe", tile = [3, 1], target_tile = [16, 1]},
			{type = "slime", tile = [12, 8], travel = [0, 0, 0], period = 4.0},
			{type = "steelie", tile = [4, 9], sense = 12.0, leash = 20.0},
			{type = "goalpad", tile = [18, 8]},
			{type = "enemy", tile = [7, 4], travel = [0, 0, 0], period = 3.0},
			{type = "bird", tile = [1, 5], target_tile = [5, 5]},
		],
	}
	var silly := base.duplicate(true)
	silly.title = "silly test"
	silly.silly = true
	var q := Quest.create("arcade test")
	q.id = "testarcade"
	q.levels = [base, silly]
	mg.set("quest", q)
	mg.set("requested_level", 0)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_scores = false
	main.countdown = false
	main.auto_advance = false
	root.add_child(main)


func _put(tile: Vector2, vel: Vector3) -> void:
	var b: Ball = main.ball
	b.sleeping = false
	var p := Vector3((tile.x + 0.5) * 2.0, 0.0, (tile.y + 0.5) * 2.0)
	p.y = main.level.height(p.x, p.z) + 0.55
	b.global_position = p
	b.linear_velocity = vel
	b.angular_velocity = Vector3.ZERO


func _process(delta: float) -> bool:
	t += delta
	var pt := t - phase_start
	var b: Ball = main.ball
	match phase:
		0:
			if pt > 0.5:
				_put(Vector2(1, 1), Vector3(4, 0, 0))
				_next()
		1:  # pipe: in at tile (3,1), out at (16,1)
			if pt > 2.0:
				var d := Vector2(b.global_position.x, b.global_position.z).distance_to(Vector2(33, 3))
				_check("the pipe carries the marble to its spout", d < 5.0 and b.visible, "%.1f from the spout" % d)
				_put(Vector2(1, 7.5), Vector3(5, 0, 0))
				_next()
		2:  # ice
			if pt > 0.3 and mark == 0.0:
				mark = 1.0
				_check("ice is slippery", b._on_ice and (b.physics_material_override as PhysicsMaterial).friction < 0.1,
					"on ice %s" % b._on_ice)
			if pt > 1.0:
				mark = 0.0
				v0 = Vector3(main.falls, 0, 0)
				_put(Vector2(12, 7), Vector3(0, 0, 3))
				_next()
		3:  # slime melts
			if pt > 2.5:
				_check("acid slime melts the marble", main.falls > int(v0.x), "falls %d -> %d" % [int(v0.x), main.falls])
				_next()
		4:
			if b.alive and pt > 0.5 and mark == 0.0:
				for n in main.world.get_children():
					if n is Steelie:
						steelie = n
				mark = 1.0
				v0 = steelie.global_position
				_put(Vector2(8, 9), Vector3.ZERO)
			if mark == 1.0 and pt > 3.0:
				var moved := Vector2(steelie.global_position.x - v0.x, steelie.global_position.z - v0.z).length()
				_check("the steelie rolls after the marble", moved > 3.0, "moved %.1f" % moved)
				mark = 0.0
				_next()
		5:  # the bird carries the marble across
			if mark == 0.0:
				mark = 1.0
				_put(Vector2(1, 5), Vector3.ZERO)
			elif pt < 2.8 and int(pt * 120) % 30 == 0 and "--trace" in OS.get_cmdline_user_args():
				print("  bird t=%.2f ball %s frozen=%s" % [pt, b.global_position.snapped(Vector3.ONE * 0.1), b.freeze])
			elif pt > 2.8:  # checked right after the drop, before the steelie comes for it
				var d := Vector2(b.global_position.x, b.global_position.z).distance_to(Vector2(11, 11))
				_check("the bird carries the marble to its landing spot", d < 3.0 and b.visible and b.alive and not b.freeze,
					"%.1f from the spot" % d)
				mark = 0.0
				_put(Vector2(18, 8), Vector3.ZERO)
				_next()
		6:  # goal pad
			if pt > 1.0:
				_check("rolling onto the GOAL pad finishes", main.finished, "finished %s" % main.finished)
				main.start_level(1)
				_next()
		7:  # Silly Race
			if pt > 0.5 and mark == 0.0:
				mark = 1.0
				_check("silly level flags the marble", main.level.silly and main.ball.silly, "")
				_put(Vector2(11, 4), Vector3.ZERO)
				v0 = main.ball.global_position
			if mark == 1.0 and pt > 2.0:
				var up: float = main.ball.global_position.y - v0.y
				_check("silly slopes roll the marble uphill", up > 0.08 and main.ball.linear_velocity.x > 1.0, "rose %.2f freeze=%s sleep=%s alive=%s lock=%.1f v=%s" % [up, main.ball.freeze, main.ball.sleeping, main.ball.alive, main.ball.input_lock, main.ball.linear_velocity])
				for n in main.world.get_children():
					if n is Enemy:
						enemy = n
				mark = 2.0
				v0 = Vector3(main.falls, 0, 0)
				_put(Vector2(6, 4), Vector3(4, 0, 0))
				phase_start = t
				return false
			if mark == 2.0 and pt < 1.5 and int(pt * 120) % 20 == 0 and "--trace" in OS.get_cmdline_user_args():
				print("  ball %s enemy %s" % [main.ball.global_position.snapped(Vector3.ONE * 0.1), enemy.global_position.snapped(Vector3.ONE * 0.1) if is_instance_valid(enemy) else "gone"])
			if mark == 2.0 and pt > 1.5:
				_check("silly marbles squish monsters", not is_instance_valid(enemy) or enemy.has_meta("squished"),
					"ball %s enemy %s" % [main.ball.global_position.snapped(Vector3.ONE * 0.1), enemy.global_position.snapped(Vector3.ONE * 0.1) if is_instance_valid(enemy) else "gone"])
				_check("...and don't pop", main.falls == int(v0.x), "falls %d -> %d" % [int(v0.x), main.falls])
				mark = 0.0
				root.get_node("Settings").arcade = true
				main._bonus_level = -1
				main.time_left = 0.0
				main.start_level(0)
				_next()
		8:  # arcade clock
			if pt > 0.5 and mark == 0.0:
				mark = 1.0
				_check("arcade adds time for the level", main.time_left > 15.0 and main.time_left < 25.0,
					"%.1f s" % main.time_left)
				main.time_left = 0.2
			if mark == 1.0 and pt > 1.0:
				_check("the clock running out ends the run", main.time_up and main.hud.results_text().contains("Time's up"),
					main.hud.results_text().replace("\n", " | "))
				root.get_node("Settings").arcade = false
				print("\n".join(results))
				print("ORIGINAL TEST ", "FAILED" if failed else "PASSED")
				quit(1 if failed else 0)
	return false


func _next() -> void:
	phase += 1
	phase_start = t


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

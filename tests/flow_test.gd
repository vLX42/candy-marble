extends SceneTree
## Countdown, pause menu, best-run ghost and editor "test from here".
##   godot --headless --fixed-fps 120 -s tests/flow_test.gd

var main: Node3D
var mg: GDScript
var t := 0.0
var phase := 0
var phase_start := 0.0
var results: Array[String] = []
var failed := false
var mark := 0.0
var once := false


func _initialize() -> void:
	mg = load("res://scripts/main.gd")
	var q := Quest.create("flow test")
	q.id = "testflow"
	q.levels = [{
		title = "flow test", par = 30.0,
		heights = ["000000000000", "000000000000", "000000000000", "000000000000"],
		objects = ["............", ".S........G.", "............", "............"],
	}]
	mg.set("quest", q)
	mg.set("requested_level", 0)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_scores = false
	main.auto_advance = false
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	var pt := t - phase_start
	match phase:
		0:
			if pt > 0.5:
				_check("course flyover plays first", main._fly_left > 0.0 and main.level_time == 0.0 and main.ball.input_lock > 2.4,
					"fly %.2f lock %.2f" % [main._fly_left, main.ball.input_lock])
				Input.action_press("up")
				_next()
		1:
			Input.action_release("up")
			if pt > 0.1 and mark == 0.0:
				mark = 1.0
				_check("any direction skips the flyover", main._fly_left == 0.0, "%.2f" % main._fly_left)
			if pt > 0.5 and mark == 1.0:
				mark = 2.0
				_check("countdown holds the clock", main.level_time == 0.0 and main.ball.input_lock > 0.0,
					"time %.2f lock %.2f" % [main.level_time, main.ball.input_lock])
			if pt > 3.0:
				_check("GO starts the clock", main.level_time > 0.4, "time %.2f" % main.level_time)
				main.start_level(0)
				_check("restart skips the flyover", main._fly_left == 0.0, "%.2f" % main._fly_left)
				main._count_left = 0.0
				main.ball.input_lock = 0.0
				_next()
		2:
			if pt > 0.5:
				Input.action_press("pause")
				_next()
		3:
			Input.action_release("pause")
			if pt > 0.2 and not once:
				once = true
				mark = main.level_time
				_check("Esc pauses and shows the menu", paused and main.hud.is_paused_visible(), "paused %s" % paused)
			if pt > 1.2:
				_check("paused clock stands still", is_equal_approx(main.level_time, mark), "%.2f -> %.2f" % [mark, main.level_time])
				main._on_pause_action("resume")
				_check("resume unpauses", not paused and not main.hud.is_paused_visible(), "")
				_next()
		4:
			if pt > 0.5:
				_check("clock runs again", main.level_time > mark, "%.2f" % main.level_time)
				# Ghost: save a straight-line run, reload, and watch it replay.
				var rec := PackedVector3Array()
				for k in 60:
					rec.append(Vector3(3.0 + k * 0.3, 0.5, 3.0))
				main._ghost_rec = rec
				main.save_scores = true
				main._save_ghost()
				root.get_node("Settings").ghost = true
				main.load_level(main.level)
				main.countdown = false
				main._count_left = 0.0
				main.level_time = 1.5
				main._update_ghost()
				var g: Node3D = main._ghost
				_check("ghost replays the saved run", g != null and g.visible and absf(g.global_position.x - (3.0 + 30 * 0.3)) < 0.1,
					str(g.global_position if g else "none"))
				main.level_time = 10.0
				main._update_ghost()
				_check("ghost hides after its run ends", g != null and not g.visible, "")
				DirAccess.remove_absolute(main._ghost_path())
				main.save_scores = false
				# Editor test play from a picked tile.
				mg.set("test_mode", true)
				mg.set("test_start", Vector2i(8, 2))
				main.load_level(main.level)
				var p: Vector3 = main.ball.global_position
				_check("test play starts on the picked tile", Vector2i(int(p.x / 2.0), int(p.z / 2.0)) == Vector2i(8, 2), str(p))
				mg.set("test_mode", false)
				mg.set("test_start", Vector2i(-1, -1))
				# Two results cards in a row (finishing level 1, then level 2): only
				# the new chips may be left to animate.
				var r := {title = "In the hole!", time = 10.0, medal = "GOLD", badge = "NEW BEST!", info = ""}
				main.hud.show_results(r)
				main.hud.show_results(r)
				_check("second results card only holds its own chips", main.hud._res_chips.get_child_count() == 2,
					"%d chips" % main.hud._res_chips.get_child_count())
				print("\n".join(results))
				print("FLOW TEST ", "FAILED" if failed else "PASSED")
				quit(1 if failed else 0)
	return false


func _next() -> void:
	phase += 1
	phase_start = t


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

extends SceneTree
## Phone controls: tilt maths for every screen rotation, and the drag stick
## driving the marble in the game.
##   godot --headless --fixed-fps 120 -s tests/touch_test.gd

var results: Array[String] = []
var failed := false
var main: Node3D
var t := 0.0
var phase := 0
var start := Vector3.ZERO


func _initialize() -> void:
	var tilt: GDScript = load("res://scripts/tilt.gd")
	# Portrait: tip the right edge down (gamma +) = right; top edge towards you (beta +) = down.
	_check("portrait tilt", tilt.screen_tilt(10, 20, 0) == Vector2(20, 10), str(tilt.screen_tilt(10, 20, 0)))
	# Landscape, rotated left (angle 90): the phone's beta axis runs across the screen.
	_check("landscape 90", tilt.screen_tilt(10, 20, 90) == Vector2(10, -20), str(tilt.screen_tilt(10, 20, 90)))
	_check("landscape 270", tilt.screen_tilt(10, 20, -90) == Vector2(-10, 20), str(tilt.screen_tilt(10, 20, -90)))
	_check("upside down", tilt.screen_tilt(10, 20, 180) == Vector2(-20, -10), "")
	var small: Vector2 = tilt.tilt_to_input(Vector2(1.0, -1.0), 1.0)
	_check("small wobble is ignored", small == Vector2.ZERO, str(small))
	var full: Vector2 = tilt.tilt_to_input(Vector2(40.0, 0.0), 1.0)
	_check("big tilt is full speed", is_equal_approx(full.x, 1.0), str(full))
	var half: Vector2 = tilt.tilt_to_input(Vector2(9.75, 0.0), 1.0)
	var keen: Vector2 = tilt.tilt_to_input(Vector2(9.75, 0.0), 2.0)
	_check("sensitivity scales tilt", half.x > 0.4 and half.x < 0.6 and keen.x > 0.99, "%.2f %.2f" % [half.x, keen.x])
	var diag: Vector2 = tilt.tilt_to_input(Vector2(40.0, 40.0), 1.0)
	_check("diagonal stays unit length", is_equal_approx(diag.length(), 1.0), str(diag))

	var mg: GDScript = load("res://scripts/main.gd")
	mg.set("quest", null)
	mg.set("requested_level", 0)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_scores = false
	main.countdown = false
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	var tl: Node = root.get_node("Tilt")
	match phase:
		0:
			if t > 0.5:
				start = main.ball.global_position
				root.get_node("Settings").control_mode = "stick"
				# Pretend to be a touch screen: feed the stick directly.
				var down := InputEventScreenTouch.new()
				down.index = 0
				down.pressed = true
				down.position = Vector2(800, 600)
				tl.handle_touch(down)
				var drag := InputEventScreenDrag.new()
				drag.index = 0
				drag.position = Vector2(800, 510)   # drag up the screen
				tl.handle_touch(drag)
				_check("stick reads a drag", tl.stick_vector().y < -0.9, str(tl.stick_vector()))
				phase = 1
		1:
			# The game's touch input only runs on touch screens; drive it here.
			var v: Vector2 = tl.stick_vector()
			main._touch_press("up", -v.y)
			if t > 2.0:
				var moved: Vector3 = main.ball.global_position - start
				var cam_fwd: Vector3 = -main.camera.global_basis.z
				cam_fwd.y = 0.0
				_check("dragging up rolls the marble up the screen", moved.dot(cam_fwd.normalized()) > 2.0,
					"moved %.2f along the view" % moved.dot(cam_fwd.normalized()))
				var up := InputEventScreenTouch.new()
				up.index = 0
				up.pressed = false
				tl.handle_touch(up)
				_check("lifting the finger stops the stick", tl.stick_vector() == Vector2.ZERO, "")
				print("\n".join(results))
				print("TOUCH TEST ", "FAILED" if failed else "PASSED")
				quit(1 if failed else 0)
	return false


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

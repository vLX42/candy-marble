extends SceneTree
## Campaign extras: the Sprinkle Islands easter egg (roll backwards off the
## start pad, find the secret, ride the secret cannon to the flag).
##   godot --headless --fixed-fps 120 -s tests/campaign_test.gd

var main: Node3D
var t := 0.0
var phase := 0
var phase_start := 0.0
var results: Array[String] = []
var failed := false
var secret: Node
var start := Vector3.ZERO


func _initialize() -> void:
	var mg: GDScript = load("res://scripts/main.gd")
	mg.set("quest", null)
	mg.set("requested_level", 4)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_scores = false
	main.countdown = false
	main.auto_advance = false
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	var pt := t - phase_start
	match phase:
		0:
			if pt > 0.5:
				_check("level 5 is Starlight Islands", main.level.title == "Starlight Islands", main.level.title)
				for n in main.world.get_children():
					if n is Secret:
						secret = n
				_check("the secret is in the level", secret != null, "")
				start = main.ball.global_position
				_next()
		1:
			# Roll backwards (-x) off the start pad, like a curious player.
			if main.ball.alive:
				main.ball.apply_central_force(Vector3(-14, 0, 0))
			if "--trace" in OS.get_cmdline_user_args() and int(pt * 120) % 30 == 0:
				print("  t=%.2f pos=%s alive=%s" % [pt, main.ball.global_position.snapped(Vector3.ONE * 0.1), main.ball.alive])
			if secret and secret._found:
				_check("rolling backwards finds the secret island", true, "%.1f s" % pt)
				_next()
			elif pt > 12.0:
				_check("rolling backwards finds the secret island", false, str(main.ball.global_position))
				_finish()
		2:
			# Roll on to the secret cannon: it should fling us next to the flag.
			var cannon: Node3D
			for n in main.world.get_children():
				if n.get("kind") == "cannon" and n.global_position.x < start.x:
					cannon = n
			if pt < 0.1 and cannon:
				PhysicsServer3D.body_set_state(main.ball.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
					Transform3D(Basis.IDENTITY, cannon.global_position + Vector3(0, 0.8, 0)))
				PhysicsServer3D.body_set_state(main.ball.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
			var g: Vector2 = main.level.goal
			var d := Vector2(main.ball.global_position.x, main.ball.global_position.z).distance_to(g)
			if pt > 1.0 and main.ball.is_grounded() and d < 10.0:
				_check("the secret cannon lands you by the flag", true, "%.1f from the hole" % d)
				_finish()
			elif pt > 8.0:
				_check("the secret cannon lands you by the flag", false, "%.1f from the hole, at %s" % [d, main.ball.global_position])
				_finish()
	if phase == 10 and pt > 0.5:
		var flip: Node3D
		for n in main.world.get_children():
			if n.get("kind") == "flipper":
				flip = n
				break
		_check("pinball tables have flippers", flip != null, "")
		if flip == null:
			_finish()
			return false
		var dir: Vector3 = flip.global_basis.z
		main.ball.sleeping = false
		main.ball.global_position = flip.global_position + Vector3(0, 0.6, 0) - dir * 2.2
		main.ball.linear_velocity = dir * 3.0
		set_meta("flipdir", dir)
		phase = 11
		phase_start = t
	elif phase == 11 and pt < 0.9 and "--trace" in OS.get_cmdline_user_args():
		print("  t=%.2f pos=%s v=%s alive=%s" % [pt, main.ball.global_position.snapped(Vector3.ONE * 0.1), main.ball.linear_velocity.snapped(Vector3.ONE * 0.1), main.ball.alive])
	elif phase == 11 and pt > 0.9:
		var v: Vector3 = main.ball.linear_velocity
		var d: Vector3 = get_meta("flipdir")
		_check("the flipper bats the marble up the table", Vector2(v.x, v.z).dot(Vector2(d.x, d.z)) > 8.0,
			"speed along the flip %.1f" % Vector2(v.x, v.z).dot(Vector2(d.x, d.z)))
		_finish()
	return false


func _finish() -> void:
	if not has_meta("flip"):
		set_meta("flip", true)
		_flipper_check()
		return
	print("\n".join(results))
	print("CAMPAIGN TEST ", "FAILED" if failed else "PASSED")
	quit(1 if failed else 0)


## Level 8: rolling onto a flipper bats the marble up the table.
func _flipper_check() -> void:
	main.start_level(7)
	phase = 10
	phase_start = t


func _next() -> void:
	phase += 1
	phase_start = t


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

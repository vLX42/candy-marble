extends SceneTree
## Floating candies: rolling through one pops it and gives a random effect,
## it comes back later, the rival can't eat them,
## sticky slows the marble and dizzy turns the steering.
##   godot --headless --fixed-fps 120 -s tests/candy_test.gd

class CandyLevel extends LevelBase:
	func _init() -> void:
		title = "candy test"
		heights = [
			"0000000000000",
			"0000000000000",
			"0000000000000",
			"0000000000000",
			"0000000000000",
		]
		objects = [
			".............",
			".S..g...%..r.",
			".............",
			".............",
			".............",
		]

var main: Node3D
var t := 0.0
var phase := 0
var phase_start := 0.0
var failed := false
var effects := {}
var away := -1.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.get_script().set("candy_seed", 1)
	main.save_scores = false
	main.countdown = false
	main.auto_advance = false
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if phase == 0:
		root.get_node("Settings").camera_follow = false
		main.load_level(CandyLevel.new())
		_next()
		return false
	var pt := t - phase_start
	match phase:
		1:
			if pt > 0.5:
				_put(_candy("golden_cupcake").global_position)
				_next()
		2:
			if pt > 0.3:
				var any: bool = main.rush_left > 0.0 or main.sticky_left > 0.0 or main.dizzy_left > 0.0
				_check("a golden cupcake gives an effect", any, "rush %.1f sticky %.1f dizzy %.1f" % [main.rush_left, main.sticky_left, main.dizzy_left])
				_check("an eaten candy is gone", _candy("golden_cupcake")._eaten, "")
				_clear()
				# Eat the gumdrop a few times (it comes back) and collect the effects.
				_next()
		3:
			var g := _candy("gumdrop")
			if not g._eaten:
				# Step out first, so rolling back in counts as touching it again.
				if away < 0.0:
					_clear()
					away = 0.3
				away -= _delta
				if away < 0.0:
					_put(g.global_position)
			elif main.rush_left > 0.0:
				effects["rush"] = true
			elif main.sticky_left > 0.0:
				effects["sticky"] = true
			elif main.dizzy_left > 0.0:
				effects["dizzy"] = true
			if pt > 75.0 or effects.size() == 3:
				_check("a gumdrop comes back and is a gamble (rush, sticky, dizzy)", effects.size() == 3, str(effects.keys()))
				_clear()
				_next()
		4:
			main.ball.sticky = true
			var slow: float = main.ball.max_speed
			main.ball.sticky = false
			_check("sticky toffee slows the marble", slow < main.ball.max_speed * 0.7, "%.1f vs %.1f" % [slow, main.ball.max_speed])
			main.ball.dizzy = true
			Input.action_press("up", 1.0)
			var turned := false
			for k in 40:
				main.ball._dizzy_t += 0.05
				var d: Vector3 = main.ball._steer_dir()
				main.ball.dizzy = false
				var straight: Vector3 = main.ball._steer_dir()
				main.ball.dizzy = true
				turned = turned or d.angle_to(straight) > 0.3
			Input.action_release("up")
			main.ball.dizzy = false
			_check("dizzy turns the steering", turned, "")
			# A rival rolling through doesn't eat it.
			var r := _candy("wrapped_candy")
			var rival: Rival = load("res://scenes/rival.tscn").instantiate()
			rival.level = main.level
			main.world.add_child(rival)
			rival.global_position = r.global_position + Vector3.UP * 0.1
			_next()
		5:
			if pt > 0.4:
				_check("the rival can't eat candy", not _candy("wrapped_candy")._eaten, "")
				print("CANDY TEST ", "FAILED" if failed else "PASSED")
				quit(1 if failed else 0)
	return false


func _candy(kind: String) -> Decor:
	for c in main.world.get_children():
		if c is Decor and c.kind == kind:
			return c
	return null


func _put(p: Vector3) -> void:
	var ball: Ball = main.ball
	PhysicsServer3D.body_set_state(ball.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis.IDENTITY, Vector3(p.x, 0.6, p.z)))
	ball.linear_velocity = Vector3.ZERO


func _clear() -> void:
	main.rush_left = 0.0
	main.ball.rush = false
	main._end_sticky()
	main.dizzy_left = 0.0
	main.ball.dizzy = false
	var s: Vector2 = main.level.spawn
	_put(Vector3(s.x, 0.0, s.y))


func _next() -> void:
	phase += 1
	phase_start = t


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		failed = true

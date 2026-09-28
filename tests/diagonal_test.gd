extends SceneTree
## Diagonal ramp tiles (a b c d): they meet the plateaus without a step, the
## marble rolls down one on its own and can be pushed up it.
##   godot --headless --fixed-fps 120 -s tests/diagonal_test.gd

var main: Node3D
var t := 0.0
var phase := 0
var phase_start := 0.0
var results: Array[String] = []
var failed := false
var mark := Vector3.ZERO


class DiagLevel extends LevelBase:
	func _init() -> void:
		title = "diagonal test"
		time_limit = 30.0
		step = 1.0
		# A high plateau (tier 4) in the top left corner, a band of four "a"
		# tiles along the anti-diagonal (rising towards -x-z), then tier 0.
		heights = []
		objects = []
		for j in 16:
			var h := ""
			var o := ""
			for i in 16:
				var s := i + j
				h += "4" if s <= 5 else ("a" if s <= 9 else "0")
				o += "S" if (i == 2 and j == 2) else ("G" if (i == 13 and j == 13) else ".")
			heights.append(h)
			objects.append(o)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.save_scores = false
	main.countdown = false
	main.auto_advance = false
	root.add_child(main)


func _put(p: Vector3, vel: Vector3) -> void:
	var b: Ball = main.ball
	b.sleeping = false
	b.global_position = Vector3(p.x, main.level.height(p.x, p.z) + 0.55, p.z)
	b.linear_velocity = vel
	b.angular_velocity = Vector3.ZERO


func _process(delta: float) -> bool:
	t += delta
	var pt := t - phase_start
	if phase == 0:
		main.load_level(DiagLevel.new())
		_next()
		return false
	var b: Ball = main.ball
	match phase:
		1:
			# Geometry: sample along every shared tile edge; neighbouring tiles must agree.
			var lvl: LevelBase = main.level
			var worst := 0.0
			var where := Vector2i.ZERO
			for j in 16:
				for i in 16:
					for k in 9:
						var f := k / 8.0 * LevelBase.TILE
						# right edge shared with (i+1, j)
						var x := (i + 1) * LevelBase.TILE
						var z := j * LevelBase.TILE + f
						var gap := absf(lvl.surface(i, j, x, z) - lvl.surface(i + 1, j, x, z))
						if i < 15 and gap > worst:
							worst = gap
							where = Vector2i(i, j)
						# bottom edge shared with (i, j+1)
						x = i * LevelBase.TILE + f
						z = (j + 1) * LevelBase.TILE
						gap = absf(lvl.surface(i, j, x, z) - lvl.surface(i, j + 1, x, z))
						if j < 15 and gap > worst:
							worst = gap
							where = Vector2i(i, j)
			_check("diagonal ramps meet their neighbours without a step", worst < 0.001, "worst gap %.3f at %s" % [worst, where])
			var top := lvl.height(5.0, 5.0)   # u = 10, first tile's flat half
			var mid := lvl.height(8.0, 8.0)    # u = 16, on the incline
			var low := lvl.height(21.0, 21.0)  # u = 42, past the band
			_check("the incline runs between the plateau heights", is_equal_approx(top, 4.0) and is_equal_approx(low, 0.0) and mid > 0.5 and mid < 3.5,
				"top %.2f mid %.2f low %.2f" % [top, mid, low])
			_put(Vector3(9.0, 0, 9.0), Vector3.ZERO)
			_next()
		2:  # rolls down on its own
			if pt > 2.5:
				var p := b.global_position
				_check("the marble rolls down the diagonal slope by itself", p.x > 13.0 and p.z > 13.0 and p.y < 2.0,
					"at %s" % p.snapped(Vector3.ONE * 0.1))
				_put(Vector3(23.0, 0, 23.0), Vector3.ZERO)
				_next()
		3:  # can be pushed up
			var p := b.global_position
			var up := p.x + p.z < 13.5 and p.y > 3.8
			if pt < 6.0 and not up:
				b.apply_central_force(Vector3(-1, 0, -1).normalized() * b.push_force)
			else:
				_check("...and can be pushed up it", up, "at %s after %.1f s" % [p.snapped(Vector3.ONE * 0.1), pt])
				print("\n".join(results))
				print("DIAGONAL TEST ", "FAILED" if failed else "PASSED")
				quit(1 if failed else 0)
	return false


func _next() -> void:
	phase += 1
	phase_start = t


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

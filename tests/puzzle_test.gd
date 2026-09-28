extends SceneTree
## Switch puzzles and the smarter monsters:
##  - numbered switches: a wrong order pops them all up, the right one opens the gate
##  - several switches on one gate: all of them are needed
##  - a timed combo pops back up if it isn't finished in time
##  - a lever flips a bridge up and an inverted bridge down, and back
##  - the steelie never rolls off an edge after a marble it can't reach
##  - the steelie finds its way round a corner and knocks the marble off a ledge
##   godot --headless --fixed-fps 120 -s tests/puzzle_test.gd

var main: Node3D
var t := 0.0
var phase := 0
var phase_start := 0.0
var results: Array[String] = []
var failed := false
var falls0 := 0
var steelie_a: Steelie
var steelie_b: Steelie
var home_a := Vector3.ZERO


class PuzzleLevel extends LevelBase:
	func _init() -> void:
		title = "puzzle test"
		time_limit = 30.0
		heights = []
		objects = []
		for j in 16:
			var h := ""
			for i in 24:
				var c := "."
				if j <= 7:
					c = "0"                              # the switch yard
				elif j in [9, 10] and i <= 4:
					c = "0"                              # the steelie's island
				elif j in [9, 10] and i >= 6 and i <= 8:
					c = "0"                              # out of its reach, over a gap
				elif i in [12, 13] and j >= 9:
					c = "0"                              # an L: up the side...
				elif j in [9, 10] and i >= 12 and i <= 20:
					c = "0"                              # ...and along the top
				h += c
			heights.append(h)
			objects.append(".".repeat(24))
		objects[7] = ".S" + ".".repeat(22)
		extras = [
			{type = "switch", tile = Vector2(2, 2), channel = "seq", order = 1},
			{type = "switch", tile = Vector2(5, 2), channel = "seq", order = 2},
			{type = "switch", tile = Vector2(8, 2), channel = "seq", order = 3},
			{type = "gate", tile = Vector2(10, 5.5), channel = "seq", size = Vector2(1, 2)},
			{type = "switch", tile = Vector2(2, 5), channel = "both"},
			{type = "switch", tile = Vector2(5, 5), channel = "both"},
			{type = "gate", tile = Vector2(12, 5.5), channel = "both", size = Vector2(1, 2)},
			{type = "switch", tile = Vector2(14, 2), channel = "combo", open_time = 1.5},
			{type = "switch", tile = Vector2(17, 2), channel = "combo", open_time = 1.5},
			{type = "gate", tile = Vector2(20, 5.5), channel = "combo", size = Vector2(1, 2)},
			{type = "switch", tile = Vector2(15, 6), channel = "lever", toggle = 1},
			{type = "gate", tile = Vector2(22, 1.5), channel = "lever", size = Vector2(2, 2), bridge = true, y = 0.0},
			{type = "gate", tile = Vector2(22, 4.5), channel = "lever", size = Vector2(2, 2), bridge = true, y = 0.0, invert = 1},
			{type = "steelie", tile = Vector2(2, 9.5), sense = 12.0, leash = 12.0},
			{type = "steelie", tile = Vector2(12.5, 14), sense = 18.0, leash = 40.0},
		]


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.save_scores = false
	main.countdown = false
	main.auto_advance = false
	root.add_child(main)


func _put(tile: Vector2) -> void:
	var b: Ball = main.ball
	b.sleeping = false
	var p: Vector2 = main.level.tile_center_f(tile)
	PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis.IDENTITY, Vector3(p.x, main.level.height(p.x, p.y) + 0.55, p.y)))
	PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)


func _gate(channel: String, inverted: bool = false) -> Gate:
	for g in get_nodes_in_group("gate_" + channel):
		if bool(g.invert) == inverted:
			return g
	return null


func _lit(channel: String) -> int:
	var n := 0
	for s in get_nodes_in_group("switch_" + channel):
		if s.lit:
			n += 1
	return n


## Presses the switches at `tiles` one after another, `gap` seconds apart,
## starting at phase time `from`. Returns true once all are pressed.
func _press(tiles: Array, pt: float, from: float, gap: float = 0.5) -> bool:
	for k in tiles.size():
		var at := from + k * gap
		if pt >= at and pt < at + 1.0 / 60.0:
			_put(tiles[k])
		# Step off between presses so the next landing counts as a new press.
		if pt >= at + gap * 0.6 and pt < at + gap * 0.6 + 1.0 / 60.0:
			_put(Vector2(1, 7))
	return pt > from + tiles.size() * gap + 0.2


func _process(delta: float) -> bool:
	t += delta
	var pt := t - phase_start
	match phase:
		0:
			root.get_node("Settings").camera_follow = false
			main.load_level(PuzzleLevel.new())
			_next()
		1:
			if pt > 0.3:
				for s in get_nodes_in_group("steelie"):
					if s.global_position.x < 12.0:
						steelie_a = s
					else:
						steelie_b = s
				home_a = steelie_a.global_position
				_next()
		2:  # sequence, wrong order: 2 first
			if _press([Vector2(5, 2)], pt, 0.1):
				_check("a switch pressed out of order pops back up", _lit("seq") == 0 and not _gate("seq").is_open,
					"%d lit" % _lit("seq"))
				_next()
		3:  # sequence, 1 then 3: wrong again, resets the 1
			if _press([Vector2(2, 2), Vector2(8, 2)], pt, 0.1):
				_check("skipping a number resets the whole set", _lit("seq") == 0 and not _gate("seq").is_open,
					"%d lit" % _lit("seq"))
				_next()
		4:  # sequence, right order
			if _press([Vector2(2, 2), Vector2(5, 2), Vector2(8, 2)], pt, 1.1):
				_check("1, 2, 3 in order opens the gate", _gate("seq").is_open, "lit %d" % _lit("seq"))
				_next()
		5:  # two switches, one gate
			if _press([Vector2(2, 5)], pt, 0.1):
				_check("one of two switches isn't enough", not _gate("both").is_open, "")
				_next()
		6:
			if _press([Vector2(5, 5)], pt, 0.1):
				_check("both switches open the gate", _gate("both").is_open, "")
				_next()
		7:  # timed combo: press one, dawdle
			if _press([Vector2(14, 2)], pt, 0.1) and pt > 2.2:
				_check("a timed combo pops back up when too slow", _lit("combo") == 0 and not _gate("combo").is_open,
					"%d lit" % _lit("combo"))
				_next()
		8:
			if _press([Vector2(14, 2), Vector2(17, 2)], pt, 0.1):
				_check("...and opens when done in time", _gate("combo").is_open, "")
				_next()
		9:  # lever
			if _press([Vector2(15, 6)], pt, 0.1):
				_check("the lever raises one bridge and drops the other",
					_gate("lever").is_open and not _gate("lever", true).is_open,
					"normal %s inverted %s" % [_gate("lever").is_open, _gate("lever", true).is_open])
				_next()
		10:
			if _press([Vector2(15, 6)], pt, 1.2):
				_check("...and back again", not _gate("lever").is_open and _gate("lever", true).is_open,
					"normal %s inverted %s" % [_gate("lever").is_open, _gate("lever", true).is_open])
				_put(Vector2(7, 9.5))
				_next()
		11:  # a marble on the far side of a gap: the steelie wants it but mustn't jump
			if pt > 4.0:
				var moved := Vector2(steelie_a.global_position.x - home_a.x, steelie_a.global_position.z - home_a.z).length()
				_check("the steelie doesn't roll off an edge after a marble it can't reach",
					steelie_a.alive and steelie_a.global_position.y > -1.0,
					"alive %s y %.1f moved %.1f" % [steelie_a.alive, steelie_a.global_position.y, moved])
				falls0 = main.falls
				_put(Vector2(17, 9.5))
				_next()
		12:  # round the corner of the L and knock the marble off
			if "--trace" in OS.get_cmdline_user_args() and int(pt * 120) % 15 == 0:
				var sp := steelie_b.global_position / LevelBase.TILE
				print("  t=%.2f steelie tile (%.1f, %.1f) y=%.2f v=%s dir=%s ball %s" % [pt, sp.x, sp.z, steelie_b.global_position.y,
					steelie_b.linear_velocity.snapped(Vector3.ONE * 0.1), steelie_b._steer_dir().snapped(Vector3.ONE * 0.01),
					(main.ball.global_position / LevelBase.TILE).snapped(Vector3.ONE * 0.1)])
			var close := Vector2(steelie_b.global_position.x - main.ball.global_position.x,
				steelie_b.global_position.z - main.ball.global_position.z).length()
			if main.falls > falls0 or pt > 14.0:
				_check("the steelie finds its way round the corner and knocks the marble off",
					main.falls > falls0 and steelie_b.alive,
					"falls %d -> %d, steelie alive %s at %s, %.1f from the marble" % [falls0, main.falls, steelie_b.alive,
						steelie_b.global_position.snapped(Vector3.ONE * 0.1), close])
				print("\n".join(results))
				print("PUZZLE TEST ", "FAILED" if failed else "PASSED")
				quit(1 if failed else 0)
	return false


func _next() -> void:
	phase += 1
	phase_start = t


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

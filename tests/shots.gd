extends SceneTree
## Screenshots of every level along its route (needs a window, not --headless):
##   godot --always-on-top -s tests/shots.gd
## Saves to tests/shots/level<N>_<k>.png

var main: Node3D
var queue: Array = []   # [level_index, waypoint_index]
var t := 0.0
var step := -1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.auto_advance = false

	main.save_scores = false
	main.countdown = false
	root.add_child(main)
	for li in main.LEVELS.size():
		var n: int = main.LEVELS[li].new().route.size()
		for wi in [0, n / 3, 2 * n / 3, n - 1]:
			queue.append([li, wi])
	DirAccess.make_dir_recursive_absolute("res://tests/shots")


func _process(delta: float) -> bool:
	t += delta
	if step >= 0 and t < 1.2:
		return false
	if step >= 0:
		var item: Array = queue[step]
		pass
		RenderingServer.force_draw()
		root.get_viewport().get_texture().get_image().save_png(
			"res://tests/shots/level%d_%d.png" % [item[0] + 1, item[1]])
	step += 1
	if step >= queue.size():
		quit()
		return false
	var li: int = queue[step][0]
	var wi: int = queue[step][1]
	if main.level_index != li or step == 0:
		main.start_level(li)
	var p: Vector2 = main.level.tile_center_f(main.level.route[wi])
	var ball: Ball = main.ball
	PhysicsServer3D.body_set_state(ball.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis.IDENTITY, main.ground(p) + Vector3.UP * 0.6))
	PhysicsServer3D.body_set_state(ball.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	t = 0.0
	return false

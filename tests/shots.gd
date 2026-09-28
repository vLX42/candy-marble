extends SceneTree
## Screenshots of every level along its route (needs a window, not --headless):
##   godot --always-on-top -s tests/shots.gd [-- --quest=res://quests/x.json]
## Saves to tests/shots/level<N>_<k>.png

var main: Node3D
var queue: Array = []   # [level_index, waypoint_index]
var t := 0.0
var step := -1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	var routes: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quest="):
			var q := Quest.load_file(arg.get_slice("=", 1))
			main.get_script().set("quest", q)
			for d: Dictionary in q.levels:
				routes.append(d.get("route", []).size())
	main.auto_advance = false

	main.save_scores = false
	main.countdown = false
	root.add_child(main)
	if routes.is_empty():
		for script: GDScript in main.LEVELS:
			routes.append(script.new().route.size())
	# -- --puzzles: instead of four points along the route, the route point
	# nearest each switch (built-in levels).
	if "--puzzles" in OS.get_cmdline_user_args():
		for li in main.LEVELS.size():
			var lvl: LevelBase = main.LEVELS[li].new()
			for e in lvl.extras:
				if e.type != "switch":
					continue
				var best := 0
				for wi in lvl.route.size():
					if lvl.route[wi].distance_to(e.tile) < lvl.route[best].distance_to(e.tile):
						best = wi
				queue.append([li, best])
	else:
		for li in routes.size():
			var n: int = routes[li]
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

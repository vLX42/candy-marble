extends SceneTree
## Rough render cost of a level. Run with a window (not --headless):
##   godot -s tests/perf.gd -- --level=4
## Prints average FPS, triangles and draw calls over a few seconds of the bot
## camera sitting at several points along the route, plus terrain mesh size.

var main
var t := 0.0
var samples := []
var level := 4
var stops := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = int(a.get_slice("=", 1))
	main = load("res://scenes/main.tscn").instantiate()
	main.first_level = level - 1
	main.save_scores = false
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t < 1.5:
		return false
	# Hop the ball along the route so we look at different parts of the level.
	var route: Array = main.level.route
	var k := int((t - 1.5) / 1.0)
	if k != stops and k < 6:
		stops = k
		var p: Vector2 = main.level.tile_center_f(route[int(route.size() * k / 6.0)])
		PhysicsServer3D.body_set_state(main.ball.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
			Transform3D(Basis.IDENTITY, main.ground(p) + Vector3.UP * 0.6))
	if k >= 6:
		var fps := 0.0
		var tris := 0.0
		var calls := 0.0
		for s in samples:
			fps += s[0]; tris += s[1]; calls += s[2]
		var n := maxf(samples.size(), 1)
		var verts := 0
		for c in main.world.get_children():
			if c is Terrain:
				for m in c.get_children():
					if m is MeshInstance3D:
						verts += m.mesh.surface_get_array_len(0)
		print("PERF level %d: fps %.0f  triangles %.0f  draw calls %.0f  terrain vertices %d" % [level, fps / n, tris / n, calls / n, verts])
		quit()
		return false
	if fmod(t, 1.0) > 0.5:
		samples.append([Performance.get_monitor(Performance.TIME_FPS),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	return false

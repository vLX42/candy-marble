extends SceneTree
## Bot playthrough: steers the ball along each level's `route` using the real
## input actions (like a player on a stick), waits for enemies, and checks the
## goal is reached. Run fast and headless:
##   godot --headless --fixed-fps 120 -s tests/levels_test.gd
## One level only:  ... -- --level=2

const MAX_SIM_TIME := 180.0
const CRUISE := 6.0

var main: Node3D
var levels: Array[int] = []
var li := 0
var wp := 0
var level_t := 0.0
var wait := 0.0
var was_alive := true
var results: Array[String] = []
var failed := false


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.auto_advance = false

	main.save_scores = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			levels = [int(arg.get_slice("=", 1)) - 1]
	if levels.is_empty():
		for i in main.LEVELS.size():
			levels.append(i)
	main.first_level = levels[0]
	root.add_child(main)


func _process(delta: float) -> bool:
	level_t += delta
	var ball: Ball = main.ball
	if main.finished:
		_report(true)
		return false
	if level_t > MAX_SIM_TIME:
		_report(false)
		return false

	if not ball.alive:
		if was_alive and "--verbose" in OS.get_cmdline_user_args():
			print("  died at %s (waypoint %d)" % [ball.global_position.snapped(Vector3.ONE * 0.1), wp])
		_release()
		was_alive = false
		return false
	if not was_alive:
		# Respawned: continue from the waypoint nearest the respawn point, after a
		# random pause so we don't hit a sweeper at the same moment every time.
		was_alive = true
		wp = _nearest_waypoint(_flat(ball.global_position))
		wait = randf_range(0.0, 1.5)
	if wait > 0.0:
		wait -= delta
		_release()
		return false
	_steer(ball)
	if "--verbose" in OS.get_cmdline_user_args() and int(level_t * 120) % 1200 == 0:
		print("  t=%.0f pos=%s wp=%d" % [level_t, ball.global_position.snapped(Vector3.ONE * 0.1), wp])
	return false


func _steer(ball: Ball) -> void:
	var route := _route()
	var pos := _flat(ball.global_position)
	# Hands off while looping or flying.
	if ball.global_position.y > main.level.height(pos.x, pos.y) + 1.1:
		_release()
		return
	# Advance when close to the waypoint or already past it.
	while wp < route.size() - 1:
		var here := route[wp]
		var next := route[wp + 1]
		if pos.distance_to(here) < 1.0 or (pos - here).dot(next - here) > 0.0:
			wp += 1
		else:
			break
	var to := route[wp] - pos
	var dir := to.normalized()
	var vel := Vector2(ball.linear_velocity.x, ball.linear_velocity.z)
	var last := wp == route.size() - 1
	# Putt gently into the hole; elsewhere cruise.
	var target_speed := clampf(to.length() * 1.2, 1.2, 4.0) if last else CRUISE
	var ctrl := dir * target_speed - vel
	# Never brake on purpose (keeps booster speed for jumps), only steer.
	var along := ctrl.dot(dir)
	if along < 0.0 and not last:
		ctrl -= dir * along
	# Read the sweepers' rhythm: go if the next second is safe, else wait,
	# else back off.
	if not _safe(pos, vel, dir):
		if _safe(pos, vel, Vector2.ZERO):
			ctrl = -vel * 3.0
		elif _safe(pos, vel, -dir):
			ctrl = -dir * CRUISE
	var strength := clampf(ctrl.length() / 1.5, 0.0, 1.0)
	var world_in := Vector3(ctrl.x, 0.0, ctrl.y).normalized() * strength

	var basis: Basis = main.camera.global_basis
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var back := Vector3(basis.z.x, 0.0, basis.z.z).normalized()
	var ix := world_in.dot(right)
	var iy := world_in.dot(back)
	_press("right", ix)
	_press("left", -ix)
	_press("down", iy)
	_press("up", -iy)


## Simulates the ball for HORIZON seconds accelerating along `push`
## (or braking when push is zero) and checks it never touches an enemy.
func _safe(pos: Vector2, vel: Vector2, push: Vector2) -> bool:
	const HORIZON := 1.0
	const STEP := 0.05
	const ACCEL := 11.0
	const REACH := 1.15  # ball radius + half enemy hitbox + margin
	var near: Array[Enemy] = []
	for e: Enemy in get_nodes_in_group("enemy"):
		if _flat(e.global_position).distance_to(pos) < 8.0:
			near.append(e)
	if near.is_empty():
		return true
	var p := pos
	var v := vel
	var t := 0.0
	while t < HORIZON:
		t += STEP
		if push == Vector2.ZERO:
			v = v.move_toward(Vector2.ZERO, ACCEL * STEP)
		else:
			v = (v + push * ACCEL * STEP).limit_length(8.0)
		p += v * STEP
		for e in near:
			var ep := _flat(e.position_at(t))
			if absf(ep.x - p.x) < REACH and absf(ep.y - p.y) < REACH:
				return false
	return true


func _press(action: String, value: float) -> void:
	if value > 0.05:
		Input.action_press(action, value)
	else:
		Input.action_release(action)


func _release() -> void:
	for a in ["up", "down", "left", "right"]:
		Input.action_release(a)


func _route() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for t in main.level.route:
		out.append(main.level.tile_center_f(t))
	return out


func _nearest_waypoint(pos: Vector2) -> int:
	var route := _route()
	var best := 0
	for i in route.size():
		if pos.distance_to(route[i]) < pos.distance_to(route[best]):
			best = i
	return best


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _report(ok: bool) -> void:
	var lvl: LevelBase = main.level
	var line := "%s level %d %-16s bot %.1f s (par %.0f), falls %d" % [
		"PASS" if ok else "FAIL", main.level_index + 1, lvl.title, level_t, lvl.time_limit, main.falls]
	if ok and level_t > lvl.time_limit:
		line += "  WARN: bot slower than par"
	results.append(line)
	print(line)
	if not ok:
		failed = true
	_release()
	li += 1
	if li >= levels.size():
		print("LEVELS ", "FAILED" if failed else "PASSED")
		quit(1 if failed else 0)
		return
	main.falls = 0
	main.start_level(levels[li])
	wp = 0
	level_t = 0.0
	was_alive = true

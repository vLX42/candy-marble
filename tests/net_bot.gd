extends "res://tests/levels_test.gd"
## An online race bot: joins a server, waits for the lobby to fill, (as host)
## starts a level, plays it with the level bot's steering and checks that the
## other marbles moved and that the results list every racer. It tests the
## networking, not the driving: the level bot is shakier in real time on a
## busy machine, so a racer that doesn't finish (DNF after the server's grace
## time) is fine as long as somebody does.
## Runs in real time (no --fixed-fps): the network is real time, and a client
## fast-forwarding its clock gets dropped by the WebSocket layer.
##   godot --headless -s tests/net_bot.gd -- --url=ws://127.0.0.1:9123 --name=Mint \
##         --players=2 [--host --level=12] [--shot=/path.png]
## Run tests/net_test.sh to start a server and two of these.

const TIMEOUT := 300.0      # real seconds

var url := "ws://127.0.0.1:9123"
var my_name := "Bot"
var host := false
var want := 2
var race_level := 11
var shot := ""
var net: Node
var step := 0
var clock := 0.0
var rows: Array = []
var remote_start := {}
var remote_moved := 0.0
var shot_taken := false
var started := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--url="):
			url = a.get_slice("=", 1)
		elif a.begins_with("--name="):
			my_name = a.get_slice("=", 1)
		elif a == "--host":
			host = true
		elif a.begins_with("--players="):
			want = int(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			race_level = int(a.get_slice("=", 1)) - 1
		elif a.begins_with("--shot="):
			shot = a.get_slice("=", 1)
	net = root.get_node("Net")
	net.results.connect(func(r: Array) -> void: rows = r)


func _process(delta: float) -> bool:
	if not started:
		# Net is only in the tree (and has a multiplayer) from the first frame.
		started = true
		net.connect_to(url, my_name)
		_say("connecting to %s" % url)
	clock += delta
	frame_dt = delta
	if Time.get_ticks_msec() / 1000.0 > TIMEOUT:
		_done(false, "timed out in step %d (status %s, phase %s)" % [step, net.status, net.phase])
		return false
	match step:
		0:  # in the lobby
			if net.status == "failed" or net.status == "closed":
				_done(false, "couldn't connect: %s" % net.status_text)
			elif net.is_online() and net.players.size() >= want:
				_say("lobby full: %s" % ", ".join(net.players.values().map(func(p: Dictionary) -> String: return p.name)))
				if host:
					net.request_start(race_level)
				step = 1
		1:  # the server starts the race: Net switches to the game scene
			# Not `is MainGame`: naming it here would compile main.gd before the
			# autoloads it uses exist.
			var cs := current_scene
			if cs != null and cs.has_method("start_level") and cs.ball and cs.level:
				main = cs
				level_t = 0.0
				wp = 0
				was_alive = true
				_say("racing level %d (%s) with %d others" % [main.level_index + 1, main.level.title, main._remotes.size()])
				step = 2
		2:  # race with the level bot's steering
			level_t += delta
			if not rows.is_empty():
				# The race ended (grace time ran out) before we got home.
				var q: Vector3 = main.ball.global_position / LevelBase.TILE
				_say("didn't finish: at tile (%.1f, %.1f), waypoint %d/%d" % [q.x, q.z, wp, main.level.route.size()])
				_release()
				step = 3
				return false
			for id: int in main._remotes:
				var r: Node3D = main._remotes[id]
				if not is_instance_valid(r):
					continue
				if not remote_start.has(id):
					remote_start[id] = r.global_position
				remote_moved = maxf(remote_moved, r.global_position.distance_to(remote_start[id]))
			if shot != "" and not shot_taken and level_t > 12.0 and not main._remotes.is_empty():
				shot_taken = true
				root.get_viewport().get_texture().get_image().save_png(shot)
				_say("screenshot -> %s" % shot)
			if main.finished:
				_release()
				_say("finished in %.2f s, falls %d" % [main.level_time, main.falls])
				step = 3
				return false
			var ball: Ball = main.ball
			if not ball.alive:
				_release()
				was_alive = false
				return false
			if not was_alive:
				was_alive = true
				wp = _nearest_waypoint(_flat(ball.global_position))
				wait = randf_range(0.0, 1.0)
			if wait > 0.0:
				wait -= delta
				_release()
				return false
			_steer(ball)
		3:  # results
			if not rows.is_empty():
				var line := []
				var finishers := 0
				for r: Dictionary in rows:
					line.append("%s %s" % [r.name, "%.2f s" % r.time if r.time >= 0.0 else "DNF"])
					if r.time >= 0.0:
						finishers += 1
				_say("results: " + ", ".join(line))
				var ok := rows.size() == want and finishers > 0 and (want < 2 or remote_moved > 5.0)
				_done(ok, "%d racers, %d finished, the others' marbles moved %.1f" % [rows.size(), finishers, remote_moved])
	return false


func _say(text: String) -> void:
	print("[%s] %s" % [my_name, text])


func _done(ok: bool, detail: String) -> void:
	_say(("NET BOT PASSED  " if ok else "NET BOT FAILED  ") + detail)
	_release()
	net.leave()
	quit(0 if ok else 1)

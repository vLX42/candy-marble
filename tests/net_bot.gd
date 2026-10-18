extends "res://tests/levels_test.gd"
## An online race bot: joins a server, waits for the lobby to fill, (as host)
## starts a series of races, plays each with the level bot's steering and
## checks that the other marbles moved, that every race's results list every
## racer, and that the last one is the standings by points. It tests the
## networking, not the driving: the level bot is shakier in real time on a
## busy machine, so a racer that doesn't finish (DNF after the server's grace
## time) is fine as long as somebody does.
## Runs in real time (no --fixed-fps): the network is real time, and a client
## fast-forwarding its clock gets dropped by the WebSocket layer.
##   godot --headless -s tests/net_bot.gd -- --url=ws://127.0.0.1:9123 --name=Mint \
##         --players=2 [--host --level=12 --bots=2 --rounds=2] [--shot=/path.png]
## Run tests/net_test.sh to start a server and two of these.

const TIMEOUT := 240.0      # real seconds per race, plus a minute

var url := "ws://127.0.0.1:9123"
var my_name := "Bot"
var host := false
var want := 2
var race_level := 11
var bot_count := 0
var rounds := 1
var races_seen := 0
var last_main: Node = null
var said_ready := false
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
		elif a.begins_with("--rounds="):
			rounds = int(a.get_slice("=", 1))
		elif a.begins_with("--bots="):
			bot_count = int(a.get_slice("=", 1))
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
		net.join(my_name, url)
		_say("connecting to %s" % url)
	clock += delta
	frame_dt = delta
	if Time.get_ticks_msec() / 1000.0 > TIMEOUT * maxi(rounds, int(net.rounds)) + 60.0:
		_done(false, "timed out in step %d (status %s, phase %s)" % [step, net.status, net.phase])
		return false
	match step:
		0:  # in the lobby
			if net.status == "failed" or net.status == "closed":
				_done(false, "couldn't connect: %s" % net.status_text)
			elif net.is_online():
				if not host and not said_ready:
					said_ready = true
					net.set_ready(true)
				if net.humans().size() >= want and (not host or (net.is_host() and net.all_ready())):
					_say("lobby full: %s" % ", ".join(net.humans().map(func(id: int) -> String: return net.name_of(id))))
					if host:
						net.set_settings(race_level, bot_count, rounds)
						net.request_start()
					step = 1
		1:  # the server starts the race: Net switches to the game scene
			# Not `is MainGame`: naming it here would compile main.gd before the
			# autoloads it uses exist.
			var cs := current_scene
			if cs != null and cs != last_main and cs.has_method("start_level") and cs.ball and cs.level:
				main = cs
				level_t = 0.0
				wp = 0
				was_alive = true
				_say("race %d of %d: level %d (%s) with %d others" % [int(net.round_no) + 1, int(net.rounds),
					main.level_index + 1, main.level.title, main._remotes.size()])
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
				races_seen += 1
				var expect: int = want + int(net.bots)
				if rows.size() != expect or finishers == 0:
					_done(false, "race %d: %d racers, %d finished" % [races_seen, rows.size(), finishers])
					return false
				if not net.last_round():
					_say("race %d results: %s" % [races_seen, ", ".join(line)])
					rows = []
					last_main = main
					step = 1
					return false
				var pts := []
				for r: Dictionary in rows:
					pts.append("%s %d" % [r.name, int(r.get("total", 0))])
				_say("standings: " + ", ".join(pts))
				var sorted_ok := true
				for k in rows.size() - 1:
					sorted_ok = sorted_ok and int(rows[k].get("total", 0)) >= int(rows[k + 1].get("total", 0))
				var ok: bool = races_seen == int(net.rounds) and (expect < 2 or remote_moved > 5.0) \
					and (int(net.rounds) == 1 or (sorted_ok and int(rows[0].get("total", 0)) > 0))
				_done(ok, "%d races, %d racers, standings by points %s, the others' marbles moved %.1f" % [
					races_seen, rows.size(), "ok" if sorted_ok else "WRONG", remote_moved])
	return false


func _say(text: String) -> void:
	print("[%s] %s" % [my_name, text])


func _done(ok: bool, detail: String) -> void:
	_say(("NET BOT PASSED  " if ok else "NET BOT FAILED  ") + detail)
	_release()
	net.leave()
	quit(0 if ok else 1)

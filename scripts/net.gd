extends Node
## Online races (autoload "Net"). One script, two jobs:
##
## Server (`-- --server [--port=9080] [--grace=30]`, headless, in Docker on the
## NAS behind wss://candy.vlx.dk): one lobby for up to six racers. It never
## simulates physics. Players join and wait; everyone but the host says Ready;
## the host picks the level and how many bots fill empty seats, then starts.
## The server waits for everyone to load, says GO, passes the marbles'
## positions around, collects finish times, sends the results and takes
## everyone back to the lobby.
##
## Client (the game): always connects to SERVER_URL (override: ?server= on the
## web page, -- --server-url= on the command line, for testing). Every player
## rolls their own marble on their own machine and sends where it is about 20
## times a second; the others show up as solid marbles (RemoteMarble).
## Switches, gates and monsters stay local: every player solves their own
## puzzles. Bots are licorice-style AI marbles that live in the host's game;
## the host sends their positions and finish times too.

signal changed                       # players, host, settings or phase changed
signal status_changed                # offline / connecting / online / failed / closed
signal go                            # everyone has loaded: start the countdown
signal remote_state(id: int, pos: Vector3, vel: Vector3, alive: bool, progress: float)
signal finish_update(id: int, time: float)
signal results(rows: Array)          # [{name, time (-1 = did not finish), slot, id, bot}, ...]

const SERVER_URL := "wss://candy.vlx.dk"
const PROTOCOL := 2
const DEFAULT_PORT := 9080
const MAX_PLAYERS := 6
const LOAD_TIMEOUT := 15.0
const RESULTS_TIME := 10.0
const STATE_RATE := 20.0
## One colour per seat in the lobby (the marble others see you as).
const COLORS := ["#F6845E", "#6FB8F0", "#8FD35A", "#B39BEA", "#F2D35C", "#F58FB8"]
const BOT_NAMES := ["Licorice", "Gumdrop", "Toffee", "Jellybean", "Taffy"]
## Loaded by path, not by class name: main.gd and title.gd use Net, so naming
## them here would be a loop the compiler can't untangle.
const MAIN_SCRIPT := "res://scripts/main.gd"
const TITLE_SCRIPT := "res://scripts/title.gd"

var server_mode := false
var port := DEFAULT_PORT
var finish_grace := 30.0             # server: seconds the others get after the first finish
## id -> {name, slot, ready, in_race, loaded, finished, time, falls, left, bot, owner}
## Bots have negative ids and an owner (the host whose game runs them).
var players := {}
var host_id := 0
var phase := "lobby"                 # lobby, loading, racing, results
var level := 0
var bots := 0                        # bots the host wants in the next race
var status := "offline"
var status_text := ""
var finish_order: Array[int] = []
var _peer: WebSocketMultiplayerPeer
var _timer := 0.0
var _first_finish := -1.0
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	var args := OS.get_cmdline_user_args()
	if "--server" in args or OS.has_feature("dedicated_server"):
		for a in args:
			if a.begins_with("--port="):
				port = int(a.get_slice("=", 1))
			if a.begins_with("--grace="):
				finish_grace = float(a.get_slice("=", 1))
		if OS.get_environment("PORT").is_valid_int():
			port = int(OS.get_environment("PORT"))
		start_server(port)


# --- both sides ------------------------------------------------------------------

func is_online() -> bool:
	return status == "online"


func my_id() -> int:
	return multiplayer.get_unique_id() if _peer else 0


func is_host() -> bool:
	return is_online() and host_id == my_id()


func color_of(id: int) -> Color:
	var p: Dictionary = players.get(id, {})
	return Color(COLORS[int(p.get("slot", 0)) % COLORS.size()])


func name_of(id: int) -> String:
	return str(players.get(id, {}).get("name", "?"))


func is_bot(id: int) -> bool:
	return bool(players.get(id, {}).get("bot", false))


## Humans in the lobby (bots only exist during a race).
func humans() -> Array[int]:
	var out: Array[int] = []
	for id: int in players:
		if not players[id].get("bot", false):
			out.append(id)
	out.sort_custom(func(a: int, b: int) -> bool: return players[a].slot < players[b].slot)
	return out


## Racers in the current race (ids, in seat order, bots included).
func race_ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in players:
		if players[id].get("in_race", false):
			out.append(id)
	out.sort_custom(func(a: int, b: int) -> bool: return players[a].slot < players[b].slot)
	return out


## Everyone but the host has said Ready (the host starts when they like).
func all_ready() -> bool:
	for id in humans():
		if id != host_id and not players[id].get("ready", false):
			return false
	return true


## How many bots fit next to the people in the lobby.
func max_bots() -> int:
	return maxi(0, MAX_PLAYERS - humans().size())


## Where to connect: the NAS, unless a test points somewhere else.
func server_url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server-url="):
			return a.get_slice("=", 1)
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('server') || ''")
		if q is String and q != "":
			return q
	return SERVER_URL


func _process(delta: float) -> void:
	_clock += delta
	if server_mode:
		_server_tick(delta)


# --- client ------------------------------------------------------------------------

## Joins the online lobby (SERVER_URL unless `url` is given).
func join(player_name: String, url: String = "") -> Error:
	leave()
	url = (url if url != "" else server_url()).strip_edges()
	if not url.begins_with("ws://") and not url.begins_with("wss://"):
		url = ("ws://" if ":" in url else "wss://") + url
	_peer = WebSocketMultiplayerPeer.new()
	var err := _peer.create_client(url)
	if err != OK:
		_set_status("failed", "Can't reach the race server.")
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	set_meta("name", player_name.strip_edges().substr(0, 16) if player_name.strip_edges() != "" else "Player")
	_set_status("connecting", "Joining the race server...")
	return OK


## Drops the connection (back to single player).
func leave() -> void:
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	host_id = 0
	phase = "lobby"
	if status != "offline":
		_set_status("offline", "")
	changed.emit()


func set_ready(on: bool) -> void:
	if is_online():
		_set_ready.rpc_id(1, on)


func set_settings(level_index: int, bot_count: int) -> void:
	if is_host():
		_set_settings.rpc_id(1, level_index, bot_count)


func request_start() -> void:
	if is_online():
		_request_start.rpc_id(1)


func report_loaded() -> void:
	if is_online():
		_loaded.rpc_id(1)


func report_finish(time: float, falls: int) -> void:
	if is_online():
		_finished.rpc_id(1, time, falls)


## The host's game reports one of its bots home.
func report_bot_finish(bot_id: int, time: float) -> void:
	if is_online():
		_bot_finished.rpc_id(1, bot_id, time)


func leave_race() -> void:
	if is_online():
		_left_race.rpc_id(1)


func send_state(pos: Vector3, vel: Vector3, alive: bool, progress: float) -> void:
	if is_online():
		_state.rpc(pos, vel, alive, progress)


func send_bot_state(bot_id: int, pos: Vector3, vel: Vector3, alive: bool, progress: float) -> void:
	if is_online():
		_bot_state.rpc(bot_id, pos, vel, alive, progress)


func _on_connected() -> void:
	_set_status("online", "In the lobby")
	_hello.rpc_id(1, get_meta("name", "Player"), PROTOCOL)


func _on_failed() -> void:
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_status("failed", "Couldn't reach the race server. Try again in a moment.")


func _on_server_gone() -> void:
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	_set_status("closed", "Lost the connection to the race server.")
	changed.emit()


func _set_status(s: String, text: String) -> void:
	status = s
	status_text = text
	status_changed.emit()


# --- messages: server to clients ----------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _lobby(list: Dictionary, host: int, current_phase: String, current_level: int, bot_count: int) -> void:
	players = list
	host_id = host
	phase = current_phase
	level = current_level
	bots = bot_count
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	_set_status("failed", reason)


@rpc("authority", "call_remote", "reliable")
func _start(level_index: int, ids: Array) -> void:
	level = level_index
	finish_order.clear()
	if not ids.has(my_id()):
		return
	var mg: GDScript = load(MAIN_SCRIPT)
	mg.set("quest", null)
	mg.set("test_mode", false)
	mg.set("net_race", true)
	mg.set("requested_level", level_index)
	Transition.go("res://scenes/main.tscn")


@rpc("authority", "call_remote", "reliable")
func _go() -> void:
	go.emit()


@rpc("authority", "call_remote", "reliable")
func _finish_update(id: int, time: float) -> void:
	if not finish_order.has(id):
		finish_order.append(id)
	finish_update.emit(id, time)


@rpc("authority", "call_remote", "reliable")
func _results(rows: Array) -> void:
	results.emit(rows)


@rpc("authority", "call_remote", "reliable")
func _to_lobby() -> void:
	var mg: GDScript = load(MAIN_SCRIPT)
	if mg.get("net_race"):
		mg.set("net_race", false)
		(load(TITLE_SCRIPT) as GDScript).set("open_page", "online")
		Transition.go("res://scenes/title.tscn")


# --- messages: clients to server (and the marble states to everyone) ---------------

@rpc("any_peer", "call_remote", "reliable")
func _hello(player_name: String, protocol: int) -> void:
	if not server_mode:
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_rejected.rpc_id(id, "The race server runs a different version of the game. Update and try again.")
		_kick_later(id)
		return
	if humans().size() >= MAX_PLAYERS:
		_rejected.rpc_id(id, "The lobby is full (%d players)." % MAX_PLAYERS)
		_kick_later(id)
		return
	var slot := _free_slot()
	var clean := player_name.strip_edges().substr(0, 16)
	players[id] = {name = clean if clean != "" else "Player %d" % (slot + 1), slot = slot, ready = false,
		in_race = false, loaded = false, finished = false, time = -1.0, falls = 0, left = false,
		bot = false, owner = 0}
	if host_id == 0 or not players.has(host_id):
		host_id = id
	bots = mini(bots, max_bots())
	_log("%s joined (seat %d, %d in the lobby)" % [players[id].name, slot + 1, humans().size()])
	_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func _set_ready(on: bool) -> void:
	if not server_mode:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id].ready = on
		_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func _set_settings(level_index: int, bot_count: int) -> void:
	if not server_mode or multiplayer.get_remote_sender_id() != host_id or phase != "lobby":
		return
	level = clampi(level_index, 0, _level_count() - 1)
	bots = clampi(bot_count, 0, max_bots())
	_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func _request_start() -> void:
	if not server_mode:
		return
	var id := multiplayer.get_remote_sender_id()
	if id != host_id or phase != "lobby" or not all_ready():
		return
	phase = "loading"
	_timer = 0.0
	_first_finish = -1.0
	finish_order.clear()
	for pid in humans():
		_reset_racer(players[pid])
	# Bots take the free seats; the host's game runs them.
	for k in mini(bots, max_bots()):
		var bid := -(k + 1)
		players[bid] = {name = BOT_NAMES[k % BOT_NAMES.size()], slot = _free_slot(), ready = true,
			in_race = true, loaded = true, finished = false, time = -1.0, falls = 0, left = false,
			bot = true, owner = host_id}
	_log("%s started level %d: %d players, %d bots" % [name_of(id), level + 1, humans().size(), bots])
	_broadcast_lobby()
	_start.rpc(level, race_ids())


@rpc("any_peer", "call_remote", "reliable")
func _loaded() -> void:
	if not server_mode:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id].loaded = true


@rpc("any_peer", "call_remote", "reliable")
func _finished(time: float, falls: int) -> void:
	if server_mode:
		_record_finish(multiplayer.get_remote_sender_id(), time, falls)


@rpc("any_peer", "call_remote", "reliable")
func _bot_finished(bot_id: int, time: float) -> void:
	if not server_mode or not players.has(bot_id):
		return
	if players[bot_id].get("owner", 0) == multiplayer.get_remote_sender_id():
		_record_finish(bot_id, time, 0)


@rpc("any_peer", "call_remote", "reliable")
func _left_race() -> void:
	if not server_mode:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id) and players[id].in_race:
		players[id].left = true
		_drop_bots_of(id)
		_log("%s left the race" % name_of(id))
		_check_race_over()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(pos: Vector3, vel: Vector3, alive: bool, progress: float) -> void:
	if server_mode:
		return
	remote_state.emit(multiplayer.get_remote_sender_id(), pos, vel, alive, progress)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _bot_state(bot_id: int, pos: Vector3, vel: Vector3, alive: bool, progress: float) -> void:
	if server_mode:
		return
	remote_state.emit(bot_id, pos, vel, alive, progress)


# --- server ------------------------------------------------------------------------

func start_server(at_port: int) -> Error:
	server_mode = true
	port = at_port
	Engine.max_fps = 30
	_peer = WebSocketMultiplayerPeer.new()
	var err := _peer.create_server(at_port)
	if err != OK:
		_log("can't listen on port %d (error %d)" % [at_port, err])
		get_tree().quit(1)
		return err
	multiplayer.multiplayer_peer = _peer
	_set_status("online", "Serving on port %d" % at_port)
	_log("Candy Marble server %s listening on port %d" % [ProjectSettings.get_setting("application/config/version", "dev"), at_port])
	return OK


func _server_tick(delta: float) -> void:
	match phase:
		"loading":
			_timer += delta
			var all_in := true
			for id in race_ids():
				if not players[id].loaded and not players[id].left:
					all_in = false
			if all_in or _timer > LOAD_TIMEOUT:
				phase = "racing"
				_log("GO")
				_broadcast_lobby()
				_go.rpc()
		"racing":
			if _first_finish >= 0.0 and _clock - _first_finish > finish_grace:
				_end_race()
		"results":
			_timer += delta
			if _timer > RESULTS_TIME:
				phase = "lobby"
				for id: int in players.keys():
					if players[id].get("bot", false):
						players.erase(id)
					else:
						players[id].in_race = false
						players[id].ready = false
				_broadcast_lobby()
				_to_lobby.rpc()


func _record_finish(id: int, time: float, falls: int) -> void:
	if phase != "racing" or not players.has(id) or players[id].finished:
		return
	players[id].finished = true
	players[id].time = time
	players[id].falls = falls
	finish_order.append(id)
	if _first_finish < 0.0:
		_first_finish = _clock
	_log("%s finished in %.2f s (%d)" % [name_of(id), time, finish_order.size()])
	_finish_update.rpc(id, time)
	_check_race_over()


## Over when every racer is home or gone. Once all the people are done, the
## bots get the grace time to finish (the clock starts at the first finish).
func _check_race_over() -> void:
	if phase != "racing" and phase != "loading":
		return
	var people_done := true
	var bots_done := true
	for id in race_ids():
		var p: Dictionary = players[id]
		var done: bool = p.finished or p.left
		if p.get("bot", false):
			bots_done = bots_done and done
		else:
			people_done = people_done and done
	if people_done and bots_done:
		_end_race()
	elif people_done and _first_finish < 0.0:
		_first_finish = _clock


func _end_race() -> void:
	var rows := []
	for id in race_ids():
		var p: Dictionary = players[id]
		rows.append({name = p.name, time = p.time if p.finished else -1.0, slot = p.slot, id = id,
			bot = p.get("bot", false)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a.time < 0.0) != (b.time < 0.0):
			return a.time >= 0.0
		return a.time < b.time if a.time >= 0.0 else a.slot < b.slot)
	phase = "results"
	_timer = 0.0
	var line := []
	for r: Dictionary in rows:
		line.append("%s %s" % [r.name, "%.2f s" % r.time if r.time >= 0.0 else "DNF"])
	_log("results: " + ", ".join(line))
	_broadcast_lobby()
	_results.rpc(rows)


func _reset_racer(p: Dictionary) -> void:
	p.in_race = true
	p.loaded = false
	p.finished = false
	p.left = false
	p.time = -1.0


func _free_slot() -> int:
	var taken := {}
	for p: Dictionary in players.values():
		taken[p.slot] = true
	var slot := 0
	while taken.has(slot):
		slot += 1
	return slot


## A host who leaves takes their bots with them (their game was running them).
func _drop_bots_of(owner_id: int) -> void:
	for id: int in players:
		if players[id].get("bot", false) and players[id].get("owner", 0) == owner_id:
			players[id].left = true


func _level_count() -> int:
	return (load(MAIN_SCRIPT) as GDScript).get_script_constant_map()["LEVELS"].size()


func _broadcast_lobby() -> void:
	_lobby.rpc(players, host_id, phase, level, bots)


func _on_peer_connected(id: int) -> void:
	if server_mode:
		_log("peer %d connected" % id)


func _on_peer_disconnected(id: int) -> void:
	if not server_mode or not players.has(id):
		return
	_log("%s left" % name_of(id))
	_drop_bots_of(id)
	players.erase(id)
	if host_id == id:
		host_id = 0
		var best := 99
		for pid in humans():
			if players[pid].slot < best:
				best = players[pid].slot
				host_id = pid
	if humans().is_empty():
		phase = "lobby"
		players.clear()
	bots = mini(bots, max_bots())
	_broadcast_lobby()
	_check_race_over()


func _kick_later(id: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if _peer and _peer.get_peer(id):
		_peer.disconnect_peer(id)


func _log(text: String) -> void:
	print("[%s] %s" % [Time.get_datetime_string_from_system(), text])

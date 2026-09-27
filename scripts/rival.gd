class_name Rival
extends Ball
## The evil licorice ball in race levels. Same physics as the player, so the two
## collide and bounce, and it uses boosters, loops and cannons too. It steers
## along the level route like a decent player: reads the sweepers' timing,
## lets go in loops and jumps, and putts gently into the hole. It cruises a bit
## slower than a perfect line so a good run beats it.

const BONK := 3.5
const BONK_COOLDOWN := 0.3

@export var cruise := 4.9
## Model to wear (the title screen demo also uses a peppermint one).
@export var skin := "rival"
## Keep lapping the route instead of stopping at the end (title screen).
@export var loop_route := false

var level: LevelBase
var finished := false
var _route: Array[Vector2] = []
var _wp := 0
var _wait := 0.0
var _was_alive := true
var _bonk_timer := 0.0
var _stuck_check := 0.0
var _stuck_wp := -1


func _ready() -> void:
	model_name = skin
	super._ready()
	add_to_group("rival")
	max_speed = 6.9
	push_force = 15.0
	for t in level.route:
		_route.append(level.tile_center_f(t))
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_bonk_timer -= delta
	if alive and not _was_alive:
		# Respawned: carry on from the nearest waypoint after a short pause.
		_wp = _nearest_waypoint()
		_wait = randf_range(0.3, 1.2)
	_was_alive = alive
	if _wait > 0.0:
		_wait -= delta
	# No new waypoint for 8 s (wedged on a prop, bouncing in a corner)? Pop and
	# respawn at the last checkpoint.
	if _wp != _stuck_wp or not alive or finished or freeze:
		_stuck_wp = _wp
		_stuck_check = 0.0
	else:
		_stuck_check += delta
		if _stuck_check > 8.0:
			_stuck_check = 0.0
			die()
	super._physics_process(delta)


## Route progress as a float (waypoint index + fraction), for race positions.
func progress_of(p: Vector3) -> float:
	return LevelBase.route_progress(_route, Vector2(p.x, p.z), _wp)


func _steer_dir() -> Vector3:
	if _wait > 0.0 or finished or _route.is_empty():
		return Vector3.ZERO
	var pos := Vector2(global_position.x, global_position.z)
	# Hands off only while really airborne (loops, jumps, cannon shots).
	if not is_grounded() and global_position.y > level.height(pos.x, pos.y) + 1.1:
		return Vector3.ZERO
	if loop_route and _wp == _route.size() - 1 and pos.distance_to(_route[_wp]) < 1.5:
		_wp = 0
	while _wp < _route.size() - 1:
		var here := _route[_wp]
		var next := _route[_wp + 1]
		if pos.distance_to(here) < 1.0 or (pos - here).dot(next - here) > 0.0:
			_wp += 1
		else:
			break
	var to := _route[_wp] - pos
	var dir := to.normalized()
	var vel := Vector2(linear_velocity.x, linear_velocity.z)
	var last := _wp == _route.size() - 1 and not loop_route
	var target_speed := clampf(to.length() * 1.2, 1.2, 4.0) if last else cruise
	var ctrl := dir * target_speed - vel
	var along := ctrl.dot(dir)
	if along < 0.0 and not last:
		ctrl -= dir * along
	if not _safe(pos, vel, dir):
		if _safe(pos, vel, Vector2.ZERO):
			ctrl = -vel * 3.0
		elif _safe(pos, vel, -dir):
			ctrl = -dir * cruise
	var strength := clampf(ctrl.length() / 1.5, 0.0, 1.0)
	return Vector3(ctrl.x, 0.0, ctrl.y).normalized() * strength


## Simulates one second ahead (pushing along `push`, or braking) and checks
## it never touches a sweeper.
func _safe(pos: Vector2, vel: Vector2, push: Vector2) -> bool:
	const HORIZON := 1.0
	const STEP := 0.05
	const ACCEL := 10.0
	const REACH := 1.15
	var near: Array[Node3D] = []
	for e: Node3D in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("threat_at") and Vector2(e.global_position.x, e.global_position.z).distance_to(pos) < 9.0:
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
			v = (v + push * ACCEL * STEP).limit_length(max_speed)
		p += v * STEP
		for e in near:
			var threat: Variant = e.threat_at(t)
			if threat == null:
				continue
			var ep: Vector3 = threat
			var reach: float = e.get("reach") if e.get("reach") != null else REACH
			if absf(ep.x - p.x) < reach and absf(ep.z - p.y) < reach:
				return false
	return true


func _nearest_waypoint() -> int:
	var pos := Vector2(global_position.x, global_position.z)
	var best := 0
	for i in _route.size():
		if pos.distance_to(_route[i]) < pos.distance_to(_route[best]):
			best = i
	return best


func _on_body_entered(body: Node) -> void:
	if not body is Ball or body == self or _bonk_timer > 0.0:
		return
	_bonk_timer = BONK_COOLDOWN
	var other := body as Node3D
	var away: Vector3 = other.global_position - global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.RIGHT
	away = away.normalized()
	body.apply_central_impulse(away * BONK + Vector3.UP * 1.0)
	apply_central_impulse(-away * BONK + Vector3.UP * 1.0)
	get_tree().call_group("game", "on_bump", (global_position + other.global_position) * 0.5)

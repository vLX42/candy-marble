class_name Steelie
extends Ball
## Marble Madness's Black Steelie: a heavy dark-metal marble that hunts you.
## It doesn't pop you; the fall does, so it plays for the fall:
##  - it finds its way over the tiles (round corners, down ramps, never off an
##    edge or into goo) instead of rolling straight at you,
##  - it aims where you're going, not where you are,
##  - near a drop it circles round to the inside and rams you towards the edge.
## It only hunts inside its territory: tiles within `leash` of home (by the
## path, not as the crow flies). Leave that and it rolls home.

@export var sense := 9.0
@export var leash := 10.0
@export var speed := 4.2
## Colour of the metal (dark steel by default).
@export var shade := Color("#3A3F4B")

const SHOVE := 5.5
const REPLAN := 0.2
## Drops bigger than this count as an edge worth pushing you off.
const DROP := 1.0
var _home := Vector3.ZERO
var _home_tile := Vector2i.ZERO
var _shove_cool := 0.0
var _plan_left := 0.0
var _territory := {}   # Vector2i -> path steps from home
var _chase := {}       # Vector2i -> path steps to the prey (empty = not hunting)
var _prey: Ball
var _lvl: LevelBase
var _last_ground := Vector2i.ZERO


func _ready() -> void:
	# Placed at floor height like other monsters: sit on the floor, not in it.
	position.y += radius + 0.1
	model_name = "rival"
	super._ready()
	remove_from_group("ball")
	add_to_group("steelie")
	add_to_group("enemy")
	mass = 1.6
	max_speed = speed
	push_force = 14.0
	_home = global_position
	body_entered.connect(_on_body_entered)
	# Shiny dark metal instead of licorice.
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m == null:
				continue
			var d := m.duplicate() as BaseMaterial3D
			d.albedo_color = shade if m.albedo_color.v < 0.5 else shade.lightened(0.55)
			d.metallic = 0.85
			d.roughness = 0.18
			mi.set_surface_override_material(s, d)


func _physics_process(delta: float) -> void:
	_shove_cool -= delta
	_plan_left -= delta
	if _plan_left <= 0.0:
		_plan_left = REPLAN
		_plan()
	super._physics_process(delta)


func _level_data() -> LevelBase:
	if _lvl == null:
		var game := get_tree().get_first_node_in_group("game")
		_lvl = game.get("level") if game else null
		if _lvl:
			_home_tile = _lvl.tile_at(_home.x, _home.z)
			_last_ground = _home_tile
			_territory = _bfs(_home_tile, {}, ceili(leash / LevelBase.TILE) + 1)
	return _lvl


## Picks the prey and works out the way to it.
func _plan() -> void:
	var l := _level_data()
	_prey = null
	_chase = {}
	if l == null or not alive:
		return
	var best := sense
	for b in get_tree().get_nodes_in_group("ball"):
		if b is Ball and b.alive and b.visible and not (b is Rival) and not (b is Steelie):
			var d := _flat(b.global_position).distance_to(_flat(global_position))
			var t := l.tile_at(b.global_position.x, b.global_position.z)
			if d < best and _territory.has(t):
				best = d
				_prey = b
	if _prey:
		var t := l.tile_at(_prey.global_position.x, _prey.global_position.z)
		_chase = _bfs(t, _territory, 999)


func _steer_dir() -> Vector3:
	if not alive:
		return Vector3.ZERO
	var l := _level_data()
	if l == null:
		return _drive_to(_home, false)
	var here := l.tile_at(global_position.x, global_position.z)
	# Hanging over an edge: plan from the last solid tile it stood on.
	if l.is_tile_ground(here.x, here.y):
		_last_ground = here
	else:
		here = _last_ground
	var target := _home
	var ram := false
	if _prey and is_instance_valid(_prey) and _prey.alive:
		var gap := _flat(_prey.global_position).distance_to(_flat(global_position))
		if gap < 4.5 or not _chase.has(here):
			var h := _herd_point(l)
			target = h[0]
			ram = h[1]
		else:
			target = _path_point(l, here, _chase)
	elif _territory.has(here) and here != _home_tile:
		target = _path_point(l, here, _territory)
	return _keep_safe(l, here, _drive_to(target, ram), ram)


## Where to go when close: aim where the prey is heading, and if there's a
## drop near it, get round to the inside first so the ram pushes it over.
## Returns [point, ramming].
func _herd_point(l: LevelBase) -> Array:
	var p := _prey.global_position
	var v := Vector3(_prey.linear_velocity.x, 0.0, _prey.linear_velocity.z)
	var gap := _flat(p).distance_to(_flat(global_position))
	var lead := p + v * clampf(gap / maxf(speed, 1.0), 0.0, 0.6)
	var edge := _edge_dir(l, p)
	if edge == Vector3.ZERO:
		return [lead, true]
	var inside := global_position - p
	inside.y = 0.0
	if inside.dot(-edge) > 0.8:
		return [lead, true]           # on the inside already: ram it towards the edge
	return [p - edge * 1.8, false]    # swing round to the inside first


## Unit vector from p towards the nearest drop or void within a few units
## (zero if the ground around p is safe).
func _edge_dir(l: LevelBase, p: Vector3) -> Vector3:
	var floor_y := l.height(p.x, p.z)
	for r: float in [1.5, 2.5, 3.5]:
		var sum := Vector3.ZERO
		for k in 12:
			var a := TAU * k / 12.0
			var d := Vector3(cos(a), 0.0, sin(a))
			var q := p + d * r
			var t := l.tile_at(q.x, q.z)
			if not l.is_tile_ground(t.x, t.y) or l.obj_char(t.x, t.y) == "A" or l.height(q.x, q.z) < floor_y - DROP:
				sum += d
		if sum.length() > 0.01:
			return sum.normalized()
	return Vector3.ZERO


## The neighbouring tile one step closer along `field`.
func _step(l: LevelBase, from: Vector2i, field: Dictionary) -> Vector2i:
	var best := from
	var best_d: int = field.get(from, 1 << 30)
	for n in _neighbours(from):
		if field.has(n) and field[n] < best_d and _can_go(l, from, n):
			best_d = field[n]
			best = n
	return best


## Where to head along `field`: two steps ahead on a straight run, one step
## round a corner.
func _path_point(l: LevelBase, here: Vector2i, field: Dictionary) -> Vector3:
	if not field.has(here):
		return _home
	var n1 := _step(l, here, field)
	var n2 := _step(l, n1, field)
	var aim := n2 if n2 != n1 and (n2.x == here.x or n2.y == here.y) else n1
	var c := l.tile_center(aim.x, aim.y)
	return Vector3(c.x, global_position.y, c.y)


## Steering as a speed controller: head for p, easing in near it (not when
## ramming), and cancel any sideways drift.
func _drive_to(p: Vector3, ram: bool) -> Vector3:
	var to := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
	var vel := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var want := Vector3.ZERO
	if to.length() > 0.2:
		want = to.normalized() * (speed if ram else minf(speed, to.length() * 2.5))
	return ((want - vel) / 2.0).limit_length(1.0)


## Never roll off an edge or into goo: if the ground ahead (where it's steering
## or where it's rolling) can't be walked to, pull back to the middle of its
## tile. A ram may carry on into the prey, whose body stops it.
func _keep_safe(l: LevelBase, here: Vector2i, dir: Vector3, ram: bool) -> Vector3:
	var vel := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var look := 0.8 + vel.length() * 0.3
	for probe: Vector3 in [dir.normalized(), vel.normalized()]:
		if probe == Vector3.ZERO:
			continue
		var q := global_position + probe * look
		var t := l.tile_at(q.x, q.z)
		if t == here or _can_go(l, here, t):
			continue
		if ram and _prey and (_prey.global_position - global_position).dot(probe) > 0.0 \
				and _flat(_prey.global_position).distance_to(_flat(global_position)) < 1.8:
			continue
		var c := l.tile_center(here.x, here.y)
		var back := Vector3(c.x - global_position.x, 0.0, c.y - global_position.z)
		return ((back * 3.0 - vel) / 2.0).limit_length(1.0)
	return dir


## Path steps from `start` over walkable tiles (only inside `within` if given).
func _bfs(start: Vector2i, within: Dictionary, max_steps: int) -> Dictionary:
	var l := _lvl
	var out := {start: 0}
	var queue: Array[Vector2i] = [start]
	var k := 0
	while k < queue.size():
		var t := queue[k]
		k += 1
		var d: int = out[t]
		if d >= max_steps:
			continue
		for n in _neighbours(t):
			if out.has(n) or (not within.is_empty() and not within.has(n)):
				continue
			# Walk the steps backwards: can the steelie get from n to t?
			if _can_go(l, n, t):
				out[n] = d + 1
				queue.append(n)
	return out


static func _neighbours(t: Vector2i) -> Array[Vector2i]:
	return [t + Vector2i(1, 0), t + Vector2i(-1, 0), t + Vector2i(0, 1), t + Vector2i(0, -1)]


## One tile to the next without a wall to climb or a drop to fall down.
static func _can_go(l: LevelBase, a: Vector2i, b: Vector2i) -> bool:
	if not l.is_tile_ground(b.x, b.y) or l.obj_char(b.x, b.y) == "A":
		return false
	var ca := l.tile_center(a.x, a.y)
	var cb := l.tile_center(b.x, b.y)
	var dh := absf(l.surface(b.x, b.y, cb.x, cb.y) - l.surface(a.x, a.y, ca.x, ca.y))
	return dh < (1.2 if l.is_ramp(a.x, a.y) or l.is_ramp(b.x, b.y) else 0.3)


## Look-ahead for the level bot, like the other monsters.
func threat_at(ahead: float) -> Variant:
	return global_position + linear_velocity * ahead


var reach := 1.1


func _on_body_entered(body: Node) -> void:
	if not (body is Ball) or body is Steelie or _shove_cool > 0.0:
		return
	_shove_cool = 0.4
	var away: Vector3 = body.global_position - global_position
	away.y = 0.0
	away = away.normalized()
	body.apply_central_impulse(away * SHOVE + Vector3.UP * 0.8)
	get_tree().call_group("game", "on_bump", global_position)


func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

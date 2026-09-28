class_name Ghost
extends Area3D
## Sour Ghost: floats near home and drifts after any ball that comes close,
## but never strays further than `leash` from home. It tires after chasing for
## `chase_time` and drifts home for `rest_time`: that's your window to slip
## past. Touching it pops the ball.
## It aims where you're going, and ghosts hunt as a pack: when another ghost
## is already closer behind you, this one swings ahead to cut you off.

@export var leash := 6.0
@export var speed := 2.6
@export var sense := 7.5
@export var chase_time := 3.0
@export var rest_time := 2.5
var reach := 1.1

var _home := Vector3.ZERO
var _vel := Vector3.ZERO
var _t := 0.0
var _chasing := 0.0
var _resting := 0.0
var _visual: Node3D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("ghost")
	_home = global_position + Vector3.UP * 0.9
	global_position = _home
	_t = randf() * TAU
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_hit)
	_visual = Palette.load_model(self, "enemy_ghost")
	if _visual == null:
		_visual = Node3D.new()
		add_child(_visual)
		Palette.add_mesh(_visual, Palette.sphere(0.5, 1.1), Palette.RASPBERRY.lightened(0.3))
		for ex in [-0.18, 0.18]:
			Palette.add_mesh(_visual, Palette.sphere(0.09), Palette.INK, Vector3(ex, 0.15, 0.45))


func _physics_process(delta: float) -> void:
	_t += delta
	var target := _home
	if _resting > 0.0:
		_resting -= delta
	else:
		var best := sense
		var prey: Ball
		for b in get_tree().get_nodes_in_group("ball"):
			if b is Ball and b.alive and not b.rush:
				var d: float = Vector2(b.global_position.x - _home.x, b.global_position.z - _home.z).length()
				if d < best:
					best = d
					prey = b
		if prey:
			target = _hunt_point(prey)
		if target != _home:
			_chasing += delta
			if _chasing > chase_time:
				_chasing = 0.0
				_resting = rest_time
				target = _home
		else:
			_chasing = maxf(0.0, _chasing - delta)
	var to := target - global_position
	to.y = 0.0
	var pace := speed if _resting <= 0.0 else speed * 0.8
	var desired := to.normalized() * pace if to.length() > 0.15 else Vector3.ZERO
	var next := global_position + desired * delta
	if Vector2(next.x - _home.x, next.z - _home.z).length() > leash:
		desired = Vector3.ZERO
	_vel = _vel.lerp(desired, 1.0 - exp(-3.0 * delta))
	global_position += _vel * delta
	global_position.y = _home.y + sin(_t * 2.2) * 0.15
	if _vel.length() > 0.2:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(_vel.x, _vel.z), 1.0 - exp(-6.0 * delta))


## Where to fly: ahead of the prey, and further ahead if a pack mate is
## already closer (so the two close in from both sides).
func _hunt_point(prey: Ball) -> Vector3:
	var p := Vector3(prey.global_position.x, _home.y, prey.global_position.z)
	var v := Vector3(prey.linear_velocity.x, 0.0, prey.linear_velocity.z)
	var gap := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	var lead := p + v * clampf(gap / maxf(speed, 0.5), 0.0, 0.8)
	for g in get_tree().get_nodes_in_group("ghost"):
		if g == self or not (g is Ghost) or g._resting > 0.0 or g._chasing <= 0.0:
			continue
		var theirs := Vector2(p.x - g.global_position.x, p.z - g.global_position.z).length()
		if theirs < gap and v.length() > 0.5:
			return lead + v.normalized() * 3.0
	return lead


func position_at(ahead: float) -> Vector3:
	return global_position + _vel * ahead


func threat_at(ahead: float) -> Variant:
	return global_position + _vel * ahead


func _on_hit(body: Node3D) -> void:
	if body is Ball:
		if body is Steelie:
			return
		if body.silly:
			# Silly Race: the marble squishes the monster.
			Palette.squish(self)
			return
		if body.rush:
			get_tree().call_group("game", "cheer", "WHOOSH!", global_position + Vector3.UP * 1.5)
			return
		body.die()

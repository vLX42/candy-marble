class_name Ball
extends RigidBody3D
## Player marble. Input pushes it with a force, but only while it is slower
## than max_speed in that direction, so bumpers and boosters can still launch
## it past the cap.

signal died
signal respawned
## Hit the ground after a fall (impact = downward speed).
signal landed(impact: float)
## Knocked into a wall or block (impact = speed lost).
signal bonked(impact: float)

@export var push_force := 16.0
@export var max_speed := 8.0
@export_range(0.0, 1.0) var air_control := 0.3
@export var fall_limit := -10.0
## Marble Madness rule: landing after a fall taller than this breaks the
## marble (world units, 0 = never). Set per level by main.
@export var break_drop := 0.0
@export var radius := 0.5
## Model in models/ to show (the rival uses "rival").
@export var model_name := "ball"

var spawn_point := Vector3.ZERO
var alive := true
## Seconds left where input is ignored (while being shot through a loop).
var input_lock := 0.0
## Sugar Rush: faster, grippier, and sweepers can't pop you. Set by main.
var rush := false:
	set(v):
		rush = v
		_apply_rush()
var _base := {}
var _trail: CPUParticles3D
var _glow: OmniLight3D
## True while flying from a cannon: no air damping so the arc lands on target.
var _flying := false
## Highest point since the marble last touched something (for break_drop).
var _air_top := -INF
var _prev_vel := Vector3.ZERO
var _knock_cool := 0.0


func _ready() -> void:
	add_to_group("ball")
	mass = 1.0
	continuous_cd = true
	linear_damp = 0.05
	angular_damp = 0.3
	contact_monitor = true
	max_contacts_reported = 4
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.15
	physics_material_override = pm

	var shape := SphereShape3D.new()
	shape.radius = radius
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

	if not has_node("Model") and Palette.load_model(self, model_name) == null:
		_build_placeholder()
	spawn_point = global_position


func _build_placeholder() -> void:
	# White peppermint with two raspberry swirls so rolling is readable.
	var v := Node3D.new()
	v.name = "Model"
	add_child(v)
	Palette.add_mesh(v, Palette.sphere(radius), Palette.WHITE)
	var ring := Palette.torus(radius * 0.93, radius * 1.03)
	Palette.add_mesh(v, ring, Palette.RASPBERRY, Vector3.ZERO, Vector3(90, 0, 0))
	Palette.add_mesh(v, ring, Palette.RASPBERRY, Vector3.ZERO, Vector3(0, 0, 90))


func _physics_process(_delta: float) -> void:
	if not alive:
		return
	if global_position.y < fall_limit:
		die()
		return

	_check_landing()
	_check_impacts(_delta)
	if _flying and input_lock <= 0.0 and get_contact_count() > 0:
		_flying = false
		linear_damp_mode = RigidBody3D.DAMP_MODE_COMBINE
		linear_damp = 0.05
	if input_lock > 0.0:
		input_lock -= _delta
		return
	var dir := _steer_dir()
	if dir == Vector3.ZERO:
		return
	var flat_vel := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if flat_vel.dot(dir) < max_speed:
		var control := 1.0 if is_grounded() else air_control
		apply_central_force(dir * push_force * control)


func _apply_rush() -> void:
	if _base.is_empty():
		_base = {max_speed = max_speed, push_force = push_force, air_control = air_control}
	max_speed = _base.max_speed * (1.45 if rush else 1.0)
	push_force = _base.push_force * (1.7 if rush else 1.0)
	air_control = 0.8 if rush else _base.air_control
	if rush and _trail == null:
		_trail = CPUParticles3D.new()
		var m := Palette.sphere(0.12)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 0.6
		m.material = mat
		_trail.mesh = m
		_trail.amount = 60
		_trail.lifetime = 0.7
		_trail.local_coords = false
		_trail.direction = Vector3.UP
		_trail.spread = 180.0
		_trail.initial_velocity_min = 0.2
		_trail.initial_velocity_max = 0.8
		_trail.gravity = Vector3.ZERO
		_trail.scale_amount_min = 0.5
		_trail.scale_amount_max = 1.2
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
		g.colors = PackedColorArray([Palette.PINK, Palette.LEMON, Palette.MINT, Palette.SKY, Palette.LILAC])
		_trail.color_initial_ramp = g
		add_child(_trail)
		_glow = OmniLight3D.new()
		_glow.light_color = Palette.PINK
		_glow.light_energy = 2.0
		_glow.omni_range = 3.0
		add_child(_glow)
	if _trail:
		_trail.emitting = rush
		_glow.visible = rush
	# Phase through sweepers while rushing.
	for e in get_tree().get_nodes_in_group("enemy"):
		if rush:
			add_collision_exception_with(e)
		else:
			remove_collision_exception_with(e)


## Where to push, on the ground plane, length <= 1. The player reads input;
## the rival overrides this with its AI.
func _steer_dir() -> Vector3:
	var input := Input.get_vector("left", "right", "up", "down")
	if input == Vector2.ZERO:
		return Vector3.ZERO
	return _screen_to_world(input)


## Maps stick/WASD input to the ground plane as seen from the camera.
func _screen_to_world(input: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var cam_basis := cam.global_basis if cam else Basis.IDENTITY
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var back := Vector3(cam_basis.z.x, 0.0, cam_basis.z.z).normalized()
	return (right * input.x + back * input.y).limit_length(1.0)


func _check_impacts(delta: float) -> void:
	_knock_cool -= delta
	var v := linear_velocity
	var hit := get_contact_count() > 0
	if hit and _prev_vel.y < -3.0 and v.y - _prev_vel.y > 2.5 and _knock_cool <= 0.0:
		_knock_cool = 0.15
		landed.emit(-_prev_vel.y)
	var h0 := Vector2(_prev_vel.x, _prev_vel.z).length()
	var h1 := Vector2(v.x, v.z).length()
	if hit and h0 - h1 > 2.5 and _knock_cool <= 0.0:
		_knock_cool = 0.15
		bonked.emit(h0 - h1)
	_prev_vel = v


func _check_landing() -> void:
	# Launches (cannons, catapults, loops) never count as falls.
	if break_drop <= 0.0 or _flying or input_lock > 0.0:
		_air_top = -INF
		return
	if get_contact_count() == 0:
		_air_top = maxf(_air_top, global_position.y)
		return
	if _air_top > -INF and _air_top - global_position.y > break_drop:
		_air_top = -INF
		get_tree().call_group("game", "cheer", "SPLAT!", global_position + Vector3.UP * 1.2)
		die()
		return
	_air_top = -INF


func is_grounded() -> bool:
	return get_contact_count() > 0


## Called by boosters: sets horizontal speed along dir, keeps vertical.
func boost(dir: Vector3, speed: float) -> void:
	if not alive:
		return
	linear_velocity = dir * speed + Vector3.UP * linear_velocity.y
	_match_roll()


## Called by pop bumpers: knock away at least at `speed`.
func kick(dir: Vector3, speed: float) -> void:
	if not alive:
		return
	var flat_speed := Vector2(linear_velocity.x, linear_velocity.z).length()
	linear_velocity = dir * maxf(speed, flat_speed) + Vector3.UP * 2.0
	_match_roll()


## Snaps the ball onto the line through `point` along `dir` (loop entries).
func align_to_lane(point: Vector3, dir: Vector3, min_speed: float = 0.0) -> void:
	var speed := linear_velocity.dot(dir)
	if not alive or speed < 2.0:
		return
	speed = maxf(speed, min_speed)
	if min_speed > 0.0:
		input_lock = 1.3
	var rel := global_position - point
	var target := point + dir * rel.dot(dir)
	target.y = global_position.y
	global_transform = Transform3D(global_basis, target)
	linear_velocity = dir * speed + Vector3.UP * linear_velocity.y
	_match_roll()


## Speed bank: put the ball on the lane through `point` along `dir` at `speed`.
func redirect_to(point: Vector3, dir: Vector3, speed: float) -> void:
	if not alive:
		return
	linear_velocity = dir * speed + Vector3.UP * linear_velocity.y
	_match_roll()


## Cannon: park the ball in the cup...
func hold_at(p: Vector3) -> void:
	if not alive:
		return
	freeze = true
	global_position = p
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## ...then fire it from `p` with velocity `v`.
func fire_from(p: Vector3, v: Vector3) -> void:
	if not alive:
		return
	global_position = p
	freeze = false
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	_flying = true
	linear_velocity = v
	angular_velocity = Vector3.ZERO
	input_lock = 0.5


## Spin the ball to match its ground speed, so friction doesn't eat the boost
## while converting a skid into a roll.
func _match_roll() -> void:
	var flat := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	angular_velocity = Vector3.UP.cross(flat) / radius


## Dropped into the golf hole: shrink away, stay put.
func sink() -> void:
	if not alive:
		return
	alive = false
	set_deferred("freeze", true)
	var tw := create_tween()
	tw.tween_property($Model, "scale", Vector3.ONE * 0.05, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(hide)
	# Out of the way so the other racer can still drop into the cup.
	tw.tween_callback(func() -> void:
		collision_layer = 0
		collision_mask = 0)


func die() -> void:
	if not alive:
		return
	alive = false
	visible = false
	set_deferred("freeze", true)
	if "--verbose" in OS.get_cmdline_user_args():
		print("  die() from ", get_stack().slice(1, 3), " y=", global_position.y)
	died.emit()
	await get_tree().create_timer(1.0).timeout
	global_transform = Transform3D(Basis.IDENTITY, spawn_point)
	$Model.scale = Vector3.ONE
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	visible = true
	alive = true
	_air_top = -INF
	respawned.emit()

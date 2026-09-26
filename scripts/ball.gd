class_name Ball
extends RigidBody3D
## Player marble. Input pushes it with a force, but only while it is slower
## than max_speed in that direction, so bumpers and boosters can still launch
## it past the cap.

signal died
signal respawned

@export var push_force := 16.0
@export var max_speed := 8.0
@export_range(0.0, 1.0) var air_control := 0.3
@export var fall_limit := -10.0
@export var radius := 0.5

var spawn_point := Vector3.ZERO
var alive := true


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

	if not has_node("Model"):
		_build_placeholder()
	spawn_point = global_position


func _build_placeholder() -> void:
	# White peppermint with two raspberry swirls so rolling is readable.
	Palette.add_mesh(self, Palette.sphere(radius), Palette.WHITE)
	var ring := Palette.torus(radius * 0.93, radius * 1.03)
	Palette.add_mesh(self, ring, Palette.RASPBERRY, Vector3.ZERO, Vector3(90, 0, 0))
	Palette.add_mesh(self, ring, Palette.RASPBERRY, Vector3.ZERO, Vector3(0, 0, 90))


func _physics_process(_delta: float) -> void:
	if not alive:
		return
	if global_position.y < fall_limit:
		die()
		return

	var input := Input.get_vector("left", "right", "up", "down")
	if input == Vector2.ZERO:
		return
	var dir := _screen_to_world(input)
	var flat_vel := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if flat_vel.dot(dir) < max_speed:
		var control := 1.0 if is_grounded() else air_control
		apply_central_force(dir * push_force * control)


## Maps stick/WASD input to the ground plane as seen from the camera.
func _screen_to_world(input: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var cam_basis := cam.global_basis if cam else Basis.IDENTITY
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var back := Vector3(cam_basis.z.x, 0.0, cam_basis.z.z).normalized()
	return (right * input.x + back * input.y).limit_length(1.0)


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


## Spin the ball to match its ground speed, so friction doesn't eat the boost
## while converting a skid into a roll.
func _match_roll() -> void:
	var flat := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	angular_velocity = Vector3.UP.cross(flat) / radius


func die() -> void:
	if not alive:
		return
	alive = false
	visible = false
	set_deferred("freeze", true)
	died.emit()
	await get_tree().create_timer(1.0).timeout
	global_transform = Transform3D(Basis.IDENTITY, spawn_point)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	visible = true
	alive = true
	respawned.emit()

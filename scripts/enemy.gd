class_name Enemy
extends AnimatableBody3D
## Wind-up spiky block. Patrols back and forth between its start position and
## start + travel. Eases in/out at the ends so the rhythm is easy to read.
## Touching it pops the ball.

@export var travel := Vector3(0, 0, 7.0)
@export var period := 2.6            # seconds for a full back-and-forth
@export_range(0.0, 1.0) var phase := 0.0

var _origin := Vector3.ZERO
var _time := 0.0
var _visual: Node3D


func _ready() -> void:
	sync_to_physics = true
	_origin = global_position
	_time = phase * period

	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.4, 1.0)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.7
	add_child(cs)

	var hit := Area3D.new()
	var hit_shape := BoxShape3D.new()
	hit_shape.size = Vector3(1.2, 1.5, 1.2)
	var hcs := CollisionShape3D.new()
	hcs.shape = hit_shape
	hcs.position.y = 0.75
	hit.add_child(hcs)
	add_child(hit)
	hit.body_entered.connect(_on_hit)

	_visual = get_node("Model") if has_node("Model") else _build_placeholder()


func _build_placeholder() -> Node3D:
	var v := Node3D.new()
	add_child(v)
	# Body (raspberry = danger), lilac feet, cream spikes, ink face, wind-up key.
	Palette.add_mesh(v, Palette.box(Vector3(1.0, 1.15, 1.0)), Palette.RASPBERRY, Vector3(0, 0.82, 0))
	for fx in [-0.25, 0.25]:
		Palette.add_mesh(v, Palette.box(Vector3(0.28, 0.25, 0.4)), Palette.LILAC, Vector3(fx, 0.12, 0.05))
	for i in 5:
		var sx := -0.4 + i * 0.2
		Palette.add_mesh(v, Palette.cylinder(0.0, 0.08, 0.22), Palette.CREAM, Vector3(sx, 1.5, 0))
	for ex in [-0.2, 0.2]:
		Palette.add_mesh(v, Palette.sphere(0.07), Palette.INK, Vector3(ex, 0.95, 0.5))
		Palette.add_mesh(v, Palette.box(Vector3(0.28, 0.06, 0.04)), Palette.INK,
			Vector3(ex, 1.1, 0.51), Vector3(0, 0, 20.0 if ex < 0 else -20.0))
	Palette.add_mesh(v, Palette.torus(0.08, 0.16), Palette.LILAC, Vector3(0, 0.9, -0.62), Vector3(90, 0, 0))
	return v


func _physics_process(delta: float) -> void:
	_time += delta
	var t := _time / period * TAU
	var s := (1.0 - cos(t)) * 0.5
	global_position = _origin + travel * s
	# Face the direction of motion (face is on +z).
	var moving := travel * sin(t)
	if moving.length() > 0.01:
		_visual.rotation.y = atan2(moving.x, moving.z)


func _on_hit(body: Node3D) -> void:
	if body is Ball:
		body.die()

class_name Bird
extends Node3D
## The Silly Race's bird. It hovers over its perch at the end of a ledge;
## roll onto the perch and it swoops down, grabs the marble, flies it across
## the gap and drops it at `target` (world x, z).

@export var target := Vector2.ZERO
@export var speed := 6.0
@export var tint := Color(0, 0, 0, 0)

const HOVER := 3.2
var _busy := false
var _body: Node3D
var _wings: Array[Node3D] = []
var _home := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	var col := tint if tint.a > 0.0 else Palette.LEMON
	_body = Node3D.new()
	_body.top_level = true
	add_child(_body)
	Palette.add_mesh(_body, Palette.sphere(0.55, 0.8), col)
	Palette.add_mesh(_body, Palette.sphere(0.32), col, Vector3(0, 0.3, 0.5))
	var beak := Palette.add_mesh(_body, Palette.cylinder(0.02, 0.16, 0.5), Color("#F6845E"), Vector3(0, 0.25, 0.95))
	beak.rotation_degrees.x = 90.0
	for ex in [-0.16, 0.16]:
		Palette.add_mesh(_body, Palette.sphere(0.07), Palette.INK, Vector3(ex, 0.4, 0.72))
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.4, 0.15, 0.0)
		_body.add_child(wing)
		Palette.add_mesh(wing, Palette.box(Vector3(1.5, 0.08, 0.7)), col, Vector3(side * 0.75, 0, 0))
		_wings.append(wing)
	_home = global_position + Vector3.UP * HOVER
	_body.global_position = _home
	var d := _dir()
	_body.global_rotation.y = atan2(d.x, d.z)
	# The perch: a candy stripe ring on the ground.
	Palette.add_mesh(self, Palette.torus(0.7, 0.9), Palette.CREAM, Vector3(0, 0.04, 0))
	var perch := Area3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 1.2
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.6
	perch.add_child(cs)
	add_child(perch)
	perch.body_entered.connect(_on_enter)


func _process(delta: float) -> void:
	_t += delta
	for k in _wings.size():
		_wings[k].rotation.z = (1.0 if k == 0 else -1.0) * sin(_t * (14.0 if _busy else 6.0)) * 0.55
	if not _busy:
		_body.global_position = _home + Vector3.UP * 0.2 * sin(_t * 2.0)


func _dir() -> Vector3:
	var d := Vector3(target.x - global_position.x, 0.0, target.y - global_position.z)
	return d.normalized() if d.length() > 0.1 else Vector3.FORWARD


func _level() -> LevelBase:
	var game := get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	return game.level if game else null


func _on_enter(body: Node3D) -> void:
	if _busy or not (body is Ball) or not body.alive:
		return
	_busy = true
	body.call_deferred("hold_at", global_position + Vector3(0, 0.5, 0))
	get_tree().call_group("game", "play_sound", "whoosh", global_position)
	var grab := global_position + Vector3(0, 1.1, 0)
	await _fly(_body.global_position, grab, 0.5, null, 0.0)
	var level := _level()
	var y := level.height(target.x, target.y) if level else global_position.y
	var drop := Vector3(target.x, y + 1.1, target.y)
	await _fly(grab, drop, maxf(0.8, grab.distance_to(drop) / speed), body, 2.0)
	if is_instance_valid(body) and body.alive:
		body.fire_from(drop - Vector3(0, 0.4, 0), _dir() * 1.5)
		get_tree().call_group("game", "play_sound", "boing", drop)
	await _fly(drop, _home, 1.2, null, 1.0)
	_busy = false


## Flies the bird from a to b over `dur` seconds in an arc `lift` high,
## carrying the marble under it.
func _fly(a: Vector3, b: Vector3, dur: float, carry: Node3D, lift: float) -> void:
	var t := 0.0
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if flat.length() > 0.1:
		_body.global_rotation.y = atan2(flat.x, flat.z)
	while t < dur:
		t += get_process_delta_time()
		var u := clampf(t / dur, 0.0, 1.0)
		var p := a.lerp(b, u) + Vector3.UP * lift * sin(PI * u)
		_body.global_position = p
		if carry and is_instance_valid(carry):
			carry.global_position = p - Vector3(0, 0.6, 0)
		await get_tree().process_frame

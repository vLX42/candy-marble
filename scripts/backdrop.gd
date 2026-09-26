class_name Backdrop
extends Node3D
## Cute scenery outside the play area: big drifting clouds, small floating candy
## islands, a rainbow and balloons rising past. Everything sits well below or
## outside the level so it never hides the ball.

const CloudScene := preload("res://models/cloud.glb")
const IsletScene := preload("res://models/islet.glb")
const RainbowScene := preload("res://models/rainbow.glb")
const BalloonScene := preload("res://models/balloon.glb")
const BALLOON_COLORS := [Palette.PINK, Palette.LEMON, Palette.LILAC, Palette.SKY, Palette.CORAL]

var bounds := Rect2()
var _rng := RandomNumberGenerator.new()
var _clouds: Array[Node3D] = []
var _islets: Array[Node3D] = []
var _balloons: Array[Node3D] = []
var _time := 0.0


func setup(level_bounds: Rect2, seed_value: int) -> void:
	bounds = level_bounds
	_rng.seed = seed_value


func _ready() -> void:
	var outer := bounds.grow(34.0)
	for k in 14:
		var c: Node3D = CloudScene.instantiate()
		c.position = _outside(outer, 6.0, _rng.randf_range(-26.0, -12.0))
		c.scale = Vector3.ONE * _rng.randf_range(3.0, 6.0)
		c.rotation.y = _rng.randf() * TAU
		add_child(c)
		_clouds.append(c)
	for k in 5:
		var s: Node3D = IsletScene.instantiate()
		s.position = _outside(outer, 10.0, _rng.randf_range(-20.0, -8.0))
		s.scale = Vector3.ONE * _rng.randf_range(0.7, 1.3)
		s.rotation.y = _rng.randf() * TAU
		add_child(s)
		_islets.append(s)
	# Rainbow on the far side (top of the screen), facing the camera.
	var r: Node3D = RainbowScene.instantiate()
	r.position = Vector3(bounds.position.x - 22.0, -30.0, bounds.position.y - 22.0)
	r.rotation_degrees.y = 45.0
	r.scale = Vector3.ONE * 2.6
	add_child(r)
	for k in 10:
		var b: Node3D = BalloonScene.instantiate()
		b.position = _outside(bounds.grow(10.0), 4.0, _rng.randf_range(-30.0, 2.0))
		b.scale = Vector3.ONE * _rng.randf_range(0.8, 1.3)
		var mat := Palette.candy(BALLOON_COLORS[k % BALLOON_COLORS.size()], 0.2)
		for mi: MeshInstance3D in b.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = mat
		add_child(b)
		_balloons.append(b)


## Random point in `area` but at least `margin` outside the level bounds.
func _outside(area: Rect2, margin: float, y: float) -> Vector3:
	var inner := bounds.grow(margin)
	for attempt in 30:
		var p := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		if not inner.has_point(p):
			return Vector3(p.x, y, p.y)
	return Vector3(area.position.x, y, area.position.y)


func _process(delta: float) -> void:
	_time += delta
	for k in _clouds.size():
		var c := _clouds[k]
		c.position.x += delta * (0.4 + 0.1 * (k % 3))
		if c.position.x > bounds.end.x + 40.0:
			c.position.x = bounds.position.x - 40.0
	for k in _islets.size():
		_islets[k].position.y += sin(_time * 0.6 + k) * delta * 0.25
	for k in _balloons.size():
		var b := _balloons[k]
		b.position.y += delta * (0.8 + 0.15 * (k % 4))
		b.position.x += sin(_time * 0.7 + k) * delta * 0.3
		if b.position.y > 4.0:
			b.position.y = -30.0

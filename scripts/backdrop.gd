class_name Backdrop
extends Node3D
## Cute scenery in the sky around the course: candy castles, gingerbread houses,
## jelly mountains, a spinning ferris wheel, drifting clouds, floating islets,
## hot-air balloons and party balloons. Everything sits well below the track
## and away from it, so it never hides the ball.

const SCENERY := [
	"candy_castle", "gingerbread_house", "jelly_mountains", "lollipop_forest",
	"ice_cream_tower", "candy_cane_arch", "donut_planet", "islet", "cotton_candy_cloud_big",
]
const BALLOON_COLORS := [Palette.PINK, Palette.LEMON, Palette.LILAC, Palette.SKY, Palette.CORAL]
const CLEARANCE := 7.0  # min distance (units) from any track tile

var level: LevelBase
var _rng := RandomNumberGenerator.new()
var _clouds: Array[Node3D] = []
var _bobbers: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _risers: Array[Node3D] = []
var _time := 0.0
var _bounds := Rect2()


func setup(level_data: LevelBase, seed_value: int) -> void:
	level = level_data
	_rng.seed = seed_value


func _ready() -> void:
	_bounds = Rect2(0, 0, level.cols * LevelBase.TILE, level.rows * LevelBase.TILE).grow(24.0)
	var spots := _free_spots(11.0)
	spots.shuffle()
	var k := 0
	for p in spots:
		var roll := _rng.randf()
		if roll < 0.45:
			_add_scenery(p, SCENERY[k % SCENERY.size()])
			k += 1
		elif roll < 0.55 and _spinners.size() < 3:
			_add_ferris_wheel(p)
		elif roll < 0.8:
			_add_cloud(p)
		else:
			_add_hot_air_balloon(p)
	for n in 16:
		_add_party_balloon()


## Grid of points over the level area that are far from any track tile.
func _free_spots(step: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var x := _bounds.position.x
	while x < _bounds.end.x:
		var z := _bounds.position.y
		while z < _bounds.end.y:
			var p := Vector2(x + _rng.randf_range(-4, 4), z + _rng.randf_range(-4, 4))
			if _clear(p):
				out.append(p)
			z += step
		x += step
	return out


func _clear(p: Vector2) -> bool:
	var r := int(ceil(CLEARANCE / LevelBase.TILE))
	var t := level.tile_at(p.x, p.y)
	for i in range(t.x - r, t.x + r + 1):
		for j in range(t.y - r, t.y + r + 1):
			if level.is_tile_ground(i, j) and level.tile_center(i, j).distance_to(p) < CLEARANCE:
				return false
	return true


func _instance(model: String) -> Node3D:
	var path := "res://models/%s.glb" % model
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = load(path).instantiate()
	add_child(n)
	Terrain.no_shadows(n)
	return n


func _add_scenery(p: Vector2, model: String) -> void:
	var n := _instance(model)
	if n == null:
		return
	var s := _rng.randf_range(1.0, 1.8)
	n.scale = Vector3.ONE * s
	n.rotation.y = deg_to_rad(45.0 + _rng.randf_range(-40.0, 40.0))
	# Keep the top of the model a bit below the track so it never hides the ball.
	n.position = Vector3(p.x, -2.0 - _top(n) * s - _rng.randf_range(0.0, 6.0), p.y)
	_bobbers.append(n)


## Highest point of a model in its own space.
static func _top(n: Node3D) -> float:
	var top := 0.0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var box := mi.transform * mi.get_aabb()
		top = maxf(top, box.end.y)
	return top


func _add_ferris_wheel(p: Vector2) -> void:
	var stand := _instance("ferris_wheel_stand")
	var rotor := _instance("ferris_wheel_rotor")
	if stand == null or rotor == null:
		return
	var s := _rng.randf_range(1.2, 1.6)
	var base := Vector3(p.x, -2.0 - 8.6 * s - _rng.randf_range(0.0, 4.0), p.y)
	var yaw := deg_to_rad(45.0)
	for n in [stand, rotor]:
		n.scale = Vector3.ONE * s
		n.rotation.y = yaw
	stand.position = base
	rotor.position = base + Vector3.UP * 5.1 * s
	_spinners.append(rotor)
	var cloud := _instance("cotton_candy_cloud_big")
	if cloud:
		cloud.position = base - Vector3.UP * 1.5
		cloud.scale = Vector3.ONE * s


func _add_cloud(p: Vector2) -> void:
	var n := _instance("cloud")
	if n == null:
		return
	n.position = Vector3(p.x, _rng.randf_range(-18.0, -6.0), p.y)
	n.scale = Vector3.ONE * _rng.randf_range(2.5, 5.0)
	n.rotation.y = _rng.randf() * TAU
	_clouds.append(n)


func _add_hot_air_balloon(p: Vector2) -> void:
	var n := _instance("hot_air_balloon")
	if n == null:
		return
	n.position = Vector3(p.x, _rng.randf_range(-30.0, -8.0), p.y)
	n.scale = Vector3.ONE * _rng.randf_range(1.0, 1.6)
	_risers.append(n)


func _add_party_balloon() -> void:
	var n := _instance("balloon")
	if n == null:
		return
	var spots := _free_spots(30.0)
	var p: Vector2 = spots[_rng.randi() % spots.size()] if spots.size() > 0 else _bounds.position
	n.position = Vector3(p.x, _rng.randf_range(-30.0, 2.0), p.y)
	n.scale = Vector3.ONE * _rng.randf_range(0.8, 1.3)
	var mat := Palette.candy(BALLOON_COLORS[_risers.size() % BALLOON_COLORS.size()], 0.2)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
	_risers.append(n)


func _process(delta: float) -> void:
	_time += delta
	for k in _clouds.size():
		var c := _clouds[k]
		c.position.x += delta * (0.4 + 0.1 * (k % 3))
		if c.position.x > _bounds.end.x:
			c.position.x = _bounds.position.x
	for k in _bobbers.size():
		_bobbers[k].position.y += sin(_time * 0.5 + k) * delta * 0.2
	for r in _spinners:
		r.rotate_object_local(Vector3.FORWARD, delta * 0.35)
	for k in _risers.size():
		var b := _risers[k]
		b.position.y += delta * (0.6 + 0.15 * (k % 4))
		b.position.x += sin(_time * 0.7 + k) * delta * 0.3
		if b.position.y > 4.0:
			b.position.y = -32.0

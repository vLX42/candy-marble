class_name Terrain
extends StaticBody3D
## Builds the island mesh, collision, icing drips and clouds from a LevelBase.
## Tops are shaded by terrain.gdshader (pillow tiles, icing, chocolate walls).

const STEP := 0.25
const N := 8                 # cells per tile side (TILE / STEP)
const WALL_BOTTOM := -3.5
const CHOCOLATE := Color("#5A3426")

const TerrainShader := preload("res://scripts/terrain.gdshader")
const CloudScene := preload("res://models/cloud.glb")

var level: LevelBase
var _st: SurfaceTool
var _faces := PackedVector3Array()
var _drips: Array[Transform3D] = []
var _cloud_spots: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()


func _init(level_data: LevelBase) -> void:
	level = level_data


func _ready() -> void:
	_rng.seed = hash(level.title)
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in level.rows:
		for i in level.cols:
			if level.is_tile_ground(i, j):
				_build_tile(i, j)

	var mat := ShaderMaterial.new()
	mat.shader = TerrainShader
	var mi := MeshInstance3D.new()
	mi.mesh = _st.commit()
	mi.material_override = mat
	add_child(mi)

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	physics_material_override = pm

	_add_drips()
	_add_clouds()


func _build_tile(i: int, j: int) -> void:
	var x0 := i * LevelBase.TILE
	var z0 := j * LevelBase.TILE
	var pillow := 0.0 if level.is_ramp(i, j) else 1.0
	var rand := _rng.randf()
	# Vertex heights for this tile.
	var hv: Array[PackedFloat32Array] = []
	for a in N + 1:
		var col := PackedFloat32Array()
		col.resize(N + 1)
		for b in N + 1:
			col[b] = level.surface(i, j, x0 + a * STEP, z0 + b * STEP)
		hv.append(col)

	for a in N:
		for b in N:
			var cx := x0 + (a + 0.5) * STEP
			var cz := z0 + (b + 0.5) * STEP
			if level.in_hole(cx, cz):
				continue
			var xa := x0 + a * STEP
			var za := z0 + b * STEP
			var p00 := Vector3(xa, hv[a][b], za)
			var p10 := Vector3(xa + STEP, hv[a + 1][b], za)
			var p11 := Vector3(xa + STEP, hv[a + 1][b + 1], za + STEP)
			var p01 := Vector3(xa, hv[a][b + 1], za + STEP)
			var col := level.cell_color(i, j, cx, cz)
			col.a = pillow
			var ns := [_normal(hv, a, b), _normal(hv, a + 1, b), _normal(hv, a + 1, b + 1), _normal(hv, a, b + 1)]
			var pts := [p00, p10, p11, p01]
			for k in [0, 1, 2, 0, 2, 3]:
				_st.set_color(col)
				_st.set_uv(Vector2(1.0, rand))
				_st.set_normal(ns[k])
				_st.add_vertex(pts[k])
				_faces.append(pts[k])
			# Walls on edges that face void, the hole, or a lower tile.
			_edge(i, j, a, b, p00, p10, Vector3.FORWARD, cx, cz - STEP, pillow)
			_edge(i, j, a, b, p10, p11, Vector3.RIGHT, cx + STEP, cz, pillow)
			_edge(i, j, a, b, p11, p01, Vector3.BACK, cx, cz + STEP, pillow)
			_edge(i, j, a, b, p01, p00, Vector3.LEFT, cx - STEP, cz, pillow)


func _normal(hv: Array[PackedFloat32Array], a: int, b: int) -> Vector3:
	var a0 := maxi(a - 1, 0)
	var a1 := mini(a + 1, N)
	var b0 := maxi(b - 1, 0)
	var b1 := mini(b + 1, N)
	var dx := (hv[a1][b] - hv[a0][b]) / ((a1 - a0) * STEP)
	var dz := (hv[a][b1] - hv[a][b0]) / ((b1 - b0) * STEP)
	return Vector3(-dx, 1.0, -dz).normalized()


func _edge(i: int, j: int, _a: int, _b: int, pa: Vector3, pb: Vector3, n: Vector3, nx: float, nz: float, pillow: float) -> void:
	var nt := level.tile_at(nx, nz)
	var to_void := not level.is_tile_ground(nt.x, nt.y)
	var into_hole := level.in_hole(nx, nz)
	if not to_void and not into_hole:
		if nt == Vector2i(i, j):
			return
		# Neighbour tile: only wall if it is lower along this edge.
		var ha := level.surface(nt.x, nt.y, pa.x, pa.z)
		var hb := level.surface(nt.x, nt.y, pb.x, pb.z)
		if ha > pa.y - 0.02 and hb > pb.y - 0.02:
			return
	var a2 := Vector3(pa.x, WALL_BOTTOM, pa.z)
	var b2 := Vector3(pb.x, WALL_BOTTOM, pb.z)
	var top := CHOCOLATE.srgb_to_linear()
	top.a = pillow
	var bottom := CHOCOLATE.srgb_to_linear().darkened(0.3)
	bottom.a = 0.0
	var wn := (n + Vector3.UP * 0.2).normalized()
	# Clockwise = front face in Godot.
	for p in [pa, b2, pb, pa, a2, b2]:
		_st.set_color(top if p.y > WALL_BOTTOM else bottom)
		_st.set_uv(Vector2(0.0, 0.0))
		_st.set_normal(wn)
		_st.add_vertex(p)
		_faces.append(p)

	var mid: Vector3 = (pa + pb) * 0.5
	if level.is_ramp(i, j) and not into_hole and _rng.randf() < 0.55:
		var length := _rng.randf_range(0.25, 0.9)
		_drips.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1, length, 1)), mid + n * 0.02 - Vector3.UP * length * 0.45))
	if to_void and _rng.randf() < 0.05:
		_cloud_spots.append(mid + n * 0.6)


func _add_drips() -> void:
	if _drips.is_empty():
		return
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.1
	capsule.height = 1.0
	var mat := Palette.candy(Palette.LEMON, 0.12)
	capsule.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = capsule
	mm.instance_count = _drips.size()
	for k in _drips.size():
		mm.set_instance_transform(k, _drips[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _add_clouds() -> void:
	var placed: Array[Vector3] = []
	for spot in _cloud_spots:
		var ok := true
		for q in placed:
			if q.distance_to(spot) < 4.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(spot)
		var cloud: Node3D = CloudScene.instantiate()
		cloud.position = Vector3(spot.x, WALL_BOTTOM + _rng.randf_range(-0.3, 0.6), spot.z)
		cloud.scale = Vector3.ONE * _rng.randf_range(1.0, 1.8)
		cloud.rotation.y = _rng.randf() * TAU
		add_child(cloud)

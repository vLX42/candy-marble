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
	_st.index()
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
	# Flat or evenly sloped tiles don't need the fine grid: vertex lines at the
	# edges and one STEP in are enough for the shader's seam groove, so they
	# look identical with 9 cells instead of 64.
	var simple := _is_simple(i, j, x0, z0)
	var off := PackedFloat32Array()
	if simple:
		off = PackedFloat32Array([0.0, STEP, LevelBase.TILE - STEP, LevelBase.TILE])
	else:
		for k in N + 1:
			off.append(k * STEP)
	var n := off.size() - 1
	var hv: Array[PackedFloat32Array] = []
	for a in n + 1:
		var col := PackedFloat32Array()
		col.resize(n + 1)
		for b in n + 1:
			col[b] = level.surface(i, j, x0 + off[a], z0 + off[b])
		hv.append(col)

	for a in n:
		for b in n:
			var xa := x0 + off[a]
			var xb := x0 + off[a + 1]
			var za := z0 + off[b]
			var zb := z0 + off[b + 1]
			var cx := (xa + xb) * 0.5
			var cz := (za + zb) * 0.5
			if not simple and level.in_hole(cx, cz):
				continue
			var p00 := Vector3(xa, hv[a][b], za)
			var p10 := Vector3(xb, hv[a + 1][b], za)
			var p11 := Vector3(xb, hv[a + 1][b + 1], zb)
			var p01 := Vector3(xa, hv[a][b + 1], zb)
			var col := level.cell_color(i, j, cx, cz)
			col.a = pillow
			var ns: Array
			if simple:
				var nrm := _normal_at(i, j, cx, cz)
				ns = [nrm, nrm, nrm, nrm]
			else:
				ns = [_normal(hv, a, b), _normal(hv, a + 1, b), _normal(hv, a + 1, b + 1), _normal(hv, a, b + 1)]
			var pts := [p00, p10, p11, p01]
			for k in [0, 1, 2, 0, 2, 3]:
				_st.set_color(col)
				_st.set_uv(Vector2(1.0, rand))
				_st.set_normal(ns[k])
				_st.add_vertex(pts[k])
				_faces.append(pts[k])
			# Walls on edges that face void, the hole, or a lower tile. The probe
			# point is the neighbouring cell's centre (fine grid) or just across
			# the edge (coarse grid, never next to the hole).
			var hx := (xb - xa) * 0.5 if not simple else 0.05
			var hz := (zb - za) * 0.5 if not simple else 0.05
			_edge(i, j, p00, p10, Vector3.FORWARD, cx, za - hz, pillow)
			_edge(i, j, p10, p11, Vector3.RIGHT, xb + hx, cz, pillow)
			_edge(i, j, p11, p01, Vector3.BACK, cx, zb + hz, pillow)
			_edge(i, j, p01, p00, Vector3.LEFT, xa - hx, cz, pillow)


## True if the tile has no waves, hills, trenches or hole on it.
func _is_simple(i: int, j: int, x0: float, z0: float) -> bool:
	for a in range(0, N + 1, 2):
		for b in range(0, N + 1, 2):
			var x := x0 + a * STEP
			var z := z0 + b * STEP
			if absf(level.feature(x, z)) > 0.0005 or level.in_hole(x, z):
				return false
	return true


func _normal_at(i: int, j: int, x: float, z: float) -> Vector3:
	var e := 0.05
	var dx := (level.surface(i, j, x + e, z) - level.surface(i, j, x - e, z)) / (2.0 * e)
	var dz := (level.surface(i, j, x, z + e) - level.surface(i, j, x, z - e)) / (2.0 * e)
	return Vector3(-dx, 1.0, -dz).normalized()


func _normal(hv: Array[PackedFloat32Array], a: int, b: int) -> Vector3:
	var a0 := maxi(a - 1, 0)
	var a1 := mini(a + 1, N)
	var b0 := maxi(b - 1, 0)
	var b1 := mini(b + 1, N)
	var dx := (hv[a1][b] - hv[a0][b]) / ((a1 - a0) * STEP)
	var dz := (hv[a][b1] - hv[a][b0]) / ((b1 - b0) * STEP)
	return Vector3(-dx, 1.0, -dz).normalized()


func _edge(i: int, j: int, pa: Vector3, pb: Vector3, n: Vector3, nx: float, nz: float, pillow: float) -> void:
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

	# Drips and cloud spots per STEP of edge, so coarse edges get as many.
	var segs := maxi(1, roundi(pa.distance_to(pb) / STEP))
	for k in segs:
		var mid: Vector3 = pa.lerp(pb, (k + 0.5) / segs)
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
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		Terrain.no_shadows(cloud)


## Turns off shadow casting for every mesh under `n` (scenery far below the
## track: its shadows are never visible, but they cost a lot to render).
static func no_shadows(n: Node) -> void:
	for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

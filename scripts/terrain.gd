class_name Terrain
extends StaticBody3D
## Greybox island generated from a height function.
## Replace later with Blender tile meshes (name them *-col so Godot adds collision).

const STEP := 0.5          # mesh resolution in world units
const TILE := 2.0          # checker size, matches one kit tile
const SKIRT_DEPTH := 3.0
const SIZE := Vector2(46.0, 27.0)

## Walkable areas (x, z, width, depth).
const AREAS: Array[Rect2] = [
	Rect2(0, 0, 42, 10),   # main lane: start, trench, hills, enemy zone
	Rect2(36, 10, 6, 4),   # jump ramp
	Rect2(33, 17, 12, 9),  # goal plateau (gap between 14 and 17)
]

## Hills: x, z, height, radius.
const HILLS: Array[Vector4] = [
	Vector4(21.0, 2.5, 1.3, 1.4),
	Vector4(24.0, 7.2, 1.6, 1.6),
	Vector4(25.8, 2.2, 0.9, 1.2),
]

const RAMP_TOP := 1.4
const PLATEAU := 0.4


static func is_ground(x: float, z: float) -> bool:
	for r in AREAS:
		if r.has_point(Vector2(x, z)):
			return true
	return false


static func height(x: float, z: float) -> float:
	if z >= 17.0:
		return PLATEAU
	if z > 10.0 and x >= 36.0:
		return clampf((z - 10.0) / 4.0, 0.0, 1.0) * RAMP_TOP
	var h := 0.0
	# Trench along z = 5, tapering in and out at the ends.
	if x > 7.0 and x < 19.0:
		var along := minf(smoothstep(7.0, 8.5, x), 1.0 - smoothstep(17.5, 19.0, x))
		var profile := 1.0 - smoothstep(1.0, 1.8, absf(z - 5.0))
		h -= 0.8 * profile * along
	for hill in HILLS:
		var dx := x - hill.x
		var dz := z - hill.y
		h += hill.z * exp(-(dx * dx + dz * dz) / (2.0 * hill.w * hill.w))
	return h


static func color_at(x: float, z: float) -> Color:
	var c := Palette.MINT
	var h := height(x, z)
	if z > 10.0 and z < 17.0:
		c = Palette.LEMON
	elif z >= 17.0:
		c = Palette.LILAC
	elif h < -0.25:
		c = Palette.SKY
	elif h > 0.35:
		c = Palette.PINK
	var checker := (int(floor(x / TILE)) + int(floor(z / TILE))) % 2 == 0
	return c.darkened(0.07) if checker else c


static func normal_at(x: float, z: float) -> Vector3:
	var e := 0.05
	var dx := (height(x + e, z) - height(x - e, z)) / (2.0 * e)
	var dz := (height(x, z + e) - height(x, z - e)) / (2.0 * e)
	return Vector3(-dx, 1.0, -dz).normalized()


func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()

	var nx := int(SIZE.x / STEP)
	var nz := int(SIZE.y / STEP)
	for i in nx:
		for j in nz:
			var x0 := i * STEP
			var z0 := j * STEP
			var x1 := x0 + STEP
			var z1 := z0 + STEP
			var cx := x0 + STEP * 0.5
			var cz := z0 + STEP * 0.5
			if not is_ground(cx, cz):
				continue
			var p00 := Vector3(x0, height(x0, z0), z0)
			var p10 := Vector3(x1, height(x1, z0), z0)
			var p11 := Vector3(x1, height(x1, z1), z1)
			var p01 := Vector3(x0, height(x0, z1), z1)
			var col := color_at(cx, cz)
			for p in [p00, p10, p11, p00, p11, p01]:
				st.set_color(col)
				st.set_normal(normal_at(p.x, p.z))
				st.add_vertex(p)
				faces.append(p)
			# Side skirts where the island ends.
			_skirt(st, faces, p00, p10, Vector3.FORWARD, not is_ground(cx, cz - STEP))
			_skirt(st, faces, p10, p11, Vector3.RIGHT, not is_ground(cx + STEP, cz))
			_skirt(st, faces, p11, p01, Vector3.BACK, not is_ground(cx, cz + STEP))
			_skirt(st, faces, p01, p00, Vector3.LEFT, not is_ground(cx - STEP, cz))

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.35
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	physics_material_override = pm


func _skirt(st: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, n: Vector3, needed: bool) -> void:
	if not needed:
		return
	var a2 := Vector3(a.x, -SKIRT_DEPTH, a.z)
	var b2 := Vector3(b.x, -SKIRT_DEPTH, b.z)
	for p in [a, b, b2, a, b2, a2]:
		st.set_color(Palette.BASE.lightened(0.3))
		st.set_normal(n)
		st.add_vertex(p)
		faces.append(p)

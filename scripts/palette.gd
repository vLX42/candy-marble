class_name Palette
## Locked color roles from the art bible (art/STYLE.md).
## Raspberry = danger, orange/lemon = interactive, white = player, pastels = world.

const MINT := Color("#A8E6C8")
const PINK := Color("#F7B2C0")
const LEMON := Color("#F6E27A")
const LILAC := Color("#C9B8EC")
const SKY := Color("#A9D6F5")
const BASE := Color("#E9A99A")
const ISLAND_SIDE := Color("#F7C9B8")
const RASPBERRY := Color("#C8204F")
const CORAL := Color("#F6845E")
const CREAM := Color("#FFF4E0")
const WHITE := Color("#FBF8F4")
const INK := Color("#3A1F2B")
const BACKGROUND := Color("#D6ECF8")


## Instances models/<name>.glb (built by blender/build_assets.py) as a child
## named "Model". Returns null if the model doesn't exist.
static func load_model(parent: Node3D, model_name: String) -> Node3D:
	var path := "res://models/%s.glb" % model_name
	if not ResourceLoader.exists(path):
		return null
	var m: Node3D = load(path).instantiate()
	m.name = "Model"
	parent.add_child(m)
	return m


## Opaque satin "vinyl toy" material.
static func candy(color: Color, roughness: float = 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	m.clearcoat_roughness = 0.2
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	return m


## Adds a placeholder mesh with a candy material to parent.
static func add_mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = candy(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func sphere(radius: float, height: float = -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0 if height < 0.0 else height
	return s


static func cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	return c


static func torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return t

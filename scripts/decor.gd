class_name Decor
extends StaticBody3D
## Off-track decoration (Blender models). Thin collider so the ball bumps it.

## Model name in models/. lollipop, tree and bear stand on the ground; the
## candies (gumdrop, golden_cupcake, heart_candy, ...) float and spin.
@export var kind := "lollipop"

var _floaty: Node3D
var _t := 0.0


func _ready() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = 0.12 if kind == "lollipop" else 0.45
	shape.height = 1.4
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.7
	add_child(cs)
	if kind not in ["lollipop", "tree", "bear"]:
		var m := Palette.load_model(self, kind)
		if m:
			m.scale = Vector3.ONE * 1.6
			m.position.y = 1.0
			_floaty = m
			_t = randf() * TAU
		return
	if has_node("Model") or Palette.load_model(self, kind) != null:
		return
	# Fallback placeholders.
	match kind:
		"lollipop":
			Palette.add_mesh(self, Palette.cylinder(0.05, 0.05, 1.3), Palette.CREAM, Vector3(0, 0.65, 0))
			Palette.add_mesh(self, Palette.cylinder(0.45, 0.45, 0.14), Palette.PINK, Vector3(0, 1.5, 0), Vector3(90, 0, 0))
		_:
			Palette.add_mesh(self, Palette.cylinder(0.12, 0.16, 0.6), Palette.CREAM, Vector3(0, 0.3, 0))
			Palette.add_mesh(self, Palette.sphere(0.55), Palette.MINT.darkened(0.1), Vector3(0, 0.9, 0))


func _process(delta: float) -> void:
	if _floaty:
		_t += delta
		_floaty.rotation.y = _t * 1.2
		_floaty.position.y = 1.0 + sin(_t * 2.0) * 0.12

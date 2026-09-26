class_name Goal
extends Area3D
## Finish cup with a lemon flag. Emits reached when the ball rolls in.

signal reached

var _done := false


func _ready() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = 1.1
	shape.height = 1.5
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.75
	add_child(cs)
	body_entered.connect(_on_body_entered)
	if not has_node("Model"):
		_build_placeholder()


func _build_placeholder() -> void:
	Palette.add_mesh(self, Palette.cylinder(1.0, 1.0, 0.03), Palette.PINK, Vector3(0, 0.02, 0))
	Palette.add_mesh(self, Palette.torus(0.95, 1.2), Palette.CREAM, Vector3(0, 0.06, 0))
	Palette.add_mesh(self, Palette.cylinder(0.04, 0.04, 1.8), Palette.WHITE, Vector3(0.9, 0.9, -0.9))
	Palette.add_mesh(self, Palette.box(Vector3(0.6, 0.4, 0.04)), Palette.LEMON, Vector3(1.22, 1.55, -0.9))


func _on_body_entered(body: Node3D) -> void:
	if body is Ball and not _done:
		_done = true
		reached.emit()

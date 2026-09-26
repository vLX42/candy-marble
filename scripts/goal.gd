class_name Goal
extends Area3D
## Golf hole. The terrain cuts the hole (LevelBase.HOLE_RADIUS); this node sits
## at the rim with the flag, a cup floor, and a trigger below the rim. When the
## ball drops in it sinks and `reached` fires.

signal reached

var _done := false


func _ready() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = LevelBase.HOLE_RADIUS - 0.05
	shape.height = 0.6
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = -0.95
	add_child(cs)
	body_entered.connect(_on_body_entered)

	# Cup floor so the ball rests in the hole.
	var floor_body := StaticBody3D.new()
	var floor_shape := CylinderShape3D.new()
	floor_shape.radius = LevelBase.HOLE_RADIUS + 0.2
	floor_shape.height = 0.2
	var fcs := CollisionShape3D.new()
	fcs.shape = floor_shape
	fcs.position.y = -1.4
	floor_body.add_child(fcs)
	add_child(floor_body)
	Palette.add_mesh(self, Palette.cylinder(LevelBase.HOLE_RADIUS + 0.1, LevelBase.HOLE_RADIUS + 0.1, 0.1),
		Color("#2E1A14"), Vector3(0, -1.3, 0))

	if not has_node("Model") and Palette.load_model(self, "flag") == null:
		Palette.add_mesh(self, Palette.torus(0.86, 1.05), Palette.CREAM, Vector3(0, 0.02, 0))
		Palette.add_mesh(self, Palette.cylinder(0.04, 0.04, 1.8), Palette.WHITE, Vector3(0.72, 0.9, -0.72))
		Palette.add_mesh(self, Palette.box(Vector3(0.6, 0.4, 0.04)), Palette.LEMON, Vector3(1.0, 1.55, -0.72))


func _on_body_entered(body: Node3D) -> void:
	if body is Ball and not _done:
		_done = true
		body.call_deferred("sink")
		reached.emit()

class_name Booster
extends Area3D
## Coral booster pad, flush with the floor. Sets the ball's speed along the
## direction the chevrons point (local +z), past the player's max speed.

@export var speed := 11.0

var _chevrons: Array[Node3D] = []


func _ready() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.6, 2.0)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.3
	add_child(cs)
	body_entered.connect(_on_body_entered)
	if not has_node("Model") and Palette.load_model(self, "booster") == null:
		_build_placeholder()


func _build_placeholder() -> void:
	Palette.add_mesh(self, Palette.box(Vector3(1.9, 0.04, 1.9)), Palette.CORAL, Vector3(0, 0.02, 0))
	for k in 3:
		var tip := 0.55 - k * 0.45
		var chevron := Node3D.new()
		add_child(chevron)
		var arm := Palette.box(Vector3(0.62, 0.05, 0.14))
		Palette.add_mesh(chevron, arm, Palette.CREAM, Vector3(-0.2, 0.05, tip - 0.2), Vector3(0, -45, 0))
		Palette.add_mesh(chevron, arm, Palette.CREAM, Vector3(0.2, 0.05, tip - 0.2), Vector3(0, 45, 0))
		_chevrons.append(chevron)


func _process(_delta: float) -> void:
	# Chase-light pulse along the chevrons.
	var t := Time.get_ticks_msec() / 1000.0
	for k in _chevrons.size():
		var s := 1.0 + 0.12 * maxf(0.0, sin(t * 6.0 + k * 1.2))
		_chevrons[k].scale = Vector3(s, 1.0, s)


func _on_body_entered(body: Node3D) -> void:
	if body is Ball:
		body.call_deferred("boost", global_basis.z.normalized(), speed)
		get_tree().call_group("game", "on_boost", global_position)

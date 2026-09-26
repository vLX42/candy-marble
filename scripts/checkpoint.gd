class_name Checkpoint
extends Area3D
## Candy gate across the track. Rolling through it moves the ball's respawn
## point here. The banner turns lemon once it's active.

@export var width := 8.0

var _active := false
var _banner: MeshInstance3D


func _ready() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 2.0, 1.0)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 1.0
	add_child(cs)
	body_entered.connect(_on_body_entered)
	if not has_node("Model"):
		_build_placeholder()


func _build_placeholder() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * width * 0.5
		Palette.add_mesh(self, Palette.cylinder(0.1, 0.12, 1.8), Palette.CREAM, Vector3(x, 0.9, 0))
		Palette.add_mesh(self, Palette.sphere(0.18), Palette.PINK, Vector3(x, 1.85, 0))
	_banner = Palette.add_mesh(self, Palette.box(Vector3(width, 0.22, 0.06)), Palette.LILAC, Vector3(0, 1.62, 0))


func _on_body_entered(body: Node3D) -> void:
	if body is Rival:
		body.spawn_point = global_position + Vector3.UP * 0.6 + global_basis.x * 1.2
		return
	if not body is Ball or _active:
		return
	_active = true
	body.spawn_point = global_position + Vector3.UP * 0.6
	if _banner:
		_banner.material_override = Palette.candy(Palette.LEMON)
	get_tree().call_group("game", "on_checkpoint", global_position)

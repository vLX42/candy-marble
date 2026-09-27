class_name Secret
extends Area3D
## Easter egg marker: a slowly spinning golden sprinkle. Touch it and the game
## tells you that you found a secret (once per level run).

var _found := false
var _star: Node3D
var _t := 0.0


func _ready() -> void:
	var shape := SphereShape3D.new()
	shape.radius = 1.4
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.6
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_star = Node3D.new()
	add_child(_star)
	for k in 5:
		var arm := MeshInstance3D.new()
		arm.mesh = Palette.cylinder(0.08, 0.08, 0.7)
		arm.material_override = Palette.candy(Color("#F7D66B"), 0.2)
		arm.rotation_degrees = Vector3(90, 0, k * 72.0)
		arm.position = Vector3(0, 1.1, 0)
		_star.add_child(arm)
	var core := MeshInstance3D.new()
	core.mesh = Palette.sphere(0.22)
	core.material_override = Palette.candy(Color("#FFF4E0"), 0.2)
	core.position = Vector3(0, 1.1, 0)
	_star.add_child(core)


func _process(delta: float) -> void:
	_t += delta
	_star.rotation.y = _t * 1.5
	_star.position.y = sin(_t * 2.0) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if _found or not (body is Ball) or body is Rival or body is Steelie:
		return
	_found = true
	get_tree().call_group("game", "cheer", "SECRET!", global_position + Vector3.UP * 2.0)
	get_tree().call_group("game", "play_sound", "rush", global_position)
	get_tree().call_group("game", "show_message", "You found the secret island!\nThe cannon knows a shortcut.", 4.0)
	_star.visible = false

class_name Bumper
extends StaticBody3D
## Pinball pop bumper (lemon mushroom). Knocks the ball away from its center.

@export var strength := 11.0
@export var radius := 0.8

var _visual: Node3D


func _ready() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.2
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.6
	add_child(cs)

	var area := Area3D.new()
	var ashape := CylinderShape3D.new()
	ashape.radius = radius + 0.2
	ashape.height = 1.4
	var acs := CollisionShape3D.new()
	acs.shape = ashape
	acs.position.y = 0.6
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)

	if has_node("Model"):
		_visual = get_node("Model")
	else:
		_visual = Palette.load_model(self, "bumper")
		if _visual == null:
			_visual = _build_placeholder()


func _build_placeholder() -> Node3D:
	var v := Node3D.new()
	add_child(v)
	Palette.add_mesh(v, Palette.cylinder(0.35, 0.45, 0.8), Palette.CREAM, Vector3(0, 0.4, 0))
	Palette.add_mesh(v, Palette.sphere(radius, 0.8), Palette.LEMON, Vector3(0, 0.95, 0))
	for i in 12:
		var a := TAU * i / 12.0
		Palette.add_mesh(v, Palette.sphere(0.06), Palette.CREAM,
			Vector3(cos(a) * radius * 0.75, 1.2, sin(a) * radius * 0.75))
	return v


func _on_body_entered(body: Node3D) -> void:
	if not body is Ball:
		return
	var away := body.global_position - global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.RIGHT
	body.call_deferred("kick", away.normalized(), strength)
	get_tree().call_group("game", "on_bump", global_position)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3(1.25, 0.8, 1.25), 0.06)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

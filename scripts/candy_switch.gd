class_name CandySwitch
extends Area3D
## Floor button: roll over it to open every gate on its channel. `open_time`
## (seconds, 0 = for good) overrides the gates' own timer. The HUD counts
## down timed gates.

@export var channel := "a"
@export var open_time := 0.0

var _cap: Node3D
var _cool := 0.0


func _ready() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 0.8
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.4
	add_child(cs)
	body_entered.connect(_on_body_entered)
	Palette.add_mesh(self, Palette.cylinder(0.85, 0.95, 0.12), Palette.CREAM, Vector3(0, 0.06, 0))
	_cap = Palette.add_mesh(self, Palette.cylinder(0.62, 0.7, 0.2), Palette.CORAL, Vector3(0, 0.2, 0))
	Palette.add_mesh(_cap, Palette.cylinder(0.3, 0.3, 0.05), Palette.LEMON, Vector3(0, 0.11, 0))


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)


func _on_body_entered(body: Node3D) -> void:
	if not (body is Ball) or body is Rival or body is Steelie or _cool > 0.0:
		return
	_cool = 1.0
	get_tree().call_group("gate_" + channel, "trigger", open_time)
	get_tree().call_group("game", "on_switch", open_time)
	var tw := create_tween()
	tw.tween_property(_cap, "position:y", 0.08, 0.08)
	tw.tween_interval(0.35)
	tw.tween_property(_cap, "position:y", 0.2, 0.2).set_trans(Tween.TRANS_BACK)

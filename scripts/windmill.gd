class_name Windmill
extends AnimatableBody3D
## Licorice Windmill: a spinning candy-cane arm. It doesn't pop the ball, it
## swats it around, so time your pass. Counts as a pinball hit for the sugar
## meter.

@export var spin := 1.2          # radians per second (negative spins the other way)
@export var arm_length := 3.8    # from the hub to the tip

const ARM_Y := 0.9
const MODEL_HALF_LENGTH := 4.5

var _swat_cooldown := 0.0


func _ready() -> void:
	sync_to_physics = true
	var shape := BoxShape3D.new()
	shape.size = Vector3(arm_length * 2.0, 0.6, 0.45)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = ARM_Y
	add_child(cs)
	var hub := CylinderShape3D.new()
	hub.radius = 0.4
	hub.height = 1.2
	var hcs := CollisionShape3D.new()
	hcs.shape = hub
	hcs.position.y = 0.6
	add_child(hcs)
	var touch := Area3D.new()
	var ts := BoxShape3D.new()
	ts.size = Vector3(arm_length * 2.0, 0.8, 0.8)
	var tcs := CollisionShape3D.new()
	tcs.shape = ts
	tcs.position.y = ARM_Y
	touch.add_child(tcs)
	add_child(touch)
	touch.body_entered.connect(_on_touch)
	var hub_model := Palette.load_model(self, "windmill_hub")
	var arm := _load_arm()
	if hub_model == null or arm == null:
		Palette.add_mesh(self, Palette.cylinder(0.4, 0.45, 1.2), Palette.CREAM, Vector3(0, 0.6, 0))
		Palette.add_mesh(self, Palette.box(Vector3(arm_length * 2.0, 0.6, 0.45)), Palette.RASPBERRY, Vector3(0, ARM_Y, 0))


func _load_arm() -> Node3D:
	var path := "res://models/windmill_arm.glb"
	if not ResourceLoader.exists(path):
		return null
	var arm: Node3D = load(path).instantiate()
	arm.name = "Arm"
	arm.position.y = ARM_Y
	arm.scale.x = arm_length / MODEL_HALF_LENGTH
	add_child(arm)
	return arm


func _physics_process(delta: float) -> void:
	rotate_y(spin * delta)
	_swat_cooldown -= delta


func _on_touch(body: Node3D) -> void:
	if body is Ball and _swat_cooldown <= 0.0:
		_swat_cooldown = 0.6
		get_tree().call_group("game", "on_bump", body.global_position)
		get_tree().call_group("game", "cheer", "SWAT!", body.global_position + Vector3.UP * 1.8)

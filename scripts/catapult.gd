class_name Catapult
extends Node3D
## Spoon catapult. Roll into the spoon from behind: the arm dips, then flings
## the ball over the top in a high arc to `target` (world xz).

@export var target := Vector2.ZERO

const PIVOT := Vector3(0, 0.9, 0)
const CUP := Vector3(0, -0.32, -1.8)   # resting ball centre relative to the pivot (models/catapult_arm.glb)
const FLING := 2.2                      # radians the arm swings

var _arm: Node3D
var _busy := false


func _ready() -> void:
	var to := target - Vector2(global_position.x, global_position.z)
	if to.length() > 0.1:
		global_rotation.y = atan2(to.x, to.y)
	# The base is solid so a ball that misses the spoon bumps into it.
	var body := StaticBody3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 1.0, 1.0)
	var bcs := CollisionShape3D.new()
	bcs.shape = bs
	bcs.position.y = 0.5
	body.add_child(bcs)
	add_child(body)
	var catch := Area3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(1.5, 1.2, 1.4)
	var ccs := CollisionShape3D.new()
	ccs.shape = cs
	ccs.position = PIVOT + CUP + Vector3.UP * 0.2
	catch.add_child(ccs)
	add_child(catch)
	catch.body_entered.connect(_on_enter)

	if Palette.load_model(self, "catapult_base") == null:
		Palette.add_mesh(self, Palette.box(Vector3(1.6, 0.9, 0.9)), Palette.LEMON, Vector3(0, 0.45, 0))
	_arm = Node3D.new()
	_arm.position = PIVOT
	add_child(_arm)
	if Palette.load_model(_arm, "catapult_arm") == null:
		Palette.add_mesh(_arm, Palette.box(Vector3(0.25, 0.2, 1.8)), Palette.CORAL, Vector3(0, -0.2, -0.9), Vector3(-12, 0, 0))
		Palette.add_mesh(_arm, Palette.cylinder(0.7, 0.55, 0.3), Palette.CREAM, CUP)


func _cup_world(angle: float) -> Vector3:
	var rotated := Basis(Vector3.RIGHT, angle) * CUP
	return to_global(PIVOT + rotated)


func _on_enter(ball: Node3D) -> void:
	if not ball is Ball or _busy or not ball.alive:
		return
	_busy = true
	var b: Ball = ball
	b.call_deferred("hold_at", _cup_world(0.0))
	get_tree().call_group("game", "on_boost", global_position)
	# Dip...
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: _set_arm(a, b), 0.0, -0.18, 0.25)
	# ...fling...
	tw.tween_method(func(a: float) -> void: _set_arm(a, b), -0.18, FLING, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _release(b))
	# ...and settle back.
	tw.tween_interval(0.5)
	tw.tween_method(func(a: float) -> void: _set_arm(a, null), FLING, 0.0, 0.8).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func() -> void: _busy = false)


func _set_arm(angle: float, carry: Ball) -> void:
	_arm.rotation.x = angle
	if carry and is_instance_valid(carry) and carry.freeze:
		carry.global_position = _cup_world(angle)


func _release(b: Ball) -> void:
	if not is_instance_valid(b) or not b.alive:
		return
	var start := _cup_world(FLING)
	var game := get_tree().get_first_node_in_group("game")
	var dest := Vector3(target.x, game.level.height(target.x, target.y) + 0.6, target.y)
	var flat := Vector2(dest.x - start.x, dest.z - start.z)
	var t := clampf(flat.length() / 6.5, 1.1, 2.4)
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var v := Vector3(flat.x / t, (dest.y - start.y + 0.5 * g * t * t) / t, flat.y / t)
	b.fire_from(start, v)
	get_tree().call_group("game", "cheer", "WHEEE!", start + Vector3.UP * 1.0)
	get_tree().call_group("game", "charge", 1.0, start)

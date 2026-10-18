class_name Decor
extends StaticBody3D
## Decoration (Blender models). Lollipops, trees and bears are solid; the
## floating candies are pickups with a random effect (main.gd candy()) that
## come back after a while.

const RESPAWN := 15.0

## Model name in models/. lollipop, tree and bear stand on the ground; the
## candies (gumdrop, golden_cupcake, heart_candy, ...) float and spin.
@export var kind := "lollipop"

var _floaty: Node3D
var _eaten := false
var _t := 0.0


func _ready() -> void:
	if kind not in ["lollipop", "tree", "bear"]:
		# Floating candy: no wall, a pickup (see main.gd candy()).
		var m := Palette.load_model(self, kind)
		if m:
			m.scale = Vector3.ONE * 1.6
			m.position.y = 1.0
			_floaty = m
			_t = randf() * TAU
		var area := Area3D.new()
		var ball_shape := SphereShape3D.new()
		ball_shape.radius = 0.75
		var acs := CollisionShape3D.new()
		acs.shape = ball_shape
		acs.position.y = 0.7
		area.add_child(acs)
		add_child(area)
		area.body_entered.connect(_on_touched)
		return
	var shape := CylinderShape3D.new()
	shape.radius = 0.12 if kind == "lollipop" else 0.45
	shape.height = 1.4
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.7
	add_child(cs)
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


func _on_touched(body: Node3D) -> void:
	if _eaten or not body is Ball or body is Rival:
		return
	_eaten = true
	get_tree().call_group("game", "candy", kind, global_position + Vector3.UP, body)
	if _floaty:
		var tw := create_tween()
		tw.tween_property(_floaty, "scale", Vector3.ONE * 0.01, 0.15)
	await get_tree().create_timer(RESPAWN, false).timeout
	if _floaty:
		var tw := create_tween()
		tw.tween_property(_floaty, "scale", Vector3.ONE * 1.6, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_eaten = false

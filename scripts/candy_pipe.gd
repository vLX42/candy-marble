class_name CandyPipe
extends Node3D
## Marble Madness pipe: roll into the funnel and the marble shoots through a
## hidden pipe and pops out of the spout at `target` (world x, z), rolling on
## in the same direction it went in.

@export var target := Vector2.ZERO
@export var speed := 6.0
@export var tint := Color(0, 0, 0, 0)

var _busy := false
var _spout: Node3D


func _ready() -> void:
	var col := tint if tint.a > 0.0 else Palette.LILAC
	# Funnel: a wide cup narrowing into the ground, with a candy stripe rim.
	Palette.add_mesh(self, Palette.cylinder(1.05, 0.55, 0.9), col, Vector3(0, 0.45, 0))
	Palette.add_mesh(self, Palette.torus(0.95, 1.12), Palette.CREAM, Vector3(0, 0.9, 0))
	Palette.add_mesh(self, Palette.cylinder(0.62, 0.62, 0.05), Color("#2E1A14"), Vector3(0, 0.89, 0))
	var mouth := Area3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.8
	shape.height = 1.2
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.6
	mouth.add_child(cs)
	add_child(mouth)
	mouth.body_entered.connect(_on_enter)
	# Spout at the far end.
	_spout = Node3D.new()
	_spout.top_level = true
	add_child(_spout)
	var level: LevelBase = _level()
	var y := level.height(target.x, target.y) if level else global_position.y
	_spout.global_position = Vector3(target.x, y, target.y)
	var dir := _exit_dir()
	_spout.global_rotation.y = atan2(dir.x, dir.z)
	var elbow := Palette.add_mesh(_spout, Palette.cylinder(0.6, 0.6, 1.4), col, Vector3(0, 0.7, -0.4))
	elbow.rotation_degrees.x = 30.0
	Palette.add_mesh(_spout, Palette.torus(0.5, 0.68), Palette.CREAM, Vector3(0, 0.55, 0.2))


func _level() -> LevelBase:
	var game := get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	return game.level if game else null


func _exit_dir() -> Vector3:
	var d := Vector3(target.x - global_position.x, 0.0, target.y - global_position.z)
	return d.normalized() if d.length() > 0.1 else global_basis.z


func _on_enter(body: Node3D) -> void:
	if _busy or not (body is Ball) or not body.alive:
		return
	_busy = true
	body.call_deferred("hold_at", global_position + Vector3(0, 0.2, 0))
	body.visible = false
	get_tree().call_group("game", "play_sound", "whoosh", global_position)
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(body) and body.alive:
		var dir := _exit_dir()
		body.visible = true
		body.fire_from(_spout.global_position + Vector3(0, 0.7, 0) + dir * 0.7, dir * speed + Vector3.UP * 1.0)
		get_tree().call_group("game", "play_sound", "boing", _spout.global_position)
	await get_tree().create_timer(0.5).timeout
	_busy = false

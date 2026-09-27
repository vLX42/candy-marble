extends SceneTree
## Screenshots of the in-game HUD in its main states (needs a window):
##   godot --always-on-top -s tests/hud_shots.gd
## Saves to tests/shots/hud_<name>.png

var main: Node3D
var t := 0.0
var step := 0
var steps := [
	["intro", 1.0, func(): main.start_level(0)],
	["playing", 3.5, func(): pass],
	["checkpoint", 0.4, func(): main.on_checkpoint(Vector3.ZERO)],
	["rush", 0.6, func():
		for i in 6: main.charge(1.0, main.ball.global_position)],
	["goal", 1.5, func(): _put(main.ball, main.ground(main.level.goal) + Vector3.UP * 0.8)],
	["race_intro", 1.0, func(): main.start_level(3)],
	["race_playing", 3.5, func(): pass],
	["race_lost", 1.5, func(): _put(main.rival, main.ground(main.level.goal) + Vector3.UP * 0.8)],
	["race_second", 1.5, func(): _put(main.ball, main.ground(main.level.goal) + Vector3.UP * 0.8)],
]


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.auto_advance = false
	main.save_scores = false
	main.countdown = false
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute("res://tests/shots")


func _process(delta: float) -> bool:
	if t == 0.0 and step < steps.size():
		steps[step][2].call()
	t += delta
	if step >= steps.size():
		quit()
		return false
	if t >= steps[step][1]:
		RenderingServer.force_draw()
		root.get_viewport().get_texture().get_image().save_png("res://tests/shots/hud_%s.png" % steps[step][0])
		step += 1
		t = 0.0
	return false


func _put(body: RigidBody3D, pos: Vector3) -> void:
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, pos))
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)

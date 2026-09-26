class_name LoopTrack
extends StaticBody3D
## Loop-the-loop from models/loop.glb (blender/build_assets.py). The ball enters
## along local +z at x = 0 and leaves 2.1 units to the local +x side.
## Needs about 9+ speed at the entry, so put a booster in front of it.

const EXIT_SHIFT := 2.1
## The entry launches the ball at this speed so it always makes it round.
const LAUNCH_SPEED := 13.0


func _ready() -> void:
	var model := Palette.load_model(self, "loop")
	if model == null:
		push_warning("models/loop.glb missing, run blender/build_assets.py")
		return
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var shape := mi.mesh.create_trimesh_shape()
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = global_transform.affine_inverse() * mi.global_transform
		add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	physics_material_override = pm

	# Entry launcher: lines the ball up with the lane and shoots it through.
	var entry := Area3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 1.6, 1.0)
	var ecs := CollisionShape3D.new()
	ecs.shape = box
	ecs.position = Vector3(0, 0.8, -3.6)
	entry.add_child(ecs)
	add_child(entry)
	entry.body_entered.connect(_on_entry)


func _on_entry(body: Node3D) -> void:
	if body is Ball:
		body.call_deferred("align_to_lane", global_position, global_basis.z.normalized(), LAUNCH_SPEED)
		get_tree().call_group("game", "on_boost", global_position)
		get_tree().call_group("game", "cheer", "LOOP!", global_position + Vector3.UP * 4.8)

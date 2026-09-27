class_name Chute
extends StaticBody3D
## Swoopy S-curve candy chute (models/chute.glb from blender/assets_pinball.py).
## Travel is local +z: the high end is at z = -4 (floor 1.98 above the origin),
## the low end at z = +4, level with the origin. A guide at the mouth lines the
## ball up with the channel so it drops in cleanly.


func _ready() -> void:
	var model := Palette.load_model(self, "chute")
	if model == null:
		push_warning("models/chute.glb missing, run blender/assets_pinball.py")
		return
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var shape := mi.mesh.create_trimesh_shape()
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = global_transform.affine_inverse() * mi.global_transform
		add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	physics_material_override = pm

	var guide := Area3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.4, 1.2)
	var gcs := CollisionShape3D.new()
	gcs.shape = box
	gcs.position = Vector3(0, 2.6, -4.9)
	guide.add_child(gcs)
	add_child(guide)
	guide.body_entered.connect(func(b: Node3D) -> void:
		if b is Ball:
			b.call_deferred("align_to_lane", to_global(Vector3(0, 0, -4)), global_basis.z.normalized(), 3.0))

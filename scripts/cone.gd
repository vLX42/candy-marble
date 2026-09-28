class_name Cone
extends StaticBody3D
## A candy cone: a tall spike the marble bounces off, like the Marble Madness
## pyramids. It's a solid body, not part of the ground, so nothing rolls up
## it (and Silly Race slopes don't pull the marble into it).


func _ready() -> void:
	var mesh := Palette.cylinder(0.03, 0.75, 2.4)
	Palette.add_mesh(self, mesh, Palette.CREAM, Vector3(0, 1.2, 0))
	Palette.add_mesh(self, Palette.torus(0.5, 0.64), Palette.PINK, Vector3(0, 0.55, 0))
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_convex_shape()
	cs.position.y = 1.2
	add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.4
	physics_material_override = pm

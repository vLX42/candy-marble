class_name GoalPad
extends Goal
## The Marble Madness finish: a raised checkered GOAL pad with flags at the
## corners. Roll onto it to finish. `size` is the pad in tiles.

@export var size := Vector2(3, 2)


func _ready() -> void:
	var w := size.x * LevelBase.TILE
	var d := size.y * LevelBase.TILE
	var shape := BoxShape3D.new()
	shape.size = Vector3(w - 0.4, 0.8, d - 0.4)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.4
	add_child(cs)
	body_entered.connect(_on_body_entered)
	# Checker slab: cream and blueberry squares, half a tile each.
	var n := Vector2i(int(size.x * 4), int(size.y * 4))
	var cell := Vector2(w / n.x, d / n.y)
	var mm_light := MultiMesh.new()
	var mm_dark := MultiMesh.new()
	var tile_mesh := Palette.box(Vector3(cell.x - 0.02, 0.06, cell.y - 0.02))
	for mm in [mm_light, mm_dark]:
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tile_mesh
	var light: Array[Transform3D] = []
	var dark: Array[Transform3D] = []
	for i in n.x:
		for j in n.y:
			var p := Vector3(-w * 0.5 + (i + 0.5) * cell.x, 0.04, -d * 0.5 + (j + 0.5) * cell.y)
			(light if (i + j) % 2 == 0 else dark).append(Transform3D(Basis.IDENTITY, p))
	for pair in [[mm_light, light, Palette.CREAM], [mm_dark, dark, Color("#4A5BD6")]]:
		var mm: MultiMesh = pair[0]
		var list: Array = pair[1]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = Palette.candy(pair[2], 0.4)
		add_child(mi)
	var word := Label3D.new()
	word.text = "GOAL"
	word.font = CandyText.FONT_BOLD
	word.font_size = 200
	word.pixel_size = 0.01 * minf(w, d) / 4.0
	word.modulate = Color("#2B2B8C")
	word.outline_modulate = Palette.CREAM
	word.outline_size = 24
	word.rotation_degrees = Vector3(-90, 0, 0)
	word.position.y = 0.09
	add_child(word)
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			var base := Vector3(cx * (w * 0.5 - 0.2), 0, cz * (d * 0.5 - 0.2))
			Palette.add_mesh(self, Palette.cylinder(0.05, 0.05, 1.6), Palette.WHITE, base + Vector3(0, 0.8, 0))
			for k in 4:
				var col := Color("#2B2B8C") if (k % 2 == 0) else Palette.CREAM
				Palette.add_mesh(self, Palette.box(Vector3(0.22, 0.22, 0.03)), col,
					base + Vector3(0.12 + (k % 2) * 0.22, 1.45 - (k / 2) * 0.22, 0))

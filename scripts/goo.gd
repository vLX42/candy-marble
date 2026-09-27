class_name Goo
extends Area3D
## Sour apple goo pool (Marble Madness's acid): one tile of bubbling green
## slime. Rolling into it pops the marble, Sugar Rush or not.

var _bubbles: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.5, 1.2)
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.position.y = 0.3
	add_child(cs)
	body_entered.connect(_on_body_entered)
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.96, 0.1, 1.96)
	slab.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#9BE35A", 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color("#6FD13A")
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 0.15
	mat.clearcoat_enabled = true
	slab.material_override = mat
	slab.position.y = 0.05
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slab)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	for k in 4:
		var b := MeshInstance3D.new()
		b.mesh = Palette.sphere(rng.randf_range(0.08, 0.16))
		b.material_override = mat
		b.position = Vector3(rng.randf_range(-0.7, 0.7), 0.1, rng.randf_range(-0.7, 0.7))
		b.set_meta("phase", rng.randf() * TAU)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(b)
		_bubbles.append(b)


func _process(delta: float) -> void:
	_t += delta
	for b in _bubbles:
		var u := fposmod(_t * 0.7 + b.get_meta("phase") / TAU, 1.0)
		b.position.y = 0.08 + u * 0.25
		b.scale = Vector3.ONE * (1.0 - u)


func _on_body_entered(body: Node3D) -> void:
	if body is Ball and body.alive:
		get_tree().call_group("game", "cheer", "SOUR!", global_position + Vector3.UP * 1.4)
		body.die()

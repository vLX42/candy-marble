class_name Slime
extends Area3D
## Marble Madness acid: a bubbling blob of sour goo that slides back and forth
## (start .. start + travel) and melts the marble it touches.

@export var travel := Vector3(0, 0, 6)
@export var period := 5.0
@export_range(0.0, 1.0) var phase := 0.0
@export var tint := Color(0, 0, 0, 0)

var reach := 1.1
var _origin := Vector3.ZERO
var _t := 0.0
var _blob: Node3D


func _ready() -> void:
	add_to_group("enemy")
	_origin = global_position
	_t = phase * period
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.3
	add_child(cs)
	body_entered.connect(_on_hit)
	var col := tint if tint.a > 0.0 else Color("#9BE35A")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col.darkened(0.2)
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 0.1
	mat.clearcoat_enabled = true
	_blob = Node3D.new()
	add_child(_blob)
	for p in [Vector3(0, 0.25, 0), Vector3(0.35, 0.18, 0.2), Vector3(-0.3, 0.16, -0.25), Vector3(0.1, 0.2, -0.4)]:
		var m := MeshInstance3D.new()
		m.mesh = Palette.sphere(0.55 if p == Vector3(0, 0.25, 0) else 0.32, 0.6)
		m.material_override = mat
		m.position = p
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_blob.add_child(m)


func offset_at(time: float) -> Vector3:
	var u := 0.5 - 0.5 * cos(time / period * TAU)
	return travel * u


func _physics_process(delta: float) -> void:
	_t += delta
	global_position = _origin + offset_at(_t)
	var wob := 1.0 + 0.08 * sin(_t * 7.0)
	_blob.scale = Vector3(wob, 2.0 - wob, wob)


func position_at(ahead: float) -> Vector3:
	return _origin + offset_at(_t + ahead)


func threat_at(ahead: float) -> Variant:
	return position_at(ahead)


func _on_hit(body: Node3D) -> void:
	if body is Ball and body.alive:
		if body.silly:
			return
		get_tree().call_group("game", "cheer", "SOUR!", global_position + Vector3.UP * 1.4)
		body.melt()

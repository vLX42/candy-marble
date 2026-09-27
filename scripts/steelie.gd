class_name Steelie
extends Ball
## Marble Madness's Black Steelie: a heavy dark-metal marble that rolls after
## you when you come near and shoves you, hoping you go over the edge. It
## doesn't pop you; the fall does. It gives up past its leash and rolls home.

@export var sense := 9.0
@export var leash := 10.0
@export var speed := 4.2
## Colour of the metal (dark steel by default).
@export var shade := Color("#3A3F4B")

const SHOVE := 5.5
var _home := Vector3.ZERO
var _shove_cool := 0.0


func _ready() -> void:
	# Placed at floor height like other monsters: sit on the floor, not in it.
	position.y += radius + 0.1
	model_name = "rival"
	super._ready()
	remove_from_group("ball")
	add_to_group("steelie")
	add_to_group("enemy")
	mass = 1.6
	max_speed = speed
	push_force = 14.0
	_home = global_position
	body_entered.connect(_on_body_entered)
	# Shiny dark metal instead of licorice.
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m == null:
				continue
			var d := m.duplicate() as BaseMaterial3D
			d.albedo_color = shade if m.albedo_color.v < 0.5 else shade.lightened(0.55)
			d.metallic = 0.85
			d.roughness = 0.18
			mi.set_surface_override_material(s, d)


func _physics_process(delta: float) -> void:
	_shove_cool -= delta
	super._physics_process(delta)


func _steer_dir() -> Vector3:
	if not alive:
		return Vector3.ZERO
	var target := _home
	for b in get_tree().get_nodes_in_group("ball"):
		if b is Ball and b.alive and not (b is Rival) and not (b is Steelie):
			var d: float = _flat(b.global_position).distance_to(_flat(_home))
			if d < leash and _flat(b.global_position).distance_to(_flat(global_position)) < sense:
				target = b.global_position
	var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if to.length() < 0.4:
		return Vector3.ZERO
	return to.normalized()


## Look-ahead for the level bot, like the other monsters.
func threat_at(ahead: float) -> Variant:
	return global_position + linear_velocity * ahead


var reach := 1.1


func _on_body_entered(body: Node) -> void:
	if not (body is Ball) or body is Steelie or _shove_cool > 0.0:
		return
	_shove_cool = 0.4
	var away: Vector3 = body.global_position - global_position
	away.y = 0.0
	away = away.normalized()
	body.apply_central_impulse(away * SHOVE + Vector3.UP * 0.8)
	get_tree().call_group("game", "on_bump", global_position)


func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

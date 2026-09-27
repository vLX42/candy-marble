class_name Hopper
extends AnimatableBody3D
## Gumdrop Hopper: bounces along `travel` and back in `hops` arcs per leg.
## Slip underneath while it's in the air; touching it pops the ball.

@export var travel := Vector3(0, 0, 6)
@export var period := 4.0          # full there-and-back, seconds
@export var hops := 3
@export var hop_height := 1.8
@export_range(0.0, 1.0) var phase := 0.0
## Hit distance for the AI's look-ahead.
var reach := 1.15

var _origin := Vector3.ZERO
var _time := 0.0
var _visual: Node3D


func _ready() -> void:
	add_to_group("enemy")
	sync_to_physics = true
	_origin = global_position
	_time = phase * period
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.95, 0.95, 0.95)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.48
	add_child(cs)
	var hit := Area3D.new()
	var hs := BoxShape3D.new()
	hs.size = Vector3(1.05, 1.0, 1.05)
	var hcs := CollisionShape3D.new()
	hcs.shape = hs
	hcs.position.y = 0.5
	hit.add_child(hcs)
	add_child(hit)
	hit.body_entered.connect(_on_hit)
	_visual = Palette.load_model(self, "enemy_hopper")
	if _visual == null:
		_visual = Node3D.new()
		add_child(_visual)
		Palette.add_mesh(_visual, Palette.sphere(0.5, 0.85), Palette.RASPBERRY, Vector3(0, 0.45, 0))
		for ex in [-0.18, 0.18]:
			Palette.add_mesh(_visual, Palette.sphere(0.07), Palette.INK, Vector3(ex, 0.6, 0.45))


func offset_at(time: float) -> Vector3:
	var u := fposmod(time / period, 1.0) * 2.0
	var leg := u if u < 1.0 else 2.0 - u
	var hop := absf(sin(PI * hops * leg))
	return travel * leg + Vector3.UP * hop_height * hop


func _physics_process(delta: float) -> void:
	_time += delta
	var o := offset_at(_time)
	global_position = _origin + o
	# Squash on the ground, stretch in the air, face the way it's hopping.
	var air := clampf(o.y / 0.5, 0.0, 1.0)
	_visual.scale = Vector3(lerpf(1.15, 0.92, air), lerpf(0.78, 1.1, air), lerpf(1.15, 0.92, air))
	var ahead := offset_at(_time + 0.05) - o
	ahead.y = 0.0
	if ahead.length() > 0.001:
		_visual.rotation.y = atan2(ahead.x, ahead.z)


func position_at(ahead: float) -> Vector3:
	return _origin + offset_at(_time + ahead)


## Where it's dangerous `ahead` seconds from now (null while high in the air).
func threat_at(ahead: float) -> Variant:
	var o := offset_at(_time + ahead)
	return _origin + o if o.y < 0.95 else null


func _on_hit(body: Node3D) -> void:
	if body is Ball:
		if body.rush:
			get_tree().call_group("game", "cheer", "WHOOSH!", global_position + Vector3.UP * 2.0)
			return
		body.die()

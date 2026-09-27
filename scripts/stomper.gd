class_name Stomper
extends AnimatableBody3D
## Marshmallow Stomper: hangs up high, slams down, rests, rises again.
## Roll under while it's up. Getting caught underneath pops the ball; bumping
## its side when it's down is fine.

@export var period := 3.0
@export var lift := 2.4
@export_range(0.0, 1.0) var phase := 0.0
var reach := 1.45

var _origin := Vector3.ZERO
var _time := 0.0
var _was_down := false


func _ready() -> void:
	add_to_group("enemy")
	sync_to_physics = true
	_origin = global_position
	_time = phase * period
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.4, 1.9)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.7
	add_child(cs)
	# Kill zone: a slab under the block, narrower than the block.
	var hit := Area3D.new()
	var hs := BoxShape3D.new()
	hs.size = Vector3(1.4, 0.45, 1.4)
	var hcs := CollisionShape3D.new()
	hcs.shape = hs
	hcs.position.y = 0.1
	hit.add_child(hcs)
	add_child(hit)
	hit.body_entered.connect(_on_hit)
	if Palette.load_model(self, "enemy_stomper") == null:
		Palette.add_mesh(self, Palette.box(Vector3(1.9, 1.4, 1.9)), Palette.PINK.darkened(0.1), Vector3(0, 0.7, 0))
		Palette.add_mesh(self, Palette.box(Vector3(1.95, 0.25, 1.95)), Palette.CREAM, Vector3(0, 1.0, 0))


## Height of the block's bottom above the ground at `time`.
func height_at(time: float) -> float:
	var u := fposmod(time / period, 1.0)
	if u < 0.45:
		return lift
	if u < 0.52:
		var k := (u - 0.45) / 0.07
		return lift * (1.0 - k * k)
	if u < 0.72:
		return 0.0
	return lift * smoothstep(0.0, 1.0, (u - 0.72) / 0.28)


func _physics_process(delta: float) -> void:
	_time += delta
	var h := height_at(_time)
	global_position = _origin + Vector3.UP * h
	var down := h < 0.01
	if down and not _was_down:
		get_tree().call_group("game", "on_stomp", global_position)
	_was_down = down


func position_at(ahead: float) -> Vector3:
	return _origin + Vector3.UP * height_at(_time + ahead)


func threat_at(ahead: float) -> Variant:
	return _origin if height_at(_time + ahead) < 1.1 else null


func _on_hit(body: Node3D) -> void:
	if body is Ball:
		if body.rush:
			get_tree().call_group("game", "cheer", "WHOOSH!", global_position + Vector3.UP * 2.5)
			return
		body.die()

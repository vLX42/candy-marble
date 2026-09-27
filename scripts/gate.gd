class_name Gate
extends AnimatableBody3D
## Candy gate: a striped barrier that sinks into the floor when its switch is
## pressed (or its pinball target bank is cleared). With `bridge` it works the
## other way round: a plank hidden below that rises to fill a gap.
## `open_time` > 0 closes it again after that many seconds.

@export var channel := "a"
## Footprint in tiles: x along the gate's local x, y along its local z.
@export var size := Vector2(1, 4)
@export var height := 1.3
@export var open_time := 0.0
@export var bridge := false

var is_open := false
var _base_y := 0.0
var _close_left := 0.0
var _shape: CollisionShape3D
var _lamp: MeshInstance3D


func _ready() -> void:
	add_to_group("gate")
	add_to_group("gate_" + channel)
	sync_to_physics = true
	_base_y = position.y
	var w := size.x * LevelBase.TILE
	var d := size.y * LevelBase.TILE
	var h := height if not bridge else 0.5
	var box := BoxShape3D.new()
	box.size = Vector3(w - 0.05, h, d - 0.05)
	_shape = CollisionShape3D.new()
	_shape.shape = box
	_shape.position.y = h * 0.5 if not bridge else -0.25
	add_child(_shape)
	if bridge:
		var plank := Palette.add_mesh(self, Palette.box(Vector3(w - 0.05, 0.5, d - 0.05)), Palette.LEMON, Vector3(0, -0.25, 0))
		plank.name = "Plank"
		for k in int(maxf(size.x, size.y)):
			var stripe := Vector3(0, 0.01, 0)
			if size.x >= size.y:
				stripe.x = -w * 0.5 + LevelBase.TILE * (k + 0.5)
			else:
				stripe.z = -d * 0.5 + LevelBase.TILE * (k + 0.5)
			Palette.add_mesh(self, Palette.box(Vector3(0.25 if size.x >= size.y else w - 0.2, 0.04, 0.25 if size.x < size.y else d - 0.2)),
				Palette.CORAL, stripe)
		position.y = _base_y - 6.0
		visible = false
		_shape.disabled = true
	else:
		# Candy-cane bars with a cream top rail.
		var bars := int(maxf(size.x, size.y) * 3)
		for k in bars:
			var p := Vector3.ZERO
			var t := (k + 0.5) / bars
			if size.x >= size.y:
				p.x = -w * 0.5 + w * t
			else:
				p.z = -d * 0.5 + d * t
			var col := Palette.RASPBERRY if k % 2 == 0 else Palette.CREAM
			Palette.add_mesh(self, Palette.box(Vector3(0.35 if size.x < size.y else 0.5, h, 0.35 if size.x >= size.y else 0.5)),
				col, p + Vector3(0, h * 0.5, 0))
		Palette.add_mesh(self, Palette.box(Vector3(w - 0.1 if size.x >= size.y else 0.45, 0.2, d - 0.1 if size.x < size.y else 0.45)),
			Palette.CREAM, Vector3(0, h + 0.05, 0))
	_lamp = Palette.add_mesh(self, Palette.sphere(0.22), Palette.RASPBERRY, Vector3(0, (h if not bridge else 0.0) + 0.35, 0))


func _process(delta: float) -> void:
	if _close_left > 0.0:
		_close_left -= delta
		if _close_left <= 0.0:
			_set_open(false)


## Called by switches and target banks.
func trigger(duration: float) -> void:
	if duration > 0.0:
		_close_left = duration
	elif open_time > 0.0:
		_close_left = open_time
	_set_open(true)


func _set_open(on: bool) -> void:
	if on == is_open:
		return
	is_open = on
	var up := _base_y
	var gone := _base_y - (height + 0.2) if not bridge else _base_y - 6.0
	var target := gone if (on != bridge) else up
	if bridge and on:
		visible = true
		_shape.disabled = false
		position.y = _base_y - 2.0
	var tw := create_tween()
	tw.tween_property(self, "position:y", target, 0.45).set_trans(Tween.TRANS_BACK if on else Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	if bridge and not on:
		tw.tween_callback(func() -> void:
			visible = false
			_shape.disabled = true)
	(_lamp.material_override as StandardMaterial3D).albedo_color = Palette.MINT if on else Palette.RASPBERRY
	get_tree().call_group("game", "play_sound", "whoosh" if on else "bonk", global_position)

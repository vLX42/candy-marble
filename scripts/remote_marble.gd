class_name RemoteMarble
extends AnimatableBody3D
## Another player's marble in an online race. It goes where the network says
## (smoothed: shown a tenth of a second behind, between the last two updates)
## and it's solid: it pushes your marble when you collide. It doesn't trigger
## switches, goals or monsters; those are for your own marble.

const DELAY := 0.1          # seconds behind the newest update, for smooth motion
const MAX_GUESS := 0.25     # how far ahead to guess when updates are late
const TELEPORT := 6.0       # a jump this big is a respawn: snap, don't glide

var player_id := 0
var progress := 0.0
var alive := true
var _snaps: Array = []      # [time, position, velocity]
var _clock := 0.0
var _body: Node3D
var _shape: CollisionShape3D


func setup(id: int, player_name: String, color: Color) -> void:
	player_id = id
	name = "Remote%d" % id
	sync_to_physics = true
	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	_shape.shape = sphere
	add_child(_shape)
	_body = Node3D.new()
	add_child(_body)
	var model := Palette.load_model(_body, "ball")
	if model:
		Palette.tint(model, color)
	else:
		Palette.add_mesh(_body, Palette.sphere(0.5), color)
	RemoteMarble.name_tag(self, player_name, color)


## A floating name above a marble (also used on the host's bots).
static func name_tag(parent: Node3D, text: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = "NameTag"
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0022
	label.font = load("res://fonts/fredoka_bold.tres")
	label.font_size = 26
	label.outline_size = 10
	label.modulate = color.lightened(0.25)
	label.outline_modulate = Color("#3A1F2B")
	label.position = Vector3(0, 1.1, 0)
	# Stay upright above a rolling marble.
	label.top_level = parent is RigidBody3D
	parent.add_child(label)
	return label


func push(pos: Vector3, vel: Vector3, is_alive: bool, at_progress: float) -> void:
	progress = at_progress
	if not _snaps.is_empty() and (pos.distance_to(_snaps[-1][1]) > TELEPORT or is_alive != alive):
		_snaps.clear()
		global_position = pos
	alive = is_alive
	visible = is_alive
	_shape.disabled = not is_alive
	_snaps.append([_clock, pos, vel])
	while _snaps.size() > 12:
		_snaps.pop_front()


func _physics_process(delta: float) -> void:
	_clock += delta
	if _snaps.is_empty():
		return
	var t := _clock - DELAY
	var target: Vector3
	if t <= _snaps[0][0]:
		target = _snaps[0][1]
	elif t >= _snaps[-1][0]:
		var last: Array = _snaps[-1]
		target = last[1] + last[2] * minf(t - last[0], MAX_GUESS)
	else:
		target = _snaps[-1][1]
		for k in range(_snaps.size() - 1):
			var a: Array = _snaps[k]
			var b: Array = _snaps[k + 1]
			if t >= a[0] and t <= b[0]:
				target = a[1].lerp(b[1], (t - a[0]) / maxf(b[0] - a[0], 0.0001))
				break
	var step := target - global_position
	global_position = target
	# Roll the model the way it moves.
	var flat := Vector3(step.x, 0.0, step.z)
	if flat.length() > 0.0005:
		var axis := Vector3.UP.cross(flat.normalized())
		_body.rotate(axis, flat.length() / 0.5)

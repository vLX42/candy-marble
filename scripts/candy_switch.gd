class_name CandySwitch
extends Area3D
## Floor button: roll over it to open every gate on its channel.
##
## One switch on a channel: it opens the gates. `open_time` (seconds, 0 = for
## good) overrides the gates' own timer.
##
## Several switches on one channel make a puzzle: every one of them must be
## pressed (they stay down and light up), then the gates open for good.
##   `order` 1, 2, 3...: they must be pressed in that order. A wrong one pops
##                       them all back up.
##   `open_time` > 0:    each press only holds that long; if the set isn't
##                       finished in time they all pop back up (a timed combo).
##
## `toggle` = 1: a lever instead of a button. Every press flips the gates on its
## channel open or shut (gates with `invert` do the opposite), so two bridges
## on one channel can take turns.

@export var channel := "a"
@export var open_time := 0.0
@export var order := 0
@export var toggle := 0

var lit := false
var solved := false
var _cap: Node3D
var _lamp: MeshInstance3D
var _cool := 0.0
var _lit_left := 0.0


func _ready() -> void:
	add_to_group("switch")
	add_to_group("switch_" + channel)
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 0.8
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.4
	add_child(cs)
	body_entered.connect(_on_body_entered)
	Palette.add_mesh(self, Palette.cylinder(0.85, 0.95, 0.12), Palette.CREAM, Vector3(0, 0.06, 0))
	var cap_col := Palette.LILAC if toggle else Palette.CORAL
	_cap = Palette.add_mesh(self, Palette.cylinder(0.62, 0.7, 0.2), cap_col, Vector3(0, 0.2, 0))
	_lamp = Palette.add_mesh(_cap, Palette.cylinder(0.3, 0.3, 0.05), Palette.LEMON, Vector3(0, 0.11, 0))
	# Order pips round the rim: one candy dot per step in the sequence.
	for k in order:
		var a := TAU * k / maxf(order, 1.0) - PI * 0.5
		Palette.add_mesh(self, Palette.sphere(0.11), Palette.INK, Vector3(cos(a) * 0.78, 0.16, sin(a) * 0.78))
	if toggle:
		# A little lever bar across the cap.
		Palette.add_mesh(_cap, Palette.box(Vector3(0.9, 0.08, 0.16)), Palette.CREAM, Vector3(0, 0.15, 0))


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if lit and not solved and _lit_left > 0.0:
		_lit_left -= delta
		if _lit_left <= 0.0:
			_reset_channel("TOO SLOW!")


func _mates() -> Array[CandySwitch]:
	var out: Array[CandySwitch] = []
	for n in get_tree().get_nodes_in_group("switch_" + channel):
		if n is CandySwitch and not n.toggle:
			out.append(n)
	return out


func _on_body_entered(body: Node3D) -> void:
	if not (body is Ball) or body is Rival or body is Steelie or _cool > 0.0:
		return
	_cool = 1.0
	if toggle:
		_bounce()
		get_tree().call_group("gate_" + channel, "flip")
		get_tree().call_group("game", "on_toggle", global_position)
		return
	var mates := _mates()
	if mates.size() <= 1 and order <= 0:
		_bounce()
		get_tree().call_group("gate_" + channel, "trigger", open_time)
		get_tree().call_group("game", "on_switch", open_time)
		return
	if lit or solved:
		return
	var done := 0
	for m in mates:
		if m.lit:
			done += 1
	if order > 0 and order != done + 1:
		_press_down()
		_reset_channel("WRONG ORDER!")
		return
	_set_lit(true)
	done += 1
	if done >= mates.size():
		for m in mates:
			m.solved = true
		get_tree().call_group("gate_" + channel, "trigger", 0.0)
		get_tree().call_group("game", "on_switch", 0.0)
	else:
		get_tree().call_group("game", "on_puzzle_step", done, mates.size(), global_position)


## Pops every switch on the channel back up.
func _reset_channel(why: String) -> void:
	for m in _mates():
		m._set_lit(false)
	get_tree().call_group("game", "on_puzzle_reset", why, global_position)


func _set_lit(on: bool) -> void:
	lit = on
	_lit_left = open_time if on else 0.0
	(_lamp.material_override as StandardMaterial3D).albedo_color = Palette.MINT if on else Palette.LEMON
	var tw := create_tween()
	tw.tween_property(_cap, "position:y", 0.08 if on else 0.2, 0.12 if on else 0.25) \
		.set_trans(Tween.TRANS_QUAD if on else Tween.TRANS_BACK)


func _press_down() -> void:
	var tw := create_tween()
	tw.tween_property(_cap, "position:y", 0.08, 0.08)


func _bounce() -> void:
	var tw := create_tween()
	tw.tween_property(_cap, "position:y", 0.08, 0.08)
	tw.tween_interval(0.35)
	tw.tween_property(_cap, "position:y", 0.2, 0.2).set_trans(Tween.TRANS_BACK)

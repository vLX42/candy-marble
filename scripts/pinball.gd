class_name Pinball
extends Node3D
## One script for the pinball toys, picked by `kind`. Models come from
## blender/assets_pinball.py; each kind has a simple placeholder fallback.
##
##   slingshot   side kicker, kicks the ball along local +z
##   cannon      catches the ball, then fires it in an arc to `target` (world xz)
##   rollover    flush star button, lights up once (all lit = bonus)
##   hoop        ring in the air, fly through it (centre at `height`)
##   target      drop target, falls when hit (whole group down = bonus, resets)
##   spinner     gate with a flag that spins as you pass (points per turn)
##   redirect    speed bank: turns a fast ball to local +z keeping its speed

@export_enum("slingshot", "cannon", "rollover", "hoop", "target", "spinner", "redirect") var kind := "slingshot"
@export var target := Vector2.ZERO
@export var height := 2.2
@export var strength := 10.0

var lit := false
var down := false
var _visual: Node3D
var _blade: Node3D
var _spin := 0.0
var _spin_acc := 0.0
var _busy := false
var _body: StaticBody3D


func _ready() -> void:
	add_to_group("pinball")
	add_to_group("pinball_" + kind)
	match kind:
		"slingshot": _build_slingshot()
		"cannon": _build_cannon()
		"rollover": _build_rollover()
		"hoop": _build_hoop()
		"target": _build_target()
		"spinner": _build_spinner()
		"redirect": _build_redirect()


func _area(size: Vector3, offset: Vector3, callback: Callable) -> Area3D:
	var a := Area3D.new()
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.position = offset
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(func(b: Node3D) -> void:
		if b is Ball:
			callback.call(b))
	return a


func _solid(size: Vector3, offset: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.position = offset
	sb.add_child(cs)
	add_child(sb)
	return sb


func _score(_points: int, label: String = "") -> void:
	if label != "":
		get_tree().call_group("game", "cheer", label, global_position + Vector3.UP * 1.6)


# --- slingshot ------------------------------------------------------------------

func _build_slingshot() -> void:
	_body = _solid(Vector3(1.6, 0.8, 0.8), Vector3(0, 0.4, 0))
	_area(Vector3(1.8, 0.9, 0.5), Vector3(0, 0.45, 0.55), _on_slingshot)
	_visual = Palette.load_model(self, "slingshot")
	if _visual == null:
		_visual = Node3D.new()
		add_child(_visual)
		Palette.add_mesh(_visual, Palette.box(Vector3(1.6, 0.7, 0.8)), Palette.LEMON, Vector3(0, 0.35, 0))
		Palette.add_mesh(_visual, Palette.box(Vector3(1.5, 0.5, 0.12)), Palette.CORAL, Vector3(0, 0.35, 0.44))


func _on_slingshot(ball: Ball) -> void:
	var dir := global_basis.z.normalized()
	ball.call_deferred("kick", dir, strength)
	_score(20)
	get_tree().call_group("game", "on_bump", global_position)
	_squash()


# --- cannon ---------------------------------------------------------------------

func _build_cannon() -> void:
	# Aim the barrel (model +Z) at the target.
	var to := target - Vector2(global_position.x, global_position.z)
	if to.length() > 0.1:
		global_rotation.y = atan2(to.x, to.y)
	_area(Vector3(1.6, 1.4, 1.6), Vector3(0, 0.7, 0), _on_cannon)
	_visual = Palette.load_model(self, "cannon")
	if _visual == null:
		_visual = Node3D.new()
		add_child(_visual)
		Palette.add_mesh(_visual, Palette.cylinder(0.9, 1.0, 0.5), Palette.CREAM, Vector3(0, 0.25, 0))
		Palette.add_mesh(_visual, Palette.torus(0.7, 0.95), Palette.CORAL, Vector3(0, 0.55, 0))


func _on_cannon(ball: Ball) -> void:
	if _busy or not ball.alive:
		return
	_busy = true
	ball.call_deferred("hold_at", to_global(Vector3(0, 0.95, 0.4)))
	get_tree().call_group("game", "on_boost", global_position)
	_squash()
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(ball) or not ball.alive:
		_busy = false
		return
	var start := to_global(Vector3(0, 1.45, 0.8))
	var level: LevelBase = get_tree().get_first_node_in_group("game").level
	var dest := Vector3(target.x, level.height(target.x, target.y) + 0.6, target.y)
	var flat := Vector2(dest.x - start.x, dest.z - start.z)
	var t := clampf(flat.length() / 9.0, 0.8, 1.8)
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var v := Vector3(flat.x / t, (dest.y - start.y + 0.5 * g * t * t) / t, flat.y / t)
	ball.call_deferred("fire_from", start, v)
	_score(100, "BOOM")
	get_tree().call_group("game", "on_bump", global_position)
	await get_tree().create_timer(0.6).timeout
	_busy = false


# --- rollover -------------------------------------------------------------------

func _build_rollover() -> void:
	_area(Vector3(1.4, 0.8, 1.4), Vector3(0, 0.4, 0), _on_rollover)
	_set_rollover_model()


func _set_rollover_model() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Palette.load_model(self, "rollover_star_lit" if lit else "rollover_star")
	if _visual == null:
		_visual = Node3D.new()
		add_child(_visual)
		var m := Palette.add_mesh(_visual, Palette.cylinder(0.6, 0.6, 0.06), Palette.CREAM if lit else Palette.LEMON, Vector3(0, 0.03, 0))
		if lit:
			var mat: StandardMaterial3D = m.material_override
			mat.emission_enabled = true
			mat.emission = Palette.LEMON
			mat.emission_energy_multiplier = 1.5


func _on_rollover(_ball: Ball) -> void:
	if lit:
		return
	lit = true
	call_deferred("_set_rollover_model")
	_score(50)
	for r in get_tree().get_nodes_in_group("pinball_rollover"):
		if not r.lit:
			return
	get_tree().call_group("game", "cheer", "ALL STARS!", global_position + Vector3.UP * 2.0)


# --- hoop -----------------------------------------------------------------------

func _build_hoop() -> void:
	_area(Vector3(2.0, 2.0, 0.6), Vector3(0, height, 0), _on_hoop)
	_visual = Palette.load_model(self, "hoop")
	if _visual == null:
		_visual = Node3D.new()
		add_child(_visual)
		Palette.add_mesh(_visual, Palette.torus(1.1, 1.45), Palette.PINK, Vector3.ZERO, Vector3(90, 0, 0))
	_visual.position.y = height


func _on_hoop(_ball: Ball) -> void:
	if _busy:
		return
	_busy = true
	_score(150, "HOOP!")
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ONE * 1.25, 0.1)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)
	await get_tree().create_timer(1.0).timeout
	_busy = false


# --- drop target ----------------------------------------------------------------

func _build_target() -> void:
	_body = _solid(Vector3(0.9, 0.9, 0.3), Vector3(0, 0.45, 0))
	_area(Vector3(1.0, 1.0, 0.7), Vector3(0, 0.45, 0), _on_target)
	_visual = Palette.load_model(self, "drop_target")
	if _visual == null:
		_visual = Node3D.new()
		add_child(_visual)
		Palette.add_mesh(_visual, Palette.box(Vector3(0.9, 0.9, 0.3)), Palette.LILAC, Vector3(0, 0.45, 0))


func _on_target(_ball: Ball) -> void:
	if down:
		return
	down = true
	_body.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	var tw := create_tween()
	tw.tween_property(_visual, "position:y", -0.95, 0.15)
	_score(75)
	for t in get_tree().get_nodes_in_group("pinball_target"):
		if not t.down:
			return
	get_tree().call_group("game", "cheer", "TARGETS!", global_position + Vector3.UP * 2.0)
	await get_tree().create_timer(2.0).timeout
	get_tree().call_group("pinball_target", "reset_target")


func reset_target() -> void:
	down = false
	_body.process_mode = Node.PROCESS_MODE_INHERIT
	create_tween().tween_property(_visual, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK)


# --- spinner --------------------------------------------------------------------

func _build_spinner() -> void:
	_area(Vector3(2.0, 1.4, 0.6), Vector3(0, 0.7, 0), _on_spinner)
	_visual = Palette.load_model(self, "spinner_frame")
	if _visual == null:
		_visual = Node3D.new()
		add_child(_visual)
		for x in [-1.0, 1.0]:
			Palette.add_mesh(_visual, Palette.cylinder(0.08, 0.08, 1.5), Palette.CREAM, Vector3(x, 0.75, 0))
	var pivot := Node3D.new()
	pivot.position.y = 1.4
	add_child(pivot)
	_blade = Palette.load_model(pivot, "spinner_blade")
	if _blade == null:
		_blade = Node3D.new()
		pivot.add_child(_blade)
		Palette.add_mesh(_blade, Palette.box(Vector3(1.8, 0.9, 0.08)), Palette.LEMON, Vector3(0, -0.45, 0))
	_blade = pivot


func _on_spinner(ball: Ball) -> void:
	_spin = clampf(ball.linear_velocity.length() * 3.0, 6.0, 40.0)


func _process(delta: float) -> void:
	if kind == "spinner" and _spin > 0.0:
		_blade.rotation.x += _spin * delta
		_spin_acc += _spin * delta
		_spin = maxf(0.0, _spin - delta * 6.0)
		while _spin_acc > TAU:
			_spin_acc -= TAU
			_score(15)


# --- redirect bank --------------------------------------------------------------

func _build_redirect() -> void:
	_area(Vector3(2.4, 1.2, 2.4), Vector3(0, 0.6, 0), _on_redirect)
	_visual = Palette.load_model(self, "speed_arrow")
	if _visual == null:
		_visual = Node3D.new()
		add_child(_visual)
		Palette.add_mesh(_visual, Palette.box(Vector3(1.9, 0.04, 1.9)), Palette.MINT.darkened(0.1), Vector3(0, 0.02, 0))


func _on_redirect(ball: Ball) -> void:
	var speed := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	ball.call_deferred("redirect_to", global_position, global_basis.z.normalized(), maxf(speed, strength))
	_score(10)


func _squash() -> void:
	if _visual == null:
		return
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

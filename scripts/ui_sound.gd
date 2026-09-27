extends Node
## Autoload: every button in the game gets a soft hover tick, a click (or a
## lower "back" pluck) and a small hover bounce. Nothing to wire per screen.

var _hover: AudioStreamPlayer
var _click: AudioStreamPlayer
var _back: AudioStreamPlayer
var _quiet_until := 0
const BACK_WORDS := ["Back", "Cancel", "Menu", "Quit", "Got it"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hover = _player("ui_hover", -14.0)
	_click = _player("ui_click", -8.0)
	_back = _player("ui_back", -8.0)
	get_tree().node_added.connect(_on_node_added)


func _player(sound: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var path := "res://audio/sfx/%s.wav" % sound
	if ResourceLoader.exists(path):
		p.stream = load(path)
	p.volume_db = db
	p.bus = "SFX"
	add_child(p)
	return p


func _on_node_added(n: Node) -> void:
	if n.get_parent() == get_tree().root:
		# A new scene: its buttons grabbing focus shouldn't tick.
		_quiet_until = Time.get_ticks_msec() + 500
	var b := n as BaseButton
	if b == null:
		return
	b.mouse_entered.connect(func() -> void: _hovered(b))
	b.focus_entered.connect(func() -> void:
		if not b.is_hovered():
			_tick())
	b.mouse_exited.connect(func() -> void: _bounce(b, 1.0))
	b.pressed.connect(func() -> void: _pressed(b))


func _hovered(b: BaseButton) -> void:
	if b.disabled:
		return
	_tick()
	if b is Button and (b as Button).theme_type_variation != "IconButton" and b.size.x < 700:
		_bounce(b, 1.035)


func _bounce(b: Control, to: float) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * to, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _tick() -> void:
	if Time.get_ticks_msec() < _quiet_until or _hover.stream == null:
		return
	_hover.pitch_scale = randf_range(0.95, 1.08)
	_hover.play()


func _pressed(b: BaseButton) -> void:
	_bounce(b, 1.0)
	var back := false
	if b is Button:
		for w in BACK_WORDS:
			if (b as Button).text.begins_with(w):
				back = true
	var p := _back if back else _click
	if p.stream:
		p.pitch_scale = randf_range(0.97, 1.04)
		p.play()

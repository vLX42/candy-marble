class_name Hud
extends CanvasLayer
## In-game HUD: level card (top left), timer card (top right), a toast banner
## for short messages and a results panel when the ball is in the hole.
## Cards use the same cream / pink-border / soft-shadow look as the menu buttons.

const INK := CandyText.CHOCOLATE
const MUTED := Color("#9A7B80")
const MEDAL_COLORS := {"GOLD": Color("#F7D66B"), "SILVER": Color("#D9DEE8"), "BRONZE": Color("#E8B08A")}

var _level_chip: Label
var _title: Label
var _par_chip: Label
var _falls_chip: Label
var _race_chip: Label
var _race_chip_box: PanelContainer
var _race_row: HBoxContainer
var _time: Label
var _best: Label
var _rush: ProgressBar
var _rush_fill: StyleBoxFlat
var _rush_label: Label

var _toast: PanelContainer
var _toast_title: RichTextLabel
var _toast_sub: Label
var _toast_token := 0
## Shown again when a timed toast runs out (e.g. "the rival won").
var sticky := ""

var _results: PanelContainer
var _res_title: RichTextLabel
var _res_time: Label
var _res_chips: HBoxContainer
var _res_info: Label
var _res_board_box: VBoxContainer
var _res_board_title: Label
var _res_board: GridContainer
var _res_hint: Label
var _count: RichTextLabel
var _count_tween: Tween
var _pause: PanelContainer
var _pause_box: VBoxContainer
var _res_buttons: HBoxContainer
var _pause_button: Button
var _stick: Control

signal pause_action(action: String)
## A results chip just stamped in (main plays a chime).
signal stamp


func _ready() -> void:
	# Keeps working while the game is paused (the pause card lives here).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_level_card()
	_build_timer_card()
	_build_toast()
	_build_results()
	_build_count()
	_build_touch()
	_build_pause()


## Big 3 / 2 / 1 / GO! in the middle of the screen.
func show_count(text: String) -> void:
	_count.text = "[center]%s[/center]" % CandyText.rainbow(text, text.length())
	_count.visible = true
	_count.pivot_offset = _count.size * 0.5
	if _count_tween:
		_count_tween.kill()
	_count.scale = Vector2(1.6, 1.6)
	_count.modulate.a = 1.0
	_count_tween = create_tween()
	_count_tween.tween_property(_count, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_count_tween.tween_interval(0.3 if text != "GO!" else 0.35)
	_count_tween.tween_property(_count, "modulate:a", 0.0, 0.2)
	_count_tween.tween_callback(func() -> void: _count.visible = false)


func show_pause(back_label: String) -> void:
	for c in _pause_box.get_children():
		if c is Button:
			_pause_box.remove_child(c)
			c.queue_free()
	var items: Array = [["Resume", "resume"], ["Restart level", "restart"]]
	if Tilt.is_touch():
		if Tilt.active():
			items.append(["Recalibrate tilt", "calibrate"])
		items.append(["Controls: %s" % ("tilt the phone" if Settings.control_mode == "tilt" else "drag to roll"), "controls"])
	items.append(["Camera: %s" % ("follows the track" if Settings.camera_follow else "fixed"), "camera"])
	items.append(["Ghost: %s" % ("on" if Settings.ghost else "off"), "ghost"])
	items.append([back_label, "quit"])
	for spec: Array in items:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size.x = 380
		b.pressed.connect(func() -> void: pause_action.emit(spec[1]))
		b.mouse_entered.connect(b.grab_focus)
		_pause_box.add_child(b)
	_pause.visible = true
	(_pause_box.get_child(1) as Button).call_deferred("grab_focus")


func hide_pause() -> void:
	_pause.visible = false


func is_paused_visible() -> bool:
	return _pause.visible


# --- Public -------------------------------------------------------------------

func set_level(number: int, title: String, par: float, race: bool) -> void:
	_level_chip.text = "LEVEL %d" % number
	_title.text = title
	_par_chip.text = "PAR %.0f s" % par
	_race_row.visible = race
	hide_results()
	sticky = ""
	_hide_toast()


func update(time: float, over_par: bool, falls: int, race_place: String) -> void:
	_time.text = "%.2f" % time
	_time.add_theme_color_override("font_color", Palette.RASPBERRY if over_par else CandyText.PASTELS[0])
	_falls_chip.text = "FALLS %d" % falls
	if _race_row.visible:
		_race_chip.text = race_place
		var sb: StyleBoxFlat = _race_chip_box.get_theme_stylebox("panel")
		sb.bg_color = Palette.MINT if race_place == "1st" else (Palette.PINK if race_place == "2nd" else Palette.RASPBERRY)
		_race_chip.add_theme_color_override("font_color", CandyText.CREAM if race_place == "LOST" else INK)


func set_best(best: float) -> void:
	_best.text = "BEST  %.2f" % best if best > 0.0 else "NO BEST YET"


## value 0..1. While `active`, the bar counts the rush down.
func set_rush(value: float, active: bool, left: float) -> void:
	_rush.value = value
	_rush_fill.bg_color = Palette.CORAL if active else Palette.PINK
	_rush_label.text = "RUSH %.1f" % maxf(left, 0.0) if active else "SUGAR"
	_rush_label.add_theme_color_override("font_color", Palette.CORAL if active else MUTED)


## Banner under the top cards. First line in candy letters, the rest small.
func show_message(text: String, duration: float = 0.0) -> void:
	_toast_token += 1
	var token := _toast_token
	_set_toast(text)
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration).timeout
	if token == _toast_token:
		_set_toast(sticky)


## Results panel. `r` keys: title, time, medal, badge, info, board_title, board
## (Array of times), highlight (row index or -1), hint.
func show_results(r: Dictionary) -> void:
	sticky = ""
	_hide_toast()
	_res_title.text = "[center]%s[/center]" % CandyText.rainbow(r.get("title", ""))
	_res_time.text = "%.2f s" % r.time if r.has("time") else ""
	_res_time.visible = r.has("time")
	for c in _res_chips.get_children():
		c.queue_free()
	var medal: String = r.get("medal", "")
	if medal != "":
		_res_chips.add_child(_chip(medal + " MEDAL", MEDAL_COLORS.get(medal, Palette.LEMON), 22)[0])
	elif r.has("medal"):
		_res_chips.add_child(_chip("OVER PAR", Color("#E9E1EC"), 22)[0])
	if r.get("badge", "") != "":
		_res_chips.add_child(_chip(r.badge, Palette.MINT, 22)[0])
	_res_chips.visible = r.has("medal") or r.get("badge", "") != ""
	_res_info.text = r.get("info", "")
	_res_info.visible = _res_info.text != ""

	for c in _res_board.get_children():
		c.queue_free()
	var times: Array = r.get("board", [])
	_res_board_box.visible = not times.is_empty()
	_res_board_title.text = r.get("board_title", "BEST TIMES")
	var hl: int = r.get("highlight", -1)
	for k in times.size():
		var col := Palette.CORAL if k == hl else INK
		var rank := _plain("%d." % (k + 1), 24, col)
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_res_board.add_child(rank)
		var t := _plain("%.2f s" % times[k], 24, col)
		t.custom_minimum_size.x = 100
		_res_board.add_child(t)
		_res_board.add_child(_plain("  NEW" if k == hl else "", 18, Palette.CORAL))
	_res_hint.text = r.get("hint", "")
	_res_hint.visible = not Tilt.is_touch()
	for c in _res_buttons.get_children():
		_res_buttons.remove_child(c)
		c.queue_free()
	var btns: Array = [["Retry", "retry"]]
	if r.get("next", false):
		btns.append(["Next level", "next"])
	btns.append(["Menu", "toggle"])
	for spec: Array in btns:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(130, 0)
		b.pressed.connect(func() -> void: pause_action.emit(spec[1]))
		_res_buttons.add_child(b)
	_results.visible = true
	_results.pivot_offset = _results.size * 0.5
	_results.scale = Vector2(0.85, 0.85)
	_results.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_results, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_results, "modulate:a", 1.0, 0.2)
	# The time counts up, then the chips stamp in one by one.
	if r.has("time"):
		var final: float = r.time
		var count := create_tween()
		count.tween_method(func(v: float) -> void: _res_time.text = "%.2f s" % v, 0.0, final, 0.6) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var chips := _res_chips.get_children()
	for k in chips.size():
		var c: Control = chips[k]
		c.modulate.a = 0.0
		var st := create_tween()
		st.tween_interval(0.65 + 0.22 * k)
		st.tween_callback(func() -> void:
			c.pivot_offset = c.size * 0.5
			c.scale = Vector2(1.8, 1.8)
			c.modulate.a = 1.0
			stamp.emit())
		st.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if r.get("confetti", false):
		var cf := create_tween()
		cf.tween_interval(0.65)
		cf.tween_callback(_confetti)


## Pastel confetti bursting out of the top of the results card.
func _confetti() -> void:
	for side in [-1.0, 1.0]:
		var p := CPUParticles2D.new()
		p.amount = 70
		p.one_shot = true
		p.explosiveness = 0.9
		p.lifetime = 2.2
		p.direction = Vector2(0.35 * side, -1.0)
		p.spread = 35.0
		p.initial_velocity_min = 420.0
		p.initial_velocity_max = 780.0
		p.gravity = Vector2(0, 900)
		p.damping_min = 40.0
		p.damping_max = 90.0
		p.angular_velocity_min = -540.0
		p.angular_velocity_max = 540.0
		p.scale_amount_min = 6.0
		p.scale_amount_max = 11.0
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
		g.colors = PackedColorArray(CandyText.PASTELS)
		p.color_initial_ramp = g
		var fade := Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.add_point(0.75, Color.WHITE)
		fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
		p.color_ramp = fade
		add_child(p)
		p.position = _results.global_position + Vector2(_results.size.x * (0.5 + 0.3 * side), 10)
		p.emitting = true
		p.finished.connect(p.queue_free)


func hide_results() -> void:
	if _results:
		_results.visible = false


## Plain text of the results panel (tests read this).
func results_text() -> String:
	if not _results.visible:
		return ""
	return "%s | %s | %s" % [_res_title.get_parsed_text(), _res_time.text, _res_info.text]


func toast_text() -> String:
	if not _toast.visible:
		return ""
	return _toast_title.get_parsed_text() + " | " + _toast_sub.text


# --- Building ---------------------------------------------------------------

func _build_level_card() -> void:
	var card := _card()
	card.position = Vector2(20, 16)
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var lc := _chip("LEVEL 1", Palette.PINK, 16)
	_level_chip = lc[1]
	top.add_child(lc[0])
	_title = Label.new()
	CandyText.style(_title, 30)
	top.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var pc := _chip("PAR", Palette.LEMON, 18)
	_par_chip = pc[1]
	row.add_child(pc[0])
	var fc := _chip("FALLS 0", Palette.SKY, 18)
	_falls_chip = fc[1]
	row.add_child(fc[0])
	var rc := _chip("1st", Palette.MINT, 18)
	_race_chip_box = rc[0]
	_race_chip = rc[1]
	_race_row = HBoxContainer.new()
	_race_row.add_theme_constant_override("separation", 6)
	_race_row.add_child(_plain("RACE", 18, MUTED))
	_race_row.add_child(_race_chip_box)
	row.add_child(_race_row)


func _build_timer_card() -> void:
	var card := _card()
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -260.0
	card.offset_right = -20.0
	card.offset_top = 16.0
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var tl := _plain("TIME", 16, MUTED)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	_best = _plain("NO BEST YET", 16, MUTED)
	head.add_child(_best)
	_time = Label.new()
	CandyText.style(_time, 56, CandyText.PASTELS[0])
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_time)
	var rush_row := HBoxContainer.new()
	rush_row.add_theme_constant_override("separation", 8)
	col.add_child(rush_row)
	_rush_label = _plain("SUGAR", 16, MUTED)
	_rush_label.custom_minimum_size.x = 78
	rush_row.add_child(_rush_label)
	_rush = ProgressBar.new()
	_rush.show_percentage = false
	_rush.max_value = 1.0
	_rush.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rush.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rush.custom_minimum_size = Vector2(0, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#F3E4E0")
	bg.set_corner_radius_all(7)
	_rush_fill = StyleBoxFlat.new()
	_rush_fill.bg_color = Palette.PINK
	_rush_fill.set_corner_radius_all(7)
	_rush.add_theme_stylebox_override("background", bg)
	_rush.add_theme_stylebox_override("fill", _rush_fill)
	rush_row.add_child(_rush)


func _build_toast() -> void:
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.anchor_right = 1.0
	wrap.offset_top = 150.0
	add_child(wrap)
	_toast = _card(28, 12)
	_toast.visible = false
	wrap.add_child(_toast)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_toast.add_child(col)
	_toast_title = _rich(46)
	col.add_child(_toast_title)
	_toast_sub = _plain("", 24, INK)
	_toast_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_toast_sub)


func _build_count() -> void:
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wrap)
	_count = _rich(150)
	_count.custom_minimum_size.x = 600
	_count.visible = false
	wrap.add_child(_count)


## Round pause button (touch screens) and the drag-stick ring.
func _build_touch() -> void:
	_stick = Control.new()
	_stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.draw.connect(_draw_stick)
	add_child(_stick)
	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.theme = CandyTheme.make(30)
	_pause_button.anchor_left = 0.5
	_pause_button.anchor_right = 0.5
	_pause_button.offset_left = -38
	_pause_button.offset_right = 38
	_pause_button.offset_top = 16
	_pause_button.offset_bottom = 88
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.visible = Tilt.is_touch()
	_pause_button.pressed.connect(func() -> void: pause_action.emit("toggle"))
	add_child(_pause_button)


func _process(_delta: float) -> void:
	if _stick and Tilt.is_touch():
		_stick.queue_redraw()


func _draw_stick() -> void:
	var st: Array = Tilt.stick_state()
	if not st[0]:
		return
	var o: Vector2 = st[1]
	var p: Vector2 = o + (st[2] - o).limit_length(90.0)
	_stick.draw_circle(o, 92.0, Color(1, 0.96, 0.88, 0.35))
	_stick.draw_arc(o, 92.0, 0.0, TAU, 48, Color(Palette.PINK, 0.9), 5.0, true)
	_stick.draw_circle(p, 38.0, Color(Palette.PINK, 0.95))
	_stick.draw_circle(p, 26.0, Color(1, 0.96, 0.88, 0.95))


func _build_pause() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.35, 0.2, 0.3, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause = PanelContainer.new()
	_pause.theme = CandyTheme.make(30)
	_pause.visible = false
	_pause.visibility_changed.connect(func() -> void: dim.visible = _pause.visible)
	dim.visible = false
	add_child(dim)
	add_child(wrap)
	wrap.add_child(_pause)
	_pause_box = VBoxContainer.new()
	_pause_box.add_theme_constant_override("separation", 10)
	_pause.add_child(_pause_box)
	var head := _rich(56)
	head.text = "[center]%s[/center]" % CandyText.rainbow("Paused")
	_pause_box.add_child(head)


func _build_results() -> void:
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wrap)
	_results = _card(44, 22, 1.0)
	_results.custom_minimum_size.x = 460
	_results.visible = false
	wrap.add_child(_results)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_results.add_child(col)
	_res_title = _rich(56)
	col.add_child(_res_title)
	_res_time = Label.new()
	CandyText.style(_res_time, 64, CandyText.PASTELS[0])
	_res_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_res_time)
	_res_chips = HBoxContainer.new()
	_res_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_res_chips.add_theme_constant_override("separation", 10)
	col.add_child(_res_chips)
	_res_info = _plain("", 24, INK)
	_res_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_res_info)

	_res_board_box = VBoxContainer.new()
	_res_board_box.add_theme_constant_override("separation", 2)
	col.add_child(_res_board_box)
	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(Palette.PINK, 0.8)
	line.thickness = 3
	sep.add_theme_stylebox_override("separator", line)
	sep.add_theme_constant_override("separation", 14)
	_res_board_box.add_child(sep)
	_res_board_title = _plain("BEST TIMES", 16, MUTED)
	_res_board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_board_box.add_child(_res_board_title)
	var bc := CenterContainer.new()
	_res_board_box.add_child(bc)
	_res_board = GridContainer.new()
	_res_board.columns = 3
	_res_board.add_theme_constant_override("h_separation", 12)
	_res_board.add_theme_constant_override("v_separation", 0)
	bc.add_child(_res_board)

	_res_hint = _plain("", 18, MUTED)
	_res_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_res_hint)
	# Tap targets (phones have no R or Esc key).
	_res_buttons = HBoxContainer.new()
	_res_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_res_buttons.add_theme_constant_override("separation", 10)
	_res_buttons.theme = CandyTheme.make(24)
	col.add_child(_res_buttons)


func _set_toast(text: String) -> void:
	if text == "":
		_hide_toast()
		return
	var lines := text.split("\n")
	_toast_title.text = "[center]%s[/center]" % CandyText.rainbow(lines[0])
	_toast_sub.text = "\n".join(lines.slice(1))
	_toast_sub.visible = lines.size() > 1
	_toast.visible = true
	_toast.pivot_offset = _toast.size * 0.5
	_toast.modulate.a = 0.0
	_toast.scale = Vector2(0.9, 0.9)
	var tw := create_tween().set_parallel()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_property(_toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_toast() -> void:
	if _toast:
		_toast.visible = false


## Cream card with a pink border and a soft raspberry shadow.
func _card(margin_x: int = 18, margin_y: int = 10, alpha: float = 0.94) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.96, 0.88, alpha)
	sb.border_color = Palette.PINK
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(24)
	sb.shadow_color = Color(0.78, 0.13, 0.31, 0.22)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = margin_x
	sb.content_margin_right = margin_x
	sb.content_margin_top = margin_y
	sb.content_margin_bottom = margin_y + 2
	p.add_theme_stylebox_override("panel", sb)
	return p


## Small rounded pill. Returns [box, label].
func _chip(text: String, bg: Color, size: int) -> Array:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(size)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 1
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := _plain(text, size, INK)
	p.add_child(l)
	return [p, l]


## Bold text with no outline, for text sitting on a card.
func _plain(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", CandyText.FONT_BOLD)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CandyText.style(r, size)
	return r

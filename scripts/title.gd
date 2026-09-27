extends Node3D
## Title screen: a little candy island where the peppermint and licorice balls
## chase each other round and round, plus the menu (play, level select with
## best times and medals, fullscreen, quit).

const SkyShader := preload("res://scripts/sky.gdshader")
const RivalScene := preload("res://scenes/rival.tscn")
const MUSIC := "res://audio/Spun_Sugar_Waltz.mp3"


class DemoLevel extends LevelBase:
	func _init() -> void:
		title = "demo"
		heights = [
			"1111111111111",
			"1000000000001",
			"1000000000001",
			"1002222222001",
			"1002333332001",
			"1002333332001",
			"1002222222001",
			"1000000000001",
			"1000000000001",
			"1111111111111",
		]
		objects = [
			"l..t..g..t..l",
			".S..........B",
			"...WWWWWWW...",
			"...t.....l...",
			"....%...%....",
			".....b.h.....",
			"...g.....t...",
			"...WWWWWWW...",
			"B............",
			"t..l..%..l..b",
		]
		route = [Vector2(1.5, 1.5), Vector2(10.5, 1.5), Vector2(11, 4.5), Vector2(10.5, 7.5),
			Vector2(1.5, 7.5), Vector2(1, 4.5)]


var _level: DemoLevel
var _cam: Camera3D
var _t := 0.0
var _scores := Scores.new()
var _menu: VBoxContainer
var _levels_panel: VBoxContainer
var _settings_panel: VBoxContainer
var _reset_armed := false
var _fullscreen_button: Button
var _theme := Theme.new()


func _ready() -> void:
	_build_world()
	_build_ui()
	_play_music()


# --- 3D ---------------------------------------------------------------------------

func _build_world() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFF1F6")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	_level = DemoLevel.new()
	_level.build()
	add_child(Terrain.new(_level))
	var backdrop := Backdrop.new()
	backdrop.setup(_level, 7)
	add_child(backdrop)
	for e in _level.entities:
		if e.type == "decor" or e.type == "bumper":
			var node: Node3D = load("res://scenes/%s.tscn" % e.type).instantiate()
			node.position = Vector3(e.pos.x, _level.height(e.pos.x, e.pos.y), e.pos.y)
			node.rotation_degrees.y = e.get("yaw", 0.0)
			if e.has("kind"):
				node.set("kind", e.kind)
			add_child(node)
	for k in 2:
		var r: Rival = RivalScene.instantiate()
		r.level = _level
		r.skin = "ball" if k == 0 else "rival"
		r.loop_route = true
		r.cruise = 5.5 if k == 0 else 5.2
		var start := _level.tile_center_f(_level.route[k * 3])
		r.position = Vector3(start.x, 0.7, start.y)
		add_child(r)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 21.0
	_cam.far = 200.0
	_cam.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	add_child(_cam)
	_cam.make_current()


func _process(delta: float) -> void:
	_t += delta
	var center := Vector3(_level.cols, 0.5, _level.rows)  # tiles are 2 units
	var offset := Vector3(-6.0 + sin(_t * 0.15) * 1.5, 0.0, 6.0 + cos(_t * 0.12) * 1.0)
	_cam.global_position = center + offset + _cam.global_basis.z * 40.0


# --- UI ---------------------------------------------------------------------------

func _build_ui() -> void:
	_setup_theme()
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme
	layer.add_child(root)

	var logo := TextureRect.new()
	logo.texture = load("res://art/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.position = Vector2(40, 18)
	logo.size = Vector2(620, 323)
	root.add_child(logo)
	var sub := Label.new()
	sub.text = "a marble race through candyland"
	CandyText.style(sub, 30)
	sub.position = Vector2(92, 330)
	root.add_child(sub)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(84, 400)
	_menu.add_theme_constant_override("separation", 14)
	root.add_child(_menu)
	var unlocked := mini(_scores.unlocked(), MainGame.LEVELS.size())
	var play := _button("Play", func() -> void: _start(0))
	if unlocked > 1:
		play = _button("Continue  (level %d)" % unlocked, func() -> void: _start(unlocked - 1))
		_menu.add_child(play)
		_menu.add_child(_button("New run", func() -> void: _start(0)))
	else:
		_menu.add_child(play)
	_menu.add_child(_button("Levels", _show_levels))
	_menu.add_child(_button("Settings", _show_settings))
	_menu.add_child(_button("Quit", func() -> void: get_tree().quit()))
	var runs: Array = _scores.top("run")
	if runs.size() > 0:
		var best := Label.new()
		best.text = "Best full run  %.2f s" % runs[0]
		CandyText.style(best, 26)
		_menu.add_child(best)
	_update_fullscreen_label()

	_levels_panel = VBoxContainer.new()
	_levels_panel.position = Vector2(84, 390)
	_levels_panel.add_theme_constant_override("separation", 14)
	_levels_panel.visible = false
	root.add_child(_levels_panel)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_levels_panel.add_child(grid)
	for i in MainGame.LEVELS.size():
		var lvl: LevelBase = MainGame.LEVELS[i].new()
		var best := _scores.best("level:" + lvl.title)
		var line := "par %.0f s" % lvl.time_limit
		if best > 0.0:
			var medal := MainGame.medal_for(best, lvl.time_limit)
			line = "best %.2f s  %s" % [best, medal.to_lower() if medal != "" else ""]
		var text := "%d  %s\n%s%s" % [i + 1, lvl.title, line, "\nRACE" if lvl.race else ""]
		var b := _button(text, func() -> void: _start(i))
		if i >= unlocked:
			b.text = "%d  %s\nlocked\nfinish level %d" % [i + 1, lvl.title, i]
			b.disabled = true
		b.custom_minimum_size = Vector2(330, 118)
		b.add_theme_font_size_override("font_size", 24)
		grid.add_child(b)
	_levels_panel.add_child(_button("Back", _show_menu))
	_build_settings(root)

	var hint := Label.new()
	hint.text = "WASD / arrows / stick to roll    R restart    Esc menu    F11 fullscreen"
	CandyText.style(hint, 22, CandyText.CHOCOLATE, false)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 84
	hint.offset_top = -56
	root.add_child(hint)

	play.grab_focus()


func _setup_theme() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#FFF4E0")
	normal.border_color = Palette.PINK
	normal.set_border_width_all(5)
	normal.set_corner_radius_all(26)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	normal.content_margin_top = 10
	normal.content_margin_bottom = 12
	normal.shadow_color = Color(0.78, 0.13, 0.31, 0.25)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 5)
	var hover := normal.duplicate()
	hover.bg_color = Palette.LEMON
	hover.border_color = Palette.CORAL
	var pressed := normal.duplicate()
	pressed.bg_color = Palette.PINK
	_theme.set_stylebox("normal", "Button", normal)
	_theme.set_stylebox("hover", "Button", hover)
	_theme.set_stylebox("focus", "Button", hover)
	_theme.set_stylebox("pressed", "Button", pressed)
	var disabled := normal.duplicate()
	disabled.bg_color = Color("#E9E1EC")
	disabled.border_color = Color("#CBBFD4")
	_theme.set_stylebox("disabled", "Button", disabled)
	_theme.set_color("font_disabled_color", "Button", Color("#8A7E90"))
	_theme.set_color("font_color", "Button", Palette.INK)
	_theme.set_color("font_hover_color", "Button", Palette.INK)
	_theme.set_color("font_focus_color", "Button", Palette.INK)
	_theme.set_color("font_pressed_color", "Button", Palette.INK)
	_theme.set_font_size("font_size", "Button", 38)
	_theme.set_font("font", "Button", CandyText.FONT_BOLD)
	_theme.set_color("font_color", "Button", CandyText.CHOCOLATE)
	_theme.set_color("font_hover_color", "Button", CandyText.CHOCOLATE)
	_theme.set_color("font_focus_color", "Button", CandyText.CHOCOLATE)
	_theme.set_color("font_pressed_color", "Button", CandyText.CHOCOLATE)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.75)
	track.set_corner_radius_all(10)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.PINK
	fill.set_corner_radius_all(10)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	_theme.set_stylebox("slider", "HSlider", track)
	_theme.set_stylebox("grabber_area", "HSlider", fill)
	_theme.set_stylebox("grabber_area_highlight", "HSlider", fill)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(360, 0)
	b.pressed.connect(action)
	return b


func _show_levels() -> void:
	_menu.visible = false
	_levels_panel.visible = true
	(_levels_panel.get_child(0).get_child(0) as Button).grab_focus()


func _show_menu() -> void:
	_levels_panel.visible = false
	_settings_panel.visible = false
	_menu.visible = true
	(_menu.get_child(0) as Button).grab_focus()


func _toggle_fullscreen() -> void:
	Settings.toggle_fullscreen()
	_update_fullscreen_label()


func _update_fullscreen_label() -> void:
	if _fullscreen_button == null:
		return
	_fullscreen_button.text = "Fullscreen: %s" % ("On" if Settings.fullscreen else "Off")


func _start(index: int) -> void:
	MainGame.requested_level = index
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (_levels_panel.visible or _settings_panel.visible):
		_show_menu()


# --- settings page ------------------------------------------------------------------

func _build_settings(root: Control) -> void:
	_settings_panel = VBoxContainer.new()
	_settings_panel.position = Vector2(84, 380)
	_settings_panel.add_theme_constant_override("separation", 10)
	_settings_panel.visible = false
	root.add_child(_settings_panel)

	_settings_panel.add_child(_setting_button(func() -> String:
		return "Camera: %s" % ("follows the track" if Settings.camera_follow else "fixed isometric"),
		func() -> void: Settings.set_value("camera_follow", not Settings.camera_follow)))
	_settings_panel.add_child(_setting_button(func() -> String:
		return "Zoom: %s" % Settings.ZOOM_NAMES[Settings.zoom],
		func() -> void: Settings.set_value("zoom", (Settings.zoom + 1) % Settings.ZOOMS.size())))
	_settings_panel.add_child(_slider("Music", Settings.music_volume, func(v: float) -> void:
		Settings.set_value("music_volume", v)))
	_settings_panel.add_child(_slider("Effects", Settings.sfx_volume, func(v: float) -> void:
		Settings.set_value("sfx_volume", v)))
	_settings_panel.add_child(_setting_button(func() -> String:
		return "Graphics: %s" % ("high" if Settings.graphics_high else "fast"),
		func() -> void: Settings.set_value("graphics_high", not Settings.graphics_high)))
	_settings_panel.add_child(_setting_button(func() -> String:
		return "Fullscreen: %s" % ("on" if Settings.fullscreen else "off"),
		func() -> void: Settings.toggle_fullscreen()))
	var reset := _button("Reset best times and unlocks", func() -> void: pass)
	reset.pressed.connect(func() -> void:
		if _reset_armed:
			_scores.reset()
			reset.text = "Progress reset"
			_reset_armed = false
		else:
			_reset_armed = true
			reset.text = "Sure? Press again to reset")
	reset.add_theme_font_size_override("font_size", 28)
	_settings_panel.add_child(reset)
	_settings_panel.add_child(_button("Back", _show_menu))


## A button whose label comes from `label` and refreshes after `action`.
func _setting_button(label: Callable, action: Callable) -> Button:
	var b := _button(label.call(), func() -> void: pass)
	b.custom_minimum_size = Vector2(620, 0)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(func() -> void:
		action.call()
		b.text = label.call()
		_update_fullscreen_label())
	return b


func _slider(title: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(150, 0)
	CandyText.style(l, 30)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(450, 40)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row


func _show_settings() -> void:
	_menu.visible = false
	_settings_panel.visible = true
	(_settings_panel.get_child(0) as Button).grab_focus()


func _play_music() -> void:
	if not ResourceLoader.exists(MUSIC):
		return
	var stream: AudioStreamMP3 = load(MUSIC)
	stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -9.0
	p.bus = "Music"
	p.autoplay = true
	add_child(p)

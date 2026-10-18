class_name TitleScreen
extends Node3D
## Title screen: a little candy island where the peppermint and licorice balls
## chase each other round and round, plus the menu (play, level select with
## best times and medals, fullscreen, quit).

const SkyShader := preload("res://scripts/sky.gdshader")
const RivalScene := preload("res://scenes/rival.tscn")
const MUSIC := "res://audio/Spun_Sugar_Waltz.mp3"

## Page to open on arrival ("quests" when coming back from a quest or the editor).
static var open_page := ""


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
var _tilt: TiltShift
var _t := 0.0
var _scores := Scores.new()
var _menu: VBoxContainer
var _levels_panel: VBoxContainer
var _settings_panel: VBoxContainer
var _reset_armed := false
var _fullscreen_button: Button
var _theme := Theme.new()
var _quests: QuestBrowser
var _front: Array[Control] = []
var _online_panel: VBoxContainer
var _online_form: VBoxContainer
var _online_lobby: VBoxContainer
var _online_status: Label
var _online_players: VBoxContainer
var _online_waiting: Label
var _name_edit: LineEdit
var _level_pick: OptionButton
var _bot_pick: OptionButton
var _rounds_pick: OptionButton
var _host_row: HBoxContainer
var _race_info: Label
var _start_button: Button
var _ready_button: Button
var _connect_button: Button


func _ready() -> void:
	# The dedicated server (Docker on the NAS) has nothing to show.
	if Net.server_mode:
		get_tree().change_scene_to_file.call_deferred("res://scenes/server.tscn")
		return
	Quest.install_samples()
	_build_world()
	_build_ui()
	_play_music()
	if open_page == "quests":
		_show_quests()
	elif open_page == "online":
		_show_online()
	open_page = ""


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
	Settings.match_renderer(env, self)
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
	_tilt = TiltShift.new()
	_tilt.focus = 0.6
	add_child(_tilt)


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
	logo.position = Vector2(46, 12)
	logo.size = Vector2(520, 271)
	root.add_child(logo)
	var sub := Label.new()
	sub.text = "a marble race through candyland"
	CandyText.style(sub, 26)
	sub.position = Vector2(92, 276)
	root.add_child(sub)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(84, 336)
	_menu.add_theme_constant_override("separation", 12)
	root.add_child(_menu)
	var unlocked := mini(_scores.unlocked(), MainGame.LEVELS.size())
	var play := _button("Play", func() -> void: _start(0))
	if unlocked > 1:
		play = _button("Continue  (level %d)" % unlocked, func() -> void: _start(unlocked - 1))
		_menu.add_child(play)
		_menu.add_child(_button("New run", func() -> void: _start(0)))
	else:
		_menu.add_child(play)
	_menu.add_child(_pair(_button("Levels", _show_levels), _button("Online race", _show_online)))
	_menu.add_child(_pair(_button("Quests", _show_quests), _button("Level editor", _open_editor)))
	if OS.has_feature("web"):
		# No quitting a web page.
		_menu.add_child(_button("Settings", _show_settings))
	else:
		_menu.add_child(_pair(_button("Settings", _show_settings), _button("Quit", func() -> void: get_tree().quit())))
	var runs: Array = _scores.top("run")
	if runs.size() > 0:
		var best := Label.new()
		best.text = "Best full run  %.2f s" % runs[0]
		CandyText.style(best, 24)
		_menu.add_child(best)
	_update_fullscreen_label()

	_levels_panel = VBoxContainer.new()
	var narrow := Tilt.is_portrait()
	_levels_panel.position = Vector2(84, 390) if not narrow else Vector2(40, 330)
	_levels_panel.add_theme_constant_override("separation", 14)
	_levels_panel.visible = false
	root.add_child(_levels_panel)
	var grid := GridContainer.new()
	grid.columns = 4 if not narrow else 2
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
		b.custom_minimum_size = Vector2(290, 104) if not narrow else Vector2(265, 96)
		b.add_theme_font_size_override("font_size", 22)
		grid.add_child(b)
	_levels_panel.add_child(_button("Back", _show_menu))
	_build_settings(root)
	_build_online(root)

	var hint := Label.new()
	hint.text = "WASD / arrows / stick to roll    R restart    Esc menu    F11 fullscreen"
	if Tilt.is_touch():
		hint.text = "Tilt your phone to roll.   Tap  II  to pause."
	CandyText.style(hint, 22, CandyText.CHOCOLATE, false)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 84
	hint.offset_top = -56
	root.add_child(hint)
	var ver := Label.new()
	var v := str(ProjectSettings.get_setting("application/config/version", "dev"))
	ver.text = "dev build" if v == "dev" else "v" + v
	CandyText.style(ver, 18, CandyText.CHOCOLATE, false)
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -160
	ver.offset_right = -24
	ver.offset_top = -48
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(ver)
	_front = [logo, sub, hint]

	_quests = QuestBrowser.new()
	_quests.visible = false
	_quests.closed.connect(_show_menu)
	root.add_child(_quests)
	_intro(logo, sub)

	play.grab_focus()


## Logo drops in with a bounce, then the menu buttons pop in one by one.
func _intro(logo: Control, sub: Control) -> void:
	var end := logo.position
	logo.position = end - Vector2(0, 360)
	var tw := create_tween()
	tw.tween_property(logo, "position", end, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	sub.modulate.a = 0.0
	create_tween().tween_property(sub, "modulate:a", 1.0, 0.4).set_delay(0.5)
	var k := 0
	for c in _menu.get_children():
		var item := c as Control
		item.modulate.a = 0.0
		item.pivot_offset = Vector2(40, 24)
		item.scale = Vector2(0.85, 0.85)
		var t := create_tween().set_parallel()
		t.tween_property(item, "modulate:a", 1.0, 0.25).set_delay(0.35 + 0.06 * k)
		t.tween_property(item, "scale", Vector2.ONE, 0.35).set_delay(0.35 + 0.06 * k) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		k += 1


func _setup_theme() -> void:
	_theme = CandyTheme.make(32)


## Two half-width buttons side by side.
func _pair(a: Button, b: Button) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for x in [a, b]:
		x.custom_minimum_size = Vector2(0, 0)
		x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(x)
	row.custom_minimum_size.x = 480
	return row


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(480, 0)
	b.pressed.connect(action)
	# Hovering moves the keyboard focus too, so only one button lights up.
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b


func _show_quests() -> void:
	_menu.visible = false
	for c in _front:
		c.visible = false
	_quests.visible = true
	_quests.refresh()
	_quests.focus_first()


func _open_editor() -> void:
	var installed := Quest.list_installed()
	LevelEditor.session_quest = installed[0] if not installed.is_empty() else null
	LevelEditor.session_level = 0
	Transition.go("res://scenes/editor.tscn")


func _show_levels() -> void:
	_menu.visible = false
	_levels_panel.visible = true
	(_levels_panel.get_child(0).get_child(0) as Button).grab_focus()


func _show_menu() -> void:
	_levels_panel.visible = false
	_settings_panel.visible = false
	_online_panel.visible = false
	_quests.visible = false
	for c in _front:
		c.visible = true
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
	MainGame.quest = null
	MainGame.test_mode = false
	MainGame.requested_level = index
	Transition.go("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (_levels_panel.visible or _settings_panel.visible):
		_show_menu()
	elif event.is_action_pressed("ui_cancel") and _online_panel.visible and not _name_edit.has_focus():
		_leave_online()


# --- settings page ------------------------------------------------------------------

func _build_settings(root: Control) -> void:
	_settings_panel = VBoxContainer.new()
	_settings_panel.position = Vector2(84, 332)
	_settings_panel.add_theme_constant_override("separation", 8)
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
		return "Miniature look: %s" % ("on" if Settings.tilt_shift else "off"),
		func() -> void: Settings.set_value("tilt_shift", not Settings.tilt_shift)))
	_settings_panel.add_child(_setting_button(func() -> String:
		return "Fullscreen: %s" % ("on" if Settings.fullscreen else "off"),
		func() -> void: Settings.toggle_fullscreen()))
	if Tilt.is_touch():
		_settings_panel.add_child(_setting_button(func() -> String:
			return "Controls: %s" % ("tilt the phone" if Settings.control_mode == "tilt" else "drag to roll"),
			func() -> void: Settings.set_value("control_mode", "stick" if Settings.control_mode == "tilt" else "tilt")))
		_settings_panel.add_child(_slider("Tilt", (Settings.tilt_sensitivity - 0.5) / 1.5, func(v: float) -> void:
			Settings.set_value("tilt_sensitivity", 0.5 + v * 1.5)))
	_settings_panel.add_child(_setting_button(func() -> String:
		return "Arcade timer: %s" % ("on (one clock for the run)" if Settings.arcade else "off"),
		func() -> void: Settings.set_value("arcade", not Settings.arcade)))
	_settings_panel.add_child(_setting_button(func() -> String:
		return "Best-run ghost: %s" % ("on" if Settings.ghost else "off"),
		func() -> void: Settings.set_value("ghost", not Settings.ghost)))
	var reset := _button("Reset best times and unlocks", func() -> void: pass)
	reset.pressed.connect(func() -> void:
		if _reset_armed:
			_scores.reset()
			reset.text = "Progress reset"
			_reset_armed = false
		else:
			_reset_armed = true
			reset.text = "Sure? Press again to reset")
	reset.add_theme_font_size_override("font_size", 24)
	var back := _button("Back", _show_menu)
	back.add_theme_font_size_override("font_size", 24)
	var row := _pair(reset, back)
	row.custom_minimum_size.x = 620 if not Tilt.is_portrait() else 500
	reset.size_flags_stretch_ratio = 2.2
	_settings_panel.add_child(row)


## A button whose label comes from `label` and refreshes after `action`.
func _setting_button(label: Callable, action: Callable) -> Button:
	var b := _button(label.call(), func() -> void: pass)
	b.custom_minimum_size = Vector2(620 if not Tilt.is_portrait() else 500, 0)
	b.add_theme_font_size_override("font_size", 26)
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
	CandyText.style(l, 26)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(450 if not Tilt.is_portrait() else 330, 34)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row


func _show_settings() -> void:
	_menu.visible = false
	_front[2].visible = false  # the controls hint; settings reaches down there
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


# --- online race ----------------------------------------------------------------------

## The online panel: join the race server (candy.vlx.dk, see Net.SERVER_URL),
## then the lobby: everyone but the host says Ready, the host picks the level
## and how many bots fill the empty seats, then starts. See scripts/net.gd.
func _build_online(root: Control) -> void:
	_online_panel = VBoxContainer.new()
	_online_panel.position = Vector2(84, 48)
	_online_panel.add_theme_constant_override("separation", 10)
	_online_panel.visible = false
	root.add_child(_online_panel)
	var head := Label.new()
	head.text = "Online race"
	CandyText.style(head, 34)
	_online_panel.add_child(head)

	_online_form = VBoxContainer.new()
	_online_form.add_theme_constant_override("separation", 8)
	_online_panel.add_child(_online_form)
	_online_form.add_child(_small_label("Race other people on the same level, up to six at a time."))
	_online_form.add_child(_small_label("Your name"))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.text = Settings.player_name
	_name_edit.placeholder_text = "Player"
	_name_edit.custom_minimum_size = Vector2(480, 0)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _connect())
	_online_form.add_child(_name_edit)
	_connect_button = _button("Join", _connect)
	_online_form.add_child(_connect_button)

	_online_lobby = VBoxContainer.new()
	_online_lobby.add_theme_constant_override("separation", 8)
	_online_panel.add_child(_online_lobby)
	_online_players = VBoxContainer.new()
	_online_players.add_theme_constant_override("separation", 4)
	_online_lobby.add_child(_online_players)
	_race_info = _small_label("")
	_online_lobby.add_child(_race_info)
	_host_row = HBoxContainer.new()
	_host_row.add_theme_constant_override("separation", 12)
	_online_lobby.add_child(_host_row)
	_rounds_pick = OptionButton.new()
	for n: int in Net.ROUND_CHOICES:
		_rounds_pick.add_item("1 race" if n == 1 else "%d races" % n, n)
	_rounds_pick.custom_minimum_size = Vector2(130, 0)
	_rounds_pick.item_selected.connect(func(_i: int) -> void: _send_settings())
	_host_row.add_child(_rounds_pick)
	_level_pick = OptionButton.new()
	# Item ids are the level index + 1; 0 is random levels (-1 in Net).
	_level_pick.add_item("Random levels", 0)
	for i in MainGame.LEVELS.size():
		var lvl: LevelBase = MainGame.LEVELS[i].new()
		_level_pick.add_item("%d  %s" % [i + 1, lvl.title], i + 1)
	_level_pick.custom_minimum_size = Vector2(300, 0)
	_level_pick.item_selected.connect(func(_i: int) -> void: _send_settings())
	_host_row.add_child(_level_pick)
	_bot_pick = OptionButton.new()
	_bot_pick.custom_minimum_size = Vector2(148, 0)
	_bot_pick.item_selected.connect(func(_i: int) -> void: _send_settings())
	_host_row.add_child(_bot_pick)
	_start_button = _button("Start race", func() -> void: Net.request_start())
	_online_lobby.add_child(_start_button)
	_ready_button = _button("I'm ready", func() -> void:
		var me: Dictionary = Net.players.get(Net.my_id(), {})
		Net.set_ready(not me.get("ready", false)))
	_online_lobby.add_child(_ready_button)
	_online_waiting = _small_label("")
	_online_lobby.add_child(_online_waiting)

	_online_status = _small_label("")
	_online_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_online_status.custom_minimum_size = Vector2(480, 0)
	_online_panel.add_child(_online_status)
	_online_panel.add_child(_button("Back", _leave_online))
	Net.changed.connect(_refresh_online)
	Net.status_changed.connect(_refresh_online)


func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	CandyText.style(l, 22, CandyText.CHOCOLATE, false)
	return l


func _show_online() -> void:
	_menu.visible = false
	for c in _front:
		c.visible = c != _front[0] and c != _front[1]
	_online_panel.visible = true
	_refresh_online()
	if Net.is_online():
		(_start_button if Net.is_host() else _ready_button).grab_focus()
	else:
		_connect_button.grab_focus()


func _connect() -> void:
	Settings.set_value("player_name", _name_edit.text.strip_edges())
	Net.join(_name_edit.text)
	_refresh_online()


func _leave_online() -> void:
	Net.leave()
	_show_menu()


func _send_settings() -> void:
	Net.set_settings(_level_pick.get_selected_id() - 1, _bot_pick.get_selected_id(), _rounds_pick.get_selected_id())


func _refresh_online() -> void:
	if _online_panel == null:
		return
	var online := Net.is_online()
	_online_form.visible = not online
	_online_lobby.visible = online
	_connect_button.disabled = Net.status == "connecting"
	_connect_button.text = "Joining..." if Net.status == "connecting" else "Join"
	_online_status.text = Net.status_text if not online else ""
	for c in _online_players.get_children():
		_online_players.remove_child(c)
		c.queue_free()
	if not online:
		return
	var ids := Net.humans()
	_online_players.add_child(_small_label("Lobby  %d / %d" % [ids.size(), Net.MAX_PLAYERS]))
	var not_ready := []
	for id: int in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var chip := ColorRect.new()
		chip.color = Net.color_of(id)
		chip.custom_minimum_size = Vector2(26, 26)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		var who := Label.new()
		var tags := []
		if id == Net.my_id():
			tags.append("you")
		if id == Net.host_id:
			tags.append("host")
		elif Net.players[id].get("ready", false):
			tags.append("ready")
		else:
			not_ready.append(Net.name_of(id))
		if Net.players[id].get("in_race", false) and Net.phase != "lobby":
			tags.append("racing")
		who.text = Net.name_of(id) + ("   (%s)" % ", ".join(tags) if not tags.is_empty() else "")
		CandyText.style(who, 26, CandyText.CHOCOLATE, false)
		row.add_child(who)
		_online_players.add_child(row)
	var host := Net.is_host()
	var bot_text := "no bots" if Net.bots == 0 else ("1 bot" if Net.bots == 1 else "%d bots" % Net.bots)
	var races := "1 race" if Net.rounds == 1 else "%d races" % Net.rounds
	if Net.level < 0:
		_race_info.text = "Next: %s on random levels,  %s" % [races, bot_text]
	else:
		var lvl_title: String = MainGame.LEVELS[clampi(Net.level, 0, MainGame.LEVELS.size() - 1)].new().title
		_race_info.text = "Next: %s, %s level %d  %s,  %s" % [races, "starting on" if Net.rounds > 1 else "on",
			Net.level + 1, lvl_title, bot_text]
	_host_row.visible = host
	_start_button.visible = host
	_ready_button.visible = not host
	if host:
		_level_pick.select(_level_pick.get_item_index(Net.level + 1))
		_rounds_pick.select(maxi(_rounds_pick.get_item_index(Net.rounds), 0))
		var room := Net.max_bots()
		if _bot_pick.item_count != room + 1:
			_bot_pick.clear()
			for k in room + 1:
				_bot_pick.add_item("No bots" if k == 0 else ("1 bot" if k == 1 else "%d bots" % k), k)
		_bot_pick.select(clampi(Net.bots, 0, room))
	var me: Dictionary = Net.players.get(Net.my_id(), {})
	_ready_button.text = "Not ready" if me.get("ready", false) else "I'm ready"
	_start_button.disabled = Net.phase != "lobby" or not Net.all_ready()
	if Net.phase != "lobby":
		_online_waiting.text = "Race %d of %d is on. You're in the next one." % [Net.round_no + 1, Net.rounds] \
			if Net.rounds > 1 else "A race is on. You're in the next one."
	elif host and not not_ready.is_empty():
		_online_waiting.text = "Waiting for %s to be ready." % ", ".join(not_ready)
	elif host and ids.size() == 1:
		_online_waiting.text = "Waiting for players to join. Start now to race the bots."
	elif host:
		_online_waiting.text = "Everyone's ready. Start when you like."
	else:
		_online_waiting.text = "Waiting for %s to start the race." % Net.name_of(Net.host_id)

class_name EditorUI
extends Control
## Panels for the level editor: tool palette on the left, Selected / Level /
## Quest tabs on the right, a top bar and a status line.

const LEFT_W := 300.0
const RIGHT_W := 390.0
const TOP_H := 64.0
const BOTTOM_H := 44.0
const FIELD_W := 200.0

var ed: LevelEditor

var _tool_buttons := {}
var _tool_group := ButtonGroup.new()
var _options: VBoxContainer
var _inspector: VBoxContainer
var _level_box: VBoxContainer
var _quest_box: VBoxContainer
var _tabs: TabContainer
var _hint: Label
var _problem: Label
var _coords: Label
var _level_pick: OptionButton
var _quest_label: Label
var _view_button: Button
var _grid_button: Button
var _undo_button: Button
var _redo_button: Button
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _help: PanelContainer
var _refreshing := false
var _delete_armed := false
var _level_list: ItemList
var _file_dialog: FileDialog
var _guide: PanelContainer
var _guide_label: Label
var _guide_button: Button
var _guide_action := ""
var _guide_hidden := false
var _new_menu: PopupMenu
var _size_caption: Label
var _tool_name: Label
var _pieces_note: Label
var _piece_buttons := {}
var _facing: Label
var _probs_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = CandyTheme.make(19)
	_build_top_bar()
	_build_tools()
	_build_right()
	_build_status()
	_build_guide()
	_build_toast()
	_build_help()
	ed.selection_changed.connect(refresh_inspector)
	ed.level_changed.connect(refresh_level)
	ed.map_changed.connect(refresh_map_info)
	ed.rebuilt.connect(refresh_guide)
	ed.quest_changed.connect(refresh_quest)
	refresh_quest()
	refresh_level()
	refresh_inspector()
	on_tool_changed()
	on_view_changed()
	refresh_guide()


# --- layout ----------------------------------------------------------------------

func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	return p


func _build_top_bar() -> void:
	var bar := _panel(self)
	bar.anchor_right = 1.0
	bar.offset_left = 8
	bar.offset_top = 8
	bar.offset_right = -8
	bar.offset_bottom = TOP_H
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	row.add_child(CandyTheme.heading("Level editor", 28))
	_quest_label = Label.new()
	_quest_label.add_theme_font_override("font", CandyText.FONT_BOLD)
	_quest_label.add_theme_font_size_override("font_size", 20)
	_quest_label.custom_minimum_size.x = 60
	_quest_label.clip_text = true
	_quest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_label.size_flags_stretch_ratio = 0.6
	row.add_child(_quest_label)
	_level_pick = OptionButton.new()
	_level_pick.focus_mode = Control.FOCUS_NONE
	_level_pick.custom_minimum_size.x = 250
	_level_pick.clip_text = true
	_level_pick.fit_to_longest_item = false
	_level_pick.item_selected.connect(func(i: int) -> void:
		if i != ed.li:
			ed.open_level(i))
	row.add_child(_level_pick)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.1
	row.add_child(spacer)
	_undo_button = _btn("Undo", ed.undo, "Ctrl+Z")
	row.add_child(_undo_button)
	_redo_button = _btn("Redo", ed.redo, "Ctrl+Y")
	row.add_child(_redo_button)
	_view_button = _btn("3D view", ed.toggle_view, "Tab: switch between the flat map and the 3D view")
	_view_button.custom_minimum_size.x = 110
	row.add_child(_view_button)
	_grid_button = _btn("Grid", func() -> void:
		ed.set_grid(not ed.show_grid)
		on_view_changed(), "G")
	_grid_button.toggle_mode = true
	_grid_button.theme_type_variation = "ToolButton"
	row.add_child(_grid_button)
	var reach := _btn("Reach", func() -> void: pass, "Shade ground the marble can't roll to from the start, and point at the gap")
	reach.toggle_mode = true
	reach.button_pressed = ed.show_reach
	reach.theme_type_variation = "ToolButton"
	reach.toggled.connect(ed.set_reach)
	row.add_child(reach)
	var anim := _btn("Animate", func() -> void: pass, "Let the monsters and toys move in the preview")
	anim.toggle_mode = true
	anim.theme_type_variation = "ToolButton"
	anim.toggled.connect(ed.set_animate)
	row.add_child(anim)
	var scenery := _btn("Scenery", func() -> void: pass, "Show the clouds and candy scenery around the map")
	scenery.toggle_mode = true
	scenery.button_pressed = true
	scenery.theme_type_variation = "ToolButton"
	scenery.toggled.connect(ed.set_scenery)
	row.add_child(scenery)
	row.add_child(_btn("Help", toggle_help, "F1"))
	row.add_child(_btn("Save", ed.save, "Ctrl+S"))
	var play := _btn("Test play", ed.test_play, "F5: play this level. Esc in the game comes back here.")
	play.add_theme_stylebox_override("normal", _colored(play, Palette.MINT))
	row.add_child(play)
	row.add_child(_btn("From here", func() -> void:
		ed.pending_test = true
		on_tool_changed(), "Test play starting on a tile you click (Shift+F5 over a tile)"))
	row.add_child(_btn("Menu", ed.exit_to_menu, "Save and go back to the quests"))


func _build_tools() -> void:
	var p := _panel(self)
	p.offset_left = 8
	p.offset_top = TOP_H + 10
	p.offset_right = 8 + LEFT_W
	p.anchor_bottom = 1.0
	p.offset_bottom = -BOTTOM_H - 12
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	p.add_child(box)
	var group := ""
	var grid: GridContainer
	for t: Array in LevelEditor.TOOLS:
		if t[2] != group:
			group = t[2]
			box.add_child(CandyTheme.caption(group.to_upper(), 14))
			grid = GridContainer.new()
			grid.columns = 5
			grid.add_theme_constant_override("h_separation", 4)
			grid.add_theme_constant_override("v_separation", 4)
			box.add_child(grid)
		var b := _btn("", func() -> void: ed.set_tool(t[0]), "%s\n%s" % [t[1], t[3]])
		b.toggle_mode = true
		b.button_group = _tool_group
		b.theme_type_variation = "IconButton"
		b.icon = _icon("tool_" + t[0])
		b.expand_icon = true
		b.custom_minimum_size = Vector2(50, 50)
		grid.add_child(b)
		_tool_buttons[t[0]] = b
	box.add_child(HSeparator.new())
	_tool_name = Label.new()
	_tool_name.add_theme_font_override("font", CandyText.FONT_BOLD)
	_tool_name.add_theme_font_size_override("font_size", 22)
	box.add_child(_tool_name)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 6)
	scroll.add_child(_options)


func _icon(icon_name: String) -> Texture2D:
	var path := "res://art/ui/icons/%s.png" % icon_name
	return load(path) if ResourceLoader.exists(path) else null


func _build_right() -> void:
	var p := _panel(self)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = -RIGHT_W - 8
	p.offset_right = -8
	p.offset_top = TOP_H + 10
	p.offset_bottom = -BOTTOM_H - 12
	_tabs = TabContainer.new()
	p.add_child(_tabs)
	for tab_name in ["Pieces", "Selected", "Level", "Quest"]:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tabs.add_child(scroll)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 7)
		scroll.add_child(box)
		match tab_name:
			"Pieces": _build_pieces(box)
			"Selected": _inspector = box
			"Level": _level_box = box
			"Quest": _quest_box = box
	_tabs.current_tab = 0
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE


func _build_status() -> void:
	var bar := _panel(self)
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = -BOTTOM_H - 4
	bar.offset_bottom = -6
	var sb: StyleBoxFlat = bar.get_theme_stylebox("panel").duplicate()
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	_hint = Label.new()
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_hint)
	_problem = Label.new()
	_problem.add_theme_color_override("font_color", Palette.RASPBERRY)
	_problem.add_theme_font_override("font", CandyText.FONT_BOLD)
	row.add_child(_problem)
	_coords = Label.new()
	_coords.custom_minimum_size.x = 200
	_coords.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_coords)


func _build_toast() -> void:
	var c := CenterContainer.new()
	c.anchor_right = 1.0
	c.offset_top = TOP_H + 18
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = CandyTheme._box(Palette.LEMON, Palette.CORAL, 3, 16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	_toast.add_theme_stylebox_override("panel", sb)
	_toast_label = Label.new()
	CandyText.style(_toast_label, 22)
	_toast.add_child(_toast_label)
	_toast.modulate.a = 0.0
	c.add_child(_toast)


func _build_help() -> void:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_help = PanelContainer.new()
	_help.visible = false
	c.add_child(_help)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_help.add_child(box)
	box.add_child(CandyTheme.heading("How the editor works", 34))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	box.add_child(cols)
	var left := [
		["Left click / drag", "use the tool"],
		["Right click", "remove the thing under the mouse"],
		["Right / middle drag", "move the view"],
		["Wheel", "zoom"],
		["WASD / arrows", "move the view"],
		["Tab", "flat map / 3D view"],
		["Q / E", "turn the 3D view"],
		["F", "fit the map in view"],
		["G", "grid on / off"],
	]
	var right := [
		["0 - 9", "ground height"],
		["[ and ]", "brush size"],
		["R  (Shift+R)", "turn 90 (45) degrees; pieces: right (left)"],
		["Shift + click", "place on half tiles"],
		["Del", "delete the selected thing"],
		["Ctrl+D", "duplicate it"],
		["Ctrl+Z / Ctrl+Y", "undo / redo"],
		["Ctrl+S", "save"],
		["F5 / Shift+F5", "test play / from the tile under the mouse"],
	]
	for list: Array in [left, right]:
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 18)
		g.add_theme_constant_override("v_separation", 4)
		cols.add_child(g)
		for pair: Array in list:
			var k := Label.new()
			k.text = pair[0]
			k.add_theme_font_override("font", CandyText.FONT_BOLD)
			k.add_theme_color_override("font_color", Palette.RASPBERRY)
			g.add_child(k)
			var v := Label.new()
			v.text = pair[1]
			g.add_child(v)
	var tips := Label.new()
	tips.text = "Tips: paint past the edge of the map to make it bigger. Walls are just higher ground next to lower ground.\nA ramp between two heights is a slope; a ramp running into void is a jump. Cannons and catapults: click again to set the landing spot.\nThe Level tab has the name, description, par time, race mode, colours and the speed and colour of every monster.\nThe Quest tab holds all levels of your quest and the share buttons."
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.custom_minimum_size.x = 820
	box.add_child(tips)
	var close := _btn("Got it", toggle_help)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(close)


## Next-step card above the status line.
func _build_guide() -> void:
	var c := CenterContainer.new()
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.anchor_right = 1.0
	c.offset_left = LEFT_W + 16
	c.offset_right = -RIGHT_W - 16
	c.offset_top = -BOTTOM_H - 96
	c.offset_bottom = -BOTTOM_H - 14
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_guide = PanelContainer.new()
	var sb: StyleBoxFlat = CandyTheme._box(Color("#FFF4E0"), Color("#35B37E"), 3, 16)
	sb.content_margin_left = 14
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0.2, 0.3, 0.2, 0.25)
	sb.shadow_size = 6
	_guide.add_theme_stylebox_override("panel", sb)
	c.add_child(_guide)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_guide.add_child(row)
	var tag := Label.new()
	tag.text = "NEXT"
	tag.add_theme_font_override("font", CandyText.FONT_BOLD)
	tag.add_theme_color_override("font_color", Color("#35B37E"))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	_guide_label = Label.new()
	_guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide_label.custom_minimum_size.x = 440
	_guide_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guide_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_guide_label)
	_guide_button = _btn("", func() -> void: ed.guide_action(_guide_action))
	_guide_button.add_theme_stylebox_override("normal", _colored(_guide_button, Palette.MINT))
	_guide_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_guide_button)
	var close := _btn("x", func() -> void:
		_guide_hidden = true
		_guide.visible = false, "Hide the guide (Help shows it again)")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(close)


func refresh_guide() -> void:
	if _guide == null or ed.built == null:
		return
	var g := ed.guide()
	_guide_label.text = g[0]
	_guide_button.text = g[1]
	_guide_action = g[2]
	_guide.visible = not _guide_hidden


func show_tab(i: int) -> void:
	_tabs.current_tab = i


func toggle_help() -> void:
	if _help.visible:
		_guide_hidden = false
		refresh_guide()
	_help.visible = not _help.visible


func toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


# --- small builders ------------------------------------------------------------------

func _btn(text: String, action: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.pressed.connect(action)
	return b


func _colored(_b: Control, col: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = theme.get_stylebox("normal", "Button").duplicate()
	sb.bg_color = col
	return sb


func _label(text: String, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 100
	return l


func _row(parent: Control, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := _label(caption)
	l.custom_minimum_size.x = 130
	l.clip_text = true
	row.add_child(l)
	parent.add_child(row)
	return row


func _slider(parent: Control, caption: String, lo: float, hi: float, step: float, value: float,
		on_change: Callable, fmt: String = "%.1f") -> HSlider:
	var row := _row(parent, caption)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := _label(fmt % value)
	v.custom_minimum_size.x = 52
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = fmt % x
		if not _refreshing:
			on_change.call(x))
	return s


## Colour row. `value` "" = none (model colours) when `allow_none`.
func _color(parent: Control, caption: String, value: String, on_change: Callable, allow_none: bool = false,
		fallback: Color = Palette.PINK) -> ColorPickerButton:
	var row := _row(parent, caption)
	var c := ColorPickerButton.new()
	c.focus_mode = Control.FOCUS_NONE
	c.edit_alpha = false
	c.custom_minimum_size = Vector2(90, 30)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.color = Color(value) if value != "" else fallback
	row.add_child(c)
	var none: Button
	if allow_none:
		none = _btn("Own" if value != "" else "Own", func() -> void: pass,
			"Use the model's own colours")
		none.toggle_mode = true
		none.theme_type_variation = "ToolButton"
		none.button_pressed = value == ""
		none.toggled.connect(func(on: bool) -> void:
			if _refreshing:
				return
			on_change.call("" if on else "#" + c.color.to_html(false)))
		row.add_child(none)
	c.color_changed.connect(func(col: Color) -> void:
		if none:
			none.set_pressed_no_signal(false)
		on_change.call("#" + col.to_html(false)))
	return c


func _line(parent: Control, caption: String, value: String, max_len: int, on_change: Callable) -> LineEdit:
	parent.add_child(CandyTheme.caption(caption))
	var e := LineEdit.new()
	e.text = value
	e.max_length = max_len
	e.text_changed.connect(func(t: String) -> void: on_change.call(t))
	e.text_submitted.connect(func(_t: String) -> void: e.release_focus())
	parent.add_child(e)
	return e


func _text_box(parent: Control, caption: String, value: String, max_len: int, on_change: Callable) -> TextEdit:
	parent.add_child(CandyTheme.caption(caption))
	var e := TextEdit.new()
	e.text = value
	e.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	e.custom_minimum_size.y = 84
	e.text_changed.connect(func() -> void:
		if e.text.length() > max_len:
			e.text = e.text.substr(0, max_len)
		on_change.call(e.text))
	parent.add_child(e)
	return e


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


# --- tool options ------------------------------------------------------------------

func on_tool_changed() -> void:
	for id: String in _tool_buttons:
		(_tool_buttons[id] as Button).set_pressed_no_signal(id == ed.tool)
	_hint.text = ed.tool_hint()
	_clear(_options)
	var t := ed.tool
	for tt: Array in LevelEditor.TOOLS:
		if tt[0] == t:
			_tool_name.text = tt[1]
	_refresh_pieces()
	var info := _label(ed.tool_hint(), true)
	info.add_theme_font_size_override("font_size", 17)
	_options.add_child(info)
	if t == "sections":
		_tabs.current_tab = 0
	if t == "road":
		_options.add_child(CandyTheme.caption("Lane width"))
		var wr := HBoxContainer.new()
		_options.add_child(wr)
		for k in [2, 3, 4, 5, 6]:
			var b := _btn(str(k), func() -> void:
				ed.road_width = k
				on_tool_changed())
			b.toggle_mode = true
			b.theme_type_variation = "ToolButton"
			b.button_pressed = ed.road_width == k
			b.custom_minimum_size.x = 44
			wr.add_child(b)
		var rails := CheckBox.new()
		rails.text = "Rails along the sides"
		rails.focus_mode = Control.FOCUS_NONE
		rails.button_pressed = ed.road_rails
		rails.toggled.connect(func(on: bool) -> void: ed.road_rails = on)
		_options.add_child(rails)
		_options.add_child(_label("Start on ground to keep its height, or on void to use the height below. Drag into other ground to join it: walls open and a ramp is added if the heights differ. Sections continue from where the road ends.", true))
	if t in ["paint", "box", "fill", "road"]:
		_options.add_child(CandyTheme.caption("Height  (keys 0-9)"))
		var g := GridContainer.new()
		g.columns = 5
		g.add_theme_constant_override("h_separation", 4)
		g.add_theme_constant_override("v_separation", 4)
		_options.add_child(g)
		var tiers: Array = ed.lv.theme.tiers
		for k in 10:
			var b := _btn(str(k), func() -> void:
				ed.tier = k
				on_tool_changed())
			b.toggle_mode = true
			b.button_pressed = ed.tier == k
			b.custom_minimum_size = Vector2(48, 34)
			var sb: StyleBoxFlat = theme.get_stylebox("normal", "Button").duplicate()
			sb.bg_color = Color(tiers[k % tiers.size()])
			sb.border_color = Palette.RASPBERRY if ed.tier == k else Color(1, 1, 1, 0.8)
			sb.set_border_width_all(4 if ed.tier == k else 2)
			for st in ["normal", "hover", "pressed", "hover_pressed"]:
				b.add_theme_stylebox_override(st, sb)
			g.add_child(b)
		_options.add_child(_label("Each step is half a marble high. A tile next to a higher one is a wall.", true))
	if t in ["paint", "raise", "lower", "ramp", "erase", "waves", "hill", "trench", "goo", "humps", "ice", "clear"]:
		_options.add_child(CandyTheme.caption("Brush  ([ and ])"))
		var row := HBoxContainer.new()
		_options.add_child(row)
		for k in [1, 2, 3, 4]:
			var b := _btn("%dx%d" % [k * 2 - 1, k * 2 - 1], func() -> void:
				ed.brush = k
				on_tool_changed())
			b.toggle_mode = true
			b.theme_type_variation = "ToolButton"
			b.button_pressed = ed.brush == k
			row.add_child(b)
	if t == "box":
		var walls := CheckBox.new()
		walls.text = "Walls around the edge"
		walls.focus_mode = Control.FOCUS_NONE
		walls.button_pressed = ed.box_walls
		walls.toggled.connect(func(on: bool) -> void: ed.box_walls = on)
		_options.add_child(walls)
	if t == "ramp":
		_options.add_child(CandyTheme.caption("Uphill towards (flat map view)"))
		var g := GridContainer.new()
		g.columns = 3
		_options.add_child(g)
		for pair: Array in [["auto", "Auto"], ["n", "Up"], ["s", "Down"], ["w", "Left"], ["e", "Right"],
				["a", "Up-left"], ["b", "Up-right"], ["c", "Down-left"], ["d", "Down-right"]]:
			var b := _btn(pair[1], func() -> void:
				ed.ramp_dir = pair[0]
				on_tool_changed())
			b.toggle_mode = true
			b.theme_type_variation = "ToolButton"
			b.button_pressed = ed.ramp_dir == pair[0]
			g.add_child(b)
		_options.add_child(_label("Auto slopes up towards the higher side. Several ramp tiles in a row make a longer, gentler slope. Diagonal ramps need a band of two or more between two heights.", true))
	if t == "booster":
		_options.add_child(CandyTheme.caption("Pushes towards  (R turns)"))
		var g := GridContainer.new()
		g.columns = 4
		_options.add_child(g)
		for pair: Array in [["^", "Up"], ["v", "Down"], ["<", "Left"], [">", "Right"]]:
			var b := _btn(pair[1], func() -> void:
				ed.booster_dir = pair[0]
				on_tool_changed())
			b.toggle_mode = true
			b.theme_type_variation = "ToolButton"
			b.button_pressed = ed.booster_dir == pair[0]
			g.add_child(b)
	if t == "decor":
		var g := GridContainer.new()
		g.columns = 2
		_options.add_child(g)
		for pair: Array in LevelEditor.DECOR:
			var b := _btn(pair[1], func() -> void:
				ed.decor_char = pair[0]
				on_tool_changed())
			b.toggle_mode = true
			b.theme_type_variation = "ToolButton"
			b.button_pressed = ed.decor_char == pair[0]
			b.custom_minimum_size.x = 130
			g.add_child(b)
	if t == "route":
		var row := HBoxContainer.new()
		_options.add_child(row)
		row.add_child(_btn("Auto path", ed.auto_path, "Find a way from the start to the hole"))
		row.add_child(_btn("Clear", ed.clear_path, "No path: the game finds one by itself"))
		_options.add_child(_label("Solid purple = your path. Faded = the path the game found by itself. The rival follows it in race levels and the camera turns along it.", true))
	if t in ["enemy", "stomper", "hopper", "ghost", "windmill"]:
		_options.add_child(_label("After placing, the Selected tab has its speed and colour. The Level tab changes all monsters at once.", true))


## Pieces tab: thumbnails of every ready-made section.
func _build_pieces(box: VBoxContainer) -> void:
	_pieces_note = _label("", true)
	_pieces_note.add_theme_font_size_override("font_size", 17)
	box.add_child(_pieces_note)
	# Turn the piece before clicking it onto the map.
	var turn := HBoxContainer.new()
	turn.add_theme_constant_override("separation", 6)
	box.add_child(turn)
	turn.add_child(_btn("Turn left", func() -> void: ed.turn_section(-1), "Shift+R"))
	_facing = _label("")
	_facing.add_theme_font_override("font", CandyText.FONT_BOLD)
	_facing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn.add_child(_facing)
	turn.add_child(_btn("Turn right", func() -> void: ed.turn_section(1), "R or right click"))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	box.add_child(g)
	for p: Array in TrackPieces.LIST:
		var b := _btn(p[1], func() -> void:
			ed.add_section(p[0])
			on_tool_changed(), "%s\n%s" % [p[1], p[3]])
		b.toggle_mode = true
		b.theme_type_variation = "IconButton"
		b.icon = _icon("piece_" + p[0])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(84, 80)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 13)
		g.add_child(b)
		_piece_buttons[p[0]] = b


func _refresh_pieces() -> void:
	if _pieces_note == null:
		return
	var has_end := not ed.track_end().is_empty()
	var dirs := ["right", "down", "left", "up"]
	_pieces_note.text = ("Click a piece to add it at the green arrow." if has_end
		else "No open track end: pick a piece, then click the map to put it down.") \
		+ "  Or click the map to place it anywhere; the arrow on the preview shows which way it runs."
	_facing.text = "Facing %s" % dirs[ed.section_heading]
	_pieces_note.add_theme_color_override("font_color", Color("#2E8B62") if has_end else Palette.CORAL)
	for id: String in _piece_buttons:
		(_piece_buttons[id] as Button).set_pressed_no_signal(ed.tool == "sections" and ed.section_id == id)


func on_view_changed() -> void:
	_view_button.text = "Flat map" if not ed.top_view else "3D view"
	_grid_button.set_pressed_no_signal(ed.show_grid)


func on_hover(tile: Vector2i) -> void:
	var c := ed.hchar(tile.x, tile.y)
	var what := "void"
	if c.is_valid_int():
		what = "height %s" % c
	elif LevelBase.DIAG.has(c):
		what = "diagonal ramp"
	elif c in LevelBase.RAMPS:
		what = "ramp"
	var o := ed.ochar(tile.x, tile.y)
	if o != "." and LevelEditor.OBJ_NAMES.has(o):
		what += ", " + LevelEditor.OBJ_NAMES[o].to_lower()
	_coords.text = "%d, %d   %s" % [tile.x, tile.y, what]


func _process(_delta: float) -> void:
	if _undo_button:
		_undo_button.disabled = not ed.can_undo()
		_redo_button.disabled = not ed.can_redo()


# --- Selected tab ---------------------------------------------------------------------

func refresh_inspector() -> void:
	_clear(_inspector)
	var e := ed.selected_extra()
	var ch := ed.selected_char()
	if e.is_empty() and ch == "":
		_inspector.add_child(CandyTheme.heading("Nothing selected", 26))
		_inspector.add_child(_label("Pick the Select tool and click something on the map, or place something new. Its settings show up here: speed, colour, direction and more.", true))
		return
	if not e.is_empty():
		_tabs.current_tab = 1
		_inspector_extra(e)
	else:
		_tabs.current_tab = 1
		_inspector_char(ch)


func _inspector_extra(e: Dictionary) -> void:
	var type: String = e.type
	_inspector.add_child(CandyTheme.heading(LevelEditor.EXTRA_NAMES.get(type, type), 28))
	var tile_text := "Tile %s, %s" % [str(e.tile[0]).trim_suffix(".0"), str(e.tile[1]).trim_suffix(".0")]
	_inspector.add_child(CandyTheme.caption(tile_text))
	var monster := type in CustomLevel.MONSTERS
	if type not in ["ghost", "catapult", "cannon"]:
		_slider(_inspector, "Direction", 0, 345, 15, e.get("yaw", 0.0), func(v: float) -> void:
			ed.set_extra_value("yaw", v), "%.0f°")
	var params: Dictionary = CustomLevel.EXTRA_PARAMS[type]
	for key: String in params:
		var spec: Array = params[key]
		var cur: float = e.get(key, spec[0])
		var is_int: bool = spec[0] is int
		var step := 1.0 if is_int else (0.05 if absf(spec[2] - spec[1]) <= 5.0 else 0.1)
		_slider(_inspector, spec[3], spec[1], spec[2], step, cur, func(v: float) -> void:
			ed.set_extra_value(key, int(v) if is_int else v), "%d" if is_int else "%.2f")
	if type in CustomLevel.HAS_TRAVEL:
		_inspector.add_child(CandyTheme.caption("Walks this many tiles (drag when placing)"))
		for axis in [0, 2]:
			var row := _row(_inspector, "Across" if axis == 0 else "Down")
			var sp := SpinBox.new()
			sp.min_value = -30
			sp.max_value = 30
			sp.step = 0.5
			sp.value = e.travel[axis] / LevelBase.TILE
			sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sp.value_changed.connect(func(v: float) -> void:
				var t: Array = (ed.selected_extra().travel as Array).duplicate()
				t[axis] = v * LevelBase.TILE
				ed.set_extra_value("travel", t))
			row.add_child(sp)
	if type in CustomLevel.HAS_TARGET:
		_inspector.add_child(CandyTheme.caption("Lands on tile %s, %s" % [str(e.target_tile[0]).trim_suffix(".0"),
			str(e.target_tile[1]).trim_suffix(".0")]))
		_inspector.add_child(_btn("Pick landing spot", ed.pick_target, "Then click on the map"))
	if monster:
		_inspector.add_child(HSeparator.new())
		var level_tint: String = ed.lv.monster_tint
		_color(_inspector, "Colour", e.get("tint", ""), func(v: String) -> void:
			ed.set_extra_value("tint", v if v != "" else null),
			true, Color(level_tint) if level_tint != "" else Palette.RASPBERRY)
		_inspector.add_child(_label("\"Own\" keeps the level's monster colour (Level tab), or the model's.", true))
	else:
		_inspector.add_child(HSeparator.new())
		_color(_inspector, "Colour", e.get("tint", ""), func(v: String) -> void:
			ed.set_extra_value("tint", v if v != "" else null), true)
	_inspector.add_child(HSeparator.new())
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	_inspector.add_child(row2)
	row2.add_child(_btn("Turn", func() -> void: ed.rotate_selection(90.0), "R"))
	row2.add_child(_btn("Duplicate", ed.duplicate_selection, "Ctrl+D"))
	var del := _btn("Delete", ed.delete_selection, "Del")
	del.add_theme_color_override("font_color", Palette.RASPBERRY)
	row2.add_child(del)


func _inspector_char(ch: String) -> void:
	_inspector.add_child(CandyTheme.heading(LevelEditor.OBJ_NAMES.get(ch, "Object"), 28))
	var t: Vector2i = ed.selection.tile
	_inspector.add_child(CandyTheme.caption("Tile %d, %d" % [t.x, t.y]))
	var about := {
		"S": "The marble starts here.", "G": "Roll in here to finish the level.",
		"C": "Saves progress. It spans the whole track across.", "K": "Saves progress. It spans the whole track across.",
		"B": "Bounces the marble away and fills the Sugar Rush meter.",
		"W": "Wobbly ripples. Neighbouring wave tiles blend together.",
		"H": "A round bump.", "P": "A tall cone the marble can't climb.", "T": "A dip. Neighbouring trench tiles join into a channel.",
		"A": "Sour goo. Rolling in pops the marble.",
		"I": "Ice: hardly any grip.",
		"M": "Big humps. A strip of hump tiles makes whole humps along its long side.",
	}
	if BOOSTER_TEXT.has(ch):
		_inspector.add_child(_label("Speed pad pushing %s." % BOOSTER_TEXT[ch], true))
	elif about.has(ch):
		_inspector.add_child(_label(about[ch], true))
	else:
		_inspector.add_child(_label("Candy scenery. The marble bumps into it.", true))
	_inspector.add_child(_label("Drag it with the Select tool to move it.", true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_inspector.add_child(row)
	if BOOSTER_TEXT.has(ch) or ch in ["C", "K"]:
		row.add_child(_btn("Turn", func() -> void: ed.rotate_selection(90.0), "R"))
	var del := _btn("Delete", ed.delete_selection, "Del")
	del.add_theme_color_override("font_color", Palette.RASPBERRY)
	row.add_child(del)


const BOOSTER_TEXT := {">": "right", "<": "left", "v": "down", "^": "up"}


# --- Level tab --------------------------------------------------------------------------

func refresh_level() -> void:
	_refreshing = true
	_clear(_level_box)
	var lv := ed.lv
	_line(_level_box, "LEVEL NAME", lv.title, 40, func(t: String) -> void:
		ed.set_level_value("title", t if t.strip_edges() != "" else "Untitled"))
	_text_box(_level_box, "DESCRIPTION  (shown when the level starts)", lv.description, 400, func(t: String) -> void:
		ed.set_level_value("description", t))
	var par_row := _row(_level_box, "Par time (s)")
	var par := SpinBox.new()
	par.min_value = 5
	par.max_value = 900
	par.step = 1
	par.value = lv.par
	par.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	par.value_changed.connect(func(v: float) -> void: ed.set_level_value("par", v))
	par_row.add_child(par)
	par_row.add_child(_btn("Guess", func() -> void:
		par.value = ed.estimate_par(), "Guess from the length of the path"))
	_level_box.add_child(_label("Gold medal at par, silver at 1.3x, bronze at 1.7x.", true))

	_slider(_level_box, "Step height", 0.25, 1.5, 0.05, lv.get("step", 0.5), func(v: float) -> void:
		ed.set_level_value("step", v), "%.2f")
	_level_box.add_child(_label("How tall one height step is. Taller steps make taller cliffs and steeper ramps.", true))
	_slider(_level_box, "Hard landings", 0, 12, 1, lv.get("break_drop", 0), func(v: float) -> void:
		ed.set_level_value("break_drop", int(v)), "%d")
	_level_box.add_child(_label("Marble Madness rule: the marble breaks on drops higher than this many steps. 0 = never.", true))
	_level_box.add_child(HSeparator.new())
	_level_box.add_child(CandyTheme.caption("RACE"))
	var race := CheckBox.new()
	race.text = "Race the licorice ball"
	race.focus_mode = Control.FOCUS_NONE
	race.button_pressed = lv.race
	race.toggled.connect(func(on: bool) -> void:
		ed.set_level_value("race", on)
		ed.mark_edited())
	_level_box.add_child(race)
	var silly := CheckBox.new()
	silly.text = "Silly level: slopes push uphill, monsters are harmless"
	silly.focus_mode = Control.FOCUS_NONE
	silly.button_pressed = lv.get("silly", false)
	silly.toggled.connect(func(on: bool) -> void:
		ed.set_level_value("silly", on)
		ed.mark_edited())
	_level_box.add_child(silly)
	_slider(_level_box, "Rival speed", 0.5, 1.6, 0.05, lv.rival_speed, func(v: float) -> void:
		ed.set_level_value("rival_speed", v), "%.2fx")
	_color(_level_box, "Rival colour", lv.rival_tint, func(v: String) -> void:
		ed.set_level_value("rival_tint", v), true, Color("#1E1418"))

	_level_box.add_child(HSeparator.new())
	_level_box.add_child(CandyTheme.caption("ALL MONSTERS"))
	_slider(_level_box, "Speed", 0.25, 3.0, 0.05, lv.monster_speed, func(v: float) -> void:
		ed.set_level_value("monster_speed", v), "%.2fx")
	_color(_level_box, "Colour", lv.monster_tint, func(v: String) -> void:
		ed.set_level_value("monster_tint", v), true, Palette.RASPBERRY)
	_level_box.add_child(_label("Each monster can also get its own colour in the Selected tab.", true))

	_level_box.add_child(HSeparator.new())
	_level_box.add_child(CandyTheme.caption("COLOURS"))
	var theme_row := _row(_level_box, "Theme")
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.fit_to_longest_item = false
	pick.add_item("Pick a theme...")
	for n: String in CustomLevel.THEMES:
		pick.add_item(n)
	pick.item_selected.connect(func(i: int) -> void:
		if i > 0:
			ed.apply_theme(pick.get_item_text(i)))
	theme_row.add_child(pick)
	var tiers_row := _row(_level_box, "Ground")
	for k in 5:
		var c := ColorPickerButton.new()
		c.focus_mode = Control.FOCUS_NONE
		c.edit_alpha = false
		c.custom_minimum_size = Vector2(36, 30)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.color = Color(lv.theme.tiers[k])
		c.tooltip_text = "Heights %d and %d" % [k, k + 5]
		c.popup_closed.connect(func() -> void:
			var tiers: Array = (ed.lv.theme.tiers as Array).duplicate()
			tiers[k] = "#" + c.color.to_html(false)
			ed.set_theme_value("tiers", tiers))
		tiers_row.add_child(c)
	for pair: Array in [["ramp", "Ramps"], ["wall", "Walls"]]:
		var c2 := _color(_level_box, pair[1], lv.theme[pair[0]], func(_v: String) -> void: pass)
		c2.popup_closed.connect(func() -> void:
			ed.set_theme_value(pair[0], "#" + c2.color.to_html(false)))

	_level_box.add_child(HSeparator.new())
	_size_caption = CandyTheme.caption("")
	_level_box.add_child(_size_caption)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	_level_box.add_child(g)
	for spec: Array in [["+ Left", [1, 0, 0, 0]], ["+ Right", [0, 0, 1, 0]], ["+ Top", [0, 1, 0, 0]], ["+ Bottom", [0, 0, 0, 1]],
			["- Left", [-1, 0, 0, 0]], ["- Right", [0, 0, -1, 0]], ["- Top", [0, -1, 0, 0]], ["- Bottom", [0, 0, 0, -1]]]:
		var d: Array = spec[1]
		var b := _btn(spec[0], func() -> void:
			ed.push_undo()
			ed.resize(d[0] * 4, d[1] * 4, d[2] * 4, d[3] * 4), "Grow or shrink by 4 tiles")
		b.add_theme_font_size_override("font_size", 16)
		g.add_child(b)
	var row := HBoxContainer.new()
	_level_box.add_child(row)
	row.add_child(_btn("Crop to fit", ed.crop, "Cut away empty rows and columns"))
	row.add_child(_btn("Fit view", ed.frame_level, "F"))

	_probs_box = VBoxContainer.new()
	_level_box.add_child(_probs_box)
	refresh_map_info()
	_refresh_level_pick()
	_refreshing = false


## Map size and problems: cheap, runs after every stroke.
func refresh_map_info() -> void:
	if _size_caption:
		_size_caption.text = "MAP SIZE  %d x %d tiles" % [ed.cols(), ed.rows()]
	var probs := ed.problems()
	_problem.text = probs[0] if probs.size() > 0 else ""
	_problem.tooltip_text = "\n".join(probs)
	if _probs_box == null:
		return
	_clear(_probs_box)
	if probs.size() > 0:
		_probs_box.add_child(HSeparator.new())
		_probs_box.add_child(CandyTheme.caption("TO FIX"))
		for p in probs:
			var l := _label(p, true)
			l.add_theme_color_override("font_color", Palette.RASPBERRY)
			_probs_box.add_child(l)


# --- Quest tab --------------------------------------------------------------------------

func refresh_quest() -> void:
	_refreshing = true
	_clear(_quest_box)
	var q := ed.quest
	_quest_label.text = q.name
	_line(_quest_box, "QUEST NAME", q.name, 48, func(t: String) -> void:
		q.name = t if t.strip_edges() != "" else "Untitled quest"
		_quest_label.text = q.name
		ed.unsaved = true)
	_line(_quest_box, "MADE BY", q.author, 40, func(t: String) -> void:
		q.author = t
		ed.unsaved = true)
	_text_box(_quest_box, "DESCRIPTION", q.description, 600, func(t: String) -> void:
		q.description = t
		ed.unsaved = true)

	_quest_box.add_child(HSeparator.new())
	_quest_box.add_child(CandyTheme.caption("LEVELS  (played in this order)"))
	_level_list = ItemList.new()
	_level_list.custom_minimum_size.y = 150
	_level_list.focus_mode = Control.FOCUS_NONE
	for k in q.levels.size():
		_level_list.add_item("%d.  %s%s" % [k + 1, q.levels[k].title, "   (race)" if q.levels[k].race else ""])
	_level_list.select(ed.li)
	_level_list.item_selected.connect(func(i: int) -> void:
		if i != ed.li:
			ed.open_level(i))
	_quest_box.add_child(_level_list)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 5)
	g.add_theme_constant_override("v_separation", 5)
	_quest_box.add_child(g)
	var nl := _btn("New level", func() -> void: pass, "Pick how the new level starts")
	nl.pressed.connect(func() -> void:
		_new_menu.position = Vector2i(nl.get_screen_position() + Vector2(0, nl.size.y))
		_new_menu.popup())
	g.add_child(nl)
	if _new_menu == null:
		_new_menu = PopupMenu.new()
		_new_menu.add_item("Guided track (start pad + sections)", 0)
		_new_menu.add_item("Open island", 1)
		_new_menu.add_item("Empty sky", 2)
		_new_menu.id_pressed.connect(func(id: int) -> void: _add_level(["track", "island", "empty"][id]))
		add_child(_new_menu)
	g.add_child(_btn("Copy", _copy_level, "Duplicate this level"))
	var del := _btn("Delete", func() -> void: pass)
	del.pressed.connect(func() -> void: _delete_level(del))
	g.add_child(del)
	g.add_child(_btn("Move up", func() -> void: _move_level(-1)))
	g.add_child(_btn("Move down", func() -> void: _move_level(1)))
	var remix := OptionButton.new()
	remix.focus_mode = Control.FOCUS_NONE
	remix.fit_to_longest_item = false
	remix.clip_text = true
	remix.add_item("Remix...")
	remix.tooltip_text = "Add a copy of a built-in level to change"
	for k in MainGame.LEVELS.size():
		var src: LevelBase = MainGame.LEVELS[k].new()
		remix.add_item("%d  %s" % [k + 1, src.title])
	remix.item_selected.connect(func(i: int) -> void:
		if i > 0:
			_remix(i - 1))
	g.add_child(remix)
	for b in g.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(b as Control).custom_minimum_size.x = 0

	_quest_box.add_child(HSeparator.new())
	_quest_box.add_child(CandyTheme.caption("SHARE"))
	_quest_box.add_child(_btn("Copy share code", _copy_code, "One line of text. Friends paste it in Quests > Paste code"))
	_quest_box.add_child(_btn("Save as file...", _export_file, "A .candyquest file. Friends drop it on the game window"))
	_quest_box.add_child(_btn("Open quest folder", func() -> void: OS.shell_open(Quest.folder()),
		"Quest files copied into this folder are installed"))

	_quest_box.add_child(HSeparator.new())
	_quest_box.add_child(CandyTheme.caption("OTHER QUESTS"))
	var open := OptionButton.new()
	open.focus_mode = Control.FOCUS_NONE
	open.clip_text = true
	open.fit_to_longest_item = false
	open.add_item("Open another quest...")
	var installed := Quest.list_installed()
	for other in installed:
		open.add_item(other.name)
	open.item_selected.connect(func(i: int) -> void:
		if i > 0:
			ed.save_if_changed()
			ed.open_quest(Quest.find(installed[i - 1].id)))
	_quest_box.add_child(open)
	_quest_box.add_child(_btn("Start a new quest", func() -> void:
		ed.save_if_changed()
		var nq := Quest.create()
		nq.levels = [LevelEditor.template("track", "Level 1")]
		nq.author = ed.quest.author
		nq.save()
		ed.open_quest(nq)
		toast("New quest started")))
	_refresh_level_pick()
	_refreshing = false


func _refresh_level_pick() -> void:
	if _level_pick == null:
		return
	_level_pick.clear()
	for k in ed.quest.levels.size():
		_level_pick.add_item("Level %d: %s" % [k + 1, ed.quest.levels[k].title])
	_level_pick.select(ed.li)
	if _level_list and _level_list.item_count == ed.quest.levels.size():
		_level_list.set_item_text(ed.li, "%d.  %s%s" % [ed.li + 1, ed.lv.title, "   (race)" if ed.lv.race else ""])


func _add_level(kind: String = "track") -> void:
	if ed.quest.levels.size() >= Quest.MAX_LEVELS:
		toast("A quest can have %d levels" % Quest.MAX_LEVELS)
		return
	ed.quest.levels.insert(ed.li + 1, LevelEditor.template(kind, "Level %d" % (ed.quest.levels.size() + 1)))
	ed.unsaved = true
	ed.open_level(ed.li + 1)
	refresh_quest()


func _copy_level() -> void:
	if ed.quest.levels.size() >= Quest.MAX_LEVELS:
		return
	var c: Dictionary = ed.lv.duplicate(true)
	c.title = (c.title + " copy").substr(0, 40)
	ed.quest.levels.insert(ed.li + 1, c)
	ed.unsaved = true
	ed.open_level(ed.li + 1)
	refresh_quest()


func _delete_level(b: Button) -> void:
	if ed.quest.levels.size() <= 1:
		toast("A quest needs at least one level")
		return
	if not _delete_armed:
		_delete_armed = true
		b.text = "Sure?"
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			_delete_armed = false
			if is_instance_valid(b):
				b.text = "Delete")
		return
	_delete_armed = false
	ed.quest.levels.remove_at(ed.li)
	ed.unsaved = true
	ed.open_level(clampi(ed.li, 0, ed.quest.levels.size() - 1))
	refresh_quest()
	toast("Level deleted")


func _move_level(d: int) -> void:
	var to := ed.li + d
	if to < 0 or to >= ed.quest.levels.size():
		return
	var l: Dictionary = ed.quest.levels[ed.li]
	ed.quest.levels.remove_at(ed.li)
	ed.quest.levels.insert(to, l)
	ed.li = to
	ed.unsaved = true
	refresh_quest()


func _remix(index: int) -> void:
	if ed.quest.levels.size() >= Quest.MAX_LEVELS:
		return
	var d := CustomLevel.dict_from_level(MainGame.LEVELS[index].new())
	d.title = (d.title + " remix").substr(0, 40)
	ed.quest.levels.insert(ed.li + 1, d)
	ed.unsaved = true
	ed.open_level(ed.li + 1)
	refresh_quest()
	toast("Copied \"%s\" into your quest" % d.title)


func _copy_code() -> void:
	ed.quest.save()
	var code := ed.quest.share_code()
	DisplayServer.clipboard_set(code)
	toast("Share code copied (%d characters). Paste it anywhere." % code.length())


func _export_file() -> void:
	ed.quest.save()
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.use_native_dialog = true
		_file_dialog.filters = PackedStringArray(["*.candyquest ; Candy Marble quest"])
		_file_dialog.file_selected.connect(func(path: String) -> void:
			if not path.ends_with(".candyquest"):
				path += ".candyquest"
			if ed.quest.write_to(path) == OK:
				toast("Saved %s" % path.get_file())
			else:
				toast("Couldn't write %s" % path))
		add_child(_file_dialog)
	_file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_file_dialog.current_file = ed.quest.file_name()
	_file_dialog.popup_centered(Vector2i(900, 600))

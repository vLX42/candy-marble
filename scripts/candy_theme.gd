class_name CandyTheme
## The cream-and-pink UI theme shared by the menus, the quest browser and the
## level editor. `size` is the button font size; the editor uses a small one.


static func make(size: int = 38) -> Theme:
	var t := Theme.new()
	var small := size < 30
	var radius := 14 if small else 26
	var border := 3 if small else 5
	t.default_font = CandyText.FONT
	t.default_font_size = maxi(18, size - 8) if small else 26

	var normal := _box(Color("#FFF4E0"), Palette.PINK, border, radius)
	normal.content_margin_left = 12 if small else 28
	normal.content_margin_right = 12 if small else 28
	normal.content_margin_top = 5 if small else 10
	normal.content_margin_bottom = 6 if small else 12
	normal.shadow_color = Color(0.78, 0.13, 0.31, 0.25)
	normal.shadow_size = 3 if small else 6
	normal.shadow_offset = Vector2(0, 3 if small else 5)
	var hover := normal.duplicate()
	hover.bg_color = Palette.LEMON
	hover.border_color = Palette.CORAL
	var pressed := normal.duplicate()
	pressed.bg_color = Palette.PINK
	var disabled := normal.duplicate()
	disabled.bg_color = Color("#E9E1EC")
	disabled.border_color = Color("#CBBFD4")
	for type in ["Button", "OptionButton", "ColorPickerButton", "MenuButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("focus", type, StyleBoxEmpty.new() if small else hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_font("font", type, CandyText.FONT_BOLD)
		t.set_font_size("font_size", type, size)
		for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			t.set_color(c, type, CandyText.CHOCOLATE)
		t.set_color("font_disabled_color", type, Color("#8A7E90"))

	# Toggle buttons in the editor: a picked tool is mint.
	var on := normal.duplicate()
	on.bg_color = Palette.MINT
	on.border_color = Color("#4FB58A")
	t.set_type_variation("ToolButton", "Button")
	t.set_stylebox("pressed", "ToolButton", on)
	t.set_stylebox("hover_pressed", "ToolButton", on)
	# Square icon buttons (editor tools and pieces): tight margins.
	t.set_type_variation("IconButton", "Button")
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var src: StyleBoxFlat = (on if st in ["pressed", "hover_pressed"] else t.get_stylebox(st, "Button")).duplicate()
		src.content_margin_left = 3
		src.content_margin_right = 3
		src.content_margin_top = 3
		src.content_margin_bottom = 3
		src.set_corner_radius_all(10)
		src.shadow_size = 2
		t.set_stylebox(st, "IconButton", src)
	t.set_stylebox("focus", "IconButton", StyleBoxEmpty.new())

	var field := _box(Color(1, 1, 1, 0.92), Palette.LILAC, 2, 10)
	field.content_margin_left = 10
	field.content_margin_right = 10
	field.content_margin_top = 4
	field.content_margin_bottom = 4
	var field_focus := field.duplicate()
	field_focus.border_color = Palette.CORAL
	for type in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", type, field)
		t.set_stylebox("focus", type, field_focus)
		t.set_stylebox("read_only", type, field)
		t.set_color("font_color", type, Palette.INK)
		t.set_color("caret_color", type, Palette.RASPBERRY)
		t.set_color("selection_color", type, Color(Palette.PINK, 0.6))
		t.set_font_size("font_size", type, t.default_font_size)

	var panel := _box(Color("#FFF4E0"), Palette.PINK, 4, 22)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	panel.shadow_color = Color(0.35, 0.1, 0.2, 0.25)
	panel.shadow_size = 10
	panel.shadow_offset = Vector2(0, 4)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "PopupPanel", panel)
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_color("font_color", "PopupMenu", CandyText.CHOCOLATE)
	t.set_color("font_hover_color", "PopupMenu", CandyText.CHOCOLATE)
	t.set_stylebox("hover", "PopupMenu", _box(Palette.LEMON, Palette.LEMON, 0, 8))
	t.set_font_size("font_size", "PopupMenu", t.default_font_size)

	t.set_color("font_color", "Label", CandyText.CHOCOLATE)
	t.set_color("font_color", "CheckBox", CandyText.CHOCOLATE)
	t.set_color("font_hover_color", "CheckBox", CandyText.CHOCOLATE)
	t.set_color("font_pressed_color", "CheckBox", CandyText.CHOCOLATE)
	t.set_color("font_hover_pressed_color", "CheckBox", CandyText.CHOCOLATE)
	t.set_color("font_focus_color", "CheckBox", CandyText.CHOCOLATE)

	var list_bg := _box(Color(1, 1, 1, 0.85), Palette.LILAC, 2, 12)
	list_bg.content_margin_left = 6
	list_bg.content_margin_right = 6
	list_bg.content_margin_top = 6
	list_bg.content_margin_bottom = 6
	t.set_stylebox("panel", "ItemList", list_bg)
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", _box(Palette.MINT, Palette.MINT, 0, 8))
	t.set_stylebox("selected_focus", "ItemList", _box(Palette.MINT, Palette.MINT, 0, 8))
	t.set_stylebox("hovered", "ItemList", _box(Color(Palette.LEMON, 0.6), Palette.LEMON, 0, 8))
	t.set_color("font_color", "ItemList", CandyText.CHOCOLATE)
	t.set_color("font_selected_color", "ItemList", CandyText.CHOCOLATE)
	t.set_color("font_hovered_color", "ItemList", CandyText.CHOCOLATE)

	var tab := _box(Color("#F6E6EC"), Palette.PINK, 3, 12)
	tab.content_margin_left = 14
	tab.content_margin_right = 14
	tab.content_margin_top = 4
	tab.content_margin_bottom = 4
	var tab_on := tab.duplicate()
	tab_on.bg_color = Color("#FFF4E0")
	tab_on.border_color = Palette.CORAL
	t.set_stylebox("tab_unselected", "TabBar", tab)
	t.set_stylebox("tab_hovered", "TabBar", tab)
	t.set_stylebox("tab_selected", "TabBar", tab_on)
	t.set_stylebox("tab_unselected", "TabContainer", tab)
	t.set_stylebox("tab_hovered", "TabContainer", tab)
	t.set_stylebox("tab_selected", "TabContainer", tab_on)
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	for type in ["TabBar", "TabContainer"]:
		t.set_font("font", type, CandyText.FONT_BOLD)
		t.set_font_size("font_size", type, t.default_font_size)
		t.set_color("font_selected_color", type, CandyText.CHOCOLATE)
		t.set_color("font_unselected_color", type, Color("#9A7A70"))
		t.set_color("font_hovered_color", type, CandyText.CHOCOLATE)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.8)
	track.border_color = Palette.LILAC
	track.set_border_width_all(1)
	track.set_corner_radius_all(10)
	track.content_margin_top = 4 if small else 6
	track.content_margin_bottom = 4 if small else 6
	var fill := track.duplicate()
	fill.bg_color = Palette.PINK
	fill.border_color = Palette.PINK
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)

	var sep := StyleBoxLine.new()
	sep.color = Color(Palette.PINK, 0.8)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 8)
	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(Palette.PINK, 0.25)
	scroll.set_corner_radius_all(6)
	var grab := scroll.duplicate()
	grab.bg_color = Palette.PINK
	t.set_stylebox("scroll", "VScrollBar", scroll)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_color("font_color", "TooltipLabel", Palette.INK)
	t.set_stylebox("panel", "TooltipPanel", _box(Color("#FFF4E0"), Palette.CORAL, 2, 8))
	return t


static func _box(bg: Color, edge: Color, width: int, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	return b


## Small caption label in chocolate.
static func caption(text: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", CandyText.FONT_BOLD)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#9A6A5A"))
	return l


## Title text in the logo style.
static func heading(text: String, size: int = 30) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CandyText.style(r, size)
	r.text = CandyText.rainbow(text)
	return r

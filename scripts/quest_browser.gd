class_name QuestBrowser
extends PanelContainer
## Title screen page for custom quests: play, edit, share, install and delete.
##
## Installing works four ways: paste a share code, open a .candyquest file,
## drop a file on the game window, or copy it into the quest folder.

signal closed

var _list: ItemList
var _detail: VBoxContainer
var _levels: ItemList
var _status: Label
var _quests: Array[Quest] = []
var _current: Quest
var _scores := Scores.new()
var _delete_armed := false
var _dialog: FileDialog
var _paste_box: PanelContainer
var _paste_edit: TextEdit


func _ready() -> void:
	theme = CandyTheme.make(24)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 60
	offset_top = 40
	offset_right = -60
	offset_bottom = -40
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	top.add_child(CandyTheme.heading("Quests", 48))
	var sub := Label.new()
	sub.text = "level packs made in the editor, by you and your friends"
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	sub.clip_text = true
	sub.custom_minimum_size.x = 20
	# Too long for an upright phone.
	sub.visible = not Tilt.is_portrait()
	top.add_child(sub)
	top.add_child(_btn("Back", func() -> void: closed.emit()))

	# Upright phones: the list goes above the details.
	var narrow := Tilt.is_portrait()
	if narrow:
		offset_left = 16
		offset_right = -16
		offset_top = 16
		offset_bottom = -16
	var body := BoxContainer.new()
	body.vertical = narrow
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(470, 0) if not narrow else Vector2(0, 330)
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 24)
	_list.item_selected.connect(func(i: int) -> void: _show(_quests[i]))
	left.add_child(_list)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	left.add_child(g)
	g.add_child(_btn("New quest", _new_quest, "Start a quest in the level editor"))
	g.add_child(_btn("Paste code", _show_paste, "Install a quest from a share code"))
	g.add_child(_btn("Open file...", _open_file, "Install a .candyquest file"))
	g.add_child(_btn("Quest folder", func() -> void: OS.shell_open(Quest.folder()),
		"Files copied here are installed next time"))
	for b in g.get_children():
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(b as Button).add_theme_font_size_override("font_size", 22)
	var tip := Label.new()
	tip.text = "Tip: drop a .candyquest file on this window to install it."
	tip.add_theme_font_size_override("font_size", 18)
	left.add_child(tip)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	right_scroll.add_child(_detail)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Palette.RASPBERRY)
	_status.add_theme_font_override("font", CandyText.FONT_BOLD)
	root.add_child(_status)
	_build_paste()
	get_window().files_dropped.connect(_on_files_dropped)
	refresh()


func _btn(text: String, action: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(action)
	return b


func refresh(select_id: String = "") -> void:
	_quests = Quest.list_installed()
	_list.clear()
	var pick := 0
	for k in _quests.size():
		var q := _quests[k]
		var by := (", by " + q.author) if q.author != "" else ""
		_list.add_item("%s%s  (%d level%s)" % [q.name, by, q.levels.size(), "" if q.levels.size() == 1 else "s"])
		if q.id == select_id:
			pick = k
	if _quests.is_empty():
		_show(null)
	else:
		_list.select(pick)
		_show(_quests[pick])


func focus_first() -> void:
	_list.grab_focus()


func _show(q: Quest) -> void:
	_current = q
	_delete_armed = false
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	if q == null:
		_detail.add_child(CandyTheme.heading("No quests yet", 40))
		var l := Label.new()
		l.text = "Make your own in the level editor with New quest, or install one from a friend with Paste code or Open file."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(l)
		return
	var head := CandyTheme.heading(q.name, 44)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(head)
	if q.author != "":
		_detail.add_child(CandyTheme.caption("made by " + q.author, 22))
	if q.description != "":
		var d := Label.new()
		d.text = q.description
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(d)
	_levels = ItemList.new()
	_levels.custom_minimum_size.y = 220
	_levels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_levels.add_theme_font_size_override("font_size", 22)
	for k in q.levels.size():
		var lv: Dictionary = q.levels[k]
		var key := "quest:%s:%d:%s" % [q.id, k, lv.title]
		var best := _scores.best(key)
		var line := "par %.0f s" % lv.par
		if best > 0.0:
			var medal := MainGame.medal_for(best, lv.par)
			line = "best %.2f s  %s" % [best, medal.to_lower()]
		_levels.add_item("%d.  %s%s    %s" % [k + 1, lv.title, "  (race)" if lv.race else "", line])
	_levels.select(0)
	_levels.item_activated.connect(func(i: int) -> void: _play(i))
	_detail.add_child(_levels)
	var run := _scores.best("quest_run:" + q.id)
	if run > 0.0:
		_detail.add_child(CandyTheme.caption("Best full run  %.2f s" % run, 22))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_detail.add_child(row)
	var play := _btn("Play", func() -> void: _play(0), "Play all levels in order")
	play.add_theme_stylebox_override("normal", _mint(play))
	row.add_child(play)
	row.add_child(_btn("Play picked level", func() -> void:
		var sel := _levels.get_selected_items()
		_play(sel[0] if sel.size() > 0 else 0)))
	row.add_child(_btn("Edit", func() -> void: _edit(q)))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	_detail.add_child(row2)
	row2.add_child(_btn("Copy share code", func() -> void:
		DisplayServer.clipboard_set(q.share_code())
		_say("Share code copied. Paste it to a friend."), "One line of text with the whole quest"))
	row2.add_child(_btn("Save as file...", func() -> void: _save_file(q), "A .candyquest file to send"))
	var del := _btn("Delete", func() -> void: pass)
	del.add_theme_color_override("font_color", Palette.RASPBERRY)
	del.pressed.connect(func() -> void:
		if not _delete_armed:
			_delete_armed = true
			del.text = "Sure? Press again"
			return
		q.delete()
		_say("Deleted \"%s\"" % q.name)
		refresh())
	row2.add_child(del)
	for r in [row, row2]:
		for b in r.get_children():
			(b as Button).add_theme_font_size_override("font_size", 22)


func _mint(b: Button) -> StyleBoxFlat:
	var sb: StyleBoxFlat = theme.get_stylebox("normal", "Button").duplicate()
	sb.bg_color = Palette.MINT
	return sb


func _say(text: String) -> void:
	_status.text = text


func _play(level: int) -> void:
	if _current == null:
		return
	MainGame.quest = _current
	MainGame.test_mode = false
	MainGame.requested_level = level
	Transition.go("res://scenes/main.tscn")


func _edit(q: Quest) -> void:
	LevelEditor.session_quest = q
	LevelEditor.session_level = 0
	Transition.go("res://scenes/editor.tscn")


func _new_quest() -> void:
	var q := Quest.create()
	q.levels = [LevelEditor.template("track", "Level 1")]
	q.save()
	_edit(q)


func _installed(q: Quest, how: String) -> void:
	if q == null:
		_say("That isn't a Candy Marble quest.")
		return
	_say("Installed \"%s\" (%s)" % [q.name, how])
	refresh(q.id)


func _on_files_dropped(files: PackedStringArray) -> void:
	if not is_visible_in_tree():
		return
	for f in files:
		_installed(Quest.install_file(f), f.get_file())


# --- paste box ----------------------------------------------------------------------

func _build_paste() -> void:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_paste_box = PanelContainer.new()
	_paste_box.visible = false
	var sb: StyleBoxFlat = theme.get_stylebox("panel", "PanelContainer").duplicate()
	sb.border_color = Palette.CORAL
	sb.shadow_size = 30
	sb.shadow_color = Color(0.2, 0.05, 0.1, 0.35)
	_paste_box.add_theme_stylebox_override("panel", sb)
	c.add_child(_paste_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_paste_box.add_child(box)
	box.add_child(CandyTheme.heading("Paste a share code", 34))
	_paste_edit = TextEdit.new()
	_paste_edit.custom_minimum_size = Vector2(760, 180)
	_paste_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_paste_edit.placeholder_text = "CANDYQUEST1:..."
	box.add_child(_paste_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(_btn("Install", func() -> void:
		var q := Quest.from_share_code(_paste_edit.text)
		if q:
			Quest.install(q)
			_paste_box.visible = false
		_installed(q, "share code")))
	row.add_child(_btn("Cancel", func() -> void: _paste_box.visible = false))


func _show_paste() -> void:
	var clip := DisplayServer.clipboard_get()
	_paste_edit.text = clip if clip.strip_edges().begins_with(Quest.CODE_PREFIX) else ""
	_paste_box.visible = true
	_paste_edit.grab_focus()


# --- files --------------------------------------------------------------------------

func _file_dialog(mode: FileDialog.FileMode) -> FileDialog:
	if _dialog:
		_dialog.queue_free()
	_dialog = FileDialog.new()
	_dialog.file_mode = mode
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.filters = PackedStringArray(["*.candyquest ; Candy Marble quest"])
	_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	add_child(_dialog)
	return _dialog


func _open_file() -> void:
	var d := _file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	d.file_selected.connect(func(path: String) -> void: _installed(Quest.install_file(path), path.get_file()))
	d.popup_centered(Vector2i(900, 600))


func _save_file(q: Quest) -> void:
	var d := _file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	d.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	d.current_file = q.file_name()
	d.file_selected.connect(func(path: String) -> void:
		if not path.ends_with(".candyquest"):
			path += ".candyquest"
		_say(("Saved " + path.get_file()) if q.write_to(path) == OK else "Couldn't write " + path))
	d.popup_centered(Vector2i(900, 600))


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _paste_box.visible:
			_paste_box.visible = false
		else:
			closed.emit()

extends SceneTree
## Level editor and quest tests. Drives the editor's tools like a mouse would,
## then checks saving, share codes, installing, sanitising and that the level
## plays in the game with its monster colours and speeds.
##   godot --headless --fixed-fps 120 -s tests/editor_test.gd

var results: Array[String] = []
var failed := false
var ed  # LevelEditor (untyped: the autoloads don't exist yet when tests compile)
var frame := 0
var step := 0
var main: Node3D
var quest: Quest


func _initialize() -> void:
	quest = Quest.create("Editor test quest")
	quest.id = "testeditor01"
	quest.author = "Test"
	load("res://scripts/editor/level_editor.gd").set("session_quest", quest)
	ed = load("res://scenes/editor.tscn").instantiate()
	root.add_child(ed)


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	match step:
		0:
			_tools()
			step = 1
		1:
			_files()
			step = 2
		2:
			_sanitize()
			step = 3
		3:
			_start_game()
			step = 4
		4:
			if frame > 40:
				_check_game()
				step = 5
		5:
			for q in Quest.list_installed():
				if q.id.begins_with("test"):
					q.delete()
			_check("all checks ran", results.size() >= 52, "%d checks" % results.size())
			print("\n".join(results))
			print("EDITOR TEST ", "FAILED" if failed else "PASSED")
			quit(1 if failed else 0)
	return false


func _drag(tool: String, a: Vector2i, b: Vector2i = Vector2i(-999, -999), shift: bool = false) -> void:
	ed.set_tool(tool)
	ed._stroke_begin(a, Vector2(a) + Vector2(0.5, 0.5), shift)
	if b.x != -999:
		ed._stroke_move(b, Vector2(b) + Vector2(0.5, 0.5), shift)
	ed._stroke_end(b if b.x != -999 else a, Vector2(b if b.x != -999 else a) + Vector2(0.5, 0.5), shift)


func _tools() -> void:
	var w0: int = ed.cols()
	var h0: int = ed.rows()
	_check("blank level opens", w0 == 16 and h0 == 10 and ed.has_char("S") and ed.has_char("G"),
		"%dx%d" % [w0, h0])

	# Mouse picking: a tile's centre on screen picks that tile, in both views.
	for top in [true, false]:
		if ed.top_view != top:
			ed.toggle_view()
		var ok := true
		for t in [Vector2i(3, 4), Vector2i(12, 5), Vector2i(8, 8)]:
			var c: Vector2 = ed.built.tile_center(t.x, t.y)
			var screen: Vector2 = ed.camera.unproject_position(Vector3(c.x, ed.built.height(c.x, c.y), c.y))
			var hit: Array = ed.pick(screen)
			ok = ok and not hit.is_empty() and hit[0] == t
		_check("mouse picks the tile under it (%s view)" % ("flat" if top else "3D"), ok, "")
	if not ed.top_view:
		ed.toggle_view()

	# Paint past the right and top edges: the map grows and old tiles shift down.
	ed.tier = 0
	_drag("paint", Vector2i(14, 5), Vector2i(19, 5))
	_check("painting past the edge grows the map", ed.cols() == 20 and ed.hchar(19, 5) == "0",
		"cols %d, tile %s" % [ed.cols(), ed.hchar(19, 5)])
	var s_before := _find("S")
	_drag("paint", Vector2i(3, -2))
	_check("growing to the top shifts everything", ed.rows() == h0 + 2 and _find("S") == s_before + Vector2i(0, 2),
		"rows %d, S %s -> %s" % [ed.rows(), s_before, _find("S")])

	# Box with walls.
	ed.tier = 2
	ed.box_walls = true
	_drag("box", Vector2i(21, 2), Vector2i(26, 8))
	_check("box with walls", ed.hchar(23, 5) == "2" and ed.hchar(21, 2) == "3" and ed.hchar(26, 8) == "3",
		"inside %s edge %s" % [ed.hchar(23, 5), ed.hchar(21, 2)])

	# Raise and lower once per stroke even when dragged back and forth.
	var t := Vector2i(5, 6)
	var before := int(ed.hchar(t.x, t.y))
	ed.brush = 1
	_drag("raise", t, t + Vector2i(1, 0))
	_check("raise lifts one step", int(ed.hchar(t.x, t.y)) == before + 1, "%d -> %s" % [before, ed.hchar(t.x, t.y)])
	_drag("lower", t)
	_check("lower sinks one step", int(ed.hchar(t.x, t.y)) == before, ed.hchar(t.x, t.y))

	# Ramp between height 0 (left) and height 2 (the box): auto picks "e".
	ed.tier = 0
	_drag("paint", Vector2i(14, 5), Vector2i(19, 5))
	ed.ramp_dir = "auto"
	_drag("ramp", Vector2i(20, 5), Vector2i(21, 5))
	_check("auto ramp rises towards the higher side", ed.hchar(20, 5) == "e" and ed.hchar(21, 5) == "e",
		ed.hchar(20, 5) + ed.hchar(21, 5))

	# Fill and eyedropper.
	ed.tier = 4
	_drag("fill", Vector2i(23, 5))
	_check("fill paints the connected area", ed.hchar(22, 3) == "4" and ed.hchar(25, 7) == "4" and ed.hchar(21, 2) == "3" and ed.hchar(21, 5) == "e",
		"%s %s %s" % [ed.hchar(22, 3), ed.hchar(25, 7), ed.hchar(21, 2)])
	ed.tier = 0
	_drag("pick", Vector2i(23, 5))
	_check("pick copies the height", ed.tier == 4 and ed.tool == "paint", "tier %d tool %s" % [ed.tier, ed.tool])

	# Objects.
	_drag("spawn", Vector2i(4, 5))
	_check("only one start", _count("S") == 1 and _find("S") == Vector2i(4, 5), str(_find("S")))
	_drag("goal", Vector2i(24, 5))
	_check("hole moves to the box", _count("G") == 1 and _find("G") == Vector2i(24, 5), str(_find("G")))
	_drag("checkpoint", Vector2i(10, 6))
	_check("gate picks its direction", ed.ochar(10, 6) in ["C", "K"], ed.ochar(10, 6))
	ed.booster_dir = ">"
	_drag("booster", Vector2i(12, 6))
	ed.rotate_selection()
	_check("booster turns with R", ed.ochar(12, 6) == "v", ed.ochar(12, 6))
	ed.decor_char = "b"
	_drag("decor", Vector2i(2, 4), Vector2i(2, 6))
	_check("decor paints", ed.ochar(2, 4) == "b" and ed.ochar(2, 6) == "b", ed.ochar(2, 5))
	_drag("waves", Vector2i(7, 4))
	_check("waves", ed.ochar(7, 4) == "W", ed.ochar(7, 4))

	# Monsters: sweeper dragged 3 tiles down, then tweaked.
	_drag("enemy", Vector2i(8, 4), Vector2i(8, 7))
	var e: Dictionary = ed.selected_extra()
	_check("sweeper travel from drag", e.type == "enemy" and Vector2(e.travel[0], e.travel[2]) == Vector2(0, 6),
		str(e.get("travel")))
	ed.set_extra_value("period", 1.5)
	ed.set_extra_value("tint", "#33aa55")
	_check("sweeper speed and colour", ed.selected_extra().period == 1.5 and ed.selected_extra().tint == "#33aa55",
		str(ed.selected_extra()))
	_drag("windmill", Vector2i(16, 5))
	ed.set_extra_value("spin", -2.5)
	_drag("ghost", Vector2i(18, 6))
	_drag("stomper", Vector2i(13, 5))
	var n_extras: int = ed.lv.extras.size()
	ed.duplicate_selection()
	_check("duplicate", ed.lv.extras.size() == n_extras + 1, str(ed.lv.extras.size()))
	ed.delete_selection()
	_check("delete", ed.lv.extras.size() == n_extras, str(ed.lv.extras.size()))

	# Cannon: place, then the next click sets the landing spot.
	_drag("cannon", Vector2i(6, 7))
	ed._stroke_begin(Vector2i(15, 7), Vector2(15.5, 7.5), false)
	var c: Dictionary = ed.selected_extra()
	_check("cannon landing spot", c.type == "cannon" and c.target_tile == [15.0, 7.0], str(c.get("target_tile")))

	# Select and drag moves; undo puts it back, redo again.
	ed.set_tool("select")
	ed._stroke_begin(Vector2i(16, 5), Vector2(16.5, 5.5), false)
	ed._stroke_move(Vector2i(16, 7), Vector2(16.5, 7.5), false)
	ed._stroke_end(Vector2i(16, 7), Vector2(16.5, 7.5), false)
	var moved: Dictionary = ed.selected_extra()
	_check("select and drag", moved.type == "windmill" and moved.tile == [16.0, 7.0], str(moved.get("tile")))
	ed.undo()
	var back := _extra("windmill")
	_check("undo the move", back.tile == [16.0, 5.0], str(back.tile))
	ed.redo()
	_check("redo the move", _extra("windmill").tile == [16.0, 7.0], str(_extra("windmill").tile))

	# Right click removes what is under the cursor.
	var before_rc: int = ed.lv.extras.size()
	ed.set_tool("paint")
	ed.remove_at(Vector2i(18, 6), Vector2(18.5, 6.5))
	_check("right click removes", ed.lv.extras.size() == before_rc - 1, str(ed.lv.extras.size()))

	# Erase clears ground and objects.
	_drag("erase", Vector2i(2, 4))
	_check("erase", ed.hchar(2, 4) == "." and ed.ochar(2, 4) == ".", ed.hchar(2, 4) + ed.ochar(2, 4))

	# Level settings.
	ed.set_level_value("title", "Test Track")
	ed.set_level_value("description", "A test.")
	ed.set_level_value("monster_speed", 2.0)
	ed.set_level_value("monster_tint", "#8844ff")
	ed.set_level_value("race", true)
	ed.set_level_value("rival_tint", "#3366ff")
	ed.apply_theme("Blueberry")
	var par: float = ed.estimate_par()
	_check("par estimate", par >= 10.0 and par < 120.0, str(par))
	_check("path found", ed.problems().is_empty(), str(ed.problems()))
	ed.auto_path()
	_check("auto path", ed.lv.route.size() >= 2, str(ed.lv.route))

	# Resize and crop.
	var wc: int = ed.cols()
	ed.resize(4, 0, 0, 0)
	_check("grow left moves things", ed.cols() == wc + 4 and _find("G").x == 28, str(_find("G")))
	ed.crop()
	_check("crop keeps a border", ed.cols() <= wc + 1 and _find("G").x < 28, "cols %d G %s" % [ed.cols(), _find("G")])

	# Quest: remix a built-in level, add and order levels.
	ed.ui._remix(0)
	_check("remix built-in level", ed.quest.levels.size() == 2 and ed.li == 1, str(ed.quest.levels.size()))
	var remix: Dictionary = ed.quest.levels[1]
	var sweepers := 0
	for x: Dictionary in remix.extras:
		if x.type == "enemy":
			sweepers += 1
	_check("remix turns sweepers into monsters", sweepers > 0 and not "".join(remix.objects).contains("x"),
		"%d sweepers" % sweepers)
	ed.ui._move_level(-1)
	_check("reorder levels", ed.quest.levels[0].title.ends_with("remix") and ed.li == 0, ed.quest.levels[0].title)
	ed.open_level(1)
	_check("switch level", ed.lv.title == "Test Track", ed.lv.title)


func _files() -> void:
	ed.save()
	var loaded := Quest.load_file(quest.path())
	_check("save and load", loaded != null and JSON.stringify(loaded.to_dict()) == JSON.stringify(Quest.from_dict(quest.to_dict()).to_dict()),
		quest.path())
	var code := quest.share_code()
	var from_code := Quest.from_share_code("hey try my quest!\n" + code.substr(0, 60) + "\n" + code.substr(60) + "\n")
	_check("share code round trip (wrapped in chat text)", from_code != null and from_code.name == quest.name
		and JSON.stringify(from_code.levels) == JSON.stringify(loaded.levels), "%d chars" % code.length())
	_check("broken share code is refused", Quest.from_share_code(code.substr(0, code.length() - 30)) == null, "")
	# Export to a file anywhere, install from there.
	var out := OS.get_user_data_dir() + "/export_test.candyquest"
	quest.write_to(out)
	var copy := Quest.load_file(out)
	copy.id = "testeditor02"
	copy.name = "Copy"
	copy.write_to(out)
	var inst := Quest.install_file(out)
	_check("install from a file", inst != null and Quest.find("testeditor02") != null, "")
	DirAccess.remove_absolute(out)
	# A file dropped by hand in the quest folder gets picked up.
	var hand := Quest.DIR + "/from a friend.candyquest"
	copy.id = "testeditor03"
	copy.write_to(hand)
	var found := Quest.find("testeditor03")
	_check("quest folder picks up loose files", found != null and FileAccess.file_exists(found.path())
		and not FileAccess.file_exists(hand), "")


func _sanitize() -> void:
	var evil := {
		format = "candy-quest", id = "../../etc/passwd", name = 42, author = "x".repeat(500),
		levels = [{
			title = "Evil", par = -5, race = "yes",
			heights = ["00000", 7, "0<script>0"], objects = ["S...G"],
			extras = [
				{type = "enemy", tile = [1, 1], period = 1e9, script = "res://evil.gd", travel = "far"},
				{type = "node", tile = [1, 1]},
				{type = "ghost", tile = [INF, 2]},
				{type = "windmill", tile = [2, 1], spin = NAN, tint = "red; drop"},
			],
			theme = {tiers = ["#zzz"], wall = 5},
			route = [[1, 1], "x", [2, 2, 2]],
		}],
	}
	var q := Quest.from_dict(evil)
	var l: Dictionary = q.levels[0]
	_check("sanitise: id is safe", not q.id.contains(".") and not q.id.contains("/"), q.id)
	_check("sanitise: text fields", q.name == "Untitled quest" and q.author.length() == 40, q.name)
	_check("sanitise: map rows", l.heights.size() == 3 and l.heights[1] == ".........." and not l.heights[2].contains("<"),
		str(l.heights))
	_check("sanitise: numbers clamped", l.par == 5.0 and l.race == false and l.extras[0].period == 20.0, str(l.par))
	_check("sanitise: unknown extras and keys dropped", l.extras.size() == 2 and not l.extras[0].has("script")
		and l.extras[1].get("spin", 1.2) == 1.2 and not l.extras[1].has("tint"), str(l.extras))
	_check("sanitise: theme and route", l.theme.tiers.size() == 5 and l.theme.wall == "#5a3426" and l.route.size() == 1,
		str(l.theme))
	_check("sanitise: rubbish is not a quest", Quest.from_dict({format = "nope"}) == null and Quest.from_dict([1]) == null
		and Quest.from_share_code("CANDYQUEST1:99:@@@@") == null, "")
	var lvl := CustomLevel.from_dict(l)
	lvl.build()
	_check("sanitised level builds", lvl.cols == 10 and lvl.goal != Vector2.INF, "%dx%d" % [lvl.cols, lvl.rows])


func _start_game() -> void:
	ed.save()
	var mg: GDScript = load("res://scripts/main.gd")
	mg.set("quest", quest.duplicate_quest())
	mg.set("test_mode", true)
	mg.set("requested_level", 1)
	ed.queue_free()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	frame = 0


func _check_game() -> void:
	var lvl: LevelBase = main.level
	_check("test play loads the custom level", lvl.title == "Test Track" and lvl is CustomLevel and main.save_scores == false,
		lvl.title)
	var enemy: Node
	var windmill: Node
	for n in main.world.get_children():
		if n is Enemy:
			enemy = n
		if n is Windmill:
			windmill = n
	_check("sweeper period uses level monster speed", enemy != null and is_equal_approx(enemy.period, 0.75),
		str(enemy.period if enemy else -1))
	_check("windmill spin uses level monster speed", windmill != null and is_equal_approx(windmill.spin, -5.0),
		str(windmill.spin if windmill else 0))
	_check("sweeper wears its own colour", enemy != null and _has_color(enemy, Color("#33aa55")), "")
	_check("windmill wears the level monster colour", windmill != null and _has_color(windmill, Color("#8844ff")), "")
	_check("race rival exists with its colour", main.rival != null and _has_color(main.rival, Color("#3366ff")), "")
	_check("theme colours on the level", lvl.wall_color == Color(CustomLevel.THEMES["Blueberry"].wall), lvl.wall_color.to_html())


func _has_color(n: Node, col: Color) -> bool:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m and m.albedo_color.is_equal_approx(Color(col, m.albedo_color.a)):
				return true
	return false


func _find(ch: String) -> Vector2i:
	for j in ed.rows():
		var i: int = (ed.lv.objects[j] as String).find(ch)
		if i >= 0:
			return Vector2i(i, j)
	return Vector2i(-1, -1)


func _count(ch: String) -> int:
	var n := 0
	for line: String in ed.lv.objects:
		n += line.count(ch)
	return n


func _extra(type: String) -> Dictionary:
	for e: Dictionary in ed.lv.extras:
		if e.type == type:
			return e
	return {}


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

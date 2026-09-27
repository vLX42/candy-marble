extends SceneTree
## Track sections, the Road tool and the guide.
##   godot --headless --fixed-fps 120 -s tests/sections_test.gd
## Also writes user://sections_test.candyquest (outside the quest folder), a
## level built only from sections, for the bot:
##   godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --quest=user://sections_test.candyquest

var results: Array[String] = []
var failed := false
var ed
var frame := 0


func _initialize() -> void:
	var q := Quest.create("Sections test")
	q.id = "testsections"
	q.levels = [load("res://scripts/editor/level_editor.gd").template("track", "Built from sections")]
	load("res://scripts/editor/level_editor.gd").set("session_quest", q)
	ed = load("res://scenes/editor.tscn").instantiate()
	root.add_child(ed)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		_pieces()
		_build_track()
		_road()
		_check("all checks ran", results.size() >= 20, "%d checks" % results.size())
		# Keep the player's quest list clean.
		ed.quest.delete()
		print("\n".join(results))
		print("SECTIONS TEST ", "FAILED" if failed else "PASSED")
		quit(1 if failed else 0)
	return false


func _pieces() -> void:
	var bad := []
	for p: Array in TrackPieces.LIST:
		var piece := TrackPieces.get_piece(p[0])
		for h in 4:
			var r := TrackPieces.stamp(piece, Vector2i(20, 20), h, 4)
			if not r.ok or r.cells.is_empty():
				bad.append("%s@%d" % [p[0], h])
	_check("every section stamps in all 4 directions", bad.is_empty(), str(bad))
	var right := TrackPieces.stamp(TrackPieces.get_piece("right"), Vector2i(0, 0), 0, 3)
	var left := TrackPieces.stamp(TrackPieces.get_piece("left"), Vector2i(0, 0), 0, 3)
	_check("turns change heading", right.end[2] == 1 and left.end[2] == 3, "%s %s" % [right.end, left.end])
	var up := TrackPieces.stamp(TrackPieces.get_piece("ramp_up"), Vector2i(0, 0), 2, 3)
	_check("ramp up ends a step higher and rotates its slope", up.end[3] == 4 and up.cells[Vector2i(-1, -2)][0] == "w",
		"%s %s" % [up.end, up.cells[Vector2i(-1, -2)]])
	var low := TrackPieces.stamp(TrackPieces.get_piece("stairs"), Vector2i(0, 0), 0, 1)
	_check("too low is refused with a reason", not low.ok and low.why.contains("low"), low.why)


func _build_track() -> void:
	_check("guided template has a start and an open end", ed.has_char("S") and not ed.track_end().is_empty(),
		str(ed.track_end()))
	var g0: Array = ed.guide()
	_check("guide asks for the track and the finish", g0[2] == "finish", g0[0])
	var seq := ["straight", "ramp_up", "right", "bumpers", "checkpoint", "jump", "left", "sweepers", "waves",
		"ramp_down", "right", "windmill", "straight"]
	for id in seq:
		ed.add_section(id)
	_check("sections line up end to end", not ed.track_end().is_empty() and ed.track_end()[3] == 3,
		"end %s" % [ed.track_end()])
	var g1: Array = ed.guide()
	_check("still no hole: guide says add Finish", g1[2] == "finish", g1[0])
	ed.guide_action("finish")
	_check("finish closes the track", ed.has_char("G") and ed.track_end().is_empty(), str(ed.track_end()))
	_check("start and hole are connected", ed.hole_reachable(), "reach %d tiles" % ed.reach.size())
	_check("path follows the sections", ed.lv.route.size() > 20, "%d points" % ed.lv.route.size())
	var g2: Array = ed.guide()
	_check("guide moves on to checkpoint, par or test play", g2[2] in ["checkpoint", "par", "test"], g2[0])
	if g2[2] == "par":
		ed.guide_action("par")
	_check("guide ends at test play", ed.guide()[2] in ["test", "checkpoint"], ed.guide()[0])
	ed.undo()
	_check("undo removes the finish and brings back the open end", not ed.has_char("G") and not ed.track_end().is_empty(), "")
	ed.redo()
	var e := 0
	for x: Dictionary in ed.lv.extras:
		if x.type == "enemy":
			e += 1
	_check("monster sections bring their monsters", e == 2, "%d sweepers" % e)
	# Turning a piece before placing it: buttons, R / Shift+R and right click.
	ed.set_tool("sections")
	ed.section_heading = 0
	ed.turn_section(1)
	var after_right: int = ed.section_heading
	ed.turn_section(-1)
	ed.turn_section(-1)
	var after_left: int = ed.section_heading
	var extras_before: int = ed.lv.extras.size()
	ed.remove_at(Vector2i(3, 3), Vector2(3.5, 3.5))
	_check("pieces turn right, left and on right click (without deleting anything)",
		after_right == 1 and after_left == 3 and ed.section_heading == 0 and ed.lv.extras.size() == extras_before,
		"%d %d %d" % [after_right, after_left, ed.section_heading])
	# A piece placed with a click, facing down.
	ed.section_id = "straight"
	ed.section_heading = 1
	var before: int = ed.rows()
	ed._place_section_at(Vector2i(2, ed.rows() + 3))
	_check("click placement grows the map and sets a new open end", ed.rows() > before and ed.track_end()[2] == 1,
		"rows %d -> %d end %s" % [before, ed.rows(), ed.track_end()])
	ed.undo()
	var built_only := Quest.from_dict(ed.quest.to_dict())
	built_only.levels = [built_only.levels[0]]
	built_only.write_to("user://sections_test.candyquest")


func _road() -> void:
	# Two walled platforms at different heights, then a road between them.
	ed.quest.levels.append(load("res://scripts/editor/level_editor.gd").template("empty", "Road test"))
	ed.open_level(1)
	ed.box_walls = true
	ed.tier = 3
	_drag("box", Vector2i(1, 1), Vector2i(7, 7))
	ed.tier = 0
	_drag("box", Vector2i(18, 1), Vector2i(24, 7))
	_drag("spawn", Vector2i(3, 4))
	_drag("goal", Vector2i(21, 4))
	_check("platforms start unconnected", not ed.hole_reachable(), "")
	var g: Array = ed.guide()
	_check("guide points at the gap and the Road tool", g[2] == "road", g[0])
	var gap: Vector2i = ed.gap_tile()
	_check("gap marker sits on the start platform edge", gap.x >= 5 and gap.x <= 7, str(gap))
	ed.road_width = 4
	ed.set_tool("road")
	ed._stroke_begin(Vector2i(5, 4), Vector2(5.5, 4.5), false)
	for x in range(6, 18):
		ed._stroke_move(Vector2i(x, 4), Vector2(x + 0.5, 4.5), false)
	ed._stroke_end(Vector2i(17, 4), Vector2(17.5, 4.5), false)
	var ramps := 0
	for line: String in ed.lv.heights:
		ramps += line.count("w")
	_check("road ramps down to the lower platform", ramps >= 4, "%d ramp tiles" % ramps)
	_check("road runs into the lower platform", ed.hchar(18, 4) == "w" and ed.hchar(20, 4) == "0", ed.hchar(18, 4) + ed.hchar(20, 4))
	_check("road opened the start platform's wall", ed.hchar(7, 4) == "3", ed.hchar(7, 4))
	_check("road has rails", ed.hchar(10, 2) == "4" and ed.hchar(10, 7) == "4", ed.hchar(10, 2) + ed.hchar(10, 7))
	_check("now the hole can be reached", ed.hole_reachable(), "")
	# A road into the sky leaves an open end for sections.
	ed.set_tool("road")
	ed._stroke_begin(Vector2i(21, 6), Vector2(21.5, 6.5), false)
	for z in range(7, 14):
		ed._stroke_move(Vector2i(21, z), Vector2(21.5, z + 0.5), false)
	ed._stroke_end(Vector2i(21, 13), Vector2(21.5, 13.5), false)
	var te: Array = ed.track_end()
	_check("road into the sky leaves an open end facing down", not te.is_empty() and te[2] == 1 and te[3] == 0, str(te))
	ed.add_section("straight")
	_check("a section continues the road", ed.hchar(21, 16) == "0", ed.hchar(21, 16))


func _drag(tool: String, a: Vector2i, b: Vector2i = Vector2i(-999, -999)) -> void:
	ed.set_tool(tool)
	ed._stroke_begin(a, Vector2(a) + Vector2(0.5, 0.5), false)
	if b.x != -999:
		ed._stroke_move(b, Vector2(b) + Vector2(0.5, 0.5), false)
	var e := b if b.x != -999 else a
	ed._stroke_end(e, Vector2(e) + Vector2(0.5, 0.5), false)


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  (" + detail + ")")
	if not ok:
		failed = true

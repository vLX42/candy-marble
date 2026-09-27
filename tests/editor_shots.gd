extends SceneTree
## Screenshots of the level editor, the quest page and a custom level in play
## (needs a window):
##   godot --always-on-top -s tests/editor_shots.gd
## Saves to tests/shots/editor_<name>.png

var node: Node
var t := 0.0
var step := 0
var sample: Quest
var steps := []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/shots")
	sample = Quest.load_file("res://quests/sweet_starter.json")
	sample.id = "testshots"
	sample.save()
	steps = [
		["level", 1.5, func() -> void:
			load("res://scripts/editor/level_editor.gd").set("session_quest", sample)
			load("res://scripts/editor/level_editor.gd").set("session_level", 1)
			_swap(load("res://scenes/editor.tscn").instantiate())],
		["guided", 1.5, func() -> void:
			var g := Quest.create("Guided")
			g.id = "testshots2"
			g.levels = [load("res://scripts/editor/level_editor.gd").template("track", "My track")]
			load("res://scripts/editor/level_editor.gd").set("session_quest", g)
			load("res://scripts/editor/level_editor.gd").set("session_level", 0)
			_swap(load("res://scenes/editor.tscn").instantiate())],
		["guided_built", 1.5, func() -> void:
			for id in ["straight", "ramp_up", "right", "bumpers", "left", "loop"]:
				node.add_section(id)
			node.frame_level()],
		["gap", 1.5, func() -> void:
			node.add_section("straight")
			var x0: int = node.cols() + 3
			node.tier = 0
			node.box_walls = true
			for pair in [["box", Vector2i(x0, 2), Vector2i(x0 + 6, 8)], ["goal", Vector2i(x0 + 3, 5), Vector2i(x0 + 3, 5)]]:
				node.set_tool(pair[0])
				node._stroke_begin(pair[1], Vector2(pair[1]) + Vector2(0.5, 0.5), false)
				node._stroke_move(pair[2], Vector2(pair[2]) + Vector2(0.5, 0.5), false)
				node._stroke_end(pair[2], Vector2(pair[2]) + Vector2(0.5, 0.5), false)
			node.set_tool("road")
			node.frame_level()],
		["back_to_sample", 1.0, func() -> void:
			load("res://scripts/editor/level_editor.gd").set("session_quest", sample)
			load("res://scripts/editor/level_editor.gd").set("session_level", 1)
			_swap(load("res://scenes/editor.tscn").instantiate())],
		["selected", 0.8, func() -> void:
			node.set_tool("select")
			for k in node.lv.extras.size():
				if node.lv.extras[k].type == "windmill":
					node.select_extra(k)],
		["3d", 1.0, func() -> void:
			node.toggle_view()
			node.set_animate(true)],
		["ramp_tool", 0.6, func() -> void:
			node.toggle_view()
			node.set_animate(false)
			node.set_tool("ramp")
			node.ui._tabs.current_tab = 2],
		["quest", 0.6, func() -> void:
			node.set_tool("paint")
			node.ui._tabs.current_tab = 3],
		["help", 0.6, func() -> void: node.ui.toggle_help()],
		["remix", 1.5, func() -> void:
			node.ui.toggle_help()
			node.ui._remix(4)],
		["title_quests", 1.5, func() -> void:
			load("res://scripts/title.gd").set("open_page", "quests")
			_swap(load("res://scenes/title.tscn").instantiate())],
		["game", 3.0, func() -> void:
			var mg: GDScript = load("res://scripts/main.gd")
			mg.set("quest", sample)
			mg.set("test_mode", true)
			mg.set("requested_level", 1)
			_swap(load("res://scenes/main.tscn").instantiate())],
	]


func _swap(n: Node) -> void:
	if node:
		node.queue_free()
	node = n
	root.add_child(node)


func _process(delta: float) -> bool:
	if step >= steps.size():
		sample.delete()
		quit()
		return false
	if t == 0.0:
		steps[step][2].call()
	t += delta
	if t >= steps[step][1]:
		RenderingServer.force_draw()
		root.get_viewport().get_texture().get_image().save_png("res://tests/shots/editor_%s.png" % steps[step][0])
		step += 1
		t = 0.0
	return false

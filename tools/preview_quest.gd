extends SceneTree
## Renders each level of a quest in the editor's 3D view (needs a window):
##   godot --always-on-top -s tools/preview_quest.gd -- res://quests/marble_madness.json
## Saves tests/shots/quest_<n>.png

var quest: Quest
var ed: Node
var i := 0
var t := 0.0


func _initialize() -> void:
	var path := "res://quests/marble_madness.json"
	for a in OS.get_cmdline_user_args():
		path = a
	quest = Quest.load_file(path)
	quest.id = "testpreview"
	DirAccess.make_dir_recursive_absolute("res://tests/shots")


func _process(delta: float) -> bool:
	if t == 0.0:
		if i >= quest.levels.size():
			quit()
			return false
		if ed:
			ed.queue_free()
		var s: GDScript = load("res://scripts/editor/level_editor.gd")
		s.set("session_quest", quest)
		s.set("session_level", i)
		ed = load("res://scenes/editor.tscn").instantiate()
		root.add_child(ed)
	t += delta
	if t > 0.6 and t < 0.7 and ed.top_view:
		ed.toggle_view()
		ed.set_scenery(false)
		ed.frame_level()
		ed.ui.visible = false
	if t > 1.6:
		root.get_viewport().get_texture().get_image().save_png("res://tests/shots/quest_%d.png" % (i + 1))
		i += 1
		t = 0.0
	return false

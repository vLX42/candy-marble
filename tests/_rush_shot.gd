extends SceneTree
var t := 0.0
var n := 0
var main
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	main.first_level = 5
	main.save_scores = false
	root.add_child(main)
func _process(d):
	t += d
	if n == 0 and t > 2.0:
		for k in 6: main.charge(1.0, main.ball.global_position)
		n = 1
	elif n == 1:
		Input.action_press("right"); Input.action_press("down")
		if t > 3.3:
			RenderingServer.force_draw()
			root.get_viewport().get_texture().get_image().save_png("res://tests/shots/rush.png")
			quit()
	return false

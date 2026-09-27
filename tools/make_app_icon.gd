extends SceneTree
## Renders icon.png (512x512): the peppermint marble on a candy tile, from the
## real models. Needs a window:  godot --always-on-top -s tools/make_app_icon.gd

var vp: SubViewport
var frames := 0


func _initialize() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFF1F6")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ball := Node3D.new()
	vp.add_child(ball)
	ball.rotation_degrees = Vector3(0, -30, 20)
	Palette.load_model(ball, "ball")
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.75
	cam.position = Vector3(0, 0.0, 10)
	vp.add_child(cam)
	cam.look_at(Vector3.ZERO)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 6:
		var ballimg := vp.get_texture().get_image()
		ballimg.convert(Image.FORMAT_RGBA8)
		var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		var top := Color("#F9C6D3")
		var bottom := Color("#C9B8EC")
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for y in 512:
			for x in 512:
				# Rounded square (radius 110) with a soft vertical gradient.
				var dx := maxf(absf(x - 255.5) - 145.0, 0.0)
				var dy := maxf(absf(y - 255.5) - 145.0, 0.0)
				var d := sqrt(dx * dx + dy * dy)
				var a := clampf(111.0 - d, 0.0, 1.0)
				if a > 0.0:
					var c := top.lerp(bottom, y / 512.0)
					img.set_pixel(x, y, Color(c, a))
		# Sprinkles.
		var cols := [Color("#FFF4E0"), Color("#F7D66B"), Color("#8EDDB6"), Color("#8CC9F0"), Color("#F4829F")]
		for k in 40:
			var p := Vector2(rng.randf_range(40, 472), rng.randf_range(40, 472))
			if p.distance_to(Vector2(256, 250)) < 190:
				continue
			var ang := rng.randf() * TAU
			var col: Color = cols[k % cols.size()]
			for t in range(-9, 10):
				for w in range(-3, 4):
					var q := p + Vector2(cos(ang), sin(ang)) * t + Vector2(-sin(ang), cos(ang)) * w * 0.8
					if Rect2(0, 0, 512, 512).has_point(q) and img.get_pixelv(q).a > 0.5:
						img.set_pixelv(q, col)
		# Soft shadow under the marble.
		for y in 512:
			for x in 512:
				var e := pow((x - 256.0) / 150.0, 2.0) + pow((y - 430.0) / 32.0, 2.0)
				if e < 1.0 and img.get_pixel(x, y).a > 0.5:
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color("#8A3553"), 0.25 * (1.0 - e)))
		img.blend_rect(ballimg, Rect2i(0, 0, 512, 512), Vector2i(0, -6))
		img.save_png("res://icon.png")
		print("wrote icon.png")
		quit()
	return false

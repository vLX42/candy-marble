extends SceneTree
## Renders the level editor's tool icons and section thumbnails from the real
## terrain and models (needs a window):
##   godot --always-on-top -s tools/make_icons.gd && godot --headless --import
## Writes art/ui/icons/tool_<id>.png and art/ui/icons/piece_<id>.png.

const OUT := "res://art/ui/icons/"
const SIZE := Vector2i(128, 128)
const PIECE_SIZE := Vector2i(192, 128)

var vp: SubViewport
var vp2: SubViewport
var cam: Camera3D
var holder: Node3D
var jobs: Array = []
var wait := 0
var current: Array = []
var main_script: GDScript


## 2D glyphs for tools that aren't a thing you place.
class Glyph extends Node2D:
	var kind := ""

	func _draw() -> void:
		var ink := Color("#5A3426")
		var tile := Color("#A8E6C8")
		var tile_edge := Color("#6CC79F")
		var coral := Color("#F6845E")
		var pink := Color("#F4829F")
		var lemon := Color("#F7D66B")
		var lilac := Color("#B99BEA")
		var rasp := Color("#C8204F")
		var cream := Color("#FFF4E0")
		match kind:
			"paint", "raise", "lower", "fill", "erase", "pick", "clear":
				# A candy tile in the middle for all ground tools.
				var pts := PackedVector2Array([Vector2(64, 60), Vector2(112, 84), Vector2(64, 108), Vector2(16, 84)])
				draw_colored_polygon(PackedVector2Array([Vector2(16, 84), Vector2(64, 108), Vector2(64, 120), Vector2(16, 96)]), Color("#7A4A36"))
				draw_colored_polygon(PackedVector2Array([Vector2(112, 84), Vector2(64, 108), Vector2(64, 120), Vector2(112, 96)]), ink)
				draw_colored_polygon(pts, tile)
				draw_polyline(pts + PackedVector2Array([pts[0]]), tile_edge, 3.0)
		match kind:
			"paint":
				draw_line(Vector2(96, 10), Vector2(62, 58), Color("#C98A5A"), 10.0)
				draw_circle(Vector2(58, 64), 12.0, pink)
				draw_colored_polygon(PackedVector2Array([Vector2(48, 70), Vector2(70, 58), Vector2(58, 84)]), pink)
			"raise", "lower":
				var up := kind == "raise"
				var y0 := 60.0 if up else 14.0
				var y1 := 14.0 if up else 60.0
				draw_line(Vector2(64, y0), Vector2(64, y1 + (10 if up else -10)), coral, 14.0)
				var tip := Vector2(64, y1)
				var d := 1.0 if up else -1.0
				draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-20, 22 * d), tip + Vector2(20, 22 * d)]), coral)
			"fill":
				draw_colored_polygon(PackedVector2Array([Vector2(40, 22), Vector2(84, 22), Vector2(78, 64), Vector2(46, 64)]), lilac)
				draw_arc(Vector2(62, 22), 22, PI, TAU, 16, ink, 4.0)
				draw_circle(Vector2(92, 58), 8.0, Color("#8CC9F0"))
				draw_colored_polygon(PackedVector2Array([Vector2(86, 54), Vector2(92, 40), Vector2(98, 54)]), Color("#8CC9F0"))
			"erase":
				draw_line(Vector2(40, 24), Vector2(88, 72), rasp, 14.0)
				draw_line(Vector2(88, 24), Vector2(40, 72), rasp, 14.0)
			"pick":
				draw_line(Vector2(96, 16), Vector2(56, 64), ink, 10.0)
				draw_circle(Vector2(98, 14), 12.0, pink)
				draw_circle(Vector2(52, 70), 6.0, tile_edge)
			"clear":
				for s: Array in [[Vector2(46, 34), 16.0], [Vector2(86, 26), 11.0], [Vector2(80, 60), 9.0]]:
					var c: Vector2 = s[0]
					var r: float = s[1]
					draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.3, -r * 0.3), c + Vector2(r, 0),
						c + Vector2(r * 0.3, r * 0.3), c + Vector2(0, r), c + Vector2(-r * 0.3, r * 0.3), c + Vector2(-r, 0),
						c + Vector2(-r * 0.3, -r * 0.3)]), lemon)
			"select":
				var arrow := PackedVector2Array([Vector2(36, 14), Vector2(36, 104), Vector2(58, 84), Vector2(74, 116),
					Vector2(90, 108), Vector2(74, 78), Vector2(102, 76)])
				draw_colored_polygon(arrow, cream)
				draw_polyline(arrow + PackedVector2Array([arrow[0]]), ink, 6.0)
			"route":
				var pts := PackedVector2Array()
				for k in 7:
					var t := k / 6.0
					pts.append(Vector2(16 + t * 96, 96 - sin(t * PI) * 60 + t * 0))
				for k in range(0, pts.size() - 1):
					if k % 2 == 0:
						draw_line(pts[k], pts[k + 1], lilac, 8.0)
				for k in [0, 3, 6]:
					draw_circle(pts[k], 12.0, Color("#8C5BD6"))
					draw_circle(pts[k], 5.0, cream)


func _initialize() -> void:
	main_script = load("res://scripts/main.gd")
	DirAccess.make_dir_recursive_absolute(OUT)
	vp = SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFF1F6")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.far = 200
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)
	vp2 = SubViewport.new()
	vp2.size = SIZE
	vp2.transparent_bg = true
	vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp2)

	for g in ["paint", "raise", "lower", "fill", "erase", "pick", "clear", "select", "route"]:
		jobs.append(["glyph", g])
	var tiles := {
		sections = [["11111", "00000", "00000", "11111"], [".....", ".>...", ".>...", "....."], [], 10.0],
		road = [["1111.", "0001.", "0001.", "1001.", ".00..", "....."], [], [], 11.5],
		box = [["2222", "2112", "2112", "2222"], [], [], 9.5],
		ramp = [["0ee2", "0ee2", "0ee2"], [], [], 9.0],
		waves = [["000", "000", "000"], ["WWW", "WWW", "WWW"], [], 8.0],
		hill = [["000", "000", "000"], ["...", ".H.", "..."], [], 8.0],
		trench = [["000", "000", "000"], ["...", "TTT", "..."], [], 8.0],
		goal = [["000", "000", "000"], ["...", ".G.", "..."], [], 7.0],
		checkpoint = [["000", "000", "000"], ["...", ".K.", "..."], [], 8.0],
		goo = [["000", "000", "000"], ["...", ".A.", "..."], [], 7.0],
		humps = [["0000", "0000"], ["MMMM", "MMMM"], [], 8.0],
		bumper = [["0"], ["B"], [], 2.6],
		booster = [["0"], [">"], [], 2.6],
		star = [["0"], ["@"], [], 2.6],
		target = [["0"], ["#"], [], 2.6],
		decor = [["0"], ["l"], [], 3.0],
		enemy = [["0"], [], [{type = "enemy", tile = [0, 0], travel = [0, 0, 0]}], 2.8],
		stomper = [["00", "00"], [], [{type = "stomper", tile = [0.5, 0.5], phase = 0.3}], 4.4],
		hopper = [["0"], [], [{type = "hopper", tile = [0, 0], travel = [0, 0, 0]}], 2.6],
		ghost = [["0"], [], [{type = "ghost", tile = [0, 0]}], 2.8],
		windmill = [["000", "000", "000"], [], [{type = "windmill", tile = [1, 1], arm_length = 2.6}], 8.5],
		slingshot = [["0"], [], [{type = "slingshot", tile = [0, 0], yaw = 45.0}], 2.6],
		cannon = [["00"], [], [{type = "cannon", tile = [0, 0], target_tile = [6, 0]}], 3.6],
		catapult = [["00"], [], [{type = "catapult", tile = [0, 0], target_tile = [0, -6]}], 4.2],
		loop = [["000", "000", "000", "000"], [], [{type = "loop", tile = [1, 1.5]}], 11.0],
		chute = [["....", "...."], [], [{type = "chute", tile = [1.5, 0.5], yaw = 90.0, y = 0.0}], 8.0],
		hoop = [["0"], [], [{type = "hoop", tile = [0, 0], yaw = 45.0, height = 1.2}], 4.0],
		spinner = [["0"], [], [{type = "spinner", tile = [0, 0], yaw = 45.0}], 2.6],
		redirect = [["0"], [], [{type = "redirect", tile = [0, 0], yaw = 90.0}], 2.8],
		flipper = [["00"], [], [{type = "flipper", tile = [0.5, 0], yaw = 0.0}], 3.2],
		ice = [["000", "000", "000"], ["III", "III", "III"], [], 7.0],
		steelie = [["0"], [], [{type = "steelie", tile = [0, 0]}], 2.6],
		slime = [["0"], [], [{type = "slime", tile = [0, 0], travel = [0, 0, 0]}], 2.8],
		pipe = [["00"], [], [{type = "pipe", tile = [0, 0], target_tile = [0, 0.4]}], 3.4],
		goalpad = [["000", "000"], [], [{type = "goalpad", tile = [1, 0.5]}], 7.5],
	}
	for id: String in tiles:
		jobs.append(["tile", id, tiles[id]])
	jobs.append(["spawn", "spawn"])
	for p: Array in TrackPieces.LIST:
		jobs.append(["piece", p[0]])


func _process(_d: float) -> bool:
	if wait > 0:
		wait -= 1
		if wait == 0:
			_save()
		return false
	if jobs.is_empty():
		print("icons done")
		quit()
		return false
	current = jobs.pop_front()
	_clear()
	match current[0]:
		"glyph":
			var g := Glyph.new()
			g.kind = current[1]
			vp2.add_child(g)
		"tile":
			var spec: Array = current[2]
			_level(spec[0], spec[1], spec[2], spec[3], SIZE)
		"spawn":
			_level(["0"], [], [], 2.4, SIZE)
			var ball := Node3D.new()
			holder.add_child(ball)
			ball.position = Vector3(1, 0.5, 1)
			Palette.load_model(ball, "ball")
		"piece":
			var piece := TrackPieces.get_piece(current[1])
			var res := TrackPieces.stamp(piece, Vector2i(1, 1), 0, piece.entry)
			var lo := Vector2i(1000, 1000)
			var hi := -lo
			for c: Vector2i in res.cells:
				lo = lo.min(c)
				hi = hi.max(c)
			var w := hi.x - lo.x + 1
			var h := hi.y - lo.y + 1
			var hs := []
			var os := []
			for j in h:
				var hl := ""
				var ol := ""
				for i in w:
					var v: Array = res.cells.get(Vector2i(i, j) + lo, [".", "."])
					hl += v[0]
					ol += v[1]
				hs.append(hl)
				os.append(ol)
			var ex := []
			for e: Dictionary in res.extras:
				var c := e.duplicate(true)
				c.tile = [e.tile[0] - lo.x, e.tile[1] - lo.y]
				if c.has("target_tile"):
					c.target_tile = [e.target_tile[0] - lo.x, e.target_tile[1] - lo.y]
				ex.append(c)
			# Iso footprint of a w x h tile block, fitted to the 3:2 thumbnail.
			var across := (w + h) * 2.0 * 0.71
			_level(hs, os, ex, maxf(across / 1.5, across * 0.62) * 1.12 + 1.0, PIECE_SIZE)
	vp.size = SIZE if current[0] != "piece" else PIECE_SIZE
	wait = 4
	return false


func _clear() -> void:
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()
	for c in vp2.get_children():
		vp2.remove_child(c)
		c.queue_free()


func _level(hs: Array, os: Array, extras: Array, size: float, _px: Vector2i) -> void:
	var objs := os.duplicate()
	while objs.size() < hs.size():
		objs.append(".".repeat((hs[0] as String).length()))
	var d := {title = "icon", heights = hs, objects = objs, extras = extras, par = 30.0}
	var l := CustomLevel.from_dict(d)
	l.build()
	var t := Terrain.new(l)
	holder.add_child(t)
	for cloud in t.get_children():
		if cloud.name.begins_with("cloud") or cloud is Node3D and not cloud is MeshInstance3D and not cloud is CollisionShape3D and not cloud is MultiMeshInstance3D:
			cloud.visible = false
	for e in l.entities:
		var n: Node3D = main_script.spawn_entity(e, l, holder)
		n.process_mode = Node.PROCESS_MODE_DISABLED
	var center := Vector3(l.cols, 0.6, l.rows)
	cam.size = size
	cam.global_position = center + cam.global_basis.z * 60.0


func _save() -> void:
	var img: Image
	var name: String
	if current[0] == "glyph":
		img = vp2.get_texture().get_image()
		name = "tool_" + current[1]
	elif current[0] == "piece":
		img = vp.get_texture().get_image()
		name = "piece_" + current[1]
	else:
		img = vp.get_texture().get_image()
		name = "tool_" + current[1]
	img.save_png(OUT + name + ".png")

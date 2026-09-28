class_name LevelEditor
extends Node3D
## In-game level editor. Edits one level of a Quest at a time and shows it
## live in 3D, built by the same code as the game (Terrain, CustomLevel,
## MainGame.spawn_entity). The panels live in EditorUI.
##
## Mouse: left = use tool, right click = remove the thing under the cursor
## (right drag or middle drag = pan), wheel = zoom.
## Keys: WASD / arrows pan, Q / E turn (3D view), Tab top / 3D view, R rotate,
## Del delete, Ctrl+Z / Ctrl+Y undo / redo, Ctrl+D duplicate, Ctrl+S save,
## F5 test play, 0-9 ground height, [ ] brush size, F1 help.

const SkyShader := preload("res://scripts/sky.gdshader")
const TILE := LevelBase.TILE
const TOP_PITCH := 64.0

## Kept across the trip to test play and back.
static var session_quest: Quest = null
static var session_level := 0
static var session_view := {}

## [id, label, group, hint]
const TOOLS := [
	["sections", "Sections", "Build", "Ready-made track pieces, in the Pieces tab on the right. Clicking one adds it at the green arrow. Clicking the map puts the picked piece there instead; R, Shift+R or right click turns it first."],
	["road", "Road", "Build", "Drag to draw a lane with rails. It keeps the height where you start, opens walls and ramps up or down to meet other ground."],
	["select", "Select", "Build", "Click a thing to tweak it, drag to move it. Shift snaps to half tiles."],
	["route", "Path", "Build", "Rival and camera path. Click to add points, right click removes the last."],
	["paint", "Paint", "Ground", "Paint ground at the chosen height. Paint past the edge to grow the map."],
	["box", "Box", "Ground", "Drag out a rectangle of ground. Tick Walls to get a rail around it."],
	["raise", "Raise", "Ground", "Click or drag to lift tiles one step."],
	["lower", "Lower", "Ground", "Click or drag to sink tiles one step."],
	["ramp", "Ramp", "Ground", "Slope between two heights. A ramp that runs into void is a jump."],
	["fill", "Fill", "Ground", "Flood fill a connected area with the chosen height."],
	["erase", "Erase", "Ground", "Remove ground and everything on it."],
	["pick", "Pick", "Ground", "Click a tile to copy its height."],
	["waves", "Waves", "Surface", "Wobbly Marble Madness ripples."],
	["hill", "Hill", "Surface", "A round bump."],
	["trench", "Trench", "Surface", "A channel. Neighbouring trench tiles join up."],
	["ice", "Ice", "Surface", "Slippery ice: hardly any grip, the marble slides on."],
	["humps", "Humps", "Surface", "Big smooth humps across a lane. Paint a strip; the humps run along its long side."],
	["goo", "Goo", "Surface", "Sour goo pool, Marble Madness's acid. Rolling in pops the marble."],
	["clear", "Clear", "Surface", "Remove surface bumps and objects from tiles (keeps the ground)."],
	["spawn", "Start", "Objects", "Where the marble starts. Only one."],
	["goal", "Hole", "Objects", "The golf hole. Only one."],
	["goalpad", "Goal pad", "Objects", "Marble Madness finish: a checkered GOAL pad. Use it instead of the hole."],
	["checkpoint", "Gate", "Objects", "Checkpoint gate. It spans the track by itself; R turns it."],
	["bumper", "Bumper", "Objects", "Pop bumper. Fills the Sugar Rush meter."],
	["booster", "Booster", "Objects", "Speed pad. R turns it."],
	["star", "Star", "Objects", "Rollover star (pinball toy)."],
	["target", "Target", "Objects", "Drop target (pinball toy)."],
	["decor", "Decor", "Objects", "Candy scenery. Pick the kind below."],
	["enemy", "Sweeper", "Monsters", "Wind-up block that patrols. Drag to set how far it walks."],
	["stomper", "Stomper", "Monsters", "Drops down and squashes the marble."],
	["hopper", "Hopper", "Monsters", "Hops back and forth. Drag to set its path."],
	["ghost", "Ghost", "Monsters", "Floats after the marble when it comes close."],
	["windmill", "Windmill", "Monsters", "Spinning arm that swats the marble away."],
	["steelie", "Steelie", "Monsters", "Dark metal marble that rolls after you and shoves you off edges."],
	["slime", "Slime", "Monsters", "Sour acid blob sliding back and forth. It melts you. Drag to set its path."],
	["slingshot", "Sling", "Toys", "Pinball slingshot. Kicks the marble back."],
	["cannon", "Cannon", "Toys", "Shoots the marble. Click again to set where it lands."],
	["catapult", "Catapult", "Toys", "Flings the marble. Click again to set where it lands."],
	["loop", "Loop", "Toys", "Loop the loop. Put a booster in front."],
	["chute", "Chute", "Toys", "Swoopy S-curve slide."],
	["hoop", "Hoop", "Toys", "Ring to jump through."],
	["spinner", "Spinner", "Toys", "Spinning gate."],
	["redirect", "Turner", "Toys", "Catches the marble and launches it the way it points."],
	["pipe", "Pipe", "Toys", "Roll into the funnel, pop out of the spout. Click again to place the spout."],
	["bird", "Bird", "Toys", "Hovers over its perch. Roll on and it carries the marble to where you click next."],
	["flipper", "Flipper", "Toys", "Pinball flipper: bats the marble the way it points (R turns)."],
]
const OBJ_CHAR := {spawn = "S", goal = "G", bumper = "B", star = "@", target = "#",
	waves = "W", hill = "H", trench = "T", goo = "A", humps = "M", ice = "I"}
const OBJ_NAMES := {
	"S": "Start", "G": "Golf hole", "B": "Bumper", ">": "Booster", "<": "Booster", "v": "Booster",
	"^": "Booster", "C": "Checkpoint", "K": "Checkpoint", "W": "Waves", "H": "Hill", "P": "Cone", "T": "Trench",
	"@": "Rollover star", "A": "Sour goo", "M": "Humps", "I": "Ice", "#": "Drop target", "l": "Lollipop", "t": "Candy tree", "b": "Gummy bear",
	"g": "Gumdrop", "%": "Golden cupcake", "h": "Heart candy", "r": "Wrapped candy", "$": "Gem candy",
}
const DECOR := [["l", "Lollipop"], ["t", "Candy tree"], ["b", "Gummy bear"], ["g", "Gumdrop"],
	["%", "Golden cupcake"], ["h", "Heart candy"], ["r", "Wrapped candy"], ["$", "Gem candy"]]
const BOOSTER_TURN := {">": "v", "v": "<", "<": "^", "^": ">"}
const EXTRA_NAMES := {
	"enemy": "Sweeper", "stomper": "Stomper", "hopper": "Hopper", "ghost": "Ghost", "windmill": "Windmill",
	"slingshot": "Slingshot", "cannon": "Cannon", "catapult": "Catapult", "loop": "Loop", "chute": "Chute",
	"hoop": "Hoop", "spinner": "Spinner", "redirect": "Turner", "flipper": "Flipper",
	"steelie": "Steelie", "slime": "Slime", "pipe": "Pipe", "bird": "Bird", "goalpad": "Goal pad",
}
const PAINT_TOOLS := ["road", "paint", "raise", "lower", "ramp", "erase", "waves", "hill", "trench", "goo", "humps", "ice", "clear", "decor",
	"bumper", "star", "target", "booster"]
const MAX_UNDO := 120

signal selection_changed
signal level_changed
## Tiles or size changed (cheaper than level_changed for the panels).
signal map_changed
## The preview was rebuilt (the guide refreshes on this).
signal rebuilt
signal quest_changed

var quest: Quest
var li := 0
var lv: Dictionary
var built: CustomLevel

var tool := "sections"
var section_id := "straight"
var section_heading := 0
var road_width := 4
var road_rails := true
## Guide: shade ground the marble can't reach and point at the gap.
var show_reach := true
## Set after a test play, cleared by the next edit.
static var session_tested := false
var tested := false
var reach := {}
var tier := 1
var brush := 1
var ramp_dir := "auto"
var booster_dir := ">"
var decor_char := "l"
var box_walls := false
var animate := false
var show_grid := true
var show_scenery := true
var top_view := true

## {kind: "extra", index: int} or {kind: "obj", tile: Vector2i} or {}
var selection := {}
var dirty := false
var unsaved := false

var camera: Camera3D
var cam_target := Vector3(15, 0, 10)
var cam_size := 26.0
var cam_yaw := 45.0
var world: Node3D
var overlay: Node3D
var ui: EditorUI

var _undo: Array = []
var _redo: Array = []
var _stroke := false
var _stroke_tiles := {}
var _stroke_start := Vector2i.ZERO
var _stroke_start_f := Vector2.ZERO
var _last_tile := Vector2i(-9999, -9999)
var _hover := Vector2i(-9999, -9999)
var _hover_f := Vector2.ZERO
var _hover_valid := false
var _pending_target := -1
## Waiting for a click on the map to start a test play there.
var pending_test := false
var _pan_button := -1
var _pan_moved := 0.0
var _press_pos := Vector2.ZERO
var _rebuild_timer := 0.0
var _autosave := 0.0
var _hover_mesh: MeshInstance3D
var _grid_mesh: MeshInstance3D
var _marks: Node3D
var _t := 0.0
var _shift := Vector2i.ZERO   # total growth to the left/top, for strokes that grow the map
var _merge_key := ""
var _drag_undo := false
var _road_tiles := {}
var _road_tier := 0
var _road_heading := 0
var _road_square: Array[Vector2i] = []
var _ghost_mesh: MeshInstance3D
## Preview terrain is built in CHUNK x CHUNK tile pieces so painting only
## rebuilds the pieces it touches.
const CHUNK := 12
var _terrain_root: Node3D
## Scenery lives outside `world` and is only rebuilt when the map size changes,
## so it doesn't jump around on every edit.
var _backdrop: Node3D
var _backdrop_key := ""
var _ents: Node3D
var _chunks := {}
var _dirty_tiles := {}
var _stroke_dirty := {}
var _tiles_only := true
var _heights_only := true


func _ready() -> void:
	_setup_environment()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	overlay = Node3D.new()
	add_child(overlay)
	_grid_mesh = MeshInstance3D.new()
	_grid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.add_child(_grid_mesh)
	_ghost_mesh = MeshInstance3D.new()
	_ghost_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.add_child(_ghost_mesh)
	_hover_mesh = MeshInstance3D.new()
	_hover_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.add_child(_hover_mesh)
	_marks = Node3D.new()
	overlay.add_child(_marks)

	var q := session_quest
	if q == null:
		Quest.install_samples()
		var installed := Quest.list_installed()
		q = installed[0] if not installed.is_empty() else Quest.create()
	quest = q
	li = clampi(session_level, 0, quest.levels.size() - 1)
	lv = quest.levels[li]
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = EditorUI.new()
	ui.ed = self
	layer.add_child(ui)
	open_quest(q, session_level)
	if not session_view.is_empty():
		cam_target = session_view.target
		cam_size = session_view.size
		cam_yaw = session_view.yaw
		top_view = session_view.top
		_apply_camera()
	session_quest = null
	session_view = {}
	tested = session_tested
	get_window().files_dropped.connect(_on_files_dropped)
	var music := "res://audio/Spun_Sugar_Waltz.mp3"
	if ResourceLoader.exists(music):
		var p := AudioStreamPlayer.new()
		var stream: AudioStreamMP3 = load(music)
		stream.loop = true
		p.stream = stream
		p.volume_db = -16.0
		p.bus = "Music"
		p.autoplay = true
		add_child(p)


func _setup_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFF1F6")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_color = Color("#FFF6EC")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	Settings.apply_graphics(env, sun)


# --- quest and level --------------------------------------------------------------

func open_quest(q: Quest, level_index: int = 0) -> void:
	quest = q
	quest_changed.emit()
	open_level(clampi(level_index, 0, quest.levels.size() - 1), true)


func open_level(index: int, frame: bool = true) -> void:
	li = index
	lv = quest.levels[li]
	_undo.clear()
	_redo.clear()
	selection = {}
	_pending_target = -1
	_full_rebuild()
	if frame:
		frame_level()
	level_changed.emit()
	selection_changed.emit()


func save() -> void:
	quest.save()
	unsaved = false
	ui.toast("Saved  \"%s\"" % quest.name)


## Saves only real changes: saving stamps the quest as edited, and an edited
## shipped sample no longer gets the newer version on the next launch.
func save_if_changed() -> void:
	if unsaved:
		quest.save()
		unsaved = false


## `tiles_only`: only map characters changed (set_h / set_o), so the preview
## can rebuild just the touched chunks.
func mark_edited(tiles_only: bool = false) -> void:
	tested = false
	session_tested = false
	if not tiles_only:
		_tiles_only = false
	dirty = true
	unsaved = true
	_rebuild_timer = 0.0


func level_dict() -> Dictionary:
	return lv


func cols() -> int:
	return (lv.heights[0] as String).length() if lv.heights.size() > 0 else 0


func rows() -> int:
	return lv.heights.size()


func hchar(i: int, j: int) -> String:
	if j < 0 or j >= rows() or i < 0 or i >= cols():
		return "."
	return (lv.heights[j] as String)[i]


func ochar(i: int, j: int) -> String:
	if j < 0 or j >= rows() or i < 0 or i >= cols():
		return "."
	return (lv.objects[j] as String)[i]


func set_h(i: int, j: int, c: String) -> void:
	_set_char("heights", i, j, c)


func set_o(i: int, j: int, c: String) -> void:
	_set_char("objects", i, j, c)


func _set_char(key: String, i: int, j: int, c: String) -> void:
	if j < 0 or j >= rows() or i < 0 or i >= cols():
		return
	var line: String = lv[key][j]
	if line[i] == c:
		return
	lv[key][j] = line.substr(0, i) + c + line.substr(i + 1)
	_dirty_tiles[Vector2i(i, j)] = true
	_stroke_dirty[Vector2i(i, j)] = true
	if key == "objects":
		_heights_only = false


func is_ground(i: int, j: int) -> bool:
	return hchar(i, j) != "."


## Grows or shrinks the map on each side (negative crops). Moves extras and
## the path along and keeps the camera on the same spot.
func resize(left: int, top: int, right: int, bottom: int) -> void:
	var w := cols() + left + right
	var h := rows() + top + bottom
	if w < 3 or h < 3 or w > CustomLevel.MAX_SIZE or h > CustomLevel.MAX_SIZE:
		ui.toast("The map can be 3 to %d tiles on each side" % CustomLevel.MAX_SIZE)
		return
	var old_w := cols()
	var old_h := rows()
	for key in ["heights", "objects"]:
		var out: Array = []
		for j in h:
			var jo := j - top
			var line: String = lv[key][jo] if jo >= 0 and jo < old_h else ""
			if line == "":
				line = ".".repeat(old_w)
			line = (".".repeat(left) + line) if left >= 0 else line.substr(-left)
			out.append(line.substr(0, w).rpad(w, "."))
		lv[key] = out
	var keep: Array = []
	for e: Dictionary in lv.extras:
		e.tile = [e.tile[0] + left, e.tile[1] + top]
		if e.has("target_tile"):
			e.target_tile = [e.target_tile[0] + left, e.target_tile[1] + top]
		if e.tile[0] > -1.0 and e.tile[1] > -1.0 and e.tile[0] < w and e.tile[1] < h:
			keep.append(e)
	lv.extras = keep
	var route: Array = []
	for p: Array in lv.route:
		route.append([p[0] + left, p[1] + top])
	lv.route = route
	if lv.has("track_end"):
		lv.track_end = [lv.track_end[0] + left, lv.track_end[1] + top, lv.track_end[2], lv.track_end[3]]
	if not _road_tiles.is_empty():
		var moved := {}
		for t: Vector2i in _road_tiles:
			moved[t + Vector2i(left, top)] = true
		_road_tiles = moved
		for k in _road_square.size():
			_road_square[k] += Vector2i(left, top)
	cam_target += Vector3(left * TILE, 0, top * TILE)
	_stroke_start += Vector2i(left, top)
	_shift += Vector2i(left, top)
	if selection.get("kind") == "obj":
		selection.tile += Vector2i(left, top)
	_apply_camera()
	mark_edited()
	_full_rebuild()
	map_changed.emit()


## Makes sure tile (i, j) is inside the map, growing it if needed. Returns
## the tile's coordinates after growing.
func ensure_tile(i: int, j: int) -> Vector2i:
	var left := maxi(0, -i)
	var top := maxi(0, -j)
	var right := maxi(0, i - cols() + 1)
	var bottom := maxi(0, j - rows() + 1)
	if left + top + right + bottom == 0:
		return Vector2i(i, j)
	if cols() + left + right > CustomLevel.MAX_SIZE or rows() + top + bottom > CustomLevel.MAX_SIZE:
		return Vector2i(-1, -1)
	resize(left, top, right, bottom)
	return Vector2i(i + left, j + top)


## Crops empty void rows and columns, keeping a one tile border.
func crop() -> void:
	var x0 := cols()
	var y0 := rows()
	var x1 := -1
	var y1 := -1
	for j in rows():
		for i in cols():
			if is_ground(i, j):
				x0 = mini(x0, i)
				y0 = mini(y0, j)
				x1 = maxi(x1, i)
				y1 = maxi(y1, j)
	if x1 < 0:
		return
	push_undo()
	resize(1 - x0, 1 - y0, x1 + 2 - cols(), y1 + 2 - rows())


# --- undo -----------------------------------------------------------------------

func push_undo() -> void:
	_merge_key = ""
	_undo.append(lv.duplicate(true))
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()


func undo() -> void:
	if _undo.is_empty():
		ui.toast("Nothing to undo")
		return
	_redo.append(lv.duplicate(true))
	_restore(_undo.pop_back())


func redo() -> void:
	if _redo.is_empty():
		ui.toast("Nothing to redo")
		return
	_undo.append(lv.duplicate(true))
	_restore(_redo.pop_back())


func _restore(snap: Dictionary) -> void:
	lv.clear()
	lv.merge(snap)
	selection = {}
	_pending_target = -1
	mark_edited()
	_full_rebuild()
	level_changed.emit()
	selection_changed.emit()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


# --- tools ----------------------------------------------------------------------

func set_tool(id: String) -> void:
	tool = id
	_pending_target = -1
	ui.on_tool_changed()
	_update_hover()


func tool_hint() -> String:
	if pending_test:
		return "Click where the marble should start the test play.  Esc cancels."
	if _pending_target >= 0:
		return "Click where the marble should land.  Esc cancels."
	for t in TOOLS:
		if t[0] == tool:
			return t[3]
	return ""


func _brush_tiles(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := brush - 1
	for dj in range(-r, r + 1):
		for di in range(-r, r + 1):
			out.append(c + Vector2i(di, dj))
	return out


func _stroke_begin(tile: Vector2i, f: Vector2, shift: bool) -> void:
	if pending_test:
		pending_test = false
		ui.on_tool_changed()
		if is_ground(tile.x, tile.y):
			test_play(tile)
		else:
			ui.toast("Pick a tile with ground on it")
		return
	if _pending_target >= 0:
		push_undo()
		var e: Dictionary = lv.extras[_pending_target]
		e.target_tile = [float(tile.x), float(tile.y)] if not shift else [snappedf(f.x - 0.5, 0.5), snappedf(f.y - 0.5, 0.5)]
		_pending_target = -1
		mark_edited()
		selection_changed.emit()
		ui.on_tool_changed()
		return
	_stroke = true
	_drag_undo = false
	_stroke_tiles = {}
	_stroke_start = tile
	_stroke_start_f = f
	_last_tile = tile
	if tool == "select":
		_select_at(tile, f)
		return
	if tool == "box":
		return
	if tool == "sections":
		_place_section_at(tile)
		_stroke = false
		return
	push_undo()
	if tool == "road":
		_road_tiles = {}
		_road_square = []
		_road_heading = 0
		var c := hchar(tile.x, tile.y)
		_road_tier = int(c) if c.is_valid_int() else tier
	_apply(tile, f, shift)


func _stroke_move(tile: Vector2i, f: Vector2, shift: bool) -> void:
	if not _stroke or tile == _last_tile and tool != "select":
		return
	if tool == "select":
		_drag_selection(tile, f, shift)
	elif tool in PAINT_TOOLS:
		if tool == "road":
			var dv := tile - _last_tile
			if dv != Vector2i.ZERO:
				if absi(dv.x) >= absi(dv.y):
					_road_heading = 0 if dv.x > 0 else 2
				else:
					_road_heading = 1 if dv.y > 0 else 3
		# Fill in the tiles between mouse samples so fast strokes have no gaps.
		# Growing the map shifts coordinates; later points follow the shift.
		var from := _last_tile
		var steps := maxi(absi(tile.x - from.x), absi(tile.y - from.y))
		var s0 := _shift
		for k in range(1, steps + 1):
			var p := Vector2(from).lerp(Vector2(tile), float(k) / steps).round()
			_apply(Vector2i(p) + (_shift - s0), f, shift)
		tile += _shift - s0
	elif tool in ["enemy", "hopper"] and not selection.is_empty():
		var e: Dictionary = lv.extras[selection.index]
		var d := Vector2(tile - _stroke_start) * TILE
		e.travel = [d.x, 0.0, d.y] if d.length() > 0.1 else _default_travel(_stroke_start)
		mark_edited()
	_last_tile = tile


func _stroke_end(tile: Vector2i, f: Vector2, _shift: bool) -> void:
	if not _stroke:
		return
	_stroke = false
	if tool == "box":
		push_undo()
		_fill_box(_stroke_start, tile)
	if tool == "road":
		_finish_road()
	# Settle everything the stroke touched, with room for long ramp runs.
	_dirty_tiles.merge(_stroke_dirty)
	_stroke_dirty = {}
	if tool == "select" and not selection.is_empty():
		selection_changed.emit()
	if tool in ["enemy", "hopper"]:
		selection_changed.emit()
	_rebuild()
	map_changed.emit()


func _apply(tile: Vector2i, f: Vector2, shift: bool) -> void:
	match tool:
		"road":
			var s3 := _shift
			var lo := -(road_width - 1) / 2
			var sq: Array[Vector2i] = []
			for dj in range(lo, lo + road_width):
				for di in range(lo, lo + road_width):
					var g := ensure_tile(tile.x + di + _shift.x - s3.x, tile.y + dj + _shift.y - s3.y)
					if g.x >= 0:
						set_h(g.x, g.y, str(_road_tier))
						_road_tiles[g] = true
						sq.append(g)
			# Keep the last square in the latest coordinates.
			for k in sq.size():
				sq[k] += _shift - s3
			_road_square = sq
		"paint":
			var s0 := _shift
			for t in _brush_tiles(tile):
				var g := ensure_tile(t.x + _shift.x - s0.x, t.y + _shift.y - s0.y)
				if g.x >= 0:
					set_h(g.x, g.y, str(tier))
		"raise", "lower":
			var s1 := _shift
			for t0 in _brush_tiles(tile):
				var t := t0 + _shift - s1
				if _stroke_tiles.has(t - _shift):
					continue
				_stroke_tiles[t - _shift] = true
				var c := hchar(t.x, t.y)
				if tool == "raise":
					if c == ".":
						var g := ensure_tile(t.x + _shift.x - s1.x, t.y + _shift.y - s1.y)
						if g.x >= 0:
							set_h(g.x, g.y, "0")
					elif c.is_valid_int():
						set_h(t.x, t.y, str(mini(9, int(c) + 1)))
				elif c.is_valid_int():
					set_h(t.x, t.y, str(maxi(0, int(c) - 1)))
		"ramp":
			var s2 := _shift
			for t in _brush_tiles(tile):
				var g := ensure_tile(t.x + _shift.x - s2.x, t.y + _shift.y - s2.y)
				if g.x >= 0:
					set_h(g.x, g.y, _ramp_char(g))
		"erase":
			for t in _brush_tiles(tile):
				set_h(t.x, t.y, ".")
				set_o(t.x, t.y, ".")
				_remove_extras_at(t)
		"clear":
			for t in _brush_tiles(tile):
				set_o(t.x, t.y, ".")
				_remove_extras_at(t)
		"fill":
			_flood(tile)
		"pick":
			var c := hchar(tile.x, tile.y)
			if c.is_valid_int():
				tier = int(c)
				set_tool("paint")
				ui.toast("Height %d" % tier)
			return
		"waves", "hill", "trench", "goo", "humps", "ice":
			for t in _brush_tiles(tile):
				if is_ground(t.x, t.y):
					set_o(t.x, t.y, OBJ_CHAR[tool])
		"spawn", "goal":
			if not is_ground(tile.x, tile.y):
				ui.toast("Put it on ground")
				return
			var ch: String = OBJ_CHAR[tool]
			for j in rows():
				var at: int = (lv.objects[j] as String).find(ch)
				if at >= 0:
					set_o(at, j, ".")
			set_o(tile.x, tile.y, ch)
			_select_obj(tile)
		"checkpoint":
			if not is_ground(tile.x, tile.y):
				ui.toast("Put it on ground")
				return
			set_o(tile.x, tile.y, "K" if _run_length(tile, Vector2i(1, 0)) < _run_length(tile, Vector2i(0, 1)) else "C")
			_select_obj(tile)
		"bumper", "star", "target", "booster", "decor":
			var ch: String = booster_dir if tool == "booster" else (decor_char if tool == "decor" else OBJ_CHAR[tool])
			if is_ground(tile.x, tile.y):
				set_o(tile.x, tile.y, ch)
				if tool != "decor":
					_select_obj(tile)
		_:
			if CustomLevel.EXTRA_PARAMS.has(tool):
				_add_extra(tool, tile, f, shift)
				_stroke = tool in ["enemy", "hopper"]
			elif tool == "route":
				var p := [float(tile.x), float(tile.y)] if not shift else [snappedf(f.x - 0.5, 0.5), snappedf(f.y - 0.5, 0.5)]
				lv.route.append(p)
	mark_edited(not (CustomLevel.EXTRA_PARAMS.has(tool) or tool == "route"))


func _ramp_char(t: Vector2i) -> String:
	if ramp_dir != "auto":
		return ramp_dir
	# Rises towards the higher neighbour; if none, keep the current direction or
	# follow the drag.
	var best := ""
	var best_rise := 0.0
	# Straight ramps first, so a diagonal only wins when it rises more.
	var dirs := {"e": Vector2i(1, 0), "w": Vector2i(-1, 0), "s": Vector2i(0, 1), "n": Vector2i(0, -1)}
	dirs.merge(LevelBase.DIAG)
	for d: String in dirs:
		var v: Vector2i = dirs[d]
		var ahead := _tier_along(t, v)
		var behind := _tier_along(t, -v)
		if ahead >= 0 and behind >= 0 and ahead - behind > best_rise:
			best_rise = ahead - behind
			best = d
	if best != "":
		return best
	var drag := t - _stroke_start
	if drag != Vector2i.ZERO:
		if absi(drag.x) >= absi(drag.y):
			return "e" if drag.x > 0 else "w"
		return "s" if drag.y > 0 else "n"
	var cur := hchar(t.x, t.y)
	return cur if cur in LevelBase.RAMPS else "e"


## Tier of the first flat tile from t along v, skipping ramp tiles (-1 if void).
func _tier_along(t: Vector2i, v: Vector2i) -> int:
	var p := t + v
	for k in 12:
		var c := hchar(p.x, p.y)
		if c.is_valid_int():
			return int(c)
		if c not in LevelBase.RAMPS:
			return -1
		p += v
	return -1


func _run_length(t: Vector2i, v: Vector2i) -> int:
	var n := 1
	for s in [v, -v]:
		var p: Vector2i = t + s
		while is_ground(p.x, p.y) and n < 60:
			n += 1
			p += s
	return n


func _default_travel(t: Vector2i) -> Array:
	# Walk across the track: along the shorter side.
	var across_x := _run_length(t, Vector2i(1, 0)) < _run_length(t, Vector2i(0, 1))
	var n := clampi((_run_length(t, Vector2i(1, 0)) if across_x else _run_length(t, Vector2i(0, 1))) - 1, 1, 6)
	return [n * TILE, 0.0, 0.0] if across_x else [0.0, 0.0, n * TILE]


func _fill_box(a: Vector2i, b: Vector2i) -> void:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	var g0 := ensure_tile(lo.x, lo.y)
	if g0.x < 0:
		return
	hi += g0 - lo
	lo = g0
	var g1 := ensure_tile(hi.x, hi.y)
	if g1.x < 0:
		return
	lo += g1 - hi
	hi = g1
	for j in range(lo.y, hi.y + 1):
		for i in range(lo.x, hi.x + 1):
			var edge := i == lo.x or i == hi.x or j == lo.y or j == hi.y
			var t := tier
			if box_walls and edge and hi.x - lo.x >= 2 and hi.y - lo.y >= 2:
				t = mini(9, tier + 1)
			set_h(i, j, str(t))
	mark_edited(true)


func _flood(start: Vector2i) -> void:
	var from := hchar(start.x, start.y)
	var to := str(tier)
	if from == to:
		return
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var count := 0
	while not queue.is_empty() and count < 20000:
		var p: Vector2i = queue.pop_back()
		set_h(p.x, p.y, to)
		count += 1
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.x >= cols() or n.y >= rows() or seen.has(n):
				continue
			if hchar(n.x, n.y) == from:
				seen[n] = true
				queue.append(n)


func _add_extra(type: String, tile: Vector2i, f: Vector2, shift: bool) -> void:
	var t := [float(tile.x), float(tile.y)]
	if shift:
		t = [snappedf(f.x - 0.5, 0.5), snappedf(f.y - 0.5, 0.5)]
	var e := {type = type, tile = t, yaw = 0.0}
	if type in CustomLevel.HAS_TRAVEL:
		e.travel = _default_travel(tile)
	if type in CustomLevel.HAS_TARGET:
		e.target_tile = [t[0] + 6.0, t[1]]
	lv.extras.append(e)
	selection = {kind = "extra", index = lv.extras.size() - 1}
	if type in CustomLevel.HAS_TARGET:
		_pending_target = selection.index
		ui.on_tool_changed()
	selection_changed.emit()


func _remove_extras_at(t: Vector2i) -> void:
	var keep: Array = []
	for e: Dictionary in lv.extras:
		if Vector2i(Vector2(e.tile[0], e.tile[1]).round()) != t:
			keep.append(e)
	if keep.size() != lv.extras.size():
		_tiles_only = false
		lv.extras = keep
		selection = {}
		selection_changed.emit()


## Removes whatever is under the cursor (right click).
func remove_at(tile: Vector2i, f: Vector2) -> void:
	# With the Sections tool a right click turns the piece instead.
	if tool == "sections":
		turn_section(1)
		return
	if tool == "route":
		if not lv.route.is_empty():
			push_undo()
			lv.route.pop_back()
			mark_edited()
			_full_rebuild()
		return
	var idx := _extra_at(f)
	if idx >= 0:
		push_undo()
		lv.extras.remove_at(idx)
	elif ochar(tile.x, tile.y) != ".":
		push_undo()
		set_o(tile.x, tile.y, ".")
	else:
		return
	selection = {}
	mark_edited()
	_full_rebuild()
	selection_changed.emit()


# --- selection --------------------------------------------------------------------

func _extra_at(f: Vector2) -> int:
	var best := -1
	var best_d := 0.8
	for k in lv.extras.size():
		var e: Dictionary = lv.extras[k]
		var d := Vector2(e.tile[0] + 0.5, e.tile[1] + 0.5).distance_to(f)
		if d < best_d:
			best_d = d
			best = k
	return best


func _select_at(tile: Vector2i, f: Vector2) -> void:
	var idx := _extra_at(f)
	if idx >= 0:
		selection = {kind = "extra", index = idx}
	elif ochar(tile.x, tile.y) != ".":
		selection = {kind = "obj", tile = tile}
	else:
		selection = {}
	selection_changed.emit()
	_draw_marks()


func _select_obj(tile: Vector2i) -> void:
	selection = {kind = "obj", tile = tile}
	selection_changed.emit()


func select_extra(index: int) -> void:
	selection = {kind = "extra", index = index}
	selection_changed.emit()
	_draw_marks()


func selected_extra() -> Dictionary:
	if selection.get("kind") == "extra" and selection.index < lv.extras.size():
		return lv.extras[selection.index]
	return {}


func selected_char() -> String:
	if selection.get("kind") == "obj":
		return ochar(selection.tile.x, selection.tile.y)
	return ""


func _drag_selection(tile: Vector2i, f: Vector2, shift: bool) -> void:
	if selection.get("kind") == "extra":
		var e: Dictionary = lv.extras[selection.index]
		var nt := [float(tile.x), float(tile.y)]
		if shift:
			nt = [snappedf(f.x - 0.5, 0.5), snappedf(f.y - 0.5, 0.5)]
		if nt == e.tile:
			return
		if not _drag_undo:
			push_undo()
			_drag_undo = true
		var delta := Vector2(nt[0] - e.tile[0], nt[1] - e.tile[1])
		e.tile = nt
		if e.has("target_tile"):
			e.target_tile = [e.target_tile[0] + delta.x, e.target_tile[1] + delta.y]
		mark_edited()
	elif selection.get("kind") == "obj":
		var from: Vector2i = selection.tile
		if tile == from or not is_ground(tile.x, tile.y) or ochar(tile.x, tile.y) != ".":
			return
		if not _drag_undo:
			push_undo()
			_drag_undo = true
		var ch := ochar(from.x, from.y)
		set_o(from.x, from.y, ".")
		set_o(tile.x, tile.y, ch)
		selection.tile = tile
		mark_edited()


## Turns the piece that a click would place: +1 clockwise, -1 back.
func turn_section(dir: int) -> void:
	section_heading = posmod(section_heading + dir, 4)
	_update_hover()
	ui.on_tool_changed()


func rotate_selection(step: float = 90.0) -> void:
	if tool == "sections":
		turn_section(1 if step > 0.0 else -1)
		return
	var e := selected_extra()
	if not e.is_empty():
		push_undo()
		e.yaw = fposmod(e.get("yaw", 0.0) + step, 360.0)
		if e.type in CustomLevel.HAS_TRAVEL:
			var v := Vector2(e.travel[0], e.travel[2]).rotated(deg_to_rad(-step)).round()
			e.travel = [v.x, 0.0, v.y]
		mark_edited()
		selection_changed.emit()
		return
	var ch := selected_char()
	if ch != "":
		push_undo()
		var t: Vector2i = selection.tile
		if BOOSTER_TURN.has(ch):
			set_o(t.x, t.y, BOOSTER_TURN[ch])
		elif ch == "C" or ch == "K":
			set_o(t.x, t.y, "K" if ch == "C" else "C")
		mark_edited()
		selection_changed.emit()
		return
	if tool == "booster":
		booster_dir = BOOSTER_TURN[booster_dir]
		ui.on_tool_changed()


func delete_selection() -> void:
	var e := selected_extra()
	if not e.is_empty():
		push_undo()
		lv.extras.remove_at(selection.index)
	elif selected_char() != "":
		push_undo()
		set_o(selection.tile.x, selection.tile.y, ".")
	else:
		return
	selection = {}
	mark_edited()
	_full_rebuild()
	selection_changed.emit()


func duplicate_selection() -> void:
	var e := selected_extra()
	if e.is_empty():
		return
	push_undo()
	var c := e.duplicate(true)
	c.tile = [e.tile[0] + 1.0, e.tile[1] + 1.0]
	if c.has("target_tile"):
		c.target_tile = [e.target_tile[0] + 1.0, e.target_tile[1] + 1.0]
	lv.extras.append(c)
	selection = {kind = "extra", index = lv.extras.size() - 1}
	mark_edited()
	_full_rebuild()
	selection_changed.emit()


## Starts picking a new landing spot for the selected cannon / catapult.
func pick_target() -> void:
	if selection.get("kind") == "extra":
		_pending_target = selection.index
		ui.on_tool_changed()


## Sets a value on the selected extra (from the inspector).
func set_extra_value(key: String, value: Variant) -> void:
	var e := selected_extra()
	if e.is_empty():
		return
	if _merge_key != key + str(selection.index):
		push_undo()
		_merge_key = key + str(selection.index)
	if value == null:
		e.erase(key)
	else:
		e[key] = value
	mark_edited()


## Sets a level setting (from the Level panel).
func set_level_value(key: String, value: Variant) -> void:
	if lv.get(key) == value:
		return
	if _merge_key != "lv:" + key:
		push_undo()
		_merge_key = "lv:" + key
	lv[key] = value
	mark_edited()
	if key == "title":
		quest_changed.emit()


func set_theme_value(key: String, value: Variant) -> void:
	push_undo()
	lv.theme[key] = value
	mark_edited()


func apply_theme(theme_name: String) -> void:
	push_undo()
	lv.theme = CustomLevel.THEMES[theme_name].duplicate(true)
	mark_edited()
	level_changed.emit()


func auto_path() -> void:
	push_undo()
	var l := CustomLevel.from_dict(lv)
	l.route = []
	l.build()
	var r: Array = []
	for p in l.route:
		r.append([p.x, p.y])
	lv.route = r
	mark_edited()
	_full_rebuild()
	ui.toast("Path with %d points" % r.size() if r.size() > 2 else "No way from the start to the hole yet")


func clear_path() -> void:
	push_undo()
	lv.route = []
	mark_edited()
	_full_rebuild()


## Rough par time: path length at a relaxed rolling speed.
func estimate_par() -> float:
	var l := CustomLevel.from_dict(lv)
	l.build()
	var length := 0.0
	for k in range(1, l.route.size()):
		length += (l.route[k] - l.route[k - 1]).length() * TILE
	return clampf(snappedf(length / 3.2 + 6.0, 5.0), 10.0, 900.0)


## Problems that stop the level from being played properly.
func problems() -> PackedStringArray:
	var out: PackedStringArray = []
	var has_s := has_char("S")
	var has_g := has_goal()
	if not has_s:
		out.append("No start. Use the Start tool.")
	if not has_g:
		out.append("No hole. Use the Hole tool.")
	if has_s and has_g and built and lv.route.is_empty() and CustomLevel.find_path(built).is_empty():
		out.append("No rolling way from the start to the hole. Fine if you use jumps, but draw a Path for the rival and camera.")
	if lv.race and not has_g:
		out.append("Race levels need a hole.")
	return out


## A hole ("G") or a goal pad.
func has_goal() -> bool:
	if has_char("G"):
		return true
	for e: Dictionary in lv.extras:
		if e.type == "goalpad":
			return true
	return false


func has_char(c: String) -> bool:
	for j in rows():
		if (lv.objects[j] as String).contains(c):
			return true
	return false


# --- track sections -----------------------------------------------------------------

func track_end() -> Array:
	return lv.get("track_end", [])


## Palette button: add a section to the open end of the track.
func add_section(id: String) -> void:
	section_id = id
	if tool != "sections":
		set_tool("sections")
	var te := track_end()
	if te.is_empty():
		ui.on_tool_changed()
		ui.toast("No open track end. Click on the map to put the %s there" % TrackPieces.label_of(id).to_lower())
		_update_hover()
		return
	_put_section(id, Vector2i(te[0], te[1]), te[2], te[3], true)


## Origin for a piece whose lane should start at `tile` facing `h`.
func _section_origin(tile: Vector2i, h: int) -> Vector2i:
	return tile - TrackPieces.L[h] * 2


func _section_tier(tile: Vector2i) -> int:
	var c := hchar(tile.x, tile.y)
	var t := int(c) if c.is_valid_int() else tier
	return t + TrackPieces.get_piece(section_id).entry


func _place_section_at(tile: Vector2i) -> void:
	_put_section(section_id, _section_origin(tile, section_heading), section_heading, _section_tier(tile), false)


func _put_section(id: String, origin: Vector2i, h: int, t: int, at_end: bool) -> bool:
	var piece := TrackPieces.get_piece(id)
	var res := TrackPieces.stamp(piece, origin, h, t, built.step)
	if not res.ok:
		ui.toast(res.why)
		return false
	push_undo()
	var lo := Vector2i(1000000, 1000000)
	var hi := -lo
	for c: Vector2i in res.cells:
		lo = lo.min(c)
		hi = hi.max(c)
	var s0 := _shift
	if ensure_tile(lo.x, lo.y).x < 0 or ensure_tile(hi.x + _shift.x - s0.x, hi.y + _shift.y - s0.y).x < 0:
		ui.toast("The map can't get any bigger")
		undo()
		return false
	var d := _shift - s0
	for v: Array in res.cells.values():
		for ch in ["S", "G"]:
			if v[1] == ch:
				for j in rows():
					var at: int = (lv.objects[j] as String).find(ch)
					if at >= 0:
						set_o(at, j, ".")
	for c: Vector2i in res.cells:
		var v: Array = res.cells[c]
		if v[0] != ".":
			set_h(c.x + d.x, c.y + d.y, v[0])
		if v[1] != ".":
			set_o(c.x + d.x, c.y + d.y, v[1])
	for e: Dictionary in res.extras:
		e.tile = [e.tile[0] + d.x, e.tile[1] + d.y]
		if e.has("target_tile"):
			e.target_tile = [e.target_tile[0] + d.x, e.target_tile[1] + d.y]
		lv.extras.append(e)
	var route: Array = []
	for r: Array in res.route:
		route.append([r[0] + d.x, r[1] + d.y])
	if id == "start":
		lv.route = route
	elif at_end and not lv.route.is_empty():
		lv.route.append_array(route)
	if res.end.is_empty():
		lv.erase("track_end")
	else:
		lv.track_end = [res.end[0] + d.x, res.end[1] + d.y, res.end[2], res.end[3]]
	mark_edited()
	_full_rebuild()
	level_changed.emit()
	ui.on_tool_changed()
	ui.toast("Added: %s" % TrackPieces.label_of(id))
	if not track_end().is_empty():
		var c := TrackPieces.end_center(track_end())
		keep_in_view(Vector3((c.x + 0.5) * TILE, 0.0, (c.y + 0.5) * TILE))
	return true


## Sets where the next section attaches (Road ends, or picking a spot).
func set_track_end(origin: Vector2i, h: int, t: int) -> void:
	lv.track_end = [origin.x, origin.y, h, clampi(t, 0, 9)]


func _road_tile(fwd: int, lat: int) -> Vector2i:
	return TrackPieces.F[_road_heading] * fwd + TrackPieces.L[_road_heading] * lat


## After a Road stroke: meet other ground (open its wall, ramp to its height),
## add rails, and leave an open end for sections.
func _finish_road() -> void:
	if _road_tiles.is_empty() or _road_square.is_empty():
		return
	var f: Vector2i = TrackPieces.F[_road_heading]
	var l: Vector2i = TrackPieces.L[_road_heading]
	var front := -1000000
	var latmin := 1000000
	var latmax := -1000000
	for p in _road_square:
		front = maxi(front, p.x * f.x + p.y * f.y)
		latmin = mini(latmin, p.x * l.x + p.y * l.y)
		latmax = maxi(latmax, p.x * l.x + p.y * l.y)
	var t := _road_tier
	var lc := (latmin + latmax) / 2
	var p1 := _road_tile(front + 1, lc)
	var p2 := _road_tile(front + 2, lc)
	var c1 := hchar(p1.x, p1.y)
	var c2 := hchar(p2.x, p2.y)
	var joined := false
	var ramp_top := t
	if c1.is_valid_int() and not _road_tiles.has(p1):
		var u := int(c1)
		# A rail in the way: open it up to the ground behind it.
		if c2.is_valid_int() and u == int(c2) + 1:
			u = int(c2)
			for lat in range(latmin, latmax + 1):
				var q := _road_tile(front + 1, lat)
				if hchar(q.x, q.y).is_valid_int():
					set_h(q.x, q.y, str(u))
		joined = true
		if u != t:
			# Ramp over the last columns of the road, rising towards the higher side.
			var k := clampi(absi(u - t) * 2, 2, 8)
			var ch: String = TrackPieces.RISE[_road_heading] if u > t else TrackPieces.RISE[(_road_heading + 2) % 4]
			for a in range(front - k + 1, front + 1):
				for lat in range(latmin, latmax + 1):
					var q := _road_tile(a, lat)
					if _road_tiles.has(q):
						set_h(q.x, q.y, ch)
			ramp_top = maxi(u, t)
			ui.toast("Joined up with a ramp %s %d step%s" % ["up" if u > t else "down", absi(u - t), "" if absi(u - t) == 1 else "s"])
		else:
			ui.toast("Joined up")
	if road_rails:
		# Grow the map once so every rail fits (resize() moves _road_tiles along).
		var lo := Vector2i(1000000, 1000000)
		var hi := -lo
		for p: Vector2i in _road_tiles:
			lo = lo.min(p)
			hi = hi.max(p)
		var s0 := _shift
		ensure_tile(lo.x - 1, lo.y - 1)
		var d0 := _shift - s0
		ensure_tile(hi.x + 1 + d0.x, hi.y + 1 + d0.y)
		for p: Vector2i in _road_tiles:
			var rail := mini(9, (ramp_top if not hchar(p.x, p.y).is_valid_int() else t) + 1)
			for dj in [-1, 0, 1]:
				for di in [-1, 0, 1]:
					var n: Vector2i = p + Vector2i(di, dj)
					if not _road_tiles.has(n) and not is_ground(n.x, n.y):
						set_h(n.x, n.y, str(rail))
		# front / lateral numbers moved with the map too.
		var dd := _shift - s0
		front += dd.x * f.x + dd.y * f.y
		latmin += dd.x * l.x + dd.y * l.y
	if not joined and road_width >= 2:
		set_track_end(f * (front + 1) + l * (latmin - 1), _road_heading, t)
	_road_tiles = {}
	_road_square = []


# --- guide -----------------------------------------------------------------------

## Tiles the marble can roll to from the start (following jumps and the path).
func _compute_reach() -> void:
	reach = {}
	if built == null or not has_char("S"):
		return
	var start := built.tile_at(built.spawn.x, built.spawn.y)
	var jumps := {}
	for e in built.extras:
		if e.has("target_tile"):
			var a0 := Vector2i(Vector2(e.tile).round())
			if not jumps.has(a0):
				jumps[a0] = []
			jumps[a0].append(Vector2i(Vector2(e.target_tile).round()))
	# Path points join too (sections with jumps and loops add them).
	for k in range(1, lv.route.size()):
		var a := Vector2i(Vector2(lv.route[k - 1][0], lv.route[k - 1][1]).round())
		var b := Vector2i(Vector2(lv.route[k][0], lv.route[k][1]).round())
		if a != b:
			if not jumps.has(a):
				jumps[a] = []
			jumps[a].append(b)
	reach[start] = true
	var queue: Array[Vector2i] = [start]
	var count := 0
	while not queue.is_empty() and count < 60000:
		var a: Vector2i = queue.pop_back()
		count += 1
		var jumped: Array = jumps.get(a, [])
		var nexts: Array = [a + Vector2i.RIGHT, a + Vector2i.LEFT, a + Vector2i.DOWN, a + Vector2i.UP]
		nexts.append_array(jumped)
		for b: Vector2i in nexts:
			if reach.has(b) or not built.is_tile_ground(b.x, b.y):
				continue
			if b not in jumped and not CustomLevel._can_step(built, a, b):
				continue
			reach[b] = true
			queue.append(b)


func hole_reachable() -> bool:
	if built == null or built.goal == Vector2.INF:
		return false
	return reach.has(built.tile_at(built.goal.x, built.goal.y))


## Reachable tile nearest the hole (where the track needs connecting).
func gap_tile() -> Vector2i:
	var g := built.tile_at(built.goal.x, built.goal.y)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for t: Vector2i in reach:
		var d := Vector2(t - g).length()
		if d < best_d:
			best_d = d
			best = t
	return best


## The next thing to do: [text, button label, action id].
func guide() -> Array:
	if not has_char("S"):
		return ["Start with Sections > Start pad and click on the map, or place a Start with the Start tool.",
			"Start pad", "start"]
	if not has_goal():
		if not track_end().is_empty():
			return ["Build your track: click pieces in the Pieces tab to add them at the green arrow. End with Finish.",
				"Add Finish", "finish"]
		return ["Add a hole: Sections > Finish, or the Hole tool.", "Hole tool", "goal"]
	if not hole_reachable():
		return ["The marble can't roll from the start to the hole yet. Draw a Road from the orange ring to the hole's ground, or add sections.",
			"Road tool", "road"]
	var length := 0.0
	for k in range(1, built.route.size()):
		length += (built.route[k] - built.route[k - 1]).length()
	if length > 45.0 and not has_char("C") and not has_char("K"):
		return ["Long level: put a checkpoint gate about halfway, so a fall doesn't send players back to the start.",
			"Gate tool", "checkpoint"]
	var guess := estimate_par()
	if absf(lv.par - guess) > maxf(15.0, guess * 0.6):
		return ["Par time is %.0f s, the track looks more like %.0f s. Set a fair par so medals mean something." % [lv.par, guess],
			"Use %.0f s" % guess, "par"]
	if not tested:
		return ["Try it! Test play shows if it's fun. Esc brings you back.", "Test play", "test"]
	return ["Looks ready. Share it from the Quest tab, or keep adding sections.", "Quest tab", "share"]


func guide_action(action: String) -> void:
	match action:
		"start", "finish":
			if action == "start" or track_end().is_empty():
				section_id = action
				set_tool("sections")
				ui.toast("Click on the map where the %s should go" % TrackPieces.label_of(action).to_lower())
			else:
				add_section(action)
		"par":
			set_level_value("par", estimate_par())
			level_changed.emit()
		"test":
			test_play()
		"share":
			ui.show_tab(3)
		_:
			set_tool(action)


# --- templates --------------------------------------------------------------------

## A fresh level: "track" = empty sky with a start pad and an open end,
## "island" = the classic open platform, "empty" = nothing.
static func template(kind: String, level_title: String) -> Dictionary:
	var d := CustomLevel.blank(level_title)
	if kind == "island":
		return d
	var w := 14 if kind == "track" else 16
	var h := 8 if kind == "track" else 10
	d.heights = []
	d.objects = []
	for j in h:
		d.heights.append(".".repeat(w))
		d.objects.append(".".repeat(w))
	if kind == "track":
		var res := TrackPieces.stamp(TrackPieces.get_piece("start"), Vector2i(1, 1), 0, 2)
		for c: Vector2i in res.cells:
			var v: Array = res.cells[c]
			var hl: String = d.heights[c.y]
			d.heights[c.y] = hl.substr(0, c.x) + v[0] + hl.substr(c.x + 1)
			if v[1] != ".":
				var ol: String = d.objects[c.y]
				d.objects[c.y] = ol.substr(0, c.x) + v[1] + ol.substr(c.x + 1)
		d.route = res.route
		d.track_end = res.end
	return d


# --- test play --------------------------------------------------------------------

func test_play(from: Vector2i = Vector2i(-1, -1)) -> void:
	var p := problems()
	if p.size() > 0 and (p[0].begins_with("No start") or p[0].begins_with("No hole")):
		ui.toast(p[0])
		return
	save_if_changed()
	session_quest = quest
	session_level = li
	session_view = {target = cam_target, size = cam_size, yaw = cam_yaw, top = top_view}
	session_tested = true
	MainGame.quest = quest.duplicate_quest()
	MainGame.test_mode = true
	MainGame.test_start = from
	MainGame.requested_level = li
	Transition.go("res://scenes/main.tscn")


func exit_to_menu() -> void:
	save_if_changed()
	TitleScreen.open_page = "quests"
	Transition.go("res://scenes/title.tscn")


func _on_files_dropped(files: PackedStringArray) -> void:
	for f in files:
		var q := Quest.install_file(f)
		if q:
			if unsaved:
				quest.save()
			open_quest(q)
			ui.toast("Opened \"%s\"" % q.name)
			return
	ui.toast("That isn't a .candyquest file")


# --- building the preview -----------------------------------------------------------

func _rebuild() -> void:
	dirty = false
	var partial := _tiles_only and world != null and not _dirty_tiles.is_empty()
	var tiles := _dirty_tiles
	var heights_only := _heights_only
	_dirty_tiles = {}
	_tiles_only = true
	_heights_only = true
	built = CustomLevel.from_dict(lv)
	built.build()
	if partial:
		# Mid-stroke: just the chunks around the brush. After: wide enough to
		# catch ramp runs that changed slope.
		var grow := 2 if _stroke else 12
		var keys := {}
		for t: Vector2i in tiles:
			for kj in range(floori(float(t.y - grow) / CHUNK), floori(float(t.y + grow) / CHUNK) + 1):
				for ki in range(floori(float(t.x - grow) / CHUNK), floori(float(t.x + grow) / CHUNK) + 1):
					keys[Vector2i(ki, kj)] = true
		for k: Vector2i in keys:
			_build_chunk(k)
		if not (_stroke and heights_only):
			_rebuild_entities()
		if not _stroke:
			_compute_reach()
		_draw_grid()
		_draw_marks()
		_update_hover()
		if not _stroke:
			rebuilt.emit()
		return
	_stroke_dirty = {}
	if world:
		remove_child(world)
		world.queue_free()
	_chunks.clear()
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_INHERIT if animate else Node.PROCESS_MODE_DISABLED
	add_child(world)
	_terrain_root = Node3D.new()
	world.add_child(_terrain_root)
	for kj in ceili(float(rows()) / CHUNK):
		for ki in ceili(float(cols()) / CHUNK):
			_build_chunk(Vector2i(ki, kj))
	_update_backdrop()
	_ents = null
	_rebuild_entities()
	_compute_reach()
	_draw_grid()
	_draw_marks()
	_update_hover()
	rebuilt.emit()


func _update_backdrop() -> void:
	var key := "%s:%d:%dx%d" % [quest.id, li, cols(), rows()] if show_scenery else ""
	if key == _backdrop_key:
		return
	_backdrop_key = key
	if _backdrop:
		remove_child(_backdrop)
		_backdrop.queue_free()
		_backdrop = null
	if show_scenery:
		var b := Backdrop.new()
		b.setup(built, hash(quest.id) + li)
		_backdrop = b
		add_child(b)
		b.process_mode = Node.PROCESS_MODE_INHERIT if animate else Node.PROCESS_MODE_DISABLED


func _full_rebuild() -> void:
	_tiles_only = false
	_rebuild()


func _build_chunk(key: Vector2i) -> void:
	if _chunks.has(key):
		(_chunks[key] as Node).queue_free()
		_chunks.erase(key)
	if key.x < 0 or key.y < 0 or key.x * CHUNK >= cols() or key.y * CHUNK >= rows():
		return
	var t := Terrain.new(built, Rect2i(key * CHUNK, Vector2i(CHUNK, CHUNK)))
	_terrain_root.add_child(t)
	_chunks[key] = t


func _rebuild_entities() -> void:
	if _ents:
		world.remove_child(_ents)
		_ents.queue_free()
	_ents = Node3D.new()
	world.add_child(_ents)
	for e in built.entities:
		MainGame.spawn_entity(e, built, _ents)
	if has_char("S"):
		var ball := Node3D.new()
		_ents.add_child(ball)
		ball.position = Vector3(built.spawn.x, built.height(built.spawn.x, built.spawn.y) + 0.5, built.spawn.y)
		Palette.load_model(ball, "ball")
		if built.race:
			var r := Node3D.new()
			_ents.add_child(r)
			var rp := built.spawn + Vector2(0, TILE)
			r.position = Vector3(rp.x, built.height(rp.x, rp.y) + 0.5, rp.y)
			Palette.load_model(r, "rival")
			Palette.tint(r, built.rival_tint)


func set_animate(on: bool) -> void:
	animate = on
	if _backdrop:
		_backdrop.process_mode = Node.PROCESS_MODE_INHERIT if animate else Node.PROCESS_MODE_DISABLED
	_full_rebuild()


func set_scenery(on: bool) -> void:
	show_scenery = on
	_full_rebuild()


func set_reach(on: bool) -> void:
	show_reach = on
	_draw_marks()


func set_grid(on: bool) -> void:
	show_grid = on
	_grid_mesh.visible = on


func _line_material(col: Color, on_top: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.no_depth_test = on_top
	m.render_priority = 5 if on_top else 0
	# Overlays are flat shapes seen from above; never cull their back faces.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _draw_grid() -> void:
	var im := ImmediateMesh.new()
	var ground_lines := PackedVector3Array()
	var void_lines := PackedVector3Array()
	var w := cols()
	var h := rows()
	# Top height per tile (NAN = void): flat tiles by tier, ramps sampled once.
	var tops := PackedFloat32Array()
	tops.resize(w * h)
	for j in h:
		var line: String = lv.heights[j]
		for i in w:
			var c := line[i]
			if c == ".":
				tops[j * w + i] = NAN
			elif c.is_valid_int():
				tops[j * w + i] = int(c) * built.step
			else:
				var ctr := built.tile_center(i, j)
				tops[j * w + i] = built.surface(i, j, ctr.x, ctr.y)
	var top := func(i: int, j: int) -> float:
		return tops[j * w + i] if i >= 0 and j >= 0 and i < w and j < h else NAN
	for j in range(h + 1):
		for i in range(w + 1):
			if i < w:
				var y := _max_top(top.call(i, j), top.call(i, j - 1))
				var arr := void_lines if is_nan(y) else ground_lines
				y = 0.0 if is_nan(y) else y + 0.04
				arr.append(Vector3(i * TILE, y, j * TILE))
				arr.append(Vector3((i + 1) * TILE, y, j * TILE))
			if j < h:
				var y2 := _max_top(top.call(i, j), top.call(i - 1, j))
				var arr2 := void_lines if is_nan(y2) else ground_lines
				y2 = 0.0 if is_nan(y2) else y2 + 0.04
				arr2.append(Vector3(i * TILE, y2, j * TILE))
				arr2.append(Vector3(i * TILE, y2, (j + 1) * TILE))
	if void_lines.size() > 0:
		im.surface_begin(Mesh.PRIMITIVE_LINES, _line_material(Color(1, 1, 1, 0.35)))
		for p in void_lines:
			im.surface_add_vertex(p)
		im.surface_end()
	if ground_lines.size() > 0:
		im.surface_begin(Mesh.PRIMITIVE_LINES, _line_material(Color(0.35, 0.2, 0.15, 0.28)))
		for p in ground_lines:
			im.surface_add_vertex(p)
		im.surface_end()
	_grid_mesh.mesh = im
	_grid_mesh.visible = show_grid


static func _max_top(a: float, b: float) -> float:
	if is_nan(a):
		return b
	if is_nan(b):
		return a
	return maxf(a, b)


## Route line, sweeper paths, landing spots and the selection ring.
func _draw_marks() -> void:
	for c in _marks.get_children():
		c.queue_free()
	if built == null:
		return
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marks.add_child(mi)
	var lines := PackedVector3Array()
	var colors := PackedColorArray()
	var route := built.route
	var drawn_route: Array = lv.route if not lv.route.is_empty() else []
	var col_route := Color("#8C5BD6") if not drawn_route.is_empty() else Color(0.55, 0.4, 0.8, 0.55)
	for k in range(1, route.size()):
		var a := built.tile_center_f(route[k - 1])
		var b := built.tile_center_f(route[k])
		lines.append(_ground3(a) + Vector3.UP * 0.35)
		lines.append(_ground3(b) + Vector3.UP * 0.35)
		colors.append(col_route)
		colors.append(col_route)
	for k in lv.extras.size():
		var e: Dictionary = lv.extras[k]
		var p := Vector2((e.tile[0] + 0.5) * TILE, (e.tile[1] + 0.5) * TILE)
		var sel: bool = selection.get("kind") == "extra" and selection.index == k
		if e.has("travel"):
			var q := p + Vector2(e.travel[0], e.travel[2])
			var c := Palette.RASPBERRY if sel else Color(Palette.RASPBERRY, 0.6)
			lines.append(_ground3(p) + Vector3.UP * 0.25)
			lines.append(_ground3(q) + Vector3.UP * 0.25)
			colors.append(c)
			colors.append(c)
			_mark_ring(_ground3(q), 0.5, c)
		if e.has("target_tile"):
			var q := Vector2((e.target_tile[0] + 0.5) * TILE, (e.target_tile[1] + 0.5) * TILE)
			var c := Palette.CORAL if sel else Color(Palette.CORAL, 0.7)
			var a3 := _ground3(p)
			var b3 := _ground3(q)
			var hgt := maxf(3.0, a3.distance_to(b3) * 0.35)
			for s in 16:
				var u0 := s / 16.0
				var u1 := (s + 1) / 16.0
				lines.append(a3.lerp(b3, u0) + Vector3.UP * (4.0 * hgt * u0 * (1.0 - u0) + 0.3))
				lines.append(a3.lerp(b3, u1) + Vector3.UP * (4.0 * hgt * u1 * (1.0 - u1) + 0.3))
				colors.append(c)
				colors.append(c)
			_mark_ring(b3, 0.9, c)
	if lines.size() > 0:
		im.surface_begin(Mesh.PRIMITIVE_LINES, _line_material(Color.WHITE, true))
		for k in lines.size():
			im.surface_set_color(colors[k])
			im.surface_add_vertex(lines[k])
		im.surface_end()
	for k in route.size():
		var s := MeshInstance3D.new()
		s.mesh = Palette.sphere(0.18)
		s.material_override = _line_material(col_route, true)
		s.position = _ground3(built.tile_center_f(route[k])) + Vector3.UP * 0.35
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marks.add_child(s)
	# Selection ring.
	var sp := Vector2.INF
	if selection.get("kind") == "extra" and selection.index < lv.extras.size():
		var e: Dictionary = lv.extras[selection.index]
		sp = Vector2((e.tile[0] + 0.5) * TILE, (e.tile[1] + 0.5) * TILE)
	elif selection.get("kind") == "obj":
		sp = built.tile_center(selection.tile.x, selection.tile.y)
	if sp != Vector2.INF:
		_mark_ring(_ground3(sp), 1.25, Color("#35B37E"), true)
	_draw_track_end()
	_draw_reach()


## Big green arrow where the next section attaches.
func _draw_track_end() -> void:
	var te := track_end()
	if te.is_empty():
		return
	var c := TrackPieces.end_center(te)
	var base := Vector3((c.x + 0.5) * TILE, te[3] * built.step + 0.35, (c.y + 0.5) * TILE)
	var f: Vector2i = TrackPieces.F[te[2]]
	var l: Vector2i = TrackPieces.L[te[2]]
	var fwd := Vector3(f.x, 0, f.y)
	var side := Vector3(l.x, 0, l.y)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _line_material(Color.WHITE, true))
	var col := Color("#35B37E")
	var tip := base + fwd * 3.2
	var pts := [
		base + fwd * 0.8 - side * 2.0, tip, base + fwd * 0.8 + side * 2.0,
		base - fwd * 1.2 - side * 0.8, base + fwd * 0.8 - side * 0.8, base + fwd * 0.8 + side * 0.8,
		base - fwd * 1.2 - side * 0.8, base + fwd * 0.8 + side * 0.8, base - fwd * 1.2 + side * 0.8,
	]
	for p: Vector3 in pts:
		im.surface_set_color(col)
		im.surface_add_vertex(p)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marks.add_child(mi)
	var label := Label3D.new()
	label.text = "next section"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.pixel_size = 0.012
	CandyText.style_3d(label, Palette.MINT)
	label.fixed_size = true
	label.pixel_size = 0.0014
	label.position = base + Vector3.UP * 1.6
	_marks.add_child(label)


## Pink shading on ground the marble can't reach, and an orange ring on the
## reachable spot nearest the hole when they aren't connected.
func _draw_reach() -> void:
	if not show_reach or not has_char("S") or reach.is_empty():
		return
	var im := ImmediateMesh.new()
	var any := false
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _line_material(Color.WHITE))
	var col := Color(Palette.RASPBERRY, 0.3)
	for j in rows():
		for i in cols():
			var t := Vector2i(i, j)
			if reach.has(t) or not is_ground(i, j):
				continue
			# Walls next to reachable ground are fine, they're meant to stop you.
			var wall := false
			for n in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				if reach.has(t + n):
					wall = true
					break
			if wall:
				continue
			var c := built.tile_center(i, j)
			var y := built.surface(i, j, c.x, c.y) + 0.07
			var x0 := i * TILE
			var z0 := j * TILE
			for p in [Vector3(x0, y, z0), Vector3(x0 + TILE, y, z0), Vector3(x0 + TILE, y, z0 + TILE),
					Vector3(x0, y, z0), Vector3(x0 + TILE, y, z0 + TILE), Vector3(x0, y, z0 + TILE)]:
				im.surface_set_color(col)
				im.surface_add_vertex(p)
			any = true
	if any:
		im.surface_end()
		var mi := MeshInstance3D.new()
		mi.mesh = im
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marks.add_child(mi)
	if has_goal() and not hole_reachable():
		var g := gap_tile()
		if g.x < 0:
			return
		var at := _ground3(built.tile_center(g.x, g.y))
		_mark_ring(at, 1.1, Palette.CORAL)
		var label := Label3D.new()
		label.text = "connect from here"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 48
		label.pixel_size = 0.012
		CandyText.style_3d(label, Palette.CORAL)
		label.fixed_size = true
		label.pixel_size = 0.0014
		label.position = at + Vector3.UP * 1.5
		_marks.add_child(label)
		var goal3 := _ground3(built.goal)
		var line := ImmediateMesh.new()
		line.surface_begin(Mesh.PRIMITIVE_LINES, _line_material(Color.WHITE, true))
		var n := int(at.distance_to(goal3) / 0.8)
		for k in range(0, n, 2):
			for u in [float(k) / n, float(k + 1) / n]:
				line.surface_set_color(Palette.CORAL)
				line.surface_add_vertex(at.lerp(goal3, u) + Vector3.UP * 0.4)
		line.surface_end()
		var lm := MeshInstance3D.new()
		lm.mesh = line
		_marks.add_child(lm)


func _mark_ring(at: Vector3, radius: float, col: Color, pulse: bool = false) -> void:
	var t := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = radius - 0.1
	m.outer_radius = radius + 0.1
	t.mesh = m
	t.material_override = _line_material(col, true)
	t.position = at + Vector3.UP * 0.12
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if pulse:
		t.name = "Pulse"
	_marks.add_child(t)


func _ground3(p: Vector2) -> Vector3:
	var t := built.tile_at(p.x, p.y)
	var y := built.height(p.x, p.y) if built.is_tile_ground(t.x, t.y) else 0.0
	return Vector3(p.x, y, p.y)


func _update_hover() -> void:
	_ghost_mesh.visible = false
	if not _hover_valid or built == null:
		_hover_mesh.visible = false
		return
	if tool == "sections":
		_hover_mesh.visible = false
		_draw_ghost()
		return
	var tiles: Array[Vector2i] = []
	if tool == "box" and _stroke:
		var lo := Vector2i(mini(_stroke_start.x, _hover.x), mini(_stroke_start.y, _hover.y))
		var hi := Vector2i(maxi(_stroke_start.x, _hover.x), maxi(_stroke_start.y, _hover.y))
		for j in range(lo.y, hi.y + 1):
			for i in range(lo.x, hi.x + 1):
				tiles.append(Vector2i(i, j))
	elif tool in ["paint", "raise", "lower", "ramp", "erase", "waves", "hill", "trench", "goo", "humps", "ice", "clear"]:
		tiles = _brush_tiles(_hover)
	else:
		tiles = [_hover]
	var col := Color(Palette.MINT, 0.45)
	if tool in ["erase", "clear"]:
		col = Color(Palette.RASPBERRY, 0.4)
	elif tool == "select" or tool == "route":
		col = Color(Palette.LILAC, 0.4)
	elif _pending_target >= 0:
		col = Color(Palette.CORAL, 0.5)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _line_material(Color.WHITE, true))
	for t in tiles:
		var y := 0.0
		if built.is_tile_ground(t.x, t.y):
			var c := built.tile_center(t.x, t.y)
			y = built.surface(t.x, t.y, c.x, c.y)
		if tool in ["paint", "box"]:
			y = maxf(y, tier * built.step)
		y += 0.06
		var x0 := t.x * TILE + 0.08
		var z0 := t.y * TILE + 0.08
		var x1 := (t.x + 1) * TILE - 0.08
		var z1 := (t.y + 1) * TILE - 0.08
		for p in [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]:
			im.surface_set_color(col)
			im.surface_add_vertex(p)
	im.surface_end()
	_hover_mesh.mesh = im
	_hover_mesh.visible = true


## See-through preview of the picked section under the mouse.
func _draw_ghost() -> void:
	var piece := TrackPieces.get_piece(section_id)
	if piece.is_empty():
		return
	var res := TrackPieces.stamp(piece, _section_origin(_hover, section_heading), section_heading, _section_tier(_hover))
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _line_material(Color.WHITE, true))
	for c: Vector2i in res.cells:
		var v: Array = res.cells[c]
		if v[0] == ".":
			continue
		var y: float = (int(v[0]) if v[0].is_valid_int() else res.end[3] if not res.end.is_empty() else tier) * built.step + 0.1
		var col := Color("#6FDDB0", 0.72)
		if not res.ok:
			col = Color(Palette.RASPBERRY, 0.65)
		elif is_ground(c.x, c.y):
			col = Color(Palette.CORAL, 0.65)
		if v[1] in ["S", "G"]:
			col = Color(Palette.LEMON, 0.8)
		var x0 := c.x * TILE + 0.06
		var z0 := c.y * TILE + 0.06
		var x1 := x0 + TILE - 0.12
		var z1 := z0 + TILE - 0.12
		for p in [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]:
			im.surface_set_color(col)
			im.surface_add_vertex(p)
	# Arrow along the lane: the way the marble will roll through the piece.
	var c0 := TrackPieces.world(_section_origin(_hover, section_heading), section_heading, 0.0, 2.5)
	var y0 := _section_tier(_hover) * built.step + 0.25
	var base := Vector3((c0.x + 0.5) * TILE, y0, (c0.y + 0.5) * TILE)
	var fv: Vector2i = TrackPieces.F[section_heading]
	var lv2: Vector2i = TrackPieces.L[section_heading]
	var fwd := Vector3(fv.x, 0, fv.y)
	var side := Vector3(lv2.x, 0, lv2.y)
	var arrow_col := Color("#1E8F5E")
	for p in [base + side * 0.5, base + fwd * 3.0 + side * 0.5, base + fwd * 3.0 - side * 0.5,
			base + side * 0.5, base + fwd * 3.0 - side * 0.5, base - side * 0.5,
			base + fwd * 2.4 + side * 1.6, base + fwd * 4.6, base + fwd * 2.4 - side * 1.6]:
		im.surface_set_color(arrow_col)
		im.surface_add_vertex(p)
	im.surface_end()
	_ghost_mesh.mesh = im
	_ghost_mesh.visible = true


# --- camera -----------------------------------------------------------------------

func frame_level() -> void:
	var w := cols() * TILE
	var h := rows() * TILE
	cam_target = Vector3(w * 0.5, 0.0, h * 0.5)
	var vp := get_viewport().get_visible_rect().size
	var aspect := (vp.x - 700.0) / maxf(vp.y - 120.0, 1.0)
	cam_size = clampf(maxf(h, w / maxf(aspect, 0.5)) * 1.15 * vp.y / maxf(vp.y - 120.0, 1.0), 12.0, 320.0)
	_apply_camera()


## Pans so `p` is inside the free area between the panels.
func keep_in_view(p: Vector3) -> void:
	var vp := get_viewport().get_visible_rect().size
	var area := Rect2(EditorUI.LEFT_W + 60, EditorUI.TOP_H + 60, vp.x - EditorUI.LEFT_W - EditorUI.RIGHT_W - 120,
		vp.y - EditorUI.TOP_H - EditorUI.BOTTOM_H - 200)
	if area.has_point(camera.unproject_position(p)):
		return
	var t := Vector3(p.x, 0.0, p.z)
	cam_target = cam_target.lerp(t, 0.6)
	_apply_camera()


func toggle_view() -> void:
	top_view = not top_view
	_apply_camera()
	ui.on_view_changed()


func _apply_camera() -> void:
	if camera == null:
		return
	camera.size = cam_size
	if top_view:
		# Tilted a little so monsters and toys read as 3D; up is still -z.
		camera.rotation_degrees = Vector3(-TOP_PITCH, 0.0, 0.0)
	else:
		camera.rotation_degrees = Vector3(-35.264, cam_yaw, 0.0)
	# Keep the map centred in the gap between the side panels.
	var vp := get_viewport().get_visible_rect().size
	var upp := cam_size / maxf(vp.y, 1.0)
	var shift := (EditorUI.RIGHT_W - EditorUI.LEFT_W) * 0.5 * upp
	camera.global_position = cam_target + camera.global_basis.z * 150.0 + camera.global_basis.x * shift


func _pan(delta_px: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var upp := cam_size / maxf(vp.y, 1.0)
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var fwd := Vector3(0, 0, -1)
	if not top_view:
		fwd = -camera.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
	var fwd_scale := 1.0 / sin(deg_to_rad(TOP_PITCH if top_view else 35.264))
	cam_target += -right * delta_px.x * upp + fwd * delta_px.y * upp * fwd_scale
	_apply_camera()


func zoom(factor: float) -> void:
	cam_size = clampf(cam_size * factor, 8.0, 320.0)
	_apply_camera()


## Tile under a screen position: [tile, fractional tile position] or [] if none.
func pick(screen: Vector2) -> Array:
	if built == null:
		return []
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return []
	# March down through the terrain height band, then fall back to the y = 0 plane.
	var top := 6.0
	var t := (top - from.y) / dir.y
	var step := 0.12
	for k in 700:
		var p := from + dir * t
		if p.y < -1.0:
			break
		var tile := built.tile_at(p.x, p.z)
		if built.is_tile_ground(tile.x, tile.y) and p.y <= built.height(p.x, p.z) + 0.02:
			return [tile, Vector2(p.x, p.z) / TILE]
		t += step
	var t0 := -from.y / dir.y
	var q := from + dir * t0
	return [built.tile_at(q.x, q.z), Vector2(q.x, q.z) / TILE]


# --- input ------------------------------------------------------------------------

func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _process(delta: float) -> void:
	_t += delta
	if dirty:
		_rebuild_timer += delta
		if _rebuild_timer > (0.12 if _stroke else 0.0):
			_rebuild()
	if unsaved:
		_autosave += delta
		if _autosave > 45.0 and not _stroke:
			_autosave = 0.0
			quest.save()
			unsaved = false
	var pulse := _marks.get_node_or_null("Pulse") as Node3D
	if pulse:
		pulse.scale = Vector3.ONE * (1.0 + 0.08 * sin(_t * 6.0))
	if _typing():
		return
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		move.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		move.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		move.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		move.y += 1
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		move = Vector2.ZERO
	if move != Vector2.ZERO:
		var vp := get_viewport().get_visible_rect().size
		_pan(-move * delta * vp.y * 0.9)
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		turn += 1
	if Input.is_physical_key_pressed(KEY_E):
		turn -= 1
	if turn != 0.0 and not top_view:
		cam_yaw += turn * 90.0 * delta
		_apply_camera()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		get_viewport().gui_release_focus()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom(1.1)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_pan_button = mb.button_index
				_pan_moved = 0.0
			elif _pan_button == mb.button_index:
				_pan_button = -1
				if mb.button_index == MOUSE_BUTTON_RIGHT and _pan_moved < 6.0:
					var hit := pick(mb.position)
					if not hit.is_empty():
						if _pending_target >= 0:
							_pending_target = -1
							ui.on_tool_changed()
						else:
							remove_at(hit[0], hit[1])
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var hit := pick(mb.position)
			if mb.pressed and not hit.is_empty():
				_stroke_begin(hit[0], hit[1], mb.shift_pressed)
			elif not mb.pressed:
				_stroke_end(hit[0] if not hit.is_empty() else _last_tile, hit[1] if not hit.is_empty() else Vector2.ZERO, mb.shift_pressed)
		return
	var mm := event as InputEventMouseMotion
	if mm:
		if _pan_button >= 0:
			_pan_moved += mm.relative.length()
			_pan(mm.relative)
		var hit := pick(mm.position)
		_hover_valid = not hit.is_empty()
		if _hover_valid:
			var changed: bool = hit[0] != _hover
			_hover = hit[0]
			_hover_f = hit[1]
			if _stroke and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_stroke_move(_hover, _hover_f, mm.shift_pressed)
			if changed:
				_update_hover()
				ui.on_hover(_hover)
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		_on_key(key)


func _on_key(key: InputEventKey) -> void:
	var ctrl := key.ctrl_pressed or key.meta_pressed
	var k := key.physical_keycode
	if ctrl and k == KEY_Z:
		redo() if key.shift_pressed else undo()
	elif ctrl and k == KEY_Y:
		redo()
	elif ctrl and k == KEY_S:
		save()
	elif ctrl and k == KEY_D:
		duplicate_selection()
	elif k == KEY_F5:
		if key.shift_pressed and _hover_valid and is_ground(_hover.x, _hover.y):
			test_play(_hover)
		else:
			test_play()
	elif k == KEY_TAB:
		toggle_view()
	elif k == KEY_R and tool == "sections":
		turn_section(-1 if key.shift_pressed else 1)
	elif k == KEY_R:
		rotate_selection(45.0 if key.shift_pressed else 90.0)
	elif k == KEY_DELETE or k == KEY_BACKSPACE:
		delete_selection()
	elif k == KEY_ESCAPE:
		if pending_test:
			pending_test = false
			ui.on_tool_changed()
		elif _pending_target >= 0:
			_pending_target = -1
			ui.on_tool_changed()
		elif not selection.is_empty():
			selection = {}
			selection_changed.emit()
			_draw_marks()
		else:
			ui.toggle_help()
	elif k == KEY_F1:
		ui.toggle_help()
	elif k == KEY_G:
		set_grid(not show_grid)
		ui.on_view_changed()
	elif k == KEY_BRACKETLEFT:
		brush = maxi(1, brush - 1)
		ui.on_tool_changed()
	elif k == KEY_BRACKETRIGHT:
		brush = mini(4, brush + 1)
		ui.on_tool_changed()
	elif k >= KEY_0 and k <= KEY_9 and not ctrl:
		tier = k - KEY_0
		if tool not in ["paint", "box", "fill"]:
			set_tool("paint")
		ui.on_tool_changed()
	elif k == KEY_F:
		frame_level()
	else:
		return
	get_viewport().set_input_as_handled()

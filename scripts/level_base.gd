class_name LevelBase
extends RefCounted
## A level is two ASCII maps of 2x2 unit tiles (column = x, row = z) plus a few
## extras. Subclasses fill the fields in _init(); main calls build().
##
## heights map
##   .      void
##   0-9    flat tile at that tier (tier * 0.5 units high). A higher neighbour
##          is a wall the ball can't climb; a lower one is a drop.
##   e w s n ramp rising towards +x / -x / +z / -z. A run of ramp tiles blends
##          between the flat tiles at both ends. If the high end is void it's a
##          kicker (jump ramp) rising 0.35 per unit.
##
## objects map
##   S spawn         G golf hole        B pop bumper       H hill
##   W wavy ground (Marble Madness style ripples, fades out at the edges)
##   T trench (neighbouring T tiles join into channels)
##   > < v ^ booster towards +x / -x / +z / -z
##   x X sweeper moving along x over the following '-' tiles (X = fast)
##   z Z sweeper moving along z over the '|' tiles below it (Z = fast)
##   C checkpoint gate spanning x (for travel along z)
##   K checkpoint gate spanning z (for travel along x)
##   l lollipop   t candy tree   b gummy bear
##   g gumdrop  % golden cupcake  h heart candy  r wrapped candy  $ gem candy (floating decor)
##   @ rollover star  # drop target
## extras: loop, cannon {target_tile}, slingshot, hoop {height}, spinner, redirect

const TILE := 2.0
const TIER := 0.5
const KICK := 0.35
const HOLE_RADIUS := 0.85
const TRENCH_DEPTH := 0.8
const SWEEPER_SPEED := 2.8
const SWEEPER_FAST := 4.5

var title := ""
var time_limit := 60.0  ## par time in seconds (medals: gold <= par, silver <= 1.3x, bronze <= 1.7x)
var heights: PackedStringArray = []
var objects: PackedStringArray = []
## Things with parameters: {type: "loop", tile: Vector2, yaw: float}
var extras: Array[Dictionary] = []
## Waypoints for the test bot, in tile units (Vector2(3, 1) = centre of tile 3,1).
var route: Array[Vector2] = []
## Race level: the evil licorice ball races you to the hole.
var race := false
var tier_colors: Array[Color] = [
	Palette.MINT, Palette.LILAC, Color("#BFE3F7"), Color("#F9C6D3"), Color("#FFE7B3"),
]

# Filled by build().
var cols := 0
var rows := 0
var spawn := Vector2.ZERO
var goal := Vector2.INF
var entities: Array[Dictionary] = []
var _trenches: Array = []        # [Vector2 a, Vector2 b] world
var _hills: Array[Vector4] = []  # x, z, height, radius
var _waves := {}                 # Vector2i tile -> true


func build() -> void:
	rows = heights.size()
	for r in heights:
		cols = maxi(cols, r.length())
	entities.clear()
	for j in objects.size():
		var line := objects[j]
		for i in line.length():
			_parse_object(line[i], i, j)
	for e in extras:
		var d := e.duplicate()
		d.pos = tile_center_f(e.tile)
		d.erase("tile")
		if d.has("target_tile"):
			d.target = tile_center_f(d.target_tile)
			d.erase("target_tile")
		if d.type in ["slingshot", "cannon", "hoop", "spinner", "redirect"]:
			d.kind = d.type
			d.type = "pinball"
		entities.append(d)


# --- tiles --------------------------------------------------------------------

func tile_char(i: int, j: int) -> String:
	if j < 0 or j >= rows or i < 0 or i >= heights[j].length():
		return "."
	return heights[j][i]


func obj_char(i: int, j: int) -> String:
	if j < 0 or j >= objects.size() or i < 0 or i >= objects[j].length():
		return "."
	return objects[j][i]


func is_tile_ground(i: int, j: int) -> bool:
	var c := tile_char(i, j)
	return c != "." and c != " "


func is_ramp(i: int, j: int) -> bool:
	return tile_char(i, j) in ["e", "w", "s", "n"]


func tier_of(i: int, j: int) -> int:
	var c := tile_char(i, j)
	return int(c) if c.is_valid_int() else -1


func tile_center(i: int, j: int) -> Vector2:
	return Vector2((i + 0.5) * TILE, (j + 0.5) * TILE)


func tile_center_f(t: Vector2) -> Vector2:
	return (t + Vector2(0.5, 0.5)) * TILE


## How far along a world-space route a point is (segment index + fraction).
static func route_progress(route: Array[Vector2], pos: Vector2, _hint: int = 0) -> float:
	var best := 0.0
	var best_d := INF
	for i in route.size() - 1:
		var a := route[i]
		var b := route[i + 1]
		var q := Geometry2D.get_closest_point_to_segment(pos, a, b)
		var d := q.distance_to(pos)
		if d < best_d:
			best_d = d
			best = i + a.distance_to(q) / maxf(a.distance_to(b), 0.001)
	return best


func tile_at(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / TILE)), int(floor(z / TILE)))


# --- heights ------------------------------------------------------------------

## Surface height at (x, z) as seen by tile (i, j). Tiles meet with a step
## where their tiers differ, so the tile matters on shared edges.
func surface(i: int, j: int, x: float, z: float) -> float:
	return _base(i, j, x, z) + feature(x, z)


func height(x: float, z: float) -> float:
	var t := tile_at(x, z)
	return surface(t.x, t.y, x, z)


func _flat(i: int, j: int) -> float:
	var t := tier_of(i, j)
	return t * TIER if t >= 0 else NAN


func _base(i: int, j: int, x: float, z: float) -> float:
	if not is_ramp(i, j):
		var f := _flat(i, j)
		return 0.0 if is_nan(f) else f
	var c := tile_char(i, j)
	var axis := Vector2i(1, 0) if c in ["e", "w"] else Vector2i(0, 1)
	var s := Vector2i(i, j)
	while tile_char(s.x - axis.x, s.y - axis.y) == c:
		s -= axis
	var e := Vector2i(i, j)
	while tile_char(e.x + axis.x, e.y + axis.y) == c:
		e += axis
	var before := _flat(s.x - axis.x, s.y - axis.y)
	var after := _flat(e.x + axis.x, e.y + axis.y)
	var coord := x if axis.x == 1 else z
	var a0 := (s.x if axis.x == 1 else s.y) * TILE
	var a1 := ((e.x if axis.x == 1 else e.y) + 1) * TILE
	var rises_positive := c in ["e", "s"]
	if not is_nan(before) and not is_nan(after):
		return lerpf(before, after, (coord - a0) / (a1 - a0))
	if rises_positive and not is_nan(before):
		return before + (coord - a0) * KICK
	if not rises_positive and not is_nan(after):
		return after + (a1 - coord) * KICK
	if not is_nan(before):
		return before
	return 0.0 if is_nan(after) else after


## Continuous extras on top of the tiles: hills, trench channels, hole funnel.
func feature(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := 0.0
	var cut := 0.0
	for tr in _trenches:
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, tr[0], tr[1]))
		if d < 1.8:
			cut = maxf(cut, TRENCH_DEPTH * (1.0 - smoothstep(0.9, 1.7, d)))
	h -= cut
	for hill in _hills:
		var dx := x - hill.x
		var dz := z - hill.y
		h += hill.z * exp(-(dx * dx + dz * dz) / (2.0 * hill.w * hill.w))
	if not _waves.is_empty():
		h += _wave(x, z)
	if goal != Vector2.INF:
		var dg := p.distance_to(goal)
		if dg < 2.8:
			h -= 0.3 * (1.0 - smoothstep(HOLE_RADIUS, 2.8, dg))
	return h


func _wave(x: float, z: float) -> float:
	var t := tile_at(x, z)
	# Sample on shared edges from both sides so neighbouring tiles agree.
	var eps := 0.001
	if not (_waves.has(t) or _waves.has(tile_at(x - eps, z)) or _waves.has(tile_at(x, z - eps))):
		return 0.0
	var mask := 1.0
	for axis in 2:
		var c := x if axis == 0 else z
		var lo := floorf(c / TILE) * TILE
		var into := c - lo
		var here := tile_at(x, z)
		var prev := here - (Vector2i(1, 0) if axis == 0 else Vector2i(0, 1))
		var next := here + (Vector2i(1, 0) if axis == 0 else Vector2i(0, 1))
		var w_here := _waves.has(here)
		if w_here and not _waves.has(prev):
			mask *= smoothstep(0.0, 1.0, into)
		if w_here and not _waves.has(next):
			mask *= smoothstep(0.0, 1.0, TILE - into)
		if not w_here:
			mask = 0.0
	return 0.32 * mask * sin((x - z) * 1.25) * cos((x + z) * 0.55)


func in_hole(x: float, z: float) -> bool:
	return goal != Vector2.INF and Vector2(x, z).distance_to(goal) < HOLE_RADIUS


## Linear-space colour for a surface cell.
func cell_color(i: int, j: int, x: float, z: float) -> Color:
	var c: Color
	if is_ramp(i, j):
		c = Palette.LEMON
	else:
		c = tier_colors[posmod(tier_of(i, j), tier_colors.size())]
	var f := feature(x, z)
	if f < -0.35:
		c = Palette.SKY.darkened(0.08)
	elif f > 0.3:
		c = Palette.PINK
	return c.srgb_to_linear()


# --- objects ------------------------------------------------------------------

func _parse_object(c: String, i: int, j: int) -> void:
	var p := tile_center(i, j)
	match c:
		"S":
			spawn = p
		"G":
			goal = p
			entities.append({type = "goal", pos = p})
		"B":
			entities.append({type = "bumper", pos = p})
		"H":
			_hills.append(Vector4(p.x, p.y, 1.1, 0.9))
		"W":
			_waves[Vector2i(i, j)] = true
		"T":
			var joined := false
			for n in [Vector2i(1, 0), Vector2i(0, 1)]:
				if obj_char(i + n.x, j + n.y) == "T":
					_trenches.append([p, tile_center(i + n.x, j + n.y)])
					joined = true
			if not joined and obj_char(i - 1, j) != "T" and obj_char(i, j - 1) != "T":
				_trenches.append([p, p])
		">", "<", "v", "^":
			var yaw: float = {">": 90.0, "<": -90.0, "v": 0.0, "^": 180.0}[c]
			entities.append({type = "booster", pos = p, yaw = yaw})
		"x", "X", "z", "Z":
			_add_sweeper(c, i, j)
		"C", "K":
			_add_checkpoint(c == "C", i, j)
		"@":
			entities.append({type = "pinball", pos = p, kind = "rollover"})
		"#":
			entities.append({type = "pinball", pos = p, kind = "target"})
		"l", "t", "b", "g", "%", "h", "r", "$":
			var kind: String = {"l": "lollipop", "t": "tree", "b": "bear", "g": "gumdrop", "%": "golden_cupcake",
				"h": "heart_candy", "r": "wrapped_candy", "$": "gem_candy"}[c]
			entities.append({type = "decor", pos = p, kind = kind, yaw = 45.0})


func _add_sweeper(c: String, i: int, j: int) -> void:
	var along_x := c in ["x", "X"]
	var mark := "-" if along_x else "|"
	var n := 0
	while obj_char(i + (n + 1 if along_x else 0), j + (0 if along_x else n + 1)) == mark:
		n += 1
	var travel := Vector3(n * TILE, 0, 0) if along_x else Vector3(0, 0, n * TILE)
	var speed := SWEEPER_FAST if c in ["X", "Z"] else SWEEPER_SPEED
	var p := tile_center(i, j)
	# Sweepers may start over void (bridge sweepers); stand on the first ground tile.
	var gi := i
	var gj := j
	for k in n + 1:
		var ti := i + (k if along_x else 0)
		var tj := j + (0 if along_x else k)
		if is_tile_ground(ti, tj):
			gi = ti
			gj = tj
			break
	entities.append({
		type = "enemy", pos = p, ground_tile = Vector2i(gi, gj), travel = travel,
		period = maxf(1.2, 2.0 * travel.length() / speed),
		phase = fmod(i * 0.37 + j * 0.61, 1.0),
	})


func _add_checkpoint(span_x: bool, i: int, j: int) -> void:
	var axis := Vector2i(1, 0) if span_x else Vector2i(0, 1)
	var a := Vector2i(i, j)
	while is_tile_ground(a.x - axis.x, a.y - axis.y):
		a -= axis
	var b := Vector2i(i, j)
	while is_tile_ground(b.x + axis.x, b.y + axis.y):
		b += axis
	var center := (tile_center(a.x, a.y) + tile_center(b.x, b.y)) * 0.5
	var width := ((b - a).length() + 1) * TILE - 0.3
	# Respawn in the middle of the gate, on the tile we were placed on.
	var p := tile_center(i, j)
	if span_x:
		p.x = center.x
	else:
		p.y = center.y
	entities.append({type = "checkpoint", pos = p, yaw = 0.0 if span_x else 90.0, width = width})

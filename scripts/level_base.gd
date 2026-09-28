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
##   a b c d diagonal ramp rising towards -x-z / +x-z / -x+z / +x+z (the
##          corner of that 2x2 letter grid). Marble Madness slopes: a band of
##          these between two plateaus with diagonal edges is one straight
##          incline. A run of n tiles is flat over the half tile at both ends,
##          so it meets the plateaus exactly, and slopes over the n-1 tiles
##          between: use two or more.
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
##   @ rollover star  # drop target   A sour goo pool (pops the marble)
##   M humps: big smooth humps across a run of M tiles (Marble Madness bridges)
##   I ice: slippery, hardly any grip
## extras: loop, cannon {target_tile}, slingshot, hoop {height}, spinner, redirect

const TILE := 2.0
const TIER := 0.5
const KICK := 0.35
const HOLE_RADIUS := 0.85
const TRENCH_DEPTH := 0.8
const SWEEPER_SPEED := 2.8
const SWEEPER_FAST := 4.5
const HUMP_HEIGHT := 0.9
const RAMPS := ["e", "w", "s", "n", "a", "b", "c", "d"]
## Diagonal ramp char -> the tile direction it rises towards.
const DIAG := {"a": Vector2i(-1, -1), "b": Vector2i(1, -1), "c": Vector2i(-1, 1), "d": Vector2i(1, 1)}

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
## Shown on the level card in quests.
var description := ""
var ramp_color := Palette.LEMON
var wall_color := Color("#5A3426")
## Multiplies every monster's speed (custom levels).
var monster_speed := 1.0
## Colour for every monster that has no own tint (alpha 0 = model colours).
var monster_tint := Color(0, 0, 0, 0)
## Race levels: rival cruise speed multiplier and colour.
var rival_speed := 1.0
var rival_tint := Color(0, 0, 0, 0)
## Marble breaks on drops of more than this many steps (0 = never).
var break_drop := 0
## Silly Race: slopes push the marble UP and monsters are harmless (squishable).
var silly := false
## False when the finish is a GOAL pad instead of the golf hole (no hole cut).
var hole := true
var _ice := {}                   # Vector2i tile -> true
## Height of one step (tier) in world units. Taller steps = taller cliffs.
var step := TIER

# Filled by build().
var cols := 0
var rows := 0
var spawn := Vector2.ZERO
var goal := Vector2.INF
var entities: Array[Dictionary] = []
var _trenches: Array = []        # [Vector2 a, Vector2 b] world
var _hills: Array[Vector4] = []  # x, z, height, radius
var _waves := {}                 # Vector2i tile -> true
var _humps := {}                 # Vector2i tile -> [axis (0 = x), start, end (world), humps]
var _diag_cache := {}            # Vector2i tile -> diagonal ramp band (see _diag)


func build() -> void:
	rows = heights.size()
	for r in heights:
		cols = maxi(cols, r.length())
	entities.clear()
	_diag_cache.clear()
	for j in objects.size():
		var line := objects[j]
		for i in line.length():
			_parse_object(line[i], i, j)
	_build_humps()
	for e in extras:
		var d := e.duplicate()
		d.pos = tile_center_f(e.tile)
		d.erase("tile")
		if d.has("target_tile"):
			d.target = tile_center_f(d.target_tile)
			d.erase("target_tile")
		if d.type in ["slingshot", "cannon", "hoop", "spinner", "redirect", "flipper"]:
			d.kind = d.type
			d.type = "pinball"
		entities.append(d)
		if d.type == "goalpad" and goal == Vector2.INF:
			goal = d.pos
			hole = false


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
	return tile_char(i, j) in RAMPS


func is_diagonal(i: int, j: int) -> bool:
	return DIAG.has(tile_char(i, j))


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
	return t * step if t >= 0 else NAN


func _base(i: int, j: int, x: float, z: float) -> float:
	if not is_ramp(i, j):
		var f := _flat(i, j)
		return 0.0 if is_nan(f) else f
	var c := tile_char(i, j)
	if DIAG.has(c):
		var dg := _diag(c, i, j)
		return _diag_height(dg, x, z)
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


## The diagonal ramp through tile (i, j): [d, u0, u1, before, after] where
## u = x * d.x + z * d.y, the incline runs from u0 to u1 and before / after are
## the flat heights at the low and high ends (NAN = void). All tiles of one
## connected band share the numbers, so a band clipped by void or the map edge
## is still one straight incline.
func _diag(c: String, i: int, j: int) -> Array:
	var key := Vector2i(i, j)
	if _diag_cache.has(key):
		return _diag_cache[key]
	var d: Vector2i = DIAG[c]
	var neg := int(d.x < 0) + int(d.y < 0)
	var region: Array[Vector2i] = [key]
	var seen := {key: true}
	var k := 0
	while k < region.size():
		var t := region[k]
		k += 1
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = t + n
			if not seen.has(q) and tile_char(q.x, q.y) == c:
				seen[q] = true
				region.append(q)
	var u_lo := INF
	var u_hi := -INF
	for t in region:
		var u := TILE * (t.x * d.x + t.y * d.y) - TILE * neg   # lowest u on this tile
		u_lo = minf(u_lo, u)
		u_hi = maxf(u_hi, u + 2.0 * TILE)
	# Plateau heights: the flat tiles along the band's lowest and highest edges
	# (the most common height wins, so a stray rail touching a corner can't
	# tilt the band); the diagonal corner neighbours only count when no tile
	# shares an edge.
	var lo_edge := {}
	var lo_corner := {}
	var hi_edge := {}
	var hi_corner := {}
	for t in region:
		var u := TILE * (t.x * d.x + t.y * d.y) - TILE * neg
		if is_equal_approx(u, u_lo):
			_count_flat(lo_edge, t - Vector2i(d.x, 0))
			_count_flat(lo_edge, t - Vector2i(0, d.y))
			_count_flat(lo_corner, t - d)
		if is_equal_approx(u + 2.0 * TILE, u_hi):
			_count_flat(hi_edge, t + Vector2i(d.x, 0))
			_count_flat(hi_edge, t + Vector2i(0, d.y))
			_count_flat(hi_corner, t + d)
	var before := _most_common(lo_edge if not lo_edge.is_empty() else lo_corner)
	var after := _most_common(hi_edge if not hi_edge.is_empty() else hi_corner)
	# Flat over the half tile at both ends (a single tile slopes corner to corner).
	var flat := TILE if u_hi - u_lo > 2.0 * TILE + 0.001 else 0.0
	var info := [d, u_lo + flat, u_hi - flat, before, after]
	for t in region:
		_diag_cache[t] = info
	return info


func _count_flat(tally: Dictionary, t: Vector2i) -> void:
	var f := _flat(t.x, t.y)
	if not is_nan(f):
		tally[f] = tally.get(f, 0) + 1


static func _most_common(tally: Dictionary) -> float:
	var best := NAN
	var best_n := 0
	for h: float in tally:
		if tally[h] > best_n:
			best_n = tally[h]
			best = h
	return best


func _diag_height(dg: Array, x: float, z: float) -> float:
	var d: Vector2i = dg[0]
	var u := x * d.x + z * d.y
	var u0: float = dg[1]
	var u1: float = dg[2]
	var before: float = dg[3]
	var after: float = dg[4]
	if not is_nan(before) and not is_nan(after):
		return lerpf(before, after, clampf((u - u0) / maxf(u1 - u0, 0.001), 0.0, 1.0))
	# Kicker: the void end keeps rising. u grows sqrt(2) per unit rolled.
	if not is_nan(before):
		return before + maxf(u - u0, 0.0) * KICK / sqrt(2.0)
	if not is_nan(after):
		return after + maxf(u1 - u, 0.0) * KICK / sqrt(2.0)
	return 0.0


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
	if not _humps.is_empty():
		h += _hump(x, z)
	if goal != Vector2.INF and hole:
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


## Each run of M tiles gets whole humps along its longer direction, flat at
## both ends so it joins the ground around it.
func _build_humps() -> void:
	_humps.clear()
	for j in objects.size():
		for i in objects[j].length():
			if objects[j][i] != "M":
				continue
			var run := [_m_run(i, j, Vector2i(1, 0)), _m_run(i, j, Vector2i(0, 1))]
			var axis := 0 if run[0].y - run[0].x >= run[1].y - run[1].x else 1
			var a0: float = run[axis].x * TILE
			var a1: float = (run[axis].y + 1) * TILE
			_humps[Vector2i(i, j)] = [axis, a0, a1, maxi(1, roundi((a1 - a0) / (2.0 * TILE)))]


## First and last tile index of the M run through (i, j) along d.
func _m_run(i: int, j: int, d: Vector2i) -> Vector2i:
	var a := Vector2i(i, j)
	while obj_char(a.x - d.x, a.y - d.y) == "M":
		a -= d
	var b := Vector2i(i, j)
	while obj_char(b.x + d.x, b.y + d.y) == "M":
		b += d
	return Vector2i(a.x, b.x) if d.x == 1 else Vector2i(a.y, b.y)


func _hump(x: float, z: float) -> float:
	var t := tile_at(x, z)
	var hp: Array = _humps.get(t, [])
	if hp.is_empty():
		# Shared tile edges: take the hump tile on the other side.
		for n in [tile_at(x - 0.001, z), tile_at(x, z - 0.001)]:
			if _humps.has(n):
				hp = _humps[n]
				break
		if hp.is_empty():
			return 0.0
	var c := x if hp[0] == 0 else z
	var u := clampf((c - hp[1]) / (hp[2] - hp[1]), 0.0, 1.0)
	var s := sin(PI * hp[3] * u)
	return HUMP_HEIGHT * s * s


func in_hole(x: float, z: float) -> bool:
	return hole and goal != Vector2.INF and Vector2(x, z).distance_to(goal) < HOLE_RADIUS


func is_ice(x: float, z: float) -> bool:
	return _ice.has(tile_at(x, z))


## Linear-space colour for a surface cell.
func cell_color(i: int, j: int, x: float, z: float) -> Color:
	var c: Color
	if _ice.has(Vector2i(i, j)):
		return Color("#CFF4FF").srgb_to_linear()
	if is_diagonal(i, j):
		# Only the incline is ramp coloured: the flat corners belong to the plateaus.
		var dg := _diag(tile_char(i, j), i, j)
		var u := x * float(dg[0].x) + z * float(dg[0].y)
		c = ramp_color
		if u < dg[1] and not is_nan(dg[3]):
			c = tier_colors[posmod(roundi(dg[3] / step), tier_colors.size())]
		elif u > dg[2] and not is_nan(dg[4]):
			c = tier_colors[posmod(roundi(dg[4] / step), tier_colors.size())]
	elif is_ramp(i, j):
		c = ramp_color
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
		"A":
			entities.append({type = "goo", pos = p})
		"I":
			_ice[Vector2i(i, j)] = true
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

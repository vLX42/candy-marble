class_name TrackPieces
## Ready-made track sections for the level editor (the same kind of pieces the
## built-in levels are stitched from, see tools/course.py).
##
## Every piece is authored travelling +x in a 6-row strip: rows 0 and 5 are
## rails, rows 1-4 the lane. Height digits are relative: world tier =
## current tier - entry + digit. stamp() rotates a piece to any heading and
## returns the cells, extras, route and the new open end of the track.

## Forward and right-hand lateral step per heading (0 = +x, 1 = +z, 2 = -x, 3 = -z).
const F := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const L := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]
const H_ROT := {"e": "s", "s": "w", "w": "n", "n": "e"}
const O_ROT := {">": "v", "v": "<", "<": "^", "^": ">", "C": "K", "K": "C"}
## Ramp character rising along each heading.
const RISE := ["e", "s", "w", "n"]

## [id, label, group, hint]
const LIST := [
	["start", "Start pad", "Begin & end", "Where the marble starts. Starts a new track."],
	["finish", "Finish", "Begin & end", "The golf hole at the end of the track."],
	["checkpoint", "Checkpoint", "Begin & end", "A gate that saves progress."],
	["straight", "Straight", "Track", "Plain straight lane with candy on the rails."],
	["long", "Long straight", "Track", "A longer straight."],
	["right", "Turn right", "Track", "Corner to the right."],
	["left", "Turn left", "Track", "Corner to the left."],
	["ramp_up", "Ramp up", "Track", "Climb one step."],
	["ramp_down", "Ramp down", "Track", "Slope down one step."],
	["drop", "Drop", "Track", "A small ledge down one step."],
	["stairs", "Stairs down", "Track", "Two little drops."],
	["funnel", "Funnel", "Track", "The lane squeezes, with boosters in the middle."],
	["bridge", "Bridge", "Track", "Narrow bridge over the void."],
	["waves", "Waves", "Bumpy", "Wobbly ripples."],
	["hills", "Hills", "Bumpy", "Round bumps."],
	["river", "River", "Bumpy", "A trench with hills around it."],
	["slalom", "Slalom", "Bumpy", "Zig-zag between blocks."],
	["bumpers", "Bumper field", "Toys", "Four pop bumpers."],
	["pinball", "Pinball table", "Toys", "Stars, bumpers, slingshots and targets."],
	["spinners", "Spinners", "Toys", "Two spinning gates."],
	["loop", "Loop", "Toys", "Loop the loop."],
	["jump", "Jump", "Toys", "Booster, kicker ramp and a hoop. Ends one step higher."],
	["cannon", "Cannon hop", "Toys", "A cannon shoots the marble over a gap. Ends one step higher."],
	["leap", "Leap down", "Toys", "Boost off an edge onto a lower lane."],
	["sweepers", "Sweepers", "Monsters", "Two wind-up blocks walking across."],
	["stompers", "Stompers", "Monsters", "Three stompers to time."],
	["hoppers", "Hoppers", "Monsters", "Two hoppers bouncing across."],
	["windmill", "Windmill", "Monsters", "A spinning windmill arm."],
	["ghosts", "Ghost hall", "Monsters", "Two ghosts float after you."],
]


static func label_of(id: String) -> String:
	for p in LIST:
		if p[0] == id:
			return p[1]
	return id


static func hint_of(id: String) -> String:
	for p in LIST:
		if p[0] == id:
			return p[3]
	return ""


# --- authoring helpers -------------------------------------------------------------

static func _grid(w: int, fill: String = ".") -> Array:
	var g := []
	for z in 6:
		var r := []
		r.resize(w)
		r.fill(fill)
		g.append(r)
	return g


static func _lane(w: int, lane_c: String = "0", rail_c: String = "1") -> Array:
	var g := _grid(w)
	for x in w:
		g[0][x] = rail_c
		g[5][x] = rail_c
		for z in range(1, 5):
			g[z][x] = lane_c
	return g


static func _rows(g: Array) -> Array:
	var out := []
	for r: Array in g:
		out.append("".join(r))
	return out


static func _piece(h: Array, o: Array = [], entry: int = 0, exit: int = -99, extras: Array = [], route: Array = []) -> Dictionary:
	var w: int = (h[0] as Array).size()
	return {h = _rows(h), o = _rows(o if not o.is_empty() else _grid(w)), w = w, entry = entry,
		exit = entry if exit == -99 else exit, extras = extras, route = route, turn = 0}


static func _rail_decor(o: Array, w: int, seed: int) -> void:
	var decor := "ltgb%lthr"
	var k := 0
	for x in range(1, w, 3):
		o[0 if k % 2 == 0 else 5][x] = decor[(seed + k) % decor.length()]
		k += 1


# --- the pieces ---------------------------------------------------------------------

static func get_piece(id: String) -> Dictionary:
	match id:
		"start":
			var h := _lane(6)
			for z in 6:
				h[z][0] = "1"
			var o := _grid(6)
			o[2][2] = "S"
			o[0][3] = "t"
			o[5][4] = "l"
			o[5][1] = "b"
			return _piece(h, o, 0, -99, [], [[2, 2], [5, 2.5]])
		"finish":
			var h := _lane(8)
			for z in 6:
				h[z][7] = "1"
			var o := _grid(8)
			o[2][5] = "G"
			o[0][7] = "%"
			o[5][7] = "t"
			o[0][2] = "l"
			o[5][3] = "g"
			var p := _piece(h, o, 0, -99, [], [[0, 2.5], [3, 2.5], [5, 2]])
			p.closed = true
			return p
		"checkpoint":
			var o := _grid(2)
			o[2][1] = "K"
			return _piece(_lane(2), o, 0, -99, [], [[0, 2.5], [1, 2.5]])
		"straight", "long":
			var w := 5 if id == "straight" else 10
			var o := _grid(w)
			_rail_decor(o, w, w)
			return _piece(_lane(w), o, 0, -99, [], [[0, 2.5], [w - 1, 2.5]])
		"right", "left":
			var d := 1 if id == "right" else -1
			var h := _grid(6)
			for x in range(0, 5):
				for z in range(1, 5):
					h[z][x] = "0"
			var exit_row := 5 if d > 0 else 0
			var rail_row := 0 if d > 0 else 5
			for x in range(1, 5):
				h[exit_row][x] = "0"
			for x in 6:
				h[rail_row][x] = "1"
			for z in 6:
				h[z][5] = "1"
			h[exit_row][0] = "1"
			var p := _piece(h, [], 0, -99, [], [[0, 2.5], [2.5, 2.5], [2.5, 5.5 if d > 0 else -0.5]])
			p.turn = d
			return p
		"ramp_up":
			var h := _lane(3)
			for z in range(1, 5):
				h[z][1] = "e"
				h[z][2] = "e"
			h[0][1] = "2"
			h[0][2] = "2"
			h[5][1] = "2"
			h[5][2] = "2"
			return _piece(h, [], 0, 1, [], [[0, 2.5], [2, 2.5]])
		"ramp_down":
			var h := _lane(3, "1", "2")
			for z in range(1, 5):
				h[z][1] = "w"
				h[z][2] = "w"
			return _piece(h, [], 1, 0, [], [[0, 2.5], [2, 2.5]])
		"drop":
			var h := _lane(4)
			for x in [0, 1]:
				for z in range(1, 5):
					h[z][x] = "1"
				h[0][x] = "2"
				h[5][x] = "2"
			return _piece(h, [], 1, 0, [], [[0, 2.5], [3, 2.5]])
		"stairs":
			var w := 6
			var h := _lane(w)
			for x in w:
				var t: int = 2 - mini(x / 2, 2)
				h[0][x] = str(t + 1)
				h[5][x] = str(t + 1)
				for z in range(1, 5):
					h[z][x] = str(t)
			var o := _grid(w)
			o[0][1] = "t"
			o[5][3] = "b"
			return _piece(h, o, 2, 0, [], [[0, 2.5], [w - 1, 2.5]])
		"funnel":
			var h := _lane(7)
			for x in range(1, 6):
				h[1][x] = "1"
				h[4][x] = "1"
			var o := _grid(7)
			o[2][3] = ">"
			o[3][3] = ">"
			o[1][2] = "%"
			o[4][4] = "g"
			return _piece(h, o, 0, -99, [], [[0, 2.5], [3, 2.5], [6, 2.5]])
		"bridge":
			var w := 10
			var h := _grid(w)
			for x in w:
				h[2][x] = "0"
				h[3][x] = "0"
			for z in [1, 4]:
				h[z][0] = "0"
				h[z][w - 1] = "0"
			return _piece(h, [], 0, -99, [], [[0, 2.5], [w - 1, 2.5]])
		"waves", "hills":
			var o := _grid(6)
			if id == "waves":
				for x in 6:
					for z in range(1, 5):
						o[z][x] = "W"
				_rail_decor(o, 6, 3)
			else:
				o[1][1] = "H"
				o[4][3] = "H"
				o[1][5] = "H"
			return _piece(_lane(6), o, 0, -99, [], [[0, 2.5], [5, 2.5]])
		"river":
			var w := 8
			var o := _grid(w)
			for x in range(1, w - 1):
				o[2][x] = "T"
			o[4][2] = "H"
			o[1][w - 3] = "H"
			return _piece(_lane(w), o, 0, -99, [], [[0, 2.5], [1, 2], [w - 2, 2], [w - 1, 2.5]])
		"slalom":
			var h := _lane(10)
			var o := _grid(10)
			for spec: Array in [[2, [1, 2]], [5, [3, 4]], [8, [1, 2]]]:
				for z: int in spec[1]:
					h[z][spec[0]] = "1"
				o[spec[1][0]][spec[0]] = "l"
			return _piece(h, o, 0, -99, [], [[0, 2.5], [1.5, 3.5], [2.5, 3.5], [3.8, 2.5], [5, 1.5], [6.2, 2.5], [8, 3.5], [9, 2.5]])
		"bumpers":
			var o := _grid(10)
			for p: Vector2i in [Vector2i(2, 1), Vector2i(4, 4), Vector2i(6, 1), Vector2i(8, 4)]:
				o[p.y][p.x] = "B"
			_rail_decor(o, 10, 5)
			return _piece(_lane(10), o, 0, -99, [], [[0, 2.5], [2, 3.3], [4, 1.8], [6, 3.2], [8, 1.8], [9, 2.5]])
		"pinball":
			var o := _grid(10)
			o[2][2] = "@"
			o[3][2] = "@"
			for p: Vector2i in [Vector2i(4, 1), Vector2i(4, 4), Vector2i(6, 2)]:
				o[p.y][p.x] = "B"
			o[1][9] = "#"
			o[4][9] = "#"
			return _piece(_lane(10), o, 0, -99,
				[{type = "slingshot", tile = [8, 1], yaw = 0.0}, {type = "slingshot", tile = [8, 4], yaw = 180.0}],
				[[0, 2.5], [2, 2.5], [4, 2.5], [5, 3.5], [7, 3.5], [8, 2.5], [9, 2.5]])
		"spinners":
			return _piece(_lane(4), [], 0, -99,
				[{type = "spinner", tile = [2, 2], yaw = 90.0}, {type = "spinner", tile = [2, 3], yaw = 90.0}],
				[[0, 2.5], [3, 2.5]])
		"loop":
			var h := _lane(9)
			for x in range(1, 7):
				h[1][x] = "1"
				h[4][x] = "1"
			return _piece(h, [], 0, -99, [{type = "loop", tile = [4, 3], yaw = 90.0}],
				[[0, 2.5], [1.5, 3], [2.5, 3], [6, 2], [8, 2.5]])
		"jump":
			var w := 11
			var h := _grid(w)
			for x in 3:
				h[0][x] = "1"
				h[5][x] = "1"
				for z in range(1, 5):
					h[z][x] = "0"
			for x in [3, 4]:
				for z in range(1, 5):
					h[z][x] = "e"
			for x in range(6, w):
				h[0][x] = "2"
				h[5][x] = "2"
				for z in range(1, 5):
					h[z][x] = "1"
			var o := _grid(w)
			o[2][1] = ">"
			o[3][1] = ">"
			return _piece(h, o, 0, 1, [{type = "hoop", tile = [5, 2.5], yaw = 90.0, rise = 1.95, base = 0}],
				[[0, 2.5], [1, 2.5], [3.5, 2.5], [8, 2.5], [10, 2.5]])
		"cannon":
			var w := 13
			var h := _grid(w)
			for x in 4:
				for z in 6:
					h[z][x] = "1"
				h[2][x] = "0"
			for z in range(1, 5):
				h[z][0] = "0"
				h[z][1] = "0"
			for z in 6:
				h[z][4] = "1"
			for x in range(8, w):
				h[0][x] = "2"
				h[5][x] = "2"
				for z in range(1, 5):
					h[z][x] = "1"
			return _piece(h, [], 0, 1,
				[{type = "cannon", tile = [3, 2], target_tile = [10, 2.5]},
				{type = "hoop", tile = [6.5, 2.3], yaw = 90.0, rise = 4.1, base = 0}],
				[[0, 2.5], [2, 2], [3, 2], [10, 2.5], [12, 2.5]])
		"leap":
			var w := 11
			var h := _grid(w)
			for x in 4:
				h[0][x] = "2"
				h[5][x] = "2"
				for z in range(1, 5):
					h[z][x] = "1"
			for x in range(5, w):
				h[0][x] = "1"
				h[5][x] = "1"
				for z in range(1, 5):
					h[z][x] = "0"
			var o := _grid(w)
			o[2][1] = ">"
			o[3][1] = ">"
			o[0][7] = "%"
			o[5][8] = "t"
			return _piece(h, o, 1, 0, [], [[0, 2.5], [1, 2.5], [3.5, 2.5], [7, 2.5], [10, 2.5]])
		"sweepers":
			var w := 6
			var ex := []
			for k in 2:
				ex.append({type = "enemy", tile = [2 + 2 * k, 1], travel_tiles = [0, 3], period = 4.3, phase = 0.5 * k})
			return _piece(_lane(w), [], 0, -99, ex, [[0, 2.5], [w - 1, 2.5]])
		"stompers":
			var w := 9
			var ex := []
			for k in 3:
				ex.append({type = "stomper", tile = [2 + 2.5 * k, 2.5 if k % 2 == 0 else 1.5], period = 2.8, phase = 0.3 * k})
			return _piece(_lane(w), [], 0, -99, ex, [[0, 2.5], [w - 1, 2.5]])
		"hoppers":
			var w := 8
			return _piece(_lane(w), [], 0, -99,
				[{type = "hopper", tile = [2.5, 1], travel_tiles = [0, 3], period = 3.6, hops = 2},
				{type = "hopper", tile = [5.5, 4], travel_tiles = [0, -3], period = 3.0, hops = 2, phase = 0.5}],
				[[0, 2.5], [w - 1, 2.5]])
		"windmill":
			var w := 8
			return _piece(_lane(w), [], 0, -99, [{type = "windmill", tile = [3.5, 2.5], spin = 1.2}],
				[[0, 2.5], [w - 1, 2.5]])
		"ghosts":
			var w := 10
			var o := _grid(w)
			_rail_decor(o, w, 2)
			return _piece(_lane(w), o, 0, -99,
				[{type = "ghost", tile = [3, 1], leash = 4.5}, {type = "ghost", tile = [7, 4], leash = 4.5}],
				[[0, 2.5], [w - 1, 2.5]])
	return {}


# --- stamping -----------------------------------------------------------------------

static func world(origin: Vector2i, h: int, x: float, z: float) -> Vector2:
	var f: Vector2 = Vector2(F[h])
	var l: Vector2 = Vector2(L[h])
	return Vector2(origin) + f * x + l * z


static func _rot(c: String, table: Dictionary, times: int) -> String:
	for k in times:
		c = table.get(c, c)
	return c


## Places `piece` with its entry at `origin` facing heading `h` at `tier`.
## Returns {ok, why, cells: {Vector2i: [h, o]}, extras, route, end: [x, z, h, tier]}.
static func stamp(piece: Dictionary, origin: Vector2i, h: int, tier: int, step: float = LevelBase.TIER) -> Dictionary:
	var out := {ok = true, why = "", cells = {}, extras = [], route = [], end = []}
	var w: int = piece.w
	for z in 6:
		var hr: String = piece.h[z]
		var orow: String = piece.o[z]
		for x in w:
			var hc := hr[x]
			var oc := orow[x]
			if hc == "." and oc == ".":
				continue
			if hc.is_valid_int():
				var t: int = tier - piece.entry + int(hc)
				if t < 0:
					out.ok = false
					out.why = "Too low here. Add a Ramp up first, or start the track higher."
				elif t > 9:
					out.ok = false
					out.why = "Too high here. Add a Ramp down first."
				hc = str(clampi(t, 0, 9))
			else:
				hc = _rot(hc, H_ROT, h)
			oc = _rot(oc, O_ROT, h)
			var p := Vector2i(world(origin, h, x, z))
			out.cells[p] = [hc, oc]
	for e: Dictionary in piece.extras:
		var d := e.duplicate(true)
		var t := world(origin, h, e.tile[0], e.tile[1])
		d.tile = [t.x, t.y]
		if d.has("target_tile"):
			var tt := world(origin, h, e.target_tile[0], e.target_tile[1])
			d.target_tile = [tt.x, tt.y]
		if d.has("yaw"):
			d.yaw = fposmod(d.yaw - 90.0 * h, 360.0)
		if d.has("travel_tiles"):
			var tv: Array = d.travel_tiles
			d.erase("travel_tiles")
			var v: Vector2 = Vector2(F[h]) * tv[0] + Vector2(L[h]) * tv[1]
			d.travel = [v.x * 2.0, 0.0, v.y * 2.0]
		if d.has("rise"):
			d.height = (tier - piece.entry + d.get("base", piece.entry)) * step + d.rise
			d.erase("rise")
			d.erase("base")
		out.extras.append(d)
	for r: Array in piece.route:
		var p := world(origin, h, r[0], r[1])
		out.route.append([p.x, p.y])
	var end_tier: int = tier + piece.exit - piece.entry
	var o: Vector2i = origin + F[h] * w
	var nh := h
	if piece.turn > 0:
		o = origin + L[h] * 6 + F[h] * 5
		nh = (h + 1) % 4
	elif piece.turn < 0:
		o = origin - L[h]
		nh = (h + 3) % 4
	out.end = [] if piece.get("closed", false) else [o.x, o.y, nh, end_tier]
	return out


## Lane centre (tile coordinates, can be fractional) of a track end.
static func end_center(end: Array) -> Vector2:
	return world(Vector2i(end[0], end[1]), end[2], -0.5, 2.5)

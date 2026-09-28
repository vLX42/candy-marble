class_name CustomLevel
extends LevelBase
## A level made in the level editor. Custom levels are plain JSON dictionaries
## (stored in a Quest), so they can be saved, shared and pasted without running
## any code. Everything read from a file goes through sanitize() first.
##
##   {title, description, par, race, heights: [..], objects: [..], extras: [..],
##    route: [[x, y], ..], theme: {tiers: [5 colours], ramp, wall},
##    monster_speed, monster_tint, rival_speed, rival_tint}
##
## Vectors are arrays ([x, y] or [x, y, z]) and colours "#rrggbb" strings.
## An empty colour string means "use the model's own colours".

const MAX_SIZE := 160
const MAX_EXTRAS := 400
const MAX_ROUTE := 400
const HEIGHT_CHARS := ".0123456789ewsnabcd"
const OBJECT_CHARS := ".SGBHWT><v^xXzZ-|CKltbg%hr$@#AMIP"

## Extras and their tweakable numbers: {param: [default, min, max, label]}.
## "travel" (Vector3) and "target_tile" (Vector2) are handled on their own.
const EXTRA_PARAMS := {
	"enemy": {period = [2.6, 0.4, 20.0, "Trip time (s)"], phase = [0.0, 0.0, 1.0, "Start offset"]},
	"stomper": {period = [3.0, 0.8, 12.0, "Stomp time (s)"], lift = [2.4, 1.0, 5.0, "Lift height"],
		phase = [0.0, 0.0, 1.0, "Start offset"]},
	"hopper": {period = [4.0, 0.8, 20.0, "Trip time (s)"], hops = [3, 1, 8, "Hops"],
		hop_height = [1.8, 0.4, 4.0, "Hop height"], phase = [0.0, 0.0, 1.0, "Start offset"]},
	"ghost": {speed = [2.6, 0.5, 8.0, "Chase speed"], leash = [6.0, 1.0, 16.0, "Leash"],
		sense = [7.5, 2.0, 20.0, "Sight range"], chase_time = [3.0, 0.5, 10.0, "Chase time"],
		rest_time = [2.5, 0.2, 10.0, "Rest time"]},
	"windmill": {spin = [1.2, -4.0, 4.0, "Spin"], arm_length = [3.8, 1.5, 6.0, "Arm length"]},
	"catapult": {},
	"cannon": {},
	"slingshot": {strength = [10.0, 4.0, 20.0, "Kick"]},
	"redirect": {strength = [8.0, 4.0, 20.0, "Launch speed"]},
	"hoop": {height = [2.2, 0.8, 9.0, "Height"]},
	"spinner": {},
	"flipper": {strength = [13.0, 6.0, 20.0, "Flip strength"]},
	"switch": {open_time = [0.0, 0.0, 60.0, "Open seconds (0 = for good)"],
		order = [0, 0, 9, "Order (0 = any)"], toggle = [0, 0, 1, "Lever: flips its gates (1 = yes)"]},
	"gate": {open_time = [0.0, 0.0, 60.0, "Open seconds (0 = for good)"], height = [1.3, 0.5, 3.0, "Height"],
		y = [0.0, -2.0, 9.0, "Height of a bridge"], invert = [0, 0, 1, "Starts open, shuts on its switch (1 = yes)"]},
	"secret": {},
	"steelie": {speed = [4.2, 1.5, 9.0, "Roll speed"], sense = [9.0, 3.0, 20.0, "Sight range"],
		leash = [10.0, 3.0, 30.0, "Leash length"]},
	"slime": {period = [5.0, 1.0, 20.0, "Trip time (s)"], phase = [0.0, 0.0, 1.0, "Start offset"]},
	"pipe": {speed = [6.0, 2.0, 14.0, "Exit speed"]},
	"bird": {speed = [6.0, 2.0, 14.0, "Flying speed"]},
	"goalpad": {},
	"loop": {},
	"chute": {y = [0.0, -2.0, 6.0, "Height"]},
}
## Extras that move and can be recoloured and sped up.
const MONSTERS := ["enemy", "stomper", "hopper", "ghost", "windmill", "steelie", "slime"]
const HAS_TRAVEL := ["enemy", "hopper", "slime"]
const HAS_TARGET := ["catapult", "cannon", "pipe", "bird"]

const THEMES := {
	"Candy": {tiers = ["#A8E6C8", "#C9B8EC", "#BFE3F7", "#F9C6D3", "#FFE7B3"], ramp = "#F6E27A", wall = "#5A3426"},
	"Mint choc": {tiers = ["#BFF0D8", "#8FD9B6", "#D9F5E6", "#A8E6C8", "#C6F0DC"], ramp = "#F7B2C0", wall = "#3E2418"},
	"Bubblegum": {tiers = ["#F9C6D3", "#F7B2C0", "#FBD9E4", "#F4A3BA", "#FDE6EE"], ramp = "#A9D6F5", wall = "#8A3553"},
	"Lemonade": {tiers = ["#FFF1A8", "#FFE07A", "#FFF6CC", "#F6E27A", "#FFEAB8"], ramp = "#F6845E", wall = "#7A5A1E"},
	"Blueberry": {tiers = ["#BFD4F7", "#A9C1F0", "#C9B8EC", "#D6E4FB", "#B4A7E8"], ramp = "#F6E27A", wall = "#2E2350"},
	"Caramel": {tiers = ["#F3D2A2", "#E8B77A", "#F7E0BF", "#DDA46A", "#FBEBD2"], ramp = "#F7B2C0", wall = "#6B3E1F"},
}


static func blank(level_title: String = "New level") -> Dictionary:
	var h: Array = []
	var o: Array = []
	for j in 8:
		h.append("." + "0".repeat(14) + ".")
		o.append(".".repeat(16))
	h.push_front(".".repeat(16))
	o.push_front(".".repeat(16))
	h.append(".".repeat(16))
	o.append(".".repeat(16))
	o[4] = "..S" + ".".repeat(13)
	o[5] = ".".repeat(12) + "G" + "..."
	return {
		title = level_title, description = "", par = 30.0, race = false,
		heights = h, objects = o, extras = [], route = [],
		theme = THEMES["Candy"].duplicate(true),
		monster_speed = 1.0, monster_tint = "", rival_speed = 1.0, rival_tint = "", break_drop = 0, step = TIER,
	}


## Playable level from a (sanitised) dictionary.
static func from_dict(d: Dictionary) -> CustomLevel:
	var s := sanitize(d)
	var l := CustomLevel.new()
	l.title = s.title
	l.description = s.description
	l.time_limit = s.par
	l.race = s.race
	l.silly = s.silly
	l.heights = PackedStringArray(s.heights)
	l.objects = PackedStringArray(s.objects)
	var tiers: Array[Color] = []
	for c: String in s.theme.tiers:
		tiers.append(Color(c))
	l.tier_colors = tiers
	l.ramp_color = Color(s.theme.ramp)
	l.wall_color = Color(s.theme.wall)
	l.monster_speed = s.monster_speed
	l.monster_tint = _color_or_none(s.monster_tint)
	l.rival_speed = s.rival_speed
	l.rival_tint = _color_or_none(s.rival_tint)
	l.break_drop = s.break_drop
	l.step = s.step
	var ex: Array[Dictionary] = []
	for e: Dictionary in s.extras:
		ex.append(decode_extra(e))
	l.extras = ex
	var r: Array[Vector2] = []
	for p: Array in s.route:
		r.append(Vector2(p[0], p[1]))
	l.route = r
	return l


func build() -> void:
	super.build()
	# Sweepers placed over void stand on the first ground tile along their path.
	for e in entities:
		if e.type != "enemy":
			continue
		var t := tile_at(e.pos.x, e.pos.y)
		if is_tile_ground(t.x, t.y):
			continue
		var travel: Vector3 = e.get("travel", Vector3.ZERO)
		var steps := int(travel.length() / TILE)
		var dir := Vector2(travel.x, travel.z).normalized()
		for k in range(1, steps + 1):
			var p := Vector2(e.pos) + dir * k * TILE
			var tt := tile_at(p.x, p.y)
			if is_tile_ground(tt.x, tt.y):
				e.ground_tile = tt
				break
	if route.size() < 2:
		route = CustomLevel.auto_route(self)


# --- sanitising -----------------------------------------------------------------

static func sanitize(d: Variant) -> Dictionary:
	var src: Dictionary = d if d is Dictionary else {}
	var out := {}
	out.title = _text(src.get("title"), "Untitled", 40)
	out.description = _text(src.get("description"), "", 400)
	out.par = clampf(_num(src.get("par"), 30.0), 5.0, 900.0)
	out.race = src.get("race") is bool and src.race
	out.silly = src.get("silly") is bool and src.silly
	out.monster_speed = clampf(_num(src.get("monster_speed"), 1.0), 0.25, 3.0)
	out.rival_speed = clampf(_num(src.get("rival_speed"), 1.0), 0.5, 1.6)
	out.break_drop = clampi(int(_num(src.get("break_drop"), 0)), 0, 18)
	out.step = snappedf(clampf(_num(src.get("step"), TIER), 0.25, 1.5), 0.05)
	out.monster_tint = _color_text(src.get("monster_tint"), "")
	out.rival_tint = _color_text(src.get("rival_tint"), "")
	var theme: Dictionary = src.get("theme") if src.get("theme") is Dictionary else {}
	var def: Dictionary = THEMES["Candy"]
	var tiers: Array = []
	var st: Array = theme.get("tiers") if theme.get("tiers") is Array else []
	for k in 5:
		tiers.append(_color_text(st[k] if k < st.size() else null, def.tiers[k]))
	out.theme = {tiers = tiers, ramp = _color_text(theme.get("ramp"), def.ramp),
		wall = _color_text(theme.get("wall"), def.wall)}

	var hs := _grid(src.get("heights"), HEIGHT_CHARS)
	if hs.is_empty():
		hs = blank().heights
	var width := 1
	for r: String in hs:
		width = maxi(width, r.length())
	var os := _grid(src.get("objects"), OBJECT_CHARS)
	for j in hs.size():
		hs[j] = hs[j].rpad(width, ".")
	var objs: Array = []
	for j in hs.size():
		var line: String = os[j] if j < os.size() else ""
		objs.append(line.substr(0, width).rpad(width, "."))
	out.heights = hs
	out.objects = objs

	var extras: Array = []
	var se: Array = src.get("extras") if src.get("extras") is Array else []
	for e: Variant in se:
		if extras.size() >= MAX_EXTRAS:
			break
		var c := sanitize_extra(e, width, hs.size())
		if not c.is_empty():
			extras.append(c)
	out.extras = extras
	var route: Array = []
	var sr: Array = src.get("route") if src.get("route") is Array else []
	for p: Variant in sr:
		if route.size() >= MAX_ROUTE:
			break
		var v := _vec(p, 2)
		if v.size() == 2:
			route.append([clampf(v[0], -1.0, width), clampf(v[1], -1.0, hs.size())])
	out.route = route
	# Editor only: where the next track section attaches [x, z, heading, tier].
	var te: Array = src.get("track_end") if src.get("track_end") is Array else []
	var tv := _vec(te, 4)
	if tv.size() == 4:
		out.track_end = [clampi(int(tv[0]), -8, width + 8), clampi(int(tv[1]), -8, hs.size() + 8),
			posmod(int(tv[2]), 4), clampi(int(tv[3]), 0, 9)]
	return out


static func sanitize_extra(e: Variant, width: int, height: int) -> Dictionary:
	if not e is Dictionary:
		return {}
	var type: String = str(e.get("type", ""))
	if not EXTRA_PARAMS.has(type):
		return {}
	var tile := _vec(e.get("tile"), 2)
	if tile.size() != 2:
		return {}
	var out := {type = type, tile = [clampf(tile[0], -2.0, width + 1.0), clampf(tile[1], -2.0, height + 1.0)]}
	out.yaw = fposmod(_num(e.get("yaw"), 0.0), 360.0)
	for key: String in EXTRA_PARAMS[type]:
		var spec: Array = EXTRA_PARAMS[type][key]
		if e.has(key):
			var v := clampf(_num(e[key], spec[0]), spec[1], spec[2])
			out[key] = roundi(v) if spec[0] is int else v
	if type in HAS_TRAVEL:
		var t := _vec(e.get("travel"), 3)
		if t.size() == 3:
			out.travel = [clampf(t[0], -60.0, 60.0), 0.0, clampf(t[2], -60.0, 60.0)]
		else:
			out.travel = [0.0, 0.0, 6.0]
	if type in HAS_TARGET:
		var t := _vec(e.get("target_tile"), 2)
		if t.size() == 2:
			out.target_tile = [clampf(t[0], -2.0, width + 1.0), clampf(t[1], -2.0, height + 1.0)]
		else:
			out.target_tile = [out.tile[0] + 6.0, out.tile[1]]
	var tint := _color_text(e.get("tint"), "")
	if tint != "":
		out.tint = tint
	# Puzzle pieces: which switch opens which gate, the gate's footprint.
	if type in ["switch", "gate"]:
		var ch := ""
		for c: String in str(e.get("channel", "a")).substr(0, 16):
			if c in "abcdefghijklmnopqrstuvwxyz0123456789_":
				ch += c
		out.channel = ch if ch != "" else "a"
	if type == "gate":
		var sz := _vec(e.get("size"), 2)
		out.size = [clampf(sz[0], 1.0, 12.0), clampf(sz[1], 1.0, 12.0)] if sz.size() == 2 else [1.0, 4.0]
		out.bridge = e.get("bridge") is bool and e.bridge
	if type == "cannon" and (e.get("hang") is float or e.get("hang") is int):
		out.hang = clampf(float(e.hang), 0.0, 5.0)
	return out


## JSON extra -> LevelBase extra (native Vector2 / Vector3 / Color values).
static func decode_extra(e: Dictionary) -> Dictionary:
	var d := {}
	for key: String in e:
		var v: Variant = e[key]
		match key:
			"tile", "target_tile", "size":
				d[key] = Vector2(v[0], v[1])
			"travel":
				d[key] = Vector3(v[0], v[1], v[2])
			"tint":
				d[key] = Color(v)
			_:
				d[key] = v
	return d


## LevelBase extra -> JSON extra.
static func encode_extra(e: Dictionary) -> Dictionary:
	var d := {}
	for key: String in e:
		var v: Variant = e[key]
		if v is Vector2 or v is Vector2i:
			d[key] = [float(v.x), float(v.y)]
		elif v is Vector3:
			d[key] = [v.x, v.y, v.z]
		elif v is Color:
			d[key] = "#" + v.to_html(false)
		else:
			d[key] = v
	return d


## JSON copy of a built-in (script) level, for remixing in the editor.
## Sweepers written as x/z runs in the object map become enemy extras.
static func dict_from_level(src: LevelBase, keep_route: bool = true) -> Dictionary:
	src.build()
	var objs: Array = []
	for line in src.objects:
		var clean := ""
		for ch in line:
			clean += "." if ch in "xXzZ-|" else ch
		objs.append(clean)
	var extras: Array = []
	for e in src.extras:
		extras.append(encode_extra(e))
	for e in src.entities:
		# Only sweepers written into the object map (x/z runs); extras are
		# already in the list above.
		if e.type == "enemy" and e.has("ground_tile"):
			var t: Vector2 = e.pos / TILE - Vector2(0.5, 0.5)
			extras.append(encode_extra({type = "enemy", tile = t.round(), travel = e.travel,
				period = e.period, phase = e.phase}))
	var tiers: Array = []
	for k in 5:
		tiers.append("#" + src.tier_colors[k % src.tier_colors.size()].to_html(false))
	var route: Array = []
	if keep_route:
		for p in src.route:
			route.append([p.x, p.y])
	return sanitize({
		title = src.title, description = src.description, par = src.time_limit, race = src.race,
		silly = src.silly, break_drop = src.break_drop, step = src.step,
		heights = Array(src.heights), objects = objs, extras = extras, route = route,
		theme = {tiers = tiers, ramp = "#" + src.ramp_color.to_html(false), wall = "#" + src.wall_color.to_html(false)},
		monster_speed = src.monster_speed, monster_tint = _tint_text(src.monster_tint),
		rival_speed = src.rival_speed, rival_tint = _tint_text(src.rival_tint),
	})


static func _tint_text(c: Color) -> String:
	return "#" + c.to_html(false) if c.a > 0.0 else ""


# --- auto route -----------------------------------------------------------------

## Tile path from spawn to goal (breadth first). Walls higher than a small
## step block the way, drops are fine, cannons and catapults jump. Used for
## the race rival and the follow camera when the author drew no path.
static func auto_route(l: LevelBase) -> Array[Vector2]:
	var out := find_path(l)
	if out.is_empty() and l.goal != Vector2.INF:
		out.append(Vector2(l.tile_at(l.spawn.x, l.spawn.y)))
		out.append(Vector2(l.tile_at(l.goal.x, l.goal.y)))
	return out


## Like auto_route, but empty when there is no rolling way to the hole.
static func find_path(l: LevelBase) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if l.goal == Vector2.INF:
		return out
	var start := l.tile_at(l.spawn.x, l.spawn.y)
	var end := l.tile_at(l.goal.x, l.goal.y)
	var jumps := {}
	for e in l.extras:
		if e.has("target_tile"):
			jumps[Vector2i(Vector2(e.tile).round())] = Vector2i(Vector2(e.target_tile).round())
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var found := false
	while not queue.is_empty():
		var a: Vector2i = queue.pop_front()
		if a == end:
			found = true
			break
		var nexts: Array[Vector2i] = [a + Vector2i.RIGHT, a + Vector2i.LEFT, a + Vector2i.DOWN, a + Vector2i.UP]
		if jumps.has(a):
			nexts.append(jumps[a])
		for b in nexts:
			if prev.has(b) or not l.is_tile_ground(b.x, b.y):
				continue
			if not (jumps.has(a) and jumps[a] == b) and not _can_step(l, a, b):
				continue
			prev[b] = a
			queue.append(b)
	if not found:
		return out
	var path: Array[Vector2i] = [end]
	while path[0] != start:
		path.push_front(prev[path[0]])
	# Keep the corners only.
	for k in path.size():
		if k == 0 or k == path.size() - 1:
			out.append(Vector2(path[k]))
			continue
		var d0 := path[k] - path[k - 1]
		var d1 := path[k + 1] - path[k]
		if d0 != d1 or d0.length() > 1.5:
			out.append(Vector2(path[k]))
	return out


static func _can_step(l: LevelBase, a: Vector2i, b: Vector2i) -> bool:
	var ca := l.tile_center(a.x, a.y)
	var cb := l.tile_center(b.x, b.y)
	var ha := l.surface(a.x, a.y, ca.x, ca.y)
	var hb := l.surface(b.x, b.y, cb.x, cb.y)
	if l.obj_char(b.x, b.y) == "A":
		return false
	if l.break_drop > 0 and ha - hb > l.break_drop * l.step + 0.3:
		return false
	if l.is_ramp(a.x, a.y) or l.is_ramp(b.x, b.y):
		return hb - ha < 1.2
	return hb - ha < 0.3


# --- helpers --------------------------------------------------------------------

static func _text(v: Variant, fallback: String, max_len: int) -> String:
	if not v is String:
		return fallback
	var s: String = v.strip_edges().substr(0, max_len)
	return s if s != "" or fallback == "" else fallback


static func _num(v: Variant, fallback: float) -> float:
	if v is float or v is int:
		var f := float(v)
		return f if is_finite(f) else fallback
	return fallback


static func _color_text(v: Variant, fallback: String) -> String:
	if v is String and v.begins_with("#") and Color.html_is_valid(v):
		return "#" + Color(v).to_html(false)
	return "#" + Color(fallback).to_html(false) if fallback != "" else ""


static func _color_or_none(s: String) -> Color:
	return Color(s) if s != "" else Color(0, 0, 0, 0)


static func _vec(v: Variant, n: int) -> Array:
	if not v is Array or v.size() != n:
		return []
	var out: Array = []
	for x: Variant in v:
		if not (x is float or x is int) or not is_finite(float(x)):
			return []
		out.append(float(x))
	return out


static func _grid(v: Variant, allowed: String) -> Array:
	var out: Array = []
	if not v is Array:
		return out
	for line: Variant in v:
		if out.size() >= MAX_SIZE:
			break
		if not line is String:
			line = ""
		var clean := ""
		for ch: String in line.substr(0, MAX_SIZE):
			clean += ch if ch in allowed else "."
		out.append(clean)
	return out

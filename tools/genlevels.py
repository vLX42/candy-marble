"""Generates scripts/levels/level_N.gd from compact Python layouts.
Run: python3 tools/genlevels.py   (see the LevelBase docs for the map characters)
"""
import os
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts", "levels")

def level(num, title, desc, time_limit, heights, objs, extras, route, width):
    for r in heights:
        assert len(r) == width, (title, r, len(r))
    rows = len(heights)
    grid = [["."] * width for _ in range(rows)]
    for (x, z), c in objs.items():
        assert 0 <= x < width and 0 <= z < rows, (title, x, z)
        assert grid[z][x] == ".", (title, x, z, grid[z][x], c)
        grid[z][x] = c
    obj_rows = ["".join(r) for r in grid]
    L = [f"extends LevelBase", f"## {desc}", "", "", "func _init() -> void:",
         f'\ttitle = "{title}"', f"\ttime_limit = {time_limit:.1f}", "\theights = ["]
    L += [f'\t\t"{r}",' for r in heights] + ["\t]", "\tobjects = ["]
    L += [f'\t\t"{r}",' for r in obj_rows] + ["\t]"]
    if extras:
        L.append("\textras = [")
        for e in extras:
            L.append("\t\t" + e + ",")
        L.append("\t]")
    L.append("\troute = [")
    line = "\t\t"
    for x, z in route:
        line += f"Vector2({x}, {z}), "
        if len(line) > 90:
            L.append(line.rstrip()); line = "\t\t"
    if line.strip():
        L.append(line.rstrip())
    L.append("\t]")
    with open(os.path.join(OUT, f"level_{num}.gd"), "w") as f:
        f.write("\n".join(L) + "\n")
    print("wrote", title, width, "x", rows)

def put(d, xs, z, c):
    for x in xs:
        d[(x, z)] = c

# ---------------------------------------------------------------- level 1
def canvas(w, h):
    return [["."] * w for _ in range(h)]

def rect(cv, x0, z0, x1, z1, c):
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            cv[z][x] = c

W1 = 30
cv = canvas(W1, 20)
# Band 1 (+x): start plateau, ramp down, waves, bumpers, slow sweeper.
rect(cv, 6, 1, 27, 4, "0"); rect(cv, 0, 1, 3, 4, "2"); rect(cv, 4, 1, 5, 4, "w")
rect(cv, 0, 0, 3, 0, "3"); rect(cv, 0, 5, 3, 5, "3")          # start rails
rect(cv, 6, 0, 28, 0, "1"); rect(cv, 6, 5, 23, 5, "1")         # lane rails
# Band 2 (+z): booster into the loop.
rect(cv, 24, 5, 27, 18, "0"); rect(cv, 23, 6, 23, 13, "1"); rect(cv, 28, 0, 28, 19, "1")
# Band 3 (-x): candy river, hills, booster, kicker over a gap, walled landing.
rect(cv, 11, 15, 27, 18, "0"); rect(cv, 11, 14, 23, 14, "1"); rect(cv, 11, 19, 28, 19, "1")
rect(cv, 9, 15, 10, 18, "w")                                     # kicker rising to -x
rect(cv, 1, 15, 7, 18, "1"); rect(cv, 1, 14, 7, 14, "2"); rect(cv, 1, 19, 7, 19, "2")
rect(cv, 0, 14, 0, 19, "3")
H = ["".join(r) for r in cv]
O = {(1, 2): "S", (0, 0): "l", (3, 0): "t", (0, 5): "b", (3, 5): "l",
     (16, 1): "B", (16, 4): "B", (19, 4): "B", (22, 1): "z", (22, 2): "|", (22, 3): "|", (22, 4): "|",
     (25, 6): "C", (25, 7): "v", (23, 16): "K", (17, 15): "H", (20, 15): "H", (12, 16): "<",
     (3, 17): "G", (10, 0): "t", (13, 5): "l", (20, 0): "b", (28, 3): "t", (23, 9): "l", (28, 11): "b",
     (16, 19): "t", (26, 19): "l", (4, 14): "b", (1, 19): "t", (6, 19): "l",
     (11, 1): "@", (11, 4): "@"}
for x in range(7, 14):
    for z in range(1, 5):
        O[(x, z)] = "W"
for x in range(14, 22):
    O[(x, 17)] = "T"
level(1, "Sugar Lane", "A friendly tour with rails: waves, bumpers, one slow sweeper, a loop, a candy river, a jump, the hole.",
      38, H, O, ['{type = "loop", tile = Vector2(25, 10), yaw = 0.0}',
                 '{type = "hoop", tile = Vector2(8, 16), height = 2.0, yaw = 90.0}'],
      [(1, 2.5), (3, 2.5), (6, 2.5), (14, 2.5), (17.5, 2.5), (21, 2.5), (25, 2.5), (25, 4), (25, 7), (25, 8),
       (26, 12.5), (26, 14), (26, 16), (24, 16), (12, 16), (10, 16), (5, 16), (3, 17)], W1)

# ---------------------------------------------------------------- level 2
rail = "1" * 10
table = "0" * 9 + "1"      # east rail except the bridge row
H = []
H.append("....." + rail + "......" + "0000" + "1" + ".")
H.append("....1" + table + "......" + "0000" + "1" + ".")
H.append("222ww" + table + "......" + "0000" + "1" + ".")
H.append("222ww" + "0" * 10 + "000000" + "0000" + "1" + ".")
H.append("222ww" + table + "......" + "0000" + "1" + ".")
H.append("....1" + table + "......" + "0000" + "1" + ".")
H.append("....." + rail + "......" + "0000" + "1" + ".")
for z in range(5): H.append("." * 21 + "000" + "...")
for z in range(4): H.append("." * 19 + "0" * 8)
H.append("." * 19 + "1" * 8)
O = {(1, 3): "S", (5, 0): "l", (5, 6): "b", (14, 6): "t", (24, 0): "t", (24, 6): "l",
     (7, 1): "B", (7, 5): "B", (11, 1): "B", (11, 5): "B", (9, 3): "@", (13, 1): "z", (17, 2): "Z", (19, 2): "Z", (22, 3): "K", (22, 8): "v",
     (19, 12): "H", (25, 14): "H", (20, 14): "G", (26, 12): "b", (19, 15): "t", (26, 15): "l"}
for z in range(2, 6): O[(13, z)] = "|"
for x in (17, 19):
    O[(x, 3)] = "|"; O[(x, 4)] = "|"
put(O, range(21, 24), 14, "T")
level(2, "Gumdrop Pinball", "Downhill into a bumper table, a sweeper-guarded bridge, a loop, then putt along the trench.",
      30, H, O, ['{type = "loop", tile = Vector2(22, 10), yaw = 0.0}'],
      [(1, 3), (4, 3), (6, 3), (9, 3), (12, 3), (13.5, 3), (14.5, 3), (20.5, 3),
       (22, 3), (22, 6), (22, 8), (22, 9), (23, 12.3), (23, 13.3), (22.5, 14), (21, 14), (20, 14)], 27)

# ---------------------------------------------------------------- level 3
H = []
for z in range(2): H.append("." * 8 + "1" * 7 + "2" + "..")
for z in range(4): H.append("0" * 5 + "ee" + "." + "1" * 7 + "2" + "..")
for z in range(2): H.append("." * 8 + "1" * 7 + "2" + "..")
for z in range(2): H.append("." * 11 + "sss" + "....")
H.append("." * 18)
for z in range(6): H.append("." * 9 + "2" * 8 + ".")
H.append("." * 9 + "3" * 8 + ".")
O = {(1, 3): "S", (3, 3): ">", (0, 2): "l", (0, 5): "t", (14, 0): "t", (8, 7): "b",
     (9, 3): "K", (11, 0): "z", (12, 6): "v", (12, 12): "C", (10, 13): "B", (14, 13): "B",
     (16, 14): "H", (9, 15): "X", (13, 16): "G", (9, 16): "t", (16, 16): "l"}
for z in range(1, 6): O[(11, z)] = "|"
put(O, range(10, 17), 15, "-")
level(3, "Sprinkle Skies", "Island hopping: two kicker jumps, sweepers in between, a fast sweeper guarding the hole.",
      16, H, O, ['{type = "hoop", tile = Vector2(7, 3), height = 2.0, yaw = 90.0}',
                 '{type = "hoop", tile = Vector2(12, 10), height = 2.4, yaw = 0.0}'], [(1, 3), (3, 3), (5.5, 3), (9, 3), (10, 4), (12, 5), (12, 6), (12, 8), (12, 11.5), (12, 12),
                     (12, 14), (13, 15.5), (13, 16)], 18)

# ---------------------------------------------------------------- level 4
H = []
for z in range(4): H.append("3" * 7 + "2" * 7 + "3" + ".")
for z in range(4): H.append("." * 10 + "2222" + "..")
for z in range(3): H.append(".2" + "1" * 12 + "..")
H.append(".2" + "1" * 6 + "." * 8)
for z in range(2): H.append(".." + "nnn" + "." * 11)
for z in range(3): H.append("0" * 10 + "." * 6)
H.append("1" * 10 + "." * 6)
O = {(0, 1): "S", (2, 0): "H", (5, 0): "H", (9, 0): "B", (11, 1): "B", (9, 3): "B", (12, 0): "z",
     (11, 5): "C", (13, 6): "l", (12, 9): "<", (13, 10): "b", (3, 11): "C",
     (7, 14): "z", (7, 15): "|", (7, 16): "|", (9, 15): "G", (1, 16): "H", (9, 17): "l", (0, 14): "t",
     (6, 0): "t"}
put(O, range(1, 6), 2, "T")
for z in (1, 2, 3): O[(12, z)] = "|"
put(O, (3, 4, 5), 15, "T")
level(4, "Licorice Loops", "Terraces: a trench start, a bumper deck, drop down to a backwards loop, ramp down to the hole.",
      52, H, O, ['{type = "loop", tile = Vector2(9, 9), yaw = -90.0}'],
      [(0, 1), (1, 2), (5, 2), (6.5, 2), (8, 2), (10, 2), (11.5, 2.5), (11.5, 3.5), (11.5, 5), (11.5, 7),
       (11.5, 8.3), (12, 9), (7.5, 10), (3, 10), (3, 11), (3, 12), (3, 14), (5, 15), (6.5, 15), (9, 15)], 16)

# ---------------------------------------------------------------- level 5
H = []
for z in range(3): H.append("0" * 12 + "ee" + "111" + "3")
H.append("..." + "444" + "......" + ".." + "111" + "3")
for z in range(2): H.append("..." + "333" + "ee" + "4444" + ".." + "111" + ".")
for z in range(6): H.append("..." + "333" + "444444" + ".." + "111" + ".")
for z in range(2): H.append("..." + "333" + "." * 8 + "sss" + ".")
for z in range(3): H.append(".." + "4" + "3333" + "." + "ww" + "2" * 7 + ".")
H.append("." * 10 + "3" * 7 + ".")
O = {(1, 1): "S", (4, 1): ">", (0, 0): "l", (0, 2): "t", (10, 2): "b",
     (15, 3): "C", (14, 6): "X", (14, 9): "x", (16, 11): "B", (12, 15): "<", (16, 16): "l",
     (4, 13): "C", (3, 10): "X", (3, 7): "x",
     (8, 6): "B", (7, 8): "x", (11, 9): "B", (9, 10): "G", (6, 10): "H", (6, 11): "t", (11, 11): "b"}
put(O, (15, 16), 6, "-"); put(O, (15, 16), 9, "-")
put(O, (4, 5), 10, "-"); put(O, (4, 5), 7, "-")
put(O, (8, 9, 10), 8, "-")
level(5, "Candy Castle", "Finale: loop start, climb the east wall past sweepers, kicker over the moat, up the castle to the hole.",
      42, H, O, ['{type = "loop", tile = Vector2(7, 1), yaw = 90.0}',
                 '{type = "hoop", tile = Vector2(7, 15), height = 2.9, yaw = 90.0}'],
      [(1, 1), (4, 1), (6, 1), (8.5, 0), (10, 0), (13, 0.5), (15, 1), (15, 3), (15, 11), (15, 13),
       (15, 15), (12, 15), (9, 15), (5, 15), (4, 15), (4, 13), (4, 5), (5, 4.6), (7.5, 4.6), (8.5, 5.2),
       (9, 7), (9, 9), (9, 10)], 18)

# ---------------------------------------------------------------- level 6
cv = canvas(22, 22)
rect(cv, 1, 1, 4, 4, "3"); rect(cv, 5, 2, 6, 3, "w")
rect(cv, 7, 0, 19, 0, "1"); rect(cv, 7, 12, 19, 12, "1"); rect(cv, 19, 0, 19, 12, "1")
rect(cv, 7, 1, 7, 11, "1"); rect(cv, 7, 2, 7, 3, "0")
rect(cv, 8, 1, 18, 11, "0")
rect(cv, 6, 14, 17, 21, "2"); rect(cv, 7, 14, 16, 20, "1")
rect(cv, 6, 14, 17, 14, "1")
H = ["".join(r) for r in cv]
O = {(2, 2): "S", (1, 1): "l", (4, 4): "b", (1, 4): "t", (11, 1): "#", (12, 1): "#", (13, 1): "#", (14, 1): "#",
     (12, 5): "B", (14, 5): "B", (13, 7): "B",
     (16, 9): "@", (15, 9): "@", (14, 9): "@",
     (14, 18): "G", (10, 19): "B", (7, 20): "t", (16, 16): "l", (7, 16): "b"}
level(6, "Pinball Parlor", "Speed run: a pinball table with targets, bumpers, speed banks, a spinner, rollovers, and a cannon over the void.",
      22, H, O, ['{type = "redirect", tile = Vector2(18, 2), yaw = 0.0, strength = 9.0}',
                 '{type = "spinner", tile = Vector2(18, 5), yaw = 0.0}',
                 '{type = "redirect", tile = Vector2(18, 9), yaw = -90.0, strength = 8.0}',
                 '{type = "slingshot", tile = Vector2(9, 9), yaw = 90.0}',
                 '{type = "slingshot", tile = Vector2(17, 11), yaw = -90.0}',
                 '{type = "cannon", tile = Vector2(12, 9), target_tile = Vector2(11, 16)}',
                 '{type = "hoop", tile = Vector2(11.5, 12.5), height = 4.0, yaw = 0.0}'],
      [(2, 2.5), (4, 2.5), (8, 2.5), (12, 2.5), (17, 2.5), (18, 2), (18, 5), (18, 8), (18, 9), (16, 9),
       (14, 9), (12, 9), (11, 16), (13, 17), (14, 18)], 22)

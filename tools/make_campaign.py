"""The 10-level campaign: writes scripts/levels/level_1.gd .. level_10.gd.
Run: python3 tools/make_campaign.py
Check: godot --headless --fixed-fps 120 -s tests/levels_test.gd

Every level has its own shape and one signature idea (see LEVELS at the
bottom). Corridors come from the course stitcher (tools/course.py); the wide
set pieces here (arenas, forks, swamps, pinball tables, islands) use `zoff`
so they can grow sideways around the 4-tile connecting lane.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from course import Course, Piece  # noqa: E402
import genlevels as g  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts", "levels")

THEMES = {
    "candy": (["#A8E6C8", "#C9B8EC", "#BFE3F7", "#F9C6D3", "#FFE7B3"], "#F6E27A", "#5A3426"),
    "meadow": (["#BFEFC9", "#A8E6C8", "#DDF5C8", "#C6F0DC", "#FFF1A8"], "#F7B2C0", "#6B3E1F"),
    "waffle": (["#F3D2A2", "#E8B77A", "#F7E0BF", "#DDA46A", "#FBEBD2"], "#F6E27A", "#6B3E1F"),
    "licorice": (["#F9C6D3", "#C9B8EC", "#FBD9E4", "#BFE3F7", "#FDE6EE"], "#F6E27A", "#2B2438"),
    "sky": (["#BFE3F7", "#D6E4FB", "#C9B8EC", "#A9D6F5", "#FFF4E0"], "#F7B2C0", "#8A3553"),
    "bakery": (["#FBEBD2", "#F3D2A2", "#F9C6D3", "#E8B77A", "#FFF4E0"], "#F7B2C0", "#5A3426"),
    "swamp": (["#BFF0D8", "#8FD9B6", "#D9F5E6", "#A8E6C8", "#C6F0DC"], "#E8B77A", "#3E2418"),
    "pinball": (["#C9B8EC", "#B4A7E8", "#F9C6D3", "#A9C1F0", "#FFE7B3"], "#F6E27A", "#2E2350"),
    "coaster": (["#FFE7B3", "#F9C6D3", "#BFE3F7", "#A8E6C8", "#C9B8EC"], "#F6845E", "#8A3553"),
    "summit": (["#FDE6EE", "#F9C6D3", "#FBD9E4", "#F7B2C0", "#FFF4E0"], "#F6E27A", "#5A3426"),
}


# --- piece helpers ------------------------------------------------------------------

_ch = [0]


def channel(tag):
    _ch[0] += 1
    return "%s%d" % (tag, _ch[0])

def gridh(W, H, fill="."):
    return [[fill] * W for _ in range(H)]


def rows(gr):
    return ["".join(r) for r in gr]


def zpiece(h, o, zoff, **kw):
    """Piece whose connecting lane is rows zoff+1..zoff+4 (it can be wider)."""
    p = Piece(rows(h), rows(o), **kw)
    p.zoff = zoff
    return p


def arena(W, H, zoff, paint, name, entry=0, exit=None, extras=(), route=()):
    """Wide area: `paint(h, o)` fills the inside (x 1..W-2, z 1..H-2) with
    relative tiers; the border becomes a rail one step above whatever it
    touches, except where the 4-tile lane comes in (x 0) and goes out (x W-1)."""
    exit = entry if exit is None else exit
    h, o = gridh(W, H), gridh(W, H)
    paint(h, o)
    lane = range(zoff + 1, zoff + 5)
    for z in lane:
        h[z][0] = str(entry)
        h[z][W - 1] = str(exit)
    top = 0
    for r in h:
        for c in r:
            if c.isdigit():
                top = max(top, int(c))
    base = [r[:] for r in h]   # rails look at the ground only, not at other rails
    for z in range(H):
        for x in range(W):
            if base[z][x] != ".":
                continue
            near = []
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    xx, zz = x + dx, z + dz
                    if 0 <= xx < W and 0 <= zz < H and base[zz][xx] not in ".#":
                        near.append(base[zz][xx])
            if not near or (0 < x < W - 1 and 0 < z < H - 1):
                continue
            if all(c.isdigit() for c in near):
                h[z][x] = str(max(int(c) for c in near) + 1)
            else:
                h[z][x] = str(top + 1)
    for z in range(H):
        for x in range(W):
            if h[z][x] == "#":
                h[z][x] = "."
    return zpiece(h, o, zoff, entry=entry, exit=exit, extras=list(extras), route=list(route), name=name)


def fill(h, x0, z0, x1, z1, c):
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            h[z][x] = str(c)


# --- new pieces ----------------------------------------------------------------------

def wide_slope(W=9, tiers=2, H=10, zoff=2):
    """A wide, gentle hillside dropping `tiers` steps."""
    def paint(h, o):
        fill(h, 1, 1, 1, H - 2, tiers)
        fill(h, 2, 1, W - 3, H - 2, "w")
        fill(h, W - 2, 1, W - 2, H - 2, 0)
        o[2][4], o[H - 3][6] = "l", "t"
    return arena(W, H, zoff, paint, "wide_slope", entry=tiers, exit=0,
                 route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)])


def meadow(W=12, H=10, zoff=2):
    """Open field of waves and round hills with candy around."""
    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for x in range(3, W - 3):
            for z in range(2, H - 2):
                o[z][x] = "W"
        o[2][2], o[H - 3][W - 3] = "H", "H"
        o[1][5], o[H - 2][3], o[1][W - 3] = "g", "b", "%"
    return arena(W, H, zoff, paint, "meadow", route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)])


def bumper_bowl(W=12, H=10, zoff=2):
    """Round-ish bowl with a ring of pop bumpers and three rollover stars."""
    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for (x, z) in [(1, 1), (W - 2, 1), (1, H - 2), (W - 2, H - 2)]:
            h[z][x] = "1"
        for (x, z) in [(4, 3), (7, 2), (7, 7), (4, 6), (9, 4)]:
            o[z][x] = "B"
        for x in (5, 6, 7):
            o[zoff + 3][x] = "@"
    return arena(W, H, zoff, paint, "bumper_bowl",
                 route=[(0, zoff + 2.5), (2.5, zoff + 2.5), (6, zoff + 3.5), (W - 1, zoff + 2.5)])


def fork(W=16, variant=0):
    """The lane splits around a pit: one side fast but guarded, the other
    safe but bumpy. `variant` swaps which side is which."""
    H, zoff = 14, 4
    fast_rows = (1, 4) if variant == 0 else (9, 12)
    slow_rows = (9, 12) if variant == 0 else (1, 4)
    extras = []

    def paint(h, o):
        fill(h, 1, 1, 3, H - 2, 0)
        fill(h, W - 4, 1, W - 2, H - 2, 0)
        fill(h, 4, fast_rows[0], W - 5, fast_rows[1], 0)
        fill(h, 4, slow_rows[0], W - 5, slow_rows[1], 0)
        for x in range(4, W - 4):
            for z in range(zoff + 1, zoff + 5):
                h[z][x] = "#"
        for x in range(5, W - 5):
            for z in range(slow_rows[0], slow_rows[1] + 1):
                o[z][x] = "W"
        o[slow_rows[0] + 1][7] = o[slow_rows[1] - 1][10] = "B"
        o[fast_rows[0] + 1][4] = o[fast_rows[0] + 2][4] = ">"
        o[zoff + 2][2] = "t"
    for k, x in enumerate((7, 10)):
        extras.append({"type": "enemy", "tile": (x, fast_rows[0]), "travel_tiles": (0, 3),
                       "period": 2.4 if k == 0 else 2.0, "phase": 0.5 * k})
    ch = channel("fork")
    extras.append({"type": "switch", "tile": (8.5, fast_rows[0] + 1.5), "channel": ch})
    extras.append({"type": "gate", "tile": (W - 2, zoff + 2.5), "yaw": 0.0, "channel": ch, "size": (1, 4)})
    fz = fast_rows[0] + 1.5
    return arena(W, H, zoff, paint, "fork", extras=extras,
                 route=[(0, zoff + 2.5), (2, zoff + 2.5), (3, fz), (W - 4, fz), (W - 3, zoff + 2.5), (W - 1, zoff + 2.5)])


def switch_gap():
    """A gap you can't cross until you press the button in the side alcove
    (past a sweeper). Then a bridge rises."""
    W, H, zoff = 13, 11, 3
    ch = channel("gap")

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for x in (6, 7):
            for z in range(1, H - 1):
                h[z][x] = "#"
        # alcove (rows 1-2) walled off from the lane, way in at x 4
        for x in range(1, 4):
            h[3][x] = "1"
        o[H - 2][1] = "l"
    extras = [
        {"type": "switch", "tile": (1.5, 1.5), "channel": ch},
        {"type": "gate", "tile": (6.5, zoff + 2.5), "yaw": 0.0, "channel": ch, "size": (2, 4), "bridge": True,
         "y_tier": 0},
        {"type": "enemy", "tile": (10, zoff + 1), "travel_tiles": (0, 3), "period": 3.2},
    ]
    return arena(W, H, zoff, paint, "switch_gap", extras=extras,
                 route=[(0, zoff + 2.5), (2, zoff + 2.5), (4.5, zoff + 1), (4.5, 1.5), (1.5, 1.5), (4.5, 1.5),
                        (4.5, zoff + 2.5), (8.5, zoff + 2.5), (W - 1, zoff + 2.5)])


def beam(W=8):
    """Balance beam: two tiles wide, no rails."""
    h, o = g.lane(W), g.grid(W)
    for x in range(1, W - 1):
        for z in (0, 1, 4, 5):
            h[z][x] = "."
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="beam")


def hump_bridge(W=9):
    """Four tiles wide, no rails, big smooth humps (Marble Madness bridge)."""
    h, o = g.lane(W), g.grid(W)
    for x in range(1, W - 1):
        h[0][x] = h[5][x] = "."
        for z in range(1, 5):
            o[z][x] = "M"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="hump_bridge")


def boost_strip(W=6):
    h, o = g.lane(W), g.grid(W)
    for z in (2, 3):
        o[z][1] = ">"
    g.rail_decor(o, W, 3)
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="boost_strip")


def big_press(timed=9.0):
    """The bakery press: a 3x3 grid of stompers in a rolling wave, a sweeper
    running along each side lane."""
    W, H, zoff = 13, 10, 2
    extras = []
    for i, x in enumerate((3.5, 6.5, 9.5)):
        for j, z in enumerate((2.5, 4.5, 6.5)):
            extras.append({"type": "stomper", "tile": (x, z), "period": 3.0, "phase": round(((i + j) % 3) / 3.0, 2)})

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        o[1][1], o[H - 2][W - 2] = "l", "t"
    if timed:
        ch = channel("press")
        extras.append({"type": "switch", "tile": (1.5, zoff + 2.5), "channel": ch, "open_time": timed})
        extras.append({"type": "gate", "tile": (W - 1, zoff + 2.5), "yaw": 0.0, "channel": ch, "size": (1, 4)})
    return arena(W, H, zoff, paint, "big_press", extras=extras,
                 route=[(0, zoff + 2.5), (2, 4.5), (11, 4.5), (W - 1, zoff + 2.5)])


def goo_planks(variant=0):
    """Raised 3-wide planks in a U over a sour goo pool (P = plank, . = goo)."""
    W, H, zoff = 16, 12, 3
    art = ["...PPPPPPPP...",
           "...PPPPPPPP...",
           "...PPPPPPPP...",
           "PPPPPP..PPPPPP",
           "PPPPPP..PPPPPP",
           "PPPPPP..PPPPPP",
           "PPPPPP..PPPPPP",
           "..............",
           "..............",
           ".............."]

    def paint(h, o):
        for j, line in enumerate(art):
            z = 1 + j if not variant else H - 2 - j
            for i, ch in enumerate(line):
                x = 1 + i
                if ch == "P":
                    h[z][x] = "1"
                else:
                    h[z][x] = "0"
                    o[z][x] = "A"
    pts = [(0, 5.5), (5, 5.5), (5, 2), (10, 2), (10, 5.5), (W - 1, 5.5)]
    if variant:
        pts = [(x, H - 1 - z) for (x, z) in pts]
    return arena(W, H, zoff, paint, "goo_planks", entry=1, exit=1, route=pts)


def pinball_arena():
    """Big pinball table: star rollovers, a bumper cluster, slingshots, a
    bank of drop targets and a turner at the far end."""
    W, H, zoff = 16, 14, 4

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for x in (3, 4, 5):
            o[zoff + 2][x] = "@"
        for (x, z) in [(7, 3), (9, 2), (11, 3), (8, 10), (10, 11), (12, 10), (10, 6)]:
            o[z][x] = "B"
        for z in (2, 3, 10, 11):
            o[z][W - 2] = "#"
        o[1][1], o[H - 2][1] = "h", "h"
    return arena(W, H, zoff, paint, "pinball_arena", extras=[
        {"type": "slingshot", "tile": (6, 1), "yaw": 0.0},
        {"type": "slingshot", "tile": (6, H - 2), "yaw": 180.0},
        {"type": "spinner", "tile": (13, zoff + 2), "yaw": 90.0},
        {"type": "spinner", "tile": (13, zoff + 3), "yaw": 90.0},
    ], route=[(0, zoff + 2.5), (6, zoff + 2.5), (8, zoff + 4), (12, zoff + 4), (W - 1, zoff + 2.5)])


def island(W=8, decor="", name="island"):
    """Small floating island with a candy garden."""
    H, zoff = 10, 2

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        spots = [(2, 1), (W - 3, 1), (2, H - 2), (W - 3, H - 2), (1, 5), (W - 2, 4)]
        for k, ch in enumerate(decor):
            x, z = spots[k % len(spots)]
            o[z][x] = ch
    return arena(W, H, zoff, paint, name, route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)])


def heart_island():
    """Easter egg: a heart drawn in heart candies."""
    W, H, zoff = 13, 12, 3
    heart = ["..hh...hh..",
             ".h..h.h..h.",
             ".h...h...h.",
             "..h.....h..",
             "...h...h...",
             "....h.h....",
             ".....h....."]

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for j, line in enumerate(heart):
            for i, ch in enumerate(line):
                if ch == "h":
                    o[2 + j][1 + i] = "h"
        # keep the lane through the middle free
        for x in range(1, W - 1):
            for z in range(zoff + 1, zoff + 5):
                if o[z][x] == "h" and z in (zoff + 2, zoff + 3):
                    o[z][x] = "."
    return arena(W, H, zoff, paint, "heart_island", route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)])


def pinball_machine(name="pinball_machine", lock=True):
    """A real pinball layout, laid lengthwise: you come in at the flipper end.
      - apron with two flippers that bat you up the table, a centre drain
        between them and an outlane drain on the far side
      - slingshots above the flippers
      - the playfield tilts up towards the top (so you roll back down)
      - jet bumper triangle, a drop target bank, a spinner orbit lane
      - three rollover lanes at the top, split by posts
      - the plunger lane up the side: two boosters, the skill shot to the top
    Exit at the top. Entry tier 0, exit tier 2."""
    W, H, zoff = 20, 16, 5
    extras = [
        {"type": "flipper", "tile": (5, 5), "yaw": 70.0, "strength": 14.0},
        {"type": "flipper", "tile": (5, 10), "yaw": 110.0, "strength": 14.0},
        {"type": "slingshot", "tile": (7, 4), "yaw": 60.0},
        {"type": "slingshot", "tile": (7, 11), "yaw": 120.0},
        {"type": "spinner", "tile": (11, 1.5), "yaw": 90.0},
        {"type": "hoop", "tile": (15, 1.5), "yaw": 90.0, "rise": 1.9, "base": 1},
    ]

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        # tilt: ramp up from x 8 to 16, top flat at tier 2
        for z in range(1, H - 1):
            for x in range(8, 17):
                h[z][x] = "e"
            for x in (17, 18):
                h[z][x] = "2"
        # centre drain between the flippers, outlane drain on the orbit side
        for (x, z) in [(5, 7), (6, 7), (5, 8), (6, 8), (4, 1), (5, 1), (6, 1), (7, 1), (4, 2), (5, 2), (6, 2), (7, 2)]:
            h[z][x] = "#"
        # a low rail in front of the drain: you come in over a flipper
        for z in range(zoff + 1, zoff + 5):
            h[z][3] = "1"
        # orbit lane (rows 1-2) walled off from the playfield by row 3
        for x in range(8, 16):
            h[3][x] = "3"
        # plunger lane (rows 13-14), wall on row 12
        for x in range(2, 16):
            h[12][x] = "3"
        o[13][2] = o[14][2] = ">"
        o[13][7] = o[14][7] = ">"
        # jet bumper triangle and drop target bank
        for (x, z) in [(13, 6), (13, 9), (11, 7)]:
            o[z][x] = "B"
        for x in (9, 10, 11):
            o[11][x] = "#"
        # top rollover lanes: posts between three stars
        for z in (6, 9):
            h[z][17] = "3"
        for z in (5, 7, 10):
            o[z][17] = "@"
        o[1][17] = o[H - 2][18] = "%"
    route = [(0, zoff + 2.5), (1.5, zoff + 2.5), (1.5, 13.5), (4, 13.5), (16, 13.5), (17.5, 12), (18, zoff + 3),
             (W - 1, zoff + 2.5)]
    if lock:
        # The exit is locked until the drop target bank is down.
        extras.append({"type": "gate", "tile": (W - 1, zoff + 2.5), "yaw": 0.0, "channel": "targets", "size": (1, 4)})
        route = [(0, zoff + 2.5), (1.5, zoff + 2.5), (1.5, 13.5), (4, 13.5), (16, 13.5), (16.5, 11),
                 (13, 11), (8.5, 11), (8.5, 9.5), (12, 8), (16, 8), (18, zoff + 3), (W - 1, zoff + 2.5)]
    return arena(W, H, zoff, paint, name, entry=0, exit=2, extras=extras, route=route)


def maze(cols=5, rows=4, seed=1, goo=False, treats="%@g", zoff=None, name="maze", puzzle=True):
    """A real maze with dead ends (2-wide corridors). Walls are a step higher,
    or sour goo when `goo` is set. Dead ends hold treats."""
    import random
    rnd = random.Random(seed)
    W, H = 7 + 3 * cols, 3 * rows + 1
    if H < 6:
        H = 6
    if zoff is None:
        zoff = max(0, min(H - 6, (H - 6) // 2))
    lane = range(zoff + 1, zoff + 5)
    r_in = min(rows - 1, max(0, (zoff + 1) // 3))
    r_out = rows - 1 - r_in if rows > 1 else 0
    # carve a perfect maze (depth-first backtracker)
    seen = {(0, r_in)}
    stack = [(0, r_in)]
    open_e, open_s = set(), set()
    while stack:
        c, r = stack[-1]
        nb = [(c + dc, r + dr) for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1))
              if 0 <= c + dc < cols and 0 <= r + dr < rows and (c + dc, r + dr) not in seen]
        if not nb:
            stack.pop()
            continue
        n = rnd.choice(nb)
        if n[0] != c:
            open_e.add((min(c, n[0]), r))
        else:
            open_s.add((c, min(r, n[1])))
        seen.add(n)
        stack.append(n)

    def wall(h, o, x, z):
        if goo:
            h[z][x] = "0"
            o[z][x] = "A"
        else:
            h[z][x] = "1"

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for x in range(3, 4 + 3 * cols):
            for z in range(1, H - 1):
                if (x - 3) % 3 == 0 or z % 3 == 0:
                    wall(h, o, x, z)
        for (c, r) in open_e:
            for z in (1 + 3 * r, 2 + 3 * r):
                h[z][6 + 3 * c] = "0"
                o[z][6 + 3 * c] = "."
        for (c, r) in open_s:
            for x in (4 + 3 * c, 5 + 3 * c):
                h[3 * (r + 1)][x] = "0"
                o[3 * (r + 1)][x] = "."
        for z in (1 + 3 * r_in, 2 + 3 * r_in):
            h[z][3] = "0"
            o[z][3] = "."
        for z in (1 + 3 * r_out, 2 + 3 * r_out):
            h[z][3 + 3 * cols] = "0"
            o[z][3 + 3 * cols] = "."
        # treats in dead ends
        k = 0
        for c in range(cols):
            for r in range(rows):
                links = sum([(c, r) in open_e, (c - 1, r) in open_e, (c, r) in open_s, (c, r - 1) in open_s])
                if links == 1 and (c, r) not in ((0, r_in), (cols - 1, r_out)) and treats:
                    o[1 + 3 * r][4 + 3 * c] = treats[k % len(treats)]
                    k += 1

    from collections import deque

    def links(c, r):
        out = []
        if (c, r) in open_e:
            out.append((c + 1, r))
        if (c - 1, r) in open_e:
            out.append((c - 1, r))
        if (c, r) in open_s:
            out.append((c, r + 1))
        if (c, r - 1) in open_s:
            out.append((c, r - 1))
        return out

    def bfs(a, b):
        prev = {a: None}
        q = deque([a])
        while q:
            n = q.popleft()
            for m in links(*n):
                if m not in prev:
                    prev[m] = n
                    q.append(m)
        path = [b]
        while prev[path[-1]] is not None:
            path.append(prev[path[-1]])
        return list(reversed(path)), prev

    start, goal = (0, r_in), (cols - 1, r_out)
    path, dist_from_start = bfs(start, goal)
    extras = []
    if puzzle:
        # The key (a switch) sits in the dead end farthest off the way out;
        # a gate locks the exit until it's pressed.
        on_path = set(path)
        best, best_d = None, -1
        for c in range(cols):
            for r in range(rows):
                if len(links(c, r)) == 1 and (c, r) not in on_path:
                    d = len(bfs(goal, (c, r))[0])
                    if d > best_d:
                        best, best_d = (c, r), d
        if best:
            ch = channel("maze")
            extras.append({"type": "switch", "tile": (4.5 + 3 * best[0], 1.5 + 3 * best[1]), "channel": ch})
            extras.append({"type": "gate", "tile": (3 + 3 * cols, 1.5 + 3 * r_out), "yaw": 0.0, "channel": ch,
                           "size": (1, 2)})
            to_key = bfs(start, best)[0]
            back = bfs(best, goal)[0]
            path = to_key + back[1:]
    mid = zoff + 2.5
    route = [(0, mid), (1.5, mid), (1.5, 1.5 + 3 * r_in)]
    route += [(4.5 + 3 * c, 1.5 + 3 * r) for (c, r) in path]
    route += [(4.5 + 3 * cols, 1.5 + 3 * r_out), (4.5 + 3 * cols, mid), (W - 1, mid)]
    return arena(W, H, zoff, paint, name, route=route, extras=extras)


# --- writer -----------------------------------------------------------------------------

def fmt(v):
    if isinstance(v, float):
        return "%.2f" % v
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


def write(num, c, title, desc, par, theme, race=False, step=0.5, break_drop=0, monster_tint="",
          rival_tint="", rival_speed=1.0, extra_cells=None, extra_extras=()):
    if extra_cells:
        for k, v in extra_cells.items():
            c.cells[k] = v
    for e in extra_extras:
        c.extras.append(e)
    hg, og, (sx, sz) = c.grids()
    tiers, ramp, wall = THEMES[theme]
    L = ["extends LevelBase", "## " + desc, "## Generated by tools/make_campaign.py, edit there.", "", "",
         "func _init() -> void:",
         '\ttitle = "%s"' % title,
         '\tdescription = "%s"' % desc,
         "\ttime_limit = %.1f" % par,
         "\tstep = %.2f" % step,
         "\tbreak_drop = %d" % break_drop,
         "\ttier_colors = [%s]" % ", ".join('Color("%s")' % t for t in tiers),
         '\tramp_color = Color("%s")' % ramp,
         '\twall_color = Color("%s")' % wall]
    if race:
        L.append("\trace = true")
        L.append("\trival_speed = %.2f" % rival_speed)
        if rival_tint:
            L.append('\trival_tint = Color("%s")' % rival_tint)
    if monster_tint:
        L.append('\tmonster_tint = Color("%s")' % monster_tint)
    L.append("\theights = [")
    L += ['\t\t"%s",' % "".join(r) for r in hg]
    L += ["\t]", "\tobjects = ["]
    L += ['\t\t"%s",' % "".join(r) for r in og]
    L += ["\t]", "\textras = ["]
    for e in c.extras:
        parts = []
        for k, v in e.items():
            if k in ("tile", "target_tile"):
                v = "Vector2(%s, %s)" % (v[0] + sx, v[1] + sz)
            elif k == "size":
                v = "Vector2(%s, %s)" % (v[0], v[1])
            elif k == "y":
                v = "%.2f" % (v * step / 0.5)
            elif k == "travel":
                v = "Vector3(%s, 0, %s)" % (v[0], v[1])
            elif k == "tint":
                v = 'Color("%s")' % v
            else:
                v = fmt(v)
            parts.append("%s = %s" % (k, v))
        L.append("\t\t{" + ", ".join(parts) + "},")
    L += ["\t]", "\troute = ["]
    for (x, z) in c.route:
        L.append("\t\tVector2(%s, %s)," % (x + sx, z + sz))
    L.append("\t]")
    with open(os.path.join(OUT, "level_%d.gd" % num), "w") as fh:
        fh.write("\n".join(L) + "\n")
    print("level %2d %-20s %dx%d tiles, tiers %d-%d" % (num, title, len(hg[0]), len(hg), c.min_tier, c.max_tier))


def run(c, plan):
    for step in plan:
        if isinstance(step, tuple) and step[0] == "turn":
            c.turn(step[1], bank=len(step) > 2)
        else:
            c.place(step)
    return c


T = lambda d, bank=False: ("turn", d, "bank") if bank else ("turn", d)  # noqa: E731


# --- the ten levels ------------------------------------------------------------------------

def level_1():
    c = run(Course(tier=8), [
        g.start(), g.straight(2), wide_slope(9, 2), maze(4, 3, 11), switch_gap(), T(+1), g.kicker(), g.straight(3),
        wide_slope(9, 3), g.checkpoint(), pinball_machine(), T(-1), g.sweepers(1), g.slope_down(1), g.finish(),
    ])
    write(1, c, "Sugar Hill", "Roll down the hill, find the key in the hedge maze, raise the bridge, beat the pinball table.",
          78, "meadow")


def level_2():
    c = run(Course(tier=3), [
        g.start(), g.straight(2), fork(16, 0), T(+1), g.straight(5), maze(5, 4, 21), g.checkpoint(), fork(16, 1), T(-1),
        g.kicker(), g.straight(2), g.finish(),
    ])
    write(2, c, "Gumdrop Fork", "The road splits twice: fast past the sweepers, or safe over the bumps.",
          60, "candy")


def level_3():
    c = run(Course(tier=8), [
        g.start(), g.straight(2), g.stairs(2), beam(8), T(+1), maze(4, 3, 31), hump_bridge(9), g.drop(), T(+1),
        g.slope_down(2, 5), g.hopper_lane(), g.checkpoint(), T(-1), g.stairs(2), g.river(), beam(6), T(-1),
        g.drop(), g.sweepers(2), g.finish(),
    ])
    write(3, c, "Waffle Falls", "Down the waffle cliffs: beams, hump bridges, steep drops. Falls break you.",
          68, "waffle", step=1.0, break_drop=2)


def level_4():
    c = run(Course(tier=4), [
        g.start(), boost_strip(), g.waves(6), T(+1, True), g.bumpers(), g.kicker(), T(+1, True), g.split(),
        g.checkpoint(), g.funnel(), T(-1, True), g.hills(), g.leap(1), boost_strip(), g.finish(),
    ])
    write(4, c, "Licorice Derby", "Race the licorice ball! Boost lanes, banked U-turns and a jump.",
          38, "licorice", race=True, rival_tint="#2b2438", rival_speed=1.1)


def level_5():
    c = Course(tier=3)
    c.place(g.start())
    run(c, [g.straight(2), g.kicker(), maze(4, 3, 51, treats="%$"), g.cannon_hop(), T(+1), island(8, "bh$r"),
            g.catapult_launch(), g.leap(1), heart_island(), g.checkpoint(), T(-1), g.kicker()])
    # Remember where the finish goes, for the secret cannon's aim.
    fin = c._world(3, 2.5)
    c.place(g.finish())
    # Easter egg: roll BACKWARDS off the start pad through a gap in its back rail,
    # down a hidden sugar bridge to a secret island with golden cupcakes, a
    # rollover star trio and a cannon that shoots you almost to the flag.
    cells = {}
    for z in (2, 3):
        cells[(0, z)] = ["3", "."]
    for x in range(-8, 0):
        for z in (2, 3):
            cells[(x, z)] = ["3", "."]
    for x in range(-17, -8):
        for z in range(-3, 9):
            edge = x in (-17,) or z in (-3, 8)
            cells[(x, z)] = ["3" if edge else "2", "."]
    for (x, z) in [(-15, -1), (-13, -1), (-11, -1), (-15, 6), (-13, 6), (-11, 6)]:
        cells[(x, z)] = ["2", "%"]
    for z in (1, 2, 3):
        cells[(-11, z)] = ["2", "@"]
    # The secret star greets you first; the cannon waits at the far end.
    extras = [
        {"type": "secret", "tile": (-10, 2.5)},
        {"type": "cannon", "tile": (-15, 2.5), "target_tile": fin, "hang": 3.4},
    ]
    write(5, c, "Sprinkle Islands", "Hop the floating islands by jump, cannon and catapult. Look around!",
          55, "sky", extra_cells=cells, extra_extras=extras)


def level_6():
    c = run(Course(tier=5), [
        g.start(), g.stomper_gate(), T(+1), big_press(), g.checkpoint(), maze(5, 3, 61), T(-1),
        g.windmill_plaza(), g.sweepers(3, "all"), g.checkpoint(), T(+1), g.drop(), g.sweepers(2, True), g.finish(),
    ])
    write(6, c, "Clockwork Bakery", "The candy factory: the big stomper press, hoppers, windmills. Keep the beat.",
          68, "bakery", monster_tint="#8cc9f0")


def level_7():
    c = run(Course(tier=4), [
        g.start(), g.ramp_up(), goo_planks(0), T(+1), g.straight(5), maze(5, 4, 71, goo=True, treats="%h"), hump_bridge(9),
        g.ghost_garden(), g.checkpoint(), T(-1), goo_planks(1), g.ramp_down(), g.river(), g.finish(),
    ])
    write(7, c, "Sour Swamp", "Stay on the planks! Sour goo, hump bridges and ghosts in the mist.",
          78, "swamp", monster_tint="#b99bea")


def level_8():
    c = run(Course(tier=4), [
        g.start(), pinball_machine(), T(+1, True), g.straight(6), pinball_arena(), g.checkpoint(), T(-1, True), g.stairs(2),
        pinball_machine("pinball_machine_2"), g.sweepers(3, "all"), g.finish(),
    ])
    write(8, c, "Pinball Wizard", "Two real pinball tables. Knock down the targets to unlock each exit.",
          66, "pinball")


def level_9():
    c = run(Course(tier=8), [
        g.start(), boost_strip(), g.loop(), T(+1, True), g.chute_drop(), switch_gap(), g.funnel(), g.kicker(), T(-1, True),
        g.loop(), g.leap(1), g.cannon_hop(), T(+1, True), g.slope_down(2), pinball_machine(), g.finish(),
    ])
    write(9, c, "Rollercoaster Ridge", "Full speed: loops, the candy chute, jumps and a cannon. Don't brake!",
          72, "coaster")


def level_10():
    c = run(Course(tier=0), [
        g.start(), g.ramp_up(), g.sweepers(2), T(+1), g.ramp_up(), g.windmill_plaza(), g.cannon_hop(), T(-1),
        hump_bridge(9), g.ramp_up(), g.stomper_gate(), g.checkpoint(), T(+1), g.catapult_launch(), g.kicker(),
        g.ramp_up(), T(-1), g.bumpers(), g.ramp_up(), g.finish(),
    ])
    write(10, c, "Candy Summit", "The final race, uphill all the way to the summit flag. Everything at once!",
          60, "summit", race=True, rival_tint="#2b2438", rival_speed=1.0)


LEVELS = [level_1, level_2, level_3, level_4, level_5, level_6, level_7, level_8, level_9, level_10]

if __name__ == "__main__":
    only = [int(a) for a in sys.argv[1:]]
    for k, f in enumerate(LEVELS):
        if not only or k + 1 in only:
            f()

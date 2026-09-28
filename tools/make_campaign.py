"""The 10-level campaign: writes scripts/levels/level_1.gd .. level_10.gd.
Run: python3 tools/make_campaign.py
Check: godot --headless --fixed-fps 120 -s tests/levels_test.gd

Ten levels in the spirit of the six Marble Madness races (Practice, Beginner,
Intermediate, Aerial, Silly, Ultimate) with candy on top. Most edges have no
rails: roll off and you're gone. Every set piece appears in one level only.
Corridors come from the course stitcher (tools/course.py), the basic track
pieces from tools/genlevels.py; the wide set pieces here use `zoff` so they
can grow sideways around the 4-tile connecting lane.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from course import Course, Piece  # noqa: E402
import genlevels as g  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts", "levels")

THEMES = {
    "meadow": (["#BFEFC9", "#A8E6C8", "#DDF5C8", "#C6F0DC", "#FFF1A8"], "#F7B2C0", "#6B3E1F"),
    "sky": (["#BFE3F7", "#D6E4FB", "#C9B8EC", "#A9D6F5", "#FFF4E0"], "#F7B2C0", "#2E2350"),
    "caramel": (["#F3D2A2", "#E8B77A", "#F7E0BF", "#DDA46A", "#FBEBD2"], "#F7B2C0", "#6B3E1F"),
    "licorice": (["#F9C6D3", "#C9B8EC", "#FBD9E4", "#BFE3F7", "#FDE6EE"], "#F6E27A", "#2B2438"),
    "space": (["#F6A55C", "#E8894A", "#FFC98A", "#D96C3D", "#FFE0B3"], "#A9D6F5", "#4A1F2B"),
    "bakery": (["#FBEBD2", "#F3D2A2", "#F9C6D3", "#E8B77A", "#FFF4E0"], "#F7B2C0", "#5A3426"),
    "swamp": (["#BFF0D8", "#8FD9B6", "#D9F5E6", "#A8E6C8", "#C6F0DC"], "#E8B77A", "#3E2418"),
    "pinball": (["#C9B8EC", "#B4A7E8", "#F9C6D3", "#A9C1F0", "#FFE7B3"], "#F6E27A", "#2E2350"),
    "bubblegum": (["#F9C6D3", "#F7B2C0", "#FBD9E4", "#F4A3BA", "#FDE6EE"], "#A9D6F5", "#8A3553"),
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


def wide(w):
    """Grid height and zoff for a lane `w` tiles wide with a spare row each side."""
    return w + 2, (w - 4) // 2


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


# --- connecting pieces (used everywhere) -------------------------------------------------

def ledge(W=6, w=4, decor=""):
    """Open straight, no rails: roll off the side and you're gone."""
    h, o = gridh(W, 6), gridh(W, 6)
    lo = 1 + (4 - w) // 2
    fill(h, 0, lo, W - 1, lo + w - 1, 0)
    for k, ch in enumerate(decor):
        o[lo + (k % w)][1 + (3 * k) % max(1, W - 2)] = ch
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="ledge")


def steep(n=1, dt=2, w=4, rails=False):
    """A steep drop: `dt` tiers over `n` ramp tiles. One tile for two tiers is
    the grated ramps of the Intermediate Race; six for four is the Beginner
    Race's long straight ramp (no rails there!)."""
    W = n + 2
    h = gridh(W, 6)
    lo = 1 + (4 - w) // 2
    for z in range(lo, lo + w):
        h[z][0] = str(dt)
        for x in range(1, n + 1):
            h[z][x] = "w"
        h[z][W - 1] = "0"
    if rails:
        for x in range(W):
            h[lo - 1][x] = h[lo + w][x] = str(dt + 1)
    return Piece(rows(h), entry=dt, exit=0, route=[(0, 2.5), (W - 1, 2.5)], name="steep")


def step_down(dt=1, w=2, W=4):
    """A ledge with a cliff edge halfway: drop `dt` tiers and roll on."""
    h = gridh(W, 6)
    lo = 1 + (4 - w) // 2
    for z in range(lo, lo + w):
        for x in range(W):
            h[z][x] = str(dt) if x < W // 2 else "0"
    return Piece(rows(h), entry=dt, exit=0, route=[(0, 2.5), (W - 1, 2.5)], name="step_down")


def boost_strip(W=6):
    h, o = g.lane(W), g.grid(W)
    for z in (2, 3):
        o[z][1] = ">"
    g.rail_decor(o, W, 3)
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="boost_strip")


# --- 1. Practice Race ----------------------------------------------------------------------

def hillside(stripes=3, w=8, drop=1):
    """The Practice Race hillside: wide rolling ground, a ramp stripe then a
    flat, over and over, no rails. The tier colours make the stripes."""
    W = 1 + 3 * stripes
    H, zoff = wide(w)
    h, o = gridh(W, H), gridh(W, H)
    for x in range(W):
        k, sub = (x - 1) // 3, (x - 1) % 3
        for z in range(1, w + 1):
            if x == 0:
                h[z][x] = str(stripes * drop)
            elif sub == 0:
                h[z][x] = "w"
            else:
                h[z][x] = str((stripes - 1 - k) * drop)
    o[1][2], o[w][W - 2] = "l", "t"
    return zpiece(h, o, zoff, entry=stripes * drop, exit=0,
                  route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)], name="hillside")


def pyramid_pinch(W=12):
    """Candy pyramids either side squeeze the lane to two tiles."""
    h, o = g.lane(W), g.grid(W)
    for x in range(3, W - 3):
        if x % 2 == 1:
            o[1][x] = "H"
        else:
            o[4][x] = "H"
    o[0][2], o[5][W - 3] = "g", "%"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="pyramid_pinch")


def diag_finish(drop=2):
    """A wide square where the ground slopes straight down the screen (a band
    of diagonal ramp tiles) to the hole in the far corner. No rails."""
    W, H, zoff = 16, 12, 2
    h, o = gridh(W, H), gridh(W, H)
    c0 = zoff + 6
    for z in range(H):
        for x in range(W):
            s = x + z
            h[z][x] = str(drop) if s < c0 else ("a" if s < c0 + 4 else "0")
    o[H - 3][W - 3] = "G"
    o[1][W - 2], o[H - 2][1], o[H - 2][W - 2] = "t", "l", "%"
    o[2][2], o[H - 4][W - 6] = "b", "g"
    return zpiece(h, o, zoff, entry=drop, exit=0,
                  route=[(0, zoff + 2.5), (3, zoff + 2.5), (6, zoff + 3.5), (9, 6.5), (W - 3, H - 3)],
                  name="diag_finish")


# --- 2. Beginner Race ----------------------------------------------------------------------

def pillar_field(W=16, w=8):
    """A walled plateau of candy pillars to weave through, with the black
    steelie waiting in the corner."""
    H, zoff = wide(w)
    spots = [(3, 1), (3, 2), (6, 6), (6, 7), (9, 1), (10, 1), (12, 5), (12, 6), (5, 8), (13, 8), (8, 4), (9, 7), (4, 5)]

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for (x, z) in spots:
            if z in (zoff + 2, zoff + 3):
                z += 2
            h[z][x] = "1"
        o[1][1], o[H - 2][W - 3] = "l", "t"
    extras = [{"type": "steelie", "tile": (W - 3, 1), "sense": 9.0, "leash": 14.0, "speed": 3.8}]
    return arena(W, H, zoff, paint, "pillar_field", extras=extras,
                 route=[(0, zoff + 2.5), (2, zoff + 2.5), (7, zoff + 1.5), (11, zoff + 3), (W - 1, zoff + 2.5)])


def pipe_hop(gap=6):
    """A candy pipe sucks you in and spits you out across the void."""
    W = gap + 6
    h, o = gridh(W, 6), gridh(W, 6)
    for x in list(range(3)) + list(range(W - 3, W)):
        h[0][x] = h[5][x] = "1"
        for z in range(1, 5):
            h[z][x] = "0"
    o[0][1], o[5][W - 2] = "g", "l"
    return Piece(rows(h), rows(o), extras=[{"type": "pipe", "tile": (1.5, 2.5), "target_tile": (W - 2, 2.5), "speed": 6.0}],
                 route=[(0, 2.5), (1.5, 2.5), (W - 2, 2.5), (W - 1, 2.5)], name="pipe_hop")


def wave_slide(n=8, dt=2, w=6):
    """The blue wave: a rippled slope down to the finish."""
    W = n + 2
    H, zoff = wide(w)
    h, o = gridh(W, H), gridh(W, H)
    for z in range(1, w + 1):
        h[z][0] = str(dt)
        h[z][W - 1] = "0"
        for x in range(1, W - 1):
            h[z][x] = "w"
            o[z][x] = "W"
    for x in range(W):
        h[0][x] = h[H - 1][x] = str(dt + 1)
    return zpiece(h, o, zoff, entry=dt, exit=0, route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)], name="wave_slide")


# --- 3. Intermediate Race ---------------------------------------------------------------------

def walkway_maze(cols=5, rows_=4, seed=1, treats="%g"):
    """A maze of raised walkways over nothing: the walls are the drop. The key
    (a switch) sits in the dead end farthest from the way out."""
    import random
    from collections import deque
    rnd = random.Random(seed)
    W, H = 7 + 3 * cols, max(6, 3 * rows_ + 1)
    zoff = max(0, (H - 6) // 2)
    r_in = min(rows_ - 1, max(0, (zoff + 1) // 3))
    r_out = rows_ - 1 - r_in if rows_ > 1 else 0
    seen = {(0, r_in)}
    stack = [(0, r_in)]
    open_e, open_s = set(), set()
    while stack:
        c, r = stack[-1]
        nb = [(c + dc, r + dr) for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1))
              if 0 <= c + dc < cols and 0 <= r + dr < rows_ and (c + dc, r + dr) not in seen]
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
        return list(reversed(path))

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for x in range(3, 4 + 3 * cols):
            for z in range(1, H - 1):
                if (x - 3) % 3 == 0 or z % 3 == 0:
                    h[z][x] = "#"
        for (c, r) in open_e:
            for z in (1 + 3 * r, 2 + 3 * r):
                h[z][6 + 3 * c] = "0"
        for (c, r) in open_s:
            for x in (4 + 3 * c, 5 + 3 * c):
                h[3 * (r + 1)][x] = "0"
        for z in (1 + 3 * r_in, 2 + 3 * r_in):
            h[z][3] = "0"
        for z in (1 + 3 * r_out, 2 + 3 * r_out):
            h[z][3 + 3 * cols] = "0"
        k = 0
        for c in range(cols):
            for r in range(rows_):
                if len(links(c, r)) == 1 and (c, r) not in ((0, r_in), (cols - 1, r_out)):
                    o[1 + 3 * r][4 + 3 * c] = treats[k % len(treats)]
                    k += 1

    start, goal = (0, r_in), (cols - 1, r_out)
    path = bfs(start, goal)
    on_path = set(path)
    best, best_d = None, -1
    for c in range(cols):
        for r in range(rows_):
            if len(links(c, r)) == 1 and (c, r) not in on_path:
                d = len(bfs(goal, (c, r)))
                if d > best_d:
                    best, best_d = (c, r), d
    extras = []
    if best:
        ch = channel("maze")
        extras.append({"type": "switch", "tile": (4.5 + 3 * best[0], 1.5 + 3 * best[1]), "channel": ch})
        extras.append({"type": "gate", "tile": (3 + 3 * cols, 1.5 + 3 * r_out), "yaw": 0.0, "channel": ch, "size": (1, 2)})
        path = bfs(start, best) + bfs(best, goal)[1:]
    mid = zoff + 2.5
    route = [(0, mid), (1.5, mid), (1.5, 1.5 + 3 * r_in)]
    route += [(4.5 + 3 * c, 1.5 + 3 * r) for (c, r) in path]
    route += [(4.5 + 3 * cols, 1.5 + 3 * r_out), (4.5 + 3 * cols, mid), (W - 1, mid)]
    return arena(W, H, zoff, paint, "walkway_maze", route=route, extras=extras)


def hump_bridge(W=9):
    """Four tiles wide, no rails, big smooth humps (the green roller bridges)."""
    h, o = g.lane(W), g.grid(W)
    for x in range(1, W - 1):
        h[0][x] = h[5][x] = "."
        for z in range(1, 5):
            o[z][x] = "M"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="hump_bridge")


def slime_ledge(W=12):
    """Acid slime blobs patrol an open ledge: they melt the marble."""
    h, o = gridh(W, 6), gridh(W, 6)
    fill(h, 0, 1, W - 1, 4, 0)
    o[1][W - 2] = "%"
    return Piece(rows(h), rows(o), extras=[
        {"type": "slime", "tile": (3, 1), "travel_tiles": (0, 3), "period": 4.0},
        {"type": "slime", "tile": (8, 4), "travel_tiles": (0, -3), "period": 4.6, "phase": 0.5},
    ], route=[(0, 2.5), (W - 1, 2.5)], name="slime_ledge")


# --- 4. Aerial Race ---------------------------------------------------------------------------

def halfpipe(W=12, w=6):
    """A banked corridor: the sides curve up two steps, ride them round."""
    H, zoff = wide(w)
    h, o = gridh(W, H), gridh(W, H)
    for x in range(W):
        h[0][x] = h[H - 1][x] = "2"
        h[1][x] = "n"
        h[H - 2][x] = "s"
        for z in range(2, H - 2):
            h[z][x] = "0"
    o[0][3], o[H - 1][W - 4] = "l", "t"
    return zpiece(h, o, zoff, route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)], name="halfpipe")


def chute_drop():
    """Candy chute slide four tiers down over a void."""
    W = 8
    h, o = gridh(W, 6), gridh(W, 6)
    for x in (0, 1):
        h[0][x] = h[5][x] = "5"
        for z in range(1, 5):
            h[z][x] = "4"
    h[1][1] = h[4][1] = "5"          # squeeze towards the chute mouth
    for x in (6, 7):
        h[0][x] = h[5][x] = "1"
        for z in range(1, 5):
            h[z][x] = "0"
    o[0][0], o[5][7] = "t", "l"
    return Piece(rows(h), rows(o), entry=4, exit=0,
                 extras=[{"type": "chute", "tile": (3.5, 2.5), "yaw": 90.0, "y_tier": 0}],
                 route=[(0, 2.5), (1.2, 2.5), (6.2, 2.5), (7, 2.5)], name="chute")


# --- 5. the islands -----------------------------------------------------------------------------

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


# --- 6. the works -----------------------------------------------------------------------------

def big_press(timed=9.0):
    """The bakery press: a 3x3 grid of stompers in a rolling wave; the gate at
    the far end only stays open for a few seconds after the button."""
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


# --- 7. the gorge -----------------------------------------------------------------------------

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


def slime_flats(W=16, w=8):
    """A wide floor dotted with goo pools where slime blobs cross the way."""
    H, zoff = wide(w)

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for (x, z) in [(3, 1), (4, 1), (7, H - 2), (8, H - 2), (11, 1), (12, 2), (6, 4), (13, H - 3), (9, 7)]:
            if z not in (zoff + 2, zoff + 3):
                o[z][x] = "A"
        o[1][W - 2], o[H - 2][1] = "%", "h"
    extras = [
        {"type": "slime", "tile": (4, zoff + 1), "travel_tiles": (0, 3), "period": 4.2},
        {"type": "slime", "tile": (9, zoff + 4), "travel_tiles": (0, -3), "period": 3.8, "phase": 0.5},
        {"type": "slime", "tile": (12, 1), "travel_tiles": (0, 6), "period": 6.0, "phase": 0.25},
    ]
    return arena(W, H, zoff, paint, "slime_flats", extras=extras,
                 route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)])


def goo_beams(W=12):
    """A two-tile beam across a sour lake one step below."""
    h, o = gridh(W, 6), gridh(W, 6)
    fill(h, 0, 0, W - 1, 5, 0)
    for z in range(6):
        for x in range(W):
            o[z][x] = "A"
    fill(h, 0, 2, W - 1, 3, 1)
    for z in (2, 3):
        for x in range(W):
            o[z][x] = "."
    o[0][W - 2] = "%"
    return Piece(rows(h), rows(o), entry=1, exit=1, route=[(0, 2.5), (W - 1, 2.5)], name="goo_beams")


# --- 8. the pinball peaks ----------------------------------------------------------------------

def pyramid_field(W=16, w=8):
    """Candy pyramids and pop bumpers on an open field, stars down the middle."""
    H, zoff = wide(w)

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for (x, z) in [(3, 1), (6, H - 2), (9, 1), (12, H - 2), (5, H - 3), (11, 2), (14, 4)]:
            if z not in (zoff + 2, zoff + 3):
                o[z][x] = "H"
        for (x, z) in [(4, zoff + 1), (8, zoff + 4), (12, zoff + 1)]:
            o[z][x] = "B"
        for x in (6, 7, 8):
            o[zoff + 2][x] = "@"
    return arena(W, H, zoff, paint, "pyramid_field",
                 route=[(0, zoff + 2.5), (2, zoff + 2.5), (6, zoff + 2), (10, zoff + 3), (W - 1, zoff + 2.5)])


def pinball_machine(name="pinball_machine"):
    """A real pinball layout, laid lengthwise: you come in at the flipper end.
      - apron with two flippers that bat you up the table, a centre drain
        between them and an outlane drain on the far side
      - slingshots above the flippers
      - the playfield tilts up towards the top (so you roll back down)
      - jet bumper triangle, a drop target bank, a spinner orbit lane
      - three rollover lanes at the top, split by posts
      - the plunger lane up the side: two boosters, the skill shot to the top
    Exit at the top, locked until the drop target bank is down. Entry tier 0, exit tier 2."""
    W, H, zoff = 20, 16, 5
    extras = [
        {"type": "flipper", "tile": (5, 5), "yaw": 70.0, "strength": 14.0},
        {"type": "flipper", "tile": (5, 10), "yaw": 110.0, "strength": 14.0},
        {"type": "slingshot", "tile": (7, 4), "yaw": 60.0},
        {"type": "slingshot", "tile": (7, 11), "yaw": 120.0},
        {"type": "spinner", "tile": (11, 1.5), "yaw": 90.0},
        {"type": "hoop", "tile": (15, 1.5), "yaw": 90.0, "rise": 1.9, "base": 1},
        {"type": "gate", "tile": (W - 1, zoff + 2.5), "yaw": 0.0, "channel": "targets", "size": (1, 4)},
    ]

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for z in range(1, H - 1):
            for x in range(8, 17):
                h[z][x] = "e"
            for x in (17, 18):
                h[z][x] = "2"
        for (x, z) in [(5, 7), (6, 7), (5, 8), (6, 8), (4, 1), (5, 1), (6, 1), (7, 1), (4, 2), (5, 2), (6, 2), (7, 2)]:
            h[z][x] = "#"
        for z in range(zoff + 1, zoff + 5):
            h[z][3] = "1"
        for x in range(8, 16):
            h[3][x] = "3"
        for x in range(2, 16):
            h[12][x] = "3"
        o[13][2] = o[14][2] = ">"
        o[13][7] = o[14][7] = ">"
        for (x, z) in [(13, 6), (13, 9), (11, 7)]:
            o[z][x] = "B"
        for x in (9, 10, 11):
            o[11][x] = "#"
        for z in (6, 9):
            h[z][17] = "3"
        for z in (5, 7, 10):
            o[z][17] = "@"
        o[1][17] = o[H - 2][18] = "%"
    route = [(0, zoff + 2.5), (1.5, zoff + 2.5), (1.5, 13.5), (4, 13.5), (16, 13.5), (16.5, 11),
             (13, 11), (8.5, 11), (8.5, 9.5), (12, 8), (16, 8), (18, zoff + 3), (W - 1, zoff + 2.5)]
    return arena(W, H, zoff, paint, name, entry=0, exit=2, extras=extras, route=route)


# --- 9. the Silly Race --------------------------------------------------------------------------

def cross_bridges(W=14, w=8):
    """Two narrow beams crossing over the void (an X on screen). The side arms
    end in golden cupcakes: dead ends, and in the Silly Race the slopes at
    their tips roll you UP and off."""
    H, zoff = wide(w)
    h, o = gridh(W, H), gridh(W, H)
    fill(h, 0, zoff + 2, W - 1, zoff + 3, 0)
    cx = W // 2
    fill(h, cx - 1, 0, cx, H - 1, 0)
    o[0][cx - 1], o[H - 1][cx] = "%", "%"
    o[zoff + 2][2], o[zoff + 3][W - 3] = "h", "h"
    return zpiece(h, o, zoff, route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)], name="cross_bridges")


# --- 10. the Ultimate Race ---------------------------------------------------------------------

def checker_dips(W=14, w=8):
    """An orange checker floor with round dips: the marble wants to settle in them."""
    H, zoff = wide(w)

    def paint(h, o):
        fill(h, 1, 1, W - 2, H - 2, 0)
        for z in range(1, H - 1):
            for x in range(2, W - 2):
                if (x + z) % 4 == 0 and (x // 2 + z) % 2 == 0:
                    o[z][x] = "T"
        o[1][1], o[H - 2][W - 2] = "r", "$"
    return arena(W, H, zoff, paint, "checker_dips", route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)])


def ice_lane(W=10):
    """Frozen icing: hardly any grip."""
    h, o = g.lane(W), g.grid(W)
    for x in range(1, W - 1):
        for z in range(1, 5):
            o[z][x] = "I"
    o[0][3], o[5][6] = "$", "$"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="ice_lane")


def steelie_run(W=14, w=6):
    """An open ledge where two black steelies come for you."""
    H, zoff = wide(w)
    h, o = gridh(W, H), gridh(W, H)
    fill(h, 0, 1, W - 1, w, 0)
    o[1][2], o[w][W - 3] = "l", "t"
    extras = [
        {"type": "steelie", "tile": (4, 1), "sense": 8.0, "leash": 9.0, "speed": 3.6},
        {"type": "steelie", "tile": (10, w), "sense": 8.0, "leash": 9.0, "speed": 3.6},
    ]
    return zpiece(h, o, zoff, extras=extras, route=[(0, zoff + 2.5), (W - 1, zoff + 2.5)], name="steelie_run")


def press_run(W=8):
    """A narrow ledge under two marshmallow stompers."""
    h, o = gridh(W, 6), gridh(W, 6)
    fill(h, 0, 2, W - 1, 3, 0)
    return Piece(rows(h), rows(o), extras=[
        {"type": "stomper", "tile": (2.5, 2.5), "period": 2.6, "phase": 0.0},
        {"type": "stomper", "tile": (5.5, 2.5), "period": 2.6, "phase": 0.5},
    ], route=[(0, 2.5), (W - 1, 2.5)], name="press_run")


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
          rival_tint="", rival_speed=1.0, silly=False, extra_cells=None, extra_extras=()):
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
    if silly:
        L.append("\tsilly = true")
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
    print("level %2d %-20s %dx%d tiles, tiers %d-%d, route %d pts" % (
        num, title, len(hg[0]), len(hg), c.min_tier, c.max_tier, len(c.route)))


def run(c, plan):
    for step in plan:
        if isinstance(step, tuple) and step[0] == "turn":
            c.turn(step[1], **step[2])
        else:
            c.place(step)
    return c


def T(d, bank=False, w=4, rails=True):
    return ("turn", d, {"bank": bank, "w": w, "rails": rails})


# --- the ten levels ------------------------------------------------------------------------

def level_1():
    """Practice Race: rolling striped hillsides, no rails, pyramids, a kicker,
    and at the end the ground tips straight down the screen to the hole."""
    c = run(Course(tier=8), [
        g.start(), g.straight(2), hillside(3, 8), T(+1), g.straight(3), pyramid_pinch(12), hillside(2, 6),
        T(-1), g.kicker(), g.straight(2), g.checkpoint(), ledge(6, 4, "l%"), T(+1), g.split(), g.slalom(),
        g.straight(2), T(+1), g.straight(4), hillside(2, 8), g.straight(3), T(-1), g.waves(6), g.hills(6),
        g.checkpoint(), ledge(8, 4, "g%"), T(-1), g.straight(3), g.river(8), g.straight(2), T(+1), g.straight(2),
        diag_finish(2),
    ])
    write(1, c, "Practice Slopes", "Rolling candy hillsides with no rails. Learn to lean, then roll down to the hole.",
          120, "meadow")


def level_2():
    """Beginner Race: a walled plateau of pillars with the black steelie, the
    long steep ramp, a staircase, a pipe, narrow zigzag ledges, the blue wave."""
    c = run(Course(tier=8), [
        g.start(), g.straight(2), g.drop(), pillar_field(16, 8), T(+1), g.straight(2), steep(6, 3, 4), ledge(4),
        g.checkpoint(), T(-1), g.stairs(1), pipe_hop(6), T(+1, w=2, rails=False), ledge(5, 2), T(-1, w=2, rails=False),
        ledge(5, 2), T(+1, w=2, rails=False), step_down(1, 2), ledge(3, 2), T(-1), g.checkpoint(), g.straight(2),
        g.bridge(10, sweep=False), T(-1), g.straight(2), steep(4, 1, 4), ledge(4), T(+1, w=2, rails=False), ledge(4, 2),
        T(+1, w=2, rails=False), ledge(4, 2), T(-1, w=2, rails=False), ledge(3, 2), T(-1), g.checkpoint(),
        wave_slide(8, 1, 6), g.straight(2), g.finish(),
    ])
    write(2, c, "Steelie Steps", "The black steelie hunts the plateau. Then the long ramp, the stairs and the ledges.",
          130, "sky", step=1.0, break_drop=3)


def level_3():
    """Intermediate Race: raised walkways with no walls, green munchers, acid
    slime, steep grated ramps, the spoon catapult and the green hump bridges."""
    c = run(Course(tier=8), [
        g.start(), g.straight(2), steep(1, 2, 4, True), walkway_maze(5, 4, 33), g.checkpoint(), T(+1),
        g.hopper_lane(), steep(1, 2, 4, True), slime_ledge(12), T(-1), g.checkpoint(), g.catapult_launch(),
        hump_bridge(9), T(+1), hump_bridge(9), T(-1), hump_bridge(9), g.checkpoint(), T(-1), g.straight(3),
        steep(1, 2, 4, True), ledge(6, 2), T(+1), g.hopper_lane(), slime_ledge(10), T(+1), g.straight(3),
        steep(2, 1, 4, True), g.checkpoint(), hump_bridge(13), g.straight(2), g.finish(),
    ])
    write(3, c, "Muncher Walkways", "Walkways with no walls, green munchers and acid slime. Ride the humps home.",
          140, "caramel", monster_tint="#6fd13a")


def level_4():
    """Aerial Race: a banked half-pipe, catwalks over the void, the candy
    chute, and the licorice rival racing you all the way."""
    c = run(Course(tier=6), [
        g.start(), boost_strip(), halfpipe(12, 6), T(+1, True), ledge(6, 2), step_down(1, 2), T(-1, w=2, rails=False),
        ledge(5, 2), T(+1, w=2, rails=False), step_down(1, 2), g.checkpoint(), g.straight(2), chute_drop(),
        T(-1, True), boost_strip(), g.funnel(), g.straight(3), T(+1, True), halfpipe(10, 6), g.checkpoint(),
        T(+1, True), g.straight(3), ledge(6, 2), T(-1, w=2, rails=False), ledge(6, 2), T(+1, w=2, rails=False),
        ledge(4, 2), T(-1), g.checkpoint(), boost_strip(), ledge(8, 4, "g%"), g.finish(),
    ])
    write(4, c, "Catwalk Derby", "Race the licorice ball: the half-pipe, catwalks over nothing, the chute.",
          85, "licorice", race=True, rival_tint="#2b2438", rival_speed=1.05)


def level_5():
    """Islands in space: leaps, cannons, and a secret behind the start."""
    c = Course(tier=4)
    c.place(g.start())
    run(c, [g.straight(2), g.leap(1), island(8, "bh$r"), T(+1), g.cannon_hop(), island(10, "g%l"), g.leap(1),
            T(-1), g.checkpoint(), g.straight(3), g.leap(1), island(8, "t%"), T(+1), ledge(6, 4, "lg"),
            g.cannon_hop(), island(12, "%hh$"), g.checkpoint(), T(+1), g.straight(4), g.leap(1), island(8, "r$"),
            T(-1), g.straight(3), g.leap(1), ledge(4, 4)])
    fin = c._world(3, 2.5)
    c.place(g.finish())
    # Easter egg: roll BACKWARDS off the start pad through a gap in its back rail,
    # down a hidden sugar bridge to a secret island with golden cupcakes, a
    # rollover star trio and a cannon that shoots you almost to the flag.
    cells = {}
    for z in (2, 3):
        cells[(0, z)] = ["4", "."]
    for x in range(-8, 0):
        for z in (2, 3):
            cells[(x, z)] = ["4", "."]
    for x in range(-17, -8):
        for z in range(-3, 9):
            edge = x in (-17,) or z in (-3, 8)
            cells[(x, z)] = ["4" if edge else "3", "."]
    for (x, z) in [(-15, -1), (-13, -1), (-11, -1), (-15, 6), (-13, 6), (-11, 6)]:
        cells[(x, z)] = ["3", "%"]
    for z in (1, 2, 3):
        cells[(-11, z)] = ["3", "@"]
    extras = [
        {"type": "secret", "tile": (-10, 2.5)},
        {"type": "cannon", "tile": (-15, 2.5), "target_tile": fin, "hang": 3.4},
    ]
    write(5, c, "Starlight Islands", "Islands floating in space: leap the gaps, ride the cannons. Look behind you!",
          100, "space", extra_cells=cells, extra_extras=extras)


def level_6():
    """The hammers of the Aerial Race as a candy factory: stompers, the big
    press with its timed gate, windmills, fast sweepers, a button bridge."""
    c = run(Course(tier=5), [
        g.start(), g.stomper_gate(), T(+1), big_press(9.0), g.checkpoint(), g.windmill_plaza(), T(-1),
        g.sweepers(3, "all"), switch_gap(), T(+1), steep(2, 2, 4, True), g.checkpoint(), g.sweepers(2, True),
        g.straight(2), T(+1), g.straight(3), g.bridge(10, sweep=True), g.checkpoint(), T(-1), g.windmill_plaza(),
        g.straight(2), T(-1), g.stomper_gate(), g.checkpoint(), g.sweepers(3, "all"), g.straight(2), g.finish(),
    ])
    write(6, c, "Stomper Works", "The candy factory: stompers, the timed press gate, windmills, a button bridge.",
          120, "bakery", monster_tint="#8cc9f0")


def level_7():
    """The acid of the Ultimate Race: planks over goo, slime blobs on the
    flats, beams over a sour lake, ghosts, a river."""
    c = run(Course(tier=4), [
        g.start(), g.ramp_up(), goo_planks(0), g.straight(3), T(+1), slime_flats(16, 8), g.checkpoint(), goo_beams(12),
        T(-1), g.ghost_garden(), g.straight(2), T(+1), g.checkpoint(), goo_beams(8), g.ramp_down(), g.straight(3),
        T(+1), g.straight(3), g.ramp_up(), goo_planks(1), g.straight(3), T(-1), g.checkpoint(), slime_flats(14, 8),
        goo_beams(10), T(-1), g.ghost_garden(), g.ramp_down(), g.straight(3), g.finish(),
    ])
    write(7, c, "Sour Gorge", "Sour goo everywhere: planks, slime blobs, beams over the lake, ghosts.",
          130, "swamp", monster_tint="#b99bea")


def level_8():
    """Pyramids and bumpers, then a real pinball table: clear the targets to get out."""
    c = run(Course(tier=4), [
        g.start(), pyramid_field(16, 8), T(+1, True), g.table(), g.checkpoint(), pinball_machine(), T(-1, True),
        g.spinners(), g.stairs(2), g.straight(2), T(-1, True), g.bumpers(), g.checkpoint(), g.straight(2),
        pyramid_field(14, 8), T(+1, True), g.straight(3), g.table(), g.checkpoint(), g.spinners(), g.straight(2),
        g.finish(),
    ])
    write(8, c, "Pinball Pyramids", "Pyramids, pop bumpers, then a real pinball table. Down the targets to get out.",
          110, "pinball")


def level_9():
    """Silly Race: everything you know is wrong. Slopes roll you up, monsters squish."""
    c = run(Course(tier=2), [
        g.start(), g.bumpers(), cross_bridges(14, 8), T(+1), g.loop(), g.sweepers(2), g.checkpoint(), T(-1),
        g.ramp_up(), g.hills(6), T(+1), g.slalom(), g.checkpoint(), g.sweepers(3, "all"), g.straight(2), T(+1),
        g.straight(3), cross_bridges(12, 8), g.checkpoint(), T(-1), g.ramp_up(), g.loop(), g.sweepers(2, True),
        T(-1), g.checkpoint(), g.hills(6), g.ramp_up(), g.straight(2), g.finish(),
    ])
    write(9, c, "Silly Sundae", "Everything you know is wrong! Slopes roll you up and monsters go squish.",
          110, "bubblegum", silly=True)


def level_10():
    """Ultimate Race: checker dips, ice, steelies, stompers, slime, all at once, racing the rival."""
    c = run(Course(tier=7), [
        g.start(), checker_dips(14, 8), T(+1), ice_lane(10), steelie_run(14, 6), g.checkpoint(), T(-1),
        press_run(8), g.drop(), g.slope_down(2, 5), T(+1), slime_ledge(12), g.checkpoint(), g.sweepers(2, True),
        T(-1), g.ramp_up(), g.straight(3), T(-1), ice_lane(8), checker_dips(12, 8), g.checkpoint(), T(+1),
        g.straight(3), steelie_run(12, 6), press_run(6), g.drop(), g.checkpoint(), T(+1), g.straight(3),
        slime_ledge(10), g.ramp_up(), g.straight(3), g.finish(),
    ])
    write(10, c, "Ultimate Candy", "The final race: dips, ice, steelies, stompers and slime, all at once.",
          110, "summit", race=True, rival_tint="#2b2438", rival_speed=1.0)


LEVELS = [level_1, level_2, level_3, level_4, level_5, level_6, level_7, level_8, level_9, level_10]

if __name__ == "__main__":
    only = [int(a) for a in sys.argv[1:]]
    for k, f in enumerate(LEVELS):
        if not only or k + 1 in only:
            f()

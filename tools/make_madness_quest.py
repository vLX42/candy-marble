"""Writes quests/marble_madness.json: six multi-level races in the spirit of
Marble Madness's races, built in the level editor's quest format (open it with
Quests > Edit to change anything).
Run: python3 tools/make_madness_quest.py
Check: godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --quest=res://quests/marble_madness.json
"""
import json
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "quests", "marble_madness.json")

# heading: 0 = +x, 1 = +z, 2 = -x, 3 = -z
FWD = [(1, 0), (0, 1), (-1, 0), (0, -1)]
RISE = ["e", "s", "w", "n"]          # ramp char rising towards heading
BACK = lambda h: RISE[(h + 2) % 4]   # ramp char rising against heading (descending travel)
THEMES = {
    "Mint choc": {"tiers": ["#BFF0D8", "#8FD9B6", "#D9F5E6", "#A8E6C8", "#C6F0DC"], "ramp": "#F7B2C0", "wall": "#3E2418"},
    "Bubblegum": {"tiers": ["#F9C6D3", "#F7B2C0", "#FBD9E4", "#F4A3BA", "#FDE6EE"], "ramp": "#A9D6F5", "wall": "#8A3553"},
    "Caramel": {"tiers": ["#F3D2A2", "#E8B77A", "#F7E0BF", "#DDA46A", "#FBEBD2"], "ramp": "#F7B2C0", "wall": "#6B3E1F"},
    "Blueberry": {"tiers": ["#BFD4F7", "#A9C1F0", "#C9B8EC", "#D6E4FB", "#B4A7E8"], "ramp": "#F6E27A", "wall": "#2E2350"},
    "Candy": {"tiers": ["#A8E6C8", "#C9B8EC", "#BFE3F7", "#F9C6D3", "#FFE7B3"], "ramp": "#F6E27A", "wall": "#5A3426"},
}


class Map:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.hts = [["."] * w for _ in range(h)]
        self.obj = [["."] * w for _ in range(h)]
        self.extras = []
        self.route = []

    def fill(self, x0, z0, x1, z1, ch):
        for z in range(min(z0, z1), max(z0, z1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                self.hts[z][x] = str(ch)

    def flood_pit(self, tier, obj):
        """Void tiles not connected to the map edge become a low pond."""
        outside = set()
        todo = [(x, z) for x in range(self.w) for z in (0, self.h - 1)] + [(x, z) for z in range(self.h) for x in (0, self.w - 1)]
        while todo:
            x, z = todo.pop()
            if (x, z) in outside or not (0 <= x < self.w and 0 <= z < self.h) or self.hts[z][x] != ".":
                continue
            outside.add((x, z))
            todo += [(x + 1, z), (x - 1, z), (x, z + 1), (x, z - 1)]
        for z in range(self.h):
            for x in range(self.w):
                if self.hts[z][x] == "." and (x, z) not in outside:
                    self.hts[z][x] = str(tier)
                    if (x + z) % 2 == 0:
                        self.obj[z][x] = obj

    def put(self, x, z, ch):
        self.obj[z][x] = ch

    def tier(self, x, z):
        c = self.hts[z][x]
        return int(c) if c.isdigit() else None

    def extra(self, **e):
        e["tile"] = list(e["tile"])
        if "target_tile" in e:
            e["target_tile"] = list(e["target_tile"])
        self.extras.append(e)

    def way(self, *pts):
        for p in pts:
            self.route.append([float(p[0]), float(p[1])])

    def level(self, title, desc, par, theme, **kw):
        d = {
            "title": title, "description": desc, "par": par, "race": False,
            "heights": ["".join(r) for r in self.hts], "objects": ["".join(r) for r in self.obj],
            "extras": self.extras, "route": self.route, "theme": THEMES[theme],
            "monster_speed": 1.0, "monster_tint": "", "rival_speed": 1.0, "rival_tint": "", "break_drop": 0,
        }
        d.update(kw)
        return d


# --- 1. Spiral Summit ------------------------------------------------------------------

def spiral_summit():
    """A square spiral winding down a candy mountain. No outer rails: rolling off
    lands you on the arm below, four steps down, and the marble splats."""
    B = 4                     # arm width in tiles
    sides = [2, 2, 3, 3, 4, 4, 5, 5]
    # Walk the spiral in block units to find its extent first.
    blocks = [(0, 0, 9, None, 0)]   # bx, bz, tier, ramp heading or None, side
    bx, bz, h, t = 0, 0, 0, 9
    for s, n in enumerate(sides):
        t -= 1
        for k in range(n):
            bx += FWD[h][0]
            bz += FWD[h][1]
            blocks.append((bx, bz, t, h if k == 0 else None, s + 1))
        h = (h + 1) % 4
    xs = [b[0] for b in blocks]
    zs = [b[1] for b in blocks]
    ox, oz = -min(xs), -min(zs)
    W = (max(xs) - min(xs) + 1) * B + 2
    H = (max(zs) - min(zs) + 1) * B + 2
    m = Map(W, H)
    centers = []
    for (bx, bz, t, ramp_h, side) in blocks:
        x0 = (bx + ox) * B + 1
        z0 = (bz + oz) * B + 1
        m.fill(x0, z0, x0 + B - 1, z0 + B - 1, BACK(ramp_h) if ramp_h is not None else t)
        centers.append((x0 + 1.5, z0 + 1.5, side, ramp_h, x0, z0))
    # The pit in the middle of the spiral: a sour goo pond far below.
    m.flood_pit(0, "A")
    sx, sz = centers[0][4] + 1, centers[0][5] + 1
    m.put(sx, sz, "S")
    # Features along the way.
    for (cx, cz, side, ramp_h, x0, z0) in centers:
        if ramp_h is not None:
            continue
        if side == 3:
            for dx in range(B):
                for dz in range(B):
                    m.put(x0 + dx, z0 + dz, "W")
        if side == 5 and (cx, cz) == [(c[0], c[1]) for c in centers if c[2] == 5 and c[3] is None][1]:
            m.put(x0 + 1, z0 + 1, "B")
            m.put(x0 + 2, z0 + 2, "B")
    # Sweeper across the long side 6, goo on side 7, a stomper on side 8.
    s6 = [c for c in centers if c[2] == 6 and c[3] is None]
    c = s6[1]
    m.extra(type="enemy", tile=(c[4], c[5]), travel=[6.0, 0.0, 0.0], period=3.0)
    s7 = [c for c in centers if c[2] == 7 and c[3] is None]
    # Goo along the edges of the lap: stay in the middle.
    for k, c in enumerate(s7):
        m.put(c[4] + (k % 4), c[5] + (0 if k % 2 == 0 else 3), "A")
    s8 = [c for c in centers if c[2] == 8 and c[3] is None]
    m.extra(type="stomper", tile=(s8[1][4] + 1.5, s8[1][5] + 1.5), period=2.6)
    # Checkpoint halfway round (side 5), hole at the very end.
    s5 = [c for c in centers if c[2] == 5 and c[3] is None]
    m.put(s5[0][4] + 1, s5[0][5] + 1, "C")
    end = centers[-1]
    m.extra(type="goalpad", tile=(end[4] + 1.5, end[5] + 1.5))
    # Candy on the summit.
    m.put(centers[0][4], centers[0][5], "l")
    m.put(centers[0][4] + 3, centers[0][5] + 3, "%")
    for (cx, cz, side, ramp_h, x0, z0) in centers:
        m.way((cx, cz))
    m.way((end[4] + 2, end[5] + 2))
    return m.level("Spiral Summit",
                   "Wind down the candy mountain. No rails, and a fall onto the lap below breaks you!",
                   62, "Mint choc", break_drop=2, step=1.0)


# --- 2. Terrace Falls -------------------------------------------------------------------

def terrace_falls():
    """A long ramp off a tower onto an open floor of candy pyramids and pillars,
    with green slinkies, then diagonal stair terraces down to the flag."""
    m = Map(36, 35)
    m.fill(2, 2, 5, 5, 9)                  # start tower
    m.put(3, 3, "S")
    m.put(2, 2, "l")
    m.put(5, 2, "t")
    m.fill(2, 6, 5, 17, "n")               # long ramp down to the floor (rises towards -z)
    m.fill(2, 18, 22, 32, 3)               # the open floor
    for x, z in [(9, 21), (12, 26), (17, 21), (8, 29), (18, 29)]:
        m.put(x, z, "H")                   # candy pyramids
    for x0, z0, t in [(7, 24, 6), (14, 18, 7), (20, 25, 5), (13, 30, 6)]:
        m.fill(x0, z0, x0 + 1, z0 + 1, t)  # pillars
    m.extra(type="hopper", tile=(10, 18), travel=[0, 0, 10], period=3.4, hops=3, tint="#6fd13a")
    m.extra(type="hopper", tile=(16, 32), travel=[0, 0, -10], period=3.0, hops=3, phase=0.5, tint="#6fd13a")
    m.extra(type="enemy", tile=(22, 19), travel=[0, 0, 22], period=5.0, tint="#6fd13a")
    m.put(21, 22, "K")
    m.extra(type="steelie", tile=(15, 27), speed=3.6, sense=7.0, leash=8.0)
    m.extra(type="slime", tile=(4, 26), travel=[10.0, 0.0, 0.0], period=4.5)
    m.extra(type="pipe", tile=(3.5, 31), target_tile=(20, 31.5), speed=5.0)
    # Diagonal stair terraces, one step at a time, down to the flag.
    for z in range(18, 33):
        for x in range(23, 35):
            m.hts[z][x] = str(max(0, 2 - ((x - 23) + (z - 18)) // 5))
    m.extra(type="goalpad", tile=(31, 25.5))
    m.put(33, 23, "%")
    m.put(33, 27, "g")
    m.way((3.5, 3.5), (3.5, 6), (3.5, 17.5), (4, 20), (7, 22.5), (15, 23.5), (21, 23.5), (25, 25), (31, 26))
    return m.level("Terrace Falls",
                   "Dodge the steelie and the acid slime, then hop down the terraces.",
                   26, "Candy", break_drop=2, step=1.0, monster_tint="#6fd13a")


# --- 3. Goo Gorge -----------------------------------------------------------------------

def goo_gorge():
    """Narrow unrailed lanes snaking down a gorge at three heights, with a hump
    bridge, goo slaloms, black steelies and a sour lake far below."""
    m = Map(40, 30)
    m.fill(10, 10, 27, 13, 0)              # the sour lake at the bottom of the gorge
    for z in range(10, 14):
        for x in range(10, 28):
            if (x + z) % 3 != 0:
                m.put(x, z, "A")
    m.fill(1, 1, 5, 5, 8)                  # start ledge
    m.put(3, 3, "S")
    m.put(1, 1, "l")
    m.fill(6, 3, 19, 4, 8)                 # lane A, two tiles wide
    for x in range(9, 17):                 # the hump bridge
        m.put(x, 3, "M")
        m.put(x, 4, "M")
    m.fill(18, 3, 19, 8, 8)
    m.fill(18, 7, 29, 8, 8)
    m.put(22, 7, "A")                      # goo slalom
    m.put(26, 8, "A")
    m.fill(28, 9, 29, 14, "n")             # ramp down three steps
    m.fill(8, 15, 29, 16, 5)               # lane B, back the other way
    m.fill(26, 15, 29, 18, 5)              # landing pad at the foot of the ramp
    m.put(26, 15, "C")
    m.extra(type="steelie", tile=(27, 18), speed=3.4, sense=5.0, leash=3.0)
    m.extra(type="stomper", tile=(13.5, 15.5), period=2.6)
    m.fill(8, 17, 9, 22, "n")              # ramp down three more
    m.fill(8, 23, 31, 24, 2)               # lane C, wavy
    m.fill(6, 23, 11, 26, 2)               # landing pad
    for x in range(12, 19):
        m.put(x, 23, "W")
        m.put(x, 24, "W")
    m.fill(20, 21, 28, 26, 2)              # acid alley: slimes patrol the edges
    m.extra(type="slime", tile=(20, 21), travel=[8.0, 0.0, 0.0], period=4.0)
    m.extra(type="slime", tile=(28, 26), travel=[-8.0, 0.0, 0.0], period=4.0, phase=0.5)
    m.fill(30, 20, 36, 27, 2)              # flag mesa
    m.fill(37, 20, 37, 27, 3)
    m.fill(30, 19, 37, 19, 3)
    m.fill(30, 28, 37, 28, 3)
    m.extra(type="goalpad", tile=(34, 23.5))
    m.put(36, 21, "t")
    m.put(36, 26, "b")
    m.way((3, 3), (5, 3.5), (8, 3.5), (17, 3.5), (18.5, 3.5), (18.5, 5.5), (18.5, 7.5), (20, 7.5), (21, 8), (23.5, 8),
          (24.5, 7), (27, 7), (28.5, 7.5), (28.5, 9), (28.5, 14), (28, 16.5), (26, 16), (24, 15.5), (10, 15.5), (8.5, 15.5), (8.5, 17),
          (8.5, 22), (8.5, 24.5), (10.5, 24), (12, 23.5), (30, 23.5), (34, 24))
    return m.level("Goo Gorge",
                   "Narrow lanes down a sour gorge. Roll the humps, dodge the goo and the steelies.",
                   44, "Caramel", break_drop=2, step=1.0)


# --- 4. Sky Catwalks --------------------------------------------------------------------

def sky_catwalks():
    """Aerial race: skinny catwalks high in the sky, a balance beam, hammers, a
    kicker jump over the void and a cannon shot to the flag."""
    m = Map(36, 28)
    m.fill(1, 1, 4, 4, 9)
    m.put(2, 2, "S")
    m.fill(5, 2, 16, 3, 9)                 # catwalk
    m.extra(type="hopper", tile=(10, 0), travel=[0, 0, 8], period=3.2, hops=2, tint="#8cc9f0")
    m.fill(17, 1, 20, 4, 9)                # windmill pad
    m.extra(type="windmill", tile=(18.5, 2.5), spin=1.1, arm_length=2.2, tint="#8cc9f0")
    m.fill(21, 2, 27, 2, 9)                # balance beam, one tile wide
    m.fill(5, 1, 16, 1, 9)                 # ice lane beside the catwalk
    for x in range(5, 17):
        m.put(x, 1, "I")
    m.fill(28, 1, 31, 5, 8)                # step down
    m.fill(29, 6, 30, 14, 8)               # catwalk down
    m.extra(type="stomper", tile=(29.5, 9.5), period=2.8)
    m.extra(type="stomper", tile=(29.5, 12.5), period=2.8, phase=0.5)
    m.fill(27, 15, 32, 18, 7)              # launch pad
    m.put(28, 16, "<")
    m.put(28, 17, "<")
    m.fill(25, 16, 26, 17, "w")            # kicker into the void
    m.fill(13, 14, 22, 19, 6)              # landing pad across the gap
    m.put(16, 16, "K")
    m.extra(type="steelie", tile=(15, 18), speed=3.4, sense=5.0, leash=3.0)
    for x in range(13, 23):
        m.put(x, 14, "I")
        m.put(x, 19, "I")
    m.fill(5, 16, 12, 17, 6)               # goo catwalk
    m.put(10, 16, "A")
    m.put(7, 17, "A")
    m.fill(1, 14, 4, 19, 6)                # cannon pad
    m.extra(type="cannon", tile=(2.5, 18), target_tile=(2.5, 24.5))
    m.fill(0, 22, 5, 27, 2)                # flag island far below
    m.extra(type="goalpad", tile=(3, 24.5))
    m.put(0, 27, "%")
    m.put(5, 22, "l")
    m.way((2, 2), (4, 2.5), (16, 2.5), (18.5, 1.5), (21, 2), (27, 2), (29.5, 3), (29.5, 5), (29.5, 14),
          (29.5, 16.5), (28, 16.5), (25.5, 16.5), (19, 16.5), (13, 16.5), (12, 17), (9.5, 17), (8.5, 16), (6, 16),
          (4.5, 16.5), (2.5, 15.5), (2.5, 18), (2.5, 24.5), (3, 25))
    return m.level("Sky Catwalks",
                   "Skinny catwalks: the beam, the hammers, a jump, then the cannon.",
                   38, "Blueberry", break_drop=4, step=1.0)


# --- 5. Silly Race ----------------------------------------------------------------------

def silly_race():
    """Everything you know is wrong: slopes roll the marble UP, and the munchers
    that pop you everywhere else get squished flat here."""
    m = Map(34, 20)
    m.fill(1, 6, 6, 13, 1)                 # start in the valley
    m.put(3, 9, "S")
    m.put(1, 6, "l")
    m.fill(7, 7, 10, 12, "w")              # ramp up (rises towards +x)
    m.fill(11, 5, 18, 14, 3)               # first terrace: squish the munchers
    m.extra(type="enemy", tile=(14, 6), travel=[0.0, 0.0, 14.0], period=3.0)
    m.extra(type="hopper", tile=(16, 13), travel=[0.0, 0.0, -12.0], period=3.4, hops=3, tint="#6fd13a")
    for x in range(12, 18):
        m.put(x, 5, "M")
        m.put(x, 14, "M")
    m.fill(19, 8, 22, 11, "w")             # second ramp up
    m.fill(23, 4, 32, 15, 6)               # the summit with the GOAL
    m.put(24, 5, "K")
    m.extra(type="enemy", tile=(26, 5), travel=[0.0, 0.0, 16.0], period=2.6, phase=0.5)
    m.extra(type="slime", tile=(28, 13), travel=[0.0, 0.0, -8.0], period=4.0)
    m.extra(type="goalpad", tile=(30, 9.5))
    m.put(32, 4, "%")
    m.put(32, 15, "g")
    m.way((3, 9.5), (6, 9.5), (10.5, 9.5), (14, 9.5), (18.5, 9.5), (22.5, 9.5), (26, 9.5), (30, 10))
    return m.level("Silly Race",
                   "Everything you know is wrong! Slopes roll you uphill and you squish the munchers.",
                   16, "Bubblegum", break_drop=3, step=1.0, silly=True)


# --- 6. Ultimate Madness ----------------------------------------------------------------

def ultimate_madness():
    """Race the licorice steelie down wave terraces, over a hump bridge across
    the goo moat and into the flag pocket."""
    m = Map(46, 28)
    m.fill(1, 8, 8, 19, 9)                 # start plateau
    m.put(3, 12, "S")
    m.put(1, 8, "l")
    m.put(1, 19, "t")
    tiers = [8, 7, 6, 5]
    for k, t in enumerate(tiers):          # terraces stepping down, open at the sides
        x0 = 9 + 5 * k
        m.fill(x0, 8, x0 + 4, 19, t)
        if k in (0, 2):
            for x in range(x0, x0 + 5):
                for z in range(9, 19):
                    m.put(x, z, "W")
    for x, z in [(20, 10), (22, 14), (20, 17)]:
        m.put(x, z, "B")
    m.extra(type="slime", tile=(16, 9), travel=[0.0, 0.0, 9.0], period=3.6)
    for x in range(19, 24):
        for z in range(8, 20):
            if (x, z) not in [(20, 10), (22, 14), (20, 17)]:
                m.put(x, z, "I")
    m.put(26, 12, "K")
    m.extra(type="hopper", tile=(27, 8), travel=[0, 0, 22], period=8.0, hops=4, tint="#6fd13a")
    m.fill(29, 5, 36, 22, 1)               # goo moat far below
    for z in range(5, 23):
        for x in range(29, 37):
            if (x + z) % 2 == 0:
                m.put(x, z, "A")
    m.fill(29, 13, 36, 14, 5)              # hump bridge over the moat
    for x in range(29, 37):
        m.put(x, 13, ".")
        m.put(x, 14, ".")
    for x in range(30, 36):
        m.put(x, 13, "M")
        m.put(x, 14, "M")
    m.fill(37, 9, 44, 18, 5)               # flag pocket with walls
    m.fill(37, 8, 44, 8, 6)
    m.fill(37, 19, 44, 19, 6)
    m.fill(45, 8, 45, 19, 6)
    m.extra(type="steelie", tile=(40, 10), speed=3.6, sense=5.0, leash=3.0)
    m.extra(type="goalpad", tile=(43, 13.5))
    m.put(44, 10, "%")
    m.put(44, 17, "g")
    m.way((3, 12), (8, 13.5), (18, 13.5), (23, 12), (28, 13.5), (36.5, 13.5), (38.5, 13.5), (43, 14))
    return m.level("Ultimate Madness",
                   "Final race! Beat the rival over ice, slime and the hump bridge.",
                   26, "Candy", break_drop=2, step=1.0, race=True, rival_tint="#2b2438", rival_speed=0.92)


LEVELS = [spiral_summit, terrace_falls, goo_gorge, sky_catwalks, silly_race, ultimate_madness]

if __name__ == "__main__":
    quest = {
        "format": "candy-quest", "version": 1, "id": "sample_marble_madness",
        "name": "Marble Madness", "author": "Candy Marble",
        "description": "Six races in the spirit of the 1984 arcade classic: steelies, acid slime, pipes, ice, a Silly Race and a checkered GOAL at the end of each. Big drops break the marble!",
        # Bump "updated" when the levels change: untouched installed copies update.
        "created": 0, "updated": 3,
        "levels": [f() for f in LEVELS],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as fh:
        json.dump(quest, fh, indent="\t")
    for lv in quest["levels"]:
        print(lv["title"], len(lv["heights"][0]), "x", len(lv["heights"]))
        for r in lv["heights"]:
            print("   ", r)

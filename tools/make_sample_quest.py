"""Writes quests/sweet_starter.json, the sample quest installed on first launch.
Run: python3 tools/make_sample_quest.py
Check it plays: godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --quest=res://quests/sweet_starter.json
"""
import json
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "quests", "sweet_starter.json")


class Map:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.hts = [["."] * w for _ in range(h)]
        self.obj = [["."] * w for _ in range(h)]

    def fill(self, x0, z0, x1, z1, ch):
        for z in range(z0, z1 + 1):
            for x in range(x0, x1 + 1):
                self.hts[z][x] = ch

    def put(self, x, z, ch):
        self.obj[z][x] = ch

    def rows(self):
        return ["".join(r) for r in self.hts], ["".join(r) for r in self.obj]


def level(title, desc, par, m, extras, **kw):
    heights, objects = m.rows()
    d = {
        "title": title, "description": desc, "par": par, "race": False,
        "heights": heights, "objects": objects, "extras": extras, "route": [],
        "theme": {"tiers": ["#A8E6C8", "#C9B8EC", "#BFE3F7", "#F9C6D3", "#FFE7B3"], "ramp": "#F6E27A", "wall": "#5A3426"},
        "monster_speed": 1.0, "monster_tint": "", "rival_speed": 1.0, "rival_tint": "",
    }
    d.update(kw)
    return d


def gumdrop_garden():
    m = Map(32, 12)
    m.fill(0, 2, 30, 9, "3")          # rails all round
    m.fill(1, 3, 6, 8, "2")           # start pad
    m.fill(7, 3, 8, 8, "w")           # ramp down (rises towards -x)
    m.fill(9, 3, 22, 8, "0")          # garden floor
    m.fill(23, 3, 24, 8, "e")         # ramp up
    m.fill(25, 3, 29, 8, "1")         # finish pad
    m.put(3, 5, "S")
    for x in range(10, 14):
        for z in range(4, 8):
            m.put(x, z, "W")
    m.put(15, 5, "K")
    m.put(17, 4, "B")
    m.put(17, 7, "B")
    m.put(21, 5, "B")
    m.put(27, 5, "G")
    for x, z, ch in [(2, 3, "l"), (2, 8, "t"), (28, 3, "g"), (28, 8, "%"), (12, 3, "b"), (12, 8, "h")]:
        m.put(x, z, ch)
    extras = [{"type": "enemy", "tile": [19, 3], "travel": [0, 0, 10], "period": 4.0}]
    return level("Gumdrop Garden", "Roll down the ramp, wobble over the waves and slip past the sweeper.",
                 35, m, extras)


def monster_mash():
    m = Map(37, 9)
    m.fill(0, 0, 36, 8, "2")          # rails
    m.fill(1, 1, 35, 7, "0")          # corridor, 7 tiles wide
    m.put(3, 4, "S")
    m.put(34, 4, "G")
    m.put(6, 4, "K")
    m.put(20, 4, "K")
    for x, z, ch in [(2, 1, "l"), (2, 7, "t"), (35, 1, "g"), (35, 7, "b")]:
        m.put(x, z, ch)
    lilac, mint, sky, lemon = "#b99bea", "#8eddb6", "#8cc9f0", "#f7d66b"
    extras = [
        {"type": "stomper", "tile": [10, 2], "period": 2.6, "phase": 0.0, "tint": lilac},
        {"type": "stomper", "tile": [10, 6], "period": 2.6, "phase": 0.5, "tint": lilac},
        {"type": "hopper", "tile": [15, 1], "travel": [0, 0, 12], "period": 4.0, "hops": 3, "tint": mint},
        {"type": "hopper", "tile": [17, 7], "travel": [0, 0, -12], "period": 4.0, "hops": 3, "phase": 0.5, "tint": mint},
        {"type": "windmill", "tile": [25, 4], "spin": 1.0, "arm_length": 3.0, "tint": sky},
        {"type": "ghost", "tile": [30, 2], "speed": 2.2, "tint": lemon},
    ]
    return level("Monster Mash", "Every monster in candyland, dressed in pastels. Time the stompers and hoppers.",
                 40, m, extras, monster_speed=0.9)


def licorice_dash():
    m = Map(28, 20)
    m.fill(0, 0, 27, 6, "3")          # rails top section
    m.fill(1, 1, 22, 5, "1")          # top straight
    m.fill(19, 6, 27, 19, "3")        # rails down section
    m.fill(20, 1, 26, 12, "1")        # corner + down straight
    m.fill(20, 13, 26, 14, "n")       # ramp down (rises towards -z)
    m.fill(20, 15, 26, 18, "0")       # finish
    m.put(3, 3, "S")
    m.put(9, 2, ">")
    m.put(9, 4, ">")
    m.put(23, 9, "v")
    m.put(23, 17, "G")
    m.put(12, 3, "B")
    m.put(23, 6, "C")
    for x, z, ch in [(2, 1, "l"), (2, 5, "t"), (26, 18, "g"), (20, 18, "%")]:
        m.put(x, z, ch)
    extras = [{"type": "enemy", "tile": [16, 1], "travel": [0, 0, 8], "period": 3.2}]
    return level("Licorice Dash", "A pink licorice ball wants the hole too. Use the boosters and beat it there!",
                 30, m, extras, race=True, rival_tint="#f4829f", rival_speed=0.95)


quest = {
    "format": "candy-quest", "version": 1, "id": "sample_sweet_starter",
    "name": "Sweet Starter", "author": "Candy Marble",
    "description": "Three little levels made in the level editor. Play them, then press Edit to see how they're built.",
    "created": 0, "updated": 0,
    "levels": [gumdrop_garden(), monster_mash(), licorice_dash()],
}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    json.dump(quest, f, indent="\t")
print("wrote", OUT)

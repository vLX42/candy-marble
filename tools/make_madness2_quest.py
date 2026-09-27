"""Writes quests/madness_returns.json: a second Marble Madness pack, five more
races after the arcade game's Practice, Intermediate, Aerial, Silly and
Ultimate races. Uses the Map helper from make_madness_quest.py.
Run: python3 tools/make_madness2_quest.py
Check: godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --quest=res://quests/madness_returns.json
"""
import json
import os

from make_madness_quest import Map

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "quests", "madness_returns.json")


# --- 1. Checker Slope (Practice Race) ----------------------------------------------------

def checker_slope():
    """A wide diagonal staircase that zigzags three times down the screen, like
    the practice race: pyramids, bumpers, a couple of slinkies, nothing mean."""
    W, H = 30, 76

    def centre(z):                          # x of the band's middle at row z
        if z <= 26:
            return z
        if z <= 49:
            return 52 - z
        return z - 46

    m = Map(W, H)
    for z in range(1, H - 1):
        c = centre(z)
        for x in range(1, W - 1):
            if abs(x - c) <= 3:
                m.hts[z][x] = str(9 - z // 8)
    m.fill(1, 1, 6, 5, 9)                   # start pad
    m.put(3, 3, "S")
    m.put(1, 1, "l")
    m.put(6, 1, "t")
    for x, z in [(9, 11), (14, 14), (21, 23), (22, 33), (17, 36), (10, 43), (8, 55), (14, 60)]:
        m.put(x, z, "H")
    for x, z in [(12, 10), (18, 20), (21, 29), (12, 38), (9, 52), (19, 66)]:
        m.put(x, z, "B")
    m.put(24, 26, "C")
    m.put(4, 49, "C")
    m.extra(type="hopper", tile=(22, 19), travel=[0.0, 0.0, 10.0], period=3.6, hops=3, tint="#6fd13a")
    m.extra(type="hopper", tile=(9, 40), travel=[10.0, 0.0, 0.0], period=3.8, hops=3, tint="#6fd13a")
    m.extra(type="hopper", tile=(18, 60), travel=[-10.0, 0.0, 0.0], period=3.4, hops=3, phase=0.5, tint="#6fd13a")
    m.extra(type="goalpad", tile=(26, 71))
    m.put(28, 70, "%")
    m.put(23, 74, "g")
    m.way(*[(centre(z) + 0.5, z + 0.5) for z in range(3, 72, 3)], (26.5, 71.5))
    return m.level("Checker Slope",
                   "The practice race. A big zigzag staircase down, mind the edges.",
                   48, "Mint choc", break_drop=2, step=1.0)


# --- 2. Muncher Mill (Intermediate Race) -------------------------------------------------

def muncher_mill():
    """Marble munchers sweep a lane, a button raises the bridge, a ramp drops
    onto a wave floor with a steelie, a pipe takes you down to the yard and a
    second muncher lane runs past goo and a hammer to the flag."""
    m = Map(40, 34)
    m.fill(1, 1, 6, 6, 9)                  # start
    m.put(3, 3, "S")
    m.put(1, 1, "l")
    m.fill(7, 1, 20, 5, 9)                 # muncher lane
    m.extra(type="enemy", tile=(10, 1), travel=[0.0, 0.0, 8.0], period=2.6)
    m.extra(type="enemy", tile=(14, 5), travel=[0.0, 0.0, -8.0], period=2.6, phase=0.5)
    m.extra(type="enemy", tile=(18, 1), travel=[0.0, 0.0, 8.0], period=2.2, phase=0.25)
    m.extra(type="switch", tile=(20, 3), channel="mill")
    # The gap: a plank rises out of it when the button is hit.
    m.extra(type="gate", tile=(21.5, 3), channel="mill", size=[2, 3], bridge=True, y=9.0, yaw=0.0)
    m.fill(23, 1, 23, 5, 9)                # landing on the far side
    m.fill(24, 2, 29, 4, "w")              # ramp down three steps
    m.fill(30, 1, 38, 8, 6)                # wave floor
    for z in range(1, 9):
        for x in range(31, 39):
            m.put(x, z, "W")
    m.put(30, 3, "K")
    m.extra(type="steelie", tile=(35, 7), speed=3.4, sense=5.0, leash=3.0)
    m.fill(33, 9, 38, 20, 6)               # down the side
    m.put(33, 9, "C")
    m.extra(type="slime", tile=(33, 13), travel=[10.0, 0.0, 0.0], period=4.0)
    m.extra(type="pipe", tile=(35.5, 18), target_tile=(26, 18), speed=5.0)
    m.fill(2, 14, 29, 21, 4)               # the yard far below
    m.put(22, 17, "K")                     # the pipe's end counts as a checkpoint
    for x in range(12, 20):
        m.put(x, 17, "M")
        m.put(x, 18, "M")
    m.extra(type="hopper", tile=(10, 14), travel=[0.0, 0.0, 12.0], period=4.4, hops=3, tint="#6fd13a")
    m.fill(2, 22, 6, 25, "n")              # ramp down two steps
    m.fill(2, 26, 34, 31, 2)               # second muncher lane
    m.put(7, 28, "K")
    for x, z in [(10, 26), (14, 31), (18, 26), (22, 31), (27, 26)]:
        m.put(x, z, "A")
    m.extra(type="enemy", tile=(12, 26), travel=[0.0, 0.0, 10.0], period=2.6)
    m.extra(type="stomper", tile=(17.5, 28.5), period=2.8)
    m.extra(type="enemy", tile=(24, 31), travel=[0.0, 0.0, -10.0], period=2.4, phase=0.5)
    m.extra(type="goalpad", tile=(31, 28.5))
    m.put(34, 26, "%")
    m.put(34, 31, "b")
    m.way((3, 3), (6, 3), (20, 3), (23, 3), (29, 3), (31, 3.5), (35.5, 4), (35.5, 9), (35.5, 18), (24, 17.5),
          (12, 17.5), (4, 17.5), (4, 21), (4, 26), (4, 28.5), (31, 28.5))
    return m.level("Muncher Mill",
                   "Munchers, a button bridge, a pipe, then a second muncher lane.",
                   66, "Caramel", break_drop=2, step=1.0)


# --- 3. Hammer Heights (Aerial Race) -----------------------------------------------------

def hammer_heights():
    """A skinny sky catwalk under a row of hammers, a button that raises two
    bridges for a few seconds only, then back west past slinkies and a windmill
    and down to a far island."""
    m = Map(34, 46)
    m.fill(1, 1, 4, 4, 9)
    m.put(2, 2, "S")
    m.put(1, 4, "l")
    m.fill(5, 2, 22, 3, 9)                 # catwalk under the hammers
    for k, x in enumerate((8, 12, 16)):
        m.extra(type="stomper", tile=(x, 2.5), period=2.4, phase=k / 3.0)
    m.put(19, 2, "K")                      # respawn before the button, not after it
    m.extra(type="switch", tile=(21, 2.5), channel="sky", open_time=12.0)
    m.extra(type="gate", tile=(23.5, 2.5), channel="sky", size=[2, 2], bridge=True, y=9.0, yaw=0.0)
    m.fill(25, 1, 31, 4, 9)                # windmill pad
    m.extra(type="windmill", tile=(28, 2.5), spin=1.0, arm_length=1.8, tint="#8cc9f0")
    m.fill(28, 5, 29, 14, 9)               # catwalk south, with a second timed bridge
    m.fill(28, 8, 29, 9, ".")
    m.extra(type="gate", tile=(28.5, 8.5), channel="sky", size=[2, 2], bridge=True, y=9.0, yaw=0.0)
    for z in range(11, 14):
        m.put(28, z, "I")
        m.put(29, z, "I")
    m.fill(28, 15, 29, 20, "n")            # ramp down three steps
    m.fill(19, 21, 31, 24, 6)              # middle deck
    m.put(24, 21, "b")
    m.put(27, 22, "K")
    m.fill(5, 22, 18, 23, 6)               # catwalk back west, slinkies hop across it
    m.extra(type="hopper", tile=(9, 20), travel=[0.0, 0.0, 10.0], period=3.2, hops=2, tint="#8cc9f0")
    m.extra(type="hopper", tile=(14, 25), travel=[0.0, 0.0, -10.0], period=3.2, hops=2, phase=0.5, tint="#8cc9f0")
    m.fill(1, 20, 4, 25, 6)                # windmill corner
    m.extra(type="windmill", tile=(2.5, 22.5), spin=-0.9, arm_length=1.6, tint="#8cc9f0")
    m.fill(2, 26, 3, 33, 6)                # catwalk south with one more hammer
    m.put(2, 27, "C")
    m.extra(type="stomper", tile=(2.5, 30.5), period=2.6)
    m.fill(2, 34, 3, 39, "n")              # ramp down three steps
    m.fill(1, 40, 18, 44, 3)               # the far island
    for x in range(6, 12):
        for z in range(40, 45):
            m.put(x, z, "I")
    m.extra(type="goalpad", tile=(15, 42))
    m.put(18, 40, "%")
    m.put(18, 44, "g")
    m.way((2, 2), (4, 2.5), (21, 2.5), (25, 2.5), (28.5, 3), (28.5, 5), (28.5, 20), (28.5, 22.5), (19, 22.5),
          (5, 22.5), (2.5, 24), (2.5, 26), (2.5, 39), (3, 42), (15, 42))
    return m.level("Hammer Heights",
                   "Time the hammers, hit the button and hurry: the bridges sink again!",
                   56, "Blueberry", break_drop=3, step=1.0)


# --- 4. Upside Hill (Silly Race) ---------------------------------------------------------

def upside_hill():
    """Silly again: roll UP three long ramps to the summit, squishing munchers on
    every terrace, then along the summit ridge to the flag."""
    m = Map(40, 30)
    m.fill(1, 22, 6, 28, 0)                # start low
    m.put(3, 25, "S")
    m.put(1, 28, "l")
    m.fill(1, 16, 6, 21, "n")              # ramp up (rises towards -z)
    m.fill(1, 8, 10, 15, 3)                # first terrace
    m.extra(type="enemy", tile=(2, 9), travel=[16.0, 0.0, 0.0], period=2.8)
    m.extra(type="hopper", tile=(8, 15), travel=[0.0, 0.0, -10.0], period=3.0, hops=2, tint="#6fd13a")
    m.fill(11, 10, 16, 14, "e")            # ramp up (rises towards +x)
    m.fill(17, 8, 36, 16, 6)               # second terrace
    m.put(17, 12, "K")
    for x in range(20, 28):
        for z in (11, 12, 13):
            m.put(x, z, "M")
    m.extra(type="enemy", tile=(22, 8), travel=[0.0, 0.0, 16.0], period=2.4)
    m.extra(type="enemy", tile=(29, 16), travel=[0.0, 0.0, -16.0], period=2.4, phase=0.5)
    m.extra(type="hopper", tile=(33, 8), travel=[0.0, 0.0, 16.0], period=3.4, hops=3, tint="#6fd13a")
    m.fill(31, 17, 36, 22, "s")            # ramp up (rises towards +z)
    m.fill(8, 23, 37, 28, 9)               # the summit ridge
    m.put(33, 23, "C")
    m.extra(type="enemy", tile=(26, 23), travel=[0.0, 0.0, 10.0], period=2.2)
    m.extra(type="enemy", tile=(20, 28), travel=[0.0, 0.0, -10.0], period=2.2, phase=0.5)
    m.extra(type="slime", tile=(15, 23), travel=[0.0, 0.0, 10.0], period=4.0)
    m.extra(type="goalpad", tile=(11, 25.5))
    m.put(8, 23, "%")
    m.put(8, 28, "g")
    m.way((3.5, 25), (3.5, 21), (3.5, 16), (4, 12.5), (10.5, 12), (16.5, 12), (33.5, 12), (33.5, 17), (33.5, 22),
          (33.5, 25.5), (11, 25.5))
    return m.level("Upside Hill",
                   "Silly again! Roll up the hill and squish the munchers on the way.",
                   40, "Bubblegum", break_drop=3, step=1.0, silly=True)


# --- 5. Wave Machine (Ultimate Race) -----------------------------------------------------

def wave_machine():
    """Race the licorice marble across a sea of waves, through the steelies,
    over an ice lane, down a booster chute, along a hump bridge and across the
    slime flats to the GOAL."""
    m = Map(44, 42)
    m.fill(1, 8, 6, 15, 9)                 # start plateau
    m.put(3, 11, "S")
    m.put(1, 8, "l")
    m.put(1, 15, "t")
    m.fill(7, 9, 10, 14, "w")              # ramp down two steps
    m.fill(11, 5, 24, 18, 7)               # the wave sea
    for z in range(5, 19):
        for x in range(11, 25):
            m.put(x, z, "W")
    for x, z in [(14, 5), (18, 18), (22, 5), (12, 18)]:
        m.put(x, z, "A")
    m.extra(type="steelie", tile=(17, 7), speed=3.4, sense=5.0, leash=3.0)
    m.extra(type="steelie", tile=(21, 16), speed=3.4, sense=5.0, leash=3.0)
    m.fill(25, 10, 30, 13, 7)              # ice lane
    for z in range(10, 14):
        for x in range(25, 31):
            m.put(x, z, "I")
    m.put(25, 11, "K")
    m.extra(type="slime", tile=(28, 10), travel=[0.0, 0.0, 6.0], period=3.2)
    m.fill(31, 10, 36, 13, "w")            # booster chute down three steps
    for x in range(31, 37):
        m.put(x, 11, ">")
        m.put(x, 12, ">")
    m.fill(37, 7, 42, 16, 4)               # landing
    m.fill(43, 7, 43, 16, 5)
    m.fill(37, 6, 43, 6, 5)
    m.put(42, 8, "l")
    m.fill(38, 17, 41, 27, 4)              # hump bridge south
    for z in range(18, 27):
        m.put(39, z, "M")
        m.put(40, z, "M")
    m.put(38, 17, "C")
    m.fill(8, 28, 42, 35, 4)               # the slime flats
    for z in range(28, 36):
        for x in range(22, 29):
            m.put(x, z, "I")
    m.put(36, 28, "K")
    m.extra(type="slime", tile=(32, 28), travel=[0.0, 0.0, 14.0], period=3.6)
    m.extra(type="slime", tile=(19, 35), travel=[0.0, 0.0, -14.0], period=3.6, phase=0.5)
    m.extra(type="steelie", tile=(25, 34), speed=3.4, sense=4.0, leash=3.0)
    for x, z in [(30, 35), (16, 28), (12, 35)]:
        m.put(x, z, "A")
    m.extra(type="goalpad", tile=(11, 31.5))
    m.put(8, 28, "%")
    m.put(8, 35, "g")
    m.way((3, 11.5), (6, 11.5), (11, 11.5), (24, 11.5), (30, 11.5), (36.5, 11.5), (39.5, 12), (39.5, 17),
          (39.5, 27), (39.5, 31.5), (11, 31.5))
    return m.level("Wave Machine",
                   "Final race! Beat the rival over waves, a chute, humps and slime.",
                   50, "Candy", break_drop=2, step=1.0, race=True, rival_tint="#2b2438", rival_speed=1.0)


LEVELS = [checker_slope, muncher_mill, hammer_heights, upside_hill, wave_machine]

if __name__ == "__main__":
    quest = {
        "format": "candy-quest", "version": 1, "id": "sample_madness_returns",
        "name": "Madness Returns", "author": "Candy Marble",
        "description": "Five more arcade races: munchers, hammers, sinking bridges, a wave sea and another Silly Race.",
        # Bump "updated" when the levels change: untouched installed copies update.
        "created": 0, "updated": 2,
        "levels": [f() for f in LEVELS],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as fh:
        json.dump(quest, fh, indent="\t")
    for lv in quest["levels"]:
        print(lv["title"], len(lv["heights"][0]), "x", len(lv["heights"]))
        for r in lv["heights"]:
            print("   ", r)

"""Generates scripts/levels/level_N.gd by stitching track pieces (tools/course.py).
Run: python3 tools/genlevels.py

Pieces are authored travelling +x in a 6-row strip: rows 0/5 rails, rows 1-4 the
lane. Route points use tile coordinates where an integer is a tile centre.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from course import Course, Piece  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts", "levels")
DECOR = "ltgb%lthr"


def grid(W, fill="."):
    return [[fill] * W for _ in range(6)]


def lane(W, lane_c="0", rail_c="1"):
    g = grid(W)
    for x in range(W):
        g[0][x] = g[5][x] = rail_c
        for z in range(1, 5):
            g[z][x] = lane_c
    return g


def rows(g):
    return ["".join(r) for r in g]


def rail_decor(o, W, seed):
    for k, x in enumerate(range(1, W, 3)):
        o[0 if k % 2 == 0 else 5][x] = DECOR[(seed + k) % len(DECOR)]


_seed = [0]


def seed():
    _seed[0] += 1
    return _seed[0]


# --- pieces -----------------------------------------------------------------------

def start():
    h = lane(6)
    for z in range(6):
        h[z][0] = "1"
    o = grid(6)
    o[2][2] = "S"
    o[0][3], o[5][4], o[5][1] = "t", "l", "b"
    return Piece(rows(h), rows(o), route=[(2, 2), (5, 2.5)], name="start")


def finish():
    h = lane(8)
    for z in range(6):
        h[z][7] = "1"
    o = grid(8)
    o[2][5] = "G"
    o[0][7], o[5][7], o[0][2], o[5][3] = "%", "t", "l", "g"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (3, 2.5), (5, 2)], name="finish")


def straight(W=5):
    h, o = lane(W), grid(W)
    rail_decor(o, W, seed())
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="straight")


def waves(W=6):
    h, o = lane(W), grid(W)
    for x in range(W):
        for z in range(1, 5):
            o[z][x] = "W"
    rail_decor(o, W, seed())
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="waves")


def hills(W=6):
    h, o = lane(W), grid(W)
    o[1][1], o[4][3], o[1][5] = "H", "H", "H"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="hills")


def bumpers():
    W = 10
    h, o = lane(W), grid(W)
    for x, z in [(2, 1), (4, 4), (6, 1), (8, 4)]:
        o[z][x] = "B"
    rail_decor(o, W, seed())
    return Piece(rows(h), rows(o), route=[(0, 2.5), (2, 3.3), (4, 1.8), (6, 3.2), (8, 1.8), (9, 2.5)], name="bumpers")


def sweepers(n=2, fast=False):
    W = 2 * n + 2
    h, o = lane(W), grid(W)
    for k in range(n):
        x = 2 + 2 * k
        o[1][x] = "Z" if (fast and k % 2 == 1) or fast == "all" else "z"
        for z in (2, 3, 4):
            o[z][x] = "|"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="sweepers")


def bridge(W=10, sweep=True):
    h, o = grid(W), grid(W)
    for x in range(W):
        h[2][x] = h[3][x] = "0"
    for z in (1, 4):
        h[z][0] = "0"
        h[z][W - 1] = "0"
    if sweep:
        for x, c in [(3, "Z"), (7, "z")]:
            if x < W - 1:
                o[0][x] = c
                for z in range(1, 6):
                    o[z][x] = "|"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], name="bridge")


def ramp_up():
    h = lane(3)
    for z in range(1, 5):
        h[z][1] = h[z][2] = "e"
    for z in (0, 5):
        h[z][1] = h[z][2] = "2"
    return Piece(rows(h), route=[(0, 2.5), (2, 2.5)], entry=0, exit=1, name="ramp_up")


def ramp_down():
    h = lane(3, "1", "2")
    for z in range(1, 5):
        h[z][1] = h[z][2] = "w"
    return Piece(rows(h), route=[(0, 2.5), (2, 2.5)], entry=1, exit=0, name="ramp_down")


def drop():
    h = lane(4)
    for x in (0, 1):
        for z in range(1, 5):
            h[z][x] = "1"
        h[0][x] = h[5][x] = "2"
    return Piece(rows(h), route=[(0, 2.5), (3, 2.5)], entry=1, exit=0, name="drop")


def kicker():
    W = 11
    h, o = grid(W), grid(W)
    for x in range(3):
        h[0][x] = h[5][x] = "1"
        for z in range(1, 5):
            h[z][x] = "0"
    for x in (3, 4):
        for z in range(1, 5):
            h[z][x] = "e"
    for x in range(6, W):
        h[0][x] = h[5][x] = "2"
        for z in range(1, 5):
            h[z][x] = "1"
    o[2][1] = o[3][1] = ">"
    return Piece(rows(h), rows(o), entry=0, exit=1,
                 extras=[{"type": "hoop", "tile": (5, 2.5), "yaw": 90.0, "rise": 1.95, "base": 0}],
                 route=[(0, 2.5), (1, 2.5), (3.5, 2.5), (8, 2.5), (10, 2.5)], name="kicker")


def loop():
    W = 9
    h = lane(W)
    for x in range(1, 7):
        h[1][x] = h[4][x] = "1"
    return Piece(rows(h), extras=[{"type": "loop", "tile": (4, 3), "yaw": 90.0}],
                 route=[(0, 2.5), (1.5, 3), (2.5, 3), (6, 2), (8, 2.5)], name="loop")


def river(W=8):
    h, o = lane(W), grid(W)
    for x in range(1, W - 1):
        o[2][x] = "T"
    o[4][2], o[1][W - 3] = "H", "H"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (1, 2), (W - 2, 2), (W - 1, 2.5)], name="river")


def table():
    W = 10
    h, o = lane(W), grid(W)
    o[2][2] = o[3][2] = "@"
    for x, z in [(4, 1), (4, 4), (6, 2)]:
        o[z][x] = "B"
    o[1][9] = o[4][9] = "#"
    return Piece(rows(h), rows(o),
                 extras=[{"type": "slingshot", "tile": (8, 1), "yaw": 0.0},
                         {"type": "slingshot", "tile": (8, 4), "yaw": 180.0}],
                 route=[(0, 2.5), (2, 2.5), (4, 2.5), (5, 3.5), (7, 3.5), (8, 2.5), (9, 2.5)], name="table")


def cannon_hop():
    W = 13
    h, o = grid(W), grid(W)
    for x in range(4):
        for z in range(6):
            h[z][x] = "1"
        h[2][x] = "0"
    for z in range(1, 5):
        h[z][0] = h[z][1] = "0"
    for z in range(6):
        h[z][4] = "1"
    for x in range(8, W):
        h[0][x] = h[5][x] = "2"
        for z in range(1, 5):
            h[z][x] = "1"
    return Piece(rows(h), rows(o), entry=0, exit=1,
                 extras=[{"type": "cannon", "tile": (3, 2), "target_tile": (10, 2.5)},
                         {"type": "hoop", "tile": (6.5, 2.3), "yaw": 90.0, "rise": 4.1, "base": 0}],
                 route=[(0, 2.5), (2, 2), (3, 2), (10, 2.5), (12, 2.5)], name="cannon_hop")


def spinners():
    h = lane(4)
    return Piece(rows(h), extras=[{"type": "spinner", "tile": (2, 2), "yaw": 90.0},
                                  {"type": "spinner", "tile": (2, 3), "yaw": 90.0}],
                 route=[(0, 2.5), (3, 2.5)], name="spinners")


def checkpoint():
    h, o = lane(2), grid(2)
    o[2][1] = "K"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (1, 2.5)], name="checkpoint")


# --- one-off pieces for the level 1 descent ---------------------------------------------

def slope_down(tiers=1, W=4):
    """Gentle icing slope down `tiers` over W-1 tiles."""
    h = lane(W, str(tiers), str(tiers + 1))
    for x in range(1, W):
        for z in range(1, 5):
            h[z][x] = "w"
    o = grid(W)
    o[0][2], o[5][1] = "l", "g"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], entry=tiers, exit=0, name="slope_down")


def slalom():
    """Zig-zag between pillow blocks."""
    W = 10
    h, o = lane(W), grid(W)
    for x, zs in [(2, (1, 2)), (5, (3, 4)), (8, (1, 2))]:
        for z in zs:
            h[z][x] = "1"
        o[zs[0]][x] = "l"
    return Piece(rows(h), rows(o),
                 route=[(0, 2.5), (1.5, 3.5), (2.5, 3.5), (3.8, 2.5), (5, 1.5), (6.2, 2.5), (8, 3.5), (9, 2.5)],
                 name="slalom")


def stairs(steps=2):
    """Candy staircase: short flats with a one-tier drop after each."""
    W = 2 * steps + 2
    h = lane(W)
    for x in range(W):
        t = steps - min(x // 2, steps)
        h[0][x] = h[5][x] = str(t + 1)
        for z in range(1, 5):
            h[z][x] = str(t)
    o = grid(W)
    o[0][1], o[5][3] = "t", "b"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (W - 1, 2.5)], entry=steps, exit=0, name="stairs")


def funnel():
    """Lane squeezes to two tiles with a booster pair in the middle."""
    W = 7
    h, o = lane(W), grid(W)
    for x in range(1, 6):
        h[1][x] = h[4][x] = "1"
    o[2][3] = o[3][3] = ">"
    o[1][2], o[4][4] = "%", "g"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (3, 2.5), (6, 2.5)], name="funnel")


def chute_drop():
    """Candy chute slide 4 tiers (2 units) down over a void."""
    W = 8
    h, o = grid(W), grid(W)
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


def leap(tiers=1):
    """Booster run off an edge, fly a one-tile gap down onto a lower level."""
    W = 11
    h, o = grid(W), grid(W)
    for x in range(4):
        h[0][x] = h[5][x] = str(tiers + 1)
        for z in range(1, 5):
            h[z][x] = str(tiers)
    for x in range(5, W):
        h[0][x] = h[5][x] = "1"
        for z in range(1, 5):
            h[z][x] = "0"
    for x in range(W - 1, W):
        for z in range(6):
            h[z][x] = "1"
    h[1][W - 1] = h[2][W - 1] = h[3][W - 1] = h[4][W - 1] = "0"
    o[2][1] = o[3][1] = ">"
    o[0][7], o[5][8] = "%", "t"
    return Piece(rows(h), rows(o), entry=tiers, exit=0,
                 route=[(0, 2.5), (1, 2.5), (3.5, 2.5), (7, 2.5), (10, 2.5)], name="leap")


def split():
    """The lane splits round a candy mound: wavy left lane, boosted right lane."""
    W = 10
    h, o = lane(W), grid(W)
    for x in range(2, 8):
        for z in (2, 3):
            h[z][x] = "2"
        o[1][x] = "W"
    o[2][3], o[3][6], o[2][5] = "%", "t", "b"
    o[4][3] = o[4][6] = ">"
    return Piece(rows(h), rows(o), route=[(0, 2.5), (1.5, 4), (8.5, 4), (9, 2.5)], name="split")


# --- enemy and catapult pieces ----------------------------------------------------------

def hopper_lane():
    """Two gumdrop hoppers bouncing across the lane: go under them mid-hop."""
    W = 10
    h, o = lane(W), grid(W)
    rail_decor(o, W, seed())
    return Piece(rows(h), rows(o), extras=[
        {"type": "hopper", "tile": (3, 1), "travel_tiles": (0, 3), "period": 3.6, "hops": 2},
        {"type": "hopper", "tile": (7, 4), "travel_tiles": (0, -3), "period": 3.0, "hops": 2, "phase": 0.5},
    ], route=[(0, 2.5), (W - 1, 2.5)], name="hopper_lane")


def stomper_gate():
    """A one-tile corridor under three marshmallow stompers in a rolling rhythm."""
    W = 11
    h, o = lane(W), grid(W)
    for x in range(1, W - 1):
        for z in (1, 3, 4):
            h[z][x] = "1"
    o[1][2], o[4][6], o[1][9] = "l", "g", "t"
    return Piece(rows(h), rows(o), extras=[
        {"type": "stomper", "tile": (3, 2), "period": 2.8, "phase": 0.0},
        {"type": "stomper", "tile": (5.5, 2), "period": 2.8, "phase": 0.3},
        {"type": "stomper", "tile": (8, 2), "period": 2.8, "phase": 0.6},
    ], route=[(0, 2.5), (1, 2), (W - 2, 2), (W - 1, 2.5)], name="stomper_gate")


def ghost_garden():
    """Candy garden with hills where two sour ghosts drift after you."""
    W = 12
    h, o = lane(W), grid(W)
    o[4][2], o[1][9] = "H", "H"
    o[0][4], o[5][7], o[0][10] = "t", "l", "%"
    return Piece(rows(h), rows(o), extras=[
        {"type": "ghost", "tile": (4, 1), "leash": 4.5},
        {"type": "ghost", "tile": (8, 4), "leash": 4.5},
    ], route=[(0, 2.5), (W - 1, 2.5)], name="ghost_garden")


def windmill_plaza():
    """Two licorice windmills spinning opposite ways: time your pass."""
    W = 13
    h, o = lane(W), grid(W)
    o[0][6], o[5][6] = "%", "g"
    return Piece(rows(h), rows(o), extras=[
        {"type": "windmill", "tile": (3, 2.5), "spin": 1.2},
        {"type": "windmill", "tile": (9, 2.5), "spin": -1.4},
    ], route=[(0, 2.5), (W - 1, 2.5)], name="windmill_plaza")


def catapult_launch():
    """Funnel into the spoon, get flung in a high arc to a lower island."""
    W = 15
    h, o = grid(W), grid(W)
    for x in range(0, 2):
        h[0][x] = h[5][x] = "2"
        for z in range(1, 5):
            h[z][x] = "1"
    for x in range(2, 5):
        for z in range(6):
            h[z][x] = "2"
        h[2][x] = "1"
    for x in range(9, W):
        h[0][x] = h[5][x] = "1"
        for z in range(1, 5):
            h[z][x] = "0"
    o[0][10], o[5][12] = "t", "l"
    return Piece(rows(h), rows(o), entry=1, exit=0, extras=[
        {"type": "catapult", "tile": (4, 2), "target_tile": (11, 2.5)},
    ], route=[(0, 2.5), (2, 2), (3.2, 2), (11, 2.5), (13, 2.5)], name="catapult_launch")


# --- levels -------------------------------------------------------------------------

def build(num, title, desc, par, tier, plan, race=False):
    c = Course(tier=tier)
    for step in plan:
        if isinstance(step, tuple) and step[0] == "turn":
            c.turn(step[1], bank=len(step) > 2)
        else:
            c.place(step)
    c.write(os.path.join(OUT, f"level_{num}.gd"), num, title, desc, par, race)


T = lambda d, bank=False: ("turn", d, "bank") if bank else ("turn", d)  # noqa: E731


def main():
    build(1, "Sugar Lane", "A descent from the top of the candy hills to the bottom, every stretch different: slope, slalom, stairs, a funnel, the candy chute, a split path, a leap down, a loop and a river.", 105, 8, [
        start(), straight(3), slope_down(1), T(+1), slalom(), stairs(2), T(-1), checkpoint(), waves(6),
        sweepers(1), T(+1), chute_drop(), funnel(), checkpoint(), bumpers(), T(-1), split(), table(), hills(),
        T(+1), checkpoint(), leap(1), bridge(8, sweep=False), spinners(), loop(), T(-1), river(), kicker(),
        drop(), finish(),
    ])
    build(2, "Gumdrop Pinball", "RACE vs the licorice ball through a pinball park: tables, windmills, a loop, a catapult.", 80, 6, [
        start(), ramp_down(), table(), T(+1, True), bumpers(), checkpoint(), windmill_plaza(), loop(),
        T(-1, True), funnel(), spinners(), stairs(2), T(+1, True), checkpoint(), slalom(), catapult_launch(),
        T(-1, True), waves(6), river(), finish(),
    ], race=True)
    build(3, "Sprinkle Skies", "Island hopping: kickers, a hopper lane, a cannon, a leap, a ghost garden and a catapult.", 75, 2, [
        start(), kicker(), T(+1), bridge(), checkpoint(), hopper_lane(), cannon_hop(), T(-1), leap(1),
        ghost_garden(), checkpoint(), T(+1), catapult_launch(), split(), T(-1), sweepers(2, True),
        slope_down(1), finish(),
    ])
    build(4, "Licorice Loops", "Down through the licorice works: stompers, the candy chute, windmills and haunted hills.", 90, 8, [
        start(), river(), drop(), T(+1), loop(), stomper_gate(), checkpoint(), T(-1), chute_drop(),
        windmill_plaza(), T(+1), checkpoint(), ghost_garden(), hills(), T(-1), stairs(2), sweepers(3),
        T(+1), checkpoint(), waves(6), slope_down(1), finish(),
    ])
    build(5, "Candy Castle", "RACE vs the licorice ball up the castle: hoppers, stompers, cannons and a catapult.", 110, 0, [
        start(), ramp_up(), sweepers(2), T(+1), bridge(), checkpoint(), hopper_lane(), kicker(), T(-1),
        stomper_gate(), cannon_hop(), T(+1), checkpoint(), windmill_plaza(), ghost_garden(), T(-1), loop(),
        catapult_launch(), T(+1), checkpoint(), funnel(), ramp_up(), finish(),
    ], race=True)
    build(6, "Pinball Parlor", "Speed run through every pinball toy in the park: tables, cannons, windmills, stompers, a catapult.", 125, 5, [
        start(), table(), T(+1, True), loop(), cannon_hop(), T(-1, True), bumpers(), spinners(), checkpoint(),
        windmill_plaza(), catapult_launch(), T(+1, True), funnel(), stomper_gate(), checkpoint(), T(-1, True),
        slalom(), hopper_lane(), split(), finish(),
    ])

if __name__ == "__main__":
    main()

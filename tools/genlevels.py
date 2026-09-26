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
    build(1, "Sugar Lane", "A long, friendly tour with rails everywhere: waves, hills, bumpers, a loop, a river, one jump.", 155, 3, [
        start(), straight(4), waves(6), T(+1), hills(), straight(4), bumpers(), T(-1), checkpoint(),
        sweepers(1), straight(4), loop(), straight(3), T(+1), river(), ramp_down(), straight(4), T(-1),
        checkpoint(), waves(8), kicker(), straight(3), T(+1), spinners(), bumpers(), drop(), T(-1),
        checkpoint(), hills(), straight(4), river(10), T(+1), waves(6), straight(3), loop(), T(-1),
        checkpoint(), bumpers(), sweepers(1), hills(), T(+1), river(), kicker(), waves(6), straight(3), finish(),
    ])
    build(2, "Gumdrop Pinball", "RACE vs the licorice ball. Bumper tables, slingshots, speed-bank corners and loops, down a long pinball run.", 130, 5, [
        start(), ramp_down(), table(), T(+1, True), bumpers(), checkpoint(), sweepers(2), loop(),
        T(-1, True), table(), straight(3), ramp_down(), bumpers(), T(+1, True), checkpoint(), spinners(),
        table(), loop(), T(-1, True), river(), drop(), bumpers(), sweepers(2, True), T(+1, True),
        checkpoint(), table(), waves(6), loop(), T(-1, True), bumpers(), straight(3), finish(),
    ], race=True)
    build(3, "Sprinkle Skies", "Island hopping: kicker jumps through hoops, cannon hops over the void, sweeper bridges.", 100, 1, [
        start(), straight(3), kicker(), T(+1), bridge(), checkpoint(), cannon_hop(), T(-1), sweepers(2),
        kicker(), straight(3), T(+1), checkpoint(), bridge(8), ramp_down(), waves(6), T(-1), cannon_hop(),
        checkpoint(), kicker(), T(+1), bridge(), sweepers(2, True), T(-1), checkpoint(), cannon_hop(),
        straight(3), finish(),
    ])
    build(4, "Licorice Loops", "Loops, candy rivers and drops, with sweepers guarding every other bend.", 210, 7, [
        start(), river(), drop(), T(+1), loop(), sweepers(2), checkpoint(), river(10), T(-1), drop(),
        loop(), hills(), T(+1), checkpoint(), sweepers(2, True), river(), drop(), T(-1), waves(8), loop(),
        T(+1), checkpoint(), bridge(), river(), drop(), T(-1), sweepers(3), loop(), T(+1), checkpoint(),
        hills(), river(), drop(), T(-1), loop(), sweepers(2, True), bridge(), T(+1), checkpoint(),
        river(10), waves(6), loop(), T(-1), hills(), sweepers(3), river(), T(+1), checkpoint(),
        bridge(8), loop(), straight(3), finish(),
    ])
    build(5, "Candy Castle", "RACE vs the licorice ball. The long climb: ramps up tier after tier past fast sweepers, bridges and kickers to the top.", 165, 0, [
        start(), straight(3), ramp_up(), sweepers(2), T(+1), bridge(), ramp_up(), checkpoint(), loop(),
        T(-1), sweepers(2, True), ramp_up(), kicker(), T(+1), checkpoint(), bridge(8), hills(),
        T(-1), sweepers(3, True), checkpoint(), cannon_hop(), T(+1), bumpers(), ramp_up(), loop(), T(-1),
        checkpoint(), bridge(), sweepers(2, True), kicker(), T(+1), waves(6), bumpers(), T(-1),
        checkpoint(), bridge(8), sweepers(3, True), loop(), T(+1), cannon_hop(), hills(), straight(3), finish(),
    ], race=True)
    build(6, "Pinball Parlor", "Pure speed run: tables, cannons, loops and speed banks. Keep it rolling.", 115, 4, [
        start(), table(), T(+1, True), loop(), cannon_hop(), T(-1, True), table(), spinners(), checkpoint(),
        loop(), T(+1, True), table(), ramp_down(), cannon_hop(), T(-1, True), checkpoint(), bumpers(),
        loop(), T(+1, True), table(), spinners(), cannon_hop(), T(-1, True), checkpoint(), table(), loop(),
        finish(),
    ])


if __name__ == "__main__":
    main()

"""Course stitcher: builds long levels by chaining track pieces.

Every piece is authored once travelling +x in a 6-row strip (rows 0 and 5 are
rails, rows 1-4 the lane). The stitcher rotates pieces for corners, converts
ramp / booster / sweeper / checkpoint characters, extras and bot routes, keeps
track of the height tier, and writes a LevelBase GDScript file.

Height digits inside a piece are relative: world tier = current tier - piece.entry + digit.
"""
import os

F = [(1, 0), (0, 1), (-1, 0), (0, -1)]           # forward per heading
L = [(0, 1), (-1, 0), (0, -1), (1, 0)]           # lateral (right hand) per heading
H_ROT = {"e": "s", "s": "w", "w": "n", "n": "e"}
O_ROT = {">": "v", "v": "<", "<": "^", "^": ">", "x": "z", "z": "x", "X": "Z", "Z": "X",
         "-": "|", "|": "-", "C": "K", "K": "C"}


def rot(c, table, times):
    for _ in range(times):
        c = table.get(c, c)
    return c


class Piece:
    def __init__(self, heights, objects=None, entry=0, exit=None, extras=(), route=(), name=""):
        self.heights = heights
        self.W = len(heights[0])
        self.H = len(heights)
        assert all(len(r) == self.W for r in heights), name
        self.objects = objects or ["." * self.W] * self.H
        assert len(self.objects) == self.H and all(len(r) == self.W for r in self.objects), name
        self.entry = entry
        self.exit = entry if exit is None else exit
        self.extras = list(extras)
        self.route = list(route)
        self.name = name


class Course:
    def __init__(self, tier=3):
        self.cells = {}
        self.extras = []
        self.route = []
        self.ox, self.oz = 0, 0
        self.h = 0
        self.tier = tier
        self.min_tier = tier
        self.max_tier = tier

    def _world(self, x, z):
        f, l = F[self.h], L[self.h]
        return (self.ox + x * f[0] + z * l[0], self.oz + x * f[1] + z * l[1])

    def place(self, p):
        for z in range(p.H):
            for x in range(p.W):
                hc = p.heights[z][x]
                oc = p.objects[z][x]
                if hc == "." and oc == ".":
                    continue
                if hc.isdigit():
                    t = self.tier - p.entry + int(hc)
                    assert 0 <= t <= 9, f"tier {t} out of range in {p.name}"
                    self.min_tier = min(self.min_tier, t)
                    self.max_tier = max(self.max_tier, t)
                    hc = str(t)
                else:
                    hc = rot(hc, H_ROT, self.h)
                oc = rot(oc, O_ROT, self.h)
                w = self._world(x, z)
                old = self.cells.get(w)
                if old and old[0] != "." and hc != ".":
                    raise ValueError(f"overlap at {w} placing {p.name}")
                if old and hc == ".":
                    hc = old[0]
                self.cells[w] = [hc, oc if oc != "." or not old else old[1]]
        for e in p.extras:
            d = dict(e)
            d["tile"] = self._world(*e["tile"])
            if "target_tile" in d:
                d["target_tile"] = self._world(*e["target_tile"])
            if "yaw" in d:
                d["yaw"] = (d["yaw"] - 90.0 * self.h) % 360.0
            if "y_tier" in d:
                d["y"] = (self.tier - p.entry + d.pop("y_tier")) * 0.5
            if "rise" in d:
                d["height"] = (self.tier - p.entry + d.pop("base", p.entry)) * 0.5 + d.pop("rise")
            self.extras.append(d)
        for (x, z) in p.route:
            self.route.append(self._world(x, z))
        f = F[self.h]
        self.ox += f[0] * p.W
        self.oz += f[1] * p.W
        self.tier += p.exit - p.entry

    def turn(self, d, bank=False):
        """d=+1 turns to the right-hand lateral, d=-1 to the left."""
        hs = [["." for _ in range(6)] for _ in range(6)]
        for x in range(0, 5):
            for z in range(1, 5):
                hs[z][x] = "0"
        exit_row = 5 if d > 0 else 0
        rail_row = 0 if d > 0 else 5
        for x in range(1, 5):
            hs[exit_row][x] = "0"
        for x in range(6):
            hs[rail_row][x] = "1"
        for z in range(6):
            hs[z][5] = "1"
        hs[exit_row][0] = "1"
        route = [(0, 2.5), (2.5, 2.5), (2.5, 5.5 if d > 0 else -0.5)]
        extras = []
        if bank:
            extras.append({"type": "redirect", "tile": (2.5, 2.5), "yaw": 0.0 if d > 0 else 180.0, "strength": 8.0})
        piece = Piece(["".join(r) for r in hs], extras=extras, route=route, name="turn")
        f, l = F[self.h], L[self.h]
        tier = self.tier
        self.place(piece)
        # place() advanced the cursor forward; undo and move to the exit side.
        self.ox -= f[0] * 6
        self.oz -= f[1] * 6
        if d > 0:
            self.ox += 6 * l[0] + 5 * f[0]
            self.oz += 6 * l[1] + 5 * f[1]
            self.h = (self.h + 1) % 4
        else:
            self.ox -= l[0]
            self.oz -= l[1]
            self.h = (self.h + 3) % 4
        self.tier = tier

    # --- output -----------------------------------------------------------------

    def grids(self):
        xs = [c[0] for c in self.cells]
        zs = [c[1] for c in self.cells]
        x0, z0 = min(xs), min(zs)
        W, H = max(xs) - x0 + 1, max(zs) - z0 + 1
        hg = [["." for _ in range(W)] for _ in range(H)]
        og = [["." for _ in range(W)] for _ in range(H)]
        for (x, z), (hc, oc) in self.cells.items():
            hg[z - z0][x - x0] = hc
            og[z - z0][x - x0] = oc
        _normalize_sweepers(og)
        shift = (-x0, -z0)
        return hg, og, shift

    def write(self, path, num, title, desc, par, race=False):
        hg, og, (sx, sz) = self.grids()
        L_ = ["extends LevelBase", f"## {desc}", "## Generated by tools/genlevels.py, edit there.", "", "",
              "func _init() -> void:", f'\ttitle = "{title}"', f"\ttime_limit = {par:.1f}"] + (["\trace = true"] if race else []) + ["\theights = ["]
        L_ += [f'\t\t"{"".join(r)}",' for r in hg] + ["\t]", "\tobjects = ["]
        L_ += [f'\t\t"{"".join(r)}",' for r in og] + ["\t]", "\textras = ["]
        for e in self.extras:
            parts = []
            for k, v in e.items():
                if k in ("tile", "target_tile"):
                    v = f"Vector2({v[0] + sx}, {v[1] + sz})"
                elif isinstance(v, str):
                    v = f'"{v}"'
                elif isinstance(v, float):
                    v = f"{v:.2f}"
                parts.append(f"{k} = {v}")
            L_.append("\t\t{" + ", ".join(parts) + "},")
        L_ += ["\t]", "\troute = ["]
        for (x, z) in self.route:
            L_.append(f"\t\tVector2({x + sx}, {z + sz}),")
        L_ += ["\t]"]
        with open(path, "w") as fh:
            fh.write("\n".join(L_) + "\n")
        print(f"wrote {title}: {len(hg[0])}x{len(hg)} tiles, route {len(self.route)} pts, tiers {self.min_tier}-{self.max_tier}")


def _normalize_sweepers(og):
    """Sweepers must sit at the low end of their '-' / '|' run."""
    H, W = len(og), len(og[0])
    for z in range(H):
        for x in range(W):
            if og[z][x] in "xX" and x > 0 and og[z][x - 1] == "-":
                s = x
                while s - 1 >= 0 and og[z][s - 1] == "-":
                    s -= 1
                og[z][s], og[z][x] = og[z][x], "-"
    for x in range(W):
        for z in range(H):
            if og[z][x] in "zZ" and z > 0 and og[z - 1][x] == "|":
                s = z
                while s - 1 >= 0 and og[s - 1][x] == "|":
                    s -= 1
                og[s][x], og[z][x] = og[z][x], "|"

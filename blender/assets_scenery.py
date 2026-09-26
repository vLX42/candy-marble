"""Backdrop scenery for Candy Marble: floating candy islands, landmarks and props.

Run headless from the repo root:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_scenery.py
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_scenery.py -- candy_castle donut_planet
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_scenery.py -- preview

Same axis convention as build_assets.py: Blender Z-up, -Y is Godot +Z (front).
Every asset has its origin at the bottom centre unless noted (ferris_wheel_rotor
and donut_planet are centred).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_assets import *  # noqa: F401,F403
from build_assets import PALETTE, ROOT, OUT, material, reset, finish, cube, sphere, cylinder, cone, torus, export

import bmesh
import bpy
from mathutils import Matrix, Vector

PALETTE.update({
    "vanilla": "#FFE7B3",
    "gold": "#FFC94A",
    "gingerbread": "#C8834A",
    "blush": "#FCD6E0",
    "wafer": "#EDBE78",
    "waferdark": "#C98E4C",
    "dough": "#EBB47C",
    "cloud": "#FFFFFF",
})

TAU = 2 * math.pi


def M(name, rough=0.3, coat=0.55):
    return material(name, rough, coat)


def CLOUD(name="cloud"):
    return material(name, 0.65, 0.0)


# --- geometry helpers ----------------------------------------------------------

def _link(bm, name, mats, idx, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    finish(obj, mats[0], smooth=smooth)
    for m in mats[1:]:
        obj.data.materials.append(m)
    if idx:
        for p, k in zip(obj.data.polygons, idx):
            p.material_index = k
    return obj


def revolve(profile, mats, loc=(0, 0, 0), seg=48, pick=None, wobble=None, rot=(0, 0, 0)):
    """Surface of revolution around local Z. profile = [(radius, z), ...] bottom to top.
    pick(i, j, theta, z) -> material index. wobble(theta, z) -> radius multiplier."""
    if not isinstance(mats, (list, tuple)):
        mats = [mats]
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r < 1e-6:
            v = bm.verts.new((0, 0, z))
            rings.append([v] * seg)
        else:
            ring = []
            for i in range(seg):
                th = TAU * i / seg
                rr = r * (wobble(th, z) if wobble else 1.0)
                ring.append(bm.verts.new((rr * math.cos(th), rr * math.sin(th), z)))
            rings.append(ring)
    idx = []
    for j in range(len(profile) - 1):
        for i in range(seg):
            i2 = (i + 1) % seg
            quad = [rings[j][i], rings[j][i2], rings[j + 1][i2], rings[j + 1][i]]
            vs = []
            for v in quad:
                if v not in vs:
                    vs.append(v)
            if len(vs) < 3:
                continue
            bm.faces.new(vs)
            th = TAU * (i + 0.5) / seg
            zc = 0.5 * (profile[j][1] + profile[j + 1][1])
            idx.append(pick(i, j, th, zc) if pick else 0)
    return _link(bm, "rev", mats, idx, loc, rot)


def tube(pts, r, mats, pick=None, n=20, caps=True):
    """Sweeps a circle along a polyline. pick(k, i, s, phi) -> material index."""
    if not isinstance(mats, (list, tuple)):
        mats = [mats]
    pts = [Vector(p) for p in pts]
    tans = []
    for k in range(len(pts)):
        a = pts[max(k - 1, 0)]
        b = pts[min(k + 1, len(pts) - 1)]
        tans.append((b - a).normalized())
    t0 = tans[0]
    up = Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0))
    nrm = (up - up.dot(t0) * t0).normalized()
    bm = bmesh.new()
    rings, svals = [], []
    s = 0.0
    for k, (p, t) in enumerate(zip(pts, tans)):
        if k:
            s += (p - pts[k - 1]).length
        nrm = (nrm - nrm.dot(t) * t).normalized()
        b = t.cross(nrm)
        ring = []
        for i in range(n):
            ph = TAU * i / n
            ring.append(bm.verts.new(p + r * (math.cos(ph) * nrm + math.sin(ph) * b)))
        rings.append(ring)
        svals.append(s)
    idx = []
    for k in range(len(pts) - 1):
        for i in range(n):
            i2 = (i + 1) % n
            bm.faces.new([rings[k][i], rings[k][i2], rings[k + 1][i2], rings[k + 1][i]])
            idx.append(pick(k, i, 0.5 * (svals[k] + svals[k + 1]), TAU * (i + 0.5) / n) if pick else 0)
    obj = _link(bm, "tube", mats, idx)
    if caps:
        for p in (pts[0], pts[-1]):
            sphere(r, tuple(p), mats[0], seg=n, rings=max(6, n // 2))
    return obj


def ring(major, minor, loc, mat, rot=(0, 0, 0), ms=40, ns=12):
    """Torus with controllable resolution (build_assets.torus is 48x16)."""
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=ms,
                                     minor_segments=ns, location=loc, rotation=rot)
    return finish(bpy.context.active_object, mat)


def densify(profile, steps=4):
    """Linearly subdivides a revolve profile so face-based stripes read smoothly."""
    out = [profile[0]]
    for (r0, z0), (r1, z1) in zip(profile[:-1], profile[1:]):
        for k in range(1, steps + 1):
            t = k / steps
            out.append((r0 + (r1 - r0) * t, z0 + (z1 - z0) * t))
    return out


def paint(obj, mat, pred, local=False):
    """Appends mat and assigns it to every face whose centre matches pred(Vector)."""
    bpy.context.view_layer.update()
    obj.data.materials.append(mat)
    k = len(obj.data.materials) - 1
    mw = obj.matrix_world
    for p in obj.data.polygons:
        c = p.center if local else mw @ p.center
        if pred(c):
            p.material_index = k
    return obj


def keep_faces(obj, pred):
    """Deletes faces whose local centre does not satisfy pred."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    dead = [f for f in bm.faces if not pred(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def swirl_disc(r, loc, ca, cb, thick=0.3, rotz=0.0, rotx=0.0, turns=2.0, seg=40, sides=(-1, 1)):
    """Flat swirl lollipop candy facing -Y (before rotation): a domed disc in ca with a
    raised spiral ribbon in cb on both faces."""
    before = set(mesh_objects())
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r,
                                         rotation=(math.radians(90), 0, 0))
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    o.scale = (1, thick, 1)
    bpy.ops.object.transform_apply(scale=True)
    finish(o, M(ca, 0.25, 0.7))
    parts = [o]
    rib = r * 0.1
    n = int(28 + 34 * turns * min(1.0, r / 0.8))
    ring_n = 6 if r < 0.5 else 8
    for side in sides:
        pts = []
        for k in range(n + 1):
            t = k / n
            rr = r * (0.06 + 0.8 * t)
            ang = side * t * turns * TAU
            surf = thick * r * math.sqrt(max(0.0, 1 - (rr / r) ** 2))
            pts.append((rr * math.cos(ang), side * (surf - rib * 0.45), rr * math.sin(ang)))
        parts.append(tube(pts, rib, [M(cb, 0.25, 0.7)], n=ring_n))
    group = [x for x in mesh_objects() if x not in before]
    bpy.ops.object.select_all(action="DESELECT")
    for x in group:
        x.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.join()
    o.rotation_euler = (rotx, 0, rotz)
    o.location = loc
    return o


def lollipop(base, height, r, ca, cb, rotz=0.0, stick_r=0.07, seg=40):
    x, y, z = base
    cylinder(stick_r, height - r * 0.6, (x, y, z + (height - r * 0.6) / 2), M("white"), verts=12, bevel=0.0)
    swirl_disc(r, (x, y, z + height), ca, cb, rotz=rotz, seg=seg)


def spiral_pick(stripes, pitch, ncol=2):
    return lambda i, j, th, z: int((th / TAU * stripes + z * pitch) % 1.0 * ncol) % ncol


def gumdrop(loc, r, col, rot=(0, 0, 0)):
    s = r / 0.2
    prof = [(0, 0), (0.2, 0), (0.205, 0.05), (0.19, 0.14), (0.15, 0.22), (0.08, 0.28), (0, 0.295)]
    return revolve([(a * s, b * s) for a, b in prof], [M(col, 0.45, 0.35)], loc=loc, seg=24, rot=rot)


def sprinkle(p, n, rnd, length=0.2, r=0.035):
    col = rnd.choice(["lemon", "mint", "sky", "lilac", "white", "coral"])
    t = n.cross(Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))).normalized()
    o = cylinder(r, length, tuple(p + n * (r * 0.4)), M(col, 0.3, 0.6), verts=8, bevel=0.0)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(t)
    return o


def cloud(cx, cy, cz, rx, ry, h, seed=1, n=10, cols=("cloud",)):
    """Fluffy cloud mass centred at (cx, cy, cz), roughly 2rx x 2ry x h."""
    rnd = random.Random(seed)
    sphere(1.0, (cx, cy, cz), CLOUD(cols[0]), scale=(rx * 0.82, ry * 0.82, h * 0.42), seg=40, rings=20)
    for k in range(n):
        a = TAU * k / n + rnd.uniform(-0.15, 0.15)
        pr = h * rnd.uniform(0.42, 0.58)
        px = cx + math.cos(a) * (rx - pr * 0.9)
        py = cy + math.sin(a) * (ry - pr * 0.9)
        pz = cz + rnd.uniform(-0.12, 0.12) * h
        sphere(pr, (px, py, pz), CLOUD(cols[k % len(cols)]), scale=(1.15, 1.15, 0.85), seg=28, rings=14)
    for k in range(max(2, n // 3)):
        a = rnd.uniform(0, TAU)
        pr = h * rnd.uniform(0.35, 0.45)
        sphere(pr, (cx + math.cos(a) * rx * 0.35, cy + math.sin(a) * ry * 0.35, cz - h * 0.25),
               CLOUD(cols[(k + 1) % len(cols)]), scale=(1.2, 1.2, 0.8), seg=24, rings=12)


def cupcake(loc, s, wrap, frost, seg=32):
    """Cupcake with fluted wrapper, origin at the bottom. Height ~1.0*s."""
    x, y, z = loc
    revolve([(0, 0), (0.3 * s, 0), (0.32 * s, 0.05 * s), (0.4 * s, 0.45 * s), (0.36 * s, 0.47 * s),
             (0, 0.47 * s)], [M(wrap)], loc=(x, y, z), seg=seg,
            wobble=lambda th, zz: 1.0 + 0.06 * math.cos(12 * th))
    for k, (rr, h) in enumerate([(0.34, 0.5), (0.27, 0.66), (0.18, 0.8)]):
        ring(rr * s * 0.72, rr * s * 0.42, (x, y, z + h * s), M(frost, 0.35, 0.5), ms=24, ns=10)
    sphere(0.1 * s, (x, y, z + 0.93 * s), M("coral", 0.2, 0.8), seg=16, rings=8)


# --- scene helpers -------------------------------------------------------------

def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def apply_all():
    bpy.context.view_layer.update()
    objs = mesh_objects()
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def transform_all(mat):
    bpy.context.view_layer.update()
    for o in mesh_objects():
        o.matrix_world = mat @ o.matrix_world


def ship(name, origin="base"):
    """Applies transforms, moves the origin (base: bottom centre stays at z=0 after
    shifting min z; none: keep as built) and exports. Prints bbox and tri count."""
    apply_all()
    if origin == "base":
        zmin = min(v.co.z for o in mesh_objects() for v in o.data.vertices)
        for o in mesh_objects():
            o.location.z -= zmin
        apply_all()
    export(name)
    obj = bpy.context.scene.objects[name]
    dg = bpy.context.evaluated_depsgraph_get()
    me = obj.evaluated_get(dg).to_mesh()
    me.calc_loop_triangles()
    tris = len(me.loop_triangles)
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    print(f"ASSET {name}: godot X {min(xs):.2f}..{max(xs):.2f}  Y {min(zs):.2f}..{max(zs):.2f}  "
          f"Z {-max(ys):.2f}..{-min(ys):.2f}  tris {tris}")


# --- assets --------------------------------------------------------------------

def build_candy_castle():
    reset()
    rnd = random.Random(7)
    cloud(0, 0, 1.0, 4.4, 4.1, 1.7, seed=3, n=12, cols=("cloud", "blush"))
    # Chocolate cake island with vanilla filling and pink frosting.
    revolve([(0, 1.3), (4.2, 1.3), (4.5, 1.42), (4.6, 1.7), (4.6, 3.1), (0, 3.1)],
            [M("chocolate", 0.35, 0.4)], seg=64)
    ring(4.6, 0.17, (0, 0, 2.25), M("vanilla"))
    revolve([(0, 2.95), (4.5, 2.95), (4.72, 3.05), (4.77, 3.22), (4.66, 3.4), (4.4, 3.47), (0, 3.47)],
            [M("pink", 0.25, 0.7)], seg=64)
    for k in range(20):
        a = TAU * k / 20 + rnd.uniform(-0.08, 0.08)
        ln = rnd.uniform(0.25, 0.8)
        sphere(0.2, (4.66 * math.cos(a), 4.66 * math.sin(a), 3.02 - ln * 0.35), M("pink", 0.25, 0.7),
               scale=(1, 1, 1 + ln * 1.4), seg=12, rings=8)
    TOP = 3.47
    H = 1.7
    HALF = 2.55
    wz = TOP + H / 2 - 0.1
    wafer, line = M("wafer", 0.4, 0.35), M("waferdark", 0.4, 0.35)
    for sy in (-1, 1):
        cube((5.1, 0.45, H), (0, sy * HALF, wz), wafer, bevel=0.06)
        cube((0.45, 5.1, H), (sy * HALF, 0, wz), wafer, bevel=0.06)
        for k in range(-4, 5):
            u = k * 0.45
            cube((0.06, 0.5, H - 0.3), (u, sy * HALF, wz), line, bevel=0.0)
            cube((0.5, 0.06, H - 0.3), (sy * HALF, u, wz), line, bevel=0.0)
        for zz in (wz - 0.45, wz, wz + 0.45):
            cube((4.5, 0.52, 0.06), (0, sy * HALF, zz), line, bevel=0.0)
            cube((0.52, 4.5, 0.06), (sy * HALF, 0, zz), line, bevel=0.0)
        for k in range(-2, 3):
            u = k * 0.72
            for o in (cube((0.42, 0.56, 0.42), (u, sy * HALF, TOP + H + 0.02), M("pink"), bevel=0.1),
                      cube((0.56, 0.42, 0.42), (sy * HALF, u, TOP + H + 0.02), M("pink"), bevel=0.1)):
                o.modifiers["Bevel"].segments = 3
    # Gate with a candy-cane frame on the front (-Y) wall.
    cube((1.0, 0.6, 1.1), (0, -HALF, TOP + 0.45), M("chocolate", 0.3), bevel=0.04)
    cylinder(0.5, 0.6, (0, -HALF, TOP + 1.0), M("chocolate", 0.3), rot=(math.radians(90), 0, 0), bevel=0.04)
    path = [(-0.64, -2.88, TOP - 0.1 + 0.1 * i) for i in range(12)]
    path += [(0.64 * math.cos(math.pi - math.pi * i / 24), -2.88, TOP + 1.0 + 0.64 * math.sin(math.pi * i / 24))
             for i in range(1, 24)]
    path += [(0.64, -2.88, TOP + 1.0 - 0.1 * i) for i in range(12)]
    tube(path, 0.09, [M("white"), M("pink")], n=14,
         pick=lambda k, i, s, ph: int(((s / 0.35 + ph / TAU) % 1.0) < 0.45))
    # Corner towers with striped cone roofs and lollipop flags.
    towers = [((-1, -1), "mint", "pink"), ((1, -1), "sky", "lemon"),
              ((1, 1), "lilac", "mint"), ((-1, 1), "lemon", "lilac")]
    roof = [(0, 0), (1.12, 0), (1.12, 0.1), (0.95, 0.45), (0.6, 1.15), (0.25, 1.8), (0, 2.1)]
    for (sx, sy), tc, rc in towers:
        cx, cy = sx * HALF, sy * HALF
        cylinder(0.88, 3.7, (cx, cy, TOP + 1.5), M(tc), verts=48, bevel=0.06)
        z0 = TOP + 3.3
        revolve(densify(roof, 3), [M(rc), M("white")], loc=(cx, cy, z0), seg=72, pick=spiral_pick(6, 0.9))
        ring(1.1, 0.11, (cx, cy, z0 + 0.06), M("white"))
        lollipop((cx, cy, z0 + 2.0), 1.0, 0.3, "pink" if rc != "pink" else "lilac", "white")
        for a in (math.atan2(0, sx), math.atan2(sy, 0)):
            wx, wy = cx + 0.86 * math.cos(a), cy + 0.86 * math.sin(a)
            cube((0.16, 0.32, 0.5), (wx, wy, TOP + 2.2), M("chocolate", 0.3), bevel=0.06, rot=(0, 0, a))
            sphere(0.16, (wx, wy, TOP + 2.45), M("chocolate", 0.3), scale=(0.5, 1, 1), seg=16, rings=8).rotation_euler = (0, 0, a)
    # Central keep.
    kx, ky = 0.0, 0.5
    cylinder(1.3, 4.9, (kx, ky, TOP + 2.2), M("pink"), verts=56, bevel=0.08)
    ring(1.31, 0.12, (kx, ky, TOP + 2.6), M("white"))
    z0 = TOP + 4.6
    revolve(densify([(a * 1.4, b * 1.35) for a, b in roof], 4), [M("lilac"), M("white")], loc=(kx, ky, z0), seg=80,
            pick=spiral_pick(8, 0.7))
    ring(1.55, 0.13, (kx, ky, z0 + 0.07), M("white"))
    lollipop((kx, ky, z0 + 2.8), 1.1, 0.48, "mint", "white")
    sphere(0.42, (kx, ky - 1.28, TOP + 3.6), M("lemon", 0.25, 0.7), scale=(1, 0.3, 1))
    ring(0.42, 0.07, (kx, ky - 1.31, TOP + 3.6), M("white"), rot=(math.radians(90), 0, 0))
    # Front yard: cotton candy trees and gumdrops.
    for x, c1, c2 in ((-1.9, "mint", "pink"), (1.9, "lilac", "sky")):
        cylinder(0.12, 0.6, (x, -3.55, TOP + 0.25), M("vanilla"), verts=12, bevel=0.0)
        sphere(0.5, (x, -3.55, TOP + 0.85), M(c1, 0.4, 0.3), seg=32, rings=16)
        sphere(0.34, (x + 0.1, -3.55, TOP + 1.25), M(c2, 0.4, 0.3), seg=32, rings=16)
    for x, c in ((-0.7, "lemon"), (0.75, "mint"), (-3.1, "sky"), (3.1, "pink")):
        gumdrop((x, -3.7 if abs(x) < 1 else -2.9, TOP - 0.03), 0.22, c)
    ship("candy_castle")


def build_gingerbread_house():
    reset()
    # Island: chocolate block with 2x2 mint pillow tiles and a cloud.
    cube((5.0, 5.0, 1.3), (0, 0, -0.65), M("chocolate", 0.35, 0.4), bevel=0.3)
    for ix in (-1, 1):
        for iy in (-1, 1):
            cube((2.4, 2.4, 0.42), (ix * 1.24, iy * 1.24, 0.1), M("mint"), bevel=0.17)
    cloud(0, 0, -1.55, 3.0, 2.8, 1.3, seed=5, n=9, cols=("cloud", "blush"))
    base = 0.3
    gb = M("gingerbread", 0.45, 0.3)
    icing = M("white", 0.35, 0.5)
    # House body: pentagon profile (YZ) extruded along X.
    bm = bmesh.new()
    prof = [(-1.2, 0), (1.2, 0), (1.2, 1.8), (0, 2.9), (-1.2, 1.8)]
    L = [bm.verts.new((-1.5, y, base + z)) for y, z in prof]
    R_ = [bm.verts.new((1.5, y, base + z)) for y, z in prof]
    bm.faces.new(list(reversed(L)))
    bm.faces.new(R_)
    for i in range(5):
        j = (i + 1) % 5
        bm.faces.new([L[i], L[j], R_[j], R_[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    body = _link(bm, "house", [gb], None, smooth=False)
    mod = body.modifiers.new("Bevel", "BEVEL")
    mod.width = 0.1
    mod.segments = 4
    mod.limit_method = "ANGLE"
    body.data.shade_smooth()
    # Roof slabs: pink frosting on gingerbread.
    ang = math.atan2(1.1, 1.2)
    slope = math.hypot(1.2, 1.1)
    for side in (-1, 1):
        d = Vector((0, -side * 1.2, 1.1)) / slope        # eave -> ridge
        nrm = Vector((0, side * 1.1, 1.2)) / slope
        eave = Vector((0, side * 1.2, base + 1.8))
        ridge = Vector((0, 0, base + 2.9))
        a = ridge + d * 0.1
        b = eave - d * 0.45
        c = (a + b) / 2 + nrm * 0.11
        ln = (a - b).length
        rot = (-side * ang, 0, 0)
        cube((3.6, ln, 0.2), tuple(c), gb, bevel=0.07, rot=rot)
        cube((3.4, ln - 0.15, 0.1), tuple(c + nrm * 0.12 + d * 0.05), M("pink", 0.25, 0.7), bevel=0.05, rot=rot)
        # icing beads along the eave
        edge = b + nrm * 0.02
        for k in range(15):
            x = -1.75 + k * 0.25
            sphere(0.1, (x, edge.y, edge.z), icing, seg=16, rings=8)
        # gumdrops on the roof
        for k, col in enumerate(["lemon", "mint", "lilac", "sky"]):
            p = (a + b) / 2 + nrm * 0.27 + d * (0.35 if k % 2 else -0.3)
            gumdrop((-1.2 + k * 0.8, p.y, p.z - 0.02), 0.14, col, rot=rot)
    cylinder(0.14, 3.7, (0, 0, base + 2.98), icing, rot=(0, math.radians(90), 0), bevel=0.05)
    for k, col in enumerate(["pink", "lemon", "mint", "lilac", "sky"]):
        gumdrop((-1.4 + k * 0.7, 0, base + 3.05), 0.17, col)
    # Chimney.
    cube((0.5, 0.5, 1.2), (0.95, 0.55, base + 2.85), M("pink"), bevel=0.08)
    cube((0.64, 0.64, 0.16), (0.95, 0.55, base + 3.48), icing, bevel=0.06)
    # Icing corners.
    for sx in (-1, 1):
        for sy in (-1, 1):
            cylinder(0.08, 1.8, (sx * 1.5, sy * 1.2, base + 0.9), icing, verts=12, bevel=0.0)
    # Door with candy-cane frame on -Y face.
    cube((0.7, 0.12, 0.9), (0, -1.22, base + 0.45), M("chocolate", 0.3), bevel=0.03)
    cylinder(0.35, 0.12, (0, -1.22, base + 0.9), M("chocolate", 0.3), rot=(math.radians(90), 0, 0), bevel=0.03)
    path = [(-0.46, -1.3, base - 0.05 + 0.095 * i) for i in range(11)]
    path += [(0.46 * math.cos(math.pi - math.pi * i / 20), -1.3, base + 0.9 + 0.46 * math.sin(math.pi * i / 20))
             for i in range(1, 20)]
    path += [(0.46, -1.3, base + 0.9 - 0.095 * i) for i in range(11)]
    tube(path, 0.075, [M("white"), M("pink")], n=12,
         pick=lambda k, i, s, ph: int(((s / 0.28 + ph / TAU) % 1.0) < 0.45))
    sphere(0.05, (0.2, -1.3, base + 0.55), M("gold", 0.25, 0.6), seg=12, rings=6)
    # Windows on both long sides + round windows on the gables.
    for sy in (-1, 1):
        for x in (-1.0, 1.0):
            cube((0.6, 0.1, 0.6), (x, sy * 1.23, base + 1.15), icing, bevel=0.04)
            cube((0.46, 0.1, 0.46), (x, sy * 1.26, base + 1.15), M("lemon", 0.25, 0.7), bevel=0.03)
            cube((0.05, 0.1, 0.46), (x, sy * 1.29, base + 1.15), icing, bevel=0.0)
            cube((0.46, 0.1, 0.05), (x, sy * 1.29, base + 1.15), icing, bevel=0.0)
    for sx in (-1, 1):
        sphere(0.3, (sx * 1.52, 0, base + 2.0), M("lemon", 0.25, 0.7), scale=(0.25, 1, 1))
        ring(0.3, 0.06, (sx * 1.56, 0, base + 2.0), icing, rot=(0, math.radians(90), 0))
        sphere(0.36, (sx * 1.51, 0, base + 1.0), M("lilac", 0.25, 0.7), scale=(0.2, 1, 1))
    # Yard: lollipops and gumdrops.
    lollipop((-1.9, -1.9, base), 1.3, 0.3, "mint", "white")
    lollipop((1.95, -1.7, base), 1.0, 0.25, "lilac", "white", rotz=0.3)
    for x, y, c in ((-2.0, 1.9, "pink"), (2.0, 1.95, "lemon"), (1.4, -2.05, "sky"), (-1.2, -2.1, "lemon")):
        gumdrop((x, y, base - 0.02), 0.2, c)
    ship("gingerbread_house")


def mountain(cx, cy, cz, R, H, col, seed):
    rnd = random.Random(seed)

    def rad(z):
        t = min(max(z / H, 0.0), 1.0)
        return R * (1.0 - t ** 1.6) ** 0.62

    prof = [(0, 0)] + [(rad(H * t), H * t) for t in [i / 24 for i in range(24)]] + [(0, H)]
    revolve(prof, [M(col, 0.14, 0.9)], loc=(cx, cy, cz), seg=56)
    # Snow cap: cream shell draped over the top with a drippy scalloped edge.
    seg, rows = 56, 16
    ph1, ph2 = rnd.uniform(0, TAU), rnd.uniform(0, TAU)
    bm = bmesh.new()
    grid = []
    for j in range(rows + 1):
        u = j / rows
        ring = []
        for i in range(seg):
            th = TAU * i / seg
            zb = H * (0.7 + 0.04 * math.sin(3 * th + ph1)) - H * 0.09 * max(0.0, math.sin(7 * th + ph2)) ** 3
            z = zb + (H - zb) * (u ** 0.8)
            r = rad(z) + 0.07
            if j == rows:
                r, z = 0.0, H + 0.07
            ring.append((r * math.cos(th), r * math.sin(th), z))
        grid.append(ring)
    vs = [[bm.verts.new(p) for p in ring] for ring in grid[:-1]]
    top = bm.verts.new(grid[-1][0])
    for j in range(rows - 1):
        for i in range(seg):
            i2 = (i + 1) % seg
            bm.faces.new([vs[j][i], vs[j][i2], vs[j + 1][i2], vs[j + 1][i]])
    for i in range(seg):
        bm.faces.new([vs[-1][i], vs[-1][(i + 1) % seg], top])
    cap = _link(bm, "cap", [M("cream", 0.3, 0.5)], None, loc=(cx, cy, cz))
    sol = cap.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.08
    sol.offset = -1.0
    # Rounded drip beads at the bottom edge.
    for i in range(0, seg, 4):
        th = TAU * i / seg
        zb = H * (0.7 + 0.04 * math.sin(3 * th + ph1)) - H * 0.09 * max(0.0, math.sin(7 * th + ph2)) ** 3
        r = rad(zb) + 0.02
        sphere(0.1 + R * 0.015, (cx + r * math.cos(th), cy + r * math.sin(th), cz + zb), M("cream", 0.3, 0.5),
               seg=16, rings=8)


def build_jelly_mountains():
    reset()
    cloud(0, 0, 0.9, 7.0, 3.6, 1.8, seed=11, n=14, cols=("cloud", "blush"))
    mountain(0.2, 0.9, 0.9, 3.3, 6.6, "mint", 1)
    mountain(-3.9, -0.1, 0.9, 2.6, 5.0, "lilac", 2)
    mountain(3.8, -0.3, 0.9, 2.4, 4.2, "pink", 3)
    for x, y, c, r in ((-1.6, -2.2, "lemon", 0.45), (1.5, -2.4, "sky", 0.38), (5.6, -1.6, "lemon", 0.3),
                       (-5.8, -1.3, "mint", 0.35)):
        gumdrop((x, y, 1.35), r, c)
    ship("jelly_mountains")


HUB_Z = 5.1
WHEEL_R = 3.2


def build_ferris_wheel_rotor():
    """Wheel in the XZ plane, spinning around Blender Y (= Godot Z). Origin = hub centre."""
    reset()
    rnd = random.Random(21)
    rot90 = (math.radians(90), 0, 0)
    for sy in (-1, 1):
        y = sy * 0.6
        # Frosted donut rim.
        ring(WHEEL_R, 0.2, (0, y, 0), M("dough", 0.45, 0.3), rot=rot90, ms=72, ns=12)
        fr = ring(WHEEL_R, 0.215, (0, y, 0), M("pink", 0.25, 0.7), rot=rot90, ms=72, ns=16)
        # local torus: Z is the ring axis -> world Y after rotation; keep the outer face.
        keep_faces(fr, lambda c: (c.z * sy * -1) > -0.05 + 0.06 * math.sin(9 * math.atan2(c.y, c.x)))
        for k in range(28):
            a = TAU * k / 28 + rnd.uniform(-0.05, 0.05)
            ph = rnd.uniform(-0.9, 0.9)
            rr = WHEEL_R + 0.215 * math.sin(ph)
            p = Vector((rr * math.cos(a), y + sy * 0.215 * math.cos(ph), rr * math.sin(a)))
            n = Vector((math.sin(ph) * math.cos(a), sy * math.cos(ph), math.sin(ph) * math.sin(a)))
            sprinkle(p, n, rnd, length=0.14, r=0.026)
        ring(1.5, 0.08, (0, y, 0), M("lilac"), rot=rot90, ms=48, ns=8)
        for k in range(8):
            a = TAU * k / 8
            ca, sa = math.cos(a), math.sin(a)
            mid = 1.65
            cylinder(0.06, WHEEL_R - 0.35, (ca * mid, y, sa * mid), M("white"), verts=12, bevel=0.0,
                     rot=(0, math.pi / 2 - a, 0))
            swirl_disc(0.34, (ca * 2.35, y + sy * 0.02, sa * 2.35), ["mint", "lemon", "sky", "lilac"][k % 4],
                       "white", thick=0.25, rotz=0 if sy < 0 else math.pi, seg=24, sides=(-1,))
    # Hub: axle + big swirl lollipop caps.
    cylinder(0.24, 1.9, (0, 0, 0), M("white"), rot=rot90, bevel=0.05)
    for sy in (-1, 1):
        swirl_disc(0.72, (0, sy * 0.74, 0), "pink", "white", thick=0.2, rotz=0 if sy < 0 else math.pi, turns=2.5, sides=(-1,))
    # Cupcake gondolas hanging from crossbars between the rims.
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        px, pz = WHEEL_R * math.cos(a), WHEEL_R * math.sin(a)
        cylinder(0.05, 1.2, (px, 0, pz), M("lemon"), rot=rot90, verts=12, bevel=0.0)
        cylinder(0.035, 0.32, (px, 0, pz - 0.16), M("white"), verts=8, bevel=0.0)
        ring(0.07, 0.025, (px, 0, pz - 0.02), M("white"), rot=rot90, ms=12, ns=6)
        cupcake((px, 0, pz - 1.18), 0.95, ["sky", "lemon", "lilac", "mint"][k % 4],
                ["pink", "white", "pink", "vanilla"][k % 4])
    ship("ferris_wheel_rotor", origin="none")


def build_ferris_wheel_stand():
    reset()
    cube((5.6, 3.6, 0.4), (0, 0, 0.2), M("chocolate", 0.35, 0.4), bevel=0.15)
    cube((5.2, 3.2, 0.3), (0, 0, 0.45), M("mint"), bevel=0.12)
    stripe = lambda k, i, s, ph: int(((s / 0.5 + ph / TAU) % 1.0) < 0.45)
    for sy in (-1, 1):
        y = sy * 1.12
        top = Vector((0, y, HUB_Z))
        for sx in (-1, 1):
            foot = Vector((sx * 2.1, y, 0.5))
            pts = [foot.lerp(top, t / 40) for t in range(41)]
            tube(pts, 0.14, [M("white"), M("pink")], n=16, pick=stripe)
            sphere(0.3, (sx * 2.1, y, 0.6), M("lilac"), scale=(1, 1, 0.6), seg=24, rings=12)
        cylinder(0.08, 2.4, (0, y, 2.1), M("white"), rot=(0, math.radians(90), 0), verts=12, bevel=0.0)
        cylinder(0.32, 0.36, (0, sy * 1.16, HUB_Z), M("lemon"), rot=(math.radians(90), 0, 0), bevel=0.06)
        gumdrop((0, sy * 1.33, HUB_Z), 0.22, "mint", rot=(-sy * math.radians(90), 0, 0))
    # A little ticket booth lollipop and gumdrops on the platform.
    lollipop((-2.2, -1.2, 0.6), 1.2, 0.3, "pink", "white")
    lollipop((2.2, 1.2, 0.6), 1.0, 0.26, "sky", "white")
    for x, y, c in ((2.2, -1.25, "lemon"), (-2.2, 1.2, "lilac")):
        gumdrop((x, y, 0.58), 0.22, c)
    ship("ferris_wheel_stand")


def build_hot_air_balloon():
    reset()
    # Cupcake-wrapper basket, origin at its bottom.
    revolve([(0, 0), (0.42, 0), (0.44, 0.05), (0.56, 0.62), (0.5, 0.64), (0, 0.64)], [M("sky")], seg=48,
            wobble=lambda th, z: 1.0 + 0.06 * math.cos(16 * th))
    ring(0.54, 0.07, (0, 0, 0.64), M("white"))
    sphere(0.45, (0, 0, 0.62), M("chocolate", 0.4, 0.3), scale=(1, 1, 0.35), seg=32, rings=16)
    # Envelope with pastel gores.
    R, ZC = 1.35, 3.0
    prof = [(0, 1.42), (0.3, 1.36)]
    tn = 12
    p_end = 0.72 * math.pi
    r_end, z_end = R * math.sin(p_end), ZC + R * math.cos(p_end)
    for i in range(1, tn + 1):
        t = i / tn
        # smooth ease from the neck to the sphere
        e = 1 - (1 - t) ** 2
        prof.append((0.3 + (r_end - 0.3) * (t ** 0.85), 1.36 + (z_end - 1.36) * e))
    for i in range(1, 25):
        ph = p_end - p_end * i / 24
        prof.append((R * math.sin(ph), ZC + R * math.cos(ph)))
    prof[-1] = (0, ZC + R)
    gores = ["pink", "white", "mint", "white", "lilac", "white", "lemon", "white"]
    revolve(prof, [M(c, 0.25, 0.7) for c in gores], seg=64, pick=lambda i, j, th, z: (i // 4) % 8)
    ring(0.33, 0.08, (0, 0, 1.38), M("lemon"))
    sphere(0.2, (0, 0, ZC + R + 0.1), M("coral", 0.2, 0.8), seg=24, rings=12)
    cylinder(0.02, 0.2, (0.04, 0, ZC + R + 0.35), M("chocolate"), verts=6, bevel=0.0, rot=(0, 0.3, 0))
    # Ropes from the basket rim into the envelope.
    for k in range(4):
        a = TAU * k / 4 + math.pi / 4
        p0 = Vector((0.5 * math.cos(a), 0.5 * math.sin(a), 0.62))
        p1 = Vector((0.52 * math.cos(a), 0.52 * math.sin(a), 1.72))
        tube([p0, p1], 0.025, [M("white")], n=8, caps=False)
    ship("hot_air_balloon")


def build_cotton_candy_cloud_big():
    reset()
    rnd = random.Random(42)
    cols = ["blush", "cloud", "blush", "pink"]
    puffs = [(0, 0, 1.4, 1.8), (-2.0, 0.2, 1.1, 1.4), (2.1, -0.1, 1.15, 1.45), (-3.3, -0.1, 0.8, 0.95),
             (3.35, 0.1, 0.85, 1.0), (-1.0, -0.8, 1.0, 1.2), (1.1, -0.9, 1.0, 1.2), (0.8, 0.9, 1.7, 1.2),
             (-1.1, 0.8, 1.6, 1.1), (0.0, -1.1, 0.8, 1.0), (-2.4, -0.9, 0.7, 0.9), (2.5, 0.9, 0.9, 0.95),
             (0.3, 0.2, 2.5, 1.0), (-2.6, 0.9, 1.0, 0.9), (2.6, -0.9, 0.75, 0.85)]
    for k, (x, y, z, r) in enumerate(puffs):
        c = cols[k % len(cols)] if k else "blush"
        mat = CLOUD(c) if c != "pink" else material("blush", 0.55, 0.05)
        sphere(r, (x, y, z), mat, scale=(1.1, 1.0, 0.88), seg=40, rings=20)
    # flat-ish base
    sphere(1.0, (0, 0, 0.75), CLOUD("cloud"), scale=(3.3, 1.3, 0.55), seg=48, rings=24)
    ship("cotton_candy_cloud_big")


def build_lollipop_forest():
    reset()
    revolve([(0, -1.3), (2.6, -1.3), (2.85, -1.1), (2.95, -0.8), (2.95, -0.1), (0, -0.1)],
            [M("chocolate", 0.35, 0.4)], seg=64)
    revolve([(0, -0.25), (2.95, -0.25), (3.08, -0.12), (3.1, 0.05), (2.98, 0.2), (2.7, 0.27), (0, 0.27)],
            [M("mint")], seg=64)
    ring(2.95, 0.12, (0, 0, -0.7), M("vanilla"))
    cloud(0, 0, -1.8, 3.2, 3.0, 1.4, seed=9, n=10, cols=("cloud", "blush"))
    base = 0.25
    pops = [(-0.3, 0.6, 6.0, 1.15, "pink", "white", 0.0),
            (1.5, 0.3, 4.6, 0.95, "mint", "white", 0.3),
            (-1.8, 0.1, 4.0, 0.85, "lilac", "white", -0.35),
            (0.6, -1.3, 2.9, 0.7, "lemon", "pink", 0.2),
            (-1.1, -1.5, 2.2, 0.6, "sky", "white", -0.2),
            (2.1, -1.2, 2.0, 0.55, "pink", "lemon", 0.4),
            (0.3, 2.0, 3.6, 0.8, "sky", "white", 0.1)]
    for x, y, h, r, ca, cb, rz in pops:
        cylinder(0.05 + r * 0.06, h - r * 0.5, (x, y, base + (h - r * 0.5) / 2 - 0.05), M("white"), verts=16,
                 bevel=0.0)
        swirl_disc(r, (x, y, base + h), ca, cb, rotz=rz, thick=0.28, seg=48)
    # A round ball lollipop.
    cylinder(0.08, 1.9, (-2.2, 1.6, base + 0.9), M("white"), verts=12, bevel=0.0)
    b = sphere(0.5, (0, 0, 0), M("lemon", 0.25, 0.7), seg=40, rings=20)
    paint(b, M("white", 0.25, 0.7), lambda c: ((math.atan2(c.y, c.x) / TAU * 3 + c.z * 1.4) % 1.0) < 0.45, local=True)
    b.location = (-2.2, 1.6, base + 2.1)
    for x, y, c in ((1.2, 1.3, "lilac"), (-2.3, -0.9, "mint"), (2.2, 0.8, "lemon"), (-0.3, -2.3, "pink")):
        gumdrop((x, y, base - 0.02), 0.24, c)
    ship("lollipop_forest")


def build_donut_planet():
    reset()
    rnd = random.Random(5)
    R, r = 2.0, 1.0
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=72, minor_segments=36)
    finish(bpy.context.active_object, M("dough", 0.5, 0.25))
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r + 0.05, major_segments=72, minor_segments=36)
    fr = finish(bpy.context.active_object, M("pink", 0.25, 0.7))

    def lim(c):
        th = math.atan2(c.y, c.x)
        return -0.05 - 0.4 * max(0.0, math.sin(9 * th + 0.5)) ** 4 + 0.08 * math.sin(4 * th)

    keep_faces(fr, lambda c: c.z > lim(c))
    sol = fr.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.05
    sol.offset = -1.0
    for _ in range(170):
        th = rnd.uniform(0, TAU)
        ph = rnd.uniform(0.35, math.pi - 0.35)  # angle on the tube, 0 = outer equator, pi/2 = top
        n = Vector((math.cos(ph) * math.cos(th), math.cos(ph) * math.sin(th), math.sin(ph)))
        ctr = Vector((R * math.cos(th), R * math.sin(th), 0))
        sprinkle(ctr + n * (r + 0.05), n, rnd, length=0.24, r=0.04)
    # Tilt like a planet.
    transform_all(Matrix.Rotation(math.radians(24), 4, "X") @ Matrix.Rotation(math.radians(-12), 4, "Y"))
    ship("donut_planet", origin="none")


def build_candy_cane_arch():
    reset()
    X, ZL, RA, r = 2.6, 2.05, 2.6, 0.3
    pts = [(-X, 0, 0.45 + (ZL - 0.45) * i / 32) for i in range(32)]
    pts += [(RA * math.cos(math.pi - math.pi * i / 128), 0, ZL + RA * math.sin(math.pi * i / 128)) for i in range(129)]
    pts += [(X, 0, ZL - (ZL - 0.45) * i / 32) for i in range(1, 33)]
    tube(pts, r, [M("white"), M("pink")], n=28,
         pick=lambda k, i, s, ph: int(((s / 0.95 + ph / TAU) % 1.0) < 0.4))
    for sx in (-1, 1):
        cube((1.4, 1.4, 0.55), (sx * X, 0, 0.275), M("mint"), bevel=0.2)
        ring(0.33, 0.1, (sx * X, 0, 0.62), M("white"))
    # Mint bow at the top, front side.
    top = ZL + RA + r
    for sx in (-1, 1):
        sphere(0.45, (sx * 0.45, -0.3, top - 0.1), M("mint"), scale=(1.0, 0.4, 0.65), seg=32, rings=16)
        cube((0.22, 0.12, 0.8), (sx * 0.22, -0.34, top - 0.55), M("mint"), bevel=0.05,
             rot=(0, sx * math.radians(18), 0))
    sphere(0.2, (0, -0.36, top - 0.1), M("mint"), scale=(1, 0.8, 1), seg=24, rings=12)
    ship("candy_cane_arch")


def build_ice_cream_tower():
    reset()
    rnd = random.Random(3)
    # Upside-down waffle cone (truncated), lattice pattern.
    prof = [(0, 0), (1.45, 0), (1.5, 0.08)] + [(1.5 - 0.72 * t / 24, 0.08 + 2.02 * t / 24) for t in range(1, 25)] + [(0, 2.1)]
    revolve(prof, [M("wafer", 0.45, 0.3), M("waferdark", 0.45, 0.3)], seg=64,
            pick=lambda i, j, th, z: int(2 <= j <= 25 and ((i + j) % 5 == 0 or (i - j) % 5 == 0)))
    ring(0.78, 0.14, (0, 0, 2.08), M("white"))
    scoops = [(1.1, 2.85, "mint"), (0.95, 4.1, "pink"), (0.8, 5.2, "vanilla")]
    for R, zc, col in scoops:
        mat = M(col, 0.35, 0.45)
        sphere(R, (0, 0, zc), mat, scale=(1, 1, 0.82), seg=48, rings=24)
        zb = zc - R * 0.62
        for k in range(16):
            a = TAU * k / 16
            sphere(R * 0.2, (math.cos(a) * R * 0.86, math.sin(a) * R * 0.86, zb), mat, seg=16, rings=8)
        for k in range(3):
            a = rnd.uniform(0, TAU)
            ln = rnd.uniform(0.2, 0.4)
            sphere(R * 0.14, (math.cos(a) * R * 0.9, math.sin(a) * R * 0.9, zb - ln * 0.4), mat,
                   scale=(1, 1, 1 + ln * 3), seg=16, rings=8)
    # Sprinkles on the vanilla scoop.
    R, zc = 0.8, 5.2
    for _ in range(40):
        th = rnd.uniform(0, TAU)
        ph = rnd.uniform(0.25, 1.3)
        n = Vector((math.cos(ph) * math.cos(th), math.cos(ph) * math.sin(th), math.sin(ph) * 0.82)).normalized()
        p = Vector((R * math.cos(ph) * math.cos(th), R * math.cos(ph) * math.sin(th), zc + R * 0.82 * math.sin(ph)))
        sprinkle(p, n, rnd, length=0.16, r=0.03)
    # Whipped cream swirl + cherry.
    for k, (rr, h) in enumerate([(0.5, 5.85), (0.38, 6.12), (0.24, 6.36)]):
        ring(rr * 0.7, rr * 0.45, (0, 0, h), M("white", 0.35, 0.5))
    sphere(0.26, (0, 0, 6.62), M("coral", 0.2, 0.8), seg=24, rings=12)
    tube([(0, 0, 6.8), (0.05, 0, 6.95), (0.18, 0, 7.1)], 0.03, [M("chocolate")], n=8)
    # Wafer stick.
    cylinder(0.1, 1.3, (0.55, 0.2, 5.5), M("wafer", 0.45, 0.3), rot=(0, math.radians(28), 0), verts=16, bevel=0.03)
    ship("ice_cream_tower")


BUILDERS = {
    "candy_castle": build_candy_castle,
    "gingerbread_house": build_gingerbread_house,
    "jelly_mountains": build_jelly_mountains,
    "ferris_wheel_rotor": build_ferris_wheel_rotor,
    "ferris_wheel_stand": build_ferris_wheel_stand,
    "hot_air_balloon": build_hot_air_balloon,
    "cotton_candy_cloud_big": build_cotton_candy_cloud_big,
    "lollipop_forest": build_lollipop_forest,
    "donut_planet": build_donut_planet,
    "candy_cane_arch": build_candy_cane_arch,
    "ice_cream_tower": build_ice_cream_tower,
}


# --- preview -------------------------------------------------------------------

def render_preview(path=None, only=None):
    path = path or os.path.join(ROOT, "art", "preview-scenery.png")
    reset()
    rows = [
        [("candy_castle", 0), ("gingerbread_house", 0), ("jelly_mountains", 0), ("ferris_wheel", 0),
         ("hot_air_balloon", 0)],
        [("cotton_candy_cloud_big", 0), ("lollipop_forest", 0), ("donut_planet", 3.2), ("candy_cane_arch", 0),
         ("ice_cream_tower", 0)],
    ]
    if only:
        rows = [[(n, z) for n, z in row if n in only] for row in rows]
        rows = [r for r in rows if r]
    row_z = 0.0
    for row in rows:
        x = 0.0
        row_h = 0.0
        for name, lift in row:
            files = [("ferris_wheel_stand", 0), ("ferris_wheel_rotor", HUB_Z)] if name == "ferris_wheel" else [(name, 0)]
            new = []
            for f, dz in files:
                before = set(bpy.context.scene.objects)
                bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, f"{f}.glb"))
                objs = [o for o in bpy.context.scene.objects if o not in before]
                for o in objs:
                    if o.parent is None:
                        o.location.z += dz
                new += objs
            bpy.context.view_layer.update()
            pts = [o.matrix_world @ Vector(c) for o in new if o.type == "MESH" for c in o.bound_box]
            xmin = min(p.x for p in pts)
            xmax = max(p.x for p in pts)
            zmax = max(p.z for p in pts)
            for o in new:
                if o.parent is None:
                    o.location.x += x - xmin
                    o.location.z += row_z + lift
            x += (xmax - xmin) + 1.5
            row_h = max(row_h, zmax + lift)
        row_z -= row_h + 4.0

    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    direction = Vector((0.35, -1, 0.55)).normalized()
    cam.location = direction * 80
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    pts = [inv @ (o.matrix_world @ Vector(c)) for o in scene.objects if o.type == "MESH" for c in o.bound_box]
    x0, x1 = min(p.x for p in pts), max(p.x for p in pts)
    y0, y1 = min(p.y for p in pts), max(p.y for p in pts)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    cam.location = cam.matrix_world @ Vector((cx, cy, 0))
    w, h = (x1 - x0) * 1.04, (y1 - y0) * 1.06
    res_x = 2400
    res_y = int(res_x * h / w)
    cam_data.ortho_scale = w
    cam_data.clip_end = 400

    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 2.4
    sun.angle = math.radians(8)
    sun_o = bpy.data.objects.new("sun", sun)
    sun_o.rotation_euler = (math.radians(40), math.radians(10), math.radians(25))
    scene.collection.objects.link(sun_o)

    world = bpy.data.worlds.new("w")
    scene.world = world
    try:
        world.use_nodes = True
    except Exception:
        pass
    nt = world.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tex = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.98, 0.72, 0.80, 1)
    ramp.color_ramp.elements[1].color = (0.58, 0.80, 0.97, 1)
    sky_bg = nt.nodes.new("ShaderNodeBackground")
    amb = nt.nodes.new("ShaderNodeBackground")
    amb.inputs["Color"].default_value = (0.85, 0.85, 0.92, 1)
    amb.inputs["Strength"].default_value = 0.6
    lp = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(tex.outputs["Window"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], sky_bg.inputs["Color"])
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(amb.outputs[0], mix.inputs[1])
    nt.links.new(sky_bg.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])

    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("rendered", path, res_x, res_y)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "preview":
        render_preview(only=argv[1:] or None)
    else:
        names = argv or list(BUILDERS)
        for name in names:
            if name == "ferris_wheel":
                build_ferris_wheel_rotor()
                build_ferris_wheel_stand()
            else:
                BUILDERS[name]()
        if not argv:
            render_preview()

"""Candy pinball pieces for Candy Marble.

Run headless from the repo root:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_pinball.py
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_pinball.py -- hoop chute
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_pinball.py -- preview

Same conventions as build_assets.py: 1 Blender unit = 1 game unit, Z-up,
Blender -Y becomes Godot +Z (forward / launch direction).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_assets import *  # noqa: E402,F401,F403
from build_assets import PALETTE, ROOT, OUT  # noqa: E402

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

# Extra tints used only by the pinball kit (friendly colours, no raspberry).
PALETTE.setdefault("lemon_lit", "#FFEF7A")
PALETTE.setdefault("biscuit", "#F3CD98")

SPRINKLE_COLS = ["lemon", "mint", "sky", "cream", "lilac", "coral"]


# --- geometry helpers ---------------------------------------------------------

def link_bm(bm, name, mats, smooth_angle=40.0):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    for m in mats:
        me.materials.append(m)
    return obj


def shade(obj, angle=40.0, flat_faces=()):
    me = obj.data
    for p in me.polygons:
        p.use_smooth = True
    for i in flat_faces:
        me.polygons[i].use_smooth = False
    try:
        me.set_sharp_from_angle(angle=math.radians(angle))
    except Exception:
        pass
    return obj


def ccw(pts):
    area = 0.0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % len(pts)]
        area += x1 * y2 - x2 * y1
    return pts if area > 0 else list(reversed(pts))


def fillet(pts, rad, n=8):
    """Rounds every corner of a 2D polygon with an arc of radius rad."""
    pts = [Vector(p) for p in ccw([tuple(p) for p in pts])]
    out = []
    N = len(pts)
    for i in range(N):
        P, A, B = pts[i], pts[i - 1], pts[(i + 1) % N]
        a = (A - P).normalized()
        b = (B - P).normalized()
        ang = math.acos(max(-1.0, min(1.0, a.dot(b))))
        r = rad[i] if isinstance(rad, (list, tuple)) else rad
        d = r / math.tan(ang / 2)
        t1, t2 = P + a * d, P + b * d
        c = P + (a + b).normalized() * (r / math.sin(ang / 2))
        a1 = math.atan2(t1.y - c.y, t1.x - c.x)
        a2 = math.atan2(t2.y - c.y, t2.x - c.x)
        delta = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        for k in range(n + 1):
            t = a1 + delta * k / n
            q = Vector((c.x + r * math.cos(t), c.y + r * math.sin(t)))
            if not out or (q - out[-1]).length > 1e-5:
                out.append(q)
    if (out[0] - out[-1]).length < 1e-5:
        out.pop()
    return [(p.x, p.y) for p in out]


def circle_hull(centres, R, n=16):
    """Outline of the convex hull of equal circles (centres CCW)."""
    cs = [Vector(c) for c in ccw([tuple(c) for c in centres])]
    N = len(cs)
    out, normals = [], []
    for i in range(N):
        e_in = cs[i] - cs[i - 1]
        e_out = cs[(i + 1) % N] - cs[i]
        a1 = math.atan2(-e_in.x, e_in.y)
        a2 = math.atan2(-e_out.x, e_out.y)
        if a2 < a1:
            a2 += 2 * math.pi
        for k in range(n + 1):
            t = a1 + (a2 - a1) * k / n
            nv = Vector((math.cos(t), math.sin(t)))
            out.append(cs[i] + nv * R)
            normals.append(nv)
    return [(p.x, p.y) for p in out], [(v.x, v.y) for v in normals]


def vertex_normals_2d(pts):
    N = len(pts)
    ns = []
    for i in range(N):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % N])
        e1, e2 = (p1 - p0).normalized(), (p2 - p1).normalized()
        n1, n2 = Vector((e1.y, -e1.x)), Vector((e2.y, -e2.x))
        s = n1 + n2
        denom = 1.0 + n1.dot(n2)
        ns.append(s / denom if denom > 1e-4 else n1)
    return ns


def rounded_slab(outline, z0, z1, mat, rt=0.03, rb=0.0, seg=5, name="slab"):
    """Extrudes a CCW 2D outline from z0 to z1 with rounded top (and bottom) edges."""
    outline = ccw([tuple(p) for p in outline])
    ns = vertex_normals_2d(outline)
    rings = []
    if rb > 0:
        for k in range(seg + 1):
            ph = -math.pi / 2 + math.pi / 2 * k / seg
            rings.append((rb * (1 - math.cos(ph)), z0 + rb + rb * math.sin(ph)))
    else:
        rings.append((0.0, z0))
    for k in range(seg + 1):
        ph = math.pi / 2 * k / seg
        z = z1 - rt + rt * math.sin(ph)
        inset = rt * (1 - math.cos(ph))
        if abs(z - rings[-1][1]) < 1e-6 and abs(inset - rings[-1][0]) < 1e-6:
            continue
        rings.append((inset, z))
    bm = bmesh.new()
    vr = []
    for inset, z in rings:
        vr.append([bm.verts.new((p[0] - n.x * inset, p[1] - n.y * inset, z)) for p, n in zip(outline, ns)])
    N = len(outline)
    for a, b in zip(vr[:-1], vr[1:]):
        for i in range(N):
            j = (i + 1) % N
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bot = bm.faces.new(list(reversed(vr[0])))
    top = bm.faces.new(vr[-1])
    bm.faces.index_update()
    flat = [bot.index, top.index]
    obj = link_bm(bm, name, [mat])
    return shade(obj, 50, flat)


def lathe(profile, mats, nseg=64, mat_fn=None, rmod=None, name="lathe", angle=40, twist=0.0):
    """Revolves a (r, z) profile around Z. r == 0 makes a pole. mat_fn(theta, z, j) -> index."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r < 1e-6:
            v = bm.verts.new((0, 0, z))
            rings.append([v] * nseg)
        else:
            ring = []
            for i in range(nseg):
                th0 = 2 * math.pi * i / nseg
                rr = r * (rmod(th0, z) if rmod else 1.0)
                th = th0 + twist * z
                ring.append(bm.verts.new((rr * math.cos(th), rr * math.sin(th), z)))
            rings.append(ring)
    for j in range(len(profile) - 1):
        a, b = rings[j], rings[j + 1]
        zm = (profile[j][1] + profile[j + 1][1]) / 2
        for i in range(nseg):
            i2 = (i + 1) % nseg
            vs = []
            for v in (a[i], a[i2], b[i2], b[i]):
                if v not in vs:
                    vs.append(v)
            if len(vs) < 3:
                continue
            f = bm.faces.new(vs)
            if mat_fn:
                f.material_index = mat_fn(2 * math.pi * (i + 0.5) / nseg, zm, j)
    # Winding is outward by construction when the profile runs bottom pole -> outside -> top/inside.
    obj = link_bm(bm, name, mats)
    return shade(obj, angle)


def sweep(points, sides, ups, profile, mats, closed_path=False, closed_prof=True, mat_fn=None,
          name="sweep", recalc=True, angle=50, twist=0.0):
    """Sweeps a 2D profile (u along side, v along up) along a path. mat_fn(i, j) -> index."""
    bm = bmesh.new()
    rows = []
    for idx, (p, s, u) in enumerate(zip(points, sides, ups)):
        p, s, u = Vector(p), Vector(s), Vector(u)
        c, sn = math.cos(twist * idx), math.sin(twist * idx)
        rows.append([bm.verts.new(p + s * (a * c - b * sn) + u * (a * sn + b * c)) for a, b in profile])
    npath = len(rows)
    nprof = len(profile)
    for i in range(npath if closed_path else npath - 1):
        a, b = rows[i], rows[(i + 1) % npath]
        for j in range(nprof if closed_prof else nprof - 1):
            j2 = (j + 1) % nprof
            f = bm.faces.new((a[j], b[j], b[j2], a[j2]))
            if mat_fn:
                f.material_index = mat_fn(i, j)
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link_bm(bm, name, mats)
    return shade(obj, angle)


def circle_profile(r, n=16, ry=None):
    ry = r if ry is None else ry
    return [(r * math.cos(2 * math.pi * k / n), ry * math.sin(2 * math.pi * k / n)) for k in range(n)]


def rounded_rect_profile(hw, hh, rc, n=5):
    pts = []
    for cx, cy, a0 in ((hw - rc, hh - rc, 0), (-hw + rc, hh - rc, 90), (-hw + rc, -hh + rc, 180),
                       (hw - rc, -hh + rc, 270)):
        for k in range(n + 1):
            t = math.radians(a0 + 90 * k / n)
            pts.append((cx + rc * math.cos(t), cy + rc * math.sin(t)))
    return pts


def star_outline(r_out, r_in, points=5, tip_angle=90.0):
    pts = []
    for k in range(points * 2):
        a = math.radians(tip_angle) + math.pi * k / points
        r = r_out if k % 2 == 0 else r_in
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def oriented(obj, loc, normal, spin=0.0):
    """Places obj (built around origin, 'up' = +Z) at loc with +Z along normal."""
    n = Vector(normal).normalized()
    q = Vector((0, 0, 1)).rotation_difference(n)
    obj.matrix_world = Matrix.Translation(Vector(loc)) @ q.to_matrix().to_4x4() @ Matrix.Rotation(spin, 4, "Z")
    return obj


def sprinkle(loc, normal, col, spin, length=0.075, r=0.028):
    o = sphere(r, (0, 0, 0), material(col, 0.25, 0.6), scale=(1, length / r, 0.8), seg=12, rings=6)
    return oriented(o, loc, normal, spin)


def dot(loc, normal, col, r=0.07, flat=0.35):
    o = sphere(r, (0, 0, 0), material(col, 0.28, 0.6), scale=(1, 1, flat), seg=20, rings=10)
    return oriented(o, loc, normal)


def export_report(name):
    export(name)
    obj = bpy.context.active_object
    obj.data.calc_loop_triangles()
    tris = len(obj.data.loop_triangles)
    xs = [(obj.matrix_world @ Vector(c)) for c in obj.bound_box]
    mn = Vector((min(v.x for v in xs), min(v.y for v in xs), min(v.z for v in xs)))
    mx = Vector((max(v.x for v in xs), max(v.y for v in xs), max(v.z for v in xs)))
    # Godot axes: x = bx, y = bz, z = -by
    print(f"REPORT {name}: tris={tris} godot_min=({mn.x:.3f}, {mn.z:.3f}, {-mx.y:.3f}) "
          f"godot_max=({mx.x:.3f}, {mx.z:.3f}, {-mn.y:.3f}) "
          f"size=({mx.x - mn.x:.3f}, {mx.z - mn.z:.3f}, {mx.y - mn.y:.3f})")


# --- assets -------------------------------------------------------------------

def build_slingshot():
    """Triangle kicker: three cream posts, lemon body, coral rubber band. Kick face = -Y."""
    reset()
    posts = [(-0.6, -0.25), (0.6, -0.25), (0.0, 0.25)]
    body, _ = circle_hull(posts, 0.1, n=12)
    rounded_slab(body, 0.0, 0.56, material("lemon", 0.28, 0.7), rt=0.09, seg=6, name="body")
    # Cream icing plate on top with sprinkles.
    cx = sum(p[0] for p in posts) / 3
    cy = sum(p[1] for p in posts) / 3
    icing_c = [(cx + (p[0] - cx) * 0.62, cy + (p[1] - cy) * 0.62) for p in posts]
    icing, _ = circle_hull(icing_c, 0.1, n=12)
    rounded_slab(icing, 0.5, 0.62, material("cream", 0.3, 0.6), rt=0.05, seg=5, name="icing")
    rng = random.Random(3)
    placed = 0
    while placed < 9:
        x, y = rng.uniform(-0.45, 0.45), rng.uniform(-0.2, 0.2)
        # inside the shrunken triangle?
        if y > -0.17 and abs(x) < 0.4 * (0.2 - y) / 0.37 + 0.02:
            sprinkle((x, y, 0.62), (0, 0, 1), rng.choice(SPRINKLE_COLS[:-1] + ["coral"]),
                     rng.uniform(0, math.pi))
            placed += 1
    # Posts with coral caps.
    for px, py in posts:
        p = lathe([(0, 0), (0.12, 0), (0.12, 0.62), (0.1, 0.68), (0, 0.7)], [material("cream", 0.3, 0.5)],
                  nseg=32, name="post")
        p.location = (px, py, 0)
        sphere(0.1, (px, py, 0.72), material("coral", 0.25, 0.7), seg=24, rings=12)
    # Coral rubber band wrapped around the posts (front straight = kick face).
    path, normals = circle_hull(posts, 0.155, n=16)
    pts = [(x, y, 0.3) for x, y in path]
    sides = [(nx, ny, 0) for nx, ny in normals]
    ups = [(0, 0, 1)] * len(pts)
    sweep(pts, sides, ups, rounded_rect_profile(0.045, 0.17, 0.04), [material("coral", 0.22, 0.8)],
          closed_path=True, name="band")
    # Cream "boing" dashes on the kick face.
    for k in range(5):
        x = -0.4 + k * 0.2
        cube((0.07, 0.03, 0.2), (x, -0.44, 0.3), material("cream", 0.3, 0.6), bevel=0.012)
    export_report("slingshot")


def build_cannon():
    """Cupcake-wrapper base, candy-cane ball body and a mortar barrel tilted 45 deg to -Y."""
    reset()
    cream = material("cream", 0.28, 0.6)
    coral = material("coral", 0.25, 0.7)
    pink = material("pink", 0.3, 0.6)
    lemon = material("lemon", 0.25, 0.7)
    # Fluted cupcake wrapper.
    flutes = 22
    wrap = [(0, 0), (0.6, 0), (0.64, 0.02), (0.66, 0.05)]
    for k in range(9):
        z = 0.05 + 0.4 * k / 8
        wrap.append((0.66 + 0.2 * (z - 0.05) / 0.4, z))
    wrap += [(0.84, 0.47), (0.8, 0.49), (0, 0.49)]
    lathe(wrap, [pink, cream], nseg=flutes * 8,
          rmod=lambda th, z: 1.0 + 0.035 * math.cos(flutes * th) if z > 0.03 else 1.0,
          mat_fn=lambda th, z, j: int(th * flutes / (2 * math.pi)) % 2, name="wrapper")
    torus(0.83, 0.055, (0, 0, 0.47), cream)
    # Candy-cane body.
    C = Vector((0, 0, 0.52))
    R = 0.56
    prof = []
    for k in range(73):
        ph = -math.radians(40) + math.radians(130) * k / 72
        prof.append((R * math.cos(ph), C.z + R * math.sin(ph)))
    prof = [(0, prof[0][1])] + prof + [(0, C.z + R)]
    lathe(prof, [cream, coral], nseg=96, twist=2 * math.pi * 1.2 / 6,
          mat_fn=lambda th, z, j: 1 if ((th / (2 * math.pi)) * 6) % 1.0 < 0.38 else 0,
          name="body")
    # Barrel: a lathe around local Z, then tilted 45 deg so its mouth faces -Y / up.
    RO, RI, T1, TF = 0.8, 0.66, 0.8, 0.46
    rimr = (RO - RI) / 2
    bp = [(0, 0.0), (0.42, 0.0)]
    for k in range(1, 9):  # rounded cup bottom
        a = math.pi / 2 * k / 8
        bp.append((0.42 + (RO - 0.42) * math.sin(a), 0.36 * (1 - math.cos(a))))
    for k in range(1, 17):
        bp.append((RO, 0.36 + (T1 - 0.36) * k / 16))
    for k in range(1, 12):
        a = math.pi * k / 12
        bp.append((RI + rimr + rimr * math.cos(a), T1 + rimr * math.sin(a)))
    bp += [(RI, T1), (RI, TF + 0.04), (RI - 0.04, TF), (0, TF)]
    n_rim0 = len(bp) - 1 - 11 - 4 + 0  # profile index where rim starts

    def barrel_mat(th, z, j):
        if j >= n_rim0 and j < n_rim0 + 12:
            return 2  # lemon rim
        if j >= len(bp) - 3:
            return 1  # coral spring pad at the bottom of the bore
        if z < T1 and j < n_rim0:
            return 1 if ((th / (2 * math.pi)) * 6) % 1.0 < 0.38 else 0
        return 3  # pink bore

    b = lathe(bp, [cream, coral, lemon, pink], nseg=96, twist=2 * math.pi * 1.6 / 6, mat_fn=barrel_mat, name="barrel")
    b.rotation_euler = (math.radians(45), 0, 0)  # +Z -> (0, -sin45, cos45)
    b.location = C + Vector((0, -math.sin(math.radians(45)), math.cos(math.radians(45)))) * 0.12
    # Little lemon wheels at the sides.
    for s in (-1, 1):
        w = lathe([(0, -0.09), (0.26, -0.09), (0.3, -0.05), (0.3, 0.05), (0.26, 0.09), (0, 0.09)],
                  [lemon, coral], nseg=48,
                  mat_fn=lambda th, z, j: 0, name="wheel")
        w.rotation_euler = (0, math.radians(90), 0)
        w.location = (s * 0.86, 0.1, 0.3)
        sphere(0.1, (s * 0.95, 0.1, 0.3), coral, scale=(0.6, 1, 1), seg=20, rings=10)
    export_report("cannon")


def build_spinner_frame():
    reset()
    cream = material("cream", 0.3, 0.5)
    for x in (-1.0, 1.0):
        foot = lathe([(0, 0), (0.24, 0), (0.26, 0.03), (0.24, 0.1), (0.17, 0.17), (0.09, 0.21), (0, 0.22)],
                     [material("lilac", 0.28, 0.6)], nseg=40, name="foot")
        foot.location = (x, 0, 0)
        post = lathe([(0, 0.1), (0.08, 0.1), (0.08, 1.35), (0, 1.35)], [cream], nseg=32, name="post")
        post.location = (x, 0, 0)
        sphere(0.14, (x, 0, 1.4), material("lemon", 0.25, 0.7), seg=32, rings=16)
    bar = lathe([(0, -1.0)] + [(0.07, -1.0 + 2.0 * k / 80) for k in range(81)] + [(0, 1.0)],
                [cream, material("coral", 0.25, 0.7)], nseg=48, twist=2 * math.pi * 1.6,
                mat_fn=lambda th, z, j: 1 if ((th / math.pi)) % 1.0 < 0.4 else 0,
                name="bar")
    # finer segmentation along the bar for the helix stripes
    bpy.ops.object.select_all(action="DESELECT")
    bar.rotation_euler = (0, math.radians(90), 0)
    bar.location = (0, 0, 1.4)
    export_report("spinner_frame")


def build_spinner_blade():
    """Flag hangs from its origin (top-centre pivot); rotate around local X."""
    reset()
    lemon = material("lemon", 0.25, 0.7)
    lilac = material("lilac", 0.28, 0.6)
    rect = fillet([(-0.9, -0.9), (0.9, -0.9), (0.9, -0.04), (-0.9, -0.04)], 0.14, n=8)
    blade = rounded_slab(rect, -0.04, 0.04, lemon, rt=0.03, rb=0.03, seg=4, name="blade")
    blade.rotation_euler = (math.radians(90), 0, 0)
    # Lilac stars on both faces.
    star = fillet(star_outline(0.3, 0.14, tip_angle=90), 0.04, n=6)
    s1 = rounded_slab([(x, y - 0.47) for x, y in star], 0.02, 0.065, lilac, rt=0.02, name="star_f")
    s1.rotation_euler = (math.radians(90), 0, 0)
    s2 = rounded_slab([(x, -(y - 0.47)) for x, y in star], 0.02, 0.065, lilac, rt=0.02, name="star_b")
    s2.rotation_euler = (math.radians(-90), 0, 0)
    # Lilac corner dots on both faces.
    for x in (-0.66, 0.66):
        for y in (-0.03, 0.03):
            dot((x, y * 1.4, -0.47), (0, -1 if y < 0 else 1, 0), "lilac", r=0.09, flat=0.3)
    # Striped sleeve around the axle.
    sl = lathe([(0, -0.85), (0.06, -0.85), (0.1, -0.82)] + [(0.11, -0.78 + 1.56 * k / 60) for k in range(61)] +
               [(0.1, 0.82), (0.06, 0.85), (0, 0.85)], [material("cream", 0.3, 0.5), lilac], nseg=48,
               twist=2 * math.pi * 1.2,
               mat_fn=lambda th, z, j: 1 if ((th / math.pi)) % 1.0 < 0.4 else 0, name="sleeve")
    sl.rotation_euler = (0, math.radians(90), 0)
    export_report("spinner_blade")


def _rollover(lit):
    reset()
    rim_col = "white" if lit else "cream"
    rim = fillet(star_outline(0.74, 0.35, tip_angle=-90), 0.075, n=8)
    rounded_slab(rim, 0.0, 0.05, material(rim_col, 0.3, 0.5), rt=0.022, name="rim")
    inner = fillet(star_outline(0.585, 0.275, tip_angle=-90), 0.06, n=8)
    if lit:
        m = material("lemon_lit", 0.22, 0.8)
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        hexv = PALETTE["lemon_lit"].lstrip("#")
        rgb = [srgb_to_linear(int(hexv[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 0.6
    else:
        m = material("lemon", 0.25, 0.7)
    rounded_slab(inner, 0.0, 0.08, m, rt=0.03, name="star")
    export_report("rollover_star_lit" if lit else "rollover_star")


def build_rollover_star():
    _rollover(False)


def build_rollover_star_lit():
    _rollover(True)


def build_hoop():
    """Upright frosted donut; hole axis along Y; origin at ring centre."""
    reset()
    R, r, ry = 1.275, 0.175, 0.26
    nu, nv = 192, 40
    pts, sides, ups = [], [], []
    for i in range(nu):
        u = 2 * math.pi * i / nu
        e = Vector((math.cos(u), 0, math.sin(u)))
        pts.append(e * R)
        sides.append(e)
        ups.append((0, 1, 0))
    prof = circle_profile(r, nv, ry)

    def frost(i, j):
        u = 2 * math.pi * (i + 0.5) / nu
        v = 2 * math.pi * (j + 0.5) / nv
        wave = 0.28 + 0.14 * math.sin(9 * u) * math.sin(3 * u + 1.0) + 0.06 * math.sin(23 * u)
        return 0 if abs(math.sin(v)) > wave else 1

    sweep(pts, sides, ups, prof, [material("pink", 0.25, 0.7), material("biscuit", 0.4, 0.3)],
          closed_path=True, mat_fn=frost, name="donut", angle=60)
    rng = random.Random(7)
    for k in range(110):
        u = rng.uniform(0, 2 * math.pi)
        v = rng.choice((1, -1)) * rng.uniform(math.radians(50), math.radians(130))
        e = Vector((math.cos(u), 0, math.sin(u)))
        p = e * (R + r * math.cos(v)) + Vector((0, ry * math.sin(v), 0))
        n = (e * (math.cos(v) / r) + Vector((0, math.sin(v) / ry, 0))).normalized()
        sprinkle(p + n * 0.012, n, rng.choice(SPRINKLE_COLS), rng.uniform(0, math.pi))
    export_report("hoop")


def build_rail_curve():
    """Quarter-pipe bank in the quadrant x>=0, y<=0 around the origin, r 1..3."""
    reset()
    R0, R1, H = 1.0, 3.0, 0.8
    SINK = 0.02

    def h(r):
        return (H + SINK) * ((r - R0) / (R1 - R0)) ** 2 - SINK

    nr, nt = 40, 64
    bm = bmesh.new()
    top, bot = [], []
    for i in range(nr + 1):
        r = R0 + (R1 - R0) * i / nr
        rt, rb = [], []
        for j in range(nt + 1):
            th = -math.pi / 2 + (math.pi / 2) * j / nt
            rt.append(bm.verts.new((r * math.cos(th), r * math.sin(th), h(r))))
            rb.append(bm.verts.new((r * math.cos(th), r * math.sin(th), -0.04)))
        top.append(rt)
        bot.append(rb)
    lines = [(2.25, 2.35), (2.65, 2.75)]
    for i in range(nr):
        rm = R0 + (R1 - R0) * (i + 0.5) / nr
        for j in range(nt):
            f = bm.faces.new((top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1]))
            dash = (j // 4) % 2 == 0
            if dash and any(a <= rm <= b for a, b in lines):
                f.material_index = 1
            bm.faces.new((bot[i][j + 1], bot[i + 1][j + 1], bot[i + 1][j], bot[i][j]))
    for j in range(nt):  # inner + outer walls
        bm.faces.new((top[0][j], top[0][j + 1], bot[0][j + 1], bot[0][j]))
        bm.faces.new((top[nr][j + 1], top[nr][j], bot[nr][j], bot[nr][j + 1]))
    for i in range(nr):  # end walls
        bm.faces.new((top[i + 1][0], top[i][0], bot[i][0], bot[i + 1][0]))
        bm.faces.new((top[i][nt], top[i + 1][nt], bot[i + 1][nt], bot[i][nt]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link_bm(bm, "bank", [material("sky", 0.28, 0.6), material("cream", 0.3, 0.5)])
    shade(obj, 30)
    # Candy-striped rim tube on the top edge.
    rr, zr = 0.13, h(R1)
    n = 256
    pts = [(R1 * math.cos(-math.pi / 2 + math.pi / 2 * k / n), R1 * math.sin(-math.pi / 2 + math.pi / 2 * k / n), zr)
           for k in range(n + 1)]
    sides = [(math.cos(-math.pi / 2 + math.pi / 2 * k / n), math.sin(-math.pi / 2 + math.pi / 2 * k / n), 0)
             for k in range(n + 1)]
    ups = [(0, 0, 1)] * (n + 1)
    nprof = 28
    sweep(pts, sides, ups, circle_profile(rr, nprof), [material("cream", 0.28, 0.6), material("coral", 0.25, 0.7)],
          mat_fn=lambda i, j: 1 if (2.0 * j / nprof) % 1.0 < 0.45 else 0, name="rim", twist=2 * math.pi / 40)
    for p in (pts[0], pts[-1]):
        sphere(rr * 1.06, p, material("lemon", 0.25, 0.7), seg=24, rings=12)
    export_report("rail_curve")


def build_drop_target():
    reset()
    cube((0.9, 0.3, 0.9), (0, 0, 0.45), material("lilac", 0.18, 0.9), bevel=0.11)
    star = fillet(star_outline(0.3, 0.14, tip_angle=90), 0.045, n=6)
    s = rounded_slab(star, -0.02, 0.05, material("lemon", 0.25, 0.7), rt=0.025, name="star")
    s.rotation_euler = (math.radians(90), 0, 0)
    s.location = (0, -0.15, 0.45)
    # Gummy shine dash on the top-front edge.
    o = sphere(0.05, (0, 0, 0), material("white", 0.2, 0.8), scale=(3.0, 1.0, 0.35), seg=20, rings=10)
    oriented(o, (-0.2, -0.1, 0.9), (0, -0.4, 1))
    export_report("drop_target")


def chute_path(t):
    """Centre line of the chute floor (Blender coords) for t in 0..1 (0 = high end)."""
    A = 1.0 / 1.2990381
    y = 4.0 - 8.0 * t
    x = A * (math.sin(2 * math.pi * t) - 0.5 * math.sin(4 * math.pi * t))
    z = 1.98 - 2.0 * (1 - math.cos(math.pi * t)) / 2
    return Vector((x, y, z))


def build_chute():
    reset()
    FLAT, WALL, WH = 0.15, 0.5, 0.5
    # Flat floor 0.3 wide + quarter-circle walls of radius 0.5 (the ball radius).
    prof =[(-FLAT - WALL * math.sin(a * math.pi / 2), WH * (1 - math.cos(a * math.pi / 2)))
            for a in [k / 12.0 for k in range(12, 0, -1)]] + \
           [(-FLAT, 0.0), (0.0, 0.0), (FLAT, 0.0)] + \
           [(FLAT + WALL * math.sin(a * math.pi / 2), WH * (1 - math.cos(a * math.pi / 2)))
            for a in [k / 12.0 for k in range(1, 13)]]
    n = 200
    pts, sides, ups = [], [], []
    for i in range(n + 1):
        t = i / n
        p = chute_path(t)
        T = (chute_path(min(1, t + 1e-3)) - chute_path(max(0, t - 1e-3))).normalized()
        side = Vector((0, 0, 1)).cross(T).normalized()
        up = T.cross(side).normalized()
        pts.append(p)
        sides.append(side)
        ups.append(up)
    np_ = len(prof)

    def mat(i, j):
        return 1 if j < 3 or j >= np_ - 4 else 0

    obj = sweep(pts, sides, ups, prof, [material("pink", 0.25, 0.7), material("cream", 0.3, 0.5)],
                closed_prof=False, mat_fn=mat, name="chute", recalc=False, angle=60)
    # faces must point into the channel (up at the start)
    if obj.data.polygons[len(prof) // 2].normal.dot(Vector(ups[0])) < 0:
        obj.data.flip_normals()
    sol = obj.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.1
    sol.offset = -1.0
    # Rolled cream rims along both wall tops.
    for sgn in (-1, 1):
        rp = [Vector(p) + Vector(s) * sgn * (FLAT + WALL + 0.05) + Vector(u) * WH for p, s, u in zip(pts, sides, ups)]
        sweep(rp, sides, ups, circle_profile(0.075, 14), [material("cream", 0.28, 0.6)], name="rim")
        for p in (rp[0], rp[-1]):
            sphere(0.078, p, material("cream", 0.28, 0.6), seg=20, rings=10)
    # Two candy-stick supports under the high half.
    for t in (0.12, 0.42):
        p = chute_path(t)
        top = p.z - 0.06
        post = lathe([(0, 0.1)] + [(0.07, 0.1 + (top - 0.1) * k / 60) for k in range(61)] + [(0, top)],
                     [material("cream", 0.3, 0.5), material("lilac", 0.28, 0.6)], nseg=32, twist=2 * math.pi * 1.2,
                     mat_fn=lambda th, z, j: 1 if ((th / math.pi)) % 1.0 < 0.4 else 0, name="leg")
        post.location = (p.x, p.y, 0)
        foot = lathe([(0, 0), (0.2, 0), (0.22, 0.03), (0.18, 0.1), (0.08, 0.15), (0, 0.16)],
                     [material("lilac", 0.28, 0.6)], nseg=32, name="foot")
        foot.location = (p.x, p.y, 0)
    export_report("chute")


def build_bouncy_mushroom_small():
    reset()
    cream = material("cream", 0.3, 0.5)
    lathe([(0, 0), (0.27, 0), (0.29, 0.03), (0.26, 0.08), (0.21, 0.18), (0.2, 0.45), (0, 0.45)], [cream],
          nseg=48, name="stem")
    torus(0.23, 0.085, (0, 0, 0.24), material("coral", 0.22, 0.8))
    cz, a, c = 0.62, 0.55, 0.3
    sphere(a, (0, 0, cz), material("lilac", 0.22, 0.8), scale=(1, 1, c / a), seg=64, rings=32)
    for ring_phi, count, off in ((math.radians(65), 8, 0.0), (math.radians(35), 5, 0.4)):
        for k in range(count):
            th = 2 * math.pi * (k + off) / count
            x, y = a * math.sin(ring_phi) * math.cos(th), a * math.sin(ring_phi) * math.sin(th)
            z = c * math.cos(ring_phi)
            n = Vector((x / a ** 2, y / a ** 2, z / c ** 2)).normalized()
            dot((x, y, cz + z), n, "cream", r=0.075 if count == 8 else 0.065)
    dot((0, 0, cz + c), (0, 0, 1), "cream", r=0.08)
    export_report("bouncy_mushroom_small")


def build_speed_arrow():
    reset()
    pad = fillet([(-0.95, -0.95), (0.95, -0.95), (0.95, 0.95), (-0.95, 0.95)], 0.26, n=10)
    rounded_slab(pad, 0.0, 0.03, material("mint", 0.28, 0.6), rt=0.018, seg=4, name="pad")
    s = 0.8
    chev = [(0, -0.3), (0.45, 0.15), (0.45, 0.37), (0, -0.08), (-0.45, 0.37), (-0.45, 0.15)]
    chev = fillet([(x * s, y * s) for x, y in chev], 0.035, n=6)
    for k in range(3):
        oy = -0.5 + k * 0.48
        rounded_slab([(x, y + oy) for x, y in chev], 0.015, 0.05, material("cream", 0.2, 0.8), rt=0.014, seg=4,
                     name="chev")
    export_report("speed_arrow")


PIN_BUILDERS = {
    "slingshot": build_slingshot,
    "cannon": build_cannon,
    "spinner_frame": build_spinner_frame,
    "spinner_blade": build_spinner_blade,
    "rollover_star": build_rollover_star,
    "rollover_star_lit": build_rollover_star_lit,
    "hoop": build_hoop,
    "rail_curve": build_rail_curve,
    "drop_target": build_drop_target,
    "chute": build_chute,
    "bouncy_mushroom_small": build_bouncy_mushroom_small,
    "speed_arrow": build_speed_arrow,
}


# --- contact sheet --------------------------------------------------------------

def render_preview(path=None):
    path = path or os.path.join(ROOT, "art", "preview-pinball.png")
    reset()
    # (name, x, y, z-lift, extra)
    layout = [
        ("slingshot", 0.0, 0.0, 0.0), ("cannon", 2.4, 0.0, 0.0), ("spinner_frame", 5.3, 0.0, 0.0),
        ("spinner_blade", 5.3, 0.0, 1.4), ("rollover_star", 7.8, 0.0, 0.0),
        ("rollover_star_lit", 9.3, 0.0, 0.0), ("drop_target", 10.8, 0.0, 0.0),
        ("bouncy_mushroom_small", 12.3, 0.0, 0.0), ("speed_arrow", 14.2, 0.0, 0.0),
        ("hoop", 0.6, 5.0, 1.46), ("rail_curve", 2.8, 4.5, 0.0), ("chute", 9.2, 6.5, 0.0),
        ("spinner_blade", 13.4, 5.0, 1.0),
    ]
    all_objs = []
    for name, x, y, z in layout:
        fp = os.path.join(OUT, f"{name}.glb")
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=fp)
        new = [o for o in bpy.context.scene.objects if o not in before]
        for o in new:
            if o.parent is None:
                o.location = (o.location.x + x, o.location.y + y, o.location.z + z)
        all_objs += [o for o in new if o.type == "MESH"]
    bpy.context.view_layer.update()

    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.005))
    floor = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.80, 0.76, 0.72, 1)
    fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    floor.data.materials.append(fm)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    direction = Vector((0.45, -1, 0.95)).normalized()
    rot = (-direction).to_track_quat("-Z", "Y")
    right = rot @ Vector((1, 0, 0))
    upv = rot @ Vector((0, 1, 0))
    pts = []
    for o in all_objs:
        for v in o.data.vertices:
            pts.append(o.matrix_world @ v.co)
    xs = [p.dot(right) for p in pts]
    ys = [p.dot(upv) for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    w, hgt = max(xs) - min(xs), max(ys) - min(ys)
    resx, resy = 2400, 1500
    cam_data.ortho_scale = max(w, hgt * resx / resy) * 1.08
    centre = right * cx + upv * cy
    cam.location = centre + direction * 60
    cam.rotation_euler = rot.to_euler()
    cam_data.clip_end = 200
    bpy.context.scene.camera = cam

    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 2.6
    sun.angle = math.radians(8)
    sun_o = bpy.data.objects.new("sun", sun)
    sun_o.rotation_euler = (math.radians(40), 0, math.radians(25))
    bpy.context.collection.objects.link(sun_o)
    world = bpy.data.worlds.new("w")
    bpy.context.scene.world = world
    try:
        world.use_nodes = True
        bg = world.node_tree.nodes.get("Background")
        bg.inputs["Color"].default_value = (0.95, 0.93, 0.92, 1)
        bg.inputs["Strength"].default_value = 0.55
    except Exception:
        world.color = (0.95, 0.93, 0.92)

    scene = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eng
            break
        except Exception:
            continue
    scene.render.resolution_x = resx
    scene.render.resolution_y = resy
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("rendered", path)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv or list(PIN_BUILDERS) + ["preview"]
    for name in names:
        if name == "preview":
            render_preview()
        else:
            PIN_BUILDERS[name]()

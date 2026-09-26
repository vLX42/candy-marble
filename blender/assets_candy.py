"""Candy collectibles and pickups for Candy Marble.

Build everything (or just the names given after --) and export models/<name>.glb:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_candy.py
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_candy.py -- coin gem_candy
Render the contact sheet art/preview-candy.png from the exported files:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_candy.py -- preview

Conventions: every asset has its origin at its visual (bounding box) centre and
stands upright; flat items (coin, star, heart, letters, clock, magnet) face -Y
(Godot +Z). They are meant to float ~0.6 above the floor and spin around Z (Godot Y).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_assets import *  # noqa: F401,F403
from build_assets import PALETTE, ROOT, OUT, srgb_to_linear, finish, reset, cube, sphere, cylinder, torus

import bmesh
import bpy
from mathutils import Matrix, Vector

EXTRA = {
    "gold": "#FFC94A",
    "gold_light": "#FFE08A",
    "vanilla": "#FFE7B3",
    "peach": "#FFB38A",
    "sky_deep": "#6FB6EC",
    "mint_deep": "#7FD3AE",
}
PALETTE.update(EXTRA)

FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"


def mat(name, roughness=0.28, coat=0.6, metallic=0.0):
    key = f"c_{name}_{roughness}_{coat}_{metallic}"
    if key in bpy.data.materials:
        return bpy.data.materials[key]
    hexv = PALETTE[name].lstrip("#")
    rgb = [srgb_to_linear(int(hexv[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    m = bpy.data.materials.new(key)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = roughness
    b.inputs["Metallic"].default_value = metallic
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = 0.1
    m.diffuse_color = (*rgb, 1.0)
    return m


def new_obj(name, bm, mats, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = smooth
    return o


def lathe(name, profile, mats, segs=64, rfunc=None, twist=None, matfunc=None):
    """Revolve a (z, r) profile around Z. r == 0 entries become poles.
    rfunc(z, theta) -> radius multiplier, twist(z) -> angle offset,
    matfunc(center Vector) -> material index."""
    bm = bmesh.new()
    rings = []
    for z, r in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        ring = []
        for i in range(segs):
            th = 2 * math.pi * i / segs
            rr = r * (rfunc(z, th) if rfunc else 1.0)
            a = th + (twist(z) if twist else 0.0)
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(segs):
            j = (i + 1) % segs
            if len(a) == 1:
                vs = (a[0], b[i], b[j])
            elif len(b) == 1:
                vs = (a[i], a[j], b[0])
            else:
                vs = (a[i], a[j], b[j], b[i])
            f = bm.faces.new(vs)
            if matfunc:
                f.material_index = matfunc(f.calc_center_median())
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_obj(name, bm, mats)


def puffy(name, outline, thick, puff, mats, bands=None, subsurf=2):
    """Pillow-shaped slab in the XZ plane (faces +-Y) from a closed 2D outline [(x, z)].
    bands: list of (scale, puff_fraction) inner rings; material index = ring band."""
    bands = bands or [(0.7, 0.65), (0.38, 0.92)]
    cx = sum(p[0] for p in outline) / len(outline)
    cz = sum(p[1] for p in outline) / len(outline)
    bm = bmesh.new()
    n = len(outline)

    def ring(scale, y):
        return [bm.verts.new((cx + (x - cx) * scale, y, cz + (z - cz) * scale)) for x, z in outline]

    for side in (-1, 1):
        rim = ring(1.0, side * thick)
        prev = rim
        for bi, (s, pf) in enumerate(bands):
            cur = ring(s, side * (thick + puff * pf))
            for i in range(n):
                j = (i + 1) % n
                f = bm.faces.new((prev[i], prev[j], cur[j], cur[i]))
                f.material_index = min(bi, len(mats) - 1)
            prev = cur
        c = bm.verts.new((cx, side * (thick + puff), cz))
        for i in range(n):
            f = bm.faces.new((prev[i], prev[(i + 1) % n], c))
            f.material_index = min(len(bands), len(mats) - 1)
        if side == -1:
            front_rim = rim
        else:
            back_rim = rim
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new((front_rim[i], front_rim[j], back_rim[j], back_rim[i]))
        f.material_index = 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = new_obj(name, bm, mats)
    if subsurf:
        m = o.modifiers.new("Subsurf", "SUBSURF")
        m.levels = m.render_levels = subsurf
    return o


def densify(pts, k):
    """Insert k-1 points on each edge of a closed polygon."""
    out = []
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        for s in range(k):
            t = s / k
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def star_pts(outer, inner, n=5, rot=math.pi / 2):
    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = rot + math.pi * i / n
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def curve_tube(name, pts, radii, bevel, mat_, res=6, caps=True):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, co, r in zip(sp.points, pts, radii):
        p.co = (co[0], co[1], co[2], 1.0)
        p.radius = r
    cu.bevel_depth = bevel
    cu.bevel_resolution = res
    cu.use_fill_caps = caps
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.data.materials.clear()
    o.data.materials.append(mat_)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def capsule(r, length, loc, mat_, direction=Vector((0, 0, 1)), spin=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r, depth=length, location=(0, 0, 0))
    o = bpy.context.active_object
    finish(o, mat_, bevel=r * 0.95, segments=3)
    q = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = q @ Matrix.Rotation(spin, 4, "Z").to_quaternion()
    o.location = loc
    return o


def finalize(name, size=None, axis=None):
    """Apply modifiers, join, move origin to bounds centre (at world origin),
    optionally scale so the largest (or given axis) dimension equals size, export."""
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in objs:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    me = obj.data
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    c = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2))
    dims = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    s = 1.0
    if size:
        ref = dims[axis] if axis is not None else max(dims)
        s = size / ref
    me.transform(Matrix.Scale(s, 4) @ Matrix.Translation(-c))
    me.update()
    obj.location = (0, 0, 0)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    d = dims * s
    print(f"ASSET {name}: dims x={d.x:.2f} y={d.y:.2f} z={d.z:.2f} tris={tris}")
    obj.select_set(True)
    path = os.path.join(OUT, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print(f"exported {path}")


def scatter_on(obj, count, fn, filt, seed=1):
    """Call fn(position, normal) on `count` random faces of obj that pass filt(pos, normal)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    mw = obj.matrix_world
    cands = []
    for p in me.polygons:
        pos = mw @ p.center
        nrm = (mw.to_3x3() @ p.normal).normalized()
        if filt(pos, nrm):
            cands.append((pos.copy(), nrm.copy()))
    ev.to_mesh_clear()
    rng = random.Random(seed)
    rng.shuffle(cands)
    chosen = []
    for pos, nrm in cands:
        if len(chosen) >= count:
            break
        if all((pos - q).length > 0.045 for q in chosen):
            chosen.append(pos)
            fn(pos, nrm, rng)


# --- collectibles -------------------------------------------------------------

def build_coin():
    """Gold-foil chocolate coin, 0.6 diameter, faces +-Y, embossed star both sides."""
    reset()
    gold = mat("gold", 0.26, 0.5, 0.75)
    light = mat("gold_light", 0.2, 0.7, 0.6)
    cylinder(0.3, 0.1, (0, 0, 0), gold, rot=(math.radians(90), 0, 0), verts=64, bevel=0.025)
    for side in (-1, 1):
        torus(0.265, 0.03, (0, side * 0.05, 0), gold, rot=(math.radians(90), 0, 0), scale=(1, 0.7, 1))
        bm = bmesh.new()
        pts = star_pts(0.15, 0.068)
        vs = [bm.verts.new((x, 0, z)) for x, z in pts]
        f = bm.faces.new(vs)
        ext = bmesh.ops.extrude_face_region(bm, geom=[f])
        for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
            v.co.y = side * 0.034
        for v in bm.verts:
            v.co.y += side * 0.03
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        o = new_obj("star", bm, [light], smooth=False)
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = 0.012
        m.segments = 3
        m.limit_method = "ANGLE"
        for p in o.data.polygons:
            p.use_smooth = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    finalize("coin", 0.6, axis=0)


def build_gumdrop():
    """Sugar-coated mint gumdrop, 0.5 wide."""
    reset()
    prof = [(0.0, 0.0), (0.0, 0.2), (0.008, 0.235), (0.03, 0.252), (0.07, 0.25), (0.14, 0.235),
            (0.22, 0.212), (0.29, 0.185), (0.345, 0.15), (0.385, 0.105), (0.408, 0.055), (0.415, 0.0)]
    body = lathe("gumdrop", prof, [mat("mint", 0.45, 0.35)], segs=48)
    sugar = mat("white", 0.2, 0.8)

    def add(pos, nrm, rng):
        s = rng.uniform(0.018, 0.028)
        bpy.ops.mesh.primitive_cube_add(size=s, location=pos + nrm * s * 0.15,
                                        rotation=(rng.uniform(0, 3), rng.uniform(0, 3), rng.uniform(0, 3)))
        c = bpy.context.active_object
        c.data.materials.append(sugar)

    scatter_on(body, 90, add, lambda p, n: p.z > 0.02 and n.z > -0.2, seed=3)
    finalize("gumdrop", 0.5, axis=0)


def build_wrapped_candy():
    """Twist-wrapped bonbon, 0.8 long along X, lemon wrapper with cream stripes."""
    reset()
    prof = [(-0.372, 0.0), (-0.388, 0.07), (-0.4, 0.14), (-0.392, 0.155), (-0.37, 0.12),
            (-0.335, 0.085), (-0.3, 0.058), (-0.27, 0.048), (-0.245, 0.06), (-0.225, 0.095)]
    for i in range(1, 16):
        a = -math.pi / 2 + math.pi * i / 16
        prof.append((0.225 * math.sin(a) * 0.93, 0.175 * math.cos(a) ** 0.8))
    prof += [(-z, r) for z, r in reversed(prof)]

    def rfunc(z, th):
        w = max(0.0, (abs(z) - 0.3) / 0.1)
        return 1.0 + 0.09 * math.sin(16 * th) * w

    def twist(z):
        return math.copysign(max(0.0, abs(z) - 0.22) * 9.0, z)

    def mf(c):
        th = math.atan2(c.y, c.x)
        tw = twist(c.z)
        s = (th - tw) / (2 * math.pi) * 8 + 0.02
        return 1 if (s % 1.0) < 0.4 else 0

    lathe("bonbon", prof, [mat("lemon", 0.25, 0.8), mat("cream", 0.25, 0.8)], segs=72,
          rfunc=rfunc, twist=twist, matfunc=mf)
    o = bpy.context.active_object if bpy.context.active_object else None
    o = bpy.data.objects["bonbon"]
    o.rotation_euler = (0, math.radians(90), 0)
    finalize("wrapped_candy", 0.8, axis=0)


def build_star_candy():
    """Puffy 5-point star, 0.8 across, faces +-Y. Lilac rim fading to a lemon centre."""
    reset()
    pts = densify(star_pts(0.46, 0.22), 3)
    puffy("star", pts, 0.07, 0.085, [mat("lilac", 0.25, 0.8), mat("pink", 0.25, 0.8), mat("lemon", 0.25, 0.8)],
          bands=[(0.72, 0.55), (0.42, 0.9)])
    finalize("star_candy", 0.8, axis=0)


def heart_pts(n=48):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 32 * 0.75, z / 32 * 0.75))
    return pts


def build_heart_candy():
    """Puffy pink heart, 0.7 wide, faces +-Y, cream highlight dots."""
    reset()
    pts = heart_pts()
    h = puffy("heart", pts, 0.07, 0.09, [mat("pink", 0.24, 0.8)], bands=[(0.72, 0.6), (0.4, 0.92)])
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[1] for p in pts) / len(pts)
    for side in (-1, 1):
        x = -0.17 * -side if False else -0.15
        sphere(0.045, (x, side * 0.135, cz + 0.12), mat("cream", 0.2, 0.9), scale=(1, 0.45, 1.25), seg=24, rings=12)
        sphere(0.022, (x - 0.02, side * 0.12, cz + 0.035), mat("cream", 0.2, 0.9), scale=(1, 0.45, 1), seg=16, rings=8)
    finalize("heart_candy", 0.7, axis=0)


def build_golden_cupcake():
    """Bonus cupcake ~1.0 tall: pleated gold cup, pink frosting swirl, lemon ball, sprinkles."""
    reset()
    gold = mat("gold", 0.26, 0.5, 0.75)
    prof = [(0.0, 0.0), (0.0, 0.25), (0.012, 0.27), (0.1, 0.29), (0.2, 0.31), (0.3, 0.33),
            (0.38, 0.345), (0.41, 0.35), (0.425, 0.33), (0.43, 0.0)]
    lathe("cup", prof, [gold], segs=96, rfunc=lambda z, th: 1.0 + 0.045 * abs(math.sin(9 * th)) if z > 0.005 else 1.0)
    torus(0.345, 0.035, (0, 0, 0.41), mat("gold_light", 0.2, 0.7, 0.6))
    pink = mat("pink", 0.3, 0.6)
    sphere(0.33, (0, 0, 0.46), pink, scale=(1, 1, 0.35), seg=48, rings=24)
    n = 260
    pts, radii = [], []
    for i in range(n):
        t = i / (n - 1)
        R = 0.28 * (1 - t) + 0.015
        a = t * 2 * math.pi * 2.6
        pts.append((R * math.cos(a), R * math.sin(a), 0.5 + t * 0.3))
        radii.append((1.0 - 0.62 * t) * math.sin(min(1.0, 0.12 + t / 0.12) * math.pi / 2))
    frost = curve_tube("frost", pts, radii, 0.105, pink, res=6)
    sphere(0.085, (0, 0, 0.9), mat("lemon", 0.18, 0.9), seg=32, rings=16)
    sphere(0.02, (-0.03, -0.06, 0.93), mat("white", 0.2, 0.9), scale=(1, 0.6, 1), seg=12, rings=6)
    stem = curve_tube("stem", [(0, 0, 0.97), (0.01, 0, 1.02), (0.04, 0, 1.06)], [1, 1, 1], 0.012,
                      mat("mint_deep", 0.3, 0.6), res=2)
    cols = ["lilac", "sky", "mint", "cream", "lemon", "peach"]

    def add(pos, nrm, rng):
        tang = nrm.cross(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))).normalized()
        capsule(0.016, 0.07, pos + nrm * 0.004, mat(rng.choice(cols), 0.25, 0.8), direction=tang)

    scatter_on(frost, 42, add, lambda p, n: n.z > 0.15 and p.z < 0.84 and (p.x ** 2 + p.y ** 2) > 0.004, seed=7)
    finalize("golden_cupcake", 1.0, axis=2)


def build_gem_candy():
    """Faceted hard-candy gem, 0.6 across, table up, point down."""
    reset()
    pts = []
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        pts.append((0.15 * math.cos(a), 0.15 * math.sin(a), 0.13))
    for i in range(8):
        a = 2 * math.pi * i / 8
        pts.append((0.245 * math.cos(a), 0.245 * math.sin(a), 0.075))
    for i in range(16):
        a = 2 * math.pi * i / 16 + math.pi / 16
        pts.append((0.3 * math.cos(a), 0.3 * math.sin(a), 0.02))
        pts.append((0.3 * math.cos(a), 0.3 * math.sin(a), -0.01))
    for i in range(8):
        a = 2 * math.pi * i / 8
        pts.append((0.17 * math.cos(a), 0.17 * math.sin(a), -0.16))
    pts.append((0, 0, -0.29))
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=bm.verts, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        c = f.calc_center_median()
        f.material_index = 0 if c.z > 0.005 else 1
        if c.z > 0.125:
            f.material_index = 2
    new_obj("gem", bm, [mat("sky", 0.06, 1.0), mat("sky_deep", 0.06, 1.0), mat("white", 0.05, 1.0)], smooth=False)
    finalize("gem_candy", 0.6, axis=0)


LETTER_COLOURS = {"C": "pink", "A": "mint", "N": "lilac", "D": "sky", "Y": "peach"}


def text_mesh(ch, extrude, bevel, offset, mat_):
    bpy.ops.object.text_add(location=(0, 0, 0))
    t = bpy.context.active_object
    t.data.body = ch
    if os.path.exists(FONT):
        t.data.font = bpy.data.fonts.load(FONT, check_existing=True)
    t.data.align_x = "CENTER"
    t.data.size = 1.0
    t.data.extrude = extrude
    t.data.bevel_depth = bevel
    t.data.bevel_resolution = 3
    t.data.offset = offset
    t.data.resolution_u = 8
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.data.materials.clear()
    o.data.materials.append(mat_)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    o.rotation_euler = (math.radians(90), 0, 0)
    return o


def build_letter(ch):
    reset()
    text_mesh(ch, 0.045, 0.05, 0.035, mat("cream", 0.25, 0.8))
    text_mesh(ch, 0.1, 0.035, -0.005, mat(LETTER_COLOURS[ch], 0.24, 0.8))
    finalize(f"candy_letter_{ch}", 0.8, axis=2)


# --- props / pickups ----------------------------------------------------------

def build_clock_candy():
    """Candy pocket watch (+time), 0.7 across incl. crown, faces +-Y."""
    reset()
    rx = math.radians(90)
    mint = mat("mint", 0.26, 0.7)
    cylinder(0.3, 0.16, (0, 0, 0), mint, rot=(rx, 0, 0), verts=64, bevel=0.055)
    cylinder(0.225, 0.176, (0, 0, 0), mat("cream", 0.22, 0.8), rot=(rx, 0, 0), verts=64, bevel=0.012)
    lemon = mat("lemon", 0.22, 0.85)
    for side in (-1, 1):
        y = side * 0.086
        torus(0.245, 0.034, (0, y, 0), mat("mint_deep", 0.24, 0.8), rot=(rx, 0, 0), scale=(1, 0.8, 1))
        for i in range(12):
            a = 2 * math.pi * i / 12
            r = 0.028 if i % 3 == 0 else 0.017
            m = mat("pink", 0.22, 0.8) if i % 3 == 0 else mat("lilac", 0.22, 0.8)
            sphere(r, (0.175 * math.sin(a), y, 0.175 * math.cos(a)), m, scale=(1, 0.6, 1), seg=16, rings=8)
        for ang, ln, w in ((math.radians(-60), 0.1, 0.03), (math.radians(35), 0.145, 0.024)):
            d = Vector((math.sin(ang), 0, math.cos(ang)))
            capsule(w, ln + 2 * w, d * (ln / 2) + Vector((0, y + side * 0.006, 0)), lemon, direction=d)
        sphere(0.035, (0, y + side * 0.01, 0), lemon, scale=(1, 0.7, 1), seg=20, rings=10)
    cylinder(0.055, 0.1, (0, 0, 0.32), mint, verts=24, bevel=0.02)
    cylinder(0.07, 0.04, (0, 0, 0.37), mat("mint_deep", 0.24, 0.8), verts=24, bevel=0.015)
    torus(0.065, 0.024, (0, 0, 0.45), lemon, rot=(rx, 0, 0))
    finalize("clock_candy", 0.7, axis=2)


def build_magnet_candy():
    """Candy horseshoe magnet, 0.7 tall, opening down, faces +-Y. Coral with cream tips."""
    reset()
    pts = []
    for i in range(8):
        pts.append((-0.2, 0, -0.26 + 0.31 * i / 7))
    for i in range(1, 32):
        a = math.pi - math.pi * i / 32
        pts.append((0.2 * math.cos(a), 0, 0.05 + 0.2 * math.sin(a)))
    for i in range(8):
        pts.append((0.2, 0, 0.05 - 0.31 * i / 7))
    curve_tube("magnet", pts, [1.0] * len(pts), 0.1, mat("coral", 0.26, 0.75), res=8)
    cream = mat("cream", 0.24, 0.8)
    for x in (-0.2, 0.2):
        cylinder(0.108, 0.15, (x, 0, -0.325), cream, verts=40, bevel=0.035)
    finalize("magnet_candy", 0.7, axis=2)


BUILDERS = {
    "coin": build_coin,
    "gumdrop": build_gumdrop,
    "wrapped_candy": build_wrapped_candy,
    "star_candy": build_star_candy,
    "heart_candy": build_heart_candy,
    "golden_cupcake": build_golden_cupcake,
    "gem_candy": build_gem_candy,
}
for _ch in "CANDY":
    BUILDERS[f"candy_letter_{_ch}"] = (lambda c: (lambda: build_letter(c)))(_ch)
BUILDERS["clock_candy"] = build_clock_candy
BUILDERS["magnet_candy"] = build_magnet_candy


# --- contact sheet ------------------------------------------------------------

def render_preview(names=None, out=None, cols=6, cell=1.2, spin=0.0):
    names = names or list(BUILDERS)
    out = out or os.path.join(ROOT, "art", "preview-candy.png")
    reset()
    rows = math.ceil(len(names) / cols)
    direction = Vector((0.45, -1.0, 0.75)).normalized()
    rot = (-direction).to_track_quat("-Z", "Y")
    right = rot @ Vector((1, 0, 0))
    up = rot @ Vector((0, 1, 0))
    for i, n in enumerate(names):
        path = os.path.join(OUT, f"{n}.glb")
        if not os.path.exists(path):
            continue
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in bpy.context.scene.objects if o not in before]
        c, r = i % cols, i // cols
        pos = right * (c - (cols - 1) / 2) * cell + up * ((rows - 1) / 2 - r) * cell
        for o in new:
            if o.parent is None:
                o.location = pos
                o.rotation_mode = "XYZ"
                o.rotation_euler.z += spin
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = cols * cell
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = direction * 40
    cam.rotation_euler = rot.to_euler()
    scene = bpy.context.scene
    scene.camera = cam
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 2.6
    sun.angle = math.radians(8)
    sun_o = bpy.data.objects.new("sun", sun)
    sun_o.rotation_euler = (math.radians(40), math.radians(10), math.radians(25))
    bpy.context.collection.objects.link(sun_o)
    fill = bpy.data.lights.new("fill", "SUN")
    fill.energy = 0.8
    fill_o = bpy.data.objects.new("fill", fill)
    fill_o.rotation_euler = (math.radians(70), 0, math.radians(-140))
    bpy.context.collection.objects.link(fill_o)
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.78, 0.8, 0.86, 1)
    bg.inputs["Strength"].default_value = 0.75
    backdrop = nt.nodes.new("ShaderNodeBackground")
    backdrop.inputs["Color"].default_value = (0.96, 0.88, 0.92, 1)
    lp = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(bg.outputs[0], mix.inputs[1])
    nt.links.new(backdrop.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], nt.nodes["World Output"].inputs["Surface"])
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = 2400
    scene.render.resolution_y = int(2400 * rows / cols)
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("rendered", out)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "preview":
        spin = math.radians(float(argv[1])) if len(argv) > 1 else 0.0
        out = argv[2] if len(argv) > 2 else None
        render_preview(spin=spin, out=out)
    else:
        for name in argv or BUILDERS:
            BUILDERS[name]()

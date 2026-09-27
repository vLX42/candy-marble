"""Enemies, windmill and catapult for Candy Marble.

Run headless from the repo root:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_enemies.py
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_enemies.py -- enemy_ghost
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/assets_enemies.py -- preview

Same conventions as build_assets.py: 1 Blender unit = 1 game unit, Z-up,
Blender -Y becomes Godot +Z (forward). Faces look towards Blender -Y.
Godot (x, y, z) = Blender (x, z, -y).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_assets import *  # noqa: E402,F401,F403
from build_assets import PALETTE, ROOT, OUT  # noqa: E402
from assets_pinball import link_bm, shade, lathe, oriented, export_report  # noqa: E402

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

PALETTE.setdefault("biscuit", "#F3CD98")
PALETTE.setdefault("wafer", "#E8B46E")
PALETTE.setdefault("sour", "#D8408A")      # raspberry-lilac jelly
PALETTE.setdefault("sour_top", "#C97FE0")
PALETTE.setdefault("marsh", "#E8547A")     # marshmallow pink-raspberry

# Catapult numbers (Blender coords, relative to the arm pivot).
PIVOT_Z = 0.9
CUP_Y = 1.8          # behind the pivot (Blender +Y = Godot -Z)
CUP_R_OUT = 0.70
CUP_R_IN = 0.62
CUP_CZ = -PIVOT_Z + CUP_R_OUT   # bowl sphere centre: outer bottom sits at -0.9


# --- small helpers --------------------------------------------------------------

def glossy(name, r=0.22, coat=0.8):
    return material(name, r, coat)


def frame_matrix(pos, normal, up=(0, 0, 1)):
    """Local frame: x = right, y = up, z = normal (out of the surface)."""
    n = Vector(normal).normalized()
    u = Vector(up)
    u = (u - n * u.dot(n)).normalized()
    r = u.cross(n)
    m = Matrix((r, u, n)).transposed().to_4x4()
    m.translation = Vector(pos)
    return m


def place(obj, m):
    obj.matrix_world = m @ obj.matrix_world
    return obj


def crystal(loc, size, mat, rng):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    o = bpy.context.active_object
    o.scale = (size, size, size * 0.9)
    bpy.ops.object.transform_apply(scale=True)
    finish(o, mat, bevel=size * 0.18, segments=1, smooth=False)
    o.rotation_euler = (rng.uniform(0, 3), rng.uniform(0, 3), rng.uniform(0, 3))
    o.location = loc
    return o


def revolve(profile, mats, nseg=64, zmod=None, rmod=None, mat_fn=None, name="rev", angle=45):
    """Like lathe() but with zmod(theta, j) / rmod(theta, j) per ring (for wavy skirts)."""
    bm = bmesh.new()
    rings = []
    for j, (r, z) in enumerate(profile):
        if r < 1e-6:
            v = bm.verts.new((0, 0, z))
            rings.append([v] * nseg)
            continue
        ring = []
        for i in range(nseg):
            th = 2 * math.pi * i / nseg
            rr = r * (rmod(th, j) if rmod else 1.0)
            zz = z + (zmod(th, j) if zmod else 0.0)
            ring.append(bm.verts.new((rr * math.cos(th), rr * math.sin(th), zz)))
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
    obj = link_bm(bm, name, mats)
    return shade(obj, angle)


def profile_r(profile, z):
    """Outer radius of a revolve profile at height z (outer side only, monotonic part)."""
    pts = [p for p in profile if p[0] > 1e-6]
    best = None
    for (r0, z0), (r1, z1) in zip(pts[:-1], pts[1:]):
        lo, hi = min(z0, z1), max(z0, z1)
        if lo <= z <= hi and hi - lo > 1e-9:
            t = (z - z0) / (z1 - z0)
            r = r0 + (r1 - r0) * t
            best = r if best is None else max(best, r)
    return best or 0.0


def surf_point(profile, x, z, zoff=0.0, inset=0.0):
    """Point + normal on the front (-Y) of a revolved body at lateral x and height z."""
    r = profile_r(profile, z - zoff)
    dz = 0.01
    dr = (profile_r(profile, z - zoff + dz) - profile_r(profile, z - zoff - dz)) / (2 * dz)
    x = max(-r * 0.95, min(r * 0.95, x))
    y = -math.sqrt(max(r * r - x * x, 0.0))
    n = Vector((x / r, y / r, -dr)).normalized()
    p = Vector((x, y, z)) - n * inset
    return p, n


def eye(m, rx, ry, pupil_dx=0.0, pupil_scale=0.55, look=(0.0, -0.1)):
    """Cream sclera + ink pupil + white glint, in the face frame m."""
    parts = []
    s = sphere(1.0, (0, 0, 0), glossy("white", 0.18, 0.9), scale=(rx, ry, min(rx, ry) * 0.45), seg=24, rings=12)
    parts.append(place(s, m))
    pr = min(rx, ry) * pupil_scale
    p = sphere(1.0, (pupil_dx + look[0] * rx, look[1] * ry, min(rx, ry) * 0.42), glossy("ink", 0.15, 0.9),
               scale=(pr, pr * 1.1, pr * 0.3), seg=20, rings=10)
    parts.append(place(p, m))
    g = sphere(1.0, (pupil_dx + look[0] * rx + pr * 0.35, look[1] * ry + pr * 0.4, min(rx, ry) * 0.42 + pr * 0.25),
               glossy("white", 0.1, 1.0), scale=(pr * 0.3, pr * 0.3, pr * 0.15), seg=12, rings=6)
    parts.append(place(g, m))
    return parts


def brow(m, length, thick, tilt_deg):
    """Chunky ink eyebrow bar in face frame m, tilted about the normal."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    o.scale = (length, thick, thick * 0.9)
    bpy.ops.object.transform_apply(scale=True)
    finish(o, glossy("ink", 0.2, 0.8), bevel=thick * 0.45, segments=3)
    o.rotation_euler = (0, 0, math.radians(tilt_deg))
    return place(o, m)


def frown(m, width, thick, depth=0.5):
    """Arc mouth with ends pointing down (angry), in face frame m."""
    R = width / 2 / math.sin(math.radians(60))
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=thick, major_segments=36, minor_segments=10)
    o = bpy.context.active_object
    bm = bmesh.new()
    bm.from_mesh(o.data)
    cy = R * math.cos(math.radians(60))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < cy - 1e-4], context="VERTS")
    # cap the two cut ends by closing holes
    bmesh.ops.holes_fill(bm, edges=bm.edges, sides=0)
    bm.to_mesh(o.data)
    bm.free()
    o.scale = (1, 1, depth)
    bpy.ops.object.transform_apply(scale=True)
    finish(o, glossy("ink", 0.2, 0.8))
    o.location = (0, -cy, 0)
    return place(o, m)


# --- 1. hopper -----------------------------------------------------------------

HOP_PROFILE = None


def hopper_profile():
    prof = [(0.0, 0.09), (0.36, 0.09), (0.44, 0.105), (0.49, 0.15), (0.505, 0.21)]
    # gumdrop: slightly tapered side, then dome
    for k in range(1, 5):
        z = 0.21 + 0.3 * k / 4
        prof.append((0.505 - 0.05 * (k / 4) ** 1.3, z))
    a, zc, h = 0.455, 0.51, 0.49
    for k in range(1, 15):
        t = math.pi / 2 * k / 14
        prof.append((a * math.cos(t) if k < 14 else 0.0, zc + h * math.sin(t)))
    return prof


def build_enemy_hopper():
    """Angry raspberry gumdrop. 1.0 wide, 1.0 tall, origin bottom centre, face -Y."""
    reset()
    rng = random.Random(7)
    prof = hopper_profile()
    body = glossy("raspberry", 0.2, 0.9)
    revolve(prof, [body], nseg=64, name="hopper")
    # sugar crystals, kept off the face
    sugar = glossy("white", 0.15, 1.0)
    n = 0
    while n < 46:
        th = rng.uniform(0, 2 * math.pi)
        z = rng.uniform(0.25, 0.96)
        front = abs(math.atan2(math.sin(th + math.pi / 2), math.cos(th + math.pi / 2)))
        if front < math.radians(62) and z < 0.9:
            continue
        r = profile_r(prof, z)
        if r < 0.08:
            continue
        crystal((r * math.cos(th) * 0.99, r * math.sin(th) * 0.99, z), rng.uniform(0.045, 0.07), sugar, rng)
        n += 1
    # feet
    for s in (-1, 1):
        sphere(1.0, (s * 0.22, -0.12, 0.085), glossy("cream", 0.25, 0.7), scale=(0.16, 0.22, 0.085), seg=32, rings=16)
    # face
    for s in (-1, 1):
        p, nrm = surf_point(prof, s * 0.17, 0.52, inset=0.02)
        eye(frame_matrix(p, nrm), 0.11, 0.13, pupil_dx=-s * 0.02, look=(-s * 0.1, -0.2))
        p, nrm = surf_point(prof, s * 0.17, 0.7, inset=0.01)
        brow(frame_matrix(p, nrm), 0.24, 0.07, -s * 24)
    p, nrm = surf_point(prof, 0.0, 0.33, inset=0.01)
    frown(frame_matrix(p, nrm), 0.18, 0.028)
    export_report("enemy_hopper")


# --- 2. stomper ----------------------------------------------------------------

def build_enemy_stomper():
    """Marshmallow crusher 1.9 x 1.4 (tall) x 1.9, origin at bottom centre (the crushing face)."""
    reset()
    rng = random.Random(11)
    BW = 1.72
    F = -BW / 2
    choc = glossy("chocolate", 0.25, 0.8)
    cube((1.9, 1.9, 0.34), (0, 0, 0.17), choc, bevel=0.1)
    cube((BW, BW, 0.95), (0, 0, 0.3 + 0.95 / 2), glossy("marsh", 0.3, 0.6), bevel=0.14)
    # cream frosting cap
    cube((1.84, 1.84, 0.3), (0, 0, 1.375 - 0.15), glossy("cream", 0.25, 0.7), bevel=0.13)
    # chocolate dip: wavy top edge blobs
    for side in range(4):
        rot = Matrix.Rotation(math.radians(90 * side), 4, "Z")
        for k in range(9):
            x = -0.8 + k * 0.2
            h = 0.06 + 0.05 * ((k * 37 + side * 13) % 5) / 4
            o = sphere(1.0, (x, F - 0.01, 0.32), choc, scale=(0.13, 0.05, h), seg=14, rings=7)
            o.matrix_world = rot @ o.matrix_world
    # frosting drips on the sides (avoid the brows)
    for side in range(4):
        rot = Matrix.Rotation(math.radians(90 * side), 4, "Z")
        for x, ln in ((-0.8, 0.22), (-0.58, 0.14), (0.0, 0.12), (0.62, 0.2), (0.82, 0.13)):
            z_top = 1.13
            o = sphere(1.0, (x * 0.92, F - 0.005, z_top - ln / 2), glossy("cream", 0.25, 0.7),
                       scale=(0.075, 0.035, ln / 2 + 0.03), seg=14, rings=7)
            o.matrix_world = rot @ o.matrix_world
            o = sphere(0.075, (x * 0.92, F - 0.005, z_top - ln), glossy("cream", 0.25, 0.7), scale=(1, 0.5, 1), seg=14, rings=7)
            o.matrix_world = rot @ o.matrix_world
    # sprinkles embedded in the top
    cols = ["pink", "lilac", "white", "raspberry"]
    for i in range(44):
        x, y = rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7)
        o = sphere(0.035, (0, 0, 0), glossy(cols[i % 4]), scale=(1, 2.6, 0.6), seg=10, rings=5)
        o.rotation_euler = (0, 0, rng.uniform(0, math.pi))
        o.location = (x, y, 1.378)
    # angry face on all four sides
    for side in range(4):
        rot = Matrix.Rotation(math.radians(90 * side), 4, "Z")
        for s in (-1, 1):
            m = rot @ frame_matrix((s * 0.36, F + 0.005, 0.72), (0, -1, 0))
            eye(m, 0.17, 0.19, pupil_dx=-s * 0.03, look=(-s * 0.1, -0.15))
            brow(rot @ frame_matrix((s * 0.36, F - 0.005, 0.95), (0, -1, 0)), 0.4, 0.1, -s * 22)
        # gritted teeth mouth
        mm = rot @ frame_matrix((0, F + 0.005, 0.46), (0, -1, 0))
        o = cube((0.56, 0.16, 0.06), (0, 0, 0), glossy("ink", 0.2, 0.8), bevel=0.05)
        place(o, mm)
        for k in range(4):
            t = cube((0.1, 0.1, 0.05), (-0.18 + k * 0.12, 0.015, 0.03), glossy("white", 0.2, 0.9), bevel=0.02)
            place(t, mm)
    export_report("enemy_stomper")


# --- 3. ghost ------------------------------------------------------------------

def ghost_profile():
    prof = [(0.0, 0.2), (0.22, 0.16), (0.4, 0.07), (0.49, 0.0), (0.525, 0.04), (0.525, 0.12)]
    for k in range(1, 4):
        prof.append((0.525 - 0.025 * k / 3, 0.12 + 0.43 * k / 3))
    for k in range(1, 15):
        t = math.pi / 2 * k / 14
        prof.append((0.5 * math.cos(t) if k < 14 else 0.0, 0.55 + 0.55 * math.sin(t)))
    return prof


def build_enemy_ghost():
    """Sour gummy ghost, 1.1 tall, ~1.05 wide, origin at its visual centre, face -Y."""
    reset()
    rng = random.Random(5)
    prof = ghost_profile()
    Z0 = -0.515   # centres the bbox (skirt waves dip ~0.07 below the profile)
    prof_w = [(r, z + Z0) for r, z in prof]
    top = glossy("sour_top", 0.12, 1.0)
    low = glossy("sour", 0.12, 1.0)

    def zmod(th, j):
        w = {1: 0.4, 2: 0.9, 3: 1.0, 4: 1.0, 5: 0.6, 6: 0.2}.get(j, 0.0)
        return 0.075 * w * math.cos(7 * th + math.pi / 2)

    def mat_fn(th, z, j):
        return 0 if z > Z0 + 0.72 + 0.04 * math.sin(3 * th) else 1

    revolve(prof_w, [top, low], nseg=70, zmod=zmod, mat_fn=mat_fn, name="ghost")
    # little arms
    for s in (-1, 1):
        o = sphere(1.0, (0, 0, 0), low, scale=(0.13, 0.1, 0.09), seg=24, rings=12)
        o.rotation_euler = (0, math.radians(s * 30), 0)
        o.location = (s * 0.47, -0.02, Z0 + 0.45)
    # sour sugar
    sugar = glossy("white", 0.15, 1.0)
    n = 0
    while n < 34:
        th = rng.uniform(0, 2 * math.pi)
        z = rng.uniform(0.2, 1.04)
        front = abs(math.atan2(math.sin(th + math.pi / 2), math.cos(th + math.pi / 2)))
        if front < math.radians(65) and 0.25 < z < 1.0:
            continue
        r = profile_r(prof, z)
        if r < 0.08:
            continue
        crystal((r * math.cos(th) * 0.99, r * math.sin(th) * 0.99, z + Z0), rng.uniform(0.035, 0.05), sugar, rng)
        n += 1
    # face
    for s in (-1, 1):
        p, nrm = surf_point(prof, s * 0.19, Z0 + 0.66, zoff=Z0, inset=0.03)
        eye(frame_matrix(p, nrm), 0.15, 0.18, pupil_dx=-s * 0.03, pupil_scale=0.6, look=(-s * 0.08, -0.15))
        p, nrm = surf_point(prof, s * 0.19, Z0 + 0.88, zoff=Z0, inset=0.01)
        brow(frame_matrix(p, nrm), 0.22, 0.065, -s * 26)
    p, nrm = surf_point(prof, 0.0, Z0 + 0.42, zoff=Z0, inset=0.01)
    frown(frame_matrix(p, nrm), 0.13, 0.024)
    export_report("enemy_ghost")


# --- 4. windmill hub -------------------------------------------------------------

def cane_mat(stripes=3, pitch=0.9):
    """Stripe by column only; pair with lathe(twist=cane_twist(...)) so edges follow the helix."""
    def fn(th, z, j):
        return 0 if ((th / (2 * math.pi)) * stripes) % 1.0 < 0.5 else 1
    return fn


def cane_twist(stripes=3, pitch=0.9):
    return 2 * math.pi / (stripes * pitch)


def build_windmill_hub():
    """Candy-cane post r 0.4 on a cookie base, 1.2 tall, origin bottom centre."""
    reset()
    rng = random.Random(3)
    base_prof = [(0.0, 0.0), (0.58, 0.0), (0.64, 0.03), (0.66, 0.1), (0.64, 0.17), (0.58, 0.2), (0.0, 0.2)]
    lathe(base_prof, [glossy("biscuit", 0.45, 0.3)], nseg=64, name="cookie")
    for i in range(12):
        a = 2 * math.pi * i / 12 + rng.uniform(-0.15, 0.15)
        r = rng.uniform(0.47, 0.54)
        o = sphere(0.05, (r * math.cos(a), r * math.sin(a), 0.2), glossy("chocolate"), scale=(1, 1, 0.55), seg=16, rings=8)
    prof = [(0.0, 0.18), (0.4, 0.18)]
    for k in range(1, 12):
        prof.append((0.4, 0.18 + 0.9 * k / 11))
    for k in range(1, 7):
        t = math.pi / 2 * k / 6
        prof.append((0.3 + 0.1 * math.cos(t), 1.08 + 0.1 * math.sin(t)))
    prof.append((0.0, 1.2))
    lathe(prof, [glossy("raspberry", 0.2, 0.9), glossy("cream", 0.22, 0.8)], nseg=64,
          mat_fn=cane_mat(3, 1.0), twist=cane_twist(3, 1.0), name="post")
    export_report("windmill_hub")


# --- 5. windmill arm -----------------------------------------------------------------

def rrect(hw, hh, rc, n=5, step=0.05):
    """Rounded rectangle profile with densified straight edges (CCW, in (u, v))."""
    pts = []
    corners = ((hw - rc, hh - rc, 0), (-hw + rc, hh - rc, 90), (-hw + rc, -hh + rc, 180), (hw - rc, -hh + rc, 270))
    for ci, (cx, cy, a0) in enumerate(corners):
        for k in range(n + 1):
            t = math.radians(a0 + 90 * k / n)
            pts.append((cx + rc * math.cos(t), cy + rc * math.sin(t)))
        nx = corners[(ci + 1) % 4]
        a1 = math.radians(a0 + 90)
        p0 = Vector((cx + rc * math.cos(a1), cy + rc * math.sin(a1)))
        t1 = math.radians(nx[2])
        p1 = Vector((nx[0] + rc * math.cos(t1), nx[1] + rc * math.sin(t1)))
        segs = max(1, int((p1 - p0).length / step))
        for k in range(1, segs):
            q = p0.lerp(p1, k / segs)
            pts.append((q.x, q.y))
    return pts


def build_windmill_arm():
    """Striped bar 9.0 along X, 0.45 wide, 0.6 tall, origin at centre, rounded ends, hub collar."""
    reset()
    L, HW, HH = 4.5, 0.225, 0.3
    prof = rrect(HW, HH, 0.13, n=6, step=0.05)   # (u = width along Y, v = height along Z)
    Re = HW
    stripe = 0.34
    SH = 0.7   # stripe slant: boundaries follow x + SH * z = const
    xs = []
    k0 = math.ceil(-(L - Re) / (stripe / 4))
    xs.append(-(L - Re))
    k = k0
    while k * stripe / 4 < L - Re - 1e-6:
        if k * stripe / 4 > -(L - Re) + 1e-6:
            xs.append(k * stripe / 4)
        k += 1
    xs.append(L - Re)
    end = [(L - Re) + Re * math.sin(math.pi / 2 * k / 10) for k in range(1, 10)]
    xs = [-e for e in reversed(end)] + xs + end
    bm = bmesh.new()
    rows = []
    for x in xs:
        d = abs(x) - (L - Re)
        s = math.sqrt(max(0.0, 1 - (d / Re) ** 2)) if d > 0 else 1.0
        w = max(0.0, min(1.0, (L - Re - abs(x)) / 0.5))   # shear fades out before the rounded ends
        rows.append([bm.verts.new((x - SH * v * w * s, u * s, v * (0.35 + 0.65 * s))) for u, v in prof])
    tipL = bm.verts.new((-L, 0, 0))
    tipR = bm.verts.new((L, 0, 0))
    N = len(prof)

    def midx(xr):
        return int(math.floor(xr / stripe + 1e-6)) % 2

    for ri, (a, b) in enumerate(zip(rows[:-1], rows[1:])):
        xr = xs[ri]
        for j in range(N):
            j2 = (j + 1) % N
            f = bm.faces.new((a[j], b[j], b[j2], a[j2]))
            f.material_index = midx(xr)
    for j in range(N):
        j2 = (j + 1) % N
        f = bm.faces.new((tipL, rows[0][j], rows[0][j2]))
        f.material_index = midx(-L)
        f = bm.faces.new((tipR, rows[-1][j2], rows[-1][j]))
        f.material_index = midx(xs[-2])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link_bm(bm, "arm", [glossy("raspberry", 0.2, 0.9), glossy("cream", 0.22, 0.8)])
    shade(obj, 60)
    # hub collar
    cylinder(0.42, 0.64, (0, 0, 0), glossy("cream", 0.22, 0.8), verts=48, bevel=0.08)
    torus(0.42, 0.06, (0, 0, 0.3), glossy("raspberry", 0.2, 0.9))
    torus(0.42, 0.06, (0, 0, -0.3), glossy("raspberry", 0.2, 0.9))
    sphere(0.26, (0, 0, 0.32), glossy("lilac", 0.2, 0.8), scale=(1, 1, 0.26 / 0.26 * 0.25), seg=32, rings=16)
    export_report("windmill_arm")


# --- 6. catapult base --------------------------------------------------------------

def beam(p0, p1, w, d, mat, bevel=0.05):
    """Beveled box from p0 to p1 (in the YZ plane), w along X, d thickness."""
    p0, p1 = Vector(p0), Vector(p1)
    v = p1 - p0
    ln = v.length
    o = cube((w, d, ln), (0, 0, 0), mat, bevel=bevel)
    ang = math.atan2(-v.y, v.z)
    o.rotation_euler = (ang, 0, 0)
    o.location = (p0 + p1) / 2
    return o


def build_catapult_base():
    """Wafer frame with two A-frame uprights and an axle along X at z 0.9, y 0."""
    reset()
    wafer = glossy("wafer", 0.4, 0.4)
    wafer_dk = glossy("biscuit", 0.4, 0.4)
    choc = glossy("chocolate", 0.25, 0.8)
    # base slab with raised wafer grid
    cube((1.8, 1.2, 0.18), (0, 0, 0.09), wafer, bevel=0.06)
    for i in range(5):
        x = -0.6 + i * 0.3
        cube((0.05, 1.08, 0.04), (x, 0, 0.18), wafer_dk, bevel=0.018)
    for i in range(3):
        y = -0.36 + i * 0.36
        cube((1.66, 0.05, 0.04), (0, y, 0.18), wafer_dk, bevel=0.018)
    # uprights: A-frames of chocolate-dipped wafer sticks
    for s in (-1, 1):
        x = s * 0.72
        for yy in (-0.46, 0.46):
            beam((x, yy, 0.12), (x, 0.0, PIVOT_Z), 0.15, 0.17, wafer, bevel=0.05)
        cube((0.19, 1.08, 0.12), (x, 0, 0.2), choc, bevel=0.05)   # chocolate foot rail
        cylinder(0.2, 0.2, (x, 0, PIVOT_Z), glossy("mint", 0.22, 0.8), rot=(0, math.radians(90), 0), bevel=0.05)
        cylinder(0.09, 0.08, (s * 0.87, 0, PIVOT_Z), glossy("lemon", 0.22, 0.8),
                 rot=(0, math.radians(90), 0), bevel=0.03)
        sphere(0.05, (s * 0.9, 0, PIVOT_Z), glossy("cream"), seg=16, rings=8)
    # axle
    cylinder(0.07, 1.7, (0, 0, PIVOT_Z), choc, rot=(0, math.radians(90), 0), verts=24, bevel=0.02)
    # a little chocolate stop bump at the back so the cup has a rest line
    export_report("catapult_base")


# --- 7. catapult arm ---------------------------------------------------------------------

def capsule_rod(p0, p1, r, mats, stripes=2, pitch=0.35, nseg=24):
    p0, p1 = Vector(p0), Vector(p1)
    ln = (p1 - p0).length
    prof = [(0.0, -r)]
    for k in range(1, 6):
        t = -math.pi / 2 + math.pi / 2 * k / 6
        prof.append((r * math.cos(t), r * math.sin(t)))
    nlen = max(2, int(ln / 0.08))
    for k in range(nlen + 1):
        prof.append((r, ln * k / nlen))
    for k in range(1, 6):
        t = math.pi / 2 * k / 6
        prof.append((r * math.cos(t), ln + r * math.sin(t)))
    prof.append((0.0, ln + r))
    o = lathe(prof, mats, nseg=nseg, mat_fn=cane_mat(stripes, pitch), twist=cane_twist(stripes, pitch), name="rod")
    return oriented(o, p0, p1 - p0)


def build_catapult_arm():
    """Throwing arm, origin at the pivot. Rests pointing back (+Y) and down, cup on the ground."""
    reset()
    cream = glossy("cream", 0.22, 0.8)
    # hub around the axle
    cylinder(0.19, 0.5, (0, 0, 0), glossy("coral", 0.22, 0.8), rot=(0, math.radians(90), 0), verts=40, bevel=0.05)
    for s in (-1, 1):
        torus(0.17, 0.045, (s * 0.25, 0, 0), cream, rot=(0, math.radians(90), 0))
    # bowl (ice-cream scoop)
    c = Vector((0, CUP_Y, CUP_CZ))
    prof = [(0.0, -CUP_R_OUT)]
    for k in range(1, 13):
        t = -math.pi / 2 + math.pi / 2 * k / 12
        prof.append((CUP_R_OUT * math.cos(t), CUP_R_OUT * math.sin(t)))
    for k in range(0, 12):
        t = -math.pi / 2 * k / 12
        prof.append((CUP_R_IN * math.cos(t), CUP_R_IN * math.sin(t)))
    prof.append((0.0, -CUP_R_IN))
    bowl = lathe(prof, [glossy("lemon", 0.2, 0.9)], nseg=64, name="bowl")
    bowl.location = c
    torus(0.5 * (CUP_R_IN + CUP_R_OUT), 0.065, (c.x, c.y, c.z), cream)
    # candy-striped rod
    stripe_mats = [glossy("mint", 0.2, 0.9), cream]
    dirv = Vector((0, -math.cos(math.radians(38)), -math.sin(math.radians(38))))
    attach = c + dirv * (CUP_R_OUT + 0.04)
    capsule_rod((0, 0.1, -0.03), attach, 0.12, stripe_mats, stripes=2, pitch=0.45, nseg=32)
    # coral cuff where the rod meets the bowl
    cuff = cylinder(0.14, 0.1, (0, 0, 0), glossy("coral", 0.22, 0.8), verts=32, bevel=0.03)
    oriented(cuff, c + dirv * (CUP_R_OUT + 0.03), dirv)
    export_report("catapult_arm")
    print(f"REPORT catapult_arm cup: bowl_centre_godot=(0, {CUP_CZ:.3f}, {-CUP_Y:.3f}) "
          f"ball_rest_centre_godot=(0, {CUP_CZ - CUP_R_IN + 0.5:.3f}, {-CUP_Y:.3f}) "
          f"outer_bottom_y={CUP_CZ - CUP_R_OUT:.3f}")


BUILDERS_E = {
    "enemy_hopper": build_enemy_hopper,
    "enemy_stomper": build_enemy_stomper,
    "enemy_ghost": build_enemy_ghost,
    "windmill_hub": build_windmill_hub,
    "windmill_arm": build_windmill_arm,
    "catapult_base": build_catapult_base,
    "catapult_arm": build_catapult_arm,
}


# --- contact sheet --------------------------------------------------------------

def render_preview(path=None):
    path = path or os.path.join(ROOT, "art", "preview-enemies.png")
    reset()
    ball_rest = CUP_CZ - CUP_R_IN + 0.5
    layout = [
        ("enemy_hopper", 0.0, 0.0, 0.0), ("enemy_stomper", 2.2, 0.0, 0.0), ("enemy_ghost", 4.6, 0.0, 1.0),
        ("enemy", 6.2, 0.0, 0.0),
        ("windmill_hub", 0.0, 4.0, 0.0), ("windmill_arm", 0.0, 4.0, 1.55),
        ("catapult_base", 7.6, 3.2, 0.0), ("catapult_arm", 7.6, 3.2, PIVOT_Z),
        ("ball", 7.6, 3.2 + CUP_Y, PIVOT_Z + ball_rest),
        ("catapult_base", 10.4, 0.2, 0.0), ("catapult_arm", 10.4, 0.2, PIVOT_Z),
    ]
    all_objs = []
    for idx, (name, x, y, z) in enumerate(layout):
        fp = os.path.join(OUT, f"{name}.glb")
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=fp)
        new = [o for o in bpy.context.scene.objects if o not in before]
        for o in new:
            if o.parent is None:
                if idx == len(layout) - 1:  # second catapult: arm mid-swing
                    o.matrix_world = Matrix.Rotation(math.radians(100), 4, "X") @ o.matrix_world
                o.location = (o.location.x + x, o.location.y + y, o.location.z + z)
        all_objs += [o for o in new if o.type == "MESH"]
    bpy.context.view_layer.update()

    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.005))
    floor = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.78, 0.72, 0.76, 1)
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
        bg.inputs["Color"].default_value = (0.97, 0.93, 0.95, 1)
        bg.inputs["Strength"].default_value = 0.45
    except Exception:
        world.color = (0.97, 0.93, 0.95)

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
    names = argv or list(BUILDERS_E) + ["preview"]
    for name in names:
        if name == "preview":
            render_preview()
        else:
            BUILDERS_E[name]()

"""Builds all Candy Marble 3D assets and exports them to models/*.glb.

Run headless from the repo root:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/build_assets.py

Axis note: Blender is Z-up, glTF/Godot is Y-up. Blender -Y becomes Godot +Z,
which is the "forward" direction for every asset (enemy faces, booster arrows,
loop travel direction).
"""
import math
import os
import sys

import bmesh
import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "models")
os.makedirs(OUT, exist_ok=True)

PALETTE = {
    "mint": "#A8E6C8",
    "pink": "#F7B2C0",
    "lemon": "#F6E27A",
    "lilac": "#C9B8EC",
    "sky": "#A9D6F5",
    "raspberry": "#C8204F",
    "coral": "#F6845E",
    "cream": "#FFF4E0",
    "white": "#FBF8F4",
    "ink": "#3A1F2B",
    "chocolate": "#5A3426",
    "gummy": "#B99BF0",
}


# --- helpers ------------------------------------------------------------------

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, roughness=0.28, coat=0.6, alpha=1.0):
    key = f"{name}_{roughness}_{coat}"
    if key in bpy.data.materials:
        return bpy.data.materials[key]
    hexv = PALETTE[name].lstrip("#")
    rgb = [srgb_to_linear(int(hexv[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    m = bpy.data.materials.new(key)
    try:
        m.use_nodes = True
    except Exception:
        pass
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.12
    return m


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def finish(obj, mat, smooth=True, bevel=0.0, segments=4, subsurf=0):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
    if subsurf:
        mod = obj.modifiers.new("Subsurf", "SUBSURF")
        mod.levels = subsurf
        mod.render_levels = subsurf
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def cube(size, loc, mat, bevel=0.12, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, mat, bevel=bevel, segments=5)


def sphere(r, loc, mat, scale=(1, 1, 1), seg=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, mat)


def cylinder(r, depth, loc, mat, rot=(0, 0, 0), verts=40, bevel=0.03, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    return finish(o, mat, bevel=bevel, segments=3)


def cone(r, depth, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=r, radius2=0.0, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    return finish(o, mat)


def torus(major, minor, loc, mat, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=48,
                                     minor_segments=16, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, mat)


def export(name):
    """Joins everything in the scene into one object and exports it."""
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    # Apply modifiers per object before joining.
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    path = os.path.join(OUT, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print(f"exported {path}")


# --- assets -------------------------------------------------------------------

def build_ball():
    """Peppermint marble, diameter 1, two raspberry swirls."""
    reset()
    o = sphere(0.5, (0, 0, 0), material("white", 0.22, 0.8), seg=96, rings=48)
    o.data.materials.append(material("raspberry", 0.22, 0.8))
    for p in o.data.polygons:
        c = p.center
        theta = math.atan2(c.y, c.x)
        phi = math.acos(max(-1.0, min(1.0, c.z / 0.5)))
        band = (theta / math.pi + phi / math.pi * 1.6) % 1.0
        if band < 0.16 or 0.5 <= band < 0.66:
            p.material_index = 1
    export("ball")


def build_enemy():
    """Wind-up spiky raspberry block, 1 x 1 x 1.15 body, face towards -Y (Godot +Z)."""
    reset()
    body = material("raspberry", 0.3)
    cube((1.0, 1.0, 1.15), (0, 0, 0.82), body, bevel=0.18)
    for fx in (-0.25, 0.25):
        cube((0.3, 0.42, 0.26), (fx, -0.05, 0.13), material("lilac"), bevel=0.1)
    for i in range(5):
        cone(0.09, 0.26, (-0.36 + i * 0.18, 0, 1.49), material("cream"))
    for ex in (-0.2, 0.2):
        sphere(0.075, (ex, -0.5, 0.92), material("ink", 0.2), seg=16, rings=8)
        tilt = math.radians(-20 if ex < 0 else 20)
        cube((0.3, 0.06, 0.07), (ex, -0.51, 1.09), material("ink", 0.2), bevel=0.02, rot=(0, tilt, 0))
    cube((0.24, 0.05, 0.04), (0, -0.51, 0.72), material("ink", 0.2), bevel=0.015)
    # Wind-up key on the back (+Y).
    cylinder(0.05, 0.2, (0, 0.6, 0.9), material("lilac"), rot=(math.radians(90), 0, 0), bevel=0.01)
    torus(0.13, 0.05, (-0.13, 0.72, 0.9), material("lilac"), rot=(math.radians(90), 0, 0))
    torus(0.13, 0.05, (0.13, 0.72, 0.9), material("lilac"), rot=(math.radians(90), 0, 0))
    export("enemy")


def build_bumper():
    """Lemon mushroom pop bumper, cap radius 0.8."""
    reset()
    cylinder(0.36, 0.8, (0, 0, 0.4), material("cream"), r2=0.3, bevel=0.08)
    sphere(0.8, (0, 0, 0.95), material("lemon", 0.25, 0.7), scale=(1, 1, 0.5))
    for i in range(14):
        a = 2 * math.pi * i / 14
        sphere(0.065, (math.cos(a) * 0.6, math.sin(a) * 0.6, 1.24), material("cream"), seg=16, rings=8)
    sphere(0.07, (0, 0, 1.36), material("cream"), seg=16, rings=8)
    export("bumper")


def build_booster():
    """Coral pad, 1.9 x 1.9, three cream chevrons pointing -Y (Godot +Z)."""
    reset()
    cube((1.9, 1.9, 0.1), (0, 0, 0.05), material("coral", 0.3), bevel=0.05)
    for k in range(3):
        tip = -0.55 + k * 0.45  # towards -Y
        for side in (-1, 1):
            cube((0.62, 0.15, 0.07), (side * 0.2, tip + 0.2, 0.12), material("cream"),
                 bevel=0.03, rot=(0, 0, math.radians(45 * side)))
    export("booster")


def build_flag():
    """Goal flag + hole rim. The hole itself is cut into the terrain."""
    reset()
    torus(0.95, 0.09, (0, 0, 0.0), material("cream"), scale=(1, 1, 0.6))
    cylinder(0.035, 1.9, (0.72, 0.72, 0.95), material("white"), verts=16, bevel=0.01)
    sphere(0.07, (0.72, 0.72, 1.92), material("lemon"), seg=16, rings=8)
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.35, depth=0.05, location=(0.72, 1.02, 1.62),
                                    rotation=(math.radians(90), 0, 0))
    f = bpy.context.active_object
    f.scale = (1.0, 1.0, 1.0)
    finish(f, material("lemon"), bevel=0.02)
    export("flag")


def build_lollipop():
    reset()
    cylinder(0.05, 1.3, (0, 0, 0.65), material("cream"), verts=16, bevel=0.01)
    disc = sphere(0.45, (0, 0, 1.5), material("pink"), scale=(1, 0.28, 1), seg=64, rings=32)
    disc.data.materials.append(material("white"))
    for p in disc.data.polygons:
        c = p.center
        r = math.hypot(c.x, c.z - 1.5)
        a = math.atan2(c.z - 1.5, c.x)
        if ((r * 7.0 - a / (2 * math.pi)) % 1.0) < 0.4:
            p.material_index = 1
    export("lollipop")


def build_tree():
    """Cotton-candy tree."""
    reset()
    cylinder(0.12, 0.7, (0, 0, 0.35), material("cream"), r2=0.09, verts=16)
    sphere(0.55, (0, 0, 0.95), material("mint", 0.4, 0.3))
    sphere(0.42, (0.12, 0.05, 1.38), material("pink", 0.4, 0.3))
    sphere(0.3, (-0.05, 0.0, 1.72), material("lilac", 0.4, 0.3))
    export("tree")


def build_bear():
    """Gummy bear decoration, ~1.1 tall, facing -Y."""
    reset()
    g = material("gummy", 0.15, 0.9)
    sphere(0.36, (0, 0, 0.36), g, scale=(1, 0.9, 1.05))              # belly
    sphere(0.3, (0, -0.02, 0.86), g, scale=(1.05, 0.95, 0.95))       # head
    for s in (-1, 1):
        sphere(0.11, (s * 0.21, 0.02, 1.08), g)                       # ears
        sphere(0.12, (s * 0.3, -0.05, 0.5), g, scale=(0.9, 0.9, 1.3))  # arms
        sphere(0.14, (s * 0.2, -0.12, 0.1), g, scale=(1, 1.4, 0.8))    # feet
        sphere(0.04, (s * 0.1, -0.28, 0.92), material("sky", 0.2), seg=16, rings=8)
    sphere(0.06, (0, -0.3, 0.82), material("sky", 0.2), scale=(1.2, 0.8, 0.9), seg=16, rings=8)
    export("bear")


def build_loop():
    """Loop-the-loop channel track.

    Travel is towards -Y (Godot +Z). Lead-in from y=+3 at x=0, a vertical loop of
    radius R that drifts sideways by SHIFT so the exit lane sits next to the
    entry lane, then a lead-out to y=-3 at x=SHIFT. The ball rolls on the inside.
    """
    reset()
    R = 2.2
    SHIFT = 2.1
    LEAD = 3.0
    FLAT = 0.45     # half width of the flat channel floor
    WALL = 0.3      # rounded wall width
    WALL_H = 0.5
    SINK = 0.08     # lead-in/out start below ground so there is no lip to hit

    profile = []
    for i in range(-6, 7):
        u = i / 6.0 * (FLAT + WALL)
        a = max(0.0, (abs(u) - FLAT) / WALL)
        h = WALL_H * (1.0 - math.sqrt(max(0.0, 1.0 - a * a)))
        profile.append((u, h))

    path = []  # (point, inward normal)
    for i in range(12):
        path.append(((0.0, LEAD - LEAD * i / 12.0, -SINK * (1.0 - i / 12.0)), (0.0, 0.0, 1.0)))
    n_loop = 120
    for k in range(n_loop + 1):
        t = 2.0 * math.pi * k / n_loop
        p = (SHIFT * k / n_loop, -R * math.sin(t), R * (1.0 - math.cos(t)))
        n = (0.0, math.sin(t), math.cos(t))
        path.append((p, n))
    for i in range(1, 13):
        path.append(((SHIFT, -LEAD * i / 12.0, -SINK * i / 12.0), (0.0, 0.0, 1.0)))

    bm = bmesh.new()
    rows = []
    for idx, (p, n) in enumerate(path):
        # Flared mouth on the lead-in so a slightly off-centre ball still gets in.
        flare = 1.0 + 0.9 * max(0.0, 1.0 - idx / 12.0)
        row = []
        for u, h in profile:
            row.append(bm.verts.new((p[0] + u * flare + n[0] * h, p[1] + n[1] * h, p[2] + n[2] * h)))
        rows.append(row)
    for a, b in zip(rows[:-1], rows[1:]):
        for j in range(len(profile) - 1):
            bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    # Make faces point at the ball side (inward normal at the first sample = up).
    if bm.faces[0].normal.z < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new("loop")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("loop", me)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    finish(obj, material("pink", 0.25, 0.7))
    obj.data.materials.append(material("cream", 0.3, 0.5))
    # Colour the rounded walls cream.
    edge_cols = {0, 1, len(profile) - 3, len(profile) - 2}
    cols = len(profile) - 1
    for idx, poly in enumerate(obj.data.polygons):
        if idx % cols in edge_cols:
            poly.material_index = 1
    sol = obj.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.12
    sol.offset = -1.0
    export("loop")


def build_cloud():
    reset()
    w = material("white", 0.6, 0.0)
    for x, y, z, r in [(0, 0, 0, 1.0), (0.9, 0.2, -0.1, 0.8), (-0.9, -0.1, -0.15, 0.75),
                       (0.3, -0.6, 0.2, 0.7), (-0.3, 0.6, 0.15, 0.65)]:
        sphere(r, (x, y, z), w, seg=32, rings=16)
    export("cloud")


def build_rainbow():
    """Big backdrop rainbow: concentric half rings, 12 units wide."""
    reset()
    colors = ["raspberry", "coral", "lemon", "mint", "sky", "lilac"]
    for k, c in enumerate(colors):
        o = torus(6.0 - k * 0.45, 0.24, (0, 0, 0), material(c, 0.35, 0.4), rot=(math.radians(90), 0, 0))
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.05], context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
    for x in (-5.0, 5.0):
        sphere(1.1, (x + (0.8 if x < 0 else -0.8) * 0.0, 0, 0.1), material("white", 0.6, 0.0), scale=(1.6, 1.0, 0.9))
    export("rainbow")


def build_balloon():
    reset()
    sphere(0.6, (0, 0, 1.6), material("pink", 0.2, 0.8), scale=(1, 1, 1.18))
    cone(0.12, 0.18, (0, 0, 0.86), material("pink", 0.2, 0.8), rot=(math.radians(180), 0, 0))
    cylinder(0.012, 0.9, (0, 0, 0.35), material("white"), verts=8, bevel=0.0)
    export("balloon")


def build_islet():
    """Small floating candy island for the backdrop: 3x3 pillow tiles on chocolate."""
    reset()
    cube((6.0, 6.0, 2.2), (0, 0, -1.1), material("chocolate", 0.3), bevel=0.35)
    for ix in range(3):
        for iy in range(3):
            cube((1.86, 1.86, 0.4), (-2 + ix * 2, -2 + iy * 2, 0.15), material("mint", 0.3), bevel=0.16)
    cylinder(0.14, 0.8, (0.6, 0.4, 0.75), material("cream"), r2=0.1, verts=16)
    sphere(0.6, (0.6, 0.4, 1.4), material("pink", 0.4, 0.3))
    sphere(0.45, (0.7, 0.45, 1.9), material("lilac", 0.4, 0.3))
    cylinder(0.05, 1.4, (-1.3, -1.0, 1.05), material("cream"), verts=12, bevel=0.0)
    sphere(0.5, (-1.3, -1.0, 1.9), material("lemon"), scale=(1, 0.3, 1))
    sphere(0.8, (0, 0, -2.6), material("white", 0.6, 0.0), scale=(2.4, 2.0, 0.8))
    export("islet")


BUILDERS = {
    "ball": build_ball,
    "enemy": build_enemy,
    "bumper": build_bumper,
    "booster": build_booster,
    "flag": build_flag,
    "lollipop": build_lollipop,
    "tree": build_tree,
    "bear": build_bear,
    "loop": build_loop,
    "cloud": build_cloud,
    "rainbow": build_rainbow,
    "balloon": build_balloon,
    "islet": build_islet,
}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name in argv or BUILDERS:
        BUILDERS[name]()

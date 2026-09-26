"""Renders a contact sheet of every exported model to art/models-preview.png.
    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/preview.py
"""
import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.read_factory_settings(use_empty=True)
names = ["rainbow", "islet", "balloon", "cloud", "loop"]
x = 0.0
for n in names:
    path = os.path.join(ROOT, "models", f"{n}.glb")
    if not os.path.exists(path):
        continue
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.context.scene.objects if o not in before]
    width = 6.0 if n == "loop" else 2.6
    for o in new:
        if o.parent is None:
            o.location.x += x + width / 2
    x += width

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.01))
floor = bpy.context.active_object
m = bpy.data.materials.new("floor")
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.75, 0.85, 0.95, 1)
floor.data.materials.append(m)

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = x * 1.0
cam = bpy.data.objects.new("cam", cam_data)
bpy.context.collection.objects.link(cam)
center = Vector((x / 2, 0, 1.0))
direction = Vector((0.25, -1, 0.7)).normalized()
cam.location = center + direction * 40
cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam

sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 3.0
sun_o = bpy.data.objects.new("sun", sun)
sun_o.rotation_euler = (math.radians(40), 0, math.radians(30))
bpy.context.collection.objects.link(sun_o)
world = bpy.data.worlds.new("w")
bpy.context.scene.world = world
world.color = (0.8, 0.8, 0.85)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 2400
scene.render.resolution_y = 640
scene.render.filepath = os.path.join(ROOT, "art", "models-preview.png")
bpy.ops.render.render(write_still=True)
print("rendered", scene.render.filepath)

"""Removes the baked-in transparency checkerboard around the logo.

Run with Blender's Python (it ships numpy):
    Blender -b -P tools/cut_logo.py -- art/reference/08-logo-source.jpg art/ui/logo.png

Flood-fills from the image border over light, grey-ish pixels (the checker
squares); the chocolate outline stops the fill so the cream inside survives.
"""
import sys

import bpy
import numpy as np

src, dst = sys.argv[sys.argv.index("--") + 1:][:2]
img = bpy.data.images.load(src)
w, h = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
rgb = px[:, :, :3]
spread = rgb.max(axis=2) - rgb.min(axis=2)
bright = rgb.min(axis=2)
candidate = (spread < 0.09) & (bright > 0.72)

region = np.zeros_like(candidate)
region[0, :] = candidate[0, :]
region[-1, :] = candidate[-1, :]
region[:, 0] = candidate[:, 0]
region[:, -1] = candidate[:, -1]
for _ in range(4000):
    grown = region.copy()
    grown[1:, :] |= region[:-1, :]
    grown[:-1, :] |= region[1:, :]
    grown[:, 1:] |= region[:, :-1]
    grown[:, :-1] |= region[:, 1:]
    grown &= candidate
    if (grown == region).all():
        break
    region = grown

alpha = np.where(region, 0.0, 1.0).astype(np.float32)
# Soften the cut edge a little: pixels touching the background get partial alpha.
edge = np.zeros_like(region)
edge[1:, :] |= region[:-1, :]
edge[:-1, :] |= region[1:, :]
edge[:, 1:] |= region[:, :-1]
edge[:, :-1] |= region[:, 1:]
edge &= ~region
alpha[edge] = 0.6
# Keep only the logo itself: the opaque region connected to the image centre
# (drops stray JPG specks left in the background).
solid = alpha > 0.5
keep = np.zeros_like(solid)
keep[h // 2, w // 2] = solid[h // 2, w // 2]
for _ in range(4000):
    grown = keep.copy()
    grown[1:, :] |= keep[:-1, :]
    grown[:-1, :] |= keep[1:, :]
    grown[:, 1:] |= keep[:, :-1]
    grown[:, :-1] |= keep[:, 1:]
    grown &= solid
    if (grown == keep).all():
        break
    keep = grown
near = keep.copy()
near[1:, :] |= keep[:-1, :]
near[:-1, :] |= keep[1:, :]
near[:, 1:] |= keep[:, :-1]
near[:, :-1] |= keep[:, 1:]
alpha[~near] = 0.0
px[:, :, 3] = alpha

# Crop to the logo with a small margin (image rows are bottom-up in Blender).
ys, xs = np.nonzero(alpha > 0.5)
m = 12
y0, y1 = max(ys.min() - m, 0), min(ys.max() + m, h - 1)
x0, x1 = max(xs.min() - m, 0), min(xs.max() + m, w - 1)
crop = px[y0:y1 + 1, x0:x1 + 1].copy()
out = bpy.data.images.new("logo", width=crop.shape[1], height=crop.shape[0], alpha=True)
out.pixels = crop.ravel()
out.filepath_raw = dst
out.file_format = "PNG"
out.save()
print(f"saved {dst} {crop.shape[1]}x{crop.shape[0]}, removed {region.mean() * 100:.1f}% of pixels")

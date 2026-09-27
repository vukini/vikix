#!/usr/bin/env python3
# lib/make-wallpaper.py — how themes/void.jpg and themes/paper.jpg were made.
#
#   python3 lib/make-wallpaper.py void themes/void.jpg
#
# Not run by the install (it needs numpy and Pillow); kept so the pictures
# can be made again, or a new theme's drawn the same way.
#
# A gentle gradient, two wide soft
# glows in the theme's colours, and fine grain so the gradient doesn't band.
import sys, numpy as np
from PIL import Image
W, H = 3840, 2160
def rgb(h): return np.array([int(h[i:i+2], 16) for i in (1, 3, 5)], float)
def make(out, top, bottom, glows, grain):
    y = np.linspace(0, 1, H)[:, None, None]
    x = np.linspace(0, 1, W)[None, :, None]
    img = rgb(top) * (1 - y) + rgb(bottom) * y
    img = np.broadcast_to(img, (H, W, 3)).copy()
    for colour, cx, cy, r, strength in glows:
        d2 = ((x - cx) * W / H) ** 2 + (y - cy) ** 2
        a = strength * np.exp(-d2 / (2 * r * r))
        img = img * (1 - a) + rgb(colour) * a
    img += np.random.default_rng(1).normal(0, grain, (H, W, 1))
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(out, quality=90, optimize=True)
which = sys.argv[1]
if which == "void":
    make(sys.argv[2], "#1e1e2e", "#11111b",
         [("#89b4fa", 0.82, 0.78, 0.38, 0.16),    # blue, low right
          ("#cba6f7", 0.12, 0.10, 0.34, 0.10)],   # mauve, top left
         1.6)
else:
    make(sys.argv[2], "#eff1f5", "#dce0e8",
         [("#1e66f5", 0.82, 0.80, 0.40, 0.08),
          ("#ea76cb", 0.12, 0.08, 0.34, 0.06)],
         1.2)

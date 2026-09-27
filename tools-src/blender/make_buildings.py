"""Builds two faceted low-poly houses in two styles, for the owner to compare:
  house_cottage: stone base, cream plaster, dark timber beams, steep red shingle roof, chimney.
  house_cabin:   log walls, dark slate roof with a deep overhang, porch with posts and a lantern.
Front faces -Y in Blender (+Z in Godot, towards the camera). Exported to game/assets/buildings/.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_buildings.py
"""
import math
import os
import random
import sys
import bpy
import bmesh
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, export  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "buildings")
rnd = random.Random(9)


def box(b, center, size, color, var=0.03):
    def make():
        geom = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in geom["verts"]:
            v.co = V((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + center
    for f in b.new_faces(make):
        k = 1.0 + rnd.uniform(-var, var)
        b.paint([f], "Build", tuple(min(1.0, c * k) for c in color))


def gable_roof(b, center, width, depth, height, overhang, thick, color):
    """A pitched roof: two sloped slabs meeting at a ridge along X, with gable ends left open."""
    w, d = width / 2 + overhang, depth / 2 + overhang
    for side in (-1, 1):
        def make(side=side):
            bm = b.bm
            eave = [V((x, side * d, 0)) + center for x in (-w, w)]
            ridge = [V((x, 0, height)) + center for x in (-w, w)]
            top = [bm.verts.new(p) for p in (eave[0], eave[1], ridge[1], ridge[0])]
            bot = [bm.verts.new(p - V((0, 0, thick))) for p in (eave[0], eave[1], ridge[1], ridge[0])]
            bm.faces.new(top if side < 0 else list(reversed(top)))
            bm.faces.new(list(reversed(bot)) if side < 0 else bot)
            for i in range(4):
                j = (i + 1) % 4
                bm.faces.new((top[i], top[j], bot[j], bot[i]) if side < 0 else (top[j], top[i], bot[i], bot[j]))
        for f in b.new_faces(make):
            b.paint([f], "Build", tuple(c * (1.0 + rnd.uniform(-0.04, 0.03)) for c in color))
    # Gable walls (triangles) under the roof.
    for x in (-width / 2, width / 2):
        def tri(x=x):
            bm = b.bm
            vs = [bm.verts.new(V((x, -depth / 2, 0)) + center), bm.verts.new(V((x, depth / 2, 0)) + center),
                  bm.verts.new(V((x, 0, height - thick)) + center)]
            bm.faces.new(vs if x > 0 else list(reversed(vs)))
        b.paint(b.new_faces(tri), "Build", WALL_GABLE)


WALL_GABLE = (0.9, 0.85, 0.74)


def window(b, x, z, y_front, w=0.55, h=0.6, frame=(0.36, 0.24, 0.16)):
    box(b, V((x, y_front - 0.03, z)), (w + 0.12, 0.08, h + 0.12), frame)
    box(b, V((x, y_front - 0.06, z)), (w, 0.06, h), (0.28, 0.38, 0.5), 0.0)
    box(b, V((x, y_front - 0.1, z)), (0.06, 0.04, h), frame, 0.0)


def cottage():
    b = Builder(["Build"])
    W, D, H = 4.2, 3.2, 2.5
    box(b, V((0, 0, 0.2)), (W + 0.3, D + 0.3, 0.7), (0.6, 0.6, 0.58), 0.06)              # stone base
    box(b, V((0, 0, 0.55 + H / 2)), (W, D, H), (0.9, 0.85, 0.74))                          # plaster walls
    beam = (0.3, 0.2, 0.14)
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            box(b, V((x, y, 0.55 + H / 2)), (0.2, 0.2, H + 0.05), beam)                    # corner posts
    for y in (-D / 2, D / 2):
        box(b, V((0, y, 0.55 + H)), (W + 0.1, 0.2, 0.18), beam)                            # top beams
        box(b, V((0, y, 0.55 + H * 0.45)), (W, 0.16, 0.14), beam)                          # mid beams
    box(b, V((0, -D / 2 - 0.02, 0.55 + 0.95)), (0.95, 0.12, 1.9), (0.42, 0.28, 0.18))     # door
    box(b, V((0, -D / 2 - 0.05, 0.55 + 1.98)), (1.15, 0.14, 0.14), beam)
    for x in (-1.35, 1.35):
        window(b, x, 0.55 + 1.45, -D / 2)
    gable_roof(b, V((0, 0, 0.55 + H)), W, D, 1.9, 0.45, 0.16, (0.66, 0.28, 0.22))         # red shingle roof
    box(b, V((1.1, 0.6, 0.55 + H + 1.6)), (0.5, 0.5, 1.5), (0.55, 0.55, 0.53), 0.06)     # chimney
    return b


def cabin():
    b = Builder(["Build", "Glow"])
    W, D, H = 4.0, 3.2, 2.3
    box(b, V((0, 0, 0.12)), (W + 0.2, D + 0.2, 0.5), (0.5, 0.5, 0.48), 0.05)
    log = [(0.66, 0.47, 0.3), (0.6, 0.42, 0.26), (0.72, 0.52, 0.33)]
    z = 0.4
    while z < 0.4 + H:
        for y in (-D / 2, D / 2):
            b.paint(b.new_faces(lambda y=y, z=z: rk.tube(b.bm, [V((-W / 2 - 0.15, y, z)), V((W / 2 + 0.15, y, z))],
                                                        [(0.14, 0.14)] * 2, ref=V((0, 0, 1)), seg=6)), "Build", rnd.choice(log))
        for x in (-W / 2, W / 2):
            b.paint(b.new_faces(lambda x=x, z=z: rk.tube(b.bm, [V((x, -D / 2 - 0.15, z + 0.12)), V((x, D / 2 + 0.15, z + 0.12))],
                                                        [(0.14, 0.14)] * 2, ref=V((0, 0, 1)), seg=6)), "Build", rnd.choice(log))
        z += 0.26
    box(b, V((0, 0, 0.4 + H / 2)), (W - 0.1, D - 0.1, H), (0.56, 0.4, 0.25), 0.0)          # inner fill
    box(b, V((0.6, -D / 2 - 0.1, 0.4 + 0.9)), (0.9, 0.1, 1.8), (0.3, 0.2, 0.13))           # door
    window(b, -1.05, 0.4 + 1.3, -D / 2 - 0.08, frame=(0.28, 0.2, 0.14))
    gable_roof(b, V((0, 0, 0.4 + H + 0.1)), W, D, 1.6, 0.7, 0.18, (0.44, 0.5, 0.58))     # slate roof
    # Porch: a little roof on two posts, and a warm lantern.
    for x in (-1.6, 1.6):
        box(b, V((x, -D / 2 - 1.0, 0.4 + 1.05)), (0.16, 0.16, 2.1), (0.4, 0.27, 0.17))
    box(b, V((0, -D / 2 - 0.55, 0.4 + 2.15)), (3.8, 1.3, 0.14), (0.44, 0.5, 0.58))
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((1.25, -D / 2 - 0.12, 0.4 + 1.9)), (0.1, 0.1, 0.14), 6, 4)), "Glow", (1.0, 0.72, 0.35))
    return b


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Build": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)
os.makedirs(OUT, exist_ok=True)
export("house_cottage", cottage(), OUT)
export("house_cabin", cabin(), OUT)

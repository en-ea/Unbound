"""Builds two detailed faceted low-poly houses in two styles, for the owner to compare:
  house_cottage: stone-block foundation, plaster walls with timber framing and braces, tiered red
                 shingle roof with ridge beam, planked door and step, shuttered windows with flower
                 boxes, stone chimney, lean-to with barrels and a crate.
  house_cabin:   round logs with light cut ends, tiered slate roof, stone side chimney, railed plank
                 porch with steps, shutters, lantern, woodpile.
Front faces -Y in Blender (+Z in Godot, towards the camera). Exported to game/assets/buildings/.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_buildings.py
"""
import os
import random
import sys
import bpy
import bmesh
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, clump, export  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "buildings")
rnd = random.Random(9)

PLASTER = (0.92, 0.87, 0.76)
TIMBER = (0.36, 0.24, 0.16)
STONE = [(0.62, 0.61, 0.58), (0.55, 0.55, 0.53), (0.68, 0.66, 0.62), (0.5, 0.5, 0.5)]
RED_ROOF = [(0.7, 0.3, 0.22), (0.64, 0.26, 0.2), (0.76, 0.35, 0.25)]
SLATE = [(0.42, 0.47, 0.55), (0.37, 0.42, 0.5), (0.47, 0.52, 0.6)]
WOOD = [(0.66, 0.47, 0.3), (0.6, 0.42, 0.26), (0.72, 0.52, 0.33)]
SHUTTER = (0.3, 0.46, 0.44)
GLASS = (0.3, 0.42, 0.55)


def paint(b, faces, color, var=0.03):
    for f in faces:
        k = 1.0 + rnd.uniform(-var, var)
        b.paint([f], "Build", tuple(min(1.0, c * k) for c in color))


def box(b, center, size, color, var=0.03):
    def make():
        geom = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in geom["verts"]:
            v.co = V((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + center
    paint(b, b.new_faces(make), color, var)


def beam(b, p0, p1, w, color):
    """A square timber between two points."""
    d = (p1 - p0).normalized()
    ref = V((0, 0, 1)) if abs(d.z) < 0.9 else V((1, 0, 0))
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [p0, p1], [(w, w)] * 2, ref=ref, seg=4)), color)


def slab(b, quad, thick, color):
    """A thick four-cornered plate (a row of roof shingles, a porch plank)."""
    def make():
        bm = b.bm
        top = [bm.verts.new(p) for p in quad]
        bot = [bm.verts.new(p - V((0, 0, thick))) for p in quad]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((top[j], top[i], bot[i], bot[j]))
    paint(b, b.new_faces(make), color, 0.05)


def tiered_roof(b, base, width, depth, height, overhang, rows, palette, ridge_color, gable_color):
    """A pitched roof built from overlapping rows of shingles, with a ridge beam and gable walls."""
    w = width / 2 + overhang
    d = depth / 2 + overhang
    for side in (-1, 1):
        for i in range(rows):
            t0, t1 = i / rows, (i + 1.15) / rows
            y0, y1 = side * d * (1 - t0), side * d * max(0.0, 1 - t1)
            z0, z1 = height * t0, height * min(1.0, t1)
            quad = [base + V((-w, y0, z0 + 0.05)), base + V((w, y0, z0 + 0.05)), base + V((w, y1, z1 + 0.05)), base + V((-w, y1, z1 + 0.05))]
            if side > 0:
                quad = list(reversed(quad))
            slab(b, quad, 0.1, rnd.choice(palette))
    beam(b, base + V((-w - 0.05, 0, height + 0.08)), base + V((w + 0.05, 0, height + 0.08)), 0.1, ridge_color)
    for x in (-width / 2, width / 2):
        def tri(x=x):
            bm = b.bm
            vs = [bm.verts.new(base + V((x, -depth / 2, 0))), bm.verts.new(base + V((x, depth / 2, 0))), bm.verts.new(base + V((x, 0, height - 0.05)))]
            bm.faces.new(vs if x > 0 else list(reversed(vs)))
        paint(b, b.new_faces(tri), gable_color)


def window(b, x, z, y_front, w=0.6, h=0.7, flowers=False, frame=TIMBER):
    box(b, V((x, y_front - 0.02, z)), (w + 0.14, 0.1, h + 0.14), frame)
    box(b, V((x, y_front - 0.05, z)), (w, 0.06, h), GLASS, 0.0)
    box(b, V((x, y_front - 0.09, z)), (0.05, 0.04, h), frame, 0.0)
    box(b, V((x, y_front - 0.09, z)), (w, 0.04, 0.05), frame, 0.0)
    for s in (-1, 1):
        box(b, V((x + s * (w / 2 + 0.2), y_front - 0.06, z)), (0.3, 0.06, h + 0.05), SHUTTER)
    box(b, V((x, y_front - 0.12, z - h / 2 - 0.08)), (w + 0.2, 0.14, 0.08), frame)
    if flowers:
        box(b, V((x, y_front - 0.16, z - h / 2 - 0.16)), (w + 0.1, 0.2, 0.16), (0.55, 0.38, 0.24))
        for i in range(5):
            clump(b, V((x - w / 2 + i * w / 4, y_front - 0.17, z - h / 2 - 0.04)), 0.06, 1, rnd,
                  rnd.choice([(0.92, 0.4, 0.5), (0.98, 0.8, 0.3), (0.45, 0.66, 0.3)]), "Build", 1.0)


def door(b, x, y_front, z0, w=0.95, h=1.95, frame=TIMBER):
    box(b, V((x, y_front - 0.02, z0 + h / 2)), (w + 0.2, 0.1, h + 0.1), frame)
    for i in range(3):
        box(b, V((x - w / 3 + i * w / 3, y_front - 0.05, z0 + h / 2 - 0.02)), (w / 3 - 0.02, 0.06, h - 0.06), rnd.choice(WOOD[:2]))
    box(b, V((x + w * 0.3, y_front - 0.1, z0 + h * 0.5)), (0.06, 0.05, 0.06), (0.8, 0.7, 0.4), 0.0)
    box(b, V((x, y_front - 0.35, z0 - 0.1)), (w + 0.5, 0.5, 0.2), STONE[0])


def barrel(b, at):
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [at, at + V((0, 0, 0.35)), at + V((0, 0, 0.7))], [(0.26, 0.26), (0.3, 0.3), (0.26, 0.26)], seg=8)), WOOD[1])
    for z in (0.12, 0.58):
        paint(b, b.new_faces(lambda z=z: rk.tube(b.bm, [at + V((0, 0, z)), at + V((0, 0, z + 0.05))], [(0.29, 0.29)] * 2, seg=8)), (0.3, 0.3, 0.32))


def cottage():
    b = Builder(["Build"])
    W, D, H, F = 4.4, 3.4, 2.6, 0.5          # width, depth, wall height, foundation top
    for i in range(-5, 6):                    # stone-block foundation
        for y in (-D / 2 - 0.05, D / 2 + 0.05):
            box(b, V((i * W / 10, y, F / 2 - 0.1)), (W / 10 - 0.03, 0.3, F + 0.2), rnd.choice(STONE), 0.05)
    for i in range(-3, 4):
        for x in (-W / 2 - 0.05, W / 2 + 0.05):
            box(b, V((x, i * D / 7, F / 2 - 0.1)), (0.3, D / 7 - 0.03, F + 0.2), rnd.choice(STONE), 0.05)
    box(b, V((0, 0, F + H / 2)), (W, D, H), PLASTER)
    for x in (-W / 2, -W / 6, W / 6, W / 2):  # timber framing: posts, beams, braces
        for y in (-D / 2 - 0.02, D / 2 + 0.02):
            beam(b, V((x, y, F)), V((x, y, F + H)), 0.09, TIMBER)
    for y in (-D / 2 - 0.03, D / 2 + 0.03):
        for z in (F + 0.05, F + H * 0.55, F + H):
            beam(b, V((-W / 2, y, z)), V((W / 2, y, z)), 0.08, TIMBER)
    for y in (-D / 2, D / 2):
        for x in (-W / 2 - 0.02, W / 2 + 0.02):
            beam(b, V((x, y, F)), V((x, y, F + H)), 0.1, TIMBER)
            beam(b, V((x, y * 0.3, F + H * 0.55)), V((x, y, F + H)), 0.06, TIMBER)
    door(b, 0.0, -D / 2, F)
    window(b, -1.45, F + 1.35, -D / 2, flowers=True)
    window(b, 1.45, F + 1.35, -D / 2, flowers=True)
    tiered_roof(b, V((0, 0, F + H)), W, D, 2.0, 0.5, 5, RED_ROOF, TIMBER, PLASTER)
    for i in range(6):                        # stone chimney with a cap
        box(b, V((1.2, 0.7, F + H + 0.9 + i * 0.3)), (0.62, 0.62, 0.3), rnd.choice(STONE), 0.06)
    box(b, V((1.2, 0.7, F + H + 2.75)), (0.78, 0.78, 0.12), STONE[3])
    lx = -W / 2 - 0.9                         # lean-to with barrels and a crate
    for y in (-0.9, 0.9):
        beam(b, V((lx - 0.6, y, 0)), V((lx - 0.6, y, 1.9)), 0.08, TIMBER)
    slab(b, [V((lx - 0.9, -1.2, 1.95)), V((lx + 0.9, -1.2, 2.5)), V((lx + 0.9, 1.2, 2.5)), V((lx - 0.9, 1.2, 1.95))], 0.08, RED_ROOF[1])
    barrel(b, V((lx - 0.1, -0.5, 0)))
    barrel(b, V((lx + 0.1, 0.25, 0)))
    box(b, V((lx - 0.1, -1.35, 0.25)), (0.5, 0.5, 0.5), WOOD[2])
    return b


def log(b, p0, p1, r=0.15):
    faces = b.new_faces(lambda: rk.tube(b.bm, [p0, p1], [(r, r)] * 2, ref=V((0, 0, 1)), seg=6))
    axis = (p1 - p0).normalized()
    for f in faces:
        f.normal_update()
        cut = abs(f.normal.dot(axis)) > 0.9
        paint(b, [f], (0.86, 0.72, 0.5) if cut else rnd.choice(WOOD), 0.04)


def cabin():
    b = Builder(["Build", "Glow"])
    W, D, H, F = 4.2, 3.4, 2.4, 0.4
    box(b, V((0, 0, F / 2 - 0.05)), (W + 0.4, D + 0.4, F + 0.1), STONE[1], 0.05)
    z = F + 0.15
    while z < F + H:                          # round logs, ends crossing at the corners
        for y in (-D / 2, D / 2):
            log(b, V((-W / 2 - 0.3, y, z)), V((W / 2 + 0.3, y, z)))
        for x in (-W / 2, W / 2):
            log(b, V((x, -D / 2 - 0.3, z + 0.14)), V((x, D / 2 + 0.3, z + 0.14)))
        z += 0.28
    box(b, V((0, 0, F + H / 2)), (W - 0.1, D - 0.1, H), WOOD[0], 0.0)
    door(b, 0.7, -D / 2 - 0.1, F, frame=(0.3, 0.2, 0.13))
    window(b, -1.1, F + 1.3, -D / 2 - 0.12, frame=(0.3, 0.2, 0.13))
    tiered_roof(b, V((0, 0, F + H + 0.1)), W, D, 1.8, 0.7, 5, SLATE, (0.3, 0.2, 0.13), WOOD[0])
    for i in range(14):                       # stone chimney up the right side
        s = 0.2 if i > 7 else 0.0
        box(b, V((W / 2 + 0.35, 0.4, 0.25 + i * 0.32)), (0.7 - s, 0.8 - s, 0.32), rnd.choice(STONE), 0.06)
    for i in range(8):                        # plank porch
        y0 = -D / 2 - 0.15 - i * 0.2
        slab(b, [V((-W / 2, y0, F + 0.05)), V((W / 2, y0, F + 0.05)), V((W / 2, y0 - 0.18, F + 0.05)), V((-W / 2, y0 - 0.18, F + 0.05))], 0.08, rnd.choice(WOOD))
    front = -D / 2 - 1.7
    for x in (-W / 2 + 0.1, -0.3, 1.2, W / 2 - 0.1):
        beam(b, V((x, front, 0)), V((x, front, F + 2.2)), 0.08, (0.4, 0.27, 0.17))
    for x0, x1 in ((-W / 2 + 0.1, -0.3), (1.2, W / 2 - 0.1)):
        beam(b, V((x0, front, F + 0.75)), V((x1, front, F + 0.75)), 0.05, (0.4, 0.27, 0.17))
    for i in range(3):                        # steps
        box(b, V((0.45, front - 0.25 - i * 0.3, F - 0.1 - i * 0.14)), (1.3, 0.3, 0.12), rnd.choice(WOOD))
    slab(b, [V((-W / 2 - 0.2, front - 0.3, F + 2.25)), V((W / 2 + 0.2, front - 0.3, F + 2.25)),
             V((W / 2 + 0.2, -D / 2, F + 2.7)), V((-W / 2 - 0.2, -D / 2, F + 2.7))], 0.1, SLATE[1])
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((1.55, -D / 2 - 0.2, F + 1.95)), (0.11, 0.11, 0.15), 6, 4)), "Glow", (1.0, 0.72, 0.35))
    for row in range(3):                      # woodpile
        for i in range(5 - row):
            p = V((-W / 2 - 1.0, -1.0 + i * 0.3 + row * 0.15, 0.15 + row * 0.26))
            log(b, p, p + V((0.7, 0, 0)), 0.13)
    return b


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Build": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)
os.makedirs(OUT, exist_ok=True)
export("house_cottage", cottage(), OUT)
export("house_cabin", cabin(), OUT)

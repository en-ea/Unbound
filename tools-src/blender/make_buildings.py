"""Builds detailed faceted low-poly houses in five styles, for the owner to compare:
  house_cottage: stone-block foundation, plaster walls with timber framing and braces, tiered red
                 shingle roof with ridge beam, planked door and step, shuttered windows with flower
                 boxes, stone chimney, lean-to with barrels and a crate.
  house_cabin:   round logs with light cut ends, tiered slate roof, stone side chimney, railed plank
                 porch with steps, shutters, lantern, woodpile.
  house_round:   storybook round house: stone ring, plaster walls, tall layered straw roof,
                 crooked chimney, round windows (one lit), arched door, lantern, bench.
  house_crooked: tall, narrow and leaning, steep red roof, moss ridge, octagon windows, pointed door.
  house_tree:    two turned storeys with straw roofs, wrapped by a huge twisting tree.
Front faces -Y in Blender (+Z in Godot, towards the camera). Exported to game/assets/buildings/.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_buildings.py
"""
import math
import os
import random
import sys
import bpy
import bmesh
from mathutils import Euler, Vector as V

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
            lift = 0.05 + i * 0.035               # each row sits just above the one below (no flicker)
            quad = [base + V((-w, y0, z0 + lift)), base + V((w, y0, z0 + lift)), base + V((w, y1, z1 + lift)), base + V((-w, y1, z1 + lift))]
            if side > 0:
                quad = list(reversed(quad))
            slab(b, quad, 0.1, rnd.choice(palette))
    beam(b, base + V((-w - 0.05, 0, height + 0.05 + rows * 0.035)), base + V((w + 0.05, 0, height + 0.05 + rows * 0.035)), 0.1, ridge_color)
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
    # A covered porch over the door, a roof dormer, a picket fence and a garden bed.
    for x in (-0.75, 0.75):
        beam(b, V((x, -D / 2 - 1.1, 0)), V((x, -D / 2 - 1.1, F + 2.3)), 0.08, TIMBER)
    slab(b, [V((-1.0, -D / 2 - 1.35, F + 2.3)), V((1.0, -D / 2 - 1.35, F + 2.3)), V((1.0, -D / 2, F + 2.75)), V((-1.0, -D / 2, F + 2.75))], 0.1, RED_ROOF[2])
    box(b, V((-1.2, -0.55, F + H + 0.75)), (0.9, 0.8, 0.8), PLASTER)
    window(b, -1.2, F + H + 0.75, -0.95, 0.45, 0.45)
    slab(b, [V((-1.75, -1.15, F + H + 1.1)), V((-0.65, -1.15, F + H + 1.1)), V((-0.65, -0.1, F + H + 1.45)), V((-1.75, -0.1, F + H + 1.45))], 0.08, RED_ROOF[0])
    for i in range(-9, 10):
        if abs(i) < 2:
            continue
        x = i * 0.34
        box(b, V((x, -D / 2 - 2.6, 0.35)), (0.08, 0.06, 0.7), (0.93, 0.9, 0.84), 0.02)
    for y in (0.2, 0.5):
        for s in (-1, 1):
            box(b, V((s * 1.9, -D / 2 - 2.62, y)), (2.4, 0.05, 0.06), (0.93, 0.9, 0.84), 0.02)
    box(b, V((-1.6, -D / 2 - 1.8, 0.1)), (2.0, 0.9, 0.2), (0.4, 0.3, 0.22))
    for i in range(12):
        clump(b, V((-2.5 + i * 0.16, -D / 2 - 1.8 + (i % 3 - 1) * 0.22, 0.28)), 0.1, 1, rnd,
              rnd.choice([(0.92, 0.4, 0.5), (0.98, 0.8, 0.3), (0.45, 0.66, 0.3), (0.62, 0.5, 0.9)]), "Build", 1.0)
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


STRAW = [(0.86, 0.7, 0.38), (0.8, 0.63, 0.32), (0.9, 0.76, 0.44), (0.76, 0.6, 0.3)]
WARM_PLASTER = (0.96, 0.88, 0.74)
MOSS = [(0.56, 0.7, 0.34), (0.48, 0.64, 0.3), (0.62, 0.74, 0.38), (0.44, 0.58, 0.28), (0.66, 0.7, 0.4)]
FLOWERS = [(0.95, 0.85, 0.4), (0.92, 0.5, 0.6), (0.95, 0.95, 0.9), (0.62, 0.55, 0.92)]


def disc(b, center, r, thick, color, seg=10):
    """A round plate facing -Y (arches, shields)."""
    faces = b.new_faces(lambda: rk.tube(b.bm, [center, center + V((0, -thick, 0))], [(r, r)] * 2, ref=V((1, 0, 0)), seg=seg))
    paint(b, faces, color)


def round_house():
    b = Builder(["Build", "Glow"])
    R, H, F = 2.1, 2.3, 0.45
    for i in range(18):                               # a ring of footing stones
        a = i / 18 * math.tau
        box(b, V((math.cos(a) * (R + 0.08), math.sin(a) * (R + 0.08), F / 2 - 0.1)), (0.62, 0.62, F + 0.2), rnd.choice(STONE), 0.06)
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, F)), V((0, 0, F + H))], [(R, R)] * 2, seg=14)), WARM_PLASTER, 0.02)
    for i in range(7):                                # timber posts around the wall (none over the door)
        a = -math.pi / 2 + (i + 1) / 8 * math.tau
        p = V((math.cos(a) * (R + 0.03), math.sin(a) * (R + 0.03), 0))
        beam(b, p + V((0, 0, F)), p + V((0, 0, F + H)), 0.08, TIMBER)
    for z in (F + 0.05, F + H - 0.05):                # beams ringing the wall
        paint(b, b.new_faces(lambda z=z: rk.tube(b.bm, [V((0, 0, z - 0.06)), V((0, 0, z + 0.06))], [(R + 0.06, R + 0.06)] * 2, seg=14)), TIMBER)
    # Layered straw roof: overlapping cones, each tier ragged at the rim.
    top = F + H + 3.3                                  # a tall, pointed witch-hat roof
    for r0, z0, r1 in [(R + 0.42, F + H - 0.05, R * 0.6), (R * 0.66 + 0.18, F + H + 1.0, R * 0.36), (R * 0.4 + 0.12, F + H + 2.0, 0.18)]:
        z1 = min(top, z0 + 1.45)
        faces = b.new_faces(lambda r0=r0, z0=z0, r1=r1, z1=z1: rk.tube(
            b.bm, [V((0, 0, z0)), V((0, 0, z0 + 0.22)), V((0, 0, z1))], [(r0, r0), (r0 * 0.96, r0 * 0.96), (r1, r1)], seg=16))
        for f in faces:
            for v in f.verts:
                if v.co.z < z0 + 0.05:
                    v.co.z -= rnd.uniform(0.0, 0.12)
        for f in faces:
            b.paint([f], "Build", rnd.choice(STRAW))
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, top - 0.5)), V((0, 0, top + 0.15))], [(0.3, 0.3), (0.04, 0.04)], seg=8)), STRAW[3])
    beam(b, V((0, 0, top - 0.1)), V((0, 0, top + 0.55)), 0.04, TIMBER)          # finial with a little ball
    clump(b, V((0, 0, top + 0.6)), 0.09, 1, rnd, (0.85, 0.72, 0.4), "Build", 1.0)
    # Arched door with a stone step.
    fy = -R - 0.02
    box(b, V((0, fy, F + 0.8)), (1.0, 0.12, 1.6), TIMBER)
    disc(b, V((0, fy + 0.02, F + 1.6)), 0.5, 0.12, TIMBER, 12)
    for i in range(3):
        box(b, V((-0.28 + i * 0.28, fy - 0.05, F + 0.78)), (0.26, 0.06, 1.5), rnd.choice(WOOD[:2]))
    disc(b, V((0, fy - 0.06, F + 1.6)), 0.4, 0.06, WOOD[1], 12)
    box(b, V((0.28, fy - 0.12, F + 0.9)), (0.07, 0.05, 0.07), (0.85, 0.72, 0.4), 0.0)
    box(b, V((0, fy - 0.45, F - 0.12)), (1.4, 0.6, 0.2), STONE[0])
    # Round windows with flower boxes; the right one glows warm.
    for a, lit in ((-2.25, False), (-0.9, True)):
        out = V((math.cos(a), math.sin(a), 0))
        p = out * (R + 0.02) + V((0, 0, F + 1.35))
        paint(b, b.new_faces(lambda p=p, out=out: rk.tube(b.bm, [p - out * 0.02, p + out * 0.1], [(0.42, 0.42)] * 2, ref=V((0, 0, 1)), seg=10)), TIMBER)
        glass = b.new_faces(lambda p=p, out=out: rk.tube(b.bm, [p + out * 0.08, p + out * 0.12], [(0.32, 0.32)] * 2, ref=V((0, 0, 1)), seg=10))
        if lit:
            b.paint(glass, "Glow", (1.0, 0.78, 0.42))
        else:
            paint(b, glass, GLASS, 0.0)
        beam(b, p + out * 0.13 + V((0, 0, -0.32)), p + out * 0.13 + V((0, 0, 0.32)), 0.03, TIMBER)
        box(b, p + out * 0.22 + V((0, 0, -0.46)), (0.55, 0.3, 0.12), (0.55, 0.38, 0.24))
        side = V((-out.y, out.x, 0))
        for k in range(4):
            clump(b, p + out * 0.24 + side * ((k - 1.5) * 0.12) + V((0, 0, -0.36)), 0.07, 1, rnd, rnd.choice(FLOWERS), "Build", 1.0)
    # Crooked stone chimney poking out of the straw.
    for i in range(9):
        box(b, V((1.05 + i * 0.035, 0.8 - i * 0.01, F + H + 0.5 + i * 0.3)), (0.55, 0.55, 0.3), rnd.choice(STONE), 0.06)
    box(b, V((1.35, 0.72, F + H + 3.2)), (0.7, 0.7, 0.1), STONE[3])
    # Lantern on a bracket by the door, a bench, and two planted pots.
    beam(b, V((0.75, fy - 0.02, F + 2.0)), V((0.75, fy - 0.4, F + 2.0)), 0.03, (0.2, 0.18, 0.18))
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0.75, fy - 0.4, F + 1.8)), (0.1, 0.1, 0.14), 6, 4)), "Glow", (1.0, 0.72, 0.35))
    box(b, V((-1.35, fy - 0.35, 0.45)), (1.2, 0.36, 0.08), WOOD[2])
    for x in (-1.8, -0.9):
        box(b, V((x, fy - 0.35, 0.22)), (0.1, 0.3, 0.44), WOOD[1])
    for x, y in ((1.3, fy - 0.3), (1.65, fy - 0.1)):
        paint(b, b.new_faces(lambda x=x, y=y: rk.tube(b.bm, [V((x, y, 0)), V((x, y, 0.35))], [(0.16, 0.16), (0.2, 0.2)], seg=8)), (0.72, 0.42, 0.28))
        clump(b, V((x, y, 0.45)), 0.18, 1, rnd, rnd.choice(MOSS), "Build", 0.9)
    return b


# --- Simple, characterful style: few big faces, flat colours, bold silhouettes -------------
WHITE = (0.95, 0.92, 0.86)
TRIM = (0.36, 0.22, 0.2)
ROOF_RED = (0.78, 0.3, 0.3)
MOSS_SOFT = [(0.56, 0.74, 0.36), (0.5, 0.68, 0.32)]
BARK = [(0.56, 0.44, 0.42), (0.5, 0.39, 0.38), (0.6, 0.48, 0.45)]
LEAF = [(0.5, 0.72, 0.34), (0.44, 0.66, 0.3), (0.58, 0.78, 0.38)]


def glow_box(b, center, size, color=(1.0, 0.8, 0.42)):
    def make():
        geom = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in geom["verts"]:
            v.co = V((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + center
    b.paint(b.new_faces(make), "Glow", color)


def prism(b, outline, y0, y1, color, var=0.015):
    """Extrudes a front outline [(x, z), ...] (counter-clockwise seen from the front) from y0 to y1."""
    def make():
        bm = b.bm
        front = [bm.verts.new(V((x, y0, z))) for x, z in outline]
        back = [bm.verts.new(V((x, y1, z))) for x, z in outline]
        bm.faces.new(front)
        bm.faces.new(list(reversed(back)))
        n = len(outline)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((front[j], front[i], back[i], back[j]))
    paint(b, b.new_faces(make), color, var)


def thick_quad(b, a, bb, c, d, thick, color):
    """A slab whose top face is a, bb, c, d (roof planes), pushed down along its normal."""
    n = (bb - a).cross(d - a).normalized()
    if n.z < 0:
        n = -n
    def make():
        bm = b.bm
        top = [bm.verts.new(p) for p in (a, bb, c, d)]
        bot = [bm.verts.new(p - n * thick) for p in (a, bb, c, d)]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((top[j], top[i], bot[i], bot[j]))
    paint(b, b.new_faces(make), color, 0.02)


def gable_roof(b, half_w, y0, y1, eave_z, peak_z, over, thick, color):
    """Two thick roof planes meeting at a ridge along Y, overhanging by `over`."""
    slope = (peak_z - eave_z) / half_w
    ex = half_w + over
    ez = eave_z - over * slope
    for s in (-1, 1):
        a, bb = V((s * ex, y0 - over, ez)), V((0, y0 - over, peak_z + thick * 0.6))
        c, d = V((0, y1 + over, peak_z + thick * 0.6)), V((s * ex, y1 + over, ez))
        thick_quad(b, a, bb, c, d, thick, color)


def octagon_window(b, x, z, y, r, lit=False):
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((x, y + 0.02, z)), V((x, y - 0.08, z))], [(r, r)] * 2, ref=V((1, 0, 0)), seg=8)), TRIM, 0.0)
    glass = b.new_faces(lambda: rk.tube(b.bm, [V((x, y - 0.08, z)), V((x, y - 0.11, z))], [(r * 0.72, r * 0.72)] * 2, ref=V((1, 0, 0)), seg=8))
    if lit:
        b.paint(glass, "Glow", (1.0, 0.8, 0.42))
    else:
        paint(b, glass, (0.3, 0.42, 0.7), 0.0)
    box(b, V((x, y - 0.12, z)), (0.04, 0.03, r * 1.4), TRIM, 0.0)
    box(b, V((x, y - 0.12, z)), (r * 1.4, 0.03, 0.04), TRIM, 0.0)


def arch_door(b, x, z0, y, w, h, frame_extra=0.14):
    """A pointed-arch door in a dark frame, on a wall whose front is at y."""
    def outline(w, h):
        return [(x - w / 2, z0), (x + w / 2, z0), (x + w / 2, z0 + h * 0.66), (x + w * 0.25, z0 + h * 0.9), (x, z0 + h),
                (x - w * 0.25, z0 + h * 0.9), (x - w / 2, z0 + h * 0.66)]
    prism(b, outline(w + frame_extra * 2, h + frame_extra), y - 0.07, y + 0.02, TRIM, 0.0)
    prism(b, outline(w, h), y - 0.1, y - 0.07, WOOD[1], 0.0)
    for k in (-1, 1):
        box(b, V((x + k * w * 0.2, y - 0.11, z0 + h * 0.45)), (0.03, 0.02, h * 0.8), TRIM, 0.0)
    box(b, V((x + w * 0.3, y - 0.13, z0 + h * 0.42)), (0.06, 0.04, 0.06), (0.9, 0.75, 0.4), 0.0)


def crooked_house():
    """Tall and narrow with a steep red roof, leaning a little: white walls, chunky dark trim,
    octagon windows, a pointed door and a soft moss ridge."""
    b = Builder(["Build", "Glow"])
    W, D, H, F, P = 3.0, 3.0, 3.2, 0.3, 2.9             # width, depth, wall height, footing, roof rise
    box(b, V((0, 0, F / 2 - 0.05)), (W + 0.3, D + 0.3, F + 0.1), (0.62, 0.6, 0.58), 0.0)
    prism(b, [(-W / 2, F), (W / 2, F), (W / 2, F + H), (0, F + H + P), (-W / 2, F + H)], -D / 2, D / 2, WHITE)
    for x in (-W / 2, W / 2):                            # chunky corner posts
        for y in (-D / 2, D / 2):
            box(b, V((x, y, F + H / 2)), (0.24, 0.24, H), TRIM, 0.0)
    box(b, V((0, -D / 2 - 0.02, F + H - 0.05)), (W + 0.2, 0.14, 0.2), TRIM, 0.0)   # beam under the gable
    gable_roof(b, W / 2, -D / 2, D / 2, F + H, F + H + P, 0.45, 0.24, ROOF_RED)
    ridge = F + H + P + 0.2
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, -D / 2 - 0.55, ridge)), V((0, D / 2 + 0.55, ridge))], [(0.26, 0.2)] * 2,
                                         ref=V((1, 0, 0)), seg=6)), MOSS_SOFT[0], 0.03)
    for y in (-D / 2 - 0.45, -0.4, 0.9):
        clump(b, V((0.05, y, ridge + 0.12)), 0.26, 1, rnd, rnd.choice(MOSS_SOFT), "Build", 0.7)
    arch_door(b, -0.3, F, -D / 2, 0.95, 1.95)
    octagon_window(b, 0.0, F + H + 0.9, -D / 2, 0.36, lit=True)
    octagon_window(b, 0.85, F + 1.5, -D / 2, 0.28)
    for p in (V((-1.1, -D / 2 - 0.03, F + 2.4)), V((1.05, -D / 2 - 0.03, F + 0.5)), V((-0.95, -D / 2 - 0.03, F + 0.35)), V((0.7, -D / 2 - 0.03, F + 3.3))):
        box(b, p, (0.26, 0.06, 0.12), (0.82, 0.76, 0.66), 0.0)        # little exposed bricks
    box(b, V((0, -D / 2 - 0.45, F - 0.12)), (1.3, 0.6, 0.18), (0.62, 0.6, 0.58), 0.0)
    for i in range(6):                                   # crooked chimney
        box(b, V((0.9 + i * 0.05, 0.7, F + H + 1.1 + i * 0.36)), (0.5, 0.5, 0.36), (0.6, 0.52, 0.5), 0.0)
    for v in b.bm.verts:                                 # the whole house leans a touch
        v.co.x += (v.co.z - F) * 0.045
    return b


def tree_house():
    """Two stacked storeys with straw roofs, turned against each other, wrapped by a huge twisting
    tree with bare branches and a few leafy tufts."""
    b = Builder(["Build", "Glow"])
    straw = (0.9, 0.72, 0.36)
    # Lower storey.
    W, D, H, F = 3.4, 3.0, 2.5, 0.25
    box(b, V((0, 0, F / 2 - 0.05)), (W + 0.3, D + 0.3, F + 0.1), (0.6, 0.58, 0.56), 0.0)
    box(b, V((0, 0, F + H / 2)), (W, D, H), WHITE, 0.015)
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            box(b, V((x, y, F + H / 2)), (0.2, 0.2, H), TRIM, 0.0)
    box(b, V((0, -D / 2 - 0.02, F + H)), (W + 0.2, 0.12, 0.18), TRIM, 0.0)
    gable_roof(b, W / 2, -D / 2, D / 2, F + H, F + H + 1.3, 0.35, 0.22, straw)
    arch_door(b, 0.6, F, -D / 2, 0.9, 1.8)
    box(b, V((-0.8, -D / 2 - 0.05, F + 1.45)), (0.72, 0.1, 0.82), TRIM, 0.0)
    glow_box(b, V((-0.8, -D / 2 - 0.1, F + 1.45)), (0.5, 0.04, 0.6))
    # Upper storey, smaller and turned.
    top = Builder(["Build", "Glow"])
    w, d, h, z0 = 2.3, 2.1, 1.9, F + H + 0.45
    box(top, V((0, 0, z0 + h / 2)), (w, d, h), WHITE, 0.015)
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            box(top, V((x, y, z0 + h / 2)), (0.18, 0.18, h), TRIM, 0.0)
    gable_roof(top, w / 2, -d / 2, d / 2, z0 + h, z0 + h + 1.5, 0.3, 0.2, straw)
    octagon_window(top, 0.0, z0 + 1.0, -d / 2, 0.3, lit=True)
    bm_top = top.bm
    for v in bm_top.verts:
        v.co.rotate(Euler((0, 0, 0.3)))
        v.co += V((-0.2, 0.15, 0))
    tmp = bpy.data.meshes.new("tmp")
    bm_top.to_mesh(tmp)
    bm_top.free()
    b.bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    # The tree: a thick trunk rising beside the house and spiralling around it.
    pts, radii = [], []
    for i in range(13):
        t = i / 12
        a = -2.3 + t * 4.6
        r = 2.25 - 0.8 * t
        pts.append(V((math.cos(a) * r, math.sin(a) * r + 0.2, 0.1 + t * 7.4)))
        k = 0.62 * (1 - t) + 0.16
        radii.append((k, k * 0.85))
    paint(b, b.new_faces(lambda: rk.tube(b.bm, pts, radii, seg=6)), BARK[0], 0.05)
    base = pts[0]
    for ang in (1.8, 3.0, 4.4):                          # roots gripping the ground
        d = V((math.cos(ang), math.sin(ang), 0))
        paint(b, b.new_faces(lambda d=d: rk.tube(b.bm, [base + V((0, 0, 0.3)), base + d * 1.0 + V((0, 0, 0.05)), base + d * 1.7 + V((0, 0, -0.1))],
                                                  [(0.3, 0.3), (0.18, 0.16), (0.05, 0.05)], seg=5)), rnd.choice(BARK), 0.04)
    tip = pts[-1]
    for i, (dx, dy, dz) in enumerate(((0.9, 0.2, 1.4), (-1.1, -0.3, 1.1), (0.2, -1.0, 1.6), (-0.3, 0.9, 1.3))):
        mid = tip + V((dx * 0.5, dy * 0.5, dz * 0.6))
        end = tip + V((dx, dy, dz))
        paint(b, b.new_faces(lambda mid=mid, end=end: rk.tube(b.bm, [tip, mid, end], [(0.16, 0.16), (0.09, 0.09), (0.02, 0.02)], seg=5)), rnd.choice(BARK), 0.04)
        if i % 2 == 0:
            clump(b, end + V((0, 0, 0.1)), 0.55, 1, rnd, rnd.choice(LEAF), "Build", 0.8)
    for t in (0.35, 0.62):                               # side branches off the spiral
        p = pts[int(t * 12)]
        out = V((p.x, p.y, 0)).normalized()
        end = p + out * 1.3 + V((0, 0, 0.9))
        paint(b, b.new_faces(lambda p=p, end=end: rk.tube(b.bm, [p, end], [(0.14, 0.14), (0.02, 0.02)], seg=5)), rnd.choice(BARK), 0.04)
        clump(b, end, 0.45, 1, rnd, rnd.choice(LEAF), "Build", 0.8)
    return b


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Build": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)
os.makedirs(OUT, exist_ok=True)
export("house_cottage", cottage(), OUT)
export("house_cabin", cabin(), OUT)
export("house_round", round_house(), OUT)
export("house_crooked", crooked_house(), OUT)
export("house_tree", tree_house(), OUT)

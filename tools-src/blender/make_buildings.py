"""Builds detailed faceted low-poly houses in five styles (round, loaf and windmill are the direction the owner liked), for the owner to compare:
  house_cottage: stone-block foundation, plaster walls with timber framing and braces, tiered red
                 shingle roof with ridge beam, planked door and step, shuttered windows with flower
                 boxes, stone chimney, lean-to with barrels and a crate.
  house_cabin:   round logs with light cut ends, tiered slate roof, stone side chimney, railed plank
                 porch with steps, shutters, lantern, woodpile.
  house_round:   storybook round house: stone ring, plaster walls, tall layered straw roof,
                 crooked chimney, round windows (one lit), arched door, lantern, bench.
  house_loaf:    oval plaster walls under a big puffy rounded straw roof, round door and windows.
  windmill:      tapered round tower, smooth bent cap, balcony ring; windmill_sails turn in game.
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


# --- Rounded, smooth low-poly style (the direction the round house set) ----------------------
STRAW_SOFT = [(0.9, 0.74, 0.4), (0.86, 0.69, 0.36), (0.93, 0.78, 0.45)]
CREAM = (0.97, 0.9, 0.78)
SHINGLE = [(0.74, 0.36, 0.3), (0.7, 0.33, 0.28), (0.78, 0.4, 0.32)]
CLOTH = (0.96, 0.93, 0.86)
TRIM = (0.38, 0.25, 0.2)


def round_window(b, p, out, r, lit):
    """A round window in a curved wall: frame, glass (lit or not), cross bars, flower box."""
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [p - out * 0.03, p + out * 0.1], [(r, r)] * 2, ref=V((0, 0, 1)), seg=12)), TRIM, 0.0)
    glass = b.new_faces(lambda: rk.tube(b.bm, [p + out * 0.1, p + out * 0.13], [(r * 0.75, r * 0.75)] * 2, ref=V((0, 0, 1)), seg=12))
    if lit:
        b.paint(glass, "Glow", (1.0, 0.8, 0.42))
    else:
        paint(b, glass, (0.32, 0.45, 0.68), 0.0)
    side = V((-out.y, out.x, 0))
    beam(b, p + out * 0.14 - V((0, 0, r * 0.75)), p + out * 0.14 + V((0, 0, r * 0.75)), 0.025, TRIM)
    beam(b, p + out * 0.14 - side * r * 0.75, p + out * 0.14 + side * r * 0.75, 0.025, TRIM)
    box(b, p + out * 0.22 - V((0, 0, r + 0.08)), (0.2 + r * 1.3, 0.26, 0.12), (0.6, 0.4, 0.25), 0.0)
    for k in range(4):
        clump(b, p + out * 0.25 + side * ((k - 1.5) * r * 0.42) - V((0, 0, r - 0.02)), 0.07, 1, rnd, rnd.choice(FLOWERS), "Build", 1.0)


def round_door(b, x, y, z0, w=0.95, h=1.7):
    """An arched door: dark frame, planks, a round top."""
    box(b, V((x, y, z0 + h / 2)), (w + 0.2, 0.14, h), TRIM, 0.0)
    disc(b, V((x, y + 0.02, z0 + h)), w / 2 + 0.1, 0.16, TRIM, 14)
    box(b, V((x, y - 0.07, z0 + h / 2)), (w, 0.04, h - 0.04), WOOD[1], 0.0)
    disc(b, V((x, y - 0.05, z0 + h)), w / 2, 0.06, WOOD[1], 14)
    for k in (-1, 1):
        box(b, V((x + k * w * 0.22, y - 0.12, z0 + h * 0.55)), (0.035, 0.03, h), TRIM, 0.0)
    box(b, V((x + w * 0.3, y - 0.14, z0 + h * 0.45)), (0.07, 0.05, 0.07), (0.9, 0.75, 0.4), 0.0)
    box(b, V((x, y - 0.4, z0 - 0.12)), (w + 0.5, 0.6, 0.2), STONE[0], 0.0)


def loaf_house():
    """Oval plaster walls under a big, puffy, rounded straw roof, like a loaf of bread."""
    b = Builder(["Build", "Glow"])
    RX, RY, H, F = 2.5, 1.7, 2.0, 0.4
    for i in range(20):                                  # footing stones around the oval
        a = i / 20 * math.tau
        box(b, V((math.cos(a) * (RX + 0.05), math.sin(a) * (RY + 0.05), F / 2 - 0.1)), (0.6, 0.55, F + 0.2), rnd.choice(STONE), 0.05)
    walls = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, F)), V((0, 0, F + H * 0.5)), V((0, 0, F + H + 0.1))],
                                         [(RX, RY), (RX + 0.06, RY + 0.06), (RX - 0.05, RY - 0.05)], seg=16))
    paint(b, walls, CREAM, 0.015)
    eave = F + H - 0.05
    c = V((0, 0, eave))
    roof = b.new_faces(lambda: rk.blob(b.bm, c, (RX + 0.75, RY + 0.7, 2.3), 16, 10, keep=lambda p: p.z >= eave - 0.01))
    for f in roof:
        for v in f.verts:
            if v.co.z < eave + 0.05:
                v.co.z -= rnd.uniform(0.0, 0.1)          # a soft, uneven straw edge
        b.paint([f], "Build", rnd.choice(STRAW_SOFT))
    for i in range(7):                                   # round stone chimney through the straw
        paint(b, b.new_faces(lambda i=i: rk.tube(b.bm, [V((1.4, 0.5, eave + 1.0 + i * 0.3)), V((1.4, 0.5, eave + 1.3 + i * 0.3))],
                                                  [(0.3, 0.3)] * 2, seg=8)), rnd.choice(STONE), 0.03)
    fy = -RY - 0.02
    round_door(b, 0.0, fy, F)
    for a, lit in ((-2.35, True), (-0.8, False)):
        out = V((math.cos(a), math.sin(a), 0))
        p = V((math.cos(a) * (RX + 0.02), math.sin(a) * (RY + 0.02), F + 1.2))
        round_window(b, p, out, 0.32, lit)
    beam(b, V((-0.8, fy - 0.02, F + 1.9)), V((-0.8, fy - 0.35, F + 1.9)), 0.03, (0.2, 0.18, 0.18))    # lantern
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((-0.8, fy - 0.35, F + 1.72)), (0.09, 0.09, 0.13), 6, 4)), "Glow", (1.0, 0.72, 0.35))
    for x, y in ((1.25, fy - 0.35), (1.6, fy - 0.1)):   # pots with shrubs
        paint(b, b.new_faces(lambda x=x, y=y: rk.tube(b.bm, [V((x, y, 0)), V((x, y, 0.35))], [(0.16, 0.16), (0.2, 0.2)], seg=8)), (0.72, 0.42, 0.28))
        clump(b, V((x, y, 0.47)), 0.2, 1, rnd, rnd.choice(MOSS), "Build", 0.9)
    return b


def windmill():
    """A tapered round tower with a smooth, slightly bent cap, a balcony ring and a door. The sails
    are a separate model (windmill_sails) so the game can turn them."""
    b = Builder(["Build", "Glow"])
    R0, R1, H, F = 2.0, 1.35, 6.0, 0.35
    for i in range(18):
        a = i / 18 * math.tau
        box(b, V((math.cos(a) * (R0 + 0.05), math.sin(a) * (R0 + 0.05), F / 2 - 0.1)), (0.66, 0.66, F + 0.2), rnd.choice(STONE), 0.05)
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, F)), V((0, 0, F + H * 0.5)), V((0, 0, F + H))],
                                         [(R0, R0), ((R0 + R1) / 2 + 0.05, (R0 + R1) / 2 + 0.05), (R1, R1)], seg=16)), CREAM, 0.015)
    for z, r in ((F + 0.05, R0 + 0.04), (F + H - 0.05, R1 + 0.06)):
        paint(b, b.new_faces(lambda z=z, r=r: rk.tube(b.bm, [V((0, 0, z - 0.08)), V((0, 0, z + 0.08))], [(r, r)] * 2, seg=16)), TRIM, 0.0)
    # Balcony: a plank ring on brackets, with a rail.
    bz = F + 3.4
    rb = (R0 + R1) / 2 + 0.75
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, bz - 0.08)), V((0, 0, bz + 0.04))], [(rb, rb)] * 2, seg=16)), WOOD[0], 0.03)
    for i in range(12):
        a = i / 12 * math.tau
        o = V((math.cos(a), math.sin(a), 0))
        beam(b, o * (rb - 0.05) + V((0, 0, bz)), o * (rb - 0.05) + V((0, 0, bz + 0.65)), 0.04, TRIM)
        if i % 3 == 0:
            beam(b, o * 1.62 + V((0, 0, bz - 0.8)), o * (rb - 0.2) + V((0, 0, bz - 0.05)), 0.05, TRIM)
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, bz + 0.62)), V((0, 0, bz + 0.7))], [(rb - 0.05, rb - 0.05)] * 2, seg=16)), TRIM, 0.0)
    # Smooth cap, its tip bending back a little.
    cz = F + H - 0.1
    cap = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, cz)), V((0, 0, cz + 0.25)), V((0, 0.1, cz + 1.3)), V((0, 0.35, cz + 2.3)), V((0, 0.6, cz + 2.8))],
                                       [(R1 + 0.5, R1 + 0.5), (R1 + 0.42, R1 + 0.42), (R1 * 0.6, R1 * 0.6), (0.25, 0.25), (0.03, 0.03)], seg=14))
    for f in cap:
        b.paint([f], "Build", rnd.choice(SHINGLE))
    clump(b, V((0, 0.62, cz + 2.85)), 0.1, 1, rnd, (0.9, 0.75, 0.4), "Build", 1.0)
    # Hub housing on the front, where the sails attach.
    hub = V((0, -R1 - 0.1, F + H - 0.6))
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [hub + V((0, 0.5, 0)), hub], [(0.28, 0.28), (0.22, 0.22)], ref=V((1, 0, 0)), seg=10)), TRIM, 0.0)
    round_door(b, 0.0, -R0 - 0.02, F, 0.9, 1.7)
    for z, a in ((F + 2.2, -1.2), (F + 4.4, -2.1), (F + 5.2, -0.6)):
        out = V((math.cos(a), math.sin(a), 0))
        r = R0 + (R1 - R0) * (z - F) / H
        round_window(b, out * (r + 0.02) + V((0, 0, z)), out, 0.25, z > F + 5)
    for i in range(3):                                   # sacks by the door
        clump(b, V((1.1 + i * 0.35, -R0 - 0.35, 0.3)), 0.3, 1, rnd, (0.86, 0.78, 0.6), "Build", 0.8)
    return b


def windmill_sails():
    """Four lattice sails with cloth, around the hub at the origin, facing -Y."""
    b = Builder(["Build", "Glow"])
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0.05, 0)), V((0, -0.2, 0))], [(0.2, 0.2), (0.14, 0.14)], ref=V((1, 0, 0)), seg=10)), TRIM, 0.0)
    for k in range(4):
        a = k * math.pi / 2 + 0.3
        d = V((math.cos(a), 0, math.sin(a)))
        s = V((-d.z, 0, d.x))
        beam(b, V((0, -0.1, 0)), d * 3.6 + V((0, -0.1, 0)), 0.07, WOOD[1])
        for i in range(5):                               # cross slats
            p = d * (0.9 + i * 0.65) + V((0, -0.12, 0))
            beam(b, p, p + s * 0.95, 0.03, WOOD[0])
        q = [d * 0.85 + V((0, -0.16, 0)), d * 3.55 + V((0, -0.16, 0)), d * 3.55 + s * 0.9 + V((0, -0.16, 0)), d * 0.85 + s * 0.9 + V((0, -0.16, 0))]
        def cloth(q=q):
            bm = b.bm
            vs = [bm.verts.new(p) for p in q]
            bm.faces.new(vs)
            bm.faces.new(list(reversed([bm.verts.new(p + V((0, 0.02, 0))) for p in q])))
        paint(b, b.new_faces(cloth), CLOTH, 0.02)
    return b


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Build": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)
os.makedirs(OUT, exist_ok=True)
export("house_cottage", cottage(), OUT)
export("house_cabin", cabin(), OUT)
export("house_round", round_house(), OUT)
export("house_loaf", loaf_house(), OUT)
export("windmill", windmill(), OUT)
export("windmill_sails", windmill_sails(), OUT)

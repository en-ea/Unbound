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
  house_hill:    a home dug into a grassy mound: round yellow door in a stone arch, round lit
                 windows in the grass, chimney and a little tree on top, lantern post.
  house_lodge:   tall A-frame whose roof sweeps nearly to the ground with flaring eaves and a prow
                 ridge; wood front, wheel window, deck, hanging lanterns.
  house_hex / house_grotto / house_tower: the dark diorama style from the owner's references
                 (faceted slate, stepped hex/octagon bases, glowing crystals and runes, gold trims).
  house_arch:    one smooth barrel roof sweeping near the ground, wood front, round glowing window.
  house_gable:   raised on a plinth, pale walls, tall off-centre charcoal roof with a prow, window slit.
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
    hub = V((0, -2.75, F + H - 0.6))                   # out past the balcony, so the sails clear it
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [hub + V((0, 1.7, 0)), hub + V((0, 0.6, 0)), hub], [(0.3, 0.3), (0.16, 0.16), (0.2, 0.2)], ref=V((1, 0, 0)), seg=10)), TRIM, 0.0)
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


# --- Clean style: soft bevelled shapes, flat uniform colours, one accent -----------------------
H_WALL = (1.0, 0.95, 0.86)
H_ROOF = (0.82, 0.42, 0.31)
H_RIDGE = (0.66, 0.32, 0.25)
H_STONE = (0.66, 0.66, 0.7)
H_WOOD = (0.52, 0.34, 0.23)
H_ACCENT = (0.27, 0.5, 0.54)
H_GLOW = (1.0, 0.78, 0.42)


def soft(b, make, color, offset=0.06, segs=2, mat="Build"):
    """Builds a shape with `make`, rounds all its edges with a small bevel, paints it one colour."""
    def run():
        before = set(b.bm.edges)
        make()
        edges = [e for e in b.bm.edges if e not in before]
        bmesh.ops.bevel(b.bm, geom=edges, offset=offset, segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True)
    b.paint(b.new_faces(run), mat, color)


def cube_at(b, center, size, rot=None):
    def make():
        geom = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in geom["verts"]:
            p = V((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            if rot:
                p.rotate(rot)
            v.co = p + center
    return make


def outline_prism(b, outline, y0, y1):
    """Front outline [(x, z)] counter-clockwise, extruded along +Y from y0 to y1."""
    def make():
        bm = b.bm
        front = [bm.verts.new(V((x, y0, z))) for x, z in outline]
        back = [bm.verts.new(V((x, y1, z))) for x, z in outline]
        bm.faces.new(front)
        bm.faces.new(list(reversed(back)))
        for i in range(len(outline)):
            j = (i + 1) % len(outline)
            bm.faces.new((front[j], front[i], back[i], back[j]))
    return make


def arch_outline(x, z0, w, h, steps=6):
    """A doorway: straight sides and a round top."""
    r = w / 2
    pts = [(x - r, z0), (x + r, z0)]
    for k in range(steps + 1):
        a = k / steps * math.pi
        pts.append((x + r * math.cos(a), z0 + h - r + r * math.sin(a)))
    return pts



def ellipsoid_point(size, a, z_frac):
    """A point on the upper half of an ellipsoid (size = rx, ry, rz) at angle a around, at height
    z_frac of rz; also returns the outward normal there."""
    rx, ry, rz = size
    z = z_frac * rz
    k = math.sqrt(max(0.0, 1 - z_frac * z_frac))
    p = V((math.cos(a) * rx * k, math.sin(a) * ry * k, z))
    n = V((p.x / (rx * rx), p.y / (ry * ry), p.z / (rz * rz))).normalized()
    return p, n


def hill_house():
    """A home dug into a grassy mound: a big round door in a stone arch, round windows peeking out
    of the grass, a chimney and a little tree on top, stepping stones and a lantern post."""
    b = Builder(["Build", "Glow"])
    GRASS = (0.5, 0.7, 0.34)
    STONE_L = (0.72, 0.7, 0.68)
    DOOR = (0.93, 0.7, 0.3)
    size = (3.9, 3.4, 2.5)
    fy = -size[1] * 0.83 + 0.2
    def mound():
        rk.blob(b.bm, V((0, 0.2, -0.05)), size, 16, 9, keep=lambda p: p.z >= -0.3)
        for v in b.bm.verts:                               # cut the front back where the door goes
            if v.co.y < fy - 0.15 and abs(v.co.x) < 1.9 and v.co.z < 2.2:
                v.co.y = fy - 0.15
    b.paint(b.new_faces(mound), "Build", GRASS)
    # Stone arch facade where the mound is cut open, and the round door.
    soft(b, outline_prism(b, arch_outline(0, -0.1, 3.0, 2.55, 8), fy - 0.25, fy + 1.2), STONE_L, 0.08)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, fy - 0.2, 1.15)), V((0, fy - 0.36, 1.15))], [(0.95, 0.95)] * 2, ref=V((1, 0, 0)), seg=16)), "Build", H_WOOD)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, fy - 0.36, 1.15)), V((0, fy - 0.42, 1.15))], [(0.8, 0.8)] * 2, ref=V((1, 0, 0)), seg=16)), "Build", DOOR)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0, fy - 0.48, 1.15)), (0.09, 0.07, 0.09), 8, 5)), "Build", (0.95, 0.8, 0.4))
    soft(b, cube_at(b, V((0, fy - 0.7, -0.02)), (1.8, 0.8, 0.14)), STONE_L, 0.06)
    # Round windows set into the grass on either side, lit warm.
    for a in (-2.2, -0.94):
        p, n = ellipsoid_point(size, a, 0.42)
        p += V((0, 0.2, -0.05))
        b.paint(b.new_faces(lambda p=p, n=n: rk.tube(b.bm, [p - n * 0.25, p + n * 0.08], [(0.46, 0.46)] * 2, ref=V((0, 0, 1)), seg=12)), "Build", STONE_L)
        b.paint(b.new_faces(lambda p=p, n=n: rk.tube(b.bm, [p + n * 0.08, p + n * 0.1], [(0.33, 0.33)] * 2, ref=V((0, 0, 1)), seg=12)), "Glow", H_GLOW)
        side = n.cross(V((0, 0, 1))).normalized()
        soft(b, cube_at(b, p + n * 0.12, (0.05, 0.05, 0.05)), H_WOOD, 0.01, 1)
        b.paint(b.new_faces(lambda p=p, n=n: rk.tube(b.bm, [p + n * 0.11 - V((0, 0, 0.33)), p + n * 0.11 + V((0, 0, 0.33))], [(0.03, 0.03)] * 2, seg=4)), "Build", H_WOOD)
        b.paint(b.new_faces(lambda p=p, n=n, side=side: rk.tube(b.bm, [p + n * 0.11 - side * 0.33, p + n * 0.11 + side * 0.33], [(0.03, 0.03)] * 2, seg=4)), "Build", H_WOOD)
    # Chimney and a small round tree on top, a few flowers in the grass.
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((1.2, 1.1, 1.4)), V((1.2, 1.1, 3.0))], [(0.3, 0.3), (0.26, 0.26)], seg=10)), "Build", STONE_L)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((1.2, 1.1, 3.0)), V((1.2, 1.1, 3.15))], [(0.36, 0.36)] * 2, seg=10)), "Build", (0.6, 0.58, 0.58))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((-1.0, 0.9, 1.6)), V((-1.05, 0.9, 3.0))], [(0.12, 0.12), (0.08, 0.08)], seg=6)), "Build", (0.5, 0.36, 0.26))
    clump(b, V((-1.05, 0.9, 3.35)), 0.75, 1, rnd, (0.42, 0.64, 0.3), "Build", 0.85)
    clump(b, V((-0.7, 0.7, 3.1)), 0.5, 1, rnd, (0.48, 0.7, 0.32), "Build", 0.85)
    for a, zf in ((-1.3, 0.75), (-1.9, 0.6), (-0.6, 0.55), (0.6, 0.8), (2.6, 0.6)):
        p, n = ellipsoid_point(size, a, zf)
        clump(b, p + V((0, 0.2, 0.0)), 0.08, 1, rnd, rnd.choice(FLOWERS), "Build", 1.0)
    # Stepping stones and a lantern post.
    for i, (x, y) in enumerate(((0.2, fy - 1.6), (-0.3, fy - 2.4), (0.25, fy - 3.2))):
        soft(b, cube_at(b, V((x, y, 0.0)), (0.7, 0.55, 0.12), Euler((0, 0, 0.3 * i))), STONE_L, 0.06)
    soft(b, cube_at(b, V((1.9, fy - 1.3, 0.9)), (0.12, 0.12, 1.8)), H_WOOD, 0.03)
    soft(b, cube_at(b, V((1.7, fy - 1.3, 1.78)), (0.5, 0.08, 0.08)), H_WOOD, 0.02, 1)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((1.5, fy - 1.3, 1.55)), (0.12, 0.12, 0.17), 6, 4)), "Glow", H_GLOW)
    return b


def swoop_lodge():
    """A tall A-frame whose roof sweeps almost to the ground with flaring eaves and a ridge that
    juts forward like a prow; warm wood front with a big wheel window, a deck and lanterns."""
    b = Builder(["Build", "Glow"])
    SLATE_T = (0.27, 0.4, 0.47)
    PLANK = (0.8, 0.58, 0.38)
    STONE_L = (0.68, 0.67, 0.68)
    D, HALF, EAVE, PEAK, DECK = 4.4, 2.9, 0.45, 5.6, 0.55
    for x in (-2.0, 2.0):                                  # stone footings under the frame
        for y in (-D / 2 - 0.9, 0.0, D / 2):
            soft(b, cube_at(b, V((x, y, DECK / 2 - 0.1)), (0.45, 0.45, DECK + 0.2)), STONE_L, 0.05)
    soft(b, cube_at(b, V((0, -0.45, DECK)), (4.4, D + 0.9, 0.16)), H_WOOD, 0.04)          # deck floor
    def x_at(v):                                          # half-width of the roof at height fraction v (concave)
        return HALF * (1 - v) ** 1.55
    # Front wall under the roof: warm planks following the curve.
    wy = -D / 2
    pts = []
    for k in range(13):
        v = k / 12
        x, z = x_at(v) - 0.32, EAVE + v * (PEAK - EAVE) - 0.35
        if DECK + 0.05 < z < PEAK - 0.75 and x > 0.1:
            pts.append((x, z))
    outline = [(-pts[0][0], DECK), (pts[0][0], DECK)] + pts + [(0, PEAK - 0.6)] + [(-x, z) for x, z in reversed(pts)]
    soft(b, outline_prism(b, outline, wy, D / 2), PLANK, 0.05)
    for x in (-1.2, -0.6, 0.6, 1.2):                     # a few plank grooves
        soft(b, cube_at(b, V((x, wy - 0.02, DECK + 1.0)), (0.04, 0.04, 1.9)), (0.66, 0.46, 0.3), 0.01, 1)
    # Roof: two thick concave planes, the ridge reaching forward.
    thick = 0.3
    for s in (-1, 1):
        def side(s=s):
            bm = b.bm
            nu, nv = 5, 7
            grid = [[None] * (nv + 1) for _ in range(nu + 1)]
            for i in range(nu + 1):
                u = i / nu
                for j in range(nv + 1):
                    v = j / nv
                    y0 = -D / 2 - 0.5 - 0.9 * v                 # front edge: the prow
                    y1 = D / 2 + 0.5 + 0.4 * v
                    y = y0 + u * (y1 - y0)
                    x = s * (x_at(v) + 0.08)
                    z = EAVE + v * (PEAK - EAVE) + 0.18 * (1 - v) ** 3 * (abs(2 * u - 1) ** 2)
                    grid[i][j] = bm.verts.new(V((x, y, z)))
            faces = []
            for i in range(nu):
                for j in range(nv):
                    q = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
                    faces.append(bm.faces.new(q if s < 0 else list(reversed(q))))
            for f in faces:
                f.normal_update()
            if sum(f.normal.z for f in faces) < 0:
                bmesh.ops.reverse_faces(bm, faces=faces)
            bmesh.ops.solidify(bm, geom=faces, thickness=thick)
        b.paint(b.new_faces(side), "Build", SLATE_T)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, -D / 2 - 1.45, PEAK + 0.1)), V((0, D / 2 + 0.95, PEAK + 0.1))], [(0.16, 0.18)] * 2, ref=V((1, 0, 0)), seg=6)), "Build", H_WOOD)
    # Big wheel window high on the front, double door below, deck steps, hanging lanterns.
    wz = DECK + 2.75
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, wy + 0.02, wz)), V((0, wy - 0.12, wz))], [(0.78, 0.78)] * 2, ref=V((1, 0, 0)), seg=16)), "Build", H_WOOD)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, wy - 0.12, wz)), V((0, wy - 0.15, wz))], [(0.64, 0.64)] * 2, ref=V((1, 0, 0)), seg=16)), "Glow", H_GLOW)
    for k in range(3):
        a = k * math.pi / 3
        d = V((math.cos(a), 0, math.sin(a))) * 0.64
        b.paint(b.new_faces(lambda d=d: rk.tube(b.bm, [V((0, wy - 0.17, wz)) - d, V((0, wy - 0.17, wz)) + d], [(0.035, 0.035)] * 2, seg=4)), "Build", H_WOOD)
    soft(b, outline_prism(b, arch_outline(0, DECK + 0.08, 1.5, 2.1), wy - 0.08, wy + 0.04), H_WOOD, 0.04)
    soft(b, outline_prism(b, arch_outline(0, DECK + 0.08, 1.24, 1.95), wy - 0.12, wy - 0.07), (0.62, 0.4, 0.26), 0.03)
    soft(b, cube_at(b, V((0, wy - 0.13, DECK + 1.0)), (0.04, 0.04, 1.85)), H_WOOD, 0.01, 1)
    for x in (-0.15, 0.15):
        soft(b, cube_at(b, V((x, wy - 0.17, DECK + 1.05)), (0.06, 0.05, 0.06)), (0.9, 0.76, 0.42), 0.015, 1)
    for i in range(3):
        soft(b, cube_at(b, V((0, -D / 2 - 1.05 - i * 0.32, DECK - 0.18 - i * 0.18)), (1.6, 0.34, 0.12)), H_WOOD, 0.03)
    for x in (-1.55, 1.55):                              # deck rails and lanterns hanging from the eaves
        soft(b, cube_at(b, V((x, -D / 2 - 0.85, DECK + 0.45)), (0.1, 0.1, 0.9)), H_WOOD, 0.02, 1)
        soft(b, cube_at(b, V((x, -D / 2 - 0.4, DECK + 0.85)), (0.08, 0.9, 0.08)), H_WOOD, 0.02, 1)
        b.paint(b.new_faces(lambda x=x: rk.tube(b.bm, [V((x * 0.8, -D / 2 - 0.9, DECK + 2.45)), V((x * 0.8, -D / 2 - 0.9, DECK + 2.0))], [(0.015, 0.015)] * 2, seg=4)), "Build", (0.2, 0.18, 0.18))
        b.paint(b.new_faces(lambda x=x: rk.blob(b.bm, V((x * 0.8, -D / 2 - 0.9, DECK + 1.88)), (0.12, 0.12, 0.17), 6, 4)), "Glow", H_GLOW)
    # Round stone chimney out of the right slope.
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((1.2, 1.0, 2.2)), V((1.2, 1.0, 5.0))], [(0.3, 0.3), (0.27, 0.27)], seg=10)), "Build", STONE_L)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((1.2, 1.0, 5.0)), V((1.2, 1.0, 5.16))], [(0.36, 0.36)] * 2, seg=10)), "Build", (0.58, 0.57, 0.58))
    return b


# --- Dark diorama style (owner's references): faceted slate, stepped hex/octagon bases, soft
# --- glowing crystals and runes, gold trims, warm windows. Flat colours, few big shapes.
DK_SLATE = (0.46, 0.49, 0.56)
DK_SLATE_D = (0.33, 0.35, 0.42)
DK_SLATE_L = (0.58, 0.6, 0.66)
ROOF_D = (0.24, 0.28, 0.38)
TIMBER_D = (0.36, 0.25, 0.19)
GOLD = (0.95, 0.72, 0.3)
CYAN = (0.45, 0.95, 1.0)
TEAL = (0.4, 0.95, 0.82)
AMBER = (1.0, 0.72, 0.36)
EMBER = (1.0, 0.45, 0.16)
MOSS_D = (0.3, 0.46, 0.28)


def prism_n(b, n, r0, r1, z0, z1, color, bevel=0.05, mat="Build", turn=0.0):
    """An n-sided prism (hexagon, octagon...) from z0 to z1, radius r0 at the bottom, r1 at the top."""
    def make():
        rk.tube(b.bm, [V((0, 0, z0)), V((0, 0, z1))], [(r0, r0), (r1, r1)], ref=V((math.cos(turn), math.sin(turn), 0)), seg=n)
    if bevel > 0:
        soft(b, make, color, bevel, 1, mat)
    else:
        b.paint(b.new_faces(make), mat, color)


def crystal(b, base, direction, length, width, color):
    """A four-sided glowing crystal: a short prism ending in a point."""
    d = direction.normalized()
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [base, base + d * length * 0.7, base + d * length],
                                        [(width, width), (width * 0.95, width * 0.95), (0.005, 0.005)], ref=V((1, 0, 0)) if abs(d.z) > 0.9 else V((0, 0, 1)), seg=4)), "Glow", color)


def face_point(n, apothem, k, z, turn=0.0):
    """The centre of side k of an n-sided prism (whose corners start at angle `turn`) and its outward direction."""
    a = turn + (k + 0.5) * math.tau / n
    out = V((math.cos(a), math.sin(a), 0))
    return out * apothem + V((0, 0, z)), out


def hex_window(b, p, out, r, glow=AMBER):
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [p - out * 0.05, p + out * 0.1], [(r, r)] * 2, ref=V((0, 0, 1)), seg=6)), "Build", TIMBER_D)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [p + out * 0.1, p + out * 0.13], [(r * 0.75, r * 0.75)] * 2, ref=V((0, 0, 1)), seg=6)), "Glow", glow)


def hex_house():
    """A six-sided stone house on a stepped hex base: slate walls with darker corner pillars and
    gold caps, a timber band, a dark hex roof with gold ridges and a floating cyan crystal, glowing
    hex windows, and a stone kiln with a glowing ember mouth beside it."""
    b = Builder(["Build", "Glow"])
    t = math.pi / 6                                            # corners at 30 deg: a flat side faces front
    prism_n(b, 6, 3.1, 3.1, -0.1, 0.25, DK_SLATE_D, 0.06, turn=t)
    prism_n(b, 6, 2.75, 2.75, 0.25, 0.5, DK_SLATE_L, 0.06, turn=t)
    R = 2.35
    prism_n(b, 6, R, R, 0.5, 2.3, DK_SLATE, 0.06, turn=t)
    for k in range(6):                                         # corner pillars with gold caps
        a = t + k * math.tau / 6
        c = V((math.cos(a) * R, math.sin(a) * R, 0))
        soft(b, cube_at(b, c + V((0, 0, 1.45)), (0.42, 0.42, 1.9), Euler((0, 0, a))), DK_SLATE_D, 0.05)
        soft(b, cube_at(b, c + V((0, 0, 2.45)), (0.5, 0.5, 0.12), Euler((0, 0, a))), GOLD, 0.03)
    prism_n(b, 6, R - 0.12, R - 0.12, 2.3, 2.95, TIMBER_D, 0.04, turn=t)
    # Roof: a dark hex pyramid with a thick eave, gold ridges, a floating crystal.
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, 2.8)), V((0, 0, 3.05)), V((0, 0, 5.3))], [(3.05, 3.05), (2.95, 2.95), (0.12, 0.12)],
                                        ref=V((math.cos(t), math.sin(t), 0)), seg=6)), "Build", ROOF_D)
    for k in range(6):
        a = t + k * math.tau / 6
        beam(b, V((math.cos(a) * 3.08, math.sin(a) * 3.08, 3.02)), V((0, 0, 5.28)), 0.05, GOLD)
    prism_n(b, 6, 0.2, 0.2, 5.25, 5.4, GOLD, 0.02, turn=t)
    crystal(b, V((0, 0, 5.62)), V((0, 0, 1)), 0.75, 0.2, CYAN)
    crystal(b, V((0, 0, 5.62)), V((0, 0, -1)), 0.22, 0.2, CYAN)
    ap = R * math.cos(math.pi / 6)
    # Door on the front side, glowing hex windows on the two front-angled sides.
    fy = -ap - 0.02
    soft(b, outline_prism(b, arch_outline(0, 0.5, 1.2, 1.95), fy - 0.1, fy + 0.05), DK_SLATE_D, 0.04)
    soft(b, outline_prism(b, arch_outline(0, 0.5, 0.92, 1.8), fy - 0.14, fy - 0.09), TIMBER_D, 0.03)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0.28, fy - 0.17, 1.35)), (0.05, 0.03, 0.05), 6, 4)), "Build", GOLD)
    for k in (3, 5):                                           # sides at -150 and -30 deg
        p, out = face_point(6, ap, k, 1.55, t)
        hex_window(b, p, out, 0.34)
    p, out = face_point(6, ap - 0.1, 4, 2.62, t)               # a small glowing slot in the timber band
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [p - out * 0.02, p + out * 0.08], [(0.5, 0.07)] * 2, ref=V((1, 0, 0)), seg=4)), "Glow", AMBER)
    # The kiln: a stone dome on a block, a glowing ember mouth, logs, a chimney pipe.
    k0 = V((3.2, 0.8, 0))
    soft(b, cube_at(b, k0 + V((0, 0, 0.45)), (1.6, 1.5, 0.9)), DK_SLATE_L, 0.06)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, k0 + V((0, 0, 0.9)), (0.72, 0.68, 0.75), 12, 8, keep=lambda q: q.z >= k0.z + 0.88)), "Build", (0.62, 0.62, 0.64))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [k0 + V((0, -0.55, 1.15)), k0 + V((0, -0.75, 1.15))], [(0.3, 0.3)] * 2, ref=V((1, 0, 0)), seg=10)), "Build", DK_SLATE_D)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [k0 + V((0, -0.7, 1.12)), k0 + V((0, -0.77, 1.12))], [(0.22, 0.22)] * 2, ref=V((1, 0, 0)), seg=10)), "Glow", EMBER)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [k0 + V((0, -0.76, 0.4)), k0 + V((0, -0.79, 0.4))], [(0.45, 0.18)] * 2, ref=V((1, 0, 0)), seg=6)), "Glow", EMBER)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [k0 + V((0.1, 0.1, 1.5)), k0 + V((0.1, 0.1, 2.3))], [(0.13, 0.13)] * 2, seg=8)), "Build", DK_SLATE_D)
    for i in range(3):
        log(b, k0 + V((-0.5 + i * 0.35, -1.15, 0.12)), k0 + V((-0.5 + i * 0.35, -1.7, 0.12)), 0.11)
    # A lantern by the door.
    soft(b, cube_at(b, V((-1.0, fy - 0.3, 1.9)), (0.06, 0.5, 0.06)), DK_SLATE_D, 0.01, 1)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((-1.0, fy - 0.52, 1.72)), V((-1.0, fy - 0.52, 1.5))], [(0.1, 0.1), (0.08, 0.08)], seg=6)), "Glow", AMBER)
    return b


def grotto_house():
    """A home built into an outcrop of faceted dark rock: a timber front with a round door and lit
    windows, glowing teal crystals growing from the rock, moss on top, carved steps."""
    b = Builder(["Build", "Glow"])
    rocks = [(V((0, 0.6, 1.2)), 2.4, DK_SLATE), (V((-1.9, 0.9, 0.9)), 1.7, DK_SLATE_D), (V((1.9, 0.8, 1.0)), 1.8, DK_SLATE),
             (V((0.4, 1.3, 2.7)), 1.6, DK_SLATE_L), (V((-1.2, 1.5, 2.3)), 1.2, DK_SLATE_D), (V((2.6, -0.2, 0.4)), 0.8, DK_SLATE_D)]
    for c, r, col in rocks:
        clump(b, c, r, 1, rnd, col, "Build", 0.85)
    # Timber front set into the rock.
    fy = -1.25
    soft(b, outline_prism(b, [(-1.6, 0.0), (1.6, 0.0), (1.6, 2.1), (0.8, 2.75), (-0.8, 2.75), (-1.6, 2.1)], fy, fy + 1.2), TIMBER_D, 0.06)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, fy - 0.02, 1.05)), V((0, fy - 0.14, 1.05))], [(0.72, 0.72)] * 2, ref=V((1, 0, 0)), seg=14)), "Build", DK_SLATE_D)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, fy - 0.14, 1.05)), V((0, fy - 0.2, 1.05))], [(0.6, 0.6)] * 2, ref=V((1, 0, 0)), seg=14)), "Build", (0.55, 0.36, 0.24))
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0.3, fy - 0.24, 1.05)), (0.06, 0.04, 0.06), 6, 4)), "Build", GOLD)
    for x in (-1.1, 1.1):
        soft(b, cube_at(b, V((x, fy - 0.05, 1.6)), (0.5, 0.1, 0.55)), DK_SLATE_D, 0.03)
        soft(b, cube_at(b, V((x, fy - 0.09, 1.6)), (0.38, 0.06, 0.42)), AMBER, 0.02, 1, "Glow")
    soft(b, cube_at(b, V((0, fy - 0.45, 2.35)), (2.2, 0.9, 0.1), Euler((-0.3, 0, 0))), TIMBER_D, 0.04)        # little awning
    # Crystals growing out of the rock, glowing teal.
    for base, d, ln, w in ((V((1.3, 0.4, 3.0)), V((0.3, -0.2, 1)), 1.4, 0.26), (V((1.7, 0.7, 2.7)), V((0.8, 0.1, 1)), 1.0, 0.2),
                           (V((0.9, 0.2, 3.1)), V((-0.2, -0.4, 1)), 0.8, 0.16), (V((-1.6, 0.4, 2.4)), V((-0.6, -0.2, 1)), 0.9, 0.18),
                           (V((-1.9, 0.0, 1.8)), V((-1, -0.4, 0.6)), 0.6, 0.14), (V((2.5, -0.5, 0.8)), V((0.7, -0.5, 0.8)), 0.6, 0.14)):
        crystal(b, base, d, ln, w, TEAL)
    for p, r in ((V((-0.4, 1.0, 3.6)), 0.5), (V((0.6, 1.4, 3.8)), 0.4), (V((-1.3, 1.6, 3.2)), 0.4)):
        clump(b, p, r, 1, rnd, MOSS_D, "Build", 0.5)
    for i in range(3):                                          # carved steps
        soft(b, cube_at(b, V((0, fy - 0.55 - i * 0.4, 0.12 - i * 0.08)), (1.6 - i * 0.1, 0.42, 0.2)), DK_SLATE_L, 0.05)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((-0.9, 1.6, 2.6)), V((-0.9, 1.6, 4.3))], [(0.16, 0.16)] * 2, seg=8)), "Build", DK_SLATE_D)   # chimney
    soft(b, cube_at(b, V((1.9, fy - 1.1, 0.9)), (0.12, 0.12, 1.8)), TIMBER_D, 0.02)                    # lantern post
    soft(b, cube_at(b, V((1.75, fy - 1.1, 1.78)), (0.4, 0.08, 0.08)), TIMBER_D, 0.02, 1)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((1.6, fy - 1.1, 1.62)), V((1.6, fy - 1.1, 1.38))], [(0.11, 0.11), (0.09, 0.09)], seg=6)), "Glow", AMBER)
    return b


def rune_tower():
    """A slim octagonal stone tower on stepped octagon bases: glowing rune strips, gold bands, a lit
    lantern room at the top under a dark spire with a small crystal."""
    b = Builder(["Build", "Glow"])
    t = math.pi / 8
    prism_n(b, 8, 2.9, 2.9, -0.1, 0.25, DK_SLATE_D, 0.06, turn=t)
    prism_n(b, 8, 2.5, 2.5, 0.25, 0.55, DK_SLATE_L, 0.06, turn=t)
    prism_n(b, 8, 1.8, 1.55, 0.55, 5.3, DK_SLATE, 0.05, turn=t)
    for z, r in ((0.6, 1.86), (2.9, 1.74), (5.25, 1.62)):       # gold bands
        prism_n(b, 8, r, r, z, z + 0.14, GOLD, 0.02, turn=t)
    ap = lambda r: r * math.cos(math.pi / 8)
    for k in (1, 3, 5, 7):                                      # rune strips on alternate sides
        for z0, z1, r in ((0.95, 2.6, 1.72), (3.25, 4.9, 1.6)):
            p, out = face_point(8, ap(r) + 0.01, k, (z0 + z1) / 2, t)
            b.paint(b.new_faces(lambda p=p, out=out, h=(z1 - z0): rk.tube(b.bm, [p - out * 0.02, p + out * 0.05], [(0.07, h / 2)] * 2, ref=V((out.y, -out.x, 0)), seg=4)), "Glow", CYAN)
    # Lantern room: wider, glowing panes all round, then the spire.
    prism_n(b, 8, 2.0, 2.0, 5.35, 5.55, DK_SLATE_D, 0.04, turn=t)
    prism_n(b, 8, 1.75, 1.75, 5.55, 6.75, AMBER, 0.0, "Glow", turn=t)
    for k in range(8):
        a = t + k * math.tau / 8
        soft(b, cube_at(b, V((math.cos(a) * 1.8, math.sin(a) * 1.8, 6.15)), (0.2, 0.2, 1.25), Euler((0, 0, a))), DK_SLATE_D, 0.03)
    prism_n(b, 8, 2.15, 2.15, 6.75, 6.95, GOLD, 0.03, turn=t)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, 6.9)), V((0, 0, 7.1)), V((0, 0, 9.4))], [(2.2, 2.2), (2.05, 2.05), (0.08, 0.08)],
                                        ref=V((math.cos(t), math.sin(t), 0)), seg=8)), "Build", ROOF_D)
    crystal(b, V((0, 0, 9.5)), V((0, 0, 1)), 0.6, 0.15, CYAN)
    crystal(b, V((0, 0, 9.5)), V((0, 0, -1)), 0.18, 0.15, CYAN)
    # Door on the front with a glowing rune above it; two slim obelisks either side.
    fy = -ap(1.8) - 0.02
    soft(b, outline_prism(b, arch_outline(0, 0.55, 1.1, 1.95), fy - 0.12, fy + 0.05), DK_SLATE_D, 0.04)
    soft(b, outline_prism(b, arch_outline(0, 0.55, 0.84, 1.8), fy - 0.16, fy - 0.11), TIMBER_D, 0.03)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, fy - 0.12, 2.75)), V((0, fy - 0.18, 2.75))], [(0.16, 0.16)] * 2, ref=V((1, 0, 0)), seg=6)), "Glow", CYAN)
    for x in (-1.9, 1.9):
        soft(b, cube_at(b, V((x, fy - 0.9, 0.95)), (0.36, 0.36, 1.8)), DK_SLATE_D, 0.05)
        b.paint(b.new_faces(lambda x=x: rk.tube(b.bm, [V((x, fy - 0.9, 1.85)), V((x, fy - 0.9, 2.35))], [(0.2, 0.2), (0.005, 0.005)], ref=V((1, 0, 0)), seg=4)), "Build", DK_SLATE_D)
        soft(b, cube_at(b, V((x, fy - 1.09, 1.1)), (0.1, 0.03, 0.9)), CYAN, 0.01, 1, "Glow")
    for i in range(2):
        soft(b, cube_at(b, V((0, fy - 0.45 - i * 0.4, 0.4 - i * 0.18)), (1.5, 0.42, 0.18)), DK_SLATE_L, 0.05)
    return b


def arch_cottage():
    """A cottage under one smooth barrel roof that sweeps almost to the ground (the lodge's roof-as-
    the-house idea, rounded like the hill house): warm wood front, a big glowing round window over
    an arched door, two lanterns, a small porch with planters, a stone chimney."""
    b = Builder(["Build", "Glow"])
    ROOF = (0.68, 0.36, 0.29)
    PLANK = (0.8, 0.58, 0.38)
    STONE_L = (0.68, 0.67, 0.68)
    HALF, TOP, BASE, D = 2.7, 4.3, 0.4, 5.6          # roof half-width, apex, eave height, depth
    soft(b, cube_at(b, V((0, 0, 0.12)), (5.0, D + 0.4, 0.34)), STONE_L, 0.07)

    def arch_xz(t, grow=0.0):                          # t 0..1 across the arch, left to right
        a = math.pi * (1 - t)
        return math.cos(a) * (HALF + grow), BASE + math.sin(a) * (TOP - BASE + grow)

    # The roof: a thick barrel shell, a little longer at the front to shade the porch.
    def roof():
        bm = b.bm
        nu, nv = 14, 4
        grid = [[None] * (nv + 1) for _ in range(nu + 1)]
        for i in range(nu + 1):
            x, z = arch_xz(i / nu)
            for j in range(nv + 1):
                y = -D / 2 - 0.7 + j / nv * (D + 1.0)
                grid[i][j] = bm.verts.new(V((x, y, z)))
        faces = []
        for i in range(nu):
            for j in range(nv):
                faces.append(bm.faces.new([grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]]))
        for f in faces:
            f.normal_update()
        if sum(f.normal.z for f in faces) < 0:
            bmesh.ops.reverse_faces(bm, faces=faces)
        bmesh.ops.solidify(bm, geom=faces, thickness=0.3)
    b.paint(b.new_faces(roof), "Build", ROOF)
    # Front and back walls: warm planks filling the arch, set back under the roof.
    outline = [(-HALF + 0.3, 0.3)] + [(x * 0.86, z * 0.95) for x, z in (arch_xz(k / 12) for k in range(1, 12))] + [(HALF - 0.3, 0.3)]
    outline = [(outline[0][0], 0.3)] + [(x, max(z, 0.3)) for x, z in outline[1:-1]] + [(outline[-1][0], 0.3)]
    soft(b, outline_prism(b, list(reversed(outline)), -D / 2 + 0.1, D / 2 - 0.2), PLANK, 0.05)
    fy = -D / 2 + 0.1
    for x in (-1.3, -0.65, 0.65, 1.3):                  # a few plank grooves
        soft(b, cube_at(b, V((x, fy - 0.02, 1.4)), (0.04, 0.04, 2.1)), (0.68, 0.48, 0.31), 0.01, 1)
    # Big round window high up, glowing, with a wooden frame and bars.
    wz = 2.85
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, fy + 0.02, wz)), V((0, fy - 0.12, wz))], [(0.72, 0.72)] * 2, ref=V((1, 0, 0)), seg=16)), "Build", H_WOOD)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, fy - 0.12, wz)), V((0, fy - 0.15, wz))], [(0.58, 0.58)] * 2, ref=V((1, 0, 0)), seg=16)), "Glow", H_GLOW)
    for d in (V((0.58, 0, 0)), V((0, 0, 0.58))):
        b.paint(b.new_faces(lambda d=d: rk.tube(b.bm, [V((0, fy - 0.17, wz)) - d, V((0, fy - 0.17, wz)) + d], [(0.035, 0.035)] * 2, seg=4)), "Build", H_WOOD)
    # Arched door, lanterns either side.
    soft(b, outline_prism(b, arch_outline(0, 0.3, 1.3, 1.95), fy - 0.08, fy + 0.04), H_WOOD, 0.04)
    soft(b, outline_prism(b, arch_outline(0, 0.3, 1.04, 1.8), fy - 0.12, fy - 0.07), (0.6, 0.39, 0.25), 0.03)
    soft(b, cube_at(b, V((0.34, fy - 0.15, 1.2)), (0.07, 0.05, 0.07)), (0.9, 0.76, 0.42), 0.015, 1)
    for x in (-1.1, 1.1):
        soft(b, cube_at(b, V((x, fy - 0.2, 1.95)), (0.05, 0.36, 0.05)), H_WOOD, 0.01, 1)
        b.paint(b.new_faces(lambda x=x: rk.blob(b.bm, V((x, fy - 0.4, 1.78)), (0.11, 0.11, 0.16), 6, 4)), "Glow", H_GLOW)
    # Porch: a low deck and two steps, planters with flowers at the corners.
    soft(b, cube_at(b, V((0, fy - 0.75, 0.3)), (3.4, 1.3, 0.14)), H_WOOD, 0.04)
    for i in range(2):
        soft(b, cube_at(b, V((0, fy - 1.55 - i * 0.32, 0.18 - i * 0.12)), (1.5, 0.34, 0.12)), H_WOOD, 0.03)
    for x in (-1.45, 1.45):
        soft(b, cube_at(b, V((x, fy - 1.1, 0.55)), (0.5, 0.5, 0.36)), (0.62, 0.42, 0.28), 0.04)
        clump(b, V((x, fy - 1.1, 0.85)), 0.3, 1, rnd, (0.44, 0.64, 0.3), "Build", 0.8)
        for k in range(3):
            clump(b, V((x + (k - 1) * 0.14, fy - 1.22, 1.02)), 0.06, 1, rnd, FLOWERS[k], "Build", 1.0)
    # Stone chimney out of the roof, towards the back.
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((1.3, 1.5, 3.0)), V((1.3, 1.5, 4.9))], [(0.3, 0.3), (0.27, 0.27)], seg=10)), "Build", STONE_L)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((1.3, 1.5, 4.9)), V((1.3, 1.5, 5.05))], [(0.36, 0.36)] * 2, seg=10)), "Build", (0.58, 0.57, 0.58))
    return b


def gable_house():
    """Raised on a stone plinth: clean pale walls under a tall, steep charcoal roof whose ridge sits
    off-centre (one side sweeps lower) and juts forward to a point; thin dark frame lines along the
    gable edges meeting past the peak; a tall glowing window slit over a tall straight door."""
    b = Builder(["Build", "Glow"])
    WALL = (0.88, 0.89, 0.9)
    PLINTH = (0.6, 0.62, 0.66)
    ROOF = (0.22, 0.25, 0.3)
    FRAME = (0.32, 0.3, 0.31)
    LIGHT = (1.0, 0.85, 0.6)
    W, D, F, H = 3.6, 4.6, 0.6, 2.5              # width, depth, plinth height, wall height
    RX, PEAK = 0.45, F + H + 3.7                  # ridge offset to the right, ridge height
    soft(b, cube_at(b, V((0, 0, F / 2 - 0.05)), (W + 1.0, D + 1.0, F + 0.1)), PLINTH, 0.07)
    for i in range(3):                            # steps up to the plinth
        soft(b, cube_at(b, V((-0.2, -D / 2 - 0.75 - i * 0.32, F - 0.12 - i * 0.2)), (1.4, 0.34, 0.2)), PLINTH, 0.05)
    eave_l, eave_r = F + H, F + H + 0.55          # the right eave sits higher: a lopsided, sharp roof
    outline = [(-W / 2, F), (W / 2, F), (W / 2, eave_r), (RX, PEAK - 0.35), (-W / 2, eave_l)]
    soft(b, outline_prism(b, outline, -D / 2, D / 2), WALL, 0.05)
    # Roof: two thick planes from each eave to the off-centre ridge; the front edge juts forward
    # more towards the top.
    thick = 0.26
    for side, x_eave, z_eave in ((-1, -W / 2 - 0.55, eave_l - 0.4), (1, W / 2 + 0.45, eave_r - 0.3)):
        def plane(x_eave=x_eave, z_eave=z_eave, side=side):
            bm = b.bm
            nu, nv = 3, 3
            grid = [[None] * (nv + 1) for _ in range(nu + 1)]
            for i in range(nu + 1):
                u = i / nu
                for j in range(nv + 1):
                    v = j / nv                           # 0 at the eave, 1 at the ridge
                    x = x_eave + (RX - x_eave) * v
                    z = z_eave + (PEAK - z_eave) * v
                    y0 = -D / 2 - 0.5 - 1.1 * v * v      # the prow
                    y1 = D / 2 + 0.5
                    grid[i][j] = bm.verts.new(V((x, y0 + u * (y1 - y0), z)))
            faces = []
            for i in range(nu):
                for j in range(nv):
                    q = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
                    faces.append(bm.faces.new(q if side < 0 else list(reversed(q))))
            for f in faces:
                f.normal_update()
            if sum(f.normal.z for f in faces) < 0:
                bmesh.ops.reverse_faces(bm, faces=faces)
            bmesh.ops.solidify(bm, geom=faces, thickness=thick)
        b.paint(b.new_faces(plane), "Build", ROOF)
    # Thin dark frame lines along the front gable, meeting in a point just past the peak.
    fy = -D / 2 - 0.03
    tip = V((RX + 0.08, fy, PEAK + 0.35))
    beam(b, V((-W / 2 - 0.1, fy, eave_l - 0.1)), tip, 0.04, FRAME)
    beam(b, V((W / 2 + 0.1, fy, eave_r - 0.1)), tip, 0.04, FRAME)
    # The tall window slit up the gable, and a tall straight door with a glowing transom.
    wx = RX * 0.6
    soft(b, cube_at(b, V((wx, fy - 0.03, F + H + 1.25)), (0.5, 0.1, 2.3)), FRAME, 0.03)
    soft(b, cube_at(b, V((wx, fy - 0.07, F + H + 1.25)), (0.3, 0.04, 2.1)), LIGHT, 0.01, 1, "Glow")
    soft(b, cube_at(b, V((-0.2, fy - 0.03, F + 1.05)), (1.0, 0.1, 2.1)), FRAME, 0.03)
    soft(b, cube_at(b, V((-0.2, fy - 0.07, F + 0.98)), (0.8, 0.04, 1.9)), (0.4, 0.3, 0.25), 0.02)
    soft(b, cube_at(b, V((-0.2, fy - 0.07, F + 2.02)), (0.8, 0.04, 0.1)), LIGHT, 0.01, 1, "Glow")
    soft(b, cube_at(b, V((0.1, fy - 0.1, F + 1.0)), (0.04, 0.04, 0.34)), (0.85, 0.75, 0.5), 0.01, 1)
    # A side window each side, a square lantern by the door, a tall square chimney.
    for s in (-1, 1):
        soft(b, cube_at(b, V((s * (W / 2 + 0.03), 0.6, F + 1.4)), (0.1, 0.9, 0.9)), FRAME, 0.03)
        soft(b, cube_at(b, V((s * (W / 2 + 0.07), 0.6, F + 1.4)), (0.04, 0.72, 0.72)), LIGHT, 0.01, 1, "Glow")
    soft(b, cube_at(b, V((-1.25, fy - 0.12, F + 1.75)), (0.18, 0.18, 0.28)), FRAME, 0.02, 1)
    soft(b, cube_at(b, V((-1.25, fy - 0.16, F + 1.75)), (0.12, 0.06, 0.2)), LIGHT, 0.01, 1, "Glow")
    soft(b, cube_at(b, V((-0.9, 1.1, PEAK - 0.9)), (0.55, 0.55, 2.2)), (0.4, 0.42, 0.46), 0.04)
    soft(b, cube_at(b, V((-0.9, 1.1, PEAK + 0.25)), (0.7, 0.7, 0.12)), ROOF, 0.03)
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
export("house_hill", hill_house(), OUT)
export("house_lodge", swoop_lodge(), OUT)
export("house_hex", hex_house(), OUT)
export("house_grotto", grotto_house(), OUT)
export("house_tower", rune_tower(), OUT)
export("house_arch", arch_cottage(), OUT)
export("house_gable", gable_house(), OUT)

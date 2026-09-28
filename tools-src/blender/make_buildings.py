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
  house_storybook: stone ground floor, cream plaster above, tall flared blue-slate roof, big arched
                 gable window, arched door with hood and lanterns, side porch.
  house_turret:  curved oval body, bell roof in tile rows, round dormer, turret, shell canopy door.
  house_lantern: plaster cottage, flared hip roof in tile rows opening into a glowing lantern cupola.
  house_hull:    stone cottage roofed with an upturned boat hull, side-on: prow and lantern, portholes.
  house_skep:    meadow: a dome of stacked straw coils like an old beehive, hex window glowing honey-gold.
  house_stump:   forest: a home in a colossal tree stump, roots, mossy shingle cone roof, fungus steps.
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


def storybook_cottage():
    """A two-level cottage for the main village: a warm stone ground floor and cream plaster above,
    under a tall blue-slate roof whose eaves flare gently outward (the roof is about half the
    height, as on the swoop lodge). The front gable carries a big glowing arched window; below it
    an arched door with a little hood and two lanterns, two small windows with flower boxes. A low
    open porch off the right side with a bench. Timber only at the corners and bands. Faces -Y."""
    b = Builder(["Build", "Glow"])
    STONE_W = (0.76, 0.7, 0.62)
    STONE_Q = (0.68, 0.63, 0.57)
    PLASTER = (0.95, 0.89, 0.77)
    TIMBER = (0.43, 0.29, 0.2)
    ROOF = (0.31, 0.44, 0.55)
    RIDGE = (0.24, 0.34, 0.43)
    DOOR = (0.55, 0.36, 0.23)
    LIGHT = (1.0, 0.8, 0.46)
    W, D = 4.2, 4.8                 # footprint
    S = 1.3                          # stone storey height
    U = 3.3                          # top of the plaster walls
    EAVE, PEAK = 2.55, 7.1           # roof eave and ridge heights
    HALF = W / 2 + 0.75              # roof half-width at the eave
    FY = -D / 2                      # the front face

    # --- ground floor: stone, with slightly proud corner stones --------------------------------
    soft(b, cube_at(b, V((0, 0, S / 2)), (W + 0.16, D + 0.16, S)), STONE_W, 0.07)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for k, h in enumerate((0.42, 0.42, 0.36)):
                big = k % 2 == 0
                cx = sx * (W / 2 + 0.04 - (0.2 if big else 0.14))
                cy = sy * (D / 2 + 0.04 - (0.14 if big else 0.2))
                soft(b, cube_at(b, V((cx, cy, 0.22 + k * 0.43)), ((0.46 if big else 0.32) + 0.04, (0.32 if big else 0.46) + 0.04, h)), STONE_Q, 0.05)
    soft(b, cube_at(b, V((0, 0, S + 0.05)), (W + 0.24, D + 0.24, 0.12)), TIMBER, 0.03)          # sill band

    # --- upper storey and gables: cream plaster, the gable following the roof's curve ----------
    def x_at(v):                                     # roof half-width at height fraction v (concave)
        return HALF * (1 - v) ** 1.3

    edge = []
    for k in range(16):
        v = 0.2 + k * 0.05
        x, z = x_at(v) - 0.14, EAVE + v * (PEAK - EAVE) - 0.36
        if 0.05 < x < W / 2 and z > U:
            edge.append((x, z))
    outline = [(-W / 2, S), (W / 2, S), (W / 2, U)] + edge + [(0, PEAK - 0.62)] + [(-x, z) for x, z in reversed(edge)] + [(-W / 2, U)]
    soft(b, outline_prism(b, outline, -D / 2, D / 2), PLASTER, 0.05)
    for sx in (-1, 1):                               # corner posts and the band under the gable
        for sy in (-1, 1):
            soft(b, cube_at(b, V((sx * W / 2, sy * D / 2, (S + U) / 2)), (0.2, 0.2, U - S)), TIMBER, 0.03)
    for y in (FY - 0.02, D / 2 + 0.02):
        soft(b, cube_at(b, V((0, y, U)), (W + 0.1, 0.16, 0.16)), TIMBER, 0.03)

    # --- roof: two thick planes, the eaves flaring gently outward ------------------------------
    thick = 0.28
    for side in (-1, 1):
        def plane(side=side):
            bm = b.bm
            nu, nv = 4, 8
            grid = [[None] * (nv + 1) for _ in range(nu + 1)]
            for i in range(nu + 1):
                u = i / nu
                for j in range(nv + 1):
                    v = j / nv
                    y0 = FY - 0.6 - 0.35 * v * v             # a slight prow at the front
                    y1 = D / 2 + 0.6
                    x = side * (x_at(v) + 0.02)
                    z = EAVE + v * (PEAK - EAVE) + 0.12 * (1 - v) ** 3 * abs(2 * u - 1) ** 2
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
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, FY - 0.95, PEAK + 0.06)), V((0, D / 2 + 0.6, PEAK + 0.06))],
                                        [(0.13, 0.15)] * 2, ref=V((1, 0, 0)), seg=6)), "Build", RIDGE)

    # --- front gable: the big arched window ------------------------------------------------------
    wz0, ww, wh = U + 0.25, 1.25, 1.75
    soft(b, outline_prism(b, arch_outline(0, wz0, ww + 0.24, wh + 0.12, 8), FY - 0.08, FY + 0.05), TIMBER, 0.035)
    b.paint(b.new_faces(outline_prism(b, arch_outline(0, wz0 + 0.06, ww, wh, 8), FY - 0.1, FY - 0.07)), "Glow", LIGHT)
    soft(b, cube_at(b, V((0, FY - 0.12, wz0 + wh / 2 + 0.04)), (0.05, 0.04, wh - 0.1)), TIMBER, 0.01, 1)
    soft(b, cube_at(b, V((0, FY - 0.12, wz0 + wh * 0.42)), (ww - 0.04, 0.04, 0.05)), TIMBER, 0.01, 1)
    soft(b, cube_at(b, V((0, FY - 0.13, wz0 - 0.06)), (ww + 0.45, 0.24, 0.1)), TIMBER, 0.02)      # sill

    # --- ground floor front: arched door with a hood and lanterns, two windows with flowers --------
    sy = FY - 0.08                                     # the stone face
    soft(b, outline_prism(b, arch_outline(0, 0.0, 1.22, 2.05, 8), sy - 0.06, sy + 0.05), TIMBER, 0.035)
    soft(b, outline_prism(b, arch_outline(0, 0.0, 0.98, 1.92, 8), sy - 0.1, sy - 0.05), DOOR, 0.03)
    for x in (-0.24, 0.24):
        soft(b, cube_at(b, V((x, sy - 0.11, 0.95)), (0.035, 0.03, 1.7)), TIMBER, 0.008, 1)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0.3, sy - 0.14, 1.0)), (0.05, 0.035, 0.05), 6, 4)), "Build", (0.92, 0.76, 0.42))
    soft(b, cube_at(b, V((0, sy - 0.42, 2.28)), (1.55, 0.78, 0.1), Euler((-0.42, 0, 0))), ROOF, 0.03)   # door hood
    for x in (-0.62, 0.62):
        soft(b, cube_at(b, V((x, sy - 0.25, 2.06)), (0.06, 0.4, 0.06), Euler((0.5, 0, 0))), TIMBER, 0.01, 1)
    for x in (-0.95, 0.95):                              # lanterns either side of the door
        soft(b, cube_at(b, V((x, sy - 0.14, 1.7)), (0.05, 0.28, 0.05)), TIMBER, 0.01, 1)
        b.paint(b.new_faces(lambda x=x: rk.tube(b.bm, [V((x, sy - 0.3, 1.64)), V((x, sy - 0.3, 1.42))], [(0.1, 0.1), (0.085, 0.085)], seg=6)), "Glow", LIGHT)
        b.paint(b.new_faces(lambda x=x: rk.tube(b.bm, [V((x, sy - 0.3, 1.64)), V((x, sy - 0.3, 1.74))], [(0.12, 0.12), (0.02, 0.02)], seg=6)), "Build", TIMBER)
    for x in (-1.55, 1.55):                              # small windows with flower boxes
        soft(b, cube_at(b, V((x, sy - 0.03, 0.85)), (0.62, 0.1, 0.62)), TIMBER, 0.02)
        b.paint(b.new_faces(cube_at(b, V((x, sy - 0.07, 0.85)), (0.46, 0.04, 0.46))), "Glow", LIGHT)
        soft(b, cube_at(b, V((x, sy - 0.1, 0.85)), (0.04, 0.03, 0.46)), TIMBER, 0.005, 1)
        soft(b, cube_at(b, V((x, sy - 0.22, 0.47)), (0.72, 0.26, 0.2)), TIMBER, 0.02)
        for k in range(4):
            clump(b, V((x - 0.24 + k * 0.16, sy - 0.24, 0.62)), 0.075, 1, rnd, FLOWERS[k % len(FLOWERS)], "Build", 1.0)
    for i in range(2):                                   # stone steps
        soft(b, cube_at(b, V((0, sy - 0.45 - i * 0.36, 0.1 - i * 0.04)), (1.5 - i * 0.2, 0.4, 0.2 - i * 0.04)), STONE_Q, 0.04)

    # --- chimney on the left slope ---------------------------------------------------------------------
    soft(b, cube_at(b, V((-1.25, 1.2, 5.4)), (0.62, 0.62, 3.8)), STONE_W, 0.05)
    soft(b, cube_at(b, V((-1.25, 1.2, 7.35)), (0.78, 0.78, 0.14)), STONE_Q, 0.03)
    soft(b, cube_at(b, V((-1.25, 1.2, 7.52)), (0.3, 0.3, 0.2)), STONE_Q, 0.03)

    # --- the open porch on the right: a lean-to roof on two posts, a bench, a barrel ---------------------
    px0, px1 = HALF - 0.05, W / 2 + 2.1
    for y in (-1.3, 1.3):
        soft(b, cube_at(b, V((px1 - 0.15, y, 0.95)), (0.16, 0.16, 1.9)), TIMBER, 0.03)
    soft(b, cube_at(b, V(((px0 + px1) / 2 + 0.1, 0.0, 0.08)), (px1 - W / 2 + 0.1, 3.0, 0.16)), STONE_Q, 0.04)
    def lean_to():
        bm = b.bm
        pts = [V((px0 - 0.4, -1.65, 2.62)), V((px1 + 0.2, -1.65, 1.92)), V((px1 + 0.2, 1.65, 1.92)), V((px0 - 0.4, 1.65, 2.62))]
        top = [bm.verts.new(p) for p in pts]
        bot = [bm.verts.new(p - V((0, 0, 0.16))) for p in pts]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((top[j], top[i], bot[i], bot[j]))
    soft(b, lean_to, ROOF, 0.03)
    soft(b, cube_at(b, V((W / 2 + 0.55, 0.2, 0.5)), (0.42, 1.5, 0.08)), TIMBER, 0.02)               # bench
    for y in (-0.4, 0.8):
        soft(b, cube_at(b, V((W / 2 + 0.55, y, 0.28)), (0.36, 0.08, 0.4)), TIMBER, 0.01, 1)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((px1 - 0.55, -0.9, 0.16)), V((px1 - 0.55, -0.9, 0.5)), V((px1 - 0.55, -0.9, 0.84))],
                                        [(0.24, 0.24), (0.28, 0.28), (0.24, 0.24)], seg=10)), "Build", (0.52, 0.36, 0.24))

    # --- a few stepping stones and flowers at the base ---------------------------------------------------
    for i, (x, y) in enumerate(((0.15, sy - 1.45), (-0.2, sy - 2.2), (0.25, sy - 2.95))):
        soft(b, cube_at(b, V((x, y, 0.02)), (0.72, 0.52, 0.1), Euler((0, 0, 0.35 * i - 0.3))), STONE_Q, 0.05)
    for x, y in ((-2.2, sy - 0.3), (-1.0, sy - 0.35), (1.1, sy - 0.3)):
        clump(b, V((x, y, 0.12)), 0.18, 1, rnd, (0.42, 0.62, 0.3), "Build", 0.6)
    return b


def turret_cottage():
    """A curved, crafted-looking cottage: an oval two-storey body tapering a little upward (warm
    cream, darker at the foot) on a ring of rounded stones; a tall bell-shaped roof laid in tile rows
    of alternating blues with flared eaves; a round-topped dormer with a barrel roof and a big
    glowing arched window; a round turret with its own taller bell roof and a glowing round window;
    an arched door under a shell canopy with a hanging lantern; a curving stone chimney; stepping
    stones curving up to the door and a low curved flower-bed wall. Faces -Y."""
    b = Builder(["Build", "Glow"])
    WALL_LO, WALL_HI = (0.84, 0.72, 0.58), (0.97, 0.91, 0.8)
    STONES = [(0.72, 0.67, 0.6), (0.66, 0.61, 0.55), (0.78, 0.72, 0.64), (0.62, 0.58, 0.53)]
    TILES = [(0.26, 0.41, 0.52), (0.31, 0.47, 0.58), (0.28, 0.44, 0.55)]
    WOOD_D = (0.42, 0.28, 0.19)
    DOOR = (0.66, 0.3, 0.24)
    LIGHT = (1.0, 0.8, 0.46)
    RX, RY = 2.4, 2.0                                   # the oval body
    WZ0, WZ1 = 0.45, 3.5                                # wall bottom and top

    def on_oval(x, z, grow=0.0):
        """Point on the oval wall's front at x (height z, tapering) and its outward direction."""
        k = 1.0 - 0.07 * (z - WZ0) / (WZ1 - WZ0)
        rx, ry = RX * k + grow, RY * k + grow
        y = -ry * math.sqrt(max(0.0, 1 - (x / rx) ** 2))
        n = V((x / rx ** 2, y / ry ** 2, 0)).normalized()
        return V((x, y, z)), n

    def bell(center, rx, ry, z0, height, flare=1.3, rows=11, palette=TILES):
        """A bell-shaped roof in tile rows: a thick flared rim, then a concave sweep to a point."""
        prof = [(0.0, flare * 0.98), (0.03, flare)]
        for k in range(1, rows):
            t = k / rows
            prof.append((0.03 + t * 0.97, flare * 0.94 * (1 - t) ** 1.55 + 0.02))
        pts = [center + V((0, 0, z0 - 0.14 + p[0] * height)) for p in prof]
        radii = [(rx * p[1], ry * p[1]) for p in prof]
        faces = b.new_faces(lambda: rk.tube(b.bm, pts, radii, seg=18))
        for f in faces:
            zc = sum(v.co.z for v in f.verts) / len(f.verts)
            band = int((zc - z0) / (height / rows) + 10)
            base = palette[band % len(palette)]
            k = 1.0 + rnd.uniform(-0.035, 0.035) + max(0.0, (zc - z0) / height) * 0.08
            b.paint([f], "Build", tuple(min(1.0, c * k) for c in base))

    # --- stone footing: a flat oval slab ringed with rounded stones -------------------------------
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, 0.0)), V((0, 0, 0.42))], [(RX + 0.12, RY + 0.12)] * 2, seg=20)), "Build", STONES[1])
    for i in range(26):
        a = i / 26 * math.tau + 0.1
        p = V((math.cos(a) * (RX + 0.08), math.sin(a) * (RY + 0.08), 0.28))
        clump(b, p, rnd.uniform(0.26, 0.34), 1, rnd, rnd.choice(STONES), "Build", 0.75)
    # --- the oval walls, cream warming toward the foot --------------------------------------------
    walls = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, WZ0)), V((0, 0, 2.0)), V((0, 0, WZ1))],
                                        [(RX, RY), (RX * 0.975, RY * 0.975), (RX * 0.93, RY * 0.93)], seg=20))
    b.gradient(walls, WALL_LO, WALL_HI)
    # --- main bell roof, and a little moss on its rim ------------------------------------------------
    bell(V((0, 0, 0)), RX, RY, WZ1 - 0.2, 4.4, 1.3)
    for a in (-2.4, -0.3, 2.2, 3.7):
        clump(b, V((math.cos(a) * RX * 1.22, math.sin(a) * RY * 1.22, WZ1 - 0.12)), 0.2, 1, rnd, (0.42, 0.58, 0.3), "Build", 0.5)
    # --- the front dormer: round-topped, a barrel roof, a big glowing arched window ---------------
    dx = -0.35
    front_y = -RY * 0.93 - 0.02
    dor = b.new_faces(outline_prism(b, arch_outline(dx, WZ1 - 0.6, 1.9, 2.55, 10), front_y, front_y + 1.9))
    b.gradient(dor, WALL_LO, WALL_HI)
    def barrel():
        rk.tube(b.bm, [V((dx, front_y - 0.28, WZ1 + 1.0)), V((dx, front_y + 2.2, WZ1 + 1.0))], [(1.12, 1.12)] * 2, ref=V((1, 0, 0)), seg=16, caps=False)
    rim = b.new_faces(barrel)
    for f in rim:
        for v in f.verts:
            v.co.z = max(v.co.z, WZ1 + 0.98)
    for f in rim:
        b.paint([f], "Build", rnd.choice(TILES))
    soft(b, outline_prism(b, arch_outline(dx, WZ1 - 0.35, 1.32, 2.05, 10), front_y - 0.12, front_y + 0.04), WOOD_D, 0.05)
    b.paint(b.new_faces(outline_prism(b, arch_outline(dx, WZ1 - 0.25, 1.02, 1.85, 10), front_y - 0.15, front_y - 0.11)), "Glow", LIGHT)
    for off in (-0.26, 0.26):
        soft(b, cube_at(b, V((dx + off, front_y - 0.17, WZ1 + 0.62)), (0.045, 0.04, 1.66)), WOOD_D, 0.01, 1)
    soft(b, cube_at(b, V((dx, front_y - 0.17, WZ1 + 0.35)), (0.98, 0.04, 0.045)), WOOD_D, 0.01, 1)
    soft(b, cube_at(b, V((dx, front_y - 0.2, WZ1 - 0.45)), (1.6, 0.34, 0.12)), WOOD_D, 0.03)
    for k in range(5):
        clump(b, V((dx - 0.6 + k * 0.3, front_y - 0.3, WZ1 - 0.3)), 0.09, 1, rnd, FLOWERS[k % len(FLOWERS)], "Build", 1.0)
    # --- the turret: a round tower with its own taller bell roof and a round window ---------------
    tc = V((2.05, -1.15, 0))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [tc + V((0, 0, 0.0)), tc + V((0, 0, 0.55))], [(1.12, 1.12)] * 2, seg=16)), "Build", STONES[3])
    tw = b.new_faces(lambda: rk.tube(b.bm, [tc + V((0, 0, 0.5)), tc + V((0, 0, 4.6))], [(0.98, 0.98), (0.9, 0.9)], seg=16))
    b.gradient(tw, WALL_LO, WALL_HI)
    bell(tc, 0.95, 0.95, 4.6, 3.5, 1.38, 9)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [tc + V((0, 0, 8.02)), tc + V((0, 0, 8.35))], [(0.05, 0.05), (0.02, 0.02)], seg=5)), "Build", WOOD_D)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, tc + V((0, 0, 8.38)), (0.09, 0.09, 0.09), 6, 4)), "Glow", LIGHT)
    a = -1.95
    out = V((math.cos(a), math.sin(a), 0))
    wp = tc + out * 0.94 + V((0, 0, 3.05))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [wp - out * 0.04, wp + out * 0.12], [(0.4, 0.4)] * 2, ref=V((0, 0, 1)), seg=14)), "Build", WOOD_D)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [wp + out * 0.1, wp + out * 0.14], [(0.3, 0.3)] * 2, ref=V((0, 0, 1)), seg=14)), "Glow", LIGHT)
    side = V((-out.y, out.x, 0))
    beam(b, wp + out * 0.15 - V((0, 0, 0.3)), wp + out * 0.15 + V((0, 0, 0.3)), 0.025, WOOD_D)
    beam(b, wp + out * 0.15 - side * 0.3, wp + out * 0.15 + side * 0.3, 0.025, WOOD_D)
    # --- the door: arched, under a shell-shaped canopy, a lantern hanging beside it -----------------
    dp, dn = on_oval(dx, 1.4)
    door_y = dp.y - 0.02
    soft(b, outline_prism(b, arch_outline(dx, WZ0 - 0.05, 1.3, 2.2, 10), door_y - 0.1, door_y + 0.12), WOOD_D, 0.05)
    soft(b, outline_prism(b, arch_outline(dx, WZ0 - 0.05, 1.02, 2.05, 10), door_y - 0.14, door_y - 0.09), DOOR, 0.03)
    for off in (-0.25, 0.25):
        soft(b, cube_at(b, V((dx + off, door_y - 0.155, 1.3)), (0.035, 0.03, 1.6)), (0.52, 0.24, 0.19), 0.008, 1)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((dx + 0.3, door_y - 0.19, 1.35)), (0.055, 0.04, 0.055), 6, 4)), "Build", (0.95, 0.78, 0.42))
    shell = b.new_faces(lambda: rk.blob(b.bm, V((dx, door_y - 0.3, 2.62)), (0.95, 0.62, 0.42), 12, 8, keep=lambda q: q.z >= 2.6 and q.y <= door_y + 0.1))
    for f in shell:
        b.paint([f], "Build", rnd.choice(TILES))
    beam(b, V((dx + 0.78, door_y - 0.05, 2.35)), V((dx + 0.78, door_y - 0.45, 2.35)), 0.03, WOOD_D)
    beam(b, V((dx + 0.78, door_y - 0.45, 2.35)), V((dx + 0.78, door_y - 0.45, 2.1)), 0.012, (0.25, 0.22, 0.2))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((dx + 0.78, door_y - 0.45, 2.1)), V((dx + 0.78, door_y - 0.45, 1.84))], [(0.11, 0.11), (0.09, 0.09)], seg=8)), "Glow", LIGHT)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((dx + 0.78, door_y - 0.45, 2.1)), V((dx + 0.78, door_y - 0.45, 2.2))], [(0.13, 0.13), (0.03, 0.03)], seg=8)), "Build", WOOD_D)
    # --- an oval window left of the door, with a flower pot under it ---------------------------------
    wp2, wn2 = on_oval(-1.45, 1.55)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [wp2 - wn2 * 0.05, wp2 + wn2 * 0.12], [(0.36, 0.5)] * 2, ref=V((-wn2.y, wn2.x, 0)), seg=14)), "Build", WOOD_D)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [wp2 + wn2 * 0.1, wp2 + wn2 * 0.14], [(0.26, 0.39)] * 2, ref=V((-wn2.y, wn2.x, 0)), seg=14)), "Glow", LIGHT)
    beam(b, wp2 + wn2 * 0.15 - V((0, 0, 0.38)), wp2 + wn2 * 0.15 + V((0, 0, 0.38)), 0.022, WOOD_D)
    for x, y in ((dx - 0.95, door_y - 0.35), (dx + 1.2, door_y - 0.3)):
        b.paint(b.new_faces(lambda x=x, y=y: rk.tube(b.bm, [V((x, y, 0.4)), V((x, y, 0.72))], [(0.17, 0.17), (0.21, 0.21)], seg=10)), "Build", (0.76, 0.46, 0.33))
        clump(b, V((x, y, 0.86)), 0.22, 1, rnd, (0.42, 0.62, 0.3), "Build", 0.85)
        clump(b, V((x + 0.05, y - 0.08, 1.02)), 0.07, 1, rnd, rnd.choice(FLOWERS), "Build", 1.0)
    # --- a curving stone chimney hugging the left side ------------------------------------------------
    cpts = [V((-RX - 0.12, 0.35, 0.3)), V((-RX - 0.22, 0.35, 2.0)), V((-RX * 0.93 - 0.12, 0.38, 4.0)), V((-RX * 0.72, 0.42, 6.3))]
    ch = b.new_faces(lambda: rk.tube(b.bm, cpts, [(0.46, 0.5), (0.4, 0.44), (0.34, 0.36), (0.3, 0.3)], ref=V((0, 1, 0)), seg=8))
    b.gradient(ch, STONES[3], STONES[2])
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [cpts[-1], cpts[-1] + V((0, 0, 0.16))], [(0.4, 0.4)] * 2, seg=8)), "Build", STONES[1])
    # --- stepping stones curving to the door, and a low curved flower-bed wall ------------------------
    for i in range(4):
        t = i / 3
        x = dx + math.sin(t * 2.2) * 0.9
        y = door_y - 0.95 - i * 0.78
        soft(b, cube_at(b, V((x, y, 0.03)), (0.8 - i * 0.04, 0.56, 0.12), Euler((0, 0, 0.4 * math.sin(i * 1.7)))), rnd.choice(STONES), 0.06)
    for i in range(9):
        a = math.pi * (0.62 + i * 0.075)
        p = V((-1.1 + math.cos(a) * 1.9, -RY - 0.6 + math.sin(a) * 1.3 - 0.9, 0.18))
        clump(b, p, 0.2, 1, rnd, rnd.choice(STONES), "Build", 0.8)
    for i in range(7):
        clump(b, V((-2.3 + i * 0.28, -RY - 1.05 - (i % 2) * 0.2, 0.28)), 0.14, 1, rnd, rnd.choice([(0.42, 0.62, 0.3)] + FLOWERS), "Build", 0.9)
    return b


def _grid_shell(b, fn, nu, nv, thick, colorize, rim):
    """A thick shell from a parametric surface fn(u, v) -> Vector (u, v in 0..1); colorize(face,
    u, v) paints each face (called with the face's centre parameters)."""
    bm = b.bm
    grid = [[bm.verts.new(fn(i / nu, j / nv)) for j in range(nv + 1)] for i in range(nu + 1)]
    faces, params = [], []
    for i in range(nu):
        for j in range(nv):
            faces.append(bm.faces.new([grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]))
            params.append(((i + 0.5) / nu, (j + 0.5) / nv))
    for f in faces:
        f.normal_update()
    if sum(f.normal.z for f in faces) < 0:
        bmesh.ops.reverse_faces(bm, faces=faces)
    before = set(bm.faces)
    bmesh.ops.solidify(bm, geom=faces, thickness=thick)
    extra = [f for f in bm.faces if f not in before]
    b.paint(extra, "Build", rim)                    # the underside and edges of the shell
    for f, (u, v) in zip(faces, params):
        colorize(f, u, v)


def lantern_house():
    """A warm plaster cottage under a steep flared hip roof in terracotta tile rows that opens at the
    top into a glass lantern cupola glowing gold (each home keeps its own light). A round-columned
    porch with a curved roof, an arched door with a round window, two arched windows set close to
    the door, a stone chimney, stepping stones. Faces -Y."""
    b = Builder(["Build", "Glow"])
    WALL_LO, WALL_HI = (0.86, 0.76, 0.62), (0.98, 0.93, 0.83)
    STONE = [(0.72, 0.67, 0.6), (0.66, 0.61, 0.55), (0.78, 0.72, 0.64)]
    TILE = [(0.72, 0.36, 0.27), (0.78, 0.42, 0.3), (0.67, 0.33, 0.25)]
    WOOD_D = (0.4, 0.27, 0.19)
    GOLD = (0.95, 0.74, 0.34)
    LIGHT = (1.0, 0.8, 0.44)
    CORE = (1.0, 0.72, 0.3)
    W, D, H = 4.6, 4.2, 3.2                      # body width, depth, wall height (from 0.45)
    Z0 = 0.45
    # Footing and the rounded body (a box with big soft corners), warm plaster fading darker below.
    soft(b, cube_at(b, V((0, 0, 0.22)), (W + 0.5, D + 0.5, 0.45)), STONE[1], 0.12, 2)
    def rounded_box():
        geom = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in geom["verts"]:
            v.co = V((v.co.x * W, v.co.y * D, v.co.z * H)) + V((0, 0, Z0 + H / 2))
        verts = geom["verts"]
        edges = list({e for v in verts for e in v.link_edges if abs(e.verts[0].co.z - e.verts[1].co.z) > H * 0.9})
        bmesh.ops.bevel(b.bm, geom=edges, offset=0.55, segments=4, profile=0.5, affect="EDGES", clamp_overlap=True)
    walls = b.new_faces(rounded_box)
    b.gradient(walls, WALL_LO, WALL_HI)
    # Roof: a steep hip roof, flared at the eaves, stopping at a ring where the lantern stands.
    RT = Z0 + H - 0.15                            # roof starts
    RH = 3.4                                      # roof height up to the lantern ring
    OX, OY = W / 2 + 0.75, D / 2 + 0.75            # eave half-extents
    TOP = 0.62                                    # lantern ring half-size
    def roof_pt(u, v):
        # u runs round the four sides (0..1), v from eave (0) to the lantern ring (1).
        a = u * math.tau
        c, s = math.cos(a), math.sin(a)
        m = max(abs(c), abs(s))                   # square-ish outline
        k = (1 - v) ** 1.35                       # concave: the eaves flare
        rx = TOP + (OX - TOP) * k
        ry = TOP + (OY - TOP) * k
        corner = 1.0 + 0.06 * (1 - v) * (1 - abs(abs(c) - abs(s)))   # corners lift a touch
        return V((c / m * rx, s / m * ry, RT + v * RH + 0.18 * (1 - v) ** 3 * corner))
    def tiles(f, u, v):
        row = int(v * 9)
        base = TILE[row % len(TILE)]
        k = 1.0 + rnd.uniform(-0.04, 0.04) + v * 0.06
        b.paint([f], "Build", tuple(min(1.0, c * k) for c in base))
    _grid_shell(b, roof_pt, 32, 9, 0.24, tiles, TILE[2])
    # The lantern cupola: a gold ring, glowing glass panes between slim posts, a small bell cap.
    lz = RT + RH
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, lz - 0.1)), V((0, 0, lz + 0.12))], [(TOP + 0.18, TOP + 0.18)] * 2, seg=8)), "Build", GOLD)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, lz + 0.1)), V((0, 0, lz + 1.15))], [(TOP * 0.92, TOP * 0.92), (TOP * 0.86, TOP * 0.86)], seg=8)), "Glow", CORE)
    for k in range(8):
        a = (k + 0.5) * math.tau / 8
        p = V((math.cos(a) * TOP * 0.95, math.sin(a) * TOP * 0.95, 0))
        beam(b, p + V((0, 0, lz + 0.1)), p * 0.93 + V((0, 0, lz + 1.17)), 0.045, WOOD_D)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, lz + 1.12)), V((0, 0, lz + 1.26)), V((0, 0, lz + 1.95))],
                                        [(TOP + 0.26, TOP + 0.26), (TOP + 0.2, TOP + 0.2), (0.04, 0.04)], seg=8)), "Build", TILE[0])
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, lz + 1.9)), V((0, 0, lz + 2.3))], [(0.035, 0.035), (0.02, 0.02)], seg=5)), "Build", GOLD)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0, 0, lz + 2.34)), (0.08, 0.08, 0.08), 6, 4)), "Build", GOLD)
    # Porch: two round columns, a curved roof, the door with a round window, a step.
    fy = -D / 2
    for x in (-1.05, 1.05):
        b.paint(b.new_faces(lambda x=x: rk.tube(b.bm, [V((x, fy - 1.15, 0.3)), V((x, fy - 1.15, 0.5)), V((x, fy - 1.15, 2.45)), V((x, fy - 1.15, 2.6))],
                                                [(0.17, 0.17), (0.13, 0.13), (0.12, 0.12), (0.17, 0.17)], seg=10)), "Build", WALL_HI)
    _grid_shell(b, lambda u, v: V(((u - 0.5) * 3.0, fy - 1.55 + v * 1.6, 2.62 + math.sin(u * math.pi) * 0.42 + v * 0.22)), 10, 2, 0.16,
                lambda f, u, v: b.paint([f], "Build", TILE[int(u * 10) % 3]), TILE[2])
    soft(b, cube_at(b, V((0, fy - 0.7, 0.4)), (2.8, 1.6, 0.14)), STONE[0], 0.06)
    soft(b, cube_at(b, V((0, fy - 1.7, 0.2)), (1.6, 0.5, 0.16)), STONE[2], 0.05)
    soft(b, outline_prism(b, arch_outline(0, Z0, 1.25, 2.1, 10), fy - 0.08, fy + 0.1), WOOD_D, 0.05)
    soft(b, outline_prism(b, arch_outline(0, Z0, 0.98, 1.95, 10), fy - 0.12, fy - 0.07), (0.3, 0.44, 0.5), 0.03)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, fy - 0.12, Z0 + 1.45)), V((0, fy - 0.16, Z0 + 1.45))], [(0.2, 0.2)] * 2, ref=V((1, 0, 0)), seg=12)), "Glow", LIGHT)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0.32, fy - 0.17, Z0 + 0.95)), (0.05, 0.035, 0.05), 6, 4)), "Build", GOLD)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, fy - 1.15, 2.55)), V((0, fy - 1.15, 2.3))], [(0.012, 0.012)] * 2, seg=4)), "Build", WOOD_D)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, fy - 1.15, 2.3)), V((0, fy - 1.15, 2.05))], [(0.12, 0.12), (0.1, 0.1)], seg=8)), "Glow", LIGHT)
    # Two arched windows close beside the porch, with flower boxes.
    for x in (-1.65, 1.65):
        soft(b, outline_prism(b, arch_outline(x, 1.35, 0.8, 1.3, 8), fy - 0.08, fy + 0.1), WOOD_D, 0.04)
        b.paint(b.new_faces(outline_prism(b, arch_outline(x, 1.43, 0.58, 1.12, 8), fy - 0.11, fy - 0.07)), "Glow", LIGHT)
        soft(b, cube_at(b, V((x, fy - 0.12, 1.95)), (0.035, 0.03, 1.05)), WOOD_D, 0.008, 1)
        soft(b, cube_at(b, V((x, fy - 0.2, 1.25)), (0.9, 0.3, 0.2)), WOOD_D, 0.03)
        for k in range(4):
            clump(b, V((x - 0.3 + k * 0.2, fy - 0.24, 1.4)), 0.08, 1, rnd, FLOWERS[k % len(FLOWERS)], "Build", 1.0)
    # A stone chimney through the back slope, and stepping stones to the porch.
    ch = b.new_faces(lambda: rk.tube(b.bm, [V((1.35, 1.1, 3.4)), V((1.35, 1.1, 6.1))], [(0.34, 0.34), (0.3, 0.3)], seg=8))
    b.gradient(ch, STONE[1], STONE[2])
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((1.35, 1.1, 6.1)), V((1.35, 1.1, 6.25))], [(0.42, 0.42)] * 2, seg=8)), "Build", STONE[0])
    for i in range(3):
        soft(b, cube_at(b, V((0.2 * math.sin(i * 1.8), fy - 2.5 - i * 0.8, 0.03)), (0.78, 0.55, 0.12), Euler((0, 0, 0.35 * math.sin(i * 1.3)))), rnd.choice(STONE), 0.06)
    for x, y in ((-2.2, fy - 0.35), (2.25, fy - 0.3), (-2.4, 0.8)):
        clump(b, V((x, y, 0.3)), 0.28, 1, rnd, (0.42, 0.62, 0.3), "Build", 0.7)
    return b


def hull_house():
    """A stone cottage roofed with an upturned boat hull, turned side-on so the camera sees the
    boat's profile: plank rows in two woods, a keel along the top, the prow rising on the right with
    a ship lantern hanging from it, the square stern on the left. A round painted door and brass
    portholes on the long front, a plank porch with rope rails, a stovepipe. Faces -Y."""
    b = Builder(["Build", "Glow"])
    WALL_LO, WALL_HI = (0.8, 0.78, 0.74), (0.95, 0.94, 0.91)
    PLANK = [(0.6, 0.4, 0.26), (0.68, 0.46, 0.3)]
    RIB = (0.46, 0.31, 0.21)
    KEEL = (0.38, 0.26, 0.18)
    BRASS = (0.93, 0.74, 0.36)
    DOOR = (0.26, 0.47, 0.54)
    LIGHT = (1.0, 0.8, 0.46)
    STONE = [(0.7, 0.68, 0.64), (0.62, 0.61, 0.58)]
    HW, L, WH = 2.2, 6.6, 2.1                      # half-depth, length (along X), wall height
    ZB = 0.4 + WH - 0.25
    # Walls: whitewashed stone, rounded corners, on a low footing. Long axis along X.
    soft(b, cube_at(b, V((-0.2, 0, 0.2)), (L + 0.2, HW * 2 + 0.5, 0.4)), STONE[1], 0.1, 2)
    def walls():
        geom = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in geom["verts"]:
            v.co = V((v.co.x * (L - 0.7), v.co.y * HW * 2, v.co.z * WH)) + V((-0.25, 0, 0.4 + WH / 2))
        edges = list({e for v in geom["verts"] for e in v.link_edges if abs(e.verts[0].co.z - e.verts[1].co.z) > WH * 0.9})
        bmesh.ops.bevel(b.bm, geom=edges, offset=0.4, segments=3, profile=0.5, affect="EDGES", clamp_overlap=True)
    b.gradient(b.new_faces(walls), WALL_LO, WALL_HI)
    # The hull: stations along X (u 0 = prow tip on the right, 1 = stern on the left), each a
    # round-bottomed arch over the top (v 0..1 from front to back).
    def hull_pt(u, v):
        x = L / 2 + 0.7 - u * (L + 1.0)
        bow = max(0.0, 1 - u / 0.3)
        width = (HW + 0.45) * (1 - bow ** 1.8)
        sheer = 1.0 * bow ** 2.0 + 0.25 * max(0.0, u - 0.85) / 0.15   # prow rises; stern lifts a touch
        a = math.pi * v
        y = -math.cos(a) * width
        z = ZB + sheer + math.sin(a) * (2.2 * (1 - 0.4 * bow)) - 0.2 * bow
        return V((x + 0.55 * bow ** 2, y, z))
    def planks(f, u, v):
        base = PLANK[int(v * 12) % 2]
        k = 1.0 + rnd.uniform(-0.03, 0.03)
        b.paint([f], "Build", tuple(min(1.0, c * k) for c in base))
    _grid_shell(b, hull_pt, 26, 12, 0.2, planks, KEEL)
    keel = [hull_pt(k / 18, 0.5) + V((0, 0, 0.1)) for k in range(19)]
    b.paint(b.new_faces(lambda: rk.tube(b.bm, keel, [(0.08, 0.1)] * len(keel), ref=V((0, 1, 0)), seg=6)), "Build", KEEL)
    for u in (0.4, 0.62, 0.84):                        # a few ribs, slim and warm
        rib = [hull_pt(u, t / 10) for t in range(11)]
        c = V((rib[5].x, 0, ZB))
        rib = [p + (p - V((p.x, 0, ZB))).normalized() * 0.1 for p in rib]
        b.paint(b.new_faces(lambda rib=rib: rk.tube(b.bm, rib, [(0.05, 0.06)] * len(rib), ref=V((1, 0, 0)), seg=4)), "Build", RIB)
    # End walls: whitewashed arches under the prow and the stern, each with a porthole.
    def end_wall(x0, x1):
        arch = [(math.cos(math.pi * t / 12) * HW * 0.96, ZB - 0.1 + math.sin(math.pi * t / 12) * 1.75) for t in range(13)]
        pts = [(HW * 0.96, 0.4)] + arch + [(-HW * 0.96, 0.4)]
        def make():
            bm = b.bm
            fa = [bm.verts.new(V((x0, y, z))) for y, z in pts]
            fb = [bm.verts.new(V((x1, y, z))) for y, z in pts]
            bm.faces.new(fa)
            bm.faces.new(list(reversed(fb)))
            for i in range(len(pts)):
                j = (i + 1) % len(pts)
                bm.faces.new((fa[j], fa[i], fb[i], fb[j]))
        b.gradient(b.new_faces(make), WALL_LO, WALL_HI)
    end_wall(L / 2 - 0.62, L / 2 - 0.2)
    end_wall(-L / 2 - 0.3, -L / 2 + 0.1)
    def porthole(p, out, r):
        ref = V((0, 0, 1))
        b.paint(b.new_faces(lambda: rk.tube(b.bm, [p - out * 0.05, p + out * 0.12], [(r, r)] * 2, ref=ref, seg=14)), "Build", BRASS)
        b.paint(b.new_faces(lambda: rk.tube(b.bm, [p + out * 0.1, p + out * 0.14], [(r * 0.72, r * 0.72)] * 2, ref=ref, seg=14)), "Glow", LIGHT)
    porthole(V((L / 2 - 0.2, 0, 2.3)), V((1, 0, 0)), 0.3)
    porthole(V((-L / 2 - 0.3, 0, 2.3)), V((-1, 0, 0)), 0.3)
    # The long front: a round painted door with brass handle, portholes either side.
    fy = -HW - 0.02
    dx = -0.35
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((dx, fy + 0.05, 1.45)), V((dx, fy - 0.1, 1.45))], [(0.92, 0.92)] * 2, ref=V((1, 0, 0)), seg=18)), "Build", KEEL)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((dx, fy - 0.1, 1.45)), V((dx, fy - 0.16, 1.45))], [(0.78, 0.78)] * 2, ref=V((1, 0, 0)), seg=18)), "Build", DOOR)
    for d in (V((0.78, 0, 0)), V((0, 0, 0.78))):
        b.paint(b.new_faces(lambda d=d: rk.tube(b.bm, [V((dx, fy - 0.17, 1.45)) - d, V((dx, fy - 0.17, 1.45)) + d], [(0.035, 0.035)] * 2, seg=4)), "Build", (0.2, 0.36, 0.42))
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((dx + 0.45, fy - 0.2, 1.35)), (0.06, 0.04, 0.06), 6, 4)), "Build", BRASS)
    for x in (dx - 1.75, dx + 1.75, dx + 3.1):
        porthole(V((x, fy, 1.7)), V((0, -1, 0)), 0.3)
    # The ship lantern hanging from the prow tip.
    tip = hull_pt(0.0, 0.5)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [tip, tip + V((0, 0, -0.6))], [(0.012, 0.012)] * 2, seg=4)), "Build", KEEL)
    lp = tip + V((0, 0, -0.6))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [lp, lp + V((0, 0, -0.34))], [(0.14, 0.14), (0.12, 0.12)], seg=8)), "Glow", LIGHT)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [lp + V((0, 0, 0.06)), lp + V((0, 0, -0.02))], [(0.16, 0.16), (0.1, 0.1)], seg=8)), "Build", BRASS)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [lp + V((0, 0, -0.34)), lp + V((0, 0, -0.4))], [(0.13, 0.13), (0.06, 0.06)], seg=8)), "Build", BRASS)
    # Plank porch along the front, posts with rope rails at its ends, a barrel and a coil of rope.
    for i in range(6):
        soft(b, cube_at(b, V((dx, fy - 0.25 - i * 0.24, 0.42)), (3.4, 0.22, 0.08)), PLANK[i % 2], 0.02, 1)
    for x in (dx - 1.75, dx + 1.75):
        for y in (fy - 0.15, fy - 1.45):
            b.paint(b.new_faces(lambda x=x, y=y: rk.tube(b.bm, [V((x, y, 0.0)), V((x, y, 1.1))], [(0.08, 0.08)] * 2, seg=6)), "Build", KEEL)
        rope = [V((x, fy - 0.15 - t * 1.3 / 8, 0.98 - math.sin(t / 8 * math.pi) * 0.13)) for t in range(9)]
        b.paint(b.new_faces(lambda rope=rope: rk.tube(b.bm, rope, [(0.025, 0.025)] * len(rope), seg=4)), "Build", (0.82, 0.72, 0.52))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((dx + 2.3, fy - 0.5, 0.0)), V((dx + 2.3, fy - 0.5, 0.42)), V((dx + 2.3, fy - 0.5, 0.84))],
                                        [(0.26, 0.26), (0.3, 0.3), (0.26, 0.26)], seg=10)), "Build", PLANK[0])
    ring = [V((dx - 2.3 + math.cos(t / 10 * math.tau) * 0.24, fy - 0.55 + math.sin(t / 10 * math.tau) * 0.24, 0.1)) for t in range(10)]
    b.paint(b.new_faces(lambda: rk.tube(b.bm, ring, [(0.07, 0.07)] * 10, ref=V((0, 0, 1)), seg=5, closed=True)), "Build", (0.82, 0.72, 0.52))
    for i in range(3):
        soft(b, cube_at(b, V((dx + 0.15 * math.sin(i * 2.0), fy - 2.0 - i * 0.8, 0.03)), (0.8, 0.55, 0.12), Euler((0, 0, 0.3 * math.sin(i * 1.4)))), rnd.choice(STONE), 0.06)
    # A black stovepipe through the hull, towards the stern.
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((-2.0, 0.6, 3.2)), V((-2.0, 0.6, 5.4))], [(0.14, 0.14)] * 2, seg=8)), "Build", (0.18, 0.18, 0.2))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((-2.0, 0.6, 5.4)), V((-2.0, 0.6, 5.55))], [(0.24, 0.24), (0.14, 0.14)], seg=8)), "Build", (0.18, 0.18, 0.2))
    return b


def skep_cottage():
    """Meadow: a home shaped like an old straw beehive (a skep): a tall dome of fat stacked straw coils,
    honey-gold light glowing from a hex window up high, a round door under a swooping wooden hood on a
    little plank porch with honey pots, flower boxes under round windows, a lantern, and a stack of
    painted hive boxes beside it. Faces -Y."""
    b = Builder(["Build", "Glow"])
    COIL = [(0.93, 0.76, 0.42), (0.86, 0.68, 0.35), (0.9, 0.72, 0.38), (0.82, 0.63, 0.31)]
    HONEY = (1.0, 0.72, 0.28)
    WOOD_W = (0.6, 0.4, 0.25)
    WOOD_D = (0.4, 0.27, 0.19)
    STONE_L = [(0.72, 0.7, 0.66), (0.64, 0.62, 0.58)]
    R, TOP, COILS = 2.9, 6.0, 8
    def radius(z):                                  # the skep's bell: steep sides, round top
        t = min(max(z / TOP, 0.0), 1.0)
        return R * (1.0 - t ** 2.2) ** 0.55 + 0.05
    for k in range(10):                             # a ring of footing stones
        a = k * math.tau / 10
        soft(b, cube_at(b, V((math.cos(a) * 2.75, math.sin(a) * 2.75, 0.15)), (1.1, 0.8, 0.4), Euler((0, 0, a))), STONE_L[k % 2], 0.08)
    # The dome: one tube up the middle, bulging per coil so the straw rings read clearly.
    pts, radii = [], []
    steps = COILS * 4
    for i in range(steps + 1):
        z = 0.3 + (TOP - 0.3) * i / steps
        bulge = 0.16 * math.sin(math.pi * (i % 4) / 4) if i < steps - 2 else 0.0
        r = radius(z - 0.3) + bulge
        pts.append(V((0, 0, z)))
        radii.append((max(r, 0.05), max(r, 0.05)))
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, radii, ref=V((1, 0, 0)), seg=20))
    for f in faces:
        z = f.calc_center_median().z
        b.paint([f], "Build", COIL[int((z - 0.3) / ((TOP - 0.3) / COILS)) % len(COIL)])
    # A wooden knob and a little crooked chimney on top.
    soft(b, lambda: rk.tube(b.bm, [V((0, 0, TOP - 0.05)), V((0, 0, TOP + 0.35)), V((0, 0, TOP + 0.55))], [(0.3, 0.3), (0.22, 0.22), (0.05, 0.05)], seg=8), WOOD_D, 0.03)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((1.0, 0.6, 4.6)), V((1.15, 0.7, 6.1)), V((1.05, 0.75, 6.5))], [(0.2, 0.2), (0.18, 0.18), (0.22, 0.22)], seg=7)), "Build", STONE_L[0])
    # Front: a swooping wooden hood over a round door, on a plank porch.
    fy = -radius(0.9) - 0.1
    round_door(b, 0, fy, 0.45, 1.0, 1.85)
    def hood():
        bm = b.bm
        nu, nv = 8, 3
        grid = []
        for i in range(nu + 1):
            u = i / nu
            row = []
            for j in range(nv + 1):
                v = j / nv
                x = (u - 0.5) * 2.4
                y = fy - 0.1 - v * 1.1
                z = 2.75 - v * 0.45 + 0.35 * (abs(u - 0.5) * 2) ** 2 - 0.25 * math.sin(math.pi * u) * v
                row.append(bm.verts.new(V((x, y, z))))
            grid.append(row)
        fs = []
        for i in range(nu):
            for j in range(nv):
                fs.append(bm.faces.new([grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]))
        for f in fs:
            f.normal_update()
        if sum(f.normal.z for f in fs) < 0:
            bmesh.ops.reverse_faces(bm, faces=fs)
        bmesh.ops.solidify(bm, geom=fs, thickness=0.12)
    b.paint(b.new_faces(hood), "Build", WOOD_W)
    for x in (-1.05, 1.05):
        soft(b, cube_at(b, V((x, fy - 1.1, 1.35)), (0.14, 0.14, 2.3)), WOOD_D, 0.03)
    soft(b, cube_at(b, V((0, fy - 0.8, 0.32)), (2.8, 1.8, 0.14)), WOOD_W, 0.03)
    for i in range(2):
        soft(b, cube_at(b, V((0, fy - 1.9 - i * 0.35, 0.18 - i * 0.12)), (1.4, 0.35, 0.12)), WOOD_D, 0.03)
    for x, h in ((-0.8, 0.35), (-0.55, 0.28), (0.85, 0.32)):   # honey pots on the porch
        b.paint(b.new_faces(lambda x=x, h=h: rk.tube(b.bm, [V((x, fy - 1.3, 0.4)), V((x, fy - 1.3, 0.4 + h * 0.5)), V((x, fy - 1.3, 0.4 + h))],
                                                     [(0.13, 0.13), (0.17, 0.17), (0.09, 0.09)], seg=8)), "Build", (0.85, 0.55, 0.3))
        b.paint(b.new_faces(lambda x=x, h=h: rk.blob(b.bm, V((x, fy - 1.3, 0.42 + h)), (0.1, 0.1, 0.04), 8, 2)), "Glow", HONEY)
    # A lantern on the right post, round windows with flower boxes, and the glowing hex window up top.
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((1.05, fy - 1.25, 2.05)), (0.12, 0.12, 0.16), 6, 4)), "Glow", HONEY)
    for a, z in ((-2.15, 1.55), (-0.95, 1.55)):
        out = V((math.cos(a), math.sin(a), 0))
        round_window(b, out * (radius(z - 0.3) - 0.02) + V((0, 0, z)), out, 0.36, True)
    zh = 3.9
    hex_window(b, V((0, -radius(zh - 0.3) + 0.02, zh)), V((0, -1, 0)), 0.42, HONEY)
    # Painted hive boxes stacked beside the house, and a few flowers.
    for i, c in enumerate(((0.95, 0.9, 0.78), (0.95, 0.78, 0.4), (0.62, 0.78, 0.8))):
        soft(b, cube_at(b, V((3.4, -0.8, 0.3 + i * 0.46)), (0.8, 0.8, 0.42), Euler((0, 0, 0.1 * i))), c, 0.04)
    soft(b, cube_at(b, V((3.4, -0.8, 1.72)), (1.0, 1.0, 0.1)), WOOD_D, 0.03)
    for k in range(7):
        a = -1.9 + k * 0.28
        clump(b, V((math.cos(a) * 3.3, math.sin(a) * 3.3, 0.25)), 0.14, 1, rnd, rnd.choice(FLOWERS), "Build", 0.9)
    return b


def stump_house():
    """Forest: a home inside a colossal old tree stump. The flared trunk in faceted bark strips with
    great roots sprawling into the ground; the cut top is capped by a steep mossy shingle roof with a
    crooked chimney; a round yellow door between two roots, round lit windows, shelf-fungus steps
    spiralling up to a little balcony, a branch holding a lantern, and red mushrooms. Faces -Y."""
    b = Builder(["Build", "Glow"])
    BARK = [(0.66, 0.48, 0.34), (0.72, 0.53, 0.37), (0.6, 0.43, 0.3), (0.76, 0.57, 0.4)]
    CUT = (0.82, 0.66, 0.44)
    SHROOM = (0.95, 0.82, 0.6)
    SHINGLE_M = [(0.36, 0.5, 0.3), (0.42, 0.56, 0.32), (0.32, 0.45, 0.28)]
    WOOD_D = (0.36, 0.24, 0.17)
    DOOR = (0.95, 0.76, 0.3)
    LIGHT = (1.0, 0.78, 0.42)
    TOP = 4.6
    def radius(z):
        return 2.0 + 1.3 * math.exp(-z * 1.5)
    pts = [V((0, 0, z)) for z in (0.0, 0.25, 0.6, 1.0, 1.6, 2.4, 3.3, 4.2, TOP)]
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, [(radius(p.z), radius(p.z)) for p in pts], ref=V((1, 0, 0)), seg=16))
    for f in faces:                                 # vertical bark strips
        c = f.calc_center_median()
        k = int((math.atan2(c.y, c.x) + math.pi) / math.tau * 16)
        b.paint([f], "Build", BARK[k % len(BARK)])
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, TOP)), V((0, 0, TOP + 0.08))], [(radius(TOP) + 0.05,) * 2] * 2, seg=16)), "Build", CUT)
    # Roots: sprawling out and down, leaving the front clear for the door.
    for k in range(9):
        a = -math.pi / 2 + 0.55 + k * (math.tau - 1.1) / 8
        d = V((math.cos(a), math.sin(a), 0))
        root = [d * 2.4 + V((0, 0, 1.1)), d * 3.3 + V((0, 0, 0.45)), d * 4.2 + V((0, 0, 0.1)), d * 4.9 + V((0, 0, -0.1))]
        faces = b.new_faces(lambda root=root: rk.tube(b.bm, root, [(0.5, 0.42), (0.38, 0.32), (0.24, 0.2), (0.08, 0.08)], ref=V((0, 0, 1)), seg=7))
        b.paint(faces, "Build", BARK[k % len(BARK)])
    # A steep cone roof in mossy shingle rows, with an overhang and a crooked stone chimney.
    rows = 6
    for i in range(rows):
        z0 = TOP + 0.05 + i * 0.42
        r0 = radius(TOP) + 0.55 - i * 0.44
        r1 = r0 - 0.5
        faces = b.new_faces(lambda z0=z0, r0=r0, r1=r1: rk.tube(b.bm, [V((0, 0, z0)), V((0, 0, z0 + 0.14)), V((0, 0, z0 + 0.62))],
                                                                [(r0, r0), (r0 - 0.04, r0 - 0.04), (max(r1, 0.08), max(r1, 0.08))], seg=14))
        b.paint(faces, "Build", SHINGLE_M[i % 3])
    soft(b, lambda: rk.tube(b.bm, [V((0, 0, TOP + 2.6)), V((0, 0, TOP + 3.1))], [(0.12, 0.12), (0.02, 0.02)], seg=6), WOOD_D, 0.02)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((1.1, 0.7, TOP + 0.5)), V((1.25, 0.8, TOP + 1.9)), V((1.1, 0.9, TOP + 2.4))],
                                        [(0.24, 0.24), (0.22, 0.22), (0.27, 0.27)], seg=7)), "Build", (0.62, 0.6, 0.58))
    # The door: a round yellow door in a dark frame, with stepping stones.
    fy = -radius(1.0) + 0.15
    soft(b, outline_prism(b, arch_outline(0, 0.2, 1.4, 2.1), fy - 0.12, fy + 0.3), WOOD_D, 0.04)
    soft(b, outline_prism(b, arch_outline(0, 0.25, 1.1, 1.9), fy - 0.18, fy - 0.1), DOOR, 0.03)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0.3, fy - 0.22, 1.05)), (0.07, 0.05, 0.07), 6, 4)), "Build", (0.35, 0.3, 0.25))
    for i, (x, y) in enumerate(((0.1, -0.8), (-0.25, -1.6), (0.2, -2.4))):
        soft(b, cube_at(b, V((x, fy + y, 0.05)), (0.8, 0.6, 0.14), Euler((0, 0, 0.3 * i))), (0.6, 0.6, 0.58), 0.08)
    # Round lit windows.
    for a, z, r in ((-2.3, 1.7, 0.38), (-0.75, 2.9, 0.34), (-1.9, 3.7, 0.28)):
        out = V((math.cos(a), math.sin(a), 0))
        p = out * (radius(z) - 0.05) + V((0, 0, z))
        paint(b, b.new_faces(lambda p=p, out=out, r=r: rk.tube(b.bm, [p - out * 0.05, p + out * 0.14], [(r + 0.08, r + 0.08)] * 2, ref=V((0, 0, 1)), seg=12)), WOOD_D, 0.0)
        b.paint(b.new_faces(lambda p=p, out=out, r=r: rk.tube(b.bm, [p + out * 0.14, p + out * 0.17], [(r, r)] * 2, ref=V((0, 0, 1)), seg=12)), "Glow", LIGHT)
    # Shelf-fungus steps spiralling up the right side to a small balcony.
    for i in range(7):
        a = -0.9 + i * 0.32
        z = 0.7 + i * 0.5
        out = V((math.cos(a), math.sin(a), 0))
        c = out * (radius(z) + 0.28) + V((0, 0, z))
        b.paint(b.new_faces(lambda c=c: rk.blob(b.bm, c, (0.45, 0.45, 0.1), 8, 3)), "Build", SHROOM if i % 2 == 0 else (0.92, 0.7, 0.45))
    a = 1.35
    out = V((math.cos(a), math.sin(a), 0))
    deck = out * (radius(4.0) + 0.55) + V((0, 0, 4.0))
    soft(b, cube_at(b, deck, (1.5, 1.2, 0.12), Euler((0, 0, a))), (0.6, 0.42, 0.28), 0.03)
    for s in (-0.6, 0.6):
        side = V((-out.y, out.x, 0))
        soft(b, cube_at(b, deck + out * 0.5 + side * s + V((0, 0, 0.35)), (0.08, 0.08, 0.7)), WOOD_D, 0.02)
    soft(b, cube_at(b, deck + out * 0.5 + V((0, 0, 0.68)), (1.3, 0.08, 0.07), Euler((0, 0, a + math.pi / 2))), WOOD_D, 0.02)
    # A branch reaching out to the left with a hanging lantern.
    br = [V((-radius(3.4) + 0.2, -0.4, 3.4)), V((-3.2, -0.8, 3.8)), V((-3.9, -1.0, 4.3))]
    b.paint(b.new_faces(lambda: rk.tube(b.bm, br, [(0.22, 0.22), (0.14, 0.14), (0.06, 0.06)], ref=V((0, 0, 1)), seg=6)), "Build", BARK[0])
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((-3.4, -0.88, 3.95)), V((-3.4, -0.88, 3.3))], [(0.012, 0.012)] * 2, seg=4)), "Build", (0.2, 0.18, 0.18))
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((-3.4, -0.88, 3.15)), (0.13, 0.13, 0.18), 6, 4)), "Glow", LIGHT)
    # Moss on the roots and red mushrooms at the foot.
    for k in range(10):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(2.6, 3.8)
        clump(b, V((math.cos(a) * d, math.sin(a) * d, 0.25)), 0.22, 1, rnd, rnd.choice(MOSS), "Build", 0.6)
    for k in range(5):
        a = -1.2 + k * 0.5
        p = V((math.cos(a) * 3.0, math.sin(a) * 3.0, 0))
        soft(b, lambda p=p: rk.tube(b.bm, [p, p + V((0, 0, 0.3))], [(0.05, 0.05)] * 2, seg=5), (0.95, 0.92, 0.84), 0.01, 1)
        b.paint(b.new_faces(lambda p=p: rk.blob(b.bm, p + V((0, 0, 0.32)), (0.17, 0.17, 0.09), 8, 3)), "Build", (0.85, 0.2, 0.17))
    return b


if __name__ == "__main__":
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
    export("house_storybook", storybook_cottage(), OUT)
    export("house_turret", turret_cottage(), OUT)
    export("house_lantern", lantern_house(), OUT)
    export("house_hull", hull_house(), OUT)
    export("house_skep", skep_cottage(), OUT)
    export("house_stump", stump_house(), OUT)

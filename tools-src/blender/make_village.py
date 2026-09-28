"""Village houses built from the owner's AI reference pictures (clean low poly, faithful to the pictures):
  house_swoophome: "Large swoop home": warm plank walls under a deep navy hip roof whose faces swoop
                   (flat at the eaves, steep near the peak) and curl up hard at the corners, a front
                   gable over an arched door, a big round glowing window, lanterns, steps, a porch,
                   a round stone chimney with smoke, on a grassy mound with fences and bushes.
  house_market:    "Market stalls round house".
  house_ring:      "Dual ring round house".
Reuses the helpers in make_buildings.py. Front faces -Y (+Z in Godot). Exported to game/assets/buildings/.

Run: blender --background --python tools-src/blender/make_village.py   (or the bpy module in cloud sessions)
"""
import math
import os
import sys
import bpy
import bmesh
from mathutils import Euler, Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, clump, export  # noqa: E402
import make_buildings as mb  # noqa: E402
from make_buildings import soft, cube_at, beam, outline_prism, arch_outline, _grid_shell, barrel, rnd, OUT  # noqa: E402

GLOW = (1.0, 0.76, 0.4)
IRON = (0.2, 0.19, 0.2)


def lantern(b, at, hang=0.0):
    """A little iron lantern with a warm light; `hang` drops it on a short chain."""
    top = at + V((0, 0, hang + 0.2))
    if hang > 0:
        b.paint(b.new_faces(lambda: rk.tube(b.bm, [top, at + V((0, 0, 0.2))], [(0.012, 0.012)] * 2, seg=4)), "Build", IRON)
    soft(b, lambda: rk.tube(b.bm, [at + V((0, 0, 0.14)), at + V((0, 0, 0.26))], [(0.13, 0.13), (0.02, 0.02)], seg=4), IRON, 0.01, 1)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [at + V((0, 0, -0.14)), at + V((0, 0, 0.14))], [(0.09, 0.09)] * 2, seg=4)), "Glow", GLOW)
    soft(b, cube_at(b, at + V((0, 0, -0.16)), (0.2, 0.2, 0.04)), IRON, 0.01, 1)


def grass_mound(b, rx, ry, cy=0.0, h=0.25, seg=28):
    GRASS = [(0.36, 0.56, 0.27), (0.4, 0.61, 0.29), (0.33, 0.52, 0.25)]
    faces = b.new_faces(lambda: rk.tube(b.bm, [V((0, cy, -0.1)), V((0, cy, h * 0.6)), V((0, cy, h))],
                                        [(rx, ry), (rx * 0.97, ry * 0.97), (rx * 0.9, ry * 0.9)], seg=seg))
    for f in faces:
        b.paint([f], "Build", rnd.choice(GRASS))


def fence_run(b, pts, post=(0.1, 0.1, 0.75), color=(0.5, 0.33, 0.21)):
    for p in pts:
        soft(b, cube_at(b, p + V((0, 0, post[2] / 2)), post), color, 0.02, 1)
    for p, q in zip(pts, pts[1:]):
        for z in (0.35, 0.62):
            beam(b, p + V((0, 0, z)), q + V((0, 0, z)), 0.04, (0.6, 0.41, 0.26))


# --- 2. Large swoop home ------------------------------------------------------------------------

def swoop_home():
    b = Builder(["Build", "Glow"])
    TILE = [(0.19, 0.22, 0.38), (0.23, 0.27, 0.44), (0.16, 0.19, 0.34)]
    RIM = (0.3, 0.35, 0.52)
    PLANK = [(0.74, 0.52, 0.33), (0.79, 0.57, 0.36), (0.69, 0.48, 0.3), (0.76, 0.54, 0.34)]
    POST = (0.4, 0.26, 0.17)
    STONE = [(0.62, 0.6, 0.58), (0.55, 0.54, 0.53), (0.68, 0.66, 0.63)]
    W, D, Z0, WALL = 5.6, 4.4, 0.45, 2.5
    TOP = Z0 + WALL
    grass_mound(b, 5.2, 4.3, cy=-0.5)
    soft(b, cube_at(b, V((0, 0, Z0 / 2 + 0.1)), (W + 0.4, D + 0.4, Z0)), STONE[1], 0.07)

    def planks(x0, x1, y, z0, z1, along="x", n=None):
        """A wall of vertical boards between x0..x1 (or y0..y1) at a fixed y (or x)."""
        n = n or max(3, int(abs(x1 - x0) / 0.36))
        w = (x1 - x0) / n
        for i in range(n):
            c = x0 + (i + 0.5) * w
            size = (abs(w) - 0.015, 0.1, z1 - z0) if along == "x" else (0.1, abs(w) - 0.015, z1 - z0)
            p = V((c, y, (z0 + z1) / 2)) if along == "x" else V((y, c, (z0 + z1) / 2))
            soft(b, cube_at(b, p, size), PLANK[(i * 7) % 4], 0.015, 1)
    planks(-W / 2, W / 2, -D / 2, Z0, TOP)
    planks(-W / 2, W / 2, D / 2, Z0, TOP)
    planks(-D / 2, D / 2, -W / 2, Z0, TOP, along="y")
    planks(-D / 2, D / 2, W / 2, Z0, TOP, along="y")
    for x in (-W / 2, W / 2):                                   # corner posts, sill and top beam
        for y in (-D / 2, D / 2):
            soft(b, cube_at(b, V((x, y, (Z0 + TOP) / 2)), (0.26, 0.26, WALL + 0.1)), POST, 0.04)
    for y in (-D / 2 - 0.02, D / 2 + 0.02):
        soft(b, cube_at(b, V((0, y, TOP - 0.1)), (W + 0.2, 0.18, 0.2)), POST, 0.03)
        soft(b, cube_at(b, V((0, y, Z0 + 0.08)), (W + 0.2, 0.16, 0.16)), POST, 0.03)

    # The main roof: a hip roof of four swooping faces meeting at a peak, corners curling up.
    O, EAVE, APEX = 0.85, TOP - 0.12, V((-0.9, 0.4, TOP + 3.4))
    corners = [V((-W / 2 - O, -D / 2 - O, 0)), V((W / 2 + O, -D / 2 - O, 0)), V((W / 2 + O, D / 2 + O, 0)), V((-W / 2 - O, D / 2 + O, 0))]
    for k in range(4):
        A, B = corners[k], corners[(k + 1) % 4]
        def face(u, v, A=A, B=B):
            base = A + (B - A) * u
            v = v * 0.96
            p = base * (1 - v) + V((APEX.x, APEX.y, 0)) * v
            z = EAVE + (APEX.z - EAVE) * v ** 1.75 + 0.95 * abs(2 * u - 1) ** 3 * (1 - v) ** 3
            return V((p.x, p.y, z))
        def colour(f, u, v):
            b.paint([f], "Build", TILE[(int(v * 11) + (1 if int(u * 14) % 5 == 0 else 0)) % 3])
        b.new_faces(lambda face=face, colour=colour: _grid_shell(b, face, 14, 11, 0.2, colour, RIM))
    soft(b, lambda: rk.tube(b.bm, [APEX + V((0, 0, -0.35)), APEX + V((0, 0, 0.1)), APEX + V((0, 0, 0.55))], [(0.18, 0.18), (0.1, 0.1), (0.02, 0.02)], seg=6), RIM, 0.02)

    # Front gable over the door: a bump-out with its own steep swooping roof, the tips curling forward.
    gx, GW, YF = 1.35, 1.55, -D / 2 - 1.0
    for x0, x1, y in ((gx - GW, gx + GW, YF),):
        planks(x0, x1, y, Z0, TOP)
    planks(YF, -D / 2, gx - GW, Z0, TOP, along="y", n=3)
    planks(YF, -D / 2, gx + GW, Z0, TOP, along="y", n=3)
    for x in (gx - GW, gx + GW):
        soft(b, cube_at(b, V((x, YF, (Z0 + TOP) / 2)), (0.24, 0.24, WALL + 0.1)), POST, 0.04)
    soft(b, cube_at(b, V((gx, YF - 0.02, TOP - 0.1)), (2 * GW + 0.2, 0.18, 0.2)), POST, 0.03)
    soft(b, cube_at(b, V((gx, -D / 2 - 0.5, Z0 / 2 + 0.1)), (2 * GW + 0.4, 1.2, Z0)), STONE[0], 0.06)
    RIDGE, GE = TOP + 3.3, TOP - 0.1
    def gable_z(v):
        return GE + (RIDGE - GE) * v ** 1.6
    pts = [(gx - GW * (1 - k / 8), gable_z(k / 8)) for k in range(9)]
    outline = [(gx - GW, TOP - 0.2)] + pts + [(2 * gx - x, z) for x, z in reversed(pts[:-1])] + [(gx + GW, TOP - 0.2)]
    soft(b, outline_prism(b, outline, YF - 0.05, YF + 0.1), PLANK[1], 0.03)
    beam(b, V((gx, YF - 0.08, TOP)), V((gx, YF - 0.08, RIDGE - 0.4)), 0.05, POST)
    for s in (-1, 1):
        beam(b, V((gx, YF - 0.08, TOP + 0.9)), V((gx + s * 0.8, YF - 0.08, TOP + 0.2)), 0.04, POST)
    for s in (-1, 1):
        def gside(u, v, s=s):
            y = YF - 0.9 + (0.4 - (YF - 0.9)) * u
            x = gx + s * (GW + 0.75) * (1 - v * 0.97)
            z = gable_z(v * 0.97) + 0.05 + 1.0 * (1 - u) ** 3 * (1 - v) ** 2.5
            return V((x, y, z))
        def colour(f, u, v):
            b.paint([f], "Build", TILE[int(v * 8) % 3])
        b.new_faces(lambda gside=gside, colour=colour: _grid_shell(b, gside, 8, 8, 0.18, colour, RIM))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((gx, YF - 1.0, RIDGE + 0.02)), V((gx, 0.4, RIDGE + 0.02))], [(0.14, 0.12)] * 2, ref=V((1, 0, 0)), seg=6)), "Build", RIM)
    # A little glowing attic window in the gable.
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((gx, YF - 0.02, TOP + 1.15)), V((gx, YF - 0.16, TOP + 1.15))], [(0.3, 0.3)] * 2, ref=V((1, 0, 0)), seg=10)), "Build", POST)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((gx, YF - 0.16, TOP + 1.15)), V((gx, YF - 0.19, TOP + 1.15))], [(0.22, 0.22)] * 2, ref=V((1, 0, 0)), seg=10)), "Glow", GLOW)

    # The door: an arched plank door in a heavy frame, with studs, and lanterns either side.
    fy = YF - 0.08
    soft(b, outline_prism(b, arch_outline(gx, Z0, 1.45, 2.15), fy - 0.1, fy + 0.06), POST, 0.05)
    soft(b, outline_prism(b, arch_outline(gx, Z0 + 0.05, 1.12, 1.98), fy - 0.14, fy - 0.08), (0.5, 0.31, 0.19), 0.03)
    for x in (gx - 0.28, gx, gx + 0.28):
        beam(b, V((x, fy - 0.16, Z0 + 0.1)), V((x, fy - 0.16, Z0 + 1.7)), 0.018, (0.42, 0.26, 0.16))
    for z in (Z0 + 0.5, Z0 + 1.3):
        for x in (gx - 0.4, gx + 0.4):
            b.paint(b.new_faces(lambda x=x, z=z: rk.blob(b.bm, V((x, fy - 0.17, z)), (0.03, 0.02, 0.03), 4, 3)), "Build", IRON)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((gx + 0.35, fy - 0.2, Z0 + 1.0)), (0.05, 0.04, 0.05), 5, 3)), "Build", (0.85, 0.7, 0.36))
    for x in (gx - 1.05, gx + 1.05):
        soft(b, cube_at(b, V((x, fy - 0.2, Z0 + 2.2)), (0.05, 0.4, 0.05)), IRON, 0.01, 1)
        lantern(b, V((x, fy - 0.38, Z0 + 1.85)), 0.15)
    for i in range(3):                                          # steps up to the door
        soft(b, cube_at(b, V((gx, fy - 0.35 - i * 0.38, Z0 - 0.05 - i * 0.14)), (1.6, 0.4, 0.14)), mb.WOOD[i % 3], 0.03)

    # The big round window on the left: thick frame, cross bars, warm glow; a porch with a bench.
    wc = V((-1.25, -D / 2 - 0.02, Z0 + 1.45))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [wc + V((0, 0.06, 0)), wc + V((0, -0.14, 0))], [(0.72, 0.72)] * 2, ref=V((1, 0, 0)), seg=16)), "Build", POST)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [wc + V((0, -0.14, 0)), wc + V((0, -0.17, 0))], [(0.58, 0.58)] * 2, ref=V((1, 0, 0)), seg=16)), "Glow", GLOW)
    beam(b, wc + V((-0.6, -0.19, 0)), wc + V((0.6, -0.19, 0)), 0.04, POST)
    beam(b, wc + V((0, -0.19, -0.6)), wc + V((0, -0.19, 0.6)), 0.04, POST)
    soft(b, cube_at(b, V((-1.3, -D / 2 - 0.75, Z0 - 0.02)), (2.8, 1.3, 0.12)), mb.WOOD[0], 0.03)       # porch deck
    for x in (-2.6, -1.8, -1.0):
        fence_run(b, [V((x, -D / 2 - 1.35, Z0)), V((x + 0.8, -D / 2 - 1.35, Z0))], (0.08, 0.08, 0.7))
    soft(b, cube_at(b, V((-2.2, -D / 2 - 0.45, Z0 + 0.4)), (1.1, 0.35, 0.08)), mb.WOOD[1], 0.02)       # bench
    for x in (-2.65, -1.75):
        soft(b, cube_at(b, V((x, -D / 2 - 0.45, Z0 + 0.2)), (0.08, 0.3, 0.4)), POST, 0.01, 1)
    lantern(b, V((-2.9, -D / 2 - 0.2, Z0 + 1.9)), 0.2)
    soft(b, cube_at(b, V((-2.9, -D / 2 - 0.1, Z0 + 2.35)), (0.05, 0.3, 0.05)), IRON, 0.01, 1)
    for i in range(2):                                          # porch steps
        soft(b, cube_at(b, V((-1.3, -D / 2 - 1.55 - i * 0.35, Z0 - 0.12 - i * 0.14)), (1.1, 0.36, 0.13)), mb.WOOD[(i + 1) % 3], 0.03)

    # A round stone chimney through the back slope, with a couple of puffs of smoke.
    ch = V((-1.9, 1.1, 0))
    faces = b.new_faces(lambda: rk.tube(b.bm, [ch + V((0, 0, TOP + 0.5)), ch + V((0, 0, TOP + 3.9))], [(0.36, 0.36), (0.32, 0.32)], seg=10))
    for f in faces:
        b.paint([f], "Build", rnd.choice(STONE))
    soft(b, lambda: rk.tube(b.bm, [ch + V((0, 0, TOP + 3.85)), ch + V((0, 0, TOP + 4.1))], [(0.44, 0.44)] * 2, seg=10), STONE[1], 0.03)
    for i, (dz, r) in enumerate(((4.55, 0.24), (5.05, 0.3), (5.6, 0.22))):
        b.paint(b.new_faces(lambda dz=dz, r=r, i=i: rk.blob(b.bm, ch + V((0.1 * i, -0.05 * i, TOP + dz)), (r, r, r * 0.9), 7, 5)), "Build", (0.28, 0.27, 0.3))

    # Bushes round the base and bits of fence either side.
    for a in [k * 0.45 for k in range(14)]:
        if -2.3 < a - math.pi * 1.5 < 1.0:
            continue
        p = V((math.cos(a) * 4.6, -0.5 + math.sin(a) * 3.8, 0.3))
        clump(b, p, rnd.uniform(0.3, 0.45), 1, rnd, rnd.choice(mb.MOSS), "Build", 0.8)
    fence_run(b, [V((-4.6, -2.2, 0.2)), V((-4.1, -3.2, 0.2)), V((-3.3, -3.9, 0.2))])
    fence_run(b, [V((3.6, -3.9, 0.2)), V((4.4, -3.2, 0.2)), V((4.9, -2.2, 0.2))])
    return b


def torus(b, center, R, r, color, seg=28, tube_seg=8, squash=1.0, mat="Build"):
    """A ring with a round cross-section (a rolled edge): R is the ring's radius, r the tube's."""
    faces = b.new_faces(lambda: rk.tube(b.bm, rk.ring_path(center, R, R, seg), [(r, r * squash)] * seg, ref=V((0, 0, 1)), seg=tube_seg, closed=True))
    b.paint(faces, mat, color)
    return faces


def round_window4(b, p, out, r, lit=True):
    """A round window with a thick frame and four panes (a cross of bars)."""
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [p - out * 0.04, p + out * 0.14], [(r + 0.09, r + 0.09)] * 2, ref=V((0, 0, 1)), seg=14)), "Build", (0.36, 0.23, 0.15))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [p + out * 0.14, p + out * 0.17], [(r, r)] * 2, ref=V((0, 0, 1)), seg=14)), "Glow" if lit else "Build", GLOW if lit else (0.3, 0.4, 0.55))
    side = V((-out.y, out.x, 0))
    beam(b, p + out * 0.18 - V((0, 0, r)), p + out * 0.18 + V((0, 0, r)), 0.035, (0.36, 0.23, 0.15))
    beam(b, p + out * 0.18 - side * r, p + out * 0.18 + side * r, 0.035, (0.36, 0.23, 0.15))


def round_body(b, R, z0, z1, lo, hi, posts=12, post_color=(0.36, 0.23, 0.15)):
    """Round plaster walls in panels between dark timber posts, with a timber band at the top."""
    walls = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, z0)), V((0, 0, z1))], [(R, R)] * 2, seg=posts * 2))
    b.gradient(walls, lo, hi)
    for k in range(posts):
        a = k * math.tau / posts
        soft(b, cube_at(b, V((math.cos(a) * (R + 0.05), math.sin(a) * (R + 0.05), (z0 + z1) / 2)), (0.2, 0.2, z1 - z0), Euler((0, 0, a))), post_color, 0.03)
    torus(b, V((0, 0, z1)), R + 0.06, 0.12, post_color, posts * 2, 6)
    torus(b, V((0, 0, z0 + 0.08)), R + 0.05, 0.1, post_color, posts * 2, 6)


def arched_door(b, x, y, z0, w=1.05, h=1.9, wood=(0.55, 0.34, 0.2), frame=(0.36, 0.23, 0.15)):
    soft(b, outline_prism(b, arch_outline(x, z0, w + 0.3, h + 0.15), y - 0.12, y + 0.08), frame, 0.04)
    soft(b, outline_prism(b, arch_outline(x, z0 + 0.03, w, h), y - 0.16, y - 0.1), wood, 0.03)
    for dx in (-w * 0.25, 0, w * 0.25):
        beam(b, V((x + dx, y - 0.18, z0 + 0.1)), V((x + dx, y - 0.18, z0 + h * 0.8)), 0.016, (0.42, 0.26, 0.16))
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((x + w * 0.32, y - 0.21, z0 + h * 0.48)), (0.045, 0.035, 0.045), 5, 3)), "Build", (0.85, 0.7, 0.36))


# --- 4. Market stalls round house ---------------------------------------------------------------

def market_house():
    b = Builder(["Build", "Glow"])
    STRAW = [(0.9, 0.7, 0.36), (0.84, 0.63, 0.3), (0.94, 0.76, 0.42)]
    R, Z0, WALL = 3.1, 0.35, 2.5
    TOP = Z0 + WALL
    for k in range(14):                                          # a ring of footing stones
        a = k * math.tau / 14
        soft(b, cube_at(b, V((math.cos(a) * (R + 0.1), math.sin(a) * (R + 0.1), 0.17)), (1.45, 0.62, 0.36), Euler((0, 0, a + math.pi / 2))),
             [(0.64, 0.62, 0.58), (0.57, 0.56, 0.53), (0.7, 0.68, 0.63)][k % 3], 0.07)
    round_body(b, R, Z0, TOP, (0.74, 0.5, 0.4), (0.88, 0.65, 0.53))
    # The thatch: a wide cone in straw rows with a fat rolled eave, and a smaller capping tier on top.
    def thatch(r0, z0, r1, z1, rows, eave_r):
        for i in range(rows):
            t0, t1 = i / rows, (i + 1) / rows
            ra, rb = r0 + (r1 - r0) * t0, r0 + (r1 - r0) * t1
            za, zb = z0 + (z1 - z0) * t0, z0 + (z1 - z0) * t1
            faces = b.new_faces(lambda ra=ra, rb=rb, za=za, zb=zb: rk.tube(b.bm, [V((0, 0, za)), V((0, 0, zb + 0.06))], [(ra, ra), (rb, rb)], seg=24))
            for f in faces:
                b.paint([f], "Build", STRAW[(i + (1 if rnd.random() < 0.2 else 0)) % 3])
        torus(b, V((0, 0, z0)), r0 - 0.05, eave_r, (0.96, 0.8, 0.48), 24, 7, 0.7)
    thatch(R + 1.0, TOP - 0.05, 1.7, TOP + 1.55, 6, 0.22)
    thatch(2.05, TOP + 1.45, 0.08, TOP + 2.75, 5, 0.18)
    soft(b, lambda: rk.tube(b.bm, [V((0, 0, TOP + 2.7)), V((0, 0, TOP + 3.05))], [(0.08, 0.08), (0.03, 0.03)], seg=6), (0.4, 0.26, 0.17), 0.02)
    # Door and windows.
    arched_door(b, 0, -R - 0.02, Z0 + 0.02)
    for a in (-2.15, -0.98, 0.35, 2.75):
        out = V((math.cos(a), math.sin(a), 0))
        round_window4(b, out * (R - 0.03) + V((0, 0, Z0 + 1.55)), out, 0.34)
    for x in (-0.95, 0.95):
        lantern(b, V((x, -R - 0.35, Z0 + 1.95)), 0.1)
        soft(b, cube_at(b, V((x, -R - 0.18, Z0 + 2.25)), (0.05, 0.35, 0.05)), IRON, 0.01, 1)
    # Three market stalls round the front, each with a striped awning and a scalloped valance.
    STRIPES = [((0.82, 0.24, 0.2), (0.97, 0.92, 0.82)), ((0.26, 0.42, 0.72), (0.97, 0.92, 0.82)), ((0.86, 0.62, 0.22), (0.97, 0.92, 0.82))]
    PRODUCE = [[(0.85, 0.2, 0.15), (0.92, 0.35, 0.2)], [(0.45, 0.7, 0.28), (0.36, 0.6, 0.24)], [(0.95, 0.62, 0.2), (0.9, 0.8, 0.3)], [(0.62, 0.3, 0.58), (0.85, 0.2, 0.15)]]
    WOOD_S = (0.58, 0.38, 0.23)
    for i, a in enumerate((-2.45, -0.72, 0.55)):
        out = V((math.cos(a), math.sin(a), 0))
        side = V((-out.y, out.x, 0))
        rot = Euler((0, 0, a - math.pi / 2))
        base = out * (R + 1.35)
        soft(b, cube_at(b, base + V((0, 0, 0.5)), (1.9, 0.8, 1.0), rot), WOOD_S, 0.04)                 # counter
        soft(b, cube_at(b, base + out * 0.41 + V((0, 0, 0.5)), (1.8, 0.04, 0.8), rot), (0.5, 0.32, 0.2), 0.01, 1)
        for k in range(3):                                                                              # crates of produce
            crate = base + side * ((k - 1) * 0.58) + out * 0.05 + V((0, 0, 1.07))
            soft(b, cube_at(b, crate, (0.52, 0.56, 0.16), rot), (0.66, 0.46, 0.28), 0.02, 1)
            cols = PRODUCE[(i + k) % 4]
            for m in range(5):
                q = crate + side * rnd.uniform(-0.17, 0.17) + out * rnd.uniform(-0.17, 0.17) + V((0, 0, 0.13 + (0.06 if m == 4 else 0)))
                clump(b, q, 0.085, 1, rnd, rnd.choice(cols), "Build", 0.9)
        for sx in (-1, 1):                                                                              # posts
            for so in (-0.3, 0.55):
                soft(b, cube_at(b, base + side * (0.92 * sx) + out * so + V((0, 0, 1.15)), (0.1, 0.1, 2.3)), (0.44, 0.28, 0.18), 0.02, 1)
        lo, hi = STRIPES[i]
        n = 7
        for k in range(n):                                                                              # awning stripes, sloping out
            w = 2.1 / n
            c = base + side * (-1.05 + (k + 0.5) * w) + out * 0.2 + V((0, 0, 2.2))
            soft(b, cube_at(b, c, (w, 1.3, 0.05), Euler((-0.42, 0, a - math.pi / 2))), lo if k % 2 == 0 else hi, 0.01, 1)
            flap = base + side * (-1.05 + (k + 0.5) * w) + out * 0.82 + V((0, 0, 1.83))                 # scalloped valance
            b.paint(b.new_faces(lambda flap=flap, w=w, rot=rot: rk.blob(b.bm, flap, (w * 0.48, 0.03, 0.14), 6, 3)), "Build", hi if k % 2 == 0 else lo)
    for p in (V((1.9, -R - 0.9, 0)), V((-2.1, -R - 0.6, 0)), V((2.6, -R + 0.3, 0))):
        barrel(b, p)
    for p in (V((-1.4, -R - 1.2, 0.2)), V((1.35, -R - 1.3, 0.2))):                                      # sacks
        b.paint(b.new_faces(lambda p=p: rk.blob(b.bm, p + V((0, 0, 0.12)), (0.2, 0.18, 0.26), 7, 5)), "Build", (0.82, 0.72, 0.52))
    for i in range(3):                                                                                  # stepping stones
        soft(b, cube_at(b, V((rnd.uniform(-0.2, 0.2), -R - 0.8 - i * 0.7, 0.03)), (0.8, 0.55, 0.08), Euler((0, 0, rnd.uniform(-0.4, 0.4)))), (0.64, 0.62, 0.58), 0.04)
    return b


# --- 3. Dual ring round house -------------------------------------------------------------------

def ring_house():
    """A low round house whose flat roof has a fat rolled rim and, inside it, a raised second ring
    round an open middle; pink-tan plaster between dark posts, an arched door, round windows, on a
    fenced grassy disc with flowers, a barrel and a lantern. Faces -Y."""
    b = Builder(["Build", "Glow"])
    CLAY = (0.84, 0.63, 0.46)
    CLAY_TOP = (0.93, 0.78, 0.6)
    R, Z0, WALL = 3.2, 0.3, 2.2
    TOP = Z0 + WALL
    # The base: a round grassy disc, a rustic fence round it with a gap at the front, flowers.
    GRASS = [(0.4, 0.62, 0.3), (0.45, 0.67, 0.32), (0.37, 0.58, 0.28)]
    faces = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, -0.08)), V((0, 0, 0.14)), V((0, 0, 0.2))], [(5.3, 5.3), (5.2, 5.2), (5.0, 5.0)], seg=32))
    for f in faces:
        b.paint([f], "Build", rnd.choice(GRASS))
    posts = [k for k in range(24) if not 16 <= k <= 20]
    ring = [V((math.cos(k * math.tau / 24) * 4.8, math.sin(k * math.tau / 24) * 4.8, 0.2)) for k in range(24)]
    for k in posts:
        soft(b, cube_at(b, ring[k] + V((0, 0, 0.38)), (0.13, 0.13, 0.76)), (0.5, 0.33, 0.21), 0.02, 1)
        if (k + 1) % 24 in posts:
            for z in (0.36, 0.62):
                beam(b, ring[k] + V((0, 0, z)), ring[(k + 1) % 24] + V((0, 0, z)), 0.045, (0.6, 0.41, 0.26))
    for k in range(18):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(3.7, 4.4)
        if abs(math.sin(a) + 1) < 0.25:
            continue
        clump(b, V((math.cos(a) * d, math.sin(a) * d, 0.3)), rnd.uniform(0.1, 0.16), 1, rnd,
              rnd.choice([(0.98, 0.85, 0.3), (0.98, 0.9, 0.5), (0.95, 0.55, 0.7), (0.45, 0.66, 0.3)]), "Build", 0.8)
    round_body(b, R, Z0, TOP, (0.76, 0.54, 0.46), (0.88, 0.68, 0.58), 12)
    # The roof: a flat top framed by a fat rolled rim, then a raised inner ring round an open middle.
    top_disc = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, TOP)), V((0, 0, TOP + 0.25))], [(R + 0.25, R + 0.25)] * 2, seg=32))
    b.paint(top_disc, "Build", CLAY)
    torus(b, V((0, 0, TOP + 0.3)), R + 0.2, 0.32, CLAY, 32, 8, 0.8)
    torus(b, V((0, 0, TOP + 0.52)), R + 0.2, 0.18, CLAY_TOP, 32, 6, 0.5)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, TOP + 0.25)), V((0, 0, TOP + 0.3))], [(R - 0.1, R - 0.1)] * 2, seg=32)), "Build", (0.72, 0.5, 0.34))
    torus(b, V((0, 0, TOP + 0.75)), 1.75, 0.42, CLAY, 28, 8, 1.1)          # the raised inner ring
    torus(b, V((0, 0, TOP + 1.1)), 1.75, 0.24, CLAY_TOP, 28, 6, 0.5)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, TOP + 0.1)), V((0, 0, TOP + 0.4))], [(1.35, 1.35)] * 2, seg=24)), "Build", (0.24, 0.17, 0.13))
    # Door with a little canopy, round windows, a lantern, a barrel and a crate.
    arched_door(b, 0, -R - 0.02, Z0 + 0.02, 1.0, 1.75)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, -R - 0.05, TOP - 0.05)), V((0, -R - 0.75, TOP - 0.3))], [(0.85, 0.08), (0.9, 0.06)], ref=V((1, 0, 0)), seg=4)), "Build", (0.5, 0.33, 0.21))
    for a in (-2.25, -0.88, 0.5, 2.9):
        out = V((math.cos(a), math.sin(a), 0))
        round_window4(b, out * (R - 0.03) + V((0, 0, Z0 + 1.25)), out, 0.32, a in (-2.25, -0.88))
    lantern(b, V((0.85, -R - 0.3, Z0 + 1.75)), 0.1)
    soft(b, cube_at(b, V((0.85, -R - 0.15, Z0 + 2.05)), (0.05, 0.3, 0.05)), IRON, 0.01, 1)
    barrel(b, V((-1.6, -R - 0.35, 0.18)))
    soft(b, cube_at(b, V((1.7, -R - 0.4, 0.45)), (0.55, 0.5, 0.5), Euler((0, 0, 0.3))), (0.64, 0.44, 0.27), 0.03)
    for i in range(4):                                                        # a stone path to the gate
        soft(b, cube_at(b, V((rnd.uniform(-0.15, 0.15), -R - 0.8 - i * 0.55, 0.22)), (0.75, 0.42, 0.07), Euler((0, 0, rnd.uniform(-0.4, 0.4)))), (0.66, 0.64, 0.6), 0.03)
    return b


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rk.make_materials({"Build": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, fn in (("house_swoophome", swoop_home), ("house_market", market_house), ("house_ring", ring_house)):
        if not only or name in only:
            export(name, fn(), OUT)

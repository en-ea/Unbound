"""Fernhollow, the village in the Whispering Wood: homes made from the wood itself, one bold idea each.
  house_sawn_stump: a home carved into a giant sawn stump: flared roots, ridged bark, the cut top showing
                 its rings, a round door between the roots, round lit windows, a crooked chimney.
  toadstool:     a cream stalk under a huge red mushroom cap with pale spots, gills underneath.
  lantern_inn:   a tall stump with a leaning witch-hat roof of dark shingles, lanterns strung round it.
  root_house:    a smaller stump whose roots arch over the door like a porch.
Reuses the helpers in make_buildings.py and make_village.py. Front faces -Y (+Z in Godot).
Exported to game/assets/buildings/.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_forest_village.py [-- name ...]
"""
import math
import os
import random
import sys
import bpy
from mathutils import Euler, Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, clump, export  # noqa: E402
import make_buildings as mb  # noqa: E402
from make_buildings import soft, cube_at, beam, OUT  # noqa: E402
from make_village import lantern, round_window4, arched_door, torus, GLOW  # noqa: E402

rnd = random.Random(31)
BARK = [(0.36, 0.24, 0.16), (0.42, 0.28, 0.18), (0.31, 0.21, 0.14)]
BARK_HI = (0.52, 0.36, 0.24)
RINGS = [(0.84, 0.68, 0.46), (0.72, 0.55, 0.34)]
MOSS = [(0.34, 0.5, 0.24), (0.4, 0.56, 0.27), (0.3, 0.45, 0.22)]
STONE = (0.55, 0.54, 0.52)
SHINGLE = [(0.2, 0.3, 0.31), (0.24, 0.35, 0.36), (0.17, 0.26, 0.27)]
CREAM = (0.9, 0.84, 0.7)
CAP = [(0.76, 0.22, 0.15), (0.82, 0.26, 0.17), (0.7, 0.19, 0.13)]


def bark_trunk(b, profile, seg=16):
    """A ridged trunk through (z, radius) pairs: every other face a shade lighter, like bark ridges."""
    faces = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, z)) for z, r in profile], [(r, r) for z, r in profile], seg=seg))
    for f in faces:
        c = f.calc_center_median()
        k = int((math.atan2(c.y, c.x) + math.pi) / math.tau * seg)
        b.paint([f], "Build", BARK[k % 3] if c.z < profile[-1][0] - 0.05 else RINGS[0])
    return faces


def cut_top(b, z, r):
    """The sawn top: pale wood with darker growth rings."""
    for i, k in enumerate((1.0, 0.72, 0.46, 0.22)):
        b.paint(b.new_faces(lambda k=k, i=i: rk.tube(b.bm, [V((0, 0, z + i * 0.012)), V((0, 0, z + i * 0.012 + 0.03))], [(r * k, r * k)] * 2, seg=16)),
                "Build", RINGS[i % 2])


def roots(b, r0, count, reach, z=0.5, lift=0.0, skip=()):
    """Roots flaring out from the trunk into the ground (skip: angles in degrees kept clear, the door)."""
    for k in range(count):
        a = k * math.tau / count + 0.25
        if any(abs(math.degrees(a) % 360 - s) < 24 for s in skip):
            continue
        d = V((math.cos(a), math.sin(a), 0))
        pts = [d * (r0 * 0.85) + V((0, 0, z + 0.5)), d * (r0 + 0.5) + V((0, 0, z + lift)), d * reach + V((0, 0, -0.1))]
        b.paint(b.new_faces(lambda pts=pts: rk.tube(b.bm, pts, [(0.42, 0.34), (0.3, 0.24), (0.1, 0.08)], ref=V((0, 0, 1)), seg=6)),
                "Build", rnd.choice(BARK))


def window_on(b, R, z, deg, r=0.38):
    a = math.radians(deg)
    out = V((math.cos(a), math.sin(a), 0))
    round_window4(b, out * (R - 0.02) + V((0, 0, z)), out, r)


def door_front(b, R, w=1.0, h=1.85):
    """An arched door set into the round front (-Y), with a stone step."""
    arched_door(b, 0, -R + 0.08, 0.12, w, h)
    soft(b, cube_at(b, V((0, -R - 0.45, 0.06)), (1.5, 0.7, 0.16)), STONE, 0.04)


def moss_tufts(b, R, z, n):
    for k in range(n):
        a = rnd.uniform(0, math.tau)
        clump(b, V((math.cos(a) * R * rnd.uniform(0.3, 0.95), math.sin(a) * R * rnd.uniform(0.3, 0.95), z)), rnd.uniform(0.2, 0.36), 1, rnd,
              rnd.choice(MOSS), "Build", 0.6)


# --- the stump house -----------------------------------------------------------------------------

def stump_house():
    b = Builder(["Build", "Glow"])
    R = 2.3
    bark_trunk(b, [(-0.1, 2.9), (0.5, 2.45), (1.6, 2.3), (3.0, 2.28), (3.3, 2.3)])
    cut_top(b, 3.3, 2.3)
    roots(b, 2.45, 8, 3.7, skip=(270,))
    door_front(b, 2.42)
    window_on(b, 2.32, 1.7, 220)
    window_on(b, 2.32, 1.9, 320)
    window_on(b, 2.32, 2.2, 60, 0.32)
    moss_tufts(b, 2.1, 3.36, 6)
    # A crooked stone chimney with an iron cap, off to one side of the cut top.
    soft(b, lambda: rk.tube(b.bm, [V((0.9, 0.6, 3.3)), V((1.0, 0.65, 4.2)), V((0.85, 0.6, 4.7))], [(0.3, 0.3), (0.26, 0.26), (0.24, 0.24)], seg=7), STONE, 0.03)
    soft(b, cube_at(b, V((0.85, 0.6, 4.78)), (0.6, 0.6, 0.08)), (0.2, 0.19, 0.2), 0.02)
    lantern(b, V((0.9, -2.75, 2.25)), 0.25)
    beam(b, V((0.9, -2.3, 2.75)), V((0.9, -2.8, 2.75)), 0.06, BARK[0])
    return b


# --- the toadstool --------------------------------------------------------------------------------

def toadstool():
    b = Builder(["Build", "Glow"])
    stalk = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, -0.1)), V((0, 0, 1.2)), V((0, 0, 2.6)), V((0, 0, 3.5))],
                                        [(1.75, 1.75), (1.55, 1.55), (1.45, 1.45), (1.6, 1.6)], seg=14))
    b.gradient(stalk, (0.82, 0.76, 0.62), CREAM)
    # The cap: a broad dome, its rim curling down a little, gills underneath.
    prof = [(3.25, 3.3), (3.55, 3.5), (4.2, 3.2), (4.9, 2.5), (5.4, 1.5), (5.65, 0.4), (5.7, 0.05)]
    cap = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, z)) for z, r in prof], [(r, r) for z, r in prof], seg=18))
    for f in cap:
        b.paint([f], "Build", rnd.choice(CAP))
    gills = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, 3.24)), V((0, 0, 3.5))], [(3.25, 3.25), (1.55, 1.55)], seg=18))
    b.paint(gills, "Build", (0.78, 0.66, 0.5))
    for k in range(11):                               # pale spots on the cap
        a = rnd.uniform(0, math.tau)
        t = rnd.uniform(0.15, 0.85)
        z = 3.6 + t * 1.9
        r = 3.45 * (1 - t ** 1.6) + 0.1
        b.paint(b.new_faces(lambda a=a, z=z, r=r: rk.blob(b.bm, V((math.cos(a) * r, math.sin(a) * r, z)), (0.32, 0.32, 0.12), 6, 3)),
                "Build", (0.97, 0.94, 0.86))
    door_front(b, 1.62, 0.95, 1.75)
    window_on(b, 1.5, 2.1, 210, 0.3)
    window_on(b, 1.5, 2.5, 330, 0.3)
    lantern(b, V((-0.85, -1.95, 2.05)), 0.0)
    for k in range(5):                                # little mushrooms at its foot
        a = math.radians(200 + k * 30)
        p = V((math.cos(a) * 2.2, math.sin(a) * 2.2, 0))
        b.paint(b.new_faces(lambda p=p: rk.tube(b.bm, [p, p + V((0, 0, 0.3))], [(0.06, 0.06)] * 2, seg=5)), "Build", CREAM)
        b.paint(b.new_faces(lambda p=p: rk.tube(b.bm, [p + V((0, 0, 0.28)), p + V((0, 0, 0.42))], [(0.2, 0.2), (0.02, 0.02)], seg=6)), "Build", rnd.choice(CAP))
    return b


# --- the lantern inn ------------------------------------------------------------------------------

def lantern_inn():
    b = Builder(["Build", "Glow"])
    bark_trunk(b, [(-0.1, 2.5), (0.5, 2.1), (2.0, 1.95), (4.4, 1.9), (4.6, 2.0)])
    roots(b, 2.1, 7, 3.2, skip=(270,))
    door_front(b, 2.05, 1.1, 1.95)
    for z, d in ((1.9, 210), (2.0, 330), (3.3, 250), (3.4, 30), (3.2, 140)):
        window_on(b, 1.95, z, d, 0.32)
    # The witch-hat roof: rings of shingles leaning off to one side as they climb.
    lean = V((0.55, 0.25, 0))
    prof = [(4.5, 2.6), (4.9, 2.2), (5.6, 1.5), (6.4, 0.85), (7.1, 0.35), (7.6, 0.05)]
    pts = [V((0, 0, z)) + lean * ((z - 4.5) / 3.1) ** 2 for z, r in prof]
    roof = b.new_faces(lambda: rk.tube(b.bm, pts, [(r, r) for z, r in prof], seg=14))
    for f in roof:
        b.paint([f], "Build", rnd.choice(SHINGLE))
    torus(b, V((0, 0, 4.5)), 2.55, 0.1, BARK[2], 28, 6)
    # A string of lanterns sagging round the eaves, and a hanging sign by the door.
    for k in range(7):
        a = math.radians(200 + k * 24)
        lantern(b, V((math.cos(a) * 2.45, math.sin(a) * 2.45, 4.05 - 0.15 * math.sin(k * 0.9))), 0.15)
    beam(b, V((-1.0, -1.95, 2.6)), V((-1.0, -2.7, 2.6)), 0.06, BARK[0])
    soft(b, cube_at(b, V((-1.0, -2.55, 2.15)), (0.08, 0.7, 0.5)), (0.6, 0.42, 0.26), 0.02)
    soft(b, lambda: rk.tube(b.bm, [V((-1.03, -2.55, 2.05)), V((-1.06, -2.55, 2.05))], [(0.14, 0.14)] * 2, seg=8, ref=V((0, 0, 1))), (0.92, 0.72, 0.3), 0.005)
    return b


# --- the root house -------------------------------------------------------------------------------

def root_house():
    b = Builder(["Build", "Glow"])
    bark_trunk(b, [(-0.1, 2.2), (0.5, 1.85), (2.2, 1.75), (2.7, 1.8)])
    cut_top(b, 2.7, 1.8)
    roots(b, 1.85, 6, 2.9, skip=(270,))
    # Two big roots arch over the door like a porch.
    for side in (-1, 1):
        pts = [V((side * 0.9, -1.6, 2.3)), V((side * 1.1, -2.6, 2.6)), V((side * 1.0, -3.3, 1.4)), V((side * 0.9, -3.4, -0.1))]
        b.paint(b.new_faces(lambda pts=pts: rk.tube(b.bm, pts, [(0.32, 0.28), (0.3, 0.26), (0.26, 0.22), (0.24, 0.2)], ref=V((1, 0, 0)), seg=6)),
                "Build", rnd.choice(BARK))
    beam(b, V((-1.0, -3.0, 2.45)), V((1.0, -3.0, 2.45)), 0.12, BARK[1])
    lantern(b, V((0, -3.0, 2.05)), 0.15)
    door_front(b, 1.82, 0.9, 1.7)
    window_on(b, 1.76, 1.6, 30, 0.3)
    window_on(b, 1.76, 1.8, 150, 0.3)
    moss_tufts(b, 1.6, 2.76, 5)
    # A little flower box under a window.
    soft(b, cube_at(b, V((1.55, 0.9, 1.15)), (0.3, 0.8, 0.18), Euler((0, 0, math.radians(30)))), (0.55, 0.36, 0.22), 0.02)
    for k in range(4):
        clump(b, V((1.62 + k * 0.0, 0.62 + k * 0.18, 1.3)), 0.11, 1, rnd, rnd.choice([(0.9, 0.5, 0.7), (0.95, 0.8, 0.35)]), "Build", 0.9)
    return b


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rk.make_materials({"Build": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, fn in (("house_sawn_stump", stump_house), ("house_toadstool", toadstool), ("house_lantern_inn", lantern_inn),
                     ("house_root", root_house)):
        if not only or name in only:
            export(name, fn(), OUT)

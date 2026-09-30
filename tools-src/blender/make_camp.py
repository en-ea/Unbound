"""Builds the Red Hand bandit camp pieces (faceted, colours in UVs like every static model):
a canvas tent, the leader's big striped tent, a sharpened-stake wall section, a watch platform with a
ladder, a Red Hand banner, a weapon rack, and a stack of crates with a barrel. Origin at the ground,
+Z up, front towards -Y. Exported to game/assets/camp/<name>.glb.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_camp.py
"""
import math
import os
import random
import sys
import bmesh
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, export  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "camp")
rk.make_materials({"Item": (1, 1, 1), "Glow": (1, 1, 1)})

# Colours are stored linear in the UVs, so these need to be as bright as the village's (dark values go black).
WOOD = (0.56, 0.43, 0.32)
DARK_WOOD = (0.42, 0.33, 0.26)
CANVAS = (0.8, 0.74, 0.63)
CANVAS_DARK = (0.66, 0.6, 0.52)
RED = (0.74, 0.2, 0.16)
BLACK = (0.24, 0.22, 0.24)
IRON = (0.62, 0.63, 0.68)
ROPE = (0.82, 0.72, 0.54)


def box(b, c, size, color, rot=0.0, mat="Item", top=1.0):
    def make():
        g = bmesh.ops.create_cube(b.bm, size=1.0)
        ca, sa = math.cos(rot), math.sin(rot)
        for v in g["verts"]:
            k = top if v.co.z > 0 else 1.0
            x, y = v.co.x * size[0] * k, v.co.y * size[1] * k
            v.co = V((x * ca - y * sa, x * sa + y * ca, v.co.z * size[2])) + c
    b.paint(b.new_faces(make), mat, color)


def pole(b, a, c, r, color, seg=5):
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [a, c], [(r, r)] * 2, ref=V((1, 0, 0)) if abs((c - a).normalized().x) < 0.9 else V((0, 0, 1)), seg=seg)), "Item", color)


def stake(b, x, y, h, r, color, rnd):
    """A sharpened log standing in the ground, leaning a touch."""
    lean = V((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), 0))
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((x, y, -0.2)), V((x, y, h - 0.35)) + lean, V((x, y, h)) + lean * 1.2],
                                         [(r, r), (r * 0.95, r * 0.95), (0.01, 0.01)], ref=V((1, 0, 0)), seg=6)), "Item", color)


def quad(b, pts, color, mat="Item"):
    b.paint(b.new_faces(lambda: b.bm.faces.new([b.bm.verts.new(p) for p in pts])), mat, color)


def tent_body(b, length, width, height, cloth, dark, rnd, sag=0.12):
    """An A-frame tent along X: two sloping canvas sides (each in 3 panels that sag between poles),
    a back wall and a front with a dark doorway."""
    hx, hw = length / 2, width / 2
    xs = [-hx, -hx / 3, hx / 3, hx]
    for side in (1, -1):
        for i in range(3):
            x0, x1 = xs[i], xs[i + 1]
            s = sag if i == 1 else sag * 0.5
            col = cloth if (i + (side > 0)) % 2 else dark
            quad(b, [V((x0, side * hw, 0.05)), V((x1, side * hw, 0.05)), V((x1, side * s, height - s * 0.4)), V((x0, side * s, height - s * 0.4))], col)
    quad(b, [V((hx, -hw, 0.05)), V((hx, hw, 0.05)), V((hx, 0, height))], dark)        # back wall
    quad(b, [V((-hx, hw, 0.05)), V((-hx, -hw, 0.05)), V((-hx, 0, height))], cloth)    # front
    quad(b, [V((-hx - 0.01, 0.45, 0.05)), V((-hx - 0.01, -0.45, 0.05)), V((-hx - 0.01, 0, height * 0.72))], BLACK)   # doorway
    for x in (-hx - 0.05, hx + 0.05):
        pole(b, V((x, 0, 0)), V((x, 0, height + 0.3)), 0.05, DARK_WOOD)
    pole(b, V((-hx - 0.05, 0, height)), V((hx + 0.05, 0, height)), 0.04, DARK_WOOD)
    for x in (-hx, hx):                                                            # guy ropes and stakes
        for side in (1, -1):
            pole(b, V((x * 1.05, 0, height + 0.2)), V((x * 1.35, side * (hw + 0.6), 0.05)), 0.012, ROPE, 3)
            box(b, V((x * 1.35, side * (hw + 0.6), 0.1)), (0.06, 0.06, 0.25), DARK_WOOD)


def tent():
    rnd = random.Random(1)
    b = Builder(["Item", "Glow"])
    tent_body(b, 3.2, 2.5, 2.1, CANVAS, CANVAS_DARK, rnd)
    box(b, V((0.4, 1.35, 0.15)), (0.5, 0.4, 0.3), WOOD)                              # a bedroll crate
    return b


def big_tent():
    """The leader's tent: bigger, striped red and black, with an awning on two spears over the door and a
    small red-hand pennant on the ridge."""
    rnd = random.Random(2)
    b = Builder(["Item", "Glow"])
    tent_body(b, 5.0, 4.0, 3.2, RED, BLACK, rnd, sag=0.18)
    quad(b, [V((-2.55, 1.2, 2.3)), V((-2.55, -1.2, 2.3)), V((-4.0, -1.3, 1.9)), V((-4.0, 1.3, 1.9))], RED)   # awning
    for y in (1.25, -1.25):
        pole(b, V((-4.0, y, 0)), V((-4.0, y, 2.2)), 0.04, DARK_WOOD)
        pole(b, V((-4.0, y, 2.2)), V((-4.0, y, 2.55)), 0.03, IRON, 4)             # spear heads
    pole(b, V((2.55, 0, 3.5)), V((2.55, 0, 4.4)), 0.03, DARK_WOOD)
    quad(b, [V((2.57, 0.02, 4.35)), V((2.57, 0.02, 3.95)), V((2.57, 0.62, 4.1))], RED)
    return b


def palisade():
    """A 4 m section of sharpened stakes lashed to two rails (the camp's wall)."""
    rnd = random.Random(3)
    b = Builder(["Item", "Glow"])
    n = 9
    for i in range(n):
        x = -2.0 + (i + 0.5) * 4.0 / n
        stake(b, x, rnd.uniform(-0.04, 0.04), rnd.uniform(2.0, 2.6), rnd.uniform(0.18, 0.23), WOOD if i % 3 else DARK_WOOD, rnd)
    for z in (0.7, 1.6):
        box(b, V((0, -0.24, z)), (4.1, 0.08, 0.14), DARK_WOOD)
        for i in range(0, n, 2):
            x = -2.0 + (i + 0.5) * 4.0 / n
            box(b, V((x, -0.25, z)), (0.08, 0.1, 0.2), ROPE)
    return b


def watch_platform():
    """A lookout: four posts, a plank floor 2.6 m up with a rail, a ladder, and a lantern."""
    b = Builder(["Item", "Glow"])
    for x in (-1.0, 1.0):
        for y in (-1.0, 1.0):
            pole(b, V((x, y, 0)), V((x * 0.92, y * 0.92, 3.7)), 0.09, DARK_WOOD, 6)
    box(b, V((0, 0, 2.6)), (2.3, 2.3, 0.12), WOOD)
    for x in (-1.0, 1.0):
        box(b, V((x * 0.93, 0, 3.4)), (0.08, 2.0, 0.08), DARK_WOOD)
        box(b, V((0, x * 0.93, 3.4)), (2.0, 0.08, 0.08), DARK_WOOD)
    for i in range(5):                                                            # the ladder, leaning in at the front
        z = 0.3 + i * 0.5
        box(b, V((0, -1.5 + z * 0.12, z)), (0.7, 0.06, 0.06), WOOD)
    for x in (-0.35, 0.35):
        pole(b, V((x, -1.55, 0)), V((x, -1.1, 2.7)), 0.04, DARK_WOOD, 4)
    pole(b, V((0.95, -0.95, 3.7)), V((0.95, -0.95, 3.9)), 0.08, (1.0, 0.72, 0.38), 6)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0.95, -0.95, 3.8)), (0.07, 0.07, 0.08), 6, 4)), "Glow", (1.0, 0.72, 0.38))
    return b


def banner():
    """A tall pole flying a ragged red banner with a black hand on it."""
    b = Builder(["Item", "Glow"])
    pole(b, V((0, 0, 0)), V((0, 0, 4.4)), 0.06, DARK_WOOD)
    pole(b, V((0, 0, 4.1)), V((0.95, 0, 4.1)), 0.03, DARK_WOOD, 4)
    # The banner: a strip with a torn, notched hem, hanging from the cross bar.
    quad(b, [V((0.05, -0.02, 4.08)), V((0.92, -0.02, 4.08)), V((0.92, -0.02, 2.6)), V((0.7, -0.02, 2.85)), V((0.48, -0.02, 2.55)), V((0.26, -0.02, 2.8)), V((0.05, -0.02, 2.62))], RED)
    quad(b, [V((0.05, 0.02, 2.62)), V((0.26, 0.02, 2.8)), V((0.48, 0.02, 2.55)), V((0.7, 0.02, 2.85)), V((0.92, 0.02, 2.6)), V((0.92, 0.02, 4.08)), V((0.05, 0.02, 4.08))], RED)
    # The hand: a palm and four fingers and a thumb, on the front.
    box(b, V((0.48, -0.035, 3.3)), (0.3, 0.02, 0.28), BLACK)
    for i, h in enumerate((0.26, 0.3, 0.28, 0.22)):
        box(b, V((0.37 + i * 0.075, -0.035, 3.44 + h / 2)), (0.055, 0.02, h), BLACK)
    box(b, V((0.3, -0.035, 3.3)), (0.18, 0.02, 0.06), BLACK, rot=0.0)
    return b


def weapon_rack():
    """An A-frame rack with a few swords and spears leaning on it."""
    b = Builder(["Item", "Glow"])
    for x in (-0.8, 0.8):
        pole(b, V((x, -0.3, 0)), V((x, 0, 1.3)), 0.04, DARK_WOOD, 4)
        pole(b, V((x, 0.3, 0)), V((x, 0, 1.3)), 0.04, DARK_WOOD, 4)
    box(b, V((0, 0, 1.25)), (1.7, 0.08, 0.08), WOOD)
    for i, x in enumerate((-0.55, -0.2, 0.15, 0.5)):
        if i % 2:
            pole(b, V((x, -0.35, 0)), V((x, -0.04, 1.7)), 0.02, WOOD, 4)                 # spear
            pole(b, V((x, -0.04, 1.7)), V((x, 0.0, 1.95)), 0.035, IRON, 3)
        else:
            box(b, V((x, -0.18, 0.55)), (0.06, 0.02, 0.9), IRON, top=0.3)                 # sword blade
            box(b, V((x, -0.1, 1.05)), (0.2, 0.05, 0.04), DARK_WOOD)
            box(b, V((x, -0.08, 1.15)), (0.04, 0.04, 0.18), (0.3, 0.18, 0.1))
    return b


def crates():
    """Stolen goods: three crates stacked, a barrel, a sack."""
    b = Builder(["Item", "Glow"])
    for c, s in ((V((0, 0, 0.35)), 0.7), (V((0.75, 0.1, 0.3)), 0.6), (V((0.3, 0.05, 1.0)), 0.6)):
        box(b, c, (s, s, s), WOOD)
        for dz in (-s * 0.35, s * 0.35):
            box(b, c + V((0, -s * 0.51, dz)), (s * 1.02, 0.03, 0.07), DARK_WOOD)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((-0.9, 0.1, 0)), V((-0.9, 0.1, 0.45)), V((-0.9, 0.1, 0.9))], [(0.32, 0.32), (0.36, 0.36), (0.32, 0.32)], ref=V((1, 0, 0)), seg=8)), "Item", WOOD)
    for z in (0.15, 0.75):
        b.paint(b.new_faces(lambda z=z: rk.tube(b.bm, [V((-0.9, 0.1, z - 0.03)), V((-0.9, 0.1, z + 0.03))], [(0.35, 0.35)] * 2, ref=V((1, 0, 0)), seg=8)), "Item", IRON)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0.9, -0.6, 0.25)), (0.3, 0.25, 0.28), 7, 5)), "Item", (0.66, 0.58, 0.44))
    return b


os.makedirs(OUT, exist_ok=True)
export("camp_tent", tent(), OUT)
export("camp_big_tent", big_tent(), OUT)
export("camp_palisade", palisade(), OUT)
export("camp_watch", watch_platform(), OUT)
export("camp_banner", banner(), OUT)
export("camp_rack", weapon_rack(), OUT)
export("camp_crates", crates(), OUT)

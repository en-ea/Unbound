"""Builds the inside of your home and its furniture (faceted low-poly, colours in UVs like the rest).

  room_<feel>[_bright]: the room shell for each feel (lantern = Cottage, lodge = Lodge, hill = Stone) and
                layout (the Hearth Room, or the Bright Room: two big windows at the back and the
                fireplace on the right-hand wall; see Home.LAYOUTS): plank floor, walls
                that step down towards the camera (a cut-away dollhouse view), a low front wall with
                the doorway, a stone hearth with a fire and a hanging pot, windows with curtains,
                shelves, a picture, a doormat. The glass is its own object ("Windows") so the game
                can light it for day or night.
  furn_<piece>: furniture you place yourself (bed, table, chairs, shelves, rugs, plants, lamps...).
                Origin at the middle of its base; the front faces -Y (+Z in Godot, the camera).
  mailbox:      the post box by your front path (it opens the home screen).
Room: inner floor x -4.8..4.8, y -3.8..3.8 (front, the doorway, at -Y). Keep in step with
Home.ROOM_HALF and world/home_interior.gd. Exported to game/assets/interior/.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_interior.py [-- <name>]
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
from lowpoly import Builder, clump  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "interior")
rnd = random.Random(7)

IX, IY, T = 4.8, 3.8, 0.3            # inner half sizes, wall thickness
H_BACK, H_FRONT = 2.9, 1.2          # side walls step down from the back to the front
KNEE = 0.55                          # the low front wall
DOOR = 0.8                           # half the doorway

IRON = (0.24, 0.24, 0.27)
GOLD = (0.96, 0.76, 0.34)
FLAME = [(0.92, 0.3, 0.06), (0.98, 0.5, 0.1), (1.0, 0.72, 0.3)]
STONE = [(0.66, 0.64, 0.6), (0.58, 0.57, 0.55), (0.72, 0.69, 0.64), (0.54, 0.53, 0.52), (0.62, 0.6, 0.58)]
LEAF = [(0.36, 0.56, 0.3), (0.3, 0.5, 0.27), (0.42, 0.62, 0.33)]
BOOKS = [(0.62, 0.22, 0.2), (0.24, 0.38, 0.55), (0.3, 0.5, 0.34), (0.78, 0.6, 0.3), (0.5, 0.3, 0.46), (0.86, 0.8, 0.66), (0.4, 0.26, 0.18)]
BLOOMS = [(0.95, 0.55, 0.72), (0.98, 0.85, 0.3), (0.6, 0.55, 0.95), (1.0, 0.95, 0.9)]
CREAM = (0.96, 0.92, 0.84)
WOOD = [(0.64, 0.43, 0.27), (0.58, 0.38, 0.23), (0.7, 0.48, 0.3)]
WOOD_D = (0.4, 0.26, 0.17)

# Each house has its own look inside: floor planks, walls, timber, cloth.
STYLES = {
    "lantern": {"walls": "cottage", "floor": [(0.72, 0.52, 0.33), (0.66, 0.47, 0.3), (0.76, 0.56, 0.36), (0.69, 0.5, 0.31)],
                "plaster": (0.95, 0.9, 0.8), "timber": (0.38, 0.25, 0.17), "lower": [(0.34, 0.5, 0.48), (0.31, 0.46, 0.45), (0.36, 0.52, 0.5)],
                "cloth": (0.78, 0.32, 0.28), "window": "square"},
    "lodge": {"walls": "planks", "floor": [(0.52, 0.34, 0.22), (0.48, 0.31, 0.2), (0.56, 0.37, 0.24), (0.5, 0.33, 0.21)],
              "plaster": (0.76, 0.55, 0.34), "timber": (0.36, 0.23, 0.15), "lower": [(0.76, 0.55, 0.34), (0.7, 0.5, 0.31), (0.8, 0.59, 0.37)],
              "cloth": (0.3, 0.46, 0.44), "window": "tall"},
    "hill": {"walls": "stone", "floor": [(0.68, 0.48, 0.31), (0.63, 0.44, 0.28), (0.72, 0.52, 0.34), (0.66, 0.46, 0.3)],
             "plaster": (0.97, 0.9, 0.74), "timber": (0.46, 0.31, 0.2), "lower": STONE,
             "cloth": (0.86, 0.66, 0.3), "window": "round"},
}


# --- helpers -------------------------------------------------------------------------------

def paint(b, faces, color, var=0.03, mat="Prop"):
    for f in faces:
        k = 1.0 + rnd.uniform(-var, var)
        b.paint([f], mat, tuple(min(1.0, c * k) for c in color))


def cube(b, center, size, rot=None):
    def make():
        geom = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in geom["verts"]:
            p = V((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            if rot:
                p.rotate(rot)
            v.co = p + center
    return make


def soft(b, make, color, offset=0.03, segs=1, mat="Prop", var=0.03):
    """Builds a shape with `make`, rounds its edges with a small bevel, paints it."""
    def run():
        before = set(b.bm.edges)
        make()
        edges = [e for e in b.bm.edges if e not in before]
        bmesh.ops.bevel(b.bm, geom=edges, offset=offset, segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True)
    paint(b, b.new_faces(run), color, var, mat)


def box(b, center, size, color, var=0.03, mat="Prop", rot=None):
    paint(b, b.new_faces(cube(b, center, size, rot)), color, var, mat)


def quad_prism(b, quad, depth, color, var=0.03, mat="Prop"):
    """A slab from a four-corner face pushed along `depth` (walls with sloping tops)."""
    def make():
        a = [b.bm.verts.new(p) for p in quad]
        c = [b.bm.verts.new(p + depth) for p in quad]
        b.bm.faces.new(a)
        b.bm.faces.new(list(reversed(c)))
        for i in range(4):
            j = (i + 1) % 4
            b.bm.faces.new((a[i], c[i], c[j], a[j]))
    paint(b, b.new_faces(make), color, var, mat)


def rod(b, p0, p1, r, color, seg=6, mat="Prop", var=0.02):
    d = (p1 - p0).normalized()
    ref = V((1, 0, 0)) if abs(d.x) < 0.9 else V((0, 0, 1))
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [p0, p1], [(r, r)] * 2, ref=ref, seg=seg)), color, var, mat)


def cyl(b, at, r, h, color, seg=10, mat="Prop", r_top=None, var=0.02):
    rt = r if r_top is None else r_top
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [at, at + V((0, 0, h))], [(r, r), (rt, rt)], seg=seg)), color, var, mat)


def ball(b, at, size, color, seg=6, rings=4, mat="Prop", var=0.03):
    paint(b, b.new_faces(lambda: rk.blob(b.bm, at, size, seg, rings)), color, var, mat)


def flame(b, at, s=1.0):
    ball(b, at + V((0, 0, 0.1 * s)), (0.1 * s, 0.1 * s, 0.16 * s), FLAME[0], 6, 4, "Glow")
    ball(b, at + V((0.03 * s, 0, 0.2 * s)), (0.06 * s, 0.06 * s, 0.12 * s), FLAME[1], 5, 3, "Glow")
    ball(b, at + V((-0.02 * s, 0, 0.27 * s)), (0.03 * s, 0.03 * s, 0.07 * s), FLAME[2], 4, 3, "Glow")


def candle(b, at, h=0.14):
    cyl(b, at, 0.05, 0.02, GOLD, 8)
    cyl(b, at + V((0, 0, 0.02)), 0.025, h, CREAM, 6)
    ball(b, at + V((0, 0, h + 0.05)), (0.018, 0.018, 0.035), FLAME[1], 4, 3, "Glow")


def pot_plant(b, at, r=0.12, leaves=5, bloom=True):
    cyl(b, at, r * 0.8, r * 1.4, (0.74, 0.42, 0.3), 8, r_top=r)
    for k in range(leaves):
        a = k * math.tau / leaves
        c = at + V((math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, r * 1.7 + rnd.uniform(0, r * 0.6)))
        clump(b, c, r * 0.55, 1, rnd, rnd.choice(LEAF), "Prop", 0.8)
    if bloom:
        for k in range(3):
            clump(b, at + V((rnd.uniform(-r, r) * 0.5, rnd.uniform(-r, r) * 0.5, r * 2.4)), r * 0.25, 1, rnd, rnd.choice(BLOOMS), "Prop", 0.8)


class Wall:
    """A wall seen from inside: u runs along it, v is height, d is depth into the room (0 = its face)."""

    def __init__(self, origin, along, inward, height):
        self.o, self.a, self.n, self.h = origin, along, inward, height

    def p(self, u, v, d=0.0):
        return self.o + self.a * u + V((0, 0, v)) + self.n * d

    def v(self, u, v):
        """A height: a number, or ("top", offset) for the wall's top plus an offset."""
        return self.h(u) + v[1] if isinstance(v, tuple) else v

    def slab(self, b, u0, u1, v0, v1, d0, d1, color, var=0.03, mat="Prop"):
        """A slab on the wall face from u0 to u1, heights v0 to v1, depth d0 to d1."""
        quad = [self.p(u0, self.v(u0, v0), d0), self.p(u1, self.v(u1, v0), d0),
                self.p(u1, self.v(u1, v1), d0), self.p(u0, self.v(u0, v1), d0)]
        quad_prism(b, quad, self.n * (d1 - d0), color, var, mat)


TOP = ("top", 0.0)


# --- the room ---------------------------------------------------------------------------------

def floor(b, s):
    box(b, V((0, 0, -0.08)), (2 * (IX + T), 2 * (IY + T), 0.12), (0.2, 0.14, 0.1), 0.0)
    x = -IX - T
    while x < IX + T - 0.01:
        w = min(0.32, IX + T - x)
        y = -IY - T
        while y < IY + T - 0.01:
            length = min(rnd.uniform(1.3, 2.9), IY + T - y)
            if IY + T - (y + length) < 0.5:
                length = IY + T - y
            box(b, V((x + w / 2, y + length / 2, -0.05)), (w - 0.012, length - 0.012, 0.1), rnd.choice(s["floor"]), 0.04)
            y += length
        x += w


def dress_wall(b, s, w, u0, u1, posts, braces=False):
    """The wall body, then its face: lower panelling (planks or stones), a rail, plaster or planks
    above, timber posts, a top plate, a skirting board."""
    style = s["walls"]
    w.slab(b, u0, u1, 0, TOP, -T, 0.0, s["plaster"], 0.02)                 # body up to the top
    w.slab(b, u0, u1, 0, 0.14, 0.0, 0.05, s["timber"], 0.0)               # skirting
    if style == "stone":                                                     # fieldstone to hip height
        for row in range(3):
            u = u0 + rnd.uniform(0, 0.2)
            while u < u1 - 0.1:
                wd = min(rnd.uniform(0.34, 0.6), u1 - u)
                w.slab(b, u + 0.02, u + wd - 0.02, 0.15 + row * 0.29, 0.15 + row * 0.29 + 0.26, 0.0, rnd.uniform(0.03, 0.07), rnd.choice(STONE), 0.05)
                u += wd
        w.slab(b, u0, u1, 1.02, 1.1, 0.0, 0.08, s["timber"], 0.02)
    elif style == "cottage":                                                 # painted panelling, a rail
        u = u0
        while u < u1 - 0.05:
            wd = min(0.26, u1 - u)
            w.slab(b, u + 0.008, u + wd - 0.008, 0.14, 1.0, 0.0, 0.03, rnd.choice(s["lower"]), 0.03)
            u += wd
        w.slab(b, u0, u1, 0.98, 1.08, 0.0, 0.07, s["timber"], 0.02)
    else:                                                                    # planks all the way up
        u = u0
        while u < u1 - 0.05:
            wd = min(rnd.uniform(0.22, 0.3), u1 - u)
            w.slab(b, u + 0.008, u + wd - 0.008, 0.14, ("top", -0.16), 0.0, 0.03, rnd.choice(s["lower"]), 0.04)
            u += wd
    for pu in posts:
        w.slab(b, pu - 0.11, pu + 0.11, 0.0, TOP, 0.0, 0.1, s["timber"], 0.03)
    if braces:
        for a, c in zip(posts, posts[1:]):
            if c - a > 1.6:
                ha, hc = w.h(a), w.h(c)
                rod(b, w.p(a + 0.12, 1.1, 0.06), w.p(a + (c - a) * 0.45, ha + (hc - ha) * 0.45 - 0.35, 0.06), 0.06, s["timber"], 4)
                rod(b, w.p(c - 0.12, 1.1, 0.06), w.p(a + (c - a) * 0.55, ha + (hc - ha) * 0.55 - 0.35, 0.06), 0.06, s["timber"], 4)
    w.slab(b, u0 - 0.001, u1 + 0.001, ("top", -0.18), ("top", 0.05), -T - 0.02, 0.12, s["timber"], 0.02)   # top plate


def window(b, glass, s, w, u, v0, width, height, curtains=True):
    t = s["timber"]
    kind = s["window"]
    if kind == "round":
        r = width / 2
        c = w.p(u, v0 + r, 0.0)
        paint(b, b.new_faces(lambda: rk.tube(b.bm, [c, c + w.n * 0.1], [(r + 0.12, r + 0.12)] * 2, ref=V((0, 0, 1)), seg=12)), t, 0.02)
        paint(glass, glass.new_faces(lambda: rk.tube(glass.bm, [c + w.n * 0.1, c + w.n * 0.12], [(r, r)] * 2, ref=V((0, 0, 1)), seg=12)), (1, 1, 1), 0.0)
        box(b, c + w.n * 0.12, (0.06, 0.06, 0.06), t)
        for k in range(4):                                   # spokes
            a = k * math.pi / 4
            d = w.a * math.cos(a) + V((0, 0, math.sin(a)))
            rod(b, c + w.n * 0.13 - d * r, c + w.n * 0.13 + d * r, 0.025, t, 4)
        w.slab(b, u - r - 0.1, u + r + 0.1, v0 - 0.08, v0 + 0.02, 0.0, 0.22, t, 0.02)   # a sill
        sill = v0 + 0.02
    else:
        hw = width / 2
        w.slab(glass, u - hw, u + hw, v0, v0 + height, 0.0, 0.03, (1, 1, 1), 0.0)
        w.slab(b, u - hw - 0.1, u - hw, v0 - 0.02, v0 + height + 0.02, 0.0, 0.1, t)
        w.slab(b, u + hw, u + hw + 0.1, v0 - 0.02, v0 + height + 0.02, 0.0, 0.1, t)
        w.slab(b, u - hw - 0.14, u + hw + 0.14, v0 + height, v0 + height + 0.12, 0.0, 0.12, t)
        w.slab(b, u - hw - 0.16, u + hw + 0.16, v0 - 0.1, v0, 0.0, 0.24, t)            # sill
        w.slab(b, u - 0.03, u + 0.03, v0, v0 + height, 0.03, 0.06, t, 0.0)            # muntins
        for k in range(1, 3 if kind == "tall" else 2):
            vv = v0 + height * k / (3 if kind == "tall" else 2)
            w.slab(b, u - hw, u + hw, vv - 0.03, vv + 0.03, 0.03, 0.06, t, 0.0)
        sill = v0
        r = hw
    for k in range(3):                                        # little pots on the sill
        at = w.p(u + (k - 1) * r * 0.6, sill, 0.14)
        pot_plant(b, at, 0.06, 3, k != 1)
    if curtains:
        top = v0 + (height if kind != "round" else width) + 0.25
        rod(b, w.p(u - r - 0.45, top, 0.16), w.p(u + r + 0.45, top, 0.16), 0.025, IRON, 6)
        for side in (-1, 1):
            for k in range(3):                                # folds
                uu = u + side * (r + 0.12 + k * 0.1)
                w.slab(b, uu - 0.055, uu + 0.055, v0 - 0.25, top - 0.02, 0.08 + (k % 2) * 0.04, 0.12 + (k % 2) * 0.04, s["cloth"], 0.05)
            tie = w.p(u + side * (r + 0.22), v0 + 0.45, 0.2)
            box(b, tie, (0.3, 0.06, 0.06) if abs(w.a.x) > 0.5 else (0.06, 0.3, 0.06), GOLD, 0.0)


def hearth(b, w, u):
    """A stone fireplace on the back wall: a slab, stacked jambs, a timber mantel with candles and
    jars, a chimney breast, logs with flames, a pot on a hook, and firewood beside it."""
    box(b, w.p(u, 0.03, 0.55), (2.3, 1.1, 0.08), STONE[3], 0.03)                        # hearth slab
    for k in range(5):
        box(b, w.p(u - 1.0 + k * 0.5, 0.07, 1.02), (0.46, 0.14, 0.04), rnd.choice(STONE), 0.05)
    for side in (-1, 1):                                                                 # jambs
        for row in range(5):
            wd = rnd.uniform(0.42, 0.52)
            box(b, w.p(u + side * (0.78 + rnd.uniform(-0.03, 0.03)), 0.12 + row * 0.26 + 0.12, 0.34), (wd, 0.62, 0.24), rnd.choice(STONE), 0.05)
    box(b, w.p(u, 0.6, 0.2), (1.2, 0.3, 1.1), (0.12, 0.1, 0.1), 0.0)                    # firebox
    soft(b, cube(b, w.p(u, 1.48, 0.36), (2.3, 0.7, 0.2)), WOOD_D, 0.03)                  # mantel
    for row in range(6):                                                                 # chimney breast
        v = 1.6 + row * 0.28
        if v > w.h(u) - 0.25:
            break
        x = u - 0.8 + (0.15 if row % 2 else 0.0)
        while x < u + 0.75:
            wd = rnd.uniform(0.34, 0.5)
            wd = min(wd, u + 0.8 - x)
            box(b, w.p(x + wd / 2, v + 0.13, 0.2 - row * 0.01), (wd - 0.03, 0.4, 0.25), rnd.choice(STONE), 0.05)
            x += wd
    # Logs, flames, embers.
    base = w.p(u, 0.12, 0.45)
    rod(b, base + V((-0.35, 0, 0.06)), base + V((0.35, 0.1, 0.06)), 0.07, (0.3, 0.2, 0.14), 6)
    rod(b, base + V((-0.3, 0.12, 0.1)), base + V((0.3, -0.06, 0.12)), 0.065, (0.36, 0.24, 0.16), 6)
    for k in range(5):
        ball(b, base + V((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.1, 0.1), 0.03)), (0.05, 0.05, 0.025), (1.0, 0.42, 0.14), 4, 3, "Glow")
    flame(b, base + V((-0.1, 0, 0.12)), 1.6)
    flame(b, base + V((0.16, 0.02, 0.12)), 1.2)
    rod(b, w.p(u - 0.3, 1.2, 0.3), w.p(u - 0.3, 0.95, 0.3), 0.012, IRON, 4)             # pot on a hook
    rod(b, w.p(u - 0.3, 1.2, 0.3), w.p(u, 1.2, 0.3), 0.012, IRON, 4)
    ball(b, w.p(u - 0.3, 0.82, 0.3), (0.2, 0.2, 0.16), IRON, 8, 5)
    # On the mantel: candles, jars, a little clock.
    top = 1.58
    candle(b, w.p(u - 0.9, top, 0.4))
    candle(b, w.p(u - 0.75, top, 0.42), 0.1)
    for k, col in enumerate([(0.55, 0.7, 0.62), (0.8, 0.5, 0.3), (0.62, 0.55, 0.78)]):
        cyl(b, w.p(u - 0.35 + k * 0.2, top, 0.4), 0.06, 0.16 + k * 0.03, col, 8)
    soft(b, cube(b, w.p(u + 0.55, top + 0.15, 0.4), (0.26, 0.14, 0.3)), WOOD[2], 0.02)
    box(b, w.p(u + 0.55, top + 0.2, 0.47), (0.17, 0.01, 0.17), CREAM, 0.0)
    candle(b, w.p(u + 0.9, top, 0.42))
    # Firewood stacked beside it.
    for row in range(3):
        for k in range(4 - row):
            c = w.p(u - 1.55 - k * 0.2 - row * 0.1, 0.12 + row * 0.17, 0.4)
            rod(b, c - w.n * 0.3, c + w.n * 0.3, 0.085, rnd.choice([(0.5, 0.34, 0.22), (0.56, 0.38, 0.24), (0.46, 0.31, 0.2)]), 6)
            cyl_end = c + w.n * 0.3
            paint(b, b.new_faces(lambda cyl_end=cyl_end: rk.tube(b.bm, [cyl_end, cyl_end + w.n * 0.01], [(0.07, 0.07)] * 2, ref=V((0, 0, 1)), seg=6)), (0.86, 0.7, 0.5), 0.03)


def shelf_wall(b, s, w, u):
    """Two shelves with jars, bowls and books, pegs with hanging herbs and a lantern below."""
    for v in (1.35, 1.85):
        w.slab(b, u - 0.9, u + 0.9, v - 0.05, v, 0.0, 0.3, s["timber"], 0.02)
        for side in (-1, 1):
            rod(b, w.p(u + side * 0.7, v - 0.05, 0.02), w.p(u + side * 0.7, v - 0.25, 0.02), 0.03, s["timber"], 4)
        x = u - 0.82
        while x < u + 0.75:
            kind = rnd.random()
            c = w.p(x, v, 0.15)
            if kind < 0.35:
                cyl(b, c, 0.06, rnd.uniform(0.12, 0.2), rnd.choice([(0.55, 0.72, 0.64), (0.82, 0.6, 0.36), (0.66, 0.58, 0.8), (0.9, 0.86, 0.78)]), 8)
                x += 0.17
            elif kind < 0.55:
                cyl(b, c, 0.1, 0.08, (0.78, 0.5, 0.36), 10, r_top=0.14)
                x += 0.3
            else:
                for k in range(rnd.randint(2, 4)):
                    h = rnd.uniform(0.2, 0.28)
                    box(b, w.p(x + k * 0.06, v + h / 2, 0.14), (0.2, 0.05, h) if abs(w.a.y) > 0.5 else (0.05, 0.2, h), rnd.choice(BOOKS), 0.03)
                x += 0.08 + 0.06 * 3
    for k in range(4):                                     # herbs on pegs
        pu = u - 0.6 + k * 0.4
        rod(b, w.p(pu, 1.05, 0.0), w.p(pu, 1.05, 0.12), 0.02, s["timber"], 4)
        for j in range(3):
            clump(b, w.p(pu + rnd.uniform(-0.04, 0.04), 0.9 - j * 0.07, 0.12), 0.05, 1, rnd, rnd.choice(LEAF + [(0.6, 0.62, 0.36)]), "Prop", 0.8)


def picture(b, w, u, v):
    w.slab(b, u - 0.42, u + 0.42, v - 0.3, v + 0.3, 0.0, 0.05, GOLD, 0.02)
    w.slab(b, u - 0.36, u + 0.36, v - 0.02, v + 0.24, 0.05, 0.06, (0.62, 0.78, 0.9), 0.0)          # sky
    w.slab(b, u - 0.36, u + 0.36, v - 0.24, v - 0.02, 0.05, 0.06, (0.46, 0.66, 0.36), 0.0)         # meadow
    w.slab(b, u - 0.3, u + 0.05, v - 0.08, v + 0.08, 0.06, 0.065, (0.36, 0.54, 0.3), 0.0)          # a hill
    w.slab(b, u + 0.18, u + 0.26, v + 0.1, v + 0.18, 0.06, 0.07, (1.0, 0.86, 0.5), 0.0)            # the sun


def sconce(b, w, u, v):
    w.slab(b, u - 0.08, u + 0.08, v - 0.2, v + 0.12, 0.0, 0.04, IRON, 0.0)
    rod(b, w.p(u, v - 0.1, 0.04), w.p(u, v - 0.1, 0.2), 0.015, IRON, 4)
    cyl(b, w.p(u, v - 0.14, 0.22), 0.05, 0.03, GOLD, 8)
    ball(b, w.p(u, v + 0.02, 0.22), (0.05, 0.05, 0.1), FLAME[1], 5, 3, "Glow")


def room(name, layout="hearth"):
    s = STYLES[name]
    b = Builder(["Prop", "Glow"])
    glass = Builder(["Prop"])
    floor(b, s)
    slope = lambda u: H_FRONT + (H_BACK - H_FRONT) * min(max((u - 0.0) / (2 * IY), 0.0), 1.0)
    back = Wall(V((-IX, IY, 0)), V((1, 0, 0)), V((0, -1, 0)), lambda u: H_BACK)
    west = Wall(V((-IX, -IY, 0)), V((0, 1, 0)), V((1, 0, 0)), slope)
    east = Wall(V((IX, -IY, 0)), V((0, 1, 0)), V((-1, 0, 0)), slope)
    dress_wall(b, s, back, -T, 2 * IX + T, [0.11, 3.7, 6.9, 2 * IX - 0.11], s["walls"] == "planks")
    dress_wall(b, s, west, -T, 2 * IY, [0.11, 3.3, 2 * IY - 0.11], s["walls"] == "planks")
    dress_wall(b, s, east, -T, 2 * IY, [0.11, 3.3, 2 * IY - 0.11], s["walls"] == "planks")
    # The low front wall, either side of the doorway, capped with a timber rail.
    front = Wall(V((-IX - T, -IY, 0)), V((1, 0, 0)), V((0, 1, 0)), lambda u: KNEE)
    for u0, u1 in ((0.0, IX + T - DOOR), (IX + T + DOOR, 2 * (IX + T))):
        front.slab(b, u0, u1, 0.0, KNEE, -T, 0.0, s["plaster"], 0.02)
        front.slab(b, u0, u1, KNEE, KNEE + 0.1, -T - 0.04, 0.04, s["timber"], 0.02)
        front.slab(b, u0, u1, 0.0, 0.14, 0.0, 0.05, s["timber"], 0.0)
    for side in (-1, 1):                                                   # door posts with lanterns
        box(b, V((side * (DOOR + 0.1), -IY - T / 2, 0.55)), (0.2, T + 0.12, 1.1), s["timber"], 0.02)
        cyl(b, V((side * (DOOR + 0.1), -IY - T / 2, 1.1)), 0.09, 0.04, IRON, 8)
        ball(b, V((side * (DOOR + 0.1), -IY - T / 2, 1.24)), (0.08, 0.08, 0.11), FLAME[1], 6, 4, "Glow")
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            rod(b, V((side * (DOOR + 0.1) + math.cos(a) * 0.09, -IY - T / 2 + math.sin(a) * 0.09, 1.12)),
                V((side * (DOOR + 0.1) + math.cos(a) * 0.09, -IY - T / 2 + math.sin(a) * 0.09, 1.36)), 0.012, IRON, 4)
        paint(b, b.new_faces(lambda side=side: rk.tube(b.bm, [V((side * (DOOR + 0.1), -IY - T / 2, 1.36)), V((side * (DOOR + 0.1), -IY - T / 2, 1.48))],
                                                       [(0.13, 0.13), (0.01, 0.01)], seg=4)), IRON, 0.0)
    box(b, V((0, -IY - T / 2, -0.01)), (2 * DOOR, T + 0.1, 0.06), STONE[0], 0.03)         # threshold
    # Doormat: woven, with stripes.
    box(b, V((0, -IY + 0.5, 0.01)), (1.2, 0.72, 0.02), (0.62, 0.46, 0.3), 0.03)
    for k in range(3):
        box(b, V((0, -IY + 0.3 + k * 0.2, 0.022)), (1.1, 0.06, 0.01), (0.44, 0.3, 0.2), 0.0)
    if layout == "bright":
        # The back wall: two big windows with a picture between; the fireplace on the east wall.
        window(b, glass, s, back, IX - 2.3, 0.95, 1.4, 1.45)
        window(b, glass, s, back, IX + 2.3, 0.95, 1.4, 1.45)
        picture(b, back, IX, 2.05)
        sconce(b, back, IX - 0.75, 2.1)
        sconce(b, back, IX + 0.75, 2.1)
        hearth(b, east, 2 * IY - 2.2)
    else:
        # The back wall: hearth left, a picture and a sconce, the big window right.
        hearth(b, back, IX - 2.4)
        picture(b, back, IX + 0.35, 2.05)
        sconce(b, back, IX + 1.05, 2.1)
        sconce(b, back, IX - 0.35, 2.1)
        window(b, glass, s, back, IX + 2.55, 1.0, 1.3, 1.35)
        # East wall: a smaller window near the back.
        window(b, glass, s, east, 2 * IY - 1.6, 1.05, 0.9, 0.9, curtains=True)
    # West wall: shelves with herbs, a broom.
    shelf_wall(b, s, west, IY + 0.4)
    rod(b, west.p(1.2, 0.05, 0.25), west.p(1.35, 1.45, 0.08), 0.025, (0.62, 0.44, 0.28), 5)
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [west.p(1.2, 0.02, 0.26), west.p(1.22, 0.32, 0.24)], [(0.14, 0.05), (0.04, 0.03)], ref=V((0, 1, 0)), seg=6)), (0.86, 0.72, 0.4), 0.05)
    return {"Room": b, "Windows": glass}


# --- furniture ----------------------------------------------------------------------------

def bed():
    b = Builder(["Prop"])
    patch = [(0.82, 0.36, 0.3), (0.95, 0.85, 0.6), (0.36, 0.52, 0.6), (0.88, 0.62, 0.34), (0.56, 0.66, 0.44)]
    for x in (-0.56, 0.56):
        soft(b, cube(b, V((x, 0, 0.3)), (0.1, 2.0, 0.2)), WOOD[0])
    for x in (-0.58, 0.58):
        soft(b, cube(b, V((x, 1.0, 0.58)), (0.13, 0.13, 1.16)), WOOD_D)
        soft(b, cube(b, V((x, -1.0, 0.38)), (0.13, 0.13, 0.76)), WOOD_D)
        ball(b, V((x, 1.0, 1.2)), (0.08, 0.08, 0.07), WOOD_D, 6, 4)
    soft(b, cube(b, V((0, 1.02, 0.78)), (1.04, 0.07, 0.6)), WOOD[2])
    soft(b, cube(b, V((0, 1.02, 1.1)), (1.2, 0.1, 0.09)), WOOD_D)
    soft(b, cube(b, V((0, -1.02, 0.52)), (1.04, 0.07, 0.3)), WOOD[2])
    soft(b, cube(b, V((0, 0, 0.47)), (1.04, 1.96, 0.18)), CREAM, 0.06, 2)
    for i in range(3):                                          # the patchwork quilt
        for j in range(5):
            soft(b, cube(b, V((-0.36 + i * 0.36, -0.9 + j * 0.28 + 0.14, 0.585)), (0.355, 0.275, 0.06)), patch[(i * 2 + j) % len(patch)], 0.02, 1, var=0.02)
    for x in (-0.555, 0.555):
        soft(b, cube(b, V((x, -0.36, 0.49)), (0.04, 1.4, 0.2)), patch[0], 0.015)
    soft(b, cube(b, V((0, -0.78, 0.64)), (1.08, 0.28, 0.07)), (0.34, 0.46, 0.56), 0.03)
    soft(b, cube(b, V((0, 0.72, 0.62)), (0.82, 0.36, 0.14)), (0.98, 0.97, 0.94), 0.06, 2)
    return b


def table():
    b = Builder(["Prop", "Glow"])
    soft(b, cube(b, V((0, 0, 0.74)), (1.6, 0.92, 0.08)), WOOD[2], 0.03)
    for x in (-0.66, 0.66):
        for y in (-0.33, 0.33):
            soft(b, cube(b, V((x, y, 0.36)), (0.1, 0.1, 0.72)), WOOD_D, 0.02)
        soft(b, cube(b, V((x, 0, 0.18)), (0.06, 0.62, 0.06)), WOOD_D, 0.01)
    soft(b, cube(b, V((0, 0, 0.18)), (1.3, 0.06, 0.06)), WOOD_D, 0.01)
    box(b, V((0, 0, 0.785)), (0.46, 0.96, 0.012), (0.86, 0.36, 0.3), 0.0)          # a runner
    box(b, V((0, 0, 0.792)), (0.36, 0.96, 0.006), (0.97, 0.9, 0.8), 0.0)
    candle(b, V((0.1, 0.12, 0.79)), 0.18)
    cyl(b, V((-0.45, 0.05, 0.78)), 0.12, 0.08, (0.8, 0.62, 0.42), 10, r_top=0.18)     # a bowl of apples
    for k in range(4):
        a = k * math.tau / 4
        ball(b, V((-0.45 + math.cos(a) * 0.07, 0.05 + math.sin(a) * 0.07, 0.9)), (0.06, 0.06, 0.055), (0.86, 0.22, 0.16) if k != 2 else (0.6, 0.78, 0.3), 6, 4)
    cyl(b, V((0.5, -0.2, 0.78)), 0.05, 0.1, CREAM, 8)                                  # a mug
    return b


def chair():
    b = Builder(["Prop"])
    soft(b, cube(b, V((0, 0, 0.46)), (0.48, 0.46, 0.06)), WOOD[0])
    for x in (-0.2, 0.2):
        for y in (-0.18, 0.18):
            soft(b, cube(b, V((x, y, 0.22)), (0.06, 0.06, 0.44)), WOOD_D, 0.015)
        soft(b, cube(b, V((x, 0.2, 0.74)), (0.06, 0.06, 0.56)), WOOD_D, 0.015)
    for z in (0.78, 0.98):
        soft(b, cube(b, V((0, 0.2, z)), (0.44, 0.05, 0.08)), WOOD[2], 0.015)
    for x in (-0.08, 0.08):
        soft(b, cube(b, V((x, 0.2, 0.7)), (0.04, 0.035, 0.44)), WOOD[1], 0.01)
    soft(b, cube(b, V((0, -0.02, 0.52)), (0.4, 0.38, 0.06)), (0.86, 0.36, 0.3), 0.03, 2)
    return b


def stool():
    b = Builder(["Prop"])
    cyl(b, V((0, 0, 0.44)), 0.21, 0.06, WOOD[2], 10)
    for k in range(3):
        a = k * math.tau / 3
        rod(b, V((math.cos(a) * 0.13, math.sin(a) * 0.13, 0.44)), V((math.cos(a) * 0.19, math.sin(a) * 0.19, 0.0)), 0.03, WOOD_D, 5)
    return b


def bookshelf():
    b = Builder(["Prop"])
    W, D, H = 1.2, 0.4, 2.0
    soft(b, cube(b, V((0, D / 2 - 0.02, H / 2)), (W, 0.04, H)), WOOD[1], 0.01)
    for x in (-W / 2 + 0.04, W / 2 - 0.04):
        soft(b, cube(b, V((x, 0, H / 2)), (0.08, D, H)), WOOD_D, 0.02)
    for z in (0.06, 0.52, 0.98, 1.44, H - 0.04):
        soft(b, cube(b, V((0, 0, z)), (W, D, 0.06)), WOOD[0], 0.015)
    soft(b, cube(b, V((0, -0.02, H + 0.04)), (W + 0.1, D + 0.06, 0.06)), WOOD_D, 0.02)
    for z in (0.09, 0.55, 1.01, 1.47):
        x = -W / 2 + 0.1
        while x < W / 2 - 0.12:
            if rnd.random() < 0.12:                                  # a gap with a jar or a leaning book
                cyl(b, V((x + 0.06, 0, z)), 0.06, 0.14, rnd.choice([(0.55, 0.72, 0.64), (0.82, 0.6, 0.36)]), 8)
                x += 0.16
                continue
            w = rnd.uniform(0.045, 0.085)
            h = rnd.uniform(0.25, 0.36)
            box(b, V((x + w / 2, 0.01, z + h / 2)), (w - 0.006, 0.26, h), rnd.choice(BOOKS), 0.04)
            x += w
    pot_plant(b, V((0.3, 0, H + 0.07)), 0.1, 5, False)
    for k in range(3):
        box(b, V((-0.3, 0, H + 0.1 + k * 0.05)), (0.3 - k * 0.03, 0.22, 0.045), rnd.choice(BOOKS), 0.02)
    return b


def wardrobe():
    b = Builder(["Prop"])
    W, D, H = 1.1, 0.6, 2.1
    soft(b, cube(b, V((0, 0, H / 2 + 0.06)), (W, D, H - 0.1)), WOOD[1], 0.03)
    soft(b, cube(b, V((0, -0.02, H + 0.05)), (W + 0.12, D + 0.1, 0.12)), WOOD_D, 0.03)
    soft(b, cube(b, V((0, -0.02, H + 0.15)), (W - 0.1, D, 0.1)), WOOD[2], 0.02)
    for x in (-W / 2 + 0.08, W / 2 - 0.08):
        for y in (-D / 2 + 0.06, D / 2 - 0.06):
            ball(b, V((x, y, 0.05)), (0.06, 0.06, 0.06), WOOD_D, 6, 3)
    for side in (-1, 1):
        cx = side * W / 4
        soft(b, cube(b, V((cx, -D / 2 - 0.01, H / 2 + 0.06)), (W / 2 - 0.05, 0.03, H - 0.24)), WOOD[0], 0.01)
        for z0, z1 in ((0.3, 1.0), (1.12, 1.9)):
            soft(b, cube(b, V((cx, -D / 2 - 0.03, (z0 + z1) / 2)), (W / 2 - 0.2, 0.02, z1 - z0)), WOOD[2], 0.01)
        ball(b, V((side * 0.06, -D / 2 - 0.05, 1.08)), (0.03, 0.03, 0.03), GOLD, 6, 4)
    return b


def dresser():
    b = Builder(["Prop"])
    W, D = 1.4, 0.5
    soft(b, cube(b, V((0, 0, 0.45)), (W, D, 0.86)), WOOD[0], 0.03)
    soft(b, cube(b, V((0, -0.02, 0.9)), (W + 0.08, D + 0.06, 0.06)), WOOD_D, 0.02)
    for k in range(3):                                           # drawers
        soft(b, cube(b, V((-W / 3 + k * W / 3, -D / 2 - 0.01, 0.72)), (W / 3 - 0.06, 0.02, 0.2)), WOOD[2], 0.01)
        ball(b, V((-W / 3 + k * W / 3, -D / 2 - 0.04, 0.72)), (0.025, 0.025, 0.025), GOLD, 6, 4)
    for side in (-1, 1):                                         # cupboard doors
        soft(b, cube(b, V((side * W / 4, -D / 2 - 0.01, 0.34)), (W / 2 - 0.08, 0.02, 0.5)), WOOD[2], 0.01)
        ball(b, V((side * 0.08, -D / 2 - 0.04, 0.42)), (0.025, 0.025, 0.025), GOLD, 6, 4)
    soft(b, cube(b, V((0, D / 2 - 0.05, 1.45)), (W, 0.05, 1.1)), WOOD[1], 0.01)   # plate rack
    for x in (-W / 2 + 0.04, W / 2 - 0.04):
        soft(b, cube(b, V((x, D / 2 - 0.15, 1.45)), (0.06, 0.24, 1.1)), WOOD_D, 0.01)
    for z in (1.4, 1.95):
        soft(b, cube(b, V((0, D / 2 - 0.15, z)), (W, 0.26, 0.05)), WOOD_D, 0.01)
    for k in range(5):                                           # plates standing on the lower shelf
        c = V((-0.5 + k * 0.25, D / 2 - 0.1, 1.58))
        paint(b, b.new_faces(lambda c=c: rk.tube(b.bm, [c, c + V((0, -0.02, 0))], [(0.11, 0.11)] * 2, ref=V((1, 0, 0)), seg=10)),
              [(0.95, 0.93, 0.88), (0.46, 0.6, 0.76)][k % 2], 0.02)
    for k in range(4):                                           # cups on the top shelf
        cyl(b, V((-0.45 + k * 0.3, D / 2 - 0.15, 1.975)), 0.05, 0.09, [(0.86, 0.4, 0.32), CREAM, (0.4, 0.56, 0.66), CREAM][k], 8)
    cyl(b, V((0.4, -0.02, 0.93)), 0.1, 0.2, (0.72, 0.5, 0.34), 10, r_top=0.07)
    pot_plant(b, V((-0.45, -0.02, 0.93)), 0.08, 4)
    return b


def rug_round():
    b = Builder(["Prop"])
    bands = [(0.72, 0.36, 0.28), (0.94, 0.84, 0.62), (0.4, 0.52, 0.6), (0.9, 0.62, 0.34), (0.72, 0.36, 0.28), (0.96, 0.9, 0.76)]
    for k, col in enumerate(bands):
        r = 1.2 - k * 0.19
        cyl(b, V((0, 0, 0)), r, 0.015 + k * 0.004, col, 18, var=0.015)
    return b


def rug_long():
    b = Builder(["Prop"])
    box(b, V((0, 0, 0.008)), (2.4, 1.6, 0.016), (0.36, 0.46, 0.58), 0.02)
    box(b, V((0, 0, 0.012)), (2.2, 1.4, 0.016), (0.92, 0.84, 0.66), 0.02)
    box(b, V((0, 0, 0.016)), (2.0, 1.2, 0.016), (0.72, 0.34, 0.28), 0.02)
    for x in (-0.6, 0.0, 0.6):                                      # diamonds
        box(b, V((x, 0, 0.022)), (0.36, 0.36, 0.01), (0.94, 0.78, 0.46), 0.0, rot=Euler((0, 0, math.pi / 4)))
        box(b, V((x, 0, 0.026)), (0.16, 0.16, 0.01), (0.36, 0.46, 0.58), 0.0, rot=Euler((0, 0, math.pi / 4)))
    for side in (-1, 1):                                             # tassels
        for k in range(9):
            box(b, V((side * 1.25, -0.72 + k * 0.18, 0.006)), (0.12, 0.03, 0.012), (0.92, 0.84, 0.66), 0.03)
    return b


def plant():
    b = Builder(["Prop"])
    cyl(b, V((0, 0, 0)), 0.2, 0.42, (0.74, 0.42, 0.3), 10, r_top=0.26)
    cyl(b, V((0, 0, 0.42)), 0.28, 0.06, (0.66, 0.36, 0.26), 10)
    cyl(b, V((0, 0, 0.44)), 0.24, 0.03, (0.3, 0.22, 0.16), 10)
    for k in range(7):                                             # a leafy crown on a few stems
        a = k * math.tau / 7 + rnd.uniform(-0.2, 0.2)
        top = V((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.9 + rnd.uniform(0, 0.45)))
        rod(b, V((0, 0, 0.44)), top, 0.02, (0.34, 0.46, 0.24), 4)
        clump(b, top, rnd.uniform(0.16, 0.22), 1, rnd, rnd.choice(LEAF), "Prop", 0.7)
    clump(b, V((0, 0, 1.35)), 0.24, 1, rnd, LEAF[2], "Prop", 0.8)
    return b


def trophy():
    """A stag's crown on a dark shield-shaped plaque, hung high on the wall (from a hunt: Crown Antlers)."""
    b = Builder(["Prop"])
    bone = [(0.93, 0.86, 0.72), (0.88, 0.8, 0.66)]
    box(b, V((0, 0.03, 1.8)), (0.46, 0.06, 0.5), WOOD_D, 0.02)
    box(b, V((0, 0.0, 1.8)), (0.36, 0.04, 0.4), (0.5, 0.32, 0.2), 0.02)
    ball(b, V((0, -0.06, 1.86)), (0.16, 0.12, 0.2), (0.82, 0.44, 0.2), 6, 4)          # the brow, coat-coloured
    for s in (1, -1):
        pts = [V((s * 0.06, -0.1, 1.95)), V((s * 0.2, -0.12, 2.08)), V((s * 0.36, -0.14, 2.26)), V((s * 0.43, -0.15, 2.46)),
               V((s * 0.37, -0.16, 2.62)), V((s * 0.24, -0.16, 2.7))]
        for i in range(len(pts) - 1):
            rod(b, pts[i], pts[i + 1], 0.035 - i * 0.005, rnd.choice(bone), 5)
        for i, d in ((1, V((s * 0.02, -0.08, 0.14))), (2, V((-s * 0.04, -0.06, 0.18))), (3, V((s * 0.06, -0.05, 0.16)))):
            rod(b, pts[i], pts[i] + d, 0.018, rnd.choice(bone), 4)
    return b


def lamp():
    b = Builder(["Prop", "Glow"])
    cyl(b, V((0, 0, 0)), 0.2, 0.05, IRON, 8, r_top=0.16)
    rod(b, V((0, 0, 0.05)), V((0, 0, 1.3)), 0.03, IRON, 6)
    cyl(b, V((0, 0, 1.3)), 0.14, 0.03, IRON, 8)
    ball(b, V((0, 0, 1.46)), (0.1, 0.1, 0.14), FLAME[1], 6, 4, "Glow")
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        rod(b, V((math.cos(a) * 0.13, math.sin(a) * 0.13, 1.33)), V((math.cos(a) * 0.13, math.sin(a) * 0.13, 1.62)), 0.012, IRON, 4)
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, 1.62)), V((0, 0, 1.8))], [(0.2, 0.2), (0.02, 0.02)], seg=6)), IRON, 0.0)
    ball(b, V((0, 0, 1.84)), (0.04, 0.04, 0.04), GOLD, 6, 4)
    return b


def trunk():
    b = Builder(["Prop"])
    W, D, H = 0.9, 0.55, 0.42
    soft(b, cube(b, V((0, 0, H / 2 + 0.03)), (W, D, H)), WOOD[1], 0.02)
    faces = b.new_faces(lambda: rk.tube(b.bm, [V((-W / 2, 0, H + 0.03)), V((W / 2, 0, H + 0.03))], [(0.16, D / 2)] * 2, ref=V((0, 0, 1)), seg=10))
    for f in faces:
        for v in f.verts:
            v.co.z = max(v.co.z, H + 0.03)
    paint(b, faces, WOOD[2], 0.03)
    for x in (-W / 2 + 0.14, W / 2 - 0.14):
        box(b, V((x, 0, H / 2 + 0.03)), (0.07, D + 0.02, H + 0.01), IRON, 0.0)
    box(b, V((0, -D / 2 - 0.02, H - 0.02)), (0.14, 0.04, 0.16), GOLD, 0.0)
    for x in (-W / 2 + 0.05, W / 2 - 0.05):
        box(b, V((x, 0, H / 2 + 0.03)), (0.05, D + 0.02, H), IRON, 0.0)
    return b


def armchair():
    b = Builder(["Prop"])
    fab = (0.44, 0.58, 0.42)
    soft(b, cube(b, V((0, 0, 0.27)), (0.9, 0.82, 0.3)), fab, 0.06, 2)
    soft(b, cube(b, V((0, 0.33, 0.72)), (0.86, 0.22, 0.72)), fab, 0.09, 2)
    for x in (-0.38, 0.38):
        soft(b, cube(b, V((x, 0, 0.56)), (0.16, 0.82, 0.3)), fab, 0.07, 2)
    soft(b, cube(b, V((0, -0.06, 0.47)), (0.6, 0.64, 0.14)), (0.96, 0.9, 0.78), 0.06, 2)
    soft(b, cube(b, V((0.12, 0.18, 0.66)), (0.32, 0.12, 0.3), Euler((0.3, 0.2, 0))), (0.9, 0.56, 0.3), 0.05, 2)
    for x in (-0.36, 0.36):
        for y in (-0.32, 0.32):
            cyl(b, V((x, y, 0.0)), 0.04, 0.12, WOOD_D, 6)
    box(b, V((-0.1, -0.2, 0.55)), (0.5, 0.5, 0.02), (0.36, 0.46, 0.58), 0.0, rot=Euler((0, 0, 0.3)))   # a folded throw
    return b


def mailbox():
    b = Builder(["Prop"])
    soft(b, cube(b, V((0, 0, 0.55)), (0.12, 0.12, 1.1)), WOOD_D, 0.02)
    soft(b, cube(b, V((0, 0, 1.12)), (0.36, 0.5, 0.2)), (0.36, 0.5, 0.48), 0.02)
    faces = b.new_faces(lambda: rk.tube(b.bm, [V((0, -0.25, 1.22)), V((0, 0.25, 1.22))], [(0.18, 0.18)] * 2, ref=V((1, 0, 0)), seg=10))
    for f in faces:
        for v in f.verts:
            v.co.z = max(v.co.z, 1.22)
    paint(b, faces, (0.4, 0.56, 0.54), 0.02)
    soft(b, cube(b, V((0, -0.26, 1.2)), (0.3, 0.02, 0.3)), (0.3, 0.44, 0.42), 0.01)
    soft(b, cube(b, V((0.2, 0.05, 1.3)), (0.03, 0.04, 0.3)), IRON, 0.005)
    soft(b, cube(b, V((0.2, 0.05, 1.42)), (0.03, 0.18, 0.1)), (0.86, 0.3, 0.24), 0.01)
    for k in range(4):
        clump(b, V((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), 0.1)), 0.13, 1, rnd, rnd.choice(LEAF), "Prop", 0.8)
    clump(b, V((0.12, -0.12, 0.2)), 0.05, 1, rnd, BLOOMS[1], "Prop", 0.8)
    return b


# --- export -------------------------------------------------------------------------------

def export_multi(name, parts):
    """Exports one or more builders as named objects in one .glb."""
    objs = []
    for obj_name, b in parts.items():
        bm = b.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new(obj_name)
        bm.to_mesh(mesh)
        bm.free()
        for m in b.mats:
            mesh.materials.append(rk.MATERIALS[m])
        for p in mesh.polygons:
            p.use_smooth = False
        obj = bpy.data.objects.new(obj_name, mesh)
        bpy.context.collection.objects.link(obj)
        objs.append(obj)
        print("PART", name, obj_name, "tris", sum(len(p.vertices) - 2 for p in mesh.polygons))
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              use_selection=True, export_vertex_color="NONE")
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Prop": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)
os.makedirs(OUT, exist_ok=True)
ONLY = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else ""
BUILD = {"room_" + h: (lambda h=h: room(h)) for h in STYLES}
BUILD.update({"room_%s_bright" % h: (lambda h=h: room(h, "bright")) for h in STYLES})
for n, fn in {"bed": bed, "table": table, "chair": chair, "stool": stool, "bookshelf": bookshelf, "wardrobe": wardrobe,
              "dresser": dresser, "rug_round": rug_round, "rug_long": rug_long, "plant": plant, "lamp": lamp,
              "trunk": trunk, "armchair": armchair, "trophy": trophy}.items():
    BUILD["furn_" + n] = (lambda fn=fn: {"Piece": fn()})
BUILD["mailbox"] = lambda: {"Piece": mailbox()}
for n, fn in BUILD.items():
    if ONLY and n != ONLY:
        continue
    rnd.seed(sum(map(ord, n)))
    export_multi(n, fn())

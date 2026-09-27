"""Builds our faceted low-poly trees, pines, bushes, a dead tree and a stump (solid, no
see-through leaves, so cheap on phones). Style: flat-shaded clumps in several distinct greens,
angular twisting trunks with branches reaching out to the clumps, drooping layered pines.
Each is exported to game/assets/nature/<name>.glb.

Leaf colours are stored in the texture coordinates (UV = red, green; UV2.x = blue, linear), so
every clump can have its own shade. (Vertex colours came through Godot's import garbled.) The
game's foliage shader reads them and adds a small per-tree tint and a wind sway.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_trees.py
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
from lowpoly import Builder, clump, limb, zigzag, blade, export as export_to  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "nature")

COLORS = {
    "Trunk": (0.46, 0.31, 0.21),
    "Canopy": (1.0, 1.0, 1.0),
    "Needles": (1.0, 1.0, 1.0),
    "Blossom": (1.0, 1.0, 1.0),
    "Fruit": (0.82, 0.18, 0.14),
    "Flower": (0.92, 0.42, 0.55),
    "Stump": (0.66, 0.52, 0.36),
    "Stone": (1.0, 1.0, 1.0),
    "Grass": (1.0, 1.0, 1.0),
    "Plant": (1.0, 1.0, 1.0),
}
GREYS = [(0.62, 0.62, 0.6), (0.55, 0.56, 0.55), (0.68, 0.67, 0.63), (0.5, 0.51, 0.52)]
GRASS = [(0.52, 0.7, 0.32), (0.45, 0.65, 0.3), (0.6, 0.75, 0.36), (0.4, 0.6, 0.28)]
PETALS = [(0.95, 0.55, 0.7), (0.98, 0.85, 0.35), (0.97, 0.96, 0.92), (0.66, 0.5, 0.9), (0.5, 0.7, 0.98), (0.98, 0.5, 0.35)]
GREENS = [(0.47, 0.64, 0.28), (0.36, 0.55, 0.27), (0.56, 0.68, 0.3), (0.63, 0.72, 0.34), (0.30, 0.47, 0.26)]
PINE_GREENS = [(0.28, 0.50, 0.33), (0.34, 0.58, 0.36), (0.24, 0.43, 0.30)]
PINKS = [(0.97, 0.76, 0.82), (0.93, 0.62, 0.72), (0.99, 0.88, 0.90)]


def broad_tree(seed, kind="oak", leaf="Canopy", palette=GREENS, fruit=False):
    rnd = random.Random(seed)
    mats = ["Trunk", leaf] + (["Fruit"] if fruit else [])
    b = Builder(mats)
    shades = rnd.sample(palette, 3)
    if kind == "small":
        height, branches, clump_r = rnd.uniform(1.8, 2.3), rnd.randint(2, 3), (0.45, 0.7)
    elif kind == "round":
        height, branches, clump_r = rnd.uniform(2.0, 2.5), rnd.randint(4, 5), (0.8, 1.15)
    elif kind == "tall":
        height, branches, clump_r = rnd.uniform(2.6, 3.0), 2, (0.6, 0.85)
    else:
        height, branches, clump_r = rnd.uniform(2.0, 2.6), rnd.randint(3, 4), (0.9, 1.35)
    trunk = zigzag(V((0, 0, -0.1)), V((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), 1)), height, 4, rnd, 0.3)
    limb(b, trunk, 0.26, 0.14, seg=6)
    top = trunk[-1]
    ends = []
    for k in range(branches):
        ang = k * math.tau / branches + rnd.uniform(-0.4, 0.4)
        out = 0.55 if kind == "tall" else rnd.uniform(0.9, 1.3)
        d = V((math.cos(ang) * out, math.sin(ang) * out, rnd.uniform(0.5, 1.0)))
        start = trunk[rnd.randint(2, 3)] if kind != "small" else trunk[rnd.randint(1, 3)]
        pts = zigzag(start, d, rnd.uniform(1.1, 1.6) * (0.8 if kind == "small" else 1.0), 2, rnd, 0.2)
        limb(b, pts, 0.1, 0.05, seg=4)
        ends.append(pts[-1])
    # Clumps at the branch tips, a crown on top, and extra clumps filling the gaps.
    spots = [(e + V((0, 0, 0.3)), rnd.uniform(*clump_r)) for e in ends]
    spots.append((top + V((0, 0, clump_r[1] * 0.9)), clump_r[1] * 1.15))
    if kind == "round":
        for k in range(6):
            ang = rnd.uniform(0, math.tau)
            spots.append((top + V((math.cos(ang) * 1.3, math.sin(ang) * 1.3, rnd.uniform(0.2, 1.4))), rnd.uniform(0.7, 1.0)))
    if kind == "tall":
        for k in range(3):
            spots.append((top + V((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 1.2 + k * 0.9)), 0.85 - k * 0.15))
    for i, (c, r) in enumerate(spots):
        clump(b, c, r, 1 if r > 0.95 or kind == "oak" else 2, rnd, shades[i % len(shades)], leaf)
    if fruit:
        for k in range(10):
            c, r = rnd.choice(spots)
            d = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.8, 0.3))).normalized()
            clump(b, c + d * r * 0.95, 0.12, 1, rnd, (1, 1, 1), "Fruit", 1.0)
    return b


def pine_tree(seed):
    rnd = random.Random(seed)
    b = Builder(["Trunk", "Needles"])
    limb(b, [V((0, 0, -0.1)), V((0, 0, 0.9))], 0.2, 0.16, seg=6)
    tiers = rnd.randint(4, 5)
    z, radius, height = 0.55, rnd.uniform(1.5, 1.75), 1.25
    for t in range(tiers):
        seg = 8

        def make(z=z, radius=radius, height=height, t=t):
            bm = b.bm
            outer, inner = [], []
            for k in range(seg * 2):
                a = k * math.pi / seg + t * 0.4
                r = radius * (1.0 if k % 2 == 0 else 0.8)            # jagged drooping edge
                dz = -0.12 if k % 2 == 0 else 0.05
                outer.append(bm.verts.new(V((math.cos(a) * r, math.sin(a) * r, z + dz))))
                inner.append(bm.verts.new(V((math.cos(a) * r * 0.55, math.sin(a) * r * 0.55, z + height * 0.45))))
            tip = bm.verts.new(V((0, 0, z + height)))
            for k in range(seg * 2):
                k2 = (k + 1) % (seg * 2)
                bm.faces.new((outer[k], outer[k2], inner[k2], inner[k]))
                bm.faces.new((inner[k], inner[k2], tip))
            bm.faces.new(list(reversed(outer)))
        b.paint(b.new_faces(make), "Needles", rnd.choice(PINE_GREENS))
        z += height * 0.62
        radius *= 0.76
        height *= 0.9
    return b


def dead_tree(seed):
    rnd = random.Random(seed)
    b = Builder(["Trunk"])
    trunk = zigzag(V((0, 0, -0.1)), V((0.1, 0, 1)), 2.6, 4, rnd, 0.35)
    limb(b, trunk, 0.24, 0.1, seg=5)

    def grow(start, d, length, r, depth):
        pts = zigzag(start, d, length, 2, rnd, 0.25)
        limb(b, pts, r, r * 0.55, seg=4)
        if depth > 0:
            for k in range(2):
                nd = (d + V((rnd.uniform(-0.9, 0.9), rnd.uniform(-0.9, 0.9), rnd.uniform(0.1, 0.6)))).normalized()
                grow(pts[-1], nd, length * 0.65, r * 0.55, depth - 1)
    for k in range(3):
        ang = k * math.tau / 3 + rnd.uniform(-0.3, 0.3)
        grow(trunk[rnd.randint(2, 4)], V((math.cos(ang), math.sin(ang), 1.2)), 1.2, 0.09, 2)
    return b


def bush(seed, flowers=False):
    rnd = random.Random(seed)
    b = Builder(["Canopy"] + (["Flower"] if flowers else []))
    shades = rnd.sample(GREENS, 2)
    spots = []
    for i in range(rnd.randint(4, 6)):
        ang = rnd.uniform(0, math.tau)
        c = V((math.cos(ang) * 0.45, math.sin(ang) * 0.45, 0.35 + rnd.uniform(0, 0.25)))
        r = rnd.uniform(0.38, 0.55)
        spots.append((c, r))
        clump(b, c, r, 1, rnd, shades[i % 2], squash=0.6)
    if flowers:
        for k in range(6):
            c, r = rnd.choice(spots)
            d = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(0.2, 1))).normalized()
            clump(b, c + d * r, 0.07, 1, rnd, (1, 1, 1), "Flower", 1.0)
    return b


def rock(seed, squash=0.72):
    """A faceted boulder, each face a slightly different grey."""
    rnd = random.Random(seed)
    b = Builder(["Stone"])

    def make():
        geom = bmesh.ops.create_icosphere(b.bm, subdivisions=2, radius=1.0)
        for v in geom["verts"]:
            d = v.co.normalized()
            v.co = V((d.x * rnd.uniform(0.8, 1.15), d.y * rnd.uniform(0.8, 1.15), d.z * squash * rnd.uniform(0.85, 1.1)))
            v.co.z += 0.35
    faces = b.new_faces(make)
    for f in faces:
        b.paint([f], "Stone", rnd.choice(GREYS))
    return b


def stones(seed, count=4):
    """A few flat faceted slabs, for stepping stones along the path."""
    rnd = random.Random(seed)
    b = Builder(["Stone"])
    placed = []    # (centre, radius): slabs never overlap, or their flat tops flicker
    for i in range(count):
        for _ in range(30):
            c = V((rnd.uniform(-0.45, 0.45), rnd.uniform(-0.45, 0.45), 0.0))
            r = rnd.uniform(0.16, 0.3)
            if all((c - pc).length > r + pr + 0.03 for pc, pr in placed):
                break
        else:
            continue
        placed.append((c, r))
        top = 0.05 + len(placed) * 0.015              # each slab a little higher than the last
        seg = rnd.randint(5, 7)
        faces = b.new_faces(lambda c=c, r=r, seg=seg, top=top: rk.tube(b.bm, [c + V((0, 0, -0.04)), c + V((0, 0, top))],
                                                                       [(r, r * rnd.uniform(0.7, 1.0))] * 2, seg=seg))
        for f in faces:
            for v in f.verts:
                v.co.z = max(v.co.z, -0.01) + 0.03        # sit just above the worn path
        b.paint(faces, "Stone", rnd.choice(GREYS))
    return b


def pebbles(seed):
    rnd = random.Random(seed)
    b = Builder(["Stone"])
    for i in range(3):
        c = V((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), 0.02))
        clump(b, c, rnd.uniform(0.05, 0.09), 1, rnd, rnd.choice(GREYS), "Stone", 0.5)
    return b


def grass(seed):
    rnd = random.Random(seed)
    b = Builder(["Grass"])
    for i in range(rnd.randint(8, 10)):
        ang = rnd.uniform(0, math.tau)
        base = V((math.cos(ang) * rnd.uniform(0, 0.12), math.sin(ang) * rnd.uniform(0, 0.12), -0.02))
        lean = V((math.cos(ang) * rnd.uniform(0.05, 0.18), math.sin(ang) * rnd.uniform(0.05, 0.18), 0))
        tip = base + lean + V((0, 0, rnd.uniform(0.28, 0.5)))
        faces = b.new_faces(lambda base=base, tip=tip: blade(b.bm, base, tip, 0.042))
        b.paint(faces, "Grass")
        col = rnd.choice(GRASS)
        b.gradient(faces, tuple(c * 0.62 for c in col), tuple(min(1.0, c * 1.2 + 0.04) for c in col))
    return b


def flower(seed, count=3):
    rnd = random.Random(seed)
    b = Builder(["Plant"])
    petal = rnd.choice(PETALS)
    for i in range(count):
        base = V((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), -0.02))
        top = base + V((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), rnd.uniform(0.3, 0.5)))
        b.paint(b.new_faces(lambda base=base, top=top: rk.tube(b.bm, [base, top], [(0.012, 0.012)] * 2, seg=3)), "Plant", GRASS[1])
        b.paint(b.new_faces(lambda top=top: blade(b.bm, top - V((0, 0, 0.22)), top - V((0, 0, 0.22)) + V((0.12, 0.02, 0.08)), 0.025)), "Plant", GRASS[0])
        clump(b, top, 0.075, 1, rnd, petal, "Plant", 0.6)
        clump(b, top + V((0, 0, 0.035)), 0.028, 1, rnd, (0.98, 0.85, 0.3), "Plant", 1.0)
    return b


def mushroom(seed, cap_color):
    rnd = random.Random(seed)
    b = Builder(["Plant"])
    for i in range(rnd.randint(1, 3)):
        c = V((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.12, 0.12), 0))
        h = rnd.uniform(0.12, 0.22)
        b.paint(b.new_faces(lambda c=c, h=h: rk.tube(b.bm, [c + V((0, 0, -0.02)), c + V((0, 0, h))], [(0.03, 0.03), (0.026, 0.026)], seg=6)),
                "Plant", (0.93, 0.9, 0.82))
        r = h * 0.7
        b.paint(b.new_faces(lambda c=c, h=h, r=r: rk.tube(b.bm, [c + V((0, 0, h - 0.02)), c + V((0, 0, h + r * 0.35)), c + V((0, 0, h + r * 0.6))],
                                                          [(r, r), (r * 0.7, r * 0.7), (0.01, 0.01)], seg=7)), "Plant", cap_color)
    return b


def fern(seed):
    rnd = random.Random(seed)
    b = Builder(["Plant"])
    for i in range(7):
        ang = i * math.tau / 7 + rnd.uniform(-0.2, 0.2)
        tip = V((math.cos(ang) * 0.45, math.sin(ang) * 0.45, rnd.uniform(0.2, 0.35)))
        faces = b.new_faces(lambda tip=tip: blade(b.bm, V((0, 0, 0.02)), tip, 0.07))
        b.paint(faces, "Plant", rnd.choice(GRASS[:3]))
    return b


def stump(seed):
    b = Builder(["Trunk", "Stump"])
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, -0.1)), V((0, 0, 0.25)), V((0, 0, 0.42))],
                                        [(0.34, 0.34), (0.26, 0.26), (0.24, 0.24)], seg=7)), "Trunk")
    for f in b.bm.faces:
        f.normal_update()
        if f.normal.z > 0.9:
            f.material_index = 1
    return b


def export(name, b):
    export_to(name, b, OUT)


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials(COLORS, roughness=0.95)
os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith(".glb") or f.endswith(".glb.import"):
        os.remove(os.path.join(OUT, f))
export("tree_oak_1", broad_tree(11))
export("tree_oak_2", broad_tree(23))
export("tree_round_1", broad_tree(31, "round"))
export("tree_round_2", broad_tree(37, "round"))
export("tree_small_1", broad_tree(43, "small"))
export("tree_small_2", broad_tree(47, "small"))
export("tree_tall_1", broad_tree(67, "tall"))
export("tree_apple_1", broad_tree(53, "round", fruit=True))
export("tree_blossom_1", broad_tree(41, "oak", "Blossom", PINKS))
export("tree_pine_1", pine_tree(5))
export("tree_pine_2", pine_tree(18))
export("tree_dead_1", dead_tree(7))
export("bush_1", bush(3))
export("bush_2", bush(8))
export("bush_flower_1", bush(13, flowers=True))
export("tree_stump", stump(1))
for i in range(3):
    export(f"rock_{i + 1}", rock(100 + i))
for i in range(3):
    export(f"stones_{i + 1}", stones(110 + i))
for i in range(2):
    export(f"pebble_{i + 1}", pebbles(120 + i))
for i in range(3):
    export(f"grass_{i + 1}", grass(130 + i))
for i in range(5):
    export(f"flower_{i + 1}", flower(140 + i * 3, 2 + i % 2))
export("mushroom_1", mushroom(150, (0.82, 0.24, 0.18)))
export("mushroom_2", mushroom(151, (0.72, 0.5, 0.32)))
export("fern_1", fern(160))
